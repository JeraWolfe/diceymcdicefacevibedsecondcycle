/// @description Character Generation, Species, and Career Access

enum SPECIES { HUMAN, FRAAL, WERENT, SESHEYAN, TSA, MECHALUS, COUNT }

function get_species_name(_sp) {
	if (_sp >= 0 && _sp < array_length(global.species_data)) return global.species_data[_sp].name;
	return "Unknown";
}
function get_profession_name(_prof) {
	switch (_prof) {
		case PROFESSION.COMBAT_SPEC: return "Combat Spec"; case PROFESSION.DIPLOMAT: return "Diplomat";
		case PROFESSION.FREE_AGENT: return "Free Agent"; case PROFESSION.TECH_OP: return "Tech Op";
		case PROFESSION.MINDWALKER: return "Mindwalker";
	} return "Unknown";
}
function parse_species_name(_name) {
	for (var _i = 0; _i < array_length(global.species_data); _i++) {
		if (string_lower(global.species_data[_i].name) == string_lower(_name)) return _i;
	} return 0;
}
function parse_profession_name(_name) {
	switch (string_lower(_name)) {
		case "combat spec": return 0; case "diplomat": return 1; case "free agent": return 2;
		case "tech op": return 3; case "mindwalker": return 4;
	} return 0;
}
function get_species_mods(_sp) {
	if (_sp >= 0 && _sp < array_length(global.species_data)) return global.species_data[_sp].mods;
	return [0,0,0,0,0,0];
}
function get_species_starting_broads(_sp) {
	if (_sp >= 0 && _sp < array_length(global.species_data)) return global.species_data[_sp].starting_broads;
	return [];
}

/// @function get_species_racial_fx(species_idx)
/// @description Returns array of fx_database entries with type=="racial" matching the species.
/// Used by grant_racial_traits() to auto-grant species traits to new characters.
function get_species_racial_fx(_species_idx) {
	var _name = string_lower(get_species_name(_species_idx));
	_name = string_replace_all(_name, "'", ""); // T'sa → tsa
	var _result = [];
	if (!variable_global_exists("fx_database")) return _result;
	for (var _i = 0; _i < array_length(global.fx_database); _i++) {
		var _fxd = global.fx_database[_i];
		if (_fxd.type != "racial") continue;
		if ((_fxd[$ "species"] ?? "") == _name) array_push(_result, _fxd);
	}
	return _result;
}

/// @function grant_racial_traits(stat)
/// @description Grants the species' racial trait FX entries to a character. Idempotent —
/// strips any existing racial entries first, so calling on regenerate or species change
/// is safe. Skipped silently if fx_database isn't loaded yet.
function grant_racial_traits(_stat) {
	if (_stat == undefined || _stat[$ "fx"] == undefined) return;
	// Strip stale racial entries first
	for (var _i = array_length(_stat.fx)-1; _i >= 0; _i--) {
		if (_stat.fx[_i].type == "racial") array_delete(_stat.fx, _i, 1);
	}
	var _traits = get_species_racial_fx(_stat.species);
	for (var _i = 0; _i < array_length(_traits); _i++) {
		var _t = _traits[_i];
		array_push(_stat.fx, {
			name: _t.name,
			type: "racial",
			quality: "",
			active: _t[$ "active"] ?? true
		});
	}
}
function get_profession_requirements(_prof) {
	if (_prof >= 0 && _prof < array_length(global.professions)) {
		var _p = global.professions[_prof];
		var _r = _p.requirements;
		return {
			ab1: ability_name_to_index(_r.primary),
			ab1_min: _r.primary_min,
			ab2: ability_name_to_index(_r.secondary),
			ab2_min: _r.secondary_min
		};
	}
	return { ab1:0, ab1_min:4, ab2:0, ab2_min:4 };
}
// roll_ability() REMOVED — never called (chargen uses weighted distribution, not 2d6+2)

// ============================================================
// CAREER ACCESS (from settings library)
// ============================================================

function get_careers_for_profession(_prof) {
	if (_prof >= 0 && _prof < array_length(global.career_data)) return global.career_data[_prof];
	return [];
}

function get_career_names_for_profession(_prof) {
	var _c = get_careers_for_profession(_prof);
	var _n = [];
	for (var _i = 0; _i < array_length(_c); _i++) array_push(_n, _c[_i].name);
	return _n;
}

/// @function estimate_career_skill_cost(prof, career)
/// @description Computes the rough total skill point cost of a career's starting
/// skills (broads + specialty ranks) under the PHB two-tier model. Used by chargen
/// to bias INT for skill-heavy career picks.
function estimate_career_skill_cost(_prof, _career) {
	if (_career == undefined) return 0;
	var _total = 0;
	// Broads — 3 if profession skill, 4 if not
	for (var _bi = 0; _bi < array_length(_career.broads); _bi++) {
		var _b = _career.broads[_bi];
		var _is_prof = (script_exists(asset_get_index("is_profession_skill"))) ? is_profession_skill(_prof, _b) : false;
		_total += _is_prof ? 3 : 4;
	}
	// Specialties — base 1 if profession, 2 if not. Total cost = sum (base, base+1, ... base+rank-1)
	for (var _si = 0; _si < array_length(_career.specs); _si++) {
		var _s = _career.specs[_si];
		var _broad = _s[0];
		var _rank = _s[2];
		var _is_prof2 = (script_exists(asset_get_index("is_profession_skill"))) ? is_profession_skill(_prof, _broad) : false;
		var _base = _is_prof2 ? 1 : 2;
		// rank 1 cost = base, rank 2 = base+(base+1), rank 3 = base+(base+1)+(base+2), etc.
		for (var _r = 0; _r < _rank; _r++) _total += (_base + _r);
	}
	return _total;
}

