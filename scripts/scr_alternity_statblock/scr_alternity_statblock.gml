/// @description Alternity RPG Stat Block System
/// Based on Alternity Science Fiction Roleplaying Game (TSR, 1998)

// -- Enums --

enum PROFESSION {
	COMBAT_SPEC,
	DIPLOMAT,
	FREE_AGENT,
	TECH_OP,
	MINDWALKER
}

enum DAMAGE_TYPE {
	LI, // Low Impact
	HI, // High Impact
	EN  // Energy
}

// -- Skill Library System --
// global.skill_tree REMOVED — use global.skill_tree directly

// damage_type_to_string() REMOVED — inline ["LI","HI","En"][clamp(_dt,0,2)] at callsites
function string_to_damage_type(_s) {
	var _map = { LI: 0, HI: 1, EN: 2 };
	return _map[$ string_upper(_s)] ?? 0;
}

// careers_to_export() REMOVED — never called (career data lives in JSON, no round-trip needed)

/// @function careers_from_import(career_array)
/// @description Converts imported career array (string damage types → enums)
function careers_from_import(_careers) {
	var _out = [];
	for (var _i = 0; _i < array_length(_careers); _i++) {
		var _c = _careers[_i];
		var _weps = [];
		if (_c[$ "weapons"] != undefined) {
			for (var _w = 0; _w < array_length(_c.weapons); _w++) {
				var _wp = _c.weapons[_w];
				// v4: [name, skill_keyword, dmg_o, dmg_g, dmg_a, range, type]
				var _dt = is_string(_wp[6]) ? string_to_damage_type(_wp[6]) : _wp[6];
				array_push(_weps, [_wp[0], _wp[1], _wp[2], _wp[3], _wp[4], _wp[5], _dt]);
			}
		}
		array_push(_out, {
			name: _c.name,
			broads: _c.broads,
			specs: _c[$ "specs"] ?? [],
			weapons: _weps,
			armor: _c[$ "armor"] ?? ["None","0","0","0"],
			gear: _c[$ "gear"] ?? []
		});
	}
	return _out;
}


// Default data generators REMOVED — data lives in JSON files (datafiles/ directory)
// Species data: species.json | Skill tree: skills.json | Careers: careers.json

// hero_has_broad_skill / hero_has_specialty COLLAPSED into find_skill() in scr_chargen
// Use: find_skill(_stat, _broad, "") >= 0   (was hero_has_broad_skill)
// Use: find_skill(_stat, _broad, _spec) >= 0 (was hero_has_specialty)

/// @function get_broad_skill_scores(statblock, broad_name)
/// @description Returns the broad skill's scores as a struct, or undefined if not found
function get_broad_skill_scores(_stat, _broad_name) {
	for (var _i = 0; _i < array_length(_stat.skills); _i++) {
		var _sk = _stat.skills[_i];
		if (_sk.broad_skill == _broad_name && _sk.specialty == "") {
			return { idx: _i, ordinary: _sk.score_ordinary, good: _sk.score_good, amazing: _sk.score_amazing, ability: _sk.ability };
		}
	}
	return undefined;
}

/// @function add_specialty_rank0(statblock, broad_name, spec_name)
/// @description Adds a rank-0 specialty under an existing broad skill (uses broad skill scores)
/// @returns {bool} true if added, false if broad skill not found or specialty already exists
function add_specialty_rank0(_stat, _broad_name, _spec_name) {
	if (find_skill(_stat, _broad_name, _spec_name) >= 0) return false;

	var _broad = get_broad_skill_scores(_stat, _broad_name);
	if (_broad == undefined) return false;

	// Find insertion point: right after the last specialty of this broad skill
	var _insert_idx = _broad.idx + 1;
	while (_insert_idx < array_length(_stat.skills)
	    && _stat.skills[_insert_idx].broad_skill == _broad_name
	    && _stat.skills[_insert_idx].specialty != "") {
		_insert_idx++;
	}

	var _skill = {
		ability: _broad.ability,
		broad_skill: _broad_name,
		specialty: _spec_name,
		rank: 0,
		score_ordinary: _broad.ordinary,
		score_good: _broad.good,
		score_amazing: _broad.amazing
	};

	array_insert(_stat.skills, _insert_idx, _skill);
	return true;
}

/// @function build_browser_list(statblock, [ability_filter])
/// @description Builds the flat list of browsable entries for the skill browser.
///   Returns array of structs: { type: "broad"/"specialty"/"add", broad, specialty, ability, owned }
///   If ability_filter is provided (e.g. "str"), only includes skills of that ability.
function build_browser_list(_stat, _ability_filter) {
	if (_ability_filter == undefined) _ability_filter = "";
	var _tree = global.skill_tree;
	var _list = [];

	for (var _t = 0; _t < array_length(_tree); _t++) {
		var _branch = _tree[_t];
		// Filter by ability if specified
		if (_ability_filter != "" && _branch.ability != _ability_filter) continue;
		var _has_broad = find_skill(_stat, _branch.broad, "") >= 0;

		// Always show the broad skill entry
		array_push(_list, {
			type: "broad",
			broad: _branch.broad,
			specialty: "",
			ability: _branch.ability,
			owned: _has_broad
		});

		// If the hero has this broad skill, show all specialties under it
		if (_has_broad) {
			for (var _s = 0; _s < array_length(_branch.specialties); _s++) {
				var _spec = _branch.specialties[_s];
				var _has_spec = find_skill(_stat, _branch.broad, _spec) >= 0;
				array_push(_list, {
					type: _has_spec ? "specialty" : "add",
					broad: _branch.broad,
					specialty: _spec,
					ability: _branch.ability,
					owned: _has_spec
				});
			}
		}
	}

	return _list;
}

// -- Stat Block Creation --

/// @function create_statblock(name, profession, career)
/// @description Creates a new Alternity character stat block as a struct
/// @param {string} _name         Hero's name
/// @param {real}   _profession   PROFESSION enum value
/// @param {string} _career       Career name (e.g. "Soldier", "Pilot")
/// @returns {struct} Complete Alternity stat block
function create_statblock(_name, _profession, _career) {
	var _stat = {};

	// Identity
	_stat.name = _name;
	_stat.profession = _profession;
	_stat.career = _career;
	_stat.species = 0; // SPECIES.HUMAN default
	_stat.secondary_profession = -1; // Diplomat dual-class only
	_stat.portrait_path = ""; // Custom portrait file path
	// Unified FX system: perks, flaws, cybertech, racial, environmental, items
	// Each entry: { name, type, quality, active }
	// Full FX data (keywords, modifiers, prereqs) lives in global.fx_database
	_stat.fx = [];

	// Abilities: score, untrained (score div 2), resistance modifier
	_stat.str = { score: 10, untrained: 5, res_mod: 0 };
	_stat.dex = { score: 10, untrained: 5, res_mod: 0 };
	_stat.con = { score: 10, untrained: 5, res_mod: 0 };
	_stat.int_ = { score: 10, untrained: 5, res_mod: 0 };
	_stat.wil = { score: 10, untrained: 5, res_mod: 0 };
	_stat.per = { score: 10, untrained: 5, res_mod: 0 };

	// Action Check: (DEX + INT) / 2 + profession bonus
	// Scores: Marginal / Ordinary / Good / Amazing
	_stat.action_check = { marginal: 0, ordinary: 0, good: 0, amazing: 0 };
	_stat.actions_per_round = 2;

	// Durability
	_stat.stun    = { max: 0, current: 0 };
	_stat.wound   = { max: 0, current: 0 };
	_stat.mortal  = { max: 0, current: 0 };

	// Skills: array of skill structs
	_stat.skills = [];

	// Weapons: array of weapon structs
	_stat.weapons = [];

	// Armor
	_stat.armor = { name: "None", li: "0", hi: "0", en: "0" };

	// Gear
	_stat.gear = [];

	// Background (legacy single string — kept for import compat)
	_stat.background = "";

	// Lore / Aura — character identity and lifepath (PHB Step 8: Choose Attributes)
	// PHB references "motivation, moral attitude, and character traits" (GMG p.119)
	_stat.lore = {
		height: "", weight: "", hair: "", gender: "",
		moral_attitude: "",  // freeform — how the character views right and wrong
		temperament: [],     // 2-3 descriptive trait words
		motivations: [],     // 1-2 driving forces
		personality: "",     // freeform personality notes, quirks, habits
		lifepath: ""         // full backstory / lifepath narrative
	};

	// Grid/Cyberdeck — computer and installed programs
	_stat.deck = { computer: "None", processor: "", programs: [] };
	// programs: array of { name, quality } — matches programs.json entries

	return _stat;
}

/// @function set_ability(statblock, ability_name, score)
/// @description Sets an ability score and auto-calculates untrained & resistance modifier
function set_ability(_stat, _ability_name, _score) {
	var _ab;
	switch (_ability_name) {
		case "str": _ab = _stat.str; break;
		case "dex": _ab = _stat.dex; break;
		case "con": _ab = _stat.con; break;
		case "int": _ab = _stat.int_; break;
		case "wil": _ab = _stat.wil; break;
		case "per": _ab = _stat.per; break;
		default: show_debug_message("Unknown ability: " + _ability_name); return;
	}
	_ab.score = _score;
	_ab.untrained = _score div 2;
	// Resistance modifier: 0 for 9-10, +1 for 11-12, +2 for 13-14, -1 for 7-8, etc.
	_ab.res_mod = (_score div 2) - 5;
}

/// @function calculate_action_check(statblock)
/// @description Calculates action check scores from DEX + INT + profession bonus
function calculate_action_check(_stat) {
	var _base = (_stat.dex.score + _stat.int_.score) div 2;

	// Profession bonus (from professions.json)
	var _bonus = 0;
	if (_stat.profession >= 0 && _stat.profession < array_length(global.professions))
		_bonus = global.professions[_stat.profession].action_check_bonus;

	var _total = _base + _bonus;
	_stat.action_check.ordinary = _total;
	_stat.action_check.good     = _total div 2;
	_stat.action_check.amazing  = _total div 4;
	_stat.action_check.marginal = _total + 1; // Marginal = ordinary + 1 (displayed as "X+")
}

/// @function calculate_durability(statblock)
/// @description Calculates durability from CON and profession
function calculate_durability(_stat) {
	var _con = _stat.con.score;
	// durability_mod from professions.json (0-2 typically)
	var _mod = 0;
	if (_stat.profession >= 0 && _stat.profession < array_length(global.professions))
		_mod = global.professions[_stat.profession].durability_mod;

	_stat.stun.max  = _con + _mod;
	_stat.wound.max = _con + _mod;
	_stat.mortal.max = (_con + _mod) div 2;

	_stat.stun.current   = _stat.stun.max;
	_stat.wound.current  = _stat.wound.max;
	_stat.mortal.current = _stat.mortal.max;
}

/// @function add_skill(statblock, ability, broad_name, specialty_name, rank, score_ord, score_good, score_amz)
/// @description Adds a skill to the stat block
function add_skill(_stat, _ability, _broad_name, _specialty_name, _rank, _score_ord, _score_good, _score_amz) {
	var _skill = {
		ability: _ability,
		broad_skill: _broad_name,
		specialty: _specialty_name,  // "" if broad skill only
		rank: _rank,
		score_ordinary: _score_ord,
		score_good: _score_good,
		score_amazing: _score_amz
	};
	array_push(_stat.skills, _skill);
}

/// @function add_weapon(statblock, name, skill_keyword, dmg_ord, dmg_good, dmg_amz, range_str, damage_type)
/// @description Adds a weapon to the stat block. skill_keyword maps to keyword_tree.weapon_skills.
function add_weapon(_stat, _name, _skill_kw, _dmg_ord, _dmg_good, _dmg_amz, _range_str, _damage_type) {
	var _weapon = {
		name: _name,
		skill_keyword: _skill_kw,    // e.g. "rifle", "pistol", "blade", "brawl"
		dmg_ordinary: _dmg_ord,
		dmg_good: _dmg_good,
		dmg_amazing: _dmg_amz,
		range_str: _range_str,       // e.g. "8/16/60" or "Personal"
		damage_type: _damage_type    // DAMAGE_TYPE enum
	};
	array_push(_stat.weapons, _weapon);
}

/// @function set_armor(statblock, name, li, hi, en)
/// @description Sets armor on the stat block
function set_armor(_stat, _name, _li, _hi, _en) {
	_stat.armor.name = _name;
	_stat.armor.li = _li;
	_stat.armor.hi = _hi;
	_stat.armor.en = _en;
}

function remove_weapon(_stat, _idx) {
	if (_idx >= 0 && _idx < array_length(_stat.weapons)) array_delete(_stat.weapons, _idx, 1);
}

function remove_gear(_stat, _idx) {
	if (_idx >= 0 && _idx < array_length(_stat.gear)) array_delete(_stat.gear, _idx, 1);
}

// add_weapon_from_db() REMOVED — inlined at callsite
// set_armor_from_db() REMOVED — inlined at callsite

function hero_has_weapon(_stat, _name) {
	for (var _i = 0; _i < array_length(_stat.weapons); _i++)
		if (_stat.weapons[_i].name == _name) return true;
	return false;
}

// format_mod() REMOVED — inline (_val > 0 ? "+" : "") + string(_val) at callsites

// create_sample_soldier() REMOVED — Voss data lives in datafiles/voss.json, loaded via load_character_from_path

// -- Export / Import --

/// @function build_statblock_export(statblock)
/// @description Builds the v4 export struct for a statblock. Used by statblock_export and save_hero_and_track.
function build_statblock_export(_stat) {
	var _export = {};
	_export._format = "alternity_statblock";
	_export._version = 4;
	_export.name = _stat.name;
	_export.species = (_stat[$ "species"] != undefined) ? get_species_name(_stat.species) : "Human";
	_export.profession = get_profession_name(_stat.profession);
	_export.career = _stat.career;
	if ((_stat[$ "secondary_profession"] ?? -1) >= 0)
		_export.secondary_profession = get_profession_name(_stat.secondary_profession);
	_export.STR = _stat.str.score; _export.DEX = _stat.dex.score; _export.CON = _stat.con.score;
	_export.INT = _stat.int_.score; _export.WIL = _stat.wil.score; _export.PER = _stat.per.score;
	_export.stun_damage = _stat.stun.max - _stat.stun.current;
	_export.wound_damage = _stat.wound.max - _stat.wound.current;
	_export.mortal_damage = _stat.mortal.max - _stat.mortal.current;
	var _skills_out = [];
	for (var _i = 0; _i < array_length(_stat.skills); _i++) {
		var _sk = _stat.skills[_i];
		if (_sk.specialty == "") array_push(_skills_out, [_sk.broad_skill, string_upper(_sk.ability), -1]);
		else array_push(_skills_out, [_sk.specialty, _sk.broad_skill, _sk.rank]);
	}
	_export.skills = _skills_out;
	_export.weapons = build_weapon_export_array(_stat);
	_export.armor = [_stat.armor.name, _stat.armor.li, _stat.armor.hi, _stat.armor.en];
	_export.gear = _stat.gear;
	_export.background = _stat.background;
	if (_stat[$ "lore"] != undefined) _export.lore = _stat.lore;
	if ((_stat[$ "portrait_path"] ?? "") != "") _export.portrait = _stat.portrait_path;
	if (array_length(_stat[$ "fx"] ?? []) > 0) _export.fx = _stat.fx;
	if (_stat[$ "deck"] != undefined) _export.deck = _stat.deck;
	return _export;
}

/// @function statblock_export(statblock)
/// @description Exports a character stat block to a JSON file via save dialog.
function statblock_export(_stat) {
	var _path = get_save_filename("JSON files|*.json", _stat.name + ".json");
	if (_path == "") return false;
	var _file = file_text_open_write(_path);
	file_text_write_string(_file, json_stringify(build_statblock_export(_stat), true));
	file_text_close(_file);
	return true;
}

/// @function statblock_import()
/// @description Imports a character stat block from a JSON file via open dialog.
function statblock_import() {
	var _path = get_open_filename("JSON files|*.json", "");
	if (_path == "" || !file_exists(_path)) return undefined;
	var _json = "";
	var _file = file_text_open_read(_path);
	while (!file_text_eof(_file)) _json += file_text_readln(_file);
	file_text_close(_file);
	return statblock_import_data(json_parse(_json));
}

/// @function _resolve_enum(val, parser)
/// @description Resolves a string-or-number value using a parser function if string.
function _resolve_enum(_val, _parser) {
	return is_string(_val) ? _parser(_val) : _val;
}