/// @function apply_career_to_statblock(statblock, career_data, additive)
/// @description Applies career skills & equipment. If additive=true, doesn't clear existing.
function apply_career_to_statblock(_stat, _career, _additive) {
	if (!_additive) {
		_stat.skills = [];
		_stat.weapons = [];
		_stat.gear = [];
	}

	// Add broad skills (skip if already owned)
	for (var _i = 0; _i < array_length(_career.broads); _i++) {
		if (find_skill(_stat, _career.broads[_i], "") < 0) {
			add_broad_skill_to_hero(_stat, _career.broads[_i]);
		}
	}

	// Add specialties
	for (var _i = 0; _i < array_length(_career.specs); _i++) {
		var _s = _career.specs[_i];
		if (find_skill(_stat, _s[0], _s[1]) < 0) {
			add_specialty_rank0(_stat, _s[0], _s[1]);
		}
		var _idx = find_skill(_stat, _s[0], _s[1]);
		if (_idx >= 0) {
			// Increase to target rank (if not already there)
			while (_stat.skills[_idx].rank < _s[2]) {
				increase_skill_rank(_stat, _idx);
			}
		}
	}

	// Weapons: [name, skill_keyword, dmg_o, dmg_g, dmg_a, range, type]
	for (var _i = 0; _i < array_length(_career.weapons); _i++) {
		var _w = _career.weapons[_i];
		add_weapon(_stat, _w[0], _w[1], _w[2], _w[3], _w[4], _w[5], _w[6]);
	}
	if (!_additive) add_weapon(_stat, "Unarmed", "brawl", "d4s", "d4+1s", "d4+2s", "Personal", DAMAGE_TYPE.LI);

	// Armor (only set if not additive, or if current is None)
	if (!_additive || _stat.armor.name == "None") {
		set_armor(_stat, _career.armor[0], _career.armor[1], _career.armor[2], _career.armor[3]);
	}

	// Gear
	for (var _i = 0; _i < array_length(_career.gear); _i++) {
		array_push(_stat.gear, _career.gear[_i]);
	}
}

// ============================================================
// CHARACTER GENERATION
// ============================================================

/// @function generate_random_character(species, prof, career, sec_prof, sec_career)
/// @description Full character generation. Pass -1 for random on any choice.
///   sec_prof/sec_career only used when prof=DIPLOMAT.
function generate_random_character(_species_choice, _prof_choice, _career_choice, _sec_prof_choice, _sec_career_choice) {
	var _species = (_species_choice < 0) ? irandom_range(0, SPECIES.COUNT-1) : _species_choice;
	var _prof = (_prof_choice < 0) ? irandom_range(0, 4) : _prof_choice;
	var _mods = get_species_mods(_species);
	var _reqs = get_profession_requirements(_prof);

	// Pre-determine Diplomat secondary profession for weight map and career application
	var _sec_prof = -1;
	if (_prof == PROFESSION.DIPLOMAT) {
		_sec_prof = _sec_prof_choice;
		if (_sec_prof < 0) {
			var _options = [PROFESSION.COMBAT_SPEC, PROFESSION.FREE_AGENT, PROFESSION.TECH_OP, PROFESSION.MINDWALKER];
			_sec_prof = _options[irandom(3)];
		}
	}

	// PICK CAREER FIRST (v0.61.0): the chosen career drives skill demand, which
	// determines how much INT we need to allocate. We can't make a legal character
	// if we distribute attributes without knowing what skills they'll need to afford.
	var _careers = get_careers_for_profession(_prof);
	var _career;
	if (_career_choice < 0 || _career_choice >= array_length(_careers))
		_career = _careers[irandom(array_length(_careers)-1)];
	else
		_career = _careers[_career_choice];

	// Estimate skill point demand for the chosen career(s)
	var _demand = estimate_career_skill_cost(_prof, _career);
	if (_prof == PROFESSION.DIPLOMAT && _sec_prof >= 0) {
		var _sec_careers_est = get_careers_for_profession(_sec_prof);
		if (array_length(_sec_careers_est) > 0) {
			var _sec_career_est;
			if (_sec_career_choice < 0 || _sec_career_choice >= array_length(_sec_careers_est))
				_sec_career_est = _sec_careers_est[0]; // estimate from first one
			else
				_sec_career_est = _sec_careers_est[_sec_career_choice];
			_demand += estimate_career_skill_cost(_sec_prof, _sec_career_est);
		}
	}

	var _base_pts = get_starting_skill_points(_prof);
	var _shortfall = max(0, _demand - _base_pts);
	// Each point of shortfall = +1 INT needed (since INT-9 grants +1 skill point)
	// Clamp to legal range [9, 14] — INT 9 is the floor (gives 0 bonus), 14 is the ceiling
	var _min_int = clamp(9 + _shortfall, 4, 14);

	// Distribute exactly 60 points across 6 abilities (PHB rule)
	// Apply species mods, respect min 4 / max 14 per ability, meet profession requirements
	var _scores = array_create(6, 0);
	var _pool = 60;

	// Start at minimums (4 each for humans, adjusted by species)
	for (var _a = 0; _a < 6; _a++) {
		_scores[_a] = clamp(4 + _mods[_a], 4, 14);
		_pool -= _scores[_a];
	}

	// HARD REQUIREMENT: primary profession minimums (PHB Table P1)
	// Character is illegal without these. Only primary profession matters.
	while (_scores[_reqs.ab1] < _reqs.ab1_min && _pool > 0) { _scores[_reqs.ab1]++; _pool--; }
	while (_scores[_reqs.ab2] < _reqs.ab2_min && _pool > 0) { _scores[_reqs.ab2]++; _pool--; }

	// v0.61.0: ENFORCE MIN INT for skill capacity. If career demand exceeds base
	// points, INT must be high enough to grant the bonus skill points.
	// (INT is index 3 in the [STR,DEX,CON,INT,WIL,PER] array.)
	while (_scores[3] < _min_int && _pool > 0) { _scores[3]++; _pool--; }

	// Build ability weight map for smart distribution
	// Higher weight = more likely to receive points
	var _weights = array_create(6, 1); // base: every stat gets weight 1
	_weights[_reqs.ab1] += 3; // primary profession's primary ability
	_weights[_reqs.ab2] += 2; // primary profession's secondary ability
	// Bias INT for skill-heavy careers (proportional to remaining shortfall)
	_weights[3] += ceil(_shortfall / 3);
	// Diplomat secondary profession: soft preference, NOT requirements
	if (_sec_prof >= 0) {
		var _sec_pref = get_profession_requirements(_sec_prof);
		_weights[_sec_pref.ab1] += 2; // secondary prof's primary (soft)
		_weights[_sec_pref.ab2] += 1; // secondary prof's secondary (mild)
	}

	// Weighted random distribution of remaining pool
	var _safety = 500;
	while (_pool > 0 && _safety > 0) {
		_safety--;
		// Sum weights of non-maxed abilities
		var _total_w = 0;
		for (var _a = 0; _a < 6; _a++) {
			if (_scores[_a] < 14) _total_w += _weights[_a];
		}
		if (_total_w <= 0) break;
		// Weighted random pick
		var _roll = irandom(_total_w - 1);
		var _cumul = 0;
		for (var _a = 0; _a < 6; _a++) {
			if (_scores[_a] >= 14) continue;
			_cumul += _weights[_a];
			if (_roll < _cumul) { _scores[_a]++; _pool--; break; }
		}
	}

	// If somehow pool still has points (all at 14), dump into lowest
	while (_pool > 0) {
		var _low = 0;
		for (var _a = 1; _a < 6; _a++) { if (_scores[_a] < _scores[_low]) _low = _a; }
		if (_scores[_low] >= 14) break;
		_scores[_low]++;
		_pool--;
	}

	// Create statblock
	var _stat = create_statblock("", _prof, _career.name);
	_stat.species = _species;

	set_ability(_stat, "str", _scores[0]); set_ability(_stat, "dex", _scores[1]);
	set_ability(_stat, "con", _scores[2]); set_ability(_stat, "int", _scores[3]);
	set_ability(_stat, "wil", _scores[4]); set_ability(_stat, "per", _scores[5]);
	calculate_action_check(_stat);
	calculate_durability(_stat);

	// ORDER MATTERS:
	// 1. Apply primary career FIRST (it wipes skills array when not additive)
	apply_career_to_statblock(_stat, _career, false);

	// 2. Apply species starting broad skills AFTER career (so career wipe doesn't destroy them)
	var _sp_broads = get_species_starting_broads(_species);
	for (var _i = 0; _i < array_length(_sp_broads); _i++) {
		if (find_skill(_stat, _sp_broads[_i], "") < 0) {
			add_broad_skill_to_hero(_stat, _sp_broads[_i]);
		}
	}

	// 3. Auto-grant racial trait FX entries (Wings for Sesheyan, Datalink for Mechalus, etc.)
	grant_racial_traits(_stat);

	// Diplomat dual-class: apply secondary career additively (_sec_prof pre-determined above for weight map)
	if (_prof == PROFESSION.DIPLOMAT) {
		_stat.secondary_profession = _sec_prof;

		var _sec_careers = get_careers_for_profession(_sec_prof);
		if (array_length(_sec_careers) > 0) {
			var _sec_career;
			if (_sec_career_choice < 0 || _sec_career_choice >= array_length(_sec_careers))
				_sec_career = _sec_careers[irandom(array_length(_sec_careers)-1)];
			else
				_sec_career = _sec_careers[_sec_career_choice];

			// Apply secondary career additively (keeps existing skills/gear)
			apply_career_to_statblock(_stat, _sec_career, true);
			_stat.career = _career.name + " / " + _sec_career.name;
		}
	}

	_stat.name = generate_random_name(_species);
	_stat.background = _stat.name + ". " + get_species_name(_species) + " " + get_profession_name(_prof) + ", " + _stat.career + ".\nNewly created character — background awaiting player input.";

	// v0.61.0: Post-generation legality check. If the character is over budget,
	// walk specs in reverse and demote the highest-rank one until legal. This is
	// a safety net — INT biasing should normally prevent this, but extreme combos
	// (Diplomat dual-class with two skill-heavy careers) can still overflow.
	if (script_exists(asset_get_index("is_chargen_legal"))) {
		var _safety = 100;
		while (!is_chargen_legal(_stat) && _safety > 0) {
			_safety--;
			// Find the highest-rank specialty and demote it
			var _hi_idx = -1; var _hi_rank = 0;
			for (var _ski = 0; _ski < array_length(_stat.skills); _ski++) {
				var _sk = _stat.skills[_ski];
				if (_sk.specialty != "" && _sk.rank > _hi_rank) {
					_hi_rank = _sk.rank;
					_hi_idx = _ski;
				}
			}
			if (_hi_idx < 0) break;
			decrease_skill_rank(_stat, _hi_idx);
		}
		if (_safety == 0) show_debug_message("[chargen] WARNING: legality auto-demote ran out of safety iterations for " + _stat.name);
	}

	return _stat;
}

/// @function generate_random_name([species_idx])
/// @description Picks a random name from the race-specific pool. If no species
/// is given (or the lookup fails), falls back to the unified fallback pool.
/// names.json schema v2: each race has its own .first[] and .last[] arrays.
function generate_random_name(_species_idx = -1) {
	var _bucket = undefined;
	if (_species_idx >= 0) {
		var _key = string_lower(get_species_name(_species_idx));
		// "T'sa" → "tsa" (strip apostrophe to match the JSON key)
		_key = string_replace_all(_key, "'", "");
		_bucket = global.names[$ _key];
	}
	if (_bucket == undefined) _bucket = global.names[$ "fallback"];
	// Last-ditch back-compat for v1-format names.json (single first_names/last_names)
	if (_bucket == undefined && global.names[$ "first_names"] != undefined) {
		_bucket = { first: global.names.first_names, last: global.names.last_names };
	}
	if (_bucket == undefined) return "Unnamed";
	var _first = _bucket.first;
	var _last = _bucket.last;
	return _first[irandom(array_length(_first)-1)] + " " + _last[irandom(array_length(_last)-1)];
}

function get_specialties_for_broad(_broad_name) {
	var _tree = global.skill_tree;
	for (var _i = 0; _i < array_length(_tree); _i++) {
		if (_tree[_i].broad == _broad_name) return _tree[_i].specialties;
	} return [];
}