/// @function statblock_import_data(data)
/// @description Builds a statblock from parsed JSON data. Returns struct or undefined.
function statblock_import_data(_data) {
	if ((_data[$ "_format"] ?? "") != "alternity_statblock") return undefined;

	var _stat = create_statblock(_data.name, _resolve_enum(_data.profession, parse_profession_name), _data.career);
	_stat.species = _resolve_enum(_data[$ "species"] ?? 0, parse_species_name);
	if (_data[$ "secondary_profession"] != undefined)
		_stat.secondary_profession = _resolve_enum(_data.secondary_profession, parse_profession_name);

	// Abilities — unified reader for v2 (nested), v3 (lowercase), v4 (uppercase)
	var _src = _data;
	if (_data[$ "STR"] != undefined) _src = _data;
	else if (_data[$ "str"] != undefined) _src = _data;
	else if (_data[$ "abilities"] != undefined) _src = _data.abilities;
	var _keys_upper = ["STR","DEX","CON","INT","WIL","PER"];
	var _keys_lower = ["str","dex","con","int","wil","per"];
	for (var _i = 0; _i < 6; _i++) {
		var _val = _src[$ _keys_upper[_i]] ?? _src[$ _keys_lower[_i]] ?? (_keys_lower[_i] == "int" ? (_src[$ "int_"] ?? 10) : 10);
		set_ability(_stat, _keys_lower[_i], _val);
	}

	calculate_action_check(_stat);
	calculate_durability(_stat);

	// Durability — v3/v4: damage taken; v2: durability struct or raw values
	if (_data[$ "stun_damage"] != undefined) {
		_stat.stun.current = _stat.stun.max - _data.stun_damage;
		_stat.wound.current = _stat.wound.max - _data.wound_damage;
		_stat.mortal.current = _stat.mortal.max - _data.mortal_damage;
	} else if (_data[$ "durability"] != undefined) {
		_stat.stun.current = _data.durability.stun_current;
		_stat.wound.current = _data.durability.wound_current;
		_stat.mortal.current = _data.durability.mortal_current;
	} else {
		if (_data[$ "stun"] != undefined) _stat.stun.current = _data.stun;
		if (_data[$ "wound"] != undefined) _stat.wound.current = _data.wound;
		if (_data[$ "mortal"] != undefined) _stat.mortal.current = _data.mortal;
	}

	// Skills — compact array or v2 object
	_stat.skills = [];
	for (var _i = 0; _i < array_length(_data.skills); _i++) {
		var _entry = _data.skills[_i];
		if (is_array(_entry) && array_length(_entry) >= 3) {
			if (_entry[2] == -1) {
				var _ab = string_lower(_entry[1]);
				var _abScore = get_ability_score_for_skill(_stat, _ab);
				add_skill(_stat, _ab, _entry[0], "", 1, _abScore, _abScore div 2, _abScore div 4);
			} else {
				var _broadInfo = get_broad_skill_scores(_stat, _entry[1]);
				var _ability = _broadInfo != undefined ? _broadInfo.ability : "str";
				var _base = (_broadInfo != undefined ? _broadInfo.ordinary : 5) + _entry[2];
				add_skill(_stat, _ability, _entry[1], _entry[0], _entry[2], _base, _base div 2, _base div 4);
			}
		} else {
			add_skill(_stat, _entry.ability, _entry.broad_skill, _entry.specialty,
				_entry.rank, _entry.score_ordinary, _entry.score_good, _entry.score_amazing);
		}
	}

	// Weapons — array or object format
	_stat.weapons = [];
	for (var _i = 0; _i < array_length(_data.weapons); _i++) {
		var _w = _data.weapons[_i];
		if (is_array(_w)) {
			var _dtype = (array_length(_w) > 6) ? (is_string(_w[6]) ? string_to_damage_type(_w[6]) : _w[6]) : DAMAGE_TYPE.LI;
			add_weapon(_stat, _w[0], _w[1], _w[2], _w[3], _w[4], _w[5], _dtype);
		} else {
			add_weapon(_stat, _w.name, _w[$ "skill_keyword"] ?? "", _w.dmg_ordinary, _w.dmg_good, _w.dmg_amazing, _w.range_str, _w[$ "damage_type"] ?? DAMAGE_TYPE.LI);
		}
	}

	// Armor
	if (is_array(_data.armor)) set_armor(_stat, _data.armor[0], _data.armor[1], _data.armor[2], _data.armor[3]);
	else set_armor(_stat, _data.armor.name, _data.armor.li, _data.armor.hi, _data.armor.en);

	_stat.gear = _data.gear;
	_stat.background = _data.background;
	_stat.portrait_path = _data[$ "portrait"] ?? "";

	// Lore
	var _loreData = _data[$ "lore"] ?? {};
	_stat.lore = {
		height: _loreData[$ "height"] ?? "", weight: _loreData[$ "weight"] ?? "",
		hair: _loreData[$ "hair"] ?? "", gender: _loreData[$ "gender"] ?? "",
		moral_attitude: _loreData[$ "moral_attitude"] ?? (_loreData[$ "morals"] ?? ""),
		temperament: _loreData[$ "temperament"] ?? [], motivations: _loreData[$ "motivations"] ?? [],
		personality: _loreData[$ "personality"] ?? "", lifepath: _loreData[$ "lifepath"] ?? ""
	};
	if (is_string(_stat.lore.temperament)) _stat.lore.temperament = _stat.lore.temperament != "" ? [_stat.lore.temperament] : [];
	if (is_string(_stat.lore.motivations)) _stat.lore.motivations = _stat.lore.motivations != "" ? [_stat.lore.motivations] : [];
	if (_stat.lore.lifepath == "" && _stat.background != "") _stat.lore.lifepath = _stat.background;

	_stat.fx = _data[$ "fx"] ?? [];
	_stat.deck = _data[$ "deck"] ?? { computer: "None", processor: "", programs: [] };

	// Migration: back-fill racial trait FX entries for characters saved before v0.61.0.
	// If the character has no entries with type=="racial" and a known species, grant them.
	var _has_racial = false;
	for (var _i = 0; _i < array_length(_stat.fx); _i++) {
		if (_stat.fx[_i].type == "racial") { _has_racial = true; break; }
	}
	if (!_has_racial && _stat.species >= 0 && script_exists(asset_get_index("grant_racial_traits"))) {
		grant_racial_traits(_stat);
	}

	return _stat;
}