function find_skill(_stat, _broad_name, _spec_name) {
	for (var _i = 0; _i < array_length(_stat.skills); _i++) {
		if (_stat.skills[_i].broad_skill == _broad_name && _stat.skills[_i].specialty == _spec_name) return _i;
	} return -1;
}

// ============================================================
// CHARGEN WIZARD HELPERS — used by the 3-screen wizard in Draw_64/Step_0
// ============================================================

/// @function chargen_reset()
/// @description Resets all wizard state to step 0 / no selections. Called from
/// every entry point that opens the wizard, and from chargen_finalize after
/// generation completes.
function chargen_reset() {
	with (obj_game) {
		chargen_step = 0;
		chargen_pick_species = -1;
		chargen_pick_prof = -1;
		chargen_pick_career = -1;
		chargen_pick_sec_prof = -1;
		chargen_pick_sec_career = -1;
		chargen_show_diplomat_sub = false;
		chargen_career_scroll = 0;
		chargen_hover_species = -1;
	}
}

/// @function chargen_finalize(species, prof, career, sec_prof, sec_career)
/// @description Final character generation step. Translates -2 sentinels (user
/// explicitly picked Random panel) to -1 (let generator randomize). Spawns the
/// hero, saves it, adds to party, sets initial UI state, closes the wizard.
function chargen_finalize(_sp, _pr, _ca, _spr, _sca) {
	if (_sp  == -2) _sp  = -1;
	if (_pr  == -2) _pr  = -1;
	if (_ca  == -2) _ca  = -1;
	if (_spr == -2) _spr = -1;
	if (_sca == -2) _sca = -1;

	with (obj_game) {
		hero = generate_random_character(_sp, _pr, _ca, _spr, _sca);
		update_hero(hero);
		save_hero_and_track(hero);
		add_to_party(hero);
		var _cpath = global.save_path + sanitize_hero_filename(hero.name) + ".json";
		roster_add_ref(hero.name, _cpath);
		if (gm_mode) save_campaign();
		selected_skill = 0;
		scroll_offset = 0;
		current_tab = 0;
		last_roll = undefined;
		roll_log = [];
		browser_list = [];
		status_msg = "Generated: " + hero.name + " (" + hero.career + ")";
		status_timer = 150;
		chargen_reset();
		chargen_open = false;
		game_state = "sheet";
	}
}

/// @function chargen_secondary_prof_options()
/// @description Returns the array of valid secondary profession indices for Diplomats.
/// (Diplomats cannot dual-class with another Diplomat.)
function chargen_secondary_prof_options() {
	return [PROFESSION.COMBAT_SPEC, PROFESSION.FREE_AGENT, PROFESSION.TECH_OP, PROFESSION.MINDWALKER];
}

// shuffle_array() REMOVED — never called

// ============================================================
// QUICK NPC GENERATION (from GMG templates)
// ============================================================

/// @function generate_quick_npc(template_index)
/// @description Generates a fully formed NPC from a global.npc_templates entry.
function generate_quick_npc(_template_idx) {
	var _t = global.npc_templates[_template_idx];
	// NPC templates default to Human (species 0) — name from human pool
	var _stat = create_statblock(generate_random_name(0), parse_profession_name(_t.profession), _t.name);
	_stat.species = 0;

	// Set abilities from template
	var _abKeys = ["str","dex","con","int","wil","per"];
	var _abUpper = ["STR","DEX","CON","INT","WIL","PER"];
	for (var _i = 0; _i < 6; _i++) set_ability(_stat, _abKeys[_i], _t.abilities[$ _abUpper[_i]]);

	// Species starting broads (Human)
	var _spBroads = get_species_starting_broads(0);
	for (var _i = 0; _i < array_length(_spBroads); _i++)
		if (find_skill(_stat, _spBroads[_i], "") < 0) add_broad_skill_to_hero(_stat, _spBroads[_i]);

	// Template skills
	for (var _i = 0; _i < array_length(_t.skills); _i++) {
		var _sk = _t.skills[_i];
		if (find_skill(_stat, _sk[0], "") < 0) add_broad_skill_to_hero(_stat, _sk[0]);
		if (_sk[1] != "") {
			add_specialty_rank0(_stat, _sk[0], _sk[1]);
			var _idx = find_skill(_stat, _sk[0], _sk[1]);
			for (var _r = 0; _r < _sk[2] && _idx >= 0; _r++) increase_skill_rank(_stat, _idx);
		}
	}

	if (array_length(_t.weapon) >= 7)
		add_weapon(_stat, _t.weapon[0], _t.weapon[1], _t.weapon[2], _t.weapon[3], _t.weapon[4], _t.weapon[5], string_to_damage_type(_t.weapon[6]));
	add_weapon(_stat, "Unarmed", "brawl", "d4s", "d4+1s", "d4+2s", "Personal", DAMAGE_TYPE.LI);
	if (array_length(_t.armor) >= 4) set_armor(_stat, _t.armor[0], _t.armor[1], _t.armor[2], _t.armor[3]);
	_stat.gear = _t.gear;
	_stat.background = _t.name + " NPC. Generated from GMG template.";
	// Auto-grant racial traits — NPCs default to species 0 (Human) so they get Versatile Human + Adaptable Learner
	grant_racial_traits(_stat);
	calculate_action_check(_stat); calculate_durability(_stat);
	recalc_skill_scores(_stat); update_hero(_stat);
	return _stat;
}

// ============================================================
// CHARGEN WIZARD DRAW FUNCTIONS
// 3-screen flow: Race → Profession → Career
// All draw functions read state from obj_game.chargen_step + chargen_pick_*
// ============================================================

/// @function draw_chargen_wizard(gw, gh, lh)
/// @description Top-level wizard draw. Dims background, draws panel frame, dispatches to per-step.
function draw_chargen_wizard(_gw, _gh, _lh) {
	with (obj_game) {
		// Dim background
		draw_set_alpha(0.78); draw_set_colour(#000000); draw_rectangle(0, 0, _gw, _gh, false); draw_set_alpha(1.0);

		// Centered panel
		var _clx = max(40, _gw/2 - 520);
		var _cly = 50;
		var _clw = min(1040, _gw - 80);
		var _clh = _gh - 100;

		draw_set_colour(c_panel); draw_rectangle(_clx, _cly, _clx+_clw, _cly+_clh, false);
		draw_set_colour(c_border); draw_rectangle(_clx, _cly, _clx+_clw, _cly+_clh, true);

		// Header
		var _step_label = ["Choose Race","Choose Profession","Choose Career"];
		var _step_idx = clamp(chargen_step, 0, 2);
		draw_set_colour(c_header);
		draw_text(_clx+16, _cly+10, "NEW CHARACTER  —  Step " + string(_step_idx+1) + " of 3: " + _step_label[_step_idx]);

		// Step pips (top-right of header)
		var _pip_x = _clx + _clw - 80;
		var _pip_y = _cly + 16;
		for (var _p = 0; _p < 3; _p++) {
			draw_set_colour(_p == _step_idx ? c_good : c_border);
			draw_circle(_pip_x + _p*20, _pip_y, 6, _p == _step_idx ? false : true);
		}

		// Cancel button (top-right corner, always visible)
		ui_btn("chargen_cancel", _clx+_clw-36, _cly+6, _clx+_clw-6, _cly+28, "X", c_border, c_failure);

		// Dispatch to per-step
		if (chargen_step == 0) draw_chargen_step_race(_clx, _cly, _clw, _clh, _lh);
		else if (chargen_step == 1) {
			if (chargen_show_diplomat_sub) draw_chargen_step_diplomat_sub(_clx, _cly, _clw, _clh, _lh);
			else                            draw_chargen_step_profession(_clx, _cly, _clw, _clh, _lh);
		}
		else if (chargen_step == 2) draw_chargen_step_career(_clx, _cly, _clw, _clh, _lh);

		// Common bottom button row (Back, Random All, Next/Generate)
		draw_chargen_bottom_buttons(_clx, _cly, _clw, _clh);
	}
}

/// @function draw_chargen_bottom_buttons(clx, cly, clw, clh)
function draw_chargen_bottom_buttons(_clx, _cly, _clw, _clh) {
	var _by = _cly + _clh - 36;
	// Back (only on steps 1+, or step 1's Diplomat sub-step)
	var _show_back = (chargen_step > 0) || (chargen_step == 1 && chargen_show_diplomat_sub);
	if (_show_back) ui_btn("chargen_back", _clx+12, _by, _clx+92, _by+26, "<- Back", c_border, c_amazing);

	// Random All (always)
	ui_btn("chargen_random_all", _clx+_clw/2 - 90, _by, _clx+_clw/2 + 90, _by+26, "RANDOM ALL", c_border, c_amazing);

	// Next or Generate (final step)
	var _is_final = (chargen_step == 2);
	var _enabled = false;
	if (chargen_step == 0) _enabled = (chargen_pick_species != -1);
	else if (chargen_step == 1) {
		if (chargen_show_diplomat_sub) _enabled = (chargen_pick_sec_prof != -1);
		else                            _enabled = (chargen_pick_prof != -1);
	}
	else if (chargen_step == 2) _enabled = (chargen_pick_career != -1);
	var _label = _is_final ? "GENERATE ->" : "Next ->";
	var _color = _enabled ? c_good : c_border;
	ui_btn("chargen_next", _clx+_clw-172, _by, _clx+_clw-12, _by+26, _label, c_border, _color);
}

/// @function draw_chargen_step_race(clx, cly, clw, clh, lh)
/// @description Screen 1: Race picker. 3x3 grid with center cell empty (info text),
/// 8 race/random panels around the ring (6 races + Random + Random All visual).
function draw_chargen_step_race(_clx, _cly, _clw, _clh, _lh) {
	var _grid_x = _clx + 24;
	var _grid_y = _cly + 50;
	var _grid_w = _clw - 48;
	var _grid_h = _clh - 50 - 50;
	var _gap = 12;
	var _cell_w = floor((_grid_w - _gap*2) / 3);
	var _cell_h = floor((_grid_h - _gap*2) / 3);

	// Cell positions in a 3x3 grid (row-major). Index 4 (center) is empty.
	// Ring order around the center: 0,1,2 / 3,_,5 / 6,7,8 → 8 cells = 6 races + Random + Random-All-info
	var _cells = [
		{ x:0, y:0, kind:"species", idx:0 }, // Human
		{ x:1, y:0, kind:"species", idx:1 }, // Fraal
		{ x:2, y:0, kind:"species", idx:2 }, // Weren
		{ x:0, y:1, kind:"species", idx:3 }, // Sesheyan
		{ x:1, y:1, kind:"center",  idx:-1 }, // Center info panel
		{ x:2, y:1, kind:"species", idx:4 }, // T'sa
		{ x:0, y:2, kind:"species", idx:5 }, // Mechalus
		{ x:1, y:2, kind:"random",  idx:-1 }, // Random Race
		{ x:2, y:2, kind:"randomall_hint", idx:-1 } // Random All hint
	];

	for (var _i = 0; _i < array_length(_cells); _i++) {
		var _c = _cells[_i];
		var _cx = _grid_x + _c.x * (_cell_w + _gap);
		var _cy = _grid_y + _c.y * (_cell_h + _gap);
		var _x2 = _cx + _cell_w;
		var _y2 = _cy + _cell_h;

		if (_c.kind == "center") {
			// Center detail panel: shows hover or selected race info
			var _show_idx = (chargen_pick_species >= 0 ? chargen_pick_species : chargen_hover_species);
			draw_set_colour(c_panel); draw_rectangle(_cx, _cy, _x2, _y2, false);
			draw_set_colour(c_border); draw_rectangle(_cx, _cy, _x2, _y2, true);
			if (_show_idx >= 0 && _show_idx < SPECIES.COUNT) {
				var _sp = global.species_data[_show_idx];
				draw_set_colour(c_amazing); draw_text(_cx+8, _cy+6, _sp.name);
				draw_set_colour(c_muted);   draw_text(_cx+8, _cy+24, "Stat mods:");
				var _ab_keys = ["STR","DEX","CON","INT","WIL","PER"];
				var _mx = _cx+8;
				var _my = _cy+40;
				for (var _ai = 0; _ai < 6; _ai++) {
					var _m = _sp.mods[_ai];
					var _col = (_m > 0 ? c_good : (_m < 0 ? c_failure : c_text));
					draw_set_colour(_col);
					draw_text(_mx, _my, _ab_keys[_ai] + " " + (_m > 0 ? "+" : "") + string(_m));
					_mx += 56;
					if (_ai == 2) { _mx = _cx+8; _my += _lh; }
				}
				_my += _lh + 4;
				draw_set_colour(c_warning); draw_text(_cx+8, _my, "Traits:");
				_my += _lh;
				draw_set_colour(c_text);
				draw_text_ext(_cx+8, _my, _sp.traits, -1, _cell_w-16);
			} else {
				draw_set_colour(c_muted);
				draw_set_halign(fa_center); draw_set_valign(fa_middle);
				draw_text(_cx + _cell_w/2, _cy + _cell_h/2, "Hover over a race to see details.\n\nClick a race panel to select.\nClick RANDOM RACE for a surprise.\nClick RANDOM ALL to skip the wizard\nand generate everything random.");
				draw_set_halign(fa_left); draw_set_valign(fa_top);
			}
			continue;
		}

		// Other cell kinds — register button rect
		var _key = (_c.kind == "species") ? ("chargen_race_" + string(_c.idx)) : ((_c.kind == "random") ? "chargen_race_random" : "");
		if (_key != "") {
			variable_struct_set(btn, _key, [_cx, _cy, _x2, _y2]);
		}
		var _hover = mouse_in(_cx, _cy, _x2, _y2);
		var _selected = false;
		if (_c.kind == "species" && chargen_pick_species == _c.idx) _selected = true;
		if (_c.kind == "random" && chargen_pick_species == -2) _selected = true;
		if (_c.kind == "species" && _hover) chargen_hover_species = _c.idx;

		// Background
		draw_set_colour(_selected ? merge_colour(c_panel, c_good, 0.4) : c_panel);
		draw_rectangle(_cx, _cy, _x2, _y2, false);
		draw_set_colour(_hover ? c_highlight : (_selected ? c_good : c_border));
		draw_rectangle(_cx, _cy, _x2, _y2, true);

		if (_c.kind == "species") {
			var _sp = global.species_data[_c.idx];
			draw_set_colour(_selected ? c_good : c_amazing);
			draw_text(_cx+8, _cy+6, _sp.name);
			// Stat mods one line
			var _mod_str = "";
			var _ab_keys2 = ["STR","DEX","CON","INT","WIL","PER"];
			for (var _ai = 0; _ai < 6; _ai++) {
				if (_sp.mods[_ai] != 0) {
					if (_mod_str != "") _mod_str += " ";
					_mod_str += _ab_keys2[_ai] + (_sp.mods[_ai] > 0 ? "+" : "") + string(_sp.mods[_ai]);
				}
			}
			if (_mod_str == "") _mod_str = "(no mods)";
			draw_set_colour(c_muted); draw_text(_cx+8, _cy+24, _mod_str);
			// Starting broads (truncated to 3)
			draw_set_colour(c_text);
			var _broads_str = "";
			for (var _bi = 0; _bi < min(3, array_length(_sp.starting_broads)); _bi++) {
				if (_bi > 0) _broads_str += ", ";
				_broads_str += _sp.starting_broads[_bi];
			}
			if (array_length(_sp.starting_broads) > 3) _broads_str += "...";
			draw_text_ext(_cx+8, _cy+40, _broads_str, -1, _cell_w-16);
			// Traits one line snippet
			draw_set_colour(c_warning);
			draw_text_ext(_cx+8, _cy+_cell_h-32, _sp.traits, -1, _cell_w-16);
		} else if (_c.kind == "random") {
			draw_set_colour(_selected ? c_good : c_amazing);
			draw_set_halign(fa_center); draw_set_valign(fa_middle);
			draw_text(_cx + _cell_w/2, _cy + _cell_h/2 - 8, "RANDOM RACE");
			draw_set_colour(c_muted);
			draw_text(_cx + _cell_w/2, _cy + _cell_h/2 + 8, "Pick a species at random");
			draw_set_halign(fa_left); draw_set_valign(fa_top);
		} else if (_c.kind == "randomall_hint") {
			draw_set_colour(c_warning);
			draw_set_halign(fa_center); draw_set_valign(fa_middle);
			draw_text(_cx + _cell_w/2, _cy + _cell_h/2 - 8, "RANDOM ALL");
			draw_set_colour(c_muted);
			draw_text(_cx + _cell_w/2, _cy + _cell_h/2 + 8, "Use the button below");
			draw_set_halign(fa_left); draw_set_valign(fa_top);
		}
	}
}

/// @function draw_chargen_step_profession(clx, cly, clw, clh, lh)
/// @description Screen 2: Profession picker. 3x2 grid + 1 random panel = 6 cells.
function draw_chargen_step_profession(_clx, _cly, _clw, _clh, _lh) {
	var _grid_x = _clx + 24;
	var _grid_y = _cly + 50;
	var _grid_w = _clw - 48;
	var _grid_h = _clh - 50 - 50;
	var _gap = 12;
	var _cell_w = floor((_grid_w - _gap*2) / 3);
	var _cell_h = floor((_grid_h - _gap) / 2);

	// 5 professions + 1 Random panel
	for (var _i = 0; _i < 6; _i++) {
		var _col = _i mod 3;
		var _row = _i div 3;
		var _cx = _grid_x + _col * (_cell_w + _gap);
		var _cy = _grid_y + _row * (_cell_h + _gap);
		var _x2 = _cx + _cell_w;
		var _y2 = _cy + _cell_h;

		var _is_random = (_i == 5);
		var _key = _is_random ? "chargen_prof_random" : ("chargen_prof_" + string(_i));
		variable_struct_set(btn, _key, [_cx, _cy, _x2, _y2]);
		var _hover = mouse_in(_cx, _cy, _x2, _y2);
		var _selected = (_is_random ? (chargen_pick_prof == -2) : (chargen_pick_prof == _i));

		draw_set_colour(_selected ? merge_colour(c_panel, c_good, 0.4) : c_panel);
		draw_rectangle(_cx, _cy, _x2, _y2, false);
		draw_set_colour(_hover ? c_highlight : (_selected ? c_good : c_border));
		draw_rectangle(_cx, _cy, _x2, _y2, true);

		if (_is_random) {
			draw_set_colour(_selected ? c_good : c_amazing);
			draw_set_halign(fa_center); draw_set_valign(fa_middle);
			draw_text(_cx + _cell_w/2, _cy + _cell_h/2 - 8, "RANDOM PROFESSION");
			draw_set_colour(c_muted);
			draw_text(_cx + _cell_w/2, _cy + _cell_h/2 + 14, "Pick a profession at random");
			draw_set_halign(fa_left); draw_set_valign(fa_top);
		} else {
			var _p = global.professions[_i];
			draw_set_colour(_selected ? c_good : c_amazing);
			draw_text(_cx+8, _cy+6, _p.name);
			// Requirements
			draw_set_colour(c_muted);
			draw_text(_cx+8, _cy+24, "Reqs: " + _p.requirements.primary + " " + string(_p.requirements.primary_min) + ", " + _p.requirements.secondary + " " + string(_p.requirements.secondary_min));
			// Starting skill points
			draw_set_colour(c_warning);
			draw_text(_cx+8, _cy+40, "Starting skill points: " + string(_p[$ "starting_points"] ?? 40));
			// Description (use a derived line if no field)
			var _desc = _p[$ "description"];
			if (_desc == undefined || _desc == "") {
				// Fall back to a one-liner per profession
				switch (_i) {
					case 0: _desc = "Combat-focused soldier. STR/CON. Tank, frontline, or sniper."; break;
					case 1: _desc = "Negotiator and dual-classer. INT/PER. Picks a second profession on top of Diplomat."; break;
					case 2: _desc = "Versatile generalist. DEX/PER. Pilot, smuggler, scout, hacker."; break;
					case 3: _desc = "Engineer and technician. INT/DEX. Repair, build, hack, science."; break;
					case 4: _desc = "Psionic specialist. WIL/INT. Telepathy, ESP, telekinesis, biokinesis."; break;
					default: _desc = "";
				}
			}
			draw_set_colour(c_text);
			draw_text_ext(_cx+8, _cy+60, _desc, -1, _cell_w-16);
		}
	}
}

/// @function draw_chargen_step_diplomat_sub(clx, cly, clw, clh, lh)
/// @description Screen 2b: Diplomat secondary profession picker. 5 cells (4 valid options + Random).
function draw_chargen_step_diplomat_sub(_clx, _cly, _clw, _clh, _lh) {
	draw_set_colour(c_warning);
	draw_text(_clx+16, _cly+30, "DIPLOMAT — Choose your second profession (cannot be Diplomat)");

	var _grid_x = _clx + 24;
	var _grid_y = _cly + 60;
	var _grid_w = _clw - 48;
	var _grid_h = _clh - 60 - 50;
	var _gap = 12;
	var _opts = chargen_secondary_prof_options();
	var _count = array_length(_opts) + 1; // +1 for Random
	var _cols = 3;
	var _rows = ceil(_count / _cols);
	var _cell_w = floor((_grid_w - _gap*(_cols-1)) / _cols);
	var _cell_h = floor((_grid_h - _gap*(_rows-1)) / _rows);

	for (var _i = 0; _i < _count; _i++) {
		var _col = _i mod _cols;
		var _row = _i div _cols;
		var _cx = _grid_x + _col * (_cell_w + _gap);
		var _cy = _grid_y + _row * (_cell_h + _gap);
		var _x2 = _cx + _cell_w;
		var _y2 = _cy + _cell_h;

		var _is_random = (_i == array_length(_opts));
		var _key = _is_random ? "chargen_secprof_random" : ("chargen_secprof_" + string(_i));
		variable_struct_set(btn, _key, [_cx, _cy, _x2, _y2]);
		var _hover = mouse_in(_cx, _cy, _x2, _y2);
		var _selected = false;
		if (_is_random && chargen_pick_sec_prof == -2) _selected = true;
		if (!_is_random && chargen_pick_sec_prof == _opts[_i]) _selected = true;

		draw_set_colour(_selected ? merge_colour(c_panel, c_good, 0.4) : c_panel);
		draw_rectangle(_cx, _cy, _x2, _y2, false);
		draw_set_colour(_hover ? c_highlight : (_selected ? c_good : c_border));
		draw_rectangle(_cx, _cy, _x2, _y2, true);

		if (_is_random) {
			draw_set_colour(_selected ? c_good : c_amazing);
			draw_set_halign(fa_center); draw_set_valign(fa_middle);
			draw_text(_cx + _cell_w/2, _cy + _cell_h/2, "RANDOM 2nd PROF");
			draw_set_halign(fa_left); draw_set_valign(fa_top);
		} else {
			var _p = global.professions[_opts[_i]];
			draw_set_colour(_selected ? c_good : c_amazing);
			draw_text(_cx+8, _cy+6, _p.name);
			draw_set_colour(c_muted);
			draw_text(_cx+8, _cy+24, "Reqs: " + _p.requirements.primary + " " + string(_p.requirements.primary_min));
		}
	}
}

/// @function draw_chargen_step_career(clx, cly, clw, clh, lh)
/// @description Screen 3: Career picker. Two-pane: list on left, preview on right.
function draw_chargen_step_career(_clx, _cly, _clw, _clh, _lh) {
	if (chargen_pick_prof < 0) {
		draw_set_colour(c_failure); draw_text(_clx+16, _cly+50, "Profession not picked yet — go back");
		return;
	}
	var _careers = get_careers_for_profession(chargen_pick_prof);
	if (array_length(_careers) == 0) {
		draw_set_colour(c_failure); draw_text(_clx+16, _cly+50, "No careers found for this profession");
		return;
	}

	var _list_x = _clx + 16;
	var _list_y = _cly + 50;
	var _list_w = floor((_clw - 32) * 0.4);
	var _list_h = _clh - 50 - 50;
	var _preview_x = _list_x + _list_w + 12;
	var _preview_w = _clw - (_preview_x - _clx) - 16;
	var _preview_h = _list_h;

	// Left list — Random card at top, then careers
	draw_set_colour(c_header); draw_text(_list_x, _list_y, "Careers (" + get_profession_name(chargen_pick_prof) + ")");
	var _cy = _list_y + _lh + 4;
	var _row_h = 36;

	// Random Career card (idx 0)
	{
		var _y2 = _cy + _row_h;
		var _hover = mouse_in(_list_x, _cy, _list_x+_list_w, _y2);
		var _selected = (chargen_pick_career == -2);
		variable_struct_set(btn, "chargen_career_random", [_list_x, _cy, _list_x+_list_w, _y2]);
		draw_set_colour(_selected ? merge_colour(c_panel, c_good, 0.4) : c_panel);
		draw_rectangle(_list_x, _cy, _list_x+_list_w, _y2, false);
		draw_set_colour(_hover ? c_highlight : (_selected ? c_good : c_border));
		draw_rectangle(_list_x, _cy, _list_x+_list_w, _y2, true);
		draw_set_colour(_selected ? c_good : c_amazing);
		draw_text(_list_x+8, _cy+8, "RANDOM CAREER");
		_cy += _row_h + 4;
	}

	// Mouse wheel scroll
	var _max_visible = floor((_list_h - (_lh + 4) - _row_h - 4) / (_row_h + 4));
	var _max_scroll = max(0, array_length(_careers) - _max_visible);
	chargen_career_scroll = clamp(chargen_career_scroll, 0, _max_scroll);

	for (var _i = 0; _i < array_length(_careers); _i++) {
		if (_i < chargen_career_scroll) continue;
		if (_cy + _row_h > _list_y + _list_h) break;
		var _c = _careers[_i];
		var _y2 = _cy + _row_h;
		var _hover = mouse_in(_list_x, _cy, _list_x+_list_w, _y2);
		var _selected = (chargen_pick_career == _i);
		variable_struct_set(btn, "chargen_career_" + string(_i), [_list_x, _cy, _list_x+_list_w, _y2]);
		draw_set_colour(_selected ? merge_colour(c_panel, c_good, 0.4) : c_panel);
		draw_rectangle(_list_x, _cy, _list_x+_list_w, _y2, false);
		draw_set_colour(_hover ? c_highlight : (_selected ? c_good : c_border));
		draw_rectangle(_list_x, _cy, _list_x+_list_w, _y2, true);
		draw_set_colour(_selected ? c_good : c_text);
		draw_text(_list_x+8, _cy+4, _c.name);
		// Sample skills
		var _spec_str = "";
		for (var _si = 0; _si < min(3, array_length(_c.specs)); _si++) {
			if (_si > 0) _spec_str += ", ";
			_spec_str += _c.specs[_si][1];
		}
		draw_set_colour(c_muted);
		draw_text(_list_x+8, _cy+18, _spec_str);
		_cy += _row_h + 4;
	}

	// Right preview pane
	draw_set_colour(c_panel); draw_rectangle(_preview_x, _list_y, _preview_x+_preview_w, _list_y+_preview_h, false);
	draw_set_colour(c_border); draw_rectangle(_preview_x, _list_y, _preview_x+_preview_w, _list_y+_preview_h, true);

	if (chargen_pick_career >= 0 && chargen_pick_career < array_length(_careers)) {
		var _c = _careers[chargen_pick_career];
		var _py = _list_y + 8;
		draw_set_colour(c_amazing); draw_text(_preview_x+8, _py, _c.name); _py += _lh + 4;
		draw_set_colour(c_warning); draw_text(_preview_x+8, _py, "Broad Skills:"); _py += _lh;
		draw_set_colour(c_text);
		for (var _bi = 0; _bi < array_length(_c.broads); _bi++) {
			draw_text(_preview_x+16, _py, "- " + _c.broads[_bi]); _py += _lh;
		}
		_py += 4;
		draw_set_colour(c_warning); draw_text(_preview_x+8, _py, "Specialties:"); _py += _lh;
		draw_set_colour(c_text);
		for (var _si = 0; _si < array_length(_c.specs); _si++) {
			var _s = _c.specs[_si];
			draw_text(_preview_x+16, _py, "- " + _s[0] + ": " + _s[1] + " r" + string(_s[2])); _py += _lh;
		}
		_py += 4;
		draw_set_colour(c_warning); draw_text(_preview_x+8, _py, "Weapons:"); _py += _lh;
		draw_set_colour(c_text);
		for (var _wi = 0; _wi < array_length(_c.weapons); _wi++) {
			draw_text(_preview_x+16, _py, "- " + _c.weapons[_wi][0]); _py += _lh;
		}
		_py += 4;
		draw_set_colour(c_warning); draw_text(_preview_x+8, _py, "Armor:"); _py += _lh;
		draw_set_colour(c_text);
		draw_text(_preview_x+16, _py, "- " + _c.armor[0]); _py += _lh + 4;
		draw_set_colour(c_warning); draw_text(_preview_x+8, _py, "Gear:"); _py += _lh;
		draw_set_colour(c_text);
		for (var _gi = 0; _gi < array_length(_c.gear); _gi++) {
			draw_text(_preview_x+16, _py, "- " + _c.gear[_gi]); _py += _lh;
		}
	} else if (chargen_pick_career == -2) {
		draw_set_colour(c_amazing);
		draw_set_halign(fa_center); draw_set_valign(fa_middle);
		draw_text(_preview_x + _preview_w/2, _list_y + _preview_h/2, "Random career\nwill be picked\nat generation time.");
		draw_set_halign(fa_left); draw_set_valign(fa_top);
	} else {
		draw_set_colour(c_muted);
		draw_set_halign(fa_center); draw_set_valign(fa_middle);
		draw_text(_preview_x + _preview_w/2, _list_y + _preview_h/2, "Click a career on the left\nto preview its skills, weapons, and gear.");
		draw_set_halign(fa_left); draw_set_valign(fa_top);
	}
}