/// @function draw_durability_circles(x, y, label, current, max_val, bar_color, text_color)
/// @description Draws a row of clickable durability circles. Left=damaged (filled),
/// right=healthy (outlined). Click damaged circle → heal back. Click healthy → damage.
/// Returns the new current value if clicked, or -1 if no click. Caller assigns the
/// result and calls log_health_change(). Label format matches the rest of the app:
/// "Stun: 12/12" (current/max), NOT "Stun: 0/12" (damage/max).
function draw_durability_circles(_x, _y, _label, _current, _max_val, _bar_color, _text_color) {
	var _dmg = _max_val - _current;
	draw_set_colour(_text_color);
	draw_text(_x, _y, _label + ": " + string(_current) + "/" + string(_max_val));
	var _cx = _x + 130; var _r = 7; var _gap = 18; var _result = -1;
	var _mx = device_mouse_x_to_gui(0); var _my = device_mouse_y_to_gui(0);
	for (var _i = 0; _i < _max_val; _i++) {
		var _ox = _cx + _i * _gap; var _oy = _y + _r + 2;
		var _isDamaged = (_i < _dmg);
		var _hover = (point_distance(_mx, _my, _ox, _oy) <= _r + 2);
		if (_hover && mouse_check_button_pressed(mb_left))
			_result = _isDamaged ? (_max_val - _i) : (_max_val - _i - 1);
		if (_isDamaged) { draw_set_colour(_bar_color); draw_circle(_ox, _oy, _r, false); }
		draw_set_colour(_hover ? #ffffff : _bar_color);
		draw_circle(_ox, _oy, _r, true);
	}
	return _result;
}

/// @function get_fx_data(name)
/// @description Looks up full FX definition from global.fx_database by name. Returns struct or undefined.
function get_fx_data(_name) {
	if (global.fx_lookup[$ _name] != undefined)
		return global.fx_database[global.fx_lookup[$ _name]];
	return undefined;
}

/// @function get_program_data(name)
/// @description Looks up full program definition from global.programs by name. Returns struct or undefined.
function get_program_data(_name) {
	if (global.program_lookup[$ _name] != undefined)
		return global.programs[global.program_lookup[$ _name]];
	return undefined;
}

/// @function get_deck_slots(statblock)
/// @description Returns { used, total } slot counts for the hero's cyberdeck.
function get_deck_slots(_stat) {
	var _proc = _stat.deck[$ "processor"] ?? "";
	var _mem = 0;
	if (_proc != "" && global.processor_quality[$ _proc] != undefined)
		_mem = global.processor_quality[$ _proc].memory_base;
	var _used = 0;
	for (var _i = 0; _i < array_length(_stat.deck.programs); _i++) {
		var _pd = get_program_data(_stat.deck.programs[_i].name);
		if (_pd != undefined) _used += _pd[$ "slots"] ?? 1;
	}
	return { used: _used, total: _mem };
}

/// @function update_hero(statblock)
/// @description Master update - recalculates ALL derived values from base data
function update_hero(_stat) {
	if (_stat[$ "fx"] == undefined) _stat.fx = [];

	// Recalculate ability derived values
	var _abs = [_stat.str, _stat.dex, _stat.con, _stat.int_, _stat.wil, _stat.per];
	for (var _i = 0; _i < 6; _i++) {
		_abs[_i].untrained = _abs[_i].score div 2;
		_abs[_i].res_mod = (_abs[_i].score div 2) - 5;
	}

	calculate_action_check(_stat);

	// Durability (preserves current damage)
	var _dmg = [_stat.stun.max - _stat.stun.current, _stat.wound.max - _stat.wound.current, _stat.mortal.max - _stat.mortal.current];
	calculate_durability(_stat);
	_stat.stun.current = max(0, _stat.stun.max - _dmg[0]);
	_stat.wound.current = max(0, _stat.wound.max - _dmg[1]);
	_stat.mortal.current = max(0, _stat.mortal.max - _dmg[2]);

	recalc_skill_scores(_stat);
	load_portrait_for_hero(_stat);
}

/// @function get_wound_penalty(statblock)
/// @description Returns situation die step penalty from wounds/mortal damage
function get_wound_penalty(_stat) {
	var _mortalDmg = _stat.mortal.max - _stat.mortal.current;
	var _woundDmg = _stat.wound.max - _stat.wound.current;
	return _mortalDmg + (_woundDmg >= _stat.wound.max ? 2 : (_woundDmg >= (_stat.wound.max div 2) ? 1 : 0));
}

// get_skill_use_penalty() REMOVED — inline (_sk.specialty != "" ? 0 : 1) at callsite

// get_untrained_score() REMOVED — inline get_ability_score_for_skill(_stat, _ability) div 2

// save_voss_template() REMOVED — Voss data lives in datafiles/voss.json, copied at startup

// ============================================================
// PERSISTENT ROLL LOG
// ============================================================

/// @function sanitize_hero_filename(name)
/// @description Strips spaces, apostrophes, and Windows-illegal chars from hero name for safe file paths
function sanitize_hero_filename(_name) {
	var _safe = string_replace_all(string_lower(_name), " ", "_");
	_safe = string_replace_all(_safe, "'", "");
	var _clean = "";
	for (var _ci = 1; _ci <= string_length(_safe); _ci++) {
		var _ch = string_char_at(_safe, _ci);
		if (string_pos(_ch, "/\\:*?\"<>|") == 0) _clean += _ch;
	}
	return (_clean == "") ? "unnamed" : _clean;
}

/// @function append_roll_log_file(hero, roll_result)
/// @description Appends a roll entry to the character's persistent log file
function append_roll_log_file(_stat, _roll) {
	var _file = file_text_open_append(get_roll_log_path(_stat));
	if (_file == -1) return;
	var _dt = date_current_datetime();
	var _ts = string(date_get_year(_dt)) + "-" + string(date_get_month(_dt)) + "-" + string(date_get_day(_dt)) + " " + string(date_get_hour(_dt)) + ":" + string(date_get_minute(_dt));
	var _sitStr = (_roll.situation_roll != 0) ? (" " + situation_step_name(_roll.situation_step) + ":" + string(_roll.situation_roll)) : "";
	var _modStr = "";
	var _mods = _roll[$ "modifiers"] ?? [];
	if (array_length(_mods) > 0) {
		_modStr = " (";
		for (var _mi = 0; _mi < array_length(_mods); _mi++) { if (_mi > 0) _modStr += ", "; _modStr += _mods[_mi]; }
		_modStr += ")";
	}
	file_text_write_string(_file, _ts + " | " + _roll.skill_name + " [" + get_difficulty_descriptor(_roll.situation_step) + "] | d20:" + string(_roll.control_roll) + _sitStr + " = " + string(_roll.total) + _modStr + " => " + _roll.degree_name);
	file_text_writeln(_file);
	file_text_close(_file);
}

/// @function load_roll_log_tail(hero, count)
/// @description Loads the last N lines from the character's roll log file
function load_roll_log_tail(_stat, _count) {
	var _path = get_roll_log_path(_stat);
	if (!file_exists(_path)) return [];
	var _all = [];
	var _file = file_text_open_read(_path);
	while (!file_text_eof(_file)) {
		var _line = file_text_readln(_file);
		while (string_length(_line) > 0 && (string_char_at(_line, string_length(_line)) == chr(10) || string_char_at(_line, string_length(_line)) == chr(13)))
			_line = string_delete(_line, string_length(_line), 1);
		if (_line != "") array_push(_all, _line);
	}
	file_text_close(_file);
	var _start = max(0, array_length(_all) - _count);
	var _result = [];
	for (var _i = _start; _i < array_length(_all); _i++) array_push(_result, _all[_i]);
	return _result;
}

/// @function get_roll_log_path(hero)
function get_roll_log_path(_stat) {
	return global.save_path + sanitize_hero_filename(_stat.name) + "_rolllog.log";
}

// ============================================================
// DAMAGE ROLLING
// ============================================================

/// @function _read_digits(str, start_pos)
/// @description Reads consecutive digit characters from str starting at start_pos. Returns string of digits.
function _read_digits(_str, _pos) {
	var _out = "";
	for (var _c = _pos; _c <= string_length(_str); _c++) {
		var _ch = string_char_at(_str, _c);
		if (_ch >= "0" && _ch <= "9") _out += _ch; else break;
	}
	return _out;
}

/// @function parse_and_roll_damage(dmg_string)
/// @description Parses "d6+1w", "d8+2s", "d4m", or multi-die "3d8w", "2d4+2w" and rolls it.
function parse_and_roll_damage(_dmg) {
	var _str = string_lower(string_replace_all(_dmg, " ", ""));
	var _sides = 0; var _mod = 0; var _dieCount = 1;
	var _dPos = string_pos("d", _str);
	if (_dPos > 0) {
		if (_dPos > 1) { var _cnt = _read_digits(_str, 1); if (_cnt != "") _dieCount = max(1, real(_cnt)); }
		var _dStr = _read_digits(_str, _dPos + 1); if (_dStr != "") _sides = real(_dStr);
	}
	// Modifier: +N or -N
	var _plus = string_pos("+", _str); var _minus = string_pos("-", _str);
	if (_plus > 0) { var _ms = _read_digits(_str, _plus + 1); if (_ms != "") _mod = real(_ms); }
	else if (_minus > 0 && _minus != _dPos) { var _ms = _read_digits(_str, _minus + 1); if (_ms != "") _mod = -real(_ms); }
	// Type: last char
	var _last = string_char_at(_str, string_length(_str));
	var _typeChar = (_last == "w") ? "w" : ((_last == "m") ? "m" : "s");
	var _typeName = (_typeChar == "w") ? "wound" : ((_typeChar == "m") ? "mortal" : "stun");
	// Roll
	var _roll = 0;
	for (var _di = 0; _di < _dieCount && _sides > 0; _di++) _roll += irandom_range(1, _sides);
	var _total = max(0, _roll + _mod);
	var _dieText = (_dieCount > 1 ? string(_dieCount) : "") + "d" + string(_sides);
	return { roll: _roll, modifier: _mod, total: _total, die_sides: _sides, die_count: _dieCount,
		type_char: _typeChar, type_name: _typeName,
		text: string(_total) + " " + _typeName + " (" + _dieText + "=" + string(_roll) + (_mod >= 0 ? "+" : "") + string(_mod) + ")" };
}

/// @function get_difficulty_descriptor(situation_step)
/// @description Returns PHB difficulty label based on the situation die step (Table P16).
function get_difficulty_descriptor(_step) {
	var _labels = ["Amazing bonus (-d20)","Good bonus (-d12)","Ordinary bonus (-d8)","Slight bonus (-d6)",
		"Marginal bonus (-d4)","Standard (+d0)","Slight penalty (+d4)","Moderate penalty (+d6)",
		"Extreme penalty (+d8)","Severe penalty (+d12)","Critical penalty (+d20)"];
	return (_step >= 0 && _step < array_length(_labels)) ? _labels[_step] : "Standard";
}

// get_range_penalty() REMOVED — inline clamp(range, 0, 2)

/// @function find_best_skill_for_weapon(statblock, weapon)
/// @description Finds the hero's best applicable skill for a weapon.
///   Uses weapon.skill_keyword → keyword_tree.weapon_skills for resolution.
function find_best_skill_for_weapon(_stat, _wep) {
	var _broad_name = "Modern Ranged Weapons";
	var _spec_name = "";

	// Resolve via skill_keyword + keyword_tree
	var _kw = _wep[$ "skill_keyword"] ?? "";
	if (_kw != "" && global.keyword_tree.weapon_skills[$ _kw] != undefined) {
		var _ws = global.keyword_tree.weapon_skills[$ _kw];
		_broad_name = _ws.broad;
		_spec_name = _ws.spec;
	}

	// Try specialty first
	if (_spec_name != "") {
		var _idx = find_skill(_stat, _broad_name, _spec_name);
		if (_idx >= 0) {
			var _sk = _stat.skills[_idx];
			return { idx: _idx, score_ord: _sk.score_ordinary, score_good: _sk.score_good, score_amz: _sk.score_amazing,
			         use_type: "Trained", penalty: 0, skill_name: _spec_name };
		}
	}

	// Try broad skill
	var _bidx = find_skill(_stat, _broad_name, "");
	if (_bidx >= 0) {
		var _sk = _stat.skills[_bidx];
		return { idx: _bidx, score_ord: _sk.score_ordinary, score_good: _sk.score_good, score_amz: _sk.score_amazing,
		         use_type: "Broad (+1)", penalty: 1, skill_name: _broad_name };
	}

	// Untrained - use ability/2 (look up ability from keyword tree)
	var _ability = "dex";
	if (global.keyword_tree.broads[$ _broad_name] != undefined)
		_ability = global.keyword_tree.broads[$ _broad_name].ability;
	var _usc = get_ability_score_for_skill(_stat, _ability) div 2;
	return { idx: -1, score_ord: _usc, score_good: _usc div 2, score_amz: _usc div 4,
	         use_type: "Untrained (+1)", penalty: 1, skill_name: _broad_name + " (untrained)" };
}

// ============================================================
// PORTRAIT SYSTEM
// ============================================================
// Naming convention: portraits/{species}_{profession}.png
// Diplomat dual: portraits/{species}_diplomat_{secondary}.png
// Custom override: stored in hero.portrait_path

/// @function get_portrait_filename(statblock)
/// @description Returns the expected default portrait filename for this character
function get_portrait_filename(_stat) {
	var _sp = "human";
	if (_stat[$ "species"] != undefined)
		_sp = string_lower(string_replace(get_species_name(_stat.species), "'", ""));

	var _prof = string_lower(string_replace(get_profession_name(_stat.profession), " ", "_"));

	// Diplomat dual-class: include secondary
	if (_stat.profession == PROFESSION.DIPLOMAT
	 && (_stat[$ "secondary_profession"] ?? -1) >= 0) {
		var _sec = string_lower(string_replace(get_profession_name(_stat.secondary_profession), " ", "_"));
		return "portraits/" + _sp + "_diplomat_" + _sec + ".png";
	}

	return "portraits/" + _sp + "_" + _prof + ".png";
}

// try_load_sprite() REMOVED — inlined into load_portrait_for_hero

/// @function load_portrait_for_hero(statblock)
/// @description Loads the appropriate portrait sprite. Returns sprite ID or -1.
function load_portrait_for_hero(_stat) {
	// Free old portrait if any
	if (global.portrait_sprite != -1) {
		sprite_delete(global.portrait_sprite);
		global.portrait_sprite = -1;
	}
	global.portrait_path = "";

	// Check for player custom portrait first (saved as relative path in portraits/)
	if ((_stat[$ "portrait_path"] ?? "") != "" && file_exists(_stat.portrait_path)) {
		var _spr = sprite_add(_stat.portrait_path, 0, false, false, 0, 0);
		if (_spr != -1) {
			global.portrait_sprite = _spr;
			global.portrait_path = _stat.portrait_path;
			return _spr;
		}
	}

	// Try default portrait based on species + profession
	var _fname = get_portrait_filename(_stat);
	if (_fname != "" && file_exists(_fname)) {
		var _spr = sprite_add(_fname, 0, false, false, 0, 0);
		if (_spr != -1) {
			global.portrait_sprite = _spr;
			global.portrait_path = _fname;
			return _spr;
		}
	}

	return -1;
}

/// @function load_custom_portrait_dialog(statblock)
/// @description Opens file dialog, copies image to portraits/ dir, saves relative path
function load_custom_portrait_dialog(_stat) {
	var _path = get_open_filename("Image|*.png;*.jpg;*.bmp", "");
	if (_path == "") return false;

	if (global.portrait_sprite != -1) {
		sprite_delete(global.portrait_sprite);
		global.portrait_sprite = -1;
	}

	// Load the sprite from the absolute path first
	var _spr = sprite_add(_path, 0, false, false, 0, 0);
	if (_spr == -1) return false;

	// Generate a local filename based on character name
	var _safe_name = sanitize_hero_filename(_stat.name);
	var _ext = filename_ext(_path);
	if (_ext == "") _ext = ".png";
	var _local_path = "portraits/" + _safe_name + _ext;

	// Save the sprite to the local portraits directory so it persists
	if (!directory_exists("portraits")) directory_create("portraits");
	sprite_save(_spr, 0, _local_path);

	global.portrait_sprite = _spr;
	global.portrait_path = _local_path;
	_stat.portrait_path = _local_path;
	return true;
}

/// @function draw_portrait(x, y, w, h, border_color)
/// @description Draws the portrait (or placeholder) scaled to fit the given area
function draw_portrait(_x, _y, _w, _h, _border_color) {
	// Background
	draw_set_colour(#111122);
	draw_rectangle(_x, _y, _x + _w, _y + _h, false);

	if (global.portrait_sprite != -1) {
		// Scale to fit
		var _sw = sprite_get_width(global.portrait_sprite);
		var _sh = sprite_get_height(global.portrait_sprite);
		var _scale = min(_w / _sw, _h / _sh);
		var _dx = _x + (_w - _sw * _scale) / 2;
		var _dy = _y + (_h - _sh * _scale) / 2;
		draw_sprite_ext(global.portrait_sprite, 0, _dx, _dy, _scale, _scale, 0, c_white, 1.0);
	} else {
		// Placeholder: colored silhouette with text
		draw_set_colour(#222244);
		draw_rectangle(_x + 4, _y + 4, _x + _w - 4, _y + _h - 4, false);

		// Silhouette shape (simple head + shoulders)
		draw_set_colour(#334466);
		var _cx = _x + _w / 2;
		var _cy2 = _y + _h * 0.4;
		draw_circle(_cx, _cy2, _w * 0.18, false); // head
		draw_ellipse(_cx - _w * 0.3, _y + _h * 0.55, _cx + _w * 0.3, _y + _h - 8, false); // shoulders

		// Label
		draw_set_colour(#888888);
		draw_set_halign(fa_center);
		draw_text(_cx, _y + _h - 22, "Click to set portrait");
		draw_set_halign(fa_left);
	}

	// Border
	draw_set_colour(_border_color);
	draw_rectangle(_x, _y, _x + _w, _y + _h, true);
}

/// @function scan_portrait_directory()
/// @description Scans portraits/ folder for existing preset images, returns array of {name, path}
function scan_portrait_directory() {
	var _results = [];
	var _sp = ["human","fraal","weren","sesheyan","tsa","mechalus"];
	var _pr = ["combat_spec","diplomat","free_agent","tech_op","mindwalker"];
	// Check all species x profession combos + diplomat duals
	for (var _s = 0; _s < 6; _s++) {
		for (var _p = 0; _p < 5; _p++) {
			var _path = "portraits/" + _sp[_s] + "_" + _pr[_p] + ".png";
			if (file_exists(_path)) {
				var _display = string_replace_all(_sp[_s] + " " + _pr[_p], "_", " ");
				// Title case
				var _out = ""; var _cap = true;
				for (var _c = 1; _c <= string_length(_display); _c++) {
					var _ch = string_char_at(_display, _c);
					if (_cap) { _ch = string_upper(_ch); _cap = false; }
					if (_ch == " ") _cap = true;
					_out += _ch;
				}
				array_push(_results, { name: _out, path: _path });
			}
			// Diplomat dual variants
			if (_pr[_p] != "diplomat") {
				var _dpath = "portraits/" + _sp[_s] + "_diplomat_" + _pr[_p] + ".png";
				if (file_exists(_dpath)) array_push(_results, { name: "Diplomat " + _pr[_p], path: _dpath });
			}
		}
	}
	return _results;
}

/// @function draw_glow(x, y, radius, color, layers)
/// @description Draws a layered glow effect using concentric transparent circles
function draw_glow(_x, _y, _r, _col, _layers) {
	for (var _i = _layers; _i >= 0; _i--) {
		draw_set_alpha(0.03 * (1 - _i/_layers));
		draw_set_colour(_col);
		draw_circle(_x, _y, _r * (0.3 + 0.7 * _i/_layers), false);
	}
	draw_set_alpha(1.0);
}

/// @function draw_particles(x, y, w, h, count, color, size_min, size_max)
/// @description Scatter particles for atmosphere (fog, sparks, dust)
function draw_particles(_x, _y, _w, _h, _count, _col, _smin, _smax) {
	draw_set_colour(_col);
	for (var _i = 0; _i < _count; _i++) {
		var _px = _x + irandom(_w);
		var _py = _y + irandom(_h);
		var _s = irandom_range(_smin * 10, _smax * 10) / 10;
		draw_set_alpha(irandom_range(5, 40) / 100);
		draw_circle(_px, _py, _s, false);
	}
	draw_set_alpha(1.0);
}

/// @function draw_energy_lines(cx, cy, count, min_r, max_r, color)
/// @description Draw crackling energy lines radiating outward
function draw_energy_lines(_cx, _cy, _count, _rmin, _rmax, _col) {
	draw_set_colour(_col);
	for (var _i = 0; _i < _count; _i++) {
		var _ang = irandom(360);
		var _r1 = irandom_range(_rmin, _rmax);
		draw_set_alpha(irandom_range(15, 60) / 100);
		var _segments = irandom_range(3, 6);
		var _lx = _cx; var _ly = _cy;
		for (var _s = 0; _s < _segments; _s++) {
			var _nx = _lx + lengthdir_x(_r1/_segments, _ang + irandom_range(-30, 30));
			var _ny = _ly + lengthdir_y(_r1/_segments, _ang + irandom_range(-30, 30));
			draw_line_width(_lx, _ly, _nx, _ny, irandom_range(1, 2));
			_lx = _nx; _ly = _ny;
		}
	}
	draw_set_alpha(1.0);
}

/// @function draw_armor_plates(x, y, w, h, color, highlight)
/// @description Draw layered armor plating with edge highlights
function draw_armor_plates(_x, _y, _w, _h, _col, _hi) {
	var _plates = irandom_range(4, 7);
	for (var _i = 0; _i < _plates; _i++) {
		var _px = _x + irandom(_w * 0.6);
		var _py = _y + irandom(_h * 0.6);
		var _pw = irandom_range(15, 40);
		var _ph2 = irandom_range(8, 20);
		draw_set_colour(_col); draw_set_alpha(0.6);
		draw_rectangle(_px, _py, _px+_pw, _py+_ph2, false);
		draw_set_colour(_hi); draw_set_alpha(0.3);
		draw_line_width(_px, _py, _px+_pw, _py, 1); // top edge highlight
		draw_line_width(_px, _py, _px, _py+_ph2, 1); // left edge
	}
	draw_set_alpha(1.0);
}

/// @function draw_weapon_silhouette(cx, cy, type, color)
/// @description Draw a weapon silhouette from line segments. type: 0=rifle, 1=pistol, 2=blade, 3=fist, 4=psi
function draw_weapon_silhouette(_cx, _cy, _type, _col) {
	draw_set_colour(_col); draw_set_alpha(0.5);
	switch (_type) {
		case 0: // Rifle — long barrel + stock
			draw_line_width(_cx-40, _cy, _cx+40, _cy, 3);
			draw_line_width(_cx+30, _cy, _cx+40, _cy-8, 2);
			draw_line_width(_cx-20, _cy, _cx-30, _cy+10, 2);
			draw_rectangle(_cx-10, _cy-4, _cx+5, _cy+4, false);
			draw_line_width(_cx, _cy+4, _cx-5, _cy+12, 2); // trigger guard
			break;
		case 1: // Pistol — compact
			draw_line_width(_cx-15, _cy, _cx+15, _cy, 3);
			draw_line_width(_cx+10, _cy, _cx+15, _cy-5, 2);
			draw_line_width(_cx-5, _cy, _cx-8, _cy+14, 2);
			draw_line_width(_cx-8, _cy+14, _cx+2, _cy+14, 2);
			break;
		case 2: // Blade — sweeping curved line
			for (var _bl = 0; _bl < 30; _bl++) {
				var _t = _bl / 30;
				var _bx = _cx - 30 + _t * 60;
				var _by = _cy + sin(_t * pi) * -20;
				draw_circle(_bx, _by, 1.5 - _t, false);
			}
			draw_line_width(_cx-30, _cy, _cx-30, _cy+12, 2); // handle
			break;
		case 3: // Fist — knuckles
			draw_circle(_cx, _cy, 12, false);
			for (var _k = 0; _k < 4; _k++) {
				draw_circle(_cx - 9 + _k * 6, _cy - 10, 3, false);
			}
			break;
		case 4: // Psi orb — concentric rings
			for (var _pr = 0; _pr < 4; _pr++) {
				draw_set_alpha(0.3 - _pr * 0.06);
				draw_circle(_cx, _cy, 8 + _pr * 6, true);
			}
			break;
	}
	draw_set_alpha(1.0);
}

/// @function _save_surface_as_sprite(surface, width, height, path)
/// @description Captures a surface to a sprite, saves to disk, and cleans up.
function _save_surface_as_sprite(_surf, _pw, _ph, _path) {
	surface_reset_target();
	var _spr = sprite_create_from_surface(_surf, 0, 0, _pw, _ph, false, false, 0, 0);
	sprite_save(_spr, 0, _path);
	sprite_delete(_spr);
	surface_free(_surf);
}

/// @function _draw_profession_icon(px, py, profession_index, icon_color)
/// @description Draws a small profession icon glyph at given position.
function _draw_profession_icon(_px, _py, _p, _col) {
	draw_set_colour(#000000); draw_set_alpha(0.6); draw_circle(_px, _py, 20, false); draw_set_alpha(1.0);
	for (var _gl = 3; _gl >= 0; _gl--) { draw_set_alpha(0.04*(3-_gl)); draw_set_colour(_col); draw_circle(_px, _py, 14+_gl*3, false); }
	draw_set_alpha(0.9); draw_set_colour(_col);
	switch (_p) {
		case 0: draw_circle(_px,_py,12,true); draw_line_width(_px,_py-14,_px,_py+14,1.5); draw_line_width(_px-14,_py,_px+14,_py,1.5); break;
		case 1: for(var _st=0;_st<5;_st++){var _ang=_st*72-90;draw_line_width(_px,_py,_px+lengthdir_x(12,_ang),_py+lengthdir_y(12,_ang),2);}break;
		case 2: draw_ellipse(_px-14,_py-8,_px+14,_py+8,true);draw_circle(_px,_py,4,false);break;
		case 3: draw_circle(_px,_py,9,true);draw_circle(_px,_py,4,false);for(var _gt=0;_gt<6;_gt++){var _ga=_gt*60;draw_line_width(_px+lengthdir_x(9,_ga),_py+lengthdir_y(9,_ga),_px+lengthdir_x(13,_ga),_py+lengthdir_y(13,_ga),2.5);}break;
		case 4: for(var _wv=0;_wv<3;_wv++)draw_circle(_px,_py,5+_wv*5,true);draw_circle(_px,_py,2,false);break;
	}
	draw_set_alpha(1.0);
}

/// @function generate_all_coded_portraits()
/// @description Generates 54 epic sci-fi portrait images using layered draw effects.
function generate_all_coded_portraits() {
	if (!directory_exists("portraits")) directory_create("portraits");

	var _sp_names = ["human","fraal","weren","sesheyan","tsa","mechalus"];
	var _pr_names = ["combat_spec","diplomat","free_agent","tech_op","mindwalker"];
	var _pr_colors = [
		[200, 30, 30],   // Combat Spec: deep crimson
		[30, 60, 200],   // Diplomat: royal blue
		[20, 180, 60],   // Free Agent: emerald
		[220, 170, 20],  // Tech Op: gold
		[160, 30, 220]   // Mindwalker: deep violet
	];
	// Weapon silhouette per profession: 0=rifle, 1=pistol, 2=blade, 3=fist, 4=psi
	var _pr_weapons = [0, 1, 2, 1, 4];
	// Glow colors per species
	var _sp_glow = [
		make_colour_rgb(200, 200, 255),  // Human: cool white
		make_colour_rgb(180, 200, 255),  // Fraal: pale blue psionic
		make_colour_rgb(255, 160, 80),   // Weren: amber/fire
		make_colour_rgb(255, 200, 50),   // Sesheyan: gold (eyes)
		make_colour_rgb(80, 255, 120),   // T'sa: electric green
		make_colour_rgb(0, 255, 220)     // Mechalus: cyan data
	];
	var _pw = 180; var _ph = 220;

	for (var _s = 0; _s < 6; _s++) {
		for (var _p = 0; _p < 5; _p++) {
			var _path = "portraits/" + _sp_names[_s] + "_" + _pr_names[_p] + ".png";
			if (file_exists(_path)) continue;

			var _surf = surface_create(_pw, _ph);
			surface_set_target(_surf);
			draw_clear_alpha(c_black, 0);

			var _cr = _pr_colors[_p][0]; var _cg = _pr_colors[_p][1]; var _cb = _pr_colors[_p][2];
			var _cx = _pw/2; var _cy = _ph * 0.38;

			// === LAYER 1: Deep background gradient ===
			for (var _gy = 0; _gy < _ph; _gy++) {
				var _t = _gy / _ph;
				draw_set_colour(make_colour_rgb(floor(_cr*0.08+_t*_cr*0.15), floor(_cg*0.08+_t*_cg*0.15), floor(_cb*0.08+_t*_cb*0.15)));
				draw_line(0, _gy, _pw, _gy);
			}

			// === LAYER 2: Atmospheric particles (smoke/dust/sparks) ===
			draw_particles(0, 0, _pw, _ph, 80, make_colour_rgb(min(255,_cr+60),min(255,_cg+60),min(255,_cb+60)), 1, 3);
			// Profession-colored hot particles near center
			draw_particles(_cx-40, _cy-30, 80, 80, 30, make_colour_rgb(min(255,_cr+120),min(255,_cg+120),min(255,_cb+120)), 0.5, 1.5);

			// === LAYER 3: Background energy effect ===
			if (_p == 4) { // Mindwalker: psionic field
				draw_glow(_cx, _cy, 70, make_colour_rgb(120, 40, 200), 20);
				draw_energy_lines(_cx, _cy, 15, 20, 60, make_colour_rgb(200, 100, 255));
			} else if (_p == 0) { // Combat: explosion/impact
				draw_glow(_cx, _cy+20, 50, make_colour_rgb(200, 60, 20), 15);
				draw_particles(_cx-30, _cy+10, 60, 40, 40, make_colour_rgb(255, 200, 50), 0.5, 2);
			} else if (_p == 3) { // Tech: data streams
				draw_set_colour(make_colour_rgb(0, 200, 160));
				for (var _ds = 0; _ds < 12; _ds++) {
					var _dx = irandom(_pw); draw_set_alpha(irandom_range(10,30)/100);
					draw_line_width(_dx, 0, _dx+irandom_range(-20,20), _ph, 1);
				}
				draw_set_alpha(1.0);
			}

			// === LAYER 4: Species silhouette (detailed) ===
			var _sc = make_colour_rgb(min(255,_cr+50), min(255,_cg+50), min(255,_cb+50));
			var _hi = make_colour_rgb(min(255,_cr+120), min(255,_cg+120), min(255,_cb+120));
			draw_set_colour(_sc);

			switch (_s) {
				case 0: // Human — helmeted soldier
					// Neck
					draw_set_colour(merge_colour(_sc, #000000, 0.3));
					draw_roundrect(_cx-10, _cy+14, _cx+10, _cy+30, false);
					// Shoulders with armor plates
					draw_set_colour(_sc);
					draw_roundrect(_cx-40, _cy+28, _cx+40, _cy+80, false);
					draw_armor_plates(_cx-38, _cy+30, 76, 48, merge_colour(_sc,#000000,0.2), _hi);
					// Head (helmet)
					draw_set_colour(merge_colour(_sc, #222222, 0.3));
					draw_circle(_cx, _cy-4, 26, false);
					draw_roundrect(_cx-28, _cy-20, _cx+28, _cy+10, false);
					// Visor (glowing)
					draw_glow(_cx, _cy-6, 20, _sp_glow[0], 8);
					draw_set_colour(make_colour_rgb(180, 200, 255));
					draw_rectangle(_cx-20, _cy-12, _cx+20, _cy-2, false);
					draw_set_colour(#ffffff); draw_set_alpha(0.4);
					draw_rectangle(_cx-18, _cy-11, _cx-4, _cy-6, false); // visor reflection
					draw_set_alpha(1.0);
					break;

				case 1: // Fraal — ethereal psionic being
					// Thin body
					draw_set_colour(merge_colour(_sc, make_colour_rgb(100,120,200), 0.3));
					draw_roundrect(_cx-10, _cy+10, _cx+10, _cy+65, false);
					// Tall skull
					draw_ellipse(_cx-16, _cy-48, _cx+16, _cy+8, false);
					// Enormous eyes (glowing)
					draw_glow(_cx-9, _cy-20, 12, make_colour_rgb(150,180,255), 10);
					draw_glow(_cx+9, _cy-20, 12, make_colour_rgb(150,180,255), 10);
					draw_set_colour(make_colour_rgb(200, 220, 255));
					draw_circle(_cx-9, _cy-20, 7, false);
					draw_circle(_cx+9, _cy-20, 7, false);
					draw_set_colour(#ffffff);
					draw_circle(_cx-9, _cy-20, 3, false);
					draw_circle(_cx+9, _cy-20, 3, false);
					// Psi aura
					draw_energy_lines(_cx, _cy-20, 8, 20, 45, make_colour_rgb(140, 160, 255));
					break;

				case 2: // Weren — hulking beast warrior
					// Massive torso
					draw_set_colour(merge_colour(_sc, #332211, 0.2));
					draw_roundrect(_cx-48, _cy+15, _cx+48, _cy+85, false);
					draw_armor_plates(_cx-45, _cy+18, 90, 60, merge_colour(_sc,#000000,0.3), _hi);
					// Thick neck
					draw_roundrect(_cx-18, _cy+5, _cx+18, _cy+25, false);
					// Head — broad, bestial
					draw_set_colour(_sc);
					draw_circle(_cx, _cy-8, 30, false);
					// Brow ridge
					draw_set_colour(merge_colour(_sc, #000000, 0.4));
					draw_roundrect(_cx-28, _cy-22, _cx+28, _cy-10, false);
					// Eyes (fierce amber glow)
					draw_glow(_cx-12, _cy-12, 8, _sp_glow[2], 8);
					draw_glow(_cx+12, _cy-12, 8, _sp_glow[2], 8);
					draw_set_colour(make_colour_rgb(255, 180, 50));
					draw_circle(_cx-12, _cy-12, 4, false);
					draw_circle(_cx+12, _cy-12, 4, false);
					// Fangs
					draw_set_colour(#eeeeee);
					draw_triangle(_cx-8, _cy+5, _cx-4, _cy+16, _cx-12, _cy+14, false);
					draw_triangle(_cx+8, _cy+5, _cx+4, _cy+16, _cx+12, _cy+14, false);
					// Battle scars
					draw_set_colour(make_colour_rgb(180, 60, 40)); draw_set_alpha(0.5);
					for (var _sc2 = 0; _sc2 < 3; _sc2++) draw_line_width(_cx+18+_sc2*7, _cy+25, _cx+22+_sc2*7, _cy+65, 2);
					draw_set_alpha(1.0);
					break;

				case 3: // Sesheyan — winged nightstalker
					// Body
					draw_set_colour(merge_colour(_sc, #1a1a2e, 0.3));
					draw_roundrect(_cx-16, _cy+5, _cx+16, _cy+60, false);
					// Wings — massive, layered feathers
					draw_set_colour(merge_colour(_sc, #000000, 0.2));
					for (var _wl = 0; _wl < 5; _wl++) {
						var _wa = -40 - _wl * 12;
						draw_triangle(_cx, _cy+10, _cx+lengthdir_x(55+_wl*5,_wa), _cy+lengthdir_y(55+_wl*5,_wa), _cx+lengthdir_x(40+_wl*5,_wa-20), _cy+lengthdir_y(40+_wl*5,_wa-20), false);
						draw_triangle(_cx, _cy+10, _cx+lengthdir_x(55+_wl*5,180-_wa), _cy+lengthdir_y(55+_wl*5,180-_wa), _cx+lengthdir_x(40+_wl*5,200-_wa), _cy+lengthdir_y(40+_wl*5,200-_wa), false);
					}
					// Head
					draw_set_colour(_sc);
					draw_circle(_cx, _cy-8, 18, false);
					// Six eyes (three rows of two, glowing amber)
					for (var _ey = 0; _ey < 3; _ey++) {
						var _er = 4 - _ey;
						draw_glow(_cx-7, _cy-16+_ey*8, _er+3, _sp_glow[3], 6);
						draw_glow(_cx+7, _cy-16+_ey*8, _er+3, _sp_glow[3], 6);
						draw_set_colour(make_colour_rgb(255, 210, 60));
						draw_circle(_cx-7, _cy-16+_ey*8, _er, false);
						draw_circle(_cx+7, _cy-16+_ey*8, _er, false);
					}
					break;

				case 4: // T'sa — sleek reptilian speedster
					// Lithe body
					draw_set_colour(merge_colour(_sc, make_colour_rgb(40,80,40), 0.2));
					draw_roundrect(_cx-14, _cy+6, _cx+14, _cy+55, false);
					// Angular head — sharp, predatory
					draw_set_colour(_sc);
					draw_triangle(_cx, _cy-35, _cx-20, _cy+5, _cx+20, _cy+5, false);
					// Crest/fin
					draw_set_colour(_hi);
					draw_triangle(_cx, _cy-40, _cx-3, _cy-25, _cx+3, _cy-25, false);
					// Eyes (bright electric green, slitted)
					draw_glow(_cx-8, _cy-16, 8, _sp_glow[4], 8);
					draw_glow(_cx+8, _cy-16, 8, _sp_glow[4], 8);
					draw_set_colour(make_colour_rgb(50, 255, 100));
					draw_circle(_cx-8, _cy-16, 4, false);
					draw_circle(_cx+8, _cy-16, 4, false);
					draw_set_colour(#000000);
					draw_line_width(_cx-8, _cy-20, _cx-8, _cy-12, 1.5);
					draw_line_width(_cx+8, _cy-20, _cx+8, _cy-12, 1.5);
					// Speed lines
					draw_set_colour(make_colour_rgb(150, 255, 180)); draw_set_alpha(0.3);
					for (var _sl = 0; _sl < 8; _sl++) {
						var _sy = _cy - 20 + _sl * 10;
						draw_line_width(_cx+22, _sy, _cx+45+irandom(15), _sy, 1);
					}
					draw_set_alpha(1.0);
					break;

				case 5: // Mechalus — cybernetic organism
					// Body frame
					draw_set_colour(merge_colour(_sc, #222233, 0.3));
					draw_roundrect(_cx-32, _cy+16, _cx+32, _cy+70, false);
					draw_armor_plates(_cx-30, _cy+18, 60, 50, merge_colour(_sc,#111122,0.3), make_colour_rgb(0,200,180));
					// Head
					draw_set_colour(_sc);
					draw_circle(_cx, _cy-6, 24, false);
					// Circuit traces (glowing cyan)
					draw_set_colour(make_colour_rgb(0, 255, 220)); draw_set_alpha(0.7);
					draw_line_width(_cx-24, _cy-18, _cx-24, _cy+8, 1.5);
					draw_line_width(_cx-24, _cy+8, _cx-12, _cy+8, 1.5);
					draw_line_width(_cx-12, _cy+8, _cx-12, _cy+16, 1.5);
					draw_line_width(_cx+24, _cy-18, _cx+24, _cy+8, 1.5);
					draw_line_width(_cx+24, _cy+8, _cx+12, _cy+8, 1.5);
					draw_line_width(_cx+12, _cy+8, _cx+12, _cy+16, 1.5);
					// Horizontal traces across body
					for (var _ct = 0; _ct < 4; _ct++) {
						draw_line_width(_cx-28, _cy+24+_ct*10, _cx+28, _cy+24+_ct*10, 0.5);
					}
					draw_set_alpha(1.0);
					// Data node glow
					for (var _dn = 0; _dn < 6; _dn++) {
						draw_glow(_cx-20+_dn*8, _cy+25+(_dn%2)*15, 4, make_colour_rgb(0,255,200), 5);
					}
					// Visor (wide, glowing)
					draw_glow(_cx, _cy-8, 18, _sp_glow[5], 10);
					draw_set_colour(make_colour_rgb(0, 220, 255));
					draw_rectangle(_cx-18, _cy-14, _cx+18, _cy-4, false);
					draw_set_colour(make_colour_rgb(100, 255, 255)); draw_set_alpha(0.5);
					draw_rectangle(_cx-16, _cy-13, _cx-2, _cy-8, false);
					draw_set_alpha(1.0);
					break;
			}

			// === LAYER 5: Weapon silhouette (profession-specific) ===
			draw_weapon_silhouette(_cx, _cy + 60, _pr_weapons[_p], _hi);

			// === LAYER 6: Profession icon (bottom right) ===
			_draw_profession_icon(_pw-26, _ph-26, _p, make_colour_rgb(min(255,_cr+100), min(255,_cg+100), min(255,_cb+100)));

			// === LAYER 7: Top glow highlight ===
			draw_glow(_cx, 10, 40, _sp_glow[_s], 12);

			// === LAYER 8: Border with inner glow ===
			draw_set_colour(make_colour_rgb(min(255,_cr+40), min(255,_cg+40), min(255,_cb+40)));
			draw_rectangle(0, 0, _pw-1, _ph-1, true);
			draw_set_colour(make_colour_rgb(min(255,_cr+80), min(255,_cg+80), min(255,_cb+80))); draw_set_alpha(0.3);
			draw_rectangle(1, 1, _pw-2, _ph-2, true);
			draw_set_alpha(1.0);

			_save_surface_as_sprite(_surf, _pw, _ph, _path);
		}

		// Diplomat dual-class — same epic species art but split color border
		for (var _p2 = 0; _p2 < 5; _p2++) {
			if (_pr_names[_p2] == "diplomat") continue;
			var _path = "portraits/" + _sp_names[_s] + "_diplomat_" + _pr_names[_p2] + ".png";
			if (file_exists(_path)) continue;

			var _surf = surface_create(_pw, _ph);
			surface_set_target(_surf);
			draw_clear_alpha(c_black, 0);

			// Blended background
			var _cr2 = _pr_colors[_p2][0]; var _cg2 = _pr_colors[_p2][1]; var _cb2 = _pr_colors[_p2][2];
			for (var _gy = 0; _gy < _ph; _gy++) {
				var _t = _gy / _ph;
				var _r = floor(lerp(30*0.12, _cr2*0.18, _t)); var _g = floor(lerp(60*0.12, _cg2*0.18, _t)); var _b = floor(lerp(200*0.12, _cb2*0.18, _t));
				draw_set_colour(make_colour_rgb(_r, _g, _b));
				draw_line(0, _gy, _pw, _gy);
			}
			draw_particles(0, 0, _pw, _ph, 60, make_colour_rgb(100,100,200), 1, 2);

			// Silhouette (simplified but glowing)
			var _cx2 = _pw/2; var _cy2 = _ph * 0.38;
			draw_glow(_cx2, _cy2, 50, merge_colour(make_colour_rgb(60,80,200), make_colour_rgb(_cr2,_cg2,_cb2), 0.5), 15);
			draw_set_colour(make_colour_rgb(140, 150, 200));
			draw_circle(_cx2, _cy2-8, 24, false);
			draw_roundrect(_cx2-34, _cy2+18, _cx2+34, _cy2+70, false);
			draw_armor_plates(_cx2-30, _cy2+20, 60, 45, make_colour_rgb(80,90,140), make_colour_rgb(120,140,220));

			// Dual icons (diplomat star left, secondary icon right)
			_draw_profession_icon(24, _ph-26, 1, make_colour_rgb(80,120,220));
			_draw_profession_icon(_pw-26, _ph-26, _p2, make_colour_rgb(min(255,_cr2+80),min(255,_cg2+80),min(255,_cb2+80)));

			// Split border
			draw_set_colour(make_colour_rgb(50,80,200)); draw_rectangle(0,0,_pw/2,_ph-1,true);
			draw_set_colour(make_colour_rgb(min(255,_cr2+50),min(255,_cg2+50),min(255,_cb2+50))); draw_rectangle(_pw/2,0,_pw-1,_ph-1,true);

			_save_surface_as_sprite(_surf, _pw, _ph, _path);
		}
	}
}


/// @function draw_inspect_highlight(x, y, w, h, active)
/// @description Draws a filled+outlined inspect highlight box if active.
function draw_inspect_highlight(_x, _y, _w, _h, _active) {
	if (!_active) return;
	draw_set_colour(merge_colour(c_panel, c_highlight, 0.15));
	draw_rectangle(_x, _y, _x+_w, _y+_h, false);
	draw_set_colour(c_highlight);
	draw_rectangle(_x, _y, _x+_w, _y+_h, true);
}

/// @function ui_btn(key, x1, y1, x2, y2, text, base_color, hover_color)
/// @description THE meta button function. Registers click rect + draws the button in one call.
///   Returns true if hovering (for inline hover effects).
function ui_btn(_key, _x1, _y1, _x2, _y2, _text, _base_color, _hover_color) {
	// Register click rect
	obj_game.btn[$ _key] = [_x1, _y1, _x2, _y2];
	// Draw
	var _hov = point_in_rectangle(device_mouse_x_to_gui(0), device_mouse_y_to_gui(0), _x1, _y1, _x2, _y2);
	draw_set_colour(_hov ? _hover_color : _base_color);
	draw_rectangle(_x1, _y1, _x2, _y2, false);
	draw_set_colour(#ffffff);
	draw_set_halign(fa_center);
	draw_text((_x1 + _x2) div 2, _y1 + (_y2 - _y1) div 2 - 6, _text);
	draw_set_halign(fa_left);
	return _hov;
}

/// @function mouse_in(x1, y1, x2, y2)
/// @description Returns true if mouse GUI position is inside the rectangle
function mouse_in(_x1, _y1, _x2, _y2) {
	return point_in_rectangle(device_mouse_x_to_gui(0), device_mouse_y_to_gui(0), _x1, _y1, _x2, _y2);
}

/// @function draw_circuit_border(x, y, w, h, col)
/// @description Draws a sci-fi circuit-trace border with notches on top and bottom edges.
function draw_circuit_border(_x, _y, _w, _h, _col) {
	draw_set_colour(_col);
	// Top edge with notches, right, bottom with notch, left — as connected path
	var _pts = [
		_x,_y, _x+_w*0.3,_y, _x+_w*0.3,_y-4, _x+_w*0.35,_y-4, _x+_w*0.35,_y,
		_x+_w*0.65,_y, _x+_w*0.65,_y-4, _x+_w*0.7,_y-4, _x+_w*0.7,_y, _x+_w,_y,
		_x+_w,_y+_h, _x+_w*0.6,_y+_h, _x+_w*0.6,_y+_h+4, _x+_w*0.55,_y+_h+4,
		_x+_w*0.55,_y+_h, _x,_y+_h, _x,_y
	];
	for (var _i = 0; _i < array_length(_pts) - 2; _i += 2)
		draw_line(_pts[_i], _pts[_i+1], _pts[_i+2], _pts[_i+3]);
}

// ============================================================
// PARTY MANAGEMENT (GM Mode)
// ============================================================

/// @function add_to_party(statblock)
/// @description Adds a character statblock to the global party array (dedupes by name)
function add_to_party(_stat) {
	for (var _i = 0; _i < array_length(global.party); _i++)
		if (global.party[_i].name == _stat.name) { global.party[_i] = _stat; return; }
	array_push(global.party, _stat);
}

/// @function remove_from_party(index)
/// @description Removes a character from the party by index
function remove_from_party(_partyArrayIndex) {
	if (_partyArrayIndex >= 0 && _partyArrayIndex < array_length(global.party))
		array_delete(global.party, _partyArrayIndex, 1);
}

/// @function add_to_npcs(statblock, faction)
/// @description Adds a statblock to the NPC list with faction tag
function add_to_npcs(_statblock, _factionName) {
	_statblock.faction = _factionName;
	for (var _i = 0; _i < array_length(global.npcs); _i++)
		if (global.npcs[_i].name == _statblock.name) { global.npcs[_i] = _statblock; return; }
	array_push(global.npcs, _statblock);
}

/// @function remove_from_npcs(index)
/// @description Removes an NPC by index
function remove_from_npcs(_npcArrayIndex) {
	if (_npcArrayIndex >= 0 && _npcArrayIndex < array_length(global.npcs))
		array_delete(global.npcs, _npcArrayIndex, 1);
}

/// @function move_npc_to_party(index)
/// @description Moves an NPC to the party list
function move_npc_to_party(_npcArrayIndex) {
	if (_npcArrayIndex >= 0 && _npcArrayIndex < array_length(global.npcs)) {
		var _npcStatblock = global.npcs[_npcArrayIndex];
		array_delete(global.npcs, _npcArrayIndex, 1);
		add_to_party(_npcStatblock);
	}
}

/// @function move_party_to_npcs(index, faction)
/// @description Moves a party member to the NPC list
function move_party_to_npcs(_partyArrayIndex, _factionName) {
	if (_partyArrayIndex >= 0 && _partyArrayIndex < array_length(global.party)) {
		var _partyStatblock = global.party[_partyArrayIndex];
		array_delete(global.party, _partyArrayIndex, 1);
		add_to_npcs(_partyStatblock, _factionName);
	}
}

/// @function switch_active_character(index)
/// @description Switches the active hero to a party member by index
function switch_active_character(_partyArrayIndex) {
	if (_partyArrayIndex >= 0 && _partyArrayIndex < array_length(global.party)) {
		obj_game.hero = global.party[_partyArrayIndex];
		obj_game.party_selected = _partyArrayIndex;
		update_hero(obj_game.hero);
	}
}

/// @function get_npcs_by_faction(faction)
/// @description Returns array of {idx, stat} for NPCs in given faction
function get_npcs_by_faction(_factionName) {
	var _result = [];
	for (var _i = 0; _i < array_length(global.npcs); _i++) {
		var _npcFaction = global.npcs[_i][$ "faction"] ?? "Unaffiliated";
		if (_npcFaction == _factionName) array_push(_result, { idx: _i, stat: global.npcs[_i] });
	}
	return _result;
}

/// @function export_campaign_full()
/// @description Saves all party and NPC characters to disk, then saves campaign.json
function export_campaign_full() {
	// Save every party member
	for (var _i = 0; _i < array_length(global.party); _i++)
		save_hero_and_track(global.party[_i]);
	// Save every NPC
	for (var _i = 0; _i < array_length(global.npcs); _i++)
		save_hero_and_track(global.npcs[_i]);
	// Save campaign structure
	save_campaign();
}

/// @function _build_char_refs(list, include_faction)
/// @description Builds path reference array from a character list. For NPCs, includes faction.
function _build_char_refs(_list, _includeFaction) {
	var _out = [];
	for (var _i = 0; _i < array_length(_list); _i++) {
		var _safeName = sanitize_hero_filename(_list[_i].name);
		var _ref = { name: _list[_i].name, path: global.save_path + _safeName + ".json" };
		if (_includeFaction) _ref.faction = _list[_i][$ "faction"] ?? "Unaffiliated";
		array_push(_out, _ref);
	}
	return _out;
}

/// @function _load_chars_from_refs(refs, target_array, apply_faction)
/// @description Loads statblocks from path refs into target array. Optionally applies faction tag.
function _load_chars_from_refs(_refs, _applyFaction) {
	var _out = [];
	for (var _i = 0; _i < array_length(_refs); _i++) {
		var _statblock = load_character_from_path(_refs[_i].path);
		if (_statblock != undefined) {
			if (_applyFaction) _statblock.faction = _refs[_i][$ "faction"] ?? "Unaffiliated";
			array_push(_out, _statblock);
		}
	}
	return _out;
}

/// @function save_all_data_dialog()
/// @description Opens save dialog, writes campaign bundle to chosen file. Returns path or "".
function save_all_data_dialog() {
	var _path = get_save_filename("JSON|*.json", "");
	if (_path == "") return "";
	var _fileHandle = file_text_open_write(_path);
	file_text_write_string(_fileHandle, json_stringify({
		_format: "alternity_campaign_bundle", _version: 1,
		roster: global.roster, party: _build_char_refs(global.party, false),
		npcs: _build_char_refs(global.npcs, true), factions: global.factions
	}, true));
	file_text_close(_fileHandle);
	return _path;
}

/// @function load_all_data_dialog()
/// @description Opens load dialog, reads campaign bundle and applies to globals. Returns path or "".
function load_all_data_dialog() {
	var _path = get_open_filename("JSON|*.json", "");
	if (_path == "" || !file_exists(_path)) return "";
	var _contents = "";
	var _fileHandle = file_text_open_read(_path);
	while (!file_text_eof(_fileHandle)) _contents += file_text_readln(_fileHandle);
	file_text_close(_fileHandle);
	var _data = json_parse(_contents);
	if (_data[$ "_format"] != "alternity_campaign_bundle" && _data[$ "_format"] != "alternity_campaign") return "";
	global.roster = _data[$ "roster"] ?? [];
	global.factions = _data[$ "factions"] ?? ["Unaffiliated"];
	if (array_length(global.factions) == 0) global.factions = ["Unaffiliated"];
	global.party = _load_chars_from_refs(_data[$ "party"] ?? [], false);
	global.npcs = _load_chars_from_refs(_data[$ "npcs"] ?? [], true);
	return _path;
}

/// @function import_player_to_party(path)
/// @description Loads a character from file and adds to party. Returns true on success.
function import_player_to_party(_path) {
	var _stat = load_character_from_path(_path);
	if (_stat != undefined) {
		add_to_party(_stat);
		roster_add_ref(_stat.name, _path);
		return true;
	}
	return false;
}

/// @function import_to_npcs(path, faction)
/// @description Loads a character from file and adds to NPC list. Returns true on success.
function import_to_npcs(_filePath, _factionName) {
	var _loadedStatblock = load_character_from_path(_filePath);
	if (_loadedStatblock != undefined) {
		add_to_npcs(_loadedStatblock, _factionName);
		roster_add_ref(_loadedStatblock.name, _filePath);
		return true;
	}
	return false;
}
