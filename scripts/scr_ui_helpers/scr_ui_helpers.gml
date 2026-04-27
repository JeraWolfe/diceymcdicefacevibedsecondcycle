/// @description UI Helper Functions
/// Eliminates redundant patterns across Step_0 and Draw_64.
///
/// FUNCTION HIERARCHY:
///   btn_clicked(key)          - Check if a named button was clicked this frame
///   log_roll(name, result)    - Log a roll to display, file, and roll log array
///   log_info(text)            - Log an info message to the roll log (no roll)
///   apply_cant_fail(roll)     - Apply can't-fail mode (failure → marginal)
///   draw_checkbox(x, y, checked, label, key) - Draw a checkbox, register button, return y advance
///   draw_stat_row(x, y, label, value, res_mod, key_prefix, index) - Draw ability with +/- buttons

/// @function apply_color_profile(mode)
/// @description Applies a colorblind palette from config. Overwrites the game's active colors.
function apply_color_profile(_mode) {
	var _profiles = global.config.color_profiles;
	var _p = _profiles[$ _mode] ?? _profiles.normal;
	obj_game.c_good      = parse_hex_color(_p.good);
	obj_game.c_failure    = parse_hex_color(_p.failure);
	obj_game.c_warning    = parse_hex_color(_p.warning);
	obj_game.c_amazing    = parse_hex_color(_p.amazing);
	obj_game.c_highlight  = parse_hex_color(_p.highlight);
	// Save to config for persistence
	global.config.accessibility.mode = _mode;
	write_json("config.json", global.config);
}

/// @function btn_clicked(key) → bool
/// @description Check if a named button rect was clicked. Replaces 73 inline checks.
function btn_clicked(_key) {
	return variable_struct_exists(obj_game.btn, _key)
		&& point_in_rectangle(
			device_mouse_x_to_gui(0), device_mouse_y_to_gui(0),
			obj_game.btn[$ _key][0], obj_game.btn[$ _key][1],
			obj_game.btn[$ _key][2], obj_game.btn[$ _key][3]);
}

/// @function format_health_message(label, old_val, new_val, char_name, by_gm, target_name)
/// @description Build the natural-language message for a health change.
///   Stun damage : "Calvin is stunned for 3 points."
///   Stun heal   : "Calvin's stun fades by 2 points."
///   Wound dmg   : "Calvin takes 4 wound damage."
///   Wound heal  : "Calvin heals 2 wound damage."
///   Mortal dmg  : "Calvin takes 1 mortal damage."
///   Mortal heal : "Calvin heals 1 mortal damage."
///   GM-assigned : "(GM assigned 4 wound damage to Calvin.)"
function format_health_message(_label, _old_val, _new_val, _char_name, _by_gm, _target_name) {
	var _delta = _old_val - _new_val;        // positive = damage taken
	var _abs   = abs(_delta);
	var _is_damage = (_new_val < _old_val);
	var _kind = string_lower(_label);          // "stun" / "wound" / "mortal"
	var _name = (_char_name != "") ? _char_name : "Player";

	if (_by_gm) {
		var _verb = _is_damage ? "assigned" : "restored";
		var _typestr = (_kind == "stun") ? "stun" : (_kind + " damage");
		return "(GM " + _verb + " " + string(_abs) + " " + _typestr + " to " + (_target_name != "" ? _target_name : _name) + ".)";
	}

	if (_kind == "stun") {
		if (_is_damage) return _name + " is stunned for " + string(_abs) + " point" + (_abs == 1 ? "" : "s") + ".";
		else            return _name + "'s stun fades by " + string(_abs) + " point" + (_abs == 1 ? "" : "s") + ".";
	}
	// wound / mortal
	if (_is_damage) return _name + " takes " + string(_abs) + " " + _kind + " damage.";
	else            return _name + " heals " + string(_abs) + " " + _kind + " damage.";
}

/// @function log_health_change(label, old_val, new_val, [by_gm], [target_name])
/// @description Log a health change with natural-language phrasing into all the
/// usual destinations: roll_log (sidebar history), rolllog_entries (Roll Log tab
/// party stream), session_log_entries (persistent disk-backed Sessionlog), AND
/// broadcasts as a chat line to the multiplayer session if connected.
/// When _by_gm is true, the message uses the "(GM assigned X to Y)" format.
/// _target_name is the character receiving the change — only meaningful in GM mode.
function log_health_change(_label, _old_val, _new_val, _by_gm = false, _target_name = "") {
	if (_old_val == _new_val) return;

	var _char = (obj_game.hero != undefined) ? obj_game.hero.name : "";
	if (_target_name != "") _char = _target_name;
	var _full = format_health_message(_label, _old_val, _new_val, _char, _by_gm, _target_name);

	var _is_damage = (_new_val < _old_val);
	var _sender = variable_instance_exists(obj_game, "net_player_name") && obj_game.net_player_name != "" ? obj_game.net_player_name : "Local";

	// Roll history (the simple list shown in right sidebar)
	array_insert(obj_game.roll_log, 0, {
		skill_name: _label,
		degree_name: _full,
		degree: _is_damage ? 0 : 2, // damage red, heal green
		total: _new_val,
		mod_str: "",
		sender_name: _sender,
		character_name: _char,
		is_remote: false,
		is_chat: false,
		chat_text: "",
		timestamp: current_time
	});
	if (array_length(obj_game.roll_log) > obj_game.max_log_entries) array_pop(obj_game.roll_log);

	// Party stream (the Roll Log tab)
	array_insert(obj_game.rolllog_entries, 0, {
		sender_name: _sender,
		character_name: _char,
		skill_name: "",
		degree_name: "",
		degree: 0,
		total: _new_val,
		mod_str: "",
		modifiers: [],
		is_remote: false,
		is_chat: true,
		chat_text: _full,
		timestamp: current_time
	});
	if (array_length(obj_game.rolllog_entries) > obj_game.max_log_entries) array_pop(obj_game.rolllog_entries);

	// Persistent session log — ALWAYS write, even when offline. Data integrity.
	session_log_append(session_log_make_chat_entry(_char, _full, false, ""));

	// Broadcast as chat to the session so all players + GM see the change.
	// In a session this is mandatory for data integrity — the session log on
	// every client must agree.
	if (variable_instance_exists(obj_game, "net_connected") && obj_game.net_connected) {
		net_send_chat(_full);
	}
	obj_game.rolllog_dirty = true;
	obj_game.hero_dirty = true;
}

/// @function open_text_modal(label, target_struct, target_key, max_len, after)
/// @description Open the in-game inline text editor on a target struct field.
/// Real-time saves: every keystroke writes through to target_struct[target_key].
/// Replaces get_string() — no OS dialog, no fullscreen black screen.
/// Press Escape or click Cancel to close. Click Save (or Enter) to commit + run after().
function open_text_modal(_label, _target_struct, _target_key, _max_len, _after) {
	obj_game.text_modal_open = true;
	obj_game.text_modal_label = _label;
	obj_game.text_modal_target_struct = _target_struct;
	obj_game.text_modal_target_key = _target_key;
	obj_game.text_modal_max_len = (_max_len > 0) ? _max_len : 200;
	obj_game.text_modal_after = _after;
	// Seed buffer from current value
	var _cur = "";
	if (_target_struct != undefined && variable_struct_exists(_target_struct, _target_key)) {
		_cur = string(_target_struct[$ _target_key] ?? "");
	}
	obj_game.text_modal_buffer = _cur;
	obj_game.net_input_focus = "text_modal"; // grab keyboard focus
}

/// @function close_text_modal(commit)
/// @description Close the modal. If commit, fire the after callback (real-time
/// saves already happened). If not, ALSO restore the original value.
function close_text_modal(_commit) {
	if (!obj_game.text_modal_open) return;
	if (_commit) {
		var _cb = obj_game.text_modal_after;
		if (_cb != undefined) _cb();
	}
	obj_game.text_modal_open = false;
	obj_game.text_modal_label = "";
	obj_game.text_modal_buffer = "";
	obj_game.text_modal_target_struct = undefined;
	obj_game.text_modal_target_key = "";
	obj_game.text_modal_after = undefined;
	if (obj_game.net_input_focus == "text_modal") obj_game.net_input_focus = "";
}

/// @function log_roll(name, result)
/// @description Unified roll logging. Replaces 17 copy-pasted blocks.
function log_roll(_name, _result) {
	_result.skill_name = _name;
	obj_game.last_roll = _result;
	// Build modifier string for display
	var _mod_str = "";
	if (array_length(_result[$ "modifiers"] ?? []) > 0) {
		_mod_str = " (";
		for (var _mi = 0; _mi < array_length(_result.modifiers); _mi++) {
			if (_mi > 0) _mod_str += ", ";
			_mod_str += _result.modifiers[_mi];
		}
		_mod_str += ")";
	}
	array_insert(obj_game.roll_log, 0, {
		skill_name: _name,
		degree_name: _result.degree_name,
		degree: _result.degree,
		total: _result.total,
		mod_str: _mod_str,
		sender_name: variable_instance_exists(obj_game, "net_player_name") ? (obj_game.net_player_name == "" ? "Local" : obj_game.net_player_name) : "Local",
		character_name: (obj_game.hero != undefined) ? obj_game.hero.name : "",
		is_remote: false,
		is_chat: false,
		chat_text: "",
		timestamp: current_time
	});
	if (obj_game.hero != undefined) append_roll_log_file(obj_game.hero, _result);
	obj_game.rolllog_dirty = true;
	if (array_length(obj_game.roll_log) > obj_game.max_log_entries) array_pop(obj_game.roll_log);

	// Persistent session log — every local roll lands here too
	var _sl_sender = (variable_instance_exists(obj_game, "net_player_name") && obj_game.net_player_name != "") ? obj_game.net_player_name : "Local";
	var _sl_char = (obj_game.hero != undefined) ? obj_game.hero.name : "";
	session_log_append(session_log_make_roll_entry(_sl_sender, _sl_char, _name, _result.degree, _result.total, _mod_str));

	// Also push the structured entry to the party stream so the Roll Log tab
	// shows both local and remote rolls in the same list when connected.
	if (variable_instance_exists(obj_game, "net_connected") && obj_game.net_connected) {
		var _stream_entry = {
			sender_name: obj_game.net_player_name == "" ? "Local" : obj_game.net_player_name,
			character_name: (obj_game.hero != undefined) ? obj_game.hero.name : "",
			skill_name: _name,
			degree_name: _result.degree_name,
			degree: _result.degree,
			total: _result.total,
			mod_str: _mod_str,
			modifiers: _result[$ "modifiers"] ?? [],
			is_remote: false,
			is_chat: false,
			chat_text: "",
			timestamp: current_time
		};
		array_insert(obj_game.rolllog_entries, 0, _stream_entry);
		if (array_length(obj_game.rolllog_entries) > obj_game.max_log_entries) {
			array_pop(obj_game.rolllog_entries);
		}

		// Broadcast to the session.
		var _char_name_bc = (obj_game.hero != undefined) ? obj_game.hero.name : "";
		net_send_roll(_result, _char_name_bc);
	}
}

/// @function log_info(text)
/// @description Log an info message (no dice roll)
function log_info(_text) {
	var _r = { degree_name: _text, degree: 1, total: 0, control_roll: 0,
	           situation_roll: 0, situation_step: SIT_STEP_BASE, is_critical_failure: false };
	log_roll("INFO", _r);
}

// make_damage_result() REMOVED — inlined at callsites

/// @function apply_cant_fail(roll)
function apply_cant_fail(_roll) {
	if (obj_game.cant_fail_mode && _roll.degree <= 0 && !_roll.is_critical_failure) {
		_roll.degree = 0; _roll.degree_name = "MARGINAL";
	}
}

// track_hit() REMOVED — inlined at callsites

// ============================================================
// SHARED HELPERS
// ============================================================



// annotate_training() REMOVED — inlined into prepare_roll and quick_roll_skill

/// @function build_weapon_export_array(statblock) → array of v4 weapon arrays
/// @description Builds export-ready weapon arrays from statblock. Used by all save/export functions.
function build_weapon_export_array(_stat) {
	var _out = [];
	for (var _i = 0; _i < array_length(_stat.weapons); _i++) {
		var _w = _stat.weapons[_i];
		var _sk_kw = _w[$ "skill_keyword"] ?? "";
		var _dt = "LI";
		switch (_w.damage_type) { case DAMAGE_TYPE.HI: _dt = "HI"; break; case DAMAGE_TYPE.EN: _dt = "En"; break; }
		array_push(_out, [_w.name, _sk_kw, _w.dmg_ordinary, _w.dmg_good, _w.dmg_amazing, _w.range_str, _dt]);
	}
	return _out;
}

// ============================================================
// META ROLLER — single entry point for ALL checks
// ============================================================
// Every skill check, feat check, combat roll, quick roll, and psionic roll
// funnels through meta_roll(). This is THE place to hook in:
//   - Perk/flaw modifiers
//   - Cybertech bonuses
//   - Environmental effects
//   - GM hidden modifiers
//   - Status effects
//
// Flow: caller builds a roll_request → meta_roll() processes it → returns result
//
// roll_request struct:
//   .name          - display name for the log ("Rifle", "Awareness", "STR feat")
//   .score_ord     - ordinary threshold
//   .score_good    - good threshold
//   .score_amz     - amazing threshold
//   .base_penalty  - situation die step penalty before modifiers
//   .roll_type     - "skill" / "feat" / "attack" / "initiative" / "damage"
//   .weapon        - (optional) weapon struct for attack/damage rolls
//   .ability       - (optional) ability key for feat rolls ("str","dex",etc.)
//   .broad_skill   - (optional) broad skill name
//   .spec_skill    - (optional) specialty name
//   .training      - (optional) "trained" / "broad" / "untrained"
//   .damage_tier   - (optional) 0/1/2 for damage rolls

/// @function build_skill_request(stat, broad, spec, extra_pen)
/// @description Build a roll request for a skill check
function build_skill_request(_stat, _broad, _spec, _extra_pen) {
	var _idx = find_skill(_stat, _broad, _spec);
	if (_idx < 0 && _spec != "") _idx = find_skill(_stat, _broad, "");

	var _req = {};
	_req.roll_type = "skill";
	_req.broad_skill = _broad;
	_req.spec_skill = _spec;

	if (_idx >= 0) {
		var _sk = _stat.skills[_idx];
		_req.score_ord = _sk.score_ordinary;
		_req.score_good = _sk.score_good;
		_req.score_amz = _sk.score_amazing;
		_req.base_penalty = (_sk.specialty != "" ? 0 : 1) + _extra_pen;
		_req.training = (_sk.specialty != "") ? "trained" : "broad";
		_req.name = (_sk.specialty != "") ? _sk.specialty : _sk.broad_skill;
		_req.ability = _sk.ability; // needed for ability-based keyword tags (e.g., "dex" for Clumsy)
	} else {
		// Untrained — find ability from skill tree
		var _ab = "str";
		var _tree = global.skill_tree;
		for (var _i = 0; _i < array_length(_tree); _i++) {
			if (_tree[_i].broad == _broad) { _ab = _tree[_i].ability; break; }
		}
		var _usc = get_ability_score_for_skill(_stat, _ab) div 2;
		_req.score_ord = _usc; _req.score_good = _usc div 2; _req.score_amz = _usc div 4;
		_req.base_penalty = 1 + _extra_pen; // PHB: untrained base die is +d4 (same as broad), penalty comes from halved score
		_req.training = "untrained";
		_req.name = _broad + " (untrained)";
		_req.ability = _ab;
	}
	return _req;
}

/// @function build_feat_request(stat, ab_key, ab_name, extra_pen)
/// PHB Table P18: Feat checks use FULL ability score (not half) with +d4 base die
function build_feat_request(_stat, _ab_key, _ab_name, _extra_pen) {
	var _score = get_ability_score_for_skill(_stat, _ab_key);
	return {
		roll_type: "feat", name: _ab_name + " feat", ability: _ab_key,
		score_ord: _score, score_good: _score div 2, score_amz: _score div 4,
		base_penalty: 1 + _extra_pen, training: "feat",
		broad_skill: "", spec_skill: ""
	};
}

/// @function build_attack_request(stat, weapon, base_pen)
function build_attack_request(_stat, _wep, _base_pen) {
	var _best = find_best_skill_for_weapon(_stat, _wep);
	// Resolve ability from weapon skill_keyword via keyword tree
	var _ab = "";
	var _kw = _wep[$ "skill_keyword"] ?? "";
	if (_kw != "" && global.keyword_tree.weapon_skills[$ _kw] != undefined) {
		var _ws = global.keyword_tree.weapon_skills[$ _kw];
		if (global.keyword_tree.broads[$ _ws.broad] != undefined)
			_ab = global.keyword_tree.broads[$ _ws.broad].ability;
	}
	return {
		roll_type: "attack", name: _wep.name + " (" + _best.skill_name + ")",
		score_ord: _best.score_ord, score_good: _best.score_good, score_amz: _best.score_amz,
		base_penalty: _base_pen + _best.penalty, training: _best.use_type,
		ability: _ab, weapon: _wep, broad_skill: "", spec_skill: _best.skill_name
	};
}

/// @function build_initiative_request(stat)
function build_initiative_request(_stat) {
	var _ac = _stat.action_check;
	return {
		roll_type: "initiative", name: "Initiative",
		score_ord: _ac.ordinary, score_good: _ac.good, score_amz: _ac.amazing,
		base_penalty: 0, training: "action_check",
		broad_skill: "", spec_skill: ""
	};
}

/// @function apply_fx_modifiers(statblock, request)
/// @description THE UNIFIED MODIFIER ENGINE. One loop, all FX types.
///   Reads hero.fx array, looks up each entry in global.fx_database,
///   matches keywords against roll tags, applies modifiers.
///   Handles: perks, flaws, cybertech, racial, environmental, items — all identical.
///
///   ADDING A NEW MODIFIER (no code changes needed):
///     1. Add an entry to fx_database.json with name, type, keywords, modifier
///     2. Done. apply_fx_modifiers() will match it on every relevant roll.
///     3. GMs: create homebrew_fx.json in same format, system merges at startup.
///
///   QUALITY-SCALED: FX with quality_scale: {"O":-1,"G":-2,"A":-3} and quality != ""
///   FIXED: most perks/flaws with modifier: -1 or +1
///   Reads ALL modifiers from hero.fx + global.fx_database. One loop, all types.
///   Perks, flaws, cybertech, racial, environmental, items — all handled identically.
function apply_fx_modifiers(_stat, _req) {
	if (_req[$ "modifiers"] == undefined) _req.modifiers = [];

	// Generate keyword tags for this roll
	var _tags = get_roll_keywords(_req);

	// One loop through ALL active FX on this hero
	for (var _i = 0; _i < array_length(_stat.fx); _i++) {
		var _hero_fx = _stat.fx[_i];

		// Skip inactive FX
		if (!(_hero_fx[$ "active"] ?? true)) continue;

		// Look up full FX definition from database
		var _fxd = get_fx_data(_hero_fx.name);
		if (_fxd == undefined) continue;

		// Determine keywords and modifier based on quality tier gating
		var _quality = _hero_fx[$ "quality"] ?? "";
		var _kw_list = [];
		var _val = 0;

		// PER-KEYWORD QUALITY GATING: keyword_tiers = { "G": { keywords: [...], modifier: -1 }, "A": { ... } }
		// Different quality tiers can unlock different keyword sets and modifiers
		var _tiers = _fxd[$ "keyword_tiers"];
		if (_tiers != undefined && _quality != "" && is_struct(_tiers) && _tiers[$ _quality] != undefined) {
			var _tier = _tiers[$ _quality];
			_kw_list = _tier[$ "keywords"] ?? [];
			_val = _tier[$ "modifier"] ?? 0;
		}
		// QUALITY-SCALED: same keywords, different modifier per quality
		else if (_fxd[$ "quality_scale"] != undefined && _quality != "" && is_struct(_fxd.quality_scale)
			&& _fxd.quality_scale[$ _quality] != undefined) {
			_kw_list = _fxd[$ "keywords"] ?? [];
			_val = _fxd.quality_scale[$ _quality];
		}
		// FIXED: flat keywords + flat modifier
		else {
			_kw_list = _fxd[$ "keywords"] ?? [];
			_val = _fxd[$ "modifier"] ?? 0;
		}

		// Skip if no keywords for this tier/quality
		if (array_length(_kw_list) == 0) continue;

		// Check if ANY keyword matches ANY roll tag
		var _match = false;
		for (var _ki = 0; _ki < array_length(_kw_list); _ki++) {
			if (roll_has_tag(_tags, _kw_list[_ki])) { _match = true; break; }
		}
		if (!_match) continue;

		// Apply if non-zero
		if (_val != 0) {
			_req.base_penalty += _val;
			array_push(_req.modifiers, _hero_fx.name + (_val >= 0 ? "+" : "") + string(_val));
		}
	}

	// Future hooks: environmental modifiers, GM hidden modifiers
	// These will just be additional FX entries with type "environmental" or "gm"
}


/// @function meta_roll(stat, request) → roll result
/// @function resolve_roll(stat, keyword_str, extra_pen)
/// @description Resolves a keyword string into a roll request struct.
///   The unified entry point for ALL rolls. Accepts natural-language keywords:
///     "Perception"                    → skill request (specialty)
///     "Awareness"                     → skill request (broad)
///     "STR feat"                      → feat request (full ability score)
///     "Initiative"                    → action check request
///     "9mm charge pistol attack"      → weapon attack request
///     "Rifle"                         → resolves via keyword_tree to spec skill
///   Returns a request struct ready for meta_roll() / prepare_roll().
function resolve_roll(_stat, _keyword_str, _extra_pen) {
	var _kw = string_trim(_keyword_str);
	var _kw_lower = string_lower(_kw);

	// Check for "feat" suffix: "STR feat", "DEX feat", etc.
	if (string_length(_kw_lower) > 5 && string_copy(_kw_lower, string_length(_kw_lower)-3, 4) == "feat") {
		var _ab_str = string_trim(string_copy(_kw_lower, 1, string_length(_kw_lower)-4));
		for (var _i = 0; _i < 6; _i++) {
			var _ak = global.ability_keys[_i];
			if (_ab_str == _ak || _ab_str == string_lower(global.ability_full[$ _ak]))
				return build_feat_request(_stat, _ak, global.ability_names[_i], _extra_pen);
		}
	}

	// Check for "initiative"
	if (_kw_lower == "initiative") return build_initiative_request(_stat);

	// Check for "attack" suffix: "weapon name attack"
	if (string_length(_kw_lower) > 7 && string_pos(" attack", _kw_lower) == string_length(_kw_lower) - 6) {
		var _wep_str = string_trim(string_copy(_kw, 1, string_length(_kw) - 7));
		// Exact name match in hero's weapons
		for (var _i = 0; _i < array_length(_stat.weapons); _i++) {
			if (string_lower(_stat.weapons[_i].name) == string_lower(_wep_str))
				return build_attack_request(_stat, _stat.weapons[_i], _extra_pen);
		}
		// Partial name match
		for (var _i = 0; _i < array_length(_stat.weapons); _i++) {
			if (string_pos(string_lower(_wep_str), string_lower(_stat.weapons[_i].name)) > 0)
				return build_attack_request(_stat, _stat.weapons[_i], _extra_pen);
		}
	}

	// Try as specialty skill (exact match in keyword_tree.skills)
	if (global.keyword_tree.skills[$ _kw] != undefined) {
		var _sk = global.keyword_tree.skills[$ _kw];
		return build_skill_request(_stat, _sk.broad, _kw, _extra_pen);
	}

	// Try as broad skill (exact match in keyword_tree.broads)
	if (global.keyword_tree.broads[$ _kw] != undefined) {
		return build_skill_request(_stat, _kw, "", _extra_pen);
	}

	// Try as weapon skill keyword (keyword_tree.weapon_skills)
	if (global.keyword_tree.weapon_skills[$ _kw_lower] != undefined) {
		var _ws = global.keyword_tree.weapon_skills[$ _kw_lower];
		return build_skill_request(_stat, _ws.broad, _ws.spec, _extra_pen);
	}

	// Try as bare ability name → feat check (abbreviation or full name)
	for (var _i = 0; _i < 6; _i++) {
		var _ak = global.ability_keys[_i];
		if (_kw_lower == _ak || _kw_lower == string_lower(global.ability_full[$ _ak])) {
			return build_feat_request(_stat, _ak, global.ability_names[_i], _extra_pen);
		}
	}

	// Ultimate fallback: treat as unknown feat
	return build_feat_request(_stat, "int", "Unknown", _extra_pen);
}

/// @function keyword_roll(stat, keyword_str, extra_pen)
/// @description One-liner convenience: resolve a keyword and roll instantly.
function keyword_roll(_stat, _keyword_str, _extra_pen) {
	return meta_roll(_stat, resolve_roll(_stat, _keyword_str, _extra_pen));
}

/// @description THE single roll function. All checks flow through here.
///   1. Apply perk/flaw modifiers
///   2. Apply wound penalties
///   3. Clamp situation die
///   4. Roll dice
///   5. Apply cant-fail
///   6. Log result
///   7. Track hit (for attacks)
/// @function prepare_roll(stat, request)
/// @description Phase 1: Compute all automatic modifiers and set the situation die.
///   Stores result in obj_game.staged_roll. Player can adjust before executing.
///   Call this when a skill/quick button is clicked. Sets the adjuster to the computed value.
function prepare_roll(_stat, _req) {
	if (_req[$ "modifiers"] == undefined) _req.modifiers = [];
	// Training annotation (was annotate_training)
	var _train = _req[$ "training"] ?? "";
	if (_train == "broad") array_push(_req.modifiers, "Broad+1");
	else if (_train == "feat") array_push(_req.modifiers, "Feat+1");
	else if (_train == "untrained") array_push(_req.modifiers, "Untrained+1");

	// Perks/flaws/cybertech
	apply_fx_modifiers(_stat, _req);

	// Wounds
	var _wp = (obj_game.apply_wound_penalty && obj_game.hero != undefined) ? get_wound_penalty(obj_game.hero) : 0;
	if (_wp > 0) {
		_req.base_penalty += _wp;
		array_push(_req.modifiers, "Wounds+" + string(_wp));
	}

	// Compute the system's recommended situation step
	var _computed = clamp(SIT_STEP_BASE + _req.base_penalty, SIT_STEP_MIN, SIT_STEP_MAX);

	// Stage the roll — SET the die to the computed default
	// Player CAN then adjust with < > buttons before clicking Roll
	// The delta between their adjustment and computed is logged as Player Mod
	obj_game.staged_roll = {
		request: _req,
		stat: _stat,
		computed_step: _computed,
		modifiers: _req.modifiers
	};
	obj_game.situation_step = _computed; // SET die to computed (training + FX + wounds)
}

/// @function execute_staged_roll()
/// @description Phase 2: Execute the staged roll with current situation_step.
///   If player adjusted the die, the delta is logged as "Player Mod".
function execute_staged_roll() {
	var _sr = obj_game.staged_roll;
	if (_sr == undefined) return undefined;

	var _req = _sr.request;
	var _stat = _sr.stat;
	var _sit = obj_game.situation_step;

	// Calculate player override
	var _player_delta = _sit - _sr.computed_step;
	if (_player_delta != 0) {
		array_push(_req.modifiers, "Player Mod" + (_player_delta >= 0 ? "+" : "") + string(_player_delta));
	}

	// Roll
	var _roll;
	if (_req.roll_type == "initiative") {
		_roll = alternity_action_check(_req.score_ord, _req.score_good, _req.score_amz, _sit);
	} else {
		_roll = alternity_check(_req.score_ord, _req.score_good, _req.score_amz, _sit);
	}

	apply_cant_fail(_roll);

	_roll.modifiers = _req.modifiers;
	_roll.difficulty = get_difficulty_descriptor(_sit);

	log_roll(_req.name, _roll);

	if (_req.roll_type == "attack" && _req[$ "weapon"] != undefined) {
		if (_roll.degree >= 1) { obj_game.last_combat_weapon = _req.weapon; obj_game.last_combat_degree = _roll.degree; }
		else { obj_game.last_combat_weapon = undefined; obj_game.last_combat_degree = -1; }
	}

	obj_game.staged_roll = undefined; // clear staged roll
	return _roll;
}

/// @function meta_roll(stat, request)
/// @description Combined prepare+execute for instant rolls (backwards compatible).
///   Use prepare_roll + execute_staged_roll for the staged workflow.
function meta_roll(_stat, _req) {
	prepare_roll(_stat, _req);
	return execute_staged_roll();
}

// ============================================================
// CONVENIENCE WRAPPERS — call meta_roll with the right request
// ============================================================

// do_attack_roll, do_feat_roll, do_skill_roll COLLAPSED — callers now inline meta_roll + build_*_request directly

// _build_best_awareness_request() REMOVED — inlined at callsite in Step_0

// _apply_auto_mods() REMOVED — inlined into quick_roll_skill

/// @function quick_roll_skill(stat, request)
/// @description Quick roll: applies auto-mods ON TOP of the player's current situation_step.
///   The player sets their base die (GM says "roll at -1 bonus" → player sets -d4).
///   Auto-mods (training, FX, wounds) adjust from there.
///   Result: player's choice + automatic adjustments = final die.
function quick_roll_skill(_stat, _req) {
	if (_req[$ "modifiers"] == undefined) _req.modifiers = [];

	// Start from the player's current situation die setting
	var _player_base = obj_game.situation_step;

	// Apply auto-mods inline (training + FX + wounds)
	var _train = _req[$ "training"] ?? "";
	if (_train == "broad") array_push(_req.modifiers, "Broad+1");
	else if (_train == "feat") array_push(_req.modifiers, "Feat+1");
	else if (_train == "untrained") array_push(_req.modifiers, "Untrained+1");
	apply_fx_modifiers(_stat, _req);
	var _wp = (obj_game.apply_wound_penalty && obj_game.hero != undefined) ? get_wound_penalty(obj_game.hero) : 0;
	if (_wp > 0) { _req.base_penalty += _wp; array_push(_req.modifiers, "Wounds+" + string(_wp)); }

	// Final step = player's chosen base + auto-mod penalties
	// _req.base_penalty now contains training + FX + wounds
	var _final = clamp(_player_base + _req.base_penalty, SIT_STEP_MIN, SIT_STEP_MAX);

	// Log the player's base if different from neutral
	var _player_offset = _player_base - SIT_STEP_BASE;
	if (_player_offset != 0) {
		array_push(_req.modifiers, "Player Set" + (_player_offset >= 0 ? "+" : "") + string(_player_offset));
	}

	// Update UI to show what was actually rolled
	obj_game.situation_step = _player_base; // keep player's base setting for next roll

	// Roll at the final adjusted step
	return _execute_instant(_req, _stat, _final);
}

/// @function _execute_instant(request, stat, final_sit_step)
/// @description Instantly rolls dice at the given situation step, logs, tracks hits.
function _execute_instant(_req, _stat, _sit) {
	var _roll;
	if (_req.roll_type == "initiative")
		_roll = alternity_action_check(_req.score_ord, _req.score_good, _req.score_amz, _sit);
	else
		_roll = alternity_check(_req.score_ord, _req.score_good, _req.score_amz, _sit);
	apply_cant_fail(_roll);
	_roll.modifiers = _req.modifiers;
	_roll.difficulty = get_difficulty_descriptor(_sit);
	log_roll(_req.name, _roll);
	if (_req.roll_type == "attack" && _req[$ "weapon"] != undefined) {
		if (_roll.degree >= 1) { obj_game.last_combat_weapon = _req.weapon; obj_game.last_combat_degree = _roll.degree; }
		else { obj_game.last_combat_weapon = undefined; obj_game.last_combat_degree = -1; }
	}
	return _roll;
}

// do_initiative_roll, do_damage_roll COLLAPSED — callers now inline directly

function do_hit_damage_roll() {
	if (obj_game.last_combat_weapon == undefined || obj_game.last_combat_degree < 1) return;
	var _wep = obj_game.last_combat_weapon; var _deg = obj_game.last_combat_degree;
	var _tiers = [_wep.dmg_ordinary, _wep.dmg_ordinary, _wep.dmg_good, _wep.dmg_amazing];
	var _names = ["", "Ordinary", "Good", "Amazing"];
	var _dr = parse_and_roll_damage(_tiers[_deg]);
	var _r = { degree_name: _dr.text, degree: _deg, total: _dr.total, control_roll: _dr.roll, situation_roll: 0, situation_step: SIT_STEP_BASE, is_critical_failure: false };
	log_roll(_wep.name + " " + _names[_deg] + " HIT", _r);
	obj_game.last_combat_weapon = undefined; obj_game.last_combat_degree = -1;
}

// get_wound_pen_if_enabled() REMOVED — inlined at callsites

// ============================================================
// KEYWORD/TRAIT SYSTEM — tag-based modifier matching
// ============================================================
// Every roll request gets tagged with keywords derived from the skill, ability, and roll type.
// Perks/flaws/cybertech define which keywords they match.
// This replaces hardcoded string matching with a data-driven pattern.
//
// Keywords auto-derived:
//   "str", "dex", "con", "int", "wil", "per" — from the skill's ability
//   "combat", "ranged", "melee", "unarmed" — from combat skill categories
//   "psionic" — from FX skills
//   "social" — from PER-based interaction skills
//   "tech" — from INT-based technical skills
//   "initiative" — from action check rolls
//   "trained", "broad", "untrained" — from training level
//   The broad skill name lowercased: "awareness", "athletics", etc.

/// @function get_roll_keywords(request)
/// @description Generates keyword tags for a roll request. Reads categories from global.keyword_tree.
function get_roll_keywords(_req) {
	var _tags = [];
	var _broad = _req[$ "broad_skill"] ?? "";
	var _broad_lower = string_lower(_broad);
	var _spec = _req[$ "spec_skill"] ?? "";
	var _ab = _req[$ "ability"] ?? "";
	var _type = _req[$ "roll_type"] ?? "";
	var _train = _req[$ "training"] ?? "";

	// Core tags: ability, roll type, training level
	if (_ab != "") array_push(_tags, _ab);
	if (_type != "") array_push(_tags, _type);
	if (_train != "") array_push(_tags, _train);

	// Broad skill name as tag
	if (_broad_lower != "") array_push(_tags, _broad_lower);

	// Specialty name as tag (for precise matching like "perception", "rifle")
	if (_spec != "") array_push(_tags, string_lower(_spec));

	// Category tags from keyword tree (replaces 5 hardcoded arrays)
	if (_spec != "" && global.keyword_tree.skills[$ _spec] != undefined) {
		var _cats = global.keyword_tree.skills[$ _spec].categories;
		for (var _ci = 0; _ci < array_length(_cats); _ci++) array_push(_tags, _cats[_ci]);
	} else if (_broad != "" && global.keyword_tree.broads[$ _broad] != undefined) {
		var _cats = global.keyword_tree.broads[$ _broad].categories;
		for (var _ci = 0; _ci < array_length(_cats); _ci++) array_push(_tags, _cats[_ci]);
	}

	// Attack rolls always get "combat" tag
	if (_type == "attack") array_push(_tags, "combat");

	return _tags;
}

/// @function roll_has_tag(tags_array, tag)
/// Uses GML 2024 built-in array_contains — wrapper kept for readability
function roll_has_tag(_tags, _tag) {
	return array_contains(_tags, _tag);
}

// ============================================================
// DROPDOWN SYSTEM — self-contained dropdown objects
// ============================================================

/// @function dropdown(key, label, options, max_vis, on_change)
/// @description Creates a dropdown struct that manages its own state.
function dropdown(_key, _label, _options, _max_vis, _on_change) {
	return {
		key: _key, label: _label, options: _options,
		selected: 0, open: false, max_vis: _max_vis, on_change: _on_change,

		draw: function(_x, _y, _w) {
			draw_set_colour(obj_game.c_text); draw_text(_x - 100, _y + 3, self.label);
			obj_game.btn[$ self.key] = [_x, _y, _x + _w, _y + 24];
			draw_set_colour(self.open ? obj_game.c_highlight : obj_game.c_border);
			draw_rectangle(_x, _y, _x + _w, _y + 24, false);
			draw_set_colour(#ffffff);
			draw_text(_x + 6, _y + 4, self.options[self.selected]);
		},

		draw_list: function() {
			if (!self.open || !variable_struct_exists(obj_game.btn, self.key)) return;
			var _b = obj_game.btn[$ self.key];
			var _max = min(array_length(self.options), self.max_vis);
			for (var _i = 0; _i < _max; _i++) {
				var _oy = _b[1] + 24 + _i * 24;
				var _h = mouse_in(_b[0], _oy, _b[2], _oy + 24);
				draw_set_colour(_h ? obj_game.c_border : obj_game.c_panel);
				draw_rectangle(_b[0], _oy, _b[2], _oy + 24, false);
				draw_set_colour(obj_game.c_border);
				draw_rectangle(_b[0], _oy, _b[2], _oy + 24, true);
				draw_set_colour(_i == self.selected ? obj_game.c_highlight : #ffffff);
				draw_text(_b[0] + 6, _oy + 4, self.options[_i]);
			}
		},

		click: function() {
			if (self.open && variable_struct_exists(obj_game.btn, self.key)) {
				var _b = obj_game.btn[$ self.key];
				var _max = min(array_length(self.options), self.max_vis);
				for (var _i = 0; _i < _max; _i++) {
					var _oy = _b[1] + 24 + _i * 24;
					if (mouse_in(_b[0], _oy, _b[2], _oy + 24)) {
						self.selected = _i; self.open = false;
						if (self.on_change != undefined) self.on_change(self, _i);
						return true;
					}
				}
				self.open = false; return true;
			}
			if (btn_clicked(self.key)) { self.open = true; return true; }
			return false;
		},

		value: function() { return self.options[self.selected]; },
		set_options: function(_opts) { self.options = _opts; self.selected = 0; }
	};
}

/// @function dropdown_group_click(dropdowns)
function dropdown_group_click(_dds) {
	for (var _i = 0; _i < array_length(_dds); _i++) {
		if (_dds[_i].open && _dds[_i].click()) return true;
	}
	for (var _i = 0; _i < array_length(_dds); _i++) {
		if (_dds[_i].click()) {
			for (var _j = 0; _j < array_length(_dds); _j++) { if (_j != _i) _dds[_j].open = false; }
			return true;
		}
	}
	return false;
}

/// @function dropdown_group_draw_lists(dropdowns)
function dropdown_group_draw_lists(_dds) {
	for (var _i = 0; _i < array_length(_dds); _i++) _dds[_i].draw_list();
}

// ============================================================
// TAB DRAW HELPERS — Eliminate repetition in scr_draw_tabs
// ============================================================

/// @function draw_section_header(x, y, title, right_text, right_color)
/// @description Draws "TITLE" in c_header, optional right-side text in given color. Returns nothing.
function draw_section_header(_x, _y, _title, _rightText, _rightColor) {
	draw_set_colour(obj_game.c_header);
	draw_text(_x + 8, _y, _title);
	if (_rightText != "") {
		draw_set_colour(_rightColor);
		draw_text(_x + string_width(_title) + 20, _y, _rightText);
	}
}

/// @function draw_checkbox_inline(x, y, checked, label, btn_key)
/// @description Draws a 14x14 checkbox with label. Registers btn rect. Returns nothing.
function draw_checkbox_inline(_x, _y, _checked, _label, _btnKey) {
	draw_set_colour(obj_game.c_border);
	draw_rectangle(_x, _y, _x + 14, _y + 14, false);
	if (_checked) {
		draw_set_colour(obj_game.c_good);
		draw_rectangle(_x + 2, _y + 2, _x + 12, _y + 12, false);
	}
	draw_set_colour(obj_game.c_text);
	draw_text(_x + 20, _y, _label);
	obj_game.btn[$ _btnKey] = [_x, _y, _x + 14, _y + 14];
}

/// @function draw_combat_options_row(x, y, lh, wound_key, cantfail_key)
/// @description Draws the wound-penalty + cant-fail checkboxes used by combat & psionics tabs. Returns new _ly.
function draw_combat_options_row(_x, _y, _lh, _woundKey, _cantfailKey) {
	draw_set_colour(obj_game.c_muted); draw_text(_x + 8, _y, "Options:");
	draw_checkbox_inline(_x + 80, _y, obj_game.apply_wound_penalty, "Wound penalty", _woundKey);
	draw_checkbox_inline(_x + 230, _y, obj_game.cant_fail_mode, "Can't-fail (marginal)", _cantfailKey);
	return _y + _lh + 6;
}

/// @function draw_encounter_char_row(lx, ly, lh, charStat, labelColor, isParty)
/// @description Draws one encounter row (AC, phase, actions, res mods, status). Returns new _ly.
function draw_encounter_char_row(_lx, _ly, _lh, _charStat, _labelColor, _isParty) {
	var _initPhase = _charStat[$ "_init_phase"] ?? -1;
	var _actionsLeft = _charStat[$ "_actions_left"] ?? _charStat.actions_per_round;
	var _phaseNames = ["Amz", "Gd", "Ord", "Mar"];
	var _phaseColors = [obj_game.c_amazing, obj_game.c_good, obj_game.c_text, obj_game.c_warning];

	draw_set_colour(_labelColor);
	draw_text(_lx + 16, _ly, _charStat.name);
	draw_set_colour(obj_game.c_muted); draw_text(_lx + 140, _ly, "AC:");
	draw_set_colour(obj_game.c_text);
	draw_text(_lx + 165, _ly, string(_charStat.action_check.ordinary) + "/" + string(_charStat.action_check.good) + "/" + string(_charStat.action_check.amazing));

	if (_initPhase >= 0 && _initPhase < 4) {
		draw_set_colour(_phaseColors[_initPhase]);
		draw_text(_lx + 280, _ly, _phaseNames[_initPhase]);
	} else {
		draw_set_colour(obj_game.c_muted); draw_text(_lx + 280, _ly, "--");
	}

	draw_set_colour(_actionsLeft > 0 ? obj_game.c_text : obj_game.c_muted);
	draw_text(_lx + 320, _ly, string(_actionsLeft) + "/" + string(_charStat.actions_per_round));
	draw_set_colour(obj_game.c_muted);
	draw_text(_lx + 370, _ly, "S:" + ((_charStat.str.res_mod > 0 ? "+" : "") + string(_charStat.str.res_mod)) + " D:" + ((_charStat.dex.res_mod > 0 ? "+" : "") + string(_charStat.dex.res_mod)) + " W:" + ((_charStat.wil.res_mod > 0 ? "+" : "") + string(_charStat.wil.res_mod)));

	var _status = "OK";
	if (_charStat.mortal.current < _charStat.mortal.max) _status = _isParty ? "MORTAL" : "DEAD";
	else if (_charStat.wound.current < _charStat.wound.max) _status = "WOUNDED";
	else if (_charStat.stun.current < _charStat.stun.max) _status = "STUNNED";
	draw_set_colour(_status == "OK" ? obj_game.c_good : ((_status == "MORTAL" || _status == "DEAD") ? obj_game.c_failure : obj_game.c_warning));
	draw_text(_lx + 530, _ly, string(_charStat.stun.current) + "/" + string(_charStat.wound.current) + "/" + string(_charStat.mortal.current) + " " + _status);

	return _ly + _lh + 2;
}

/// @function draw_scrollable_info_blocks(lx, ly, lw, lh, blocks, total_h, scroll_var_name)
/// @description Draws scrollable info blocks (used by Info tab and GM Resources). Returns _ly.
function draw_scrollable_info_blocks(_lx, _ly, _lw, _lh, _blocks, _totalHeight, _scrollVarName) {
	var _guiHeight = display_get_gui_height();
	var _infoWidth = _lw - 40;
	var _viewHeight = _guiHeight - _ly - 30;
	var _maxScroll = max(0, _totalHeight - _viewHeight);
	var _scrollVal = clamp(variable_instance_get(obj_game, _scrollVarName) ?? 0, 0, _maxScroll);
	variable_instance_set(obj_game, _scrollVarName, _scrollVal);

	var _drawY = _ly - _scrollVal;
	var _clipTop = _ly;
	var _clipBottom = _ly + _viewHeight;

	for (var _blockIndex = 0; _blockIndex < array_length(_blocks); _blockIndex++) {
		var _block = _blocks[_blockIndex];
		var _blockBottom = _drawY + _block.h;
		if (_blockBottom > _clipTop && _drawY < _clipBottom) {
			draw_set_colour(_block.color);
			if (_block.text != "") draw_text_ext(_lx + 8 + _block.indent, _drawY, _block.text, -1, _infoWidth - _block.indent);
		}
		_drawY = _blockBottom;
		if (_drawY > _clipBottom + 50) break;
	}

	return _ly;
}

/// @function info_add_line(blocks, label, desc, col, width)
/// @description Adds a content line to info blocks array. Returns height added.
function info_add_line(_blocks, _label, _desc, _col, _width) {
	if (_label == "" && _desc == "") {
		array_push(_blocks, { text: "", color: obj_game.c_muted, indent: 0, h: 8 });
		return 8;
	}
	if (_desc == "") {
		var _height = string_height_ext(_label, -1, _width);
		array_push(_blocks, { text: _label, color: _col, indent: 0, h: _height + 2 });
		return _height + 2;
	}
	var _combined = _label + ":  " + _desc;
	var _height = string_height_ext(_combined, -1, _width - 12);
	array_push(_blocks, { text: _combined, color: _col, indent: 12, h: _height });
	return _height;
}

/// @function info_add_section(blocks, title, lh)
/// @description Adds a section header to info blocks array. Returns height added.
function info_add_section(_blocks, _title, _lh) {
	array_push(_blocks, { text: _title, color: obj_game.c_header, indent: 0, h: _lh + 4 });
	return _lh + 4;
}

/// @function build_gm_resource_blocks(blocks, lh, width)
/// @description Populates info blocks with GM resource/customization content. Returns total height.
function build_gm_resource_blocks(_blocks, _lh, _width) {
	var _totalHeight = 0;

	_totalHeight += info_add_section(_blocks, "CUSTOM EQUIPMENT (equipment.json)", _lh);
	_totalHeight += info_add_line(_blocks, "Location", "datafiles/equipment.json — edit with any text editor.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Structure", "Three arrays: weapons[], armor[], gear[]. Each is a JSON array of objects.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Add a weapon", "Copy an existing entry, change: name, skill, dmg_ordinary/good/amazing, range, type (LI/HI/En), pl (0-8).", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Add armor", "Fields: name, li/hi/en (absorption codes like \"d6-1\"), pl.", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Add gear", "Fields: name, description, mass, cost, pl.", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "PL filter", "Items only appear if their pl <= campaign_pl (set on Equipment tab).", obj_game.c_muted, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "CUSTOM SKILLS (skills.json)", _lh);
	_totalHeight += info_add_line(_blocks, "Location", "datafiles/skills.json — the master skill tree.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Structure", "Array of broad skills. Each has: name, ability (str/dex/con/int/wil/per), specialties[].", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Add a specialty", "Find the broad skill entry, add a string to its specialties array.", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Add a broad skill", "Add a new object: { \"name\": \"My Skill\", \"ability\": \"int\", \"specialties\": [\"Sub1\", \"Sub2\"] }.", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Skill ranks", "Ranks 0-3. Rank 0 = just purchased. Each rank improves score. Costs escalate per PHB.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Keyword mapping", "If your skill needs perk/flaw matching, add it to keyword_tree.json.", obj_game.c_warning, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "CUSTOM PERKS, FLAWS & CYBERTECH (fx_database.json)", _lh);
	_totalHeight += info_add_line(_blocks, "Location", "datafiles/fx_database.json — all perks, flaws, and cybertech.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Add a perk", "name, type:\"perk\", cost (skill pts), description, keywords[], modifier (neg = bonus).", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Add a flaw", "type:\"flaw\", cost negative (gives pts back), modifier positive (penalty).", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Add cybertech", "type:\"cybertech\", size (tolerance), category (neural/body/sensory/weapon/utility), prereqs[].", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Quality scaling", "quality_scale: {\"O\":-1, \"G\":-2, \"A\":-3} — same keywords, different modifier.", obj_game.c_warning, _width);
	_totalHeight += info_add_line(_blocks, "Keyword tiers", "keyword_tiers: per quality, different keywords AND modifiers. Most flexible.", obj_game.c_warning, _width);
	_totalHeight += info_add_line(_blocks, "No code changes needed", "The FX engine automatically picks up new entries from the JSON.", obj_game.c_amazing, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "CUSTOM PSIONICS", _lh);
	_totalHeight += info_add_line(_blocks, "Psionic skills", "Add to skills.json under Telepathy, Telekinesis, ESP, Biokinesis.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "New discipline", "New broad skill with ability:\"wil\". Add to keyword_tree.json under \"psionic\".", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Psionic perks", "Add to fx_database.json with keywords matching your psionic skills.", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "CUSTOM NPC TEMPLATES (npc_templates.json)", _lh);
	_totalHeight += info_add_line(_blocks, "Location", "datafiles/npc_templates.json — templates for Quick NPC generation.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Add a template", "name, profession (0-4), abilities, skills [{broad,specialty,rank}], weapon/armor/gear.", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Quick NPC button", "NPC tab > Quick NPC picks a random template and generates a full character.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "CUSTOM SPECIES (species.json)", _lh);
	_totalHeight += info_add_line(_blocks, "Location", "datafiles/species.json — all playable species.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Add a species", "name, mods[6 ints], starting_broads[], traits (description string).", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Code change", "Also add to SPECIES enum in scr_chargen.gml (before COUNT).", obj_game.c_warning, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "CAMPAIGN MANAGEMENT", _lh);
	_totalHeight += info_add_line(_blocks, "Campaign file", "campaign.json in save directory. Stores roster, party refs, NPC refs + factions.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Character files", "characters/*.json — each character saved individually.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Scan Files", "Campaign tab > Scan Files finds all .json character files in characters/ folder.", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Export All", "Saves every party member and NPC to disk, then writes campaign.json.", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Factions", "NPC tab > + Faction creates named groups. NPCs are organized by faction.", obj_game.c_text, _width);

	return _totalHeight;
}

/// @function build_player_info_blocks(blocks, lh, width)
/// @description Populates info blocks with player help content. Returns total height.
function build_player_info_blocks(_blocks, _lh, _width) {
	var _totalHeight = 0;

	_totalHeight += info_add_section(_blocks, "HOW TO ROLL (start here)", _lh);
	_totalHeight += info_add_line(_blocks, "Step 1", "Click a skill on the Character tab (left panel). It highlights blue.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Step 2", "Look at the right panel — it shows the skill name and score (O/G/A).", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Step 3", "The Situation Die defaults to +d0 (neutral). Your GM may tell you to adjust it with the < > arrows.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Step 4", "Click the ROLL button. The app rolls d20 + situation die, compares to your score.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Result", "Shows Amazing (blue), Good (green), Ordinary (white), Failure (red), or Critical.", obj_game.c_amazing, _width);
	_totalHeight += info_add_line(_blocks, "Quick Rolls", "Use the Awareness / Mental Res / Physical Res / Initiative buttons on the right — they roll instantly.", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Modifiers", "Perks, flaws, cybertech, and wounds automatically adjust the situation die. You see them listed under the roll.", obj_game.c_warning, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "THE RIGHT PANEL (always visible)", _lh);
	_totalHeight += info_add_line(_blocks, "New / Menu", "Create a new character or return to the welcome screen.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Portrait", "Click Browse to load a custom image, or use presets.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Quick Roll buttons", "Awareness, Mental Resolve, Physical Resolve, Initiative — one-click rolls.", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Situation Die < > Reset", "Adjust the die before rolling. Reset returns to neutral or staged value.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "ROLL button", "Rolls the selected skill or staged roll. Shows result + modifiers.", obj_game.c_amazing, _width);
	_totalHeight += info_add_line(_blocks, "Export / Import / Save / Load", "File operations at the bottom of the right panel.", obj_game.c_muted, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "CHARACTER TAB (Tab 0)", _lh);
	_totalHeight += info_add_line(_blocks, "Skill list", "Your trained skills. Click to select (for rolling). Click +/- to add/remove ranks.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Cost column", "Shows skill point cost. 'P' = profession skill (cheaper). '-' = other.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Perk/flaw toggles", "Radio buttons to set perks and flaws active or inactive. Active ones modify your rolls automatically.", obj_game.c_warning, _width);
	_totalHeight += info_add_line(_blocks, "Untrained section", "Collapsed by default. Click to expand and see skills you don't have (can attempt at half score).", obj_game.c_muted, _width);
	_totalHeight += info_add_line(_blocks, "Skill Browser", "Button at bottom opens full skill tree. Add new broad skills or specialties.", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "EQUIPMENT TAB (Tab 1)", _lh);
	_totalHeight += info_add_line(_blocks, "Three views", "Weapons / Armor / Gear — use the sub-tab buttons at top.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Your inventory", "Listed at top. Click weapon names to inspect details.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Add panel", "Click 'Add' to browse available equipment filtered by Progress Level.", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Custom weapons", "Use 'Custom Weapon' button to create homebrew gear.", obj_game.c_warning, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "COMBAT TAB (Tab 2)", _lh);
	_totalHeight += info_add_line(_blocks, "Initiative", "Click Roll Initiative to determine your action phase (Amazing/Good/Ordinary/Marginal).", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Phase tracker", "4 boxes at top. Click to place actions. Your weapon attacks are below.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Attack rolls", "Click a weapon to roll attack. The damage codes are clickable — click to roll damage.", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Range / Wound / Can't Fail", "Toggle buttons: range penalty (S/M/L), include wound penalty, failures become marginal.", obj_game.c_warning, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "PSIONICS TAB (Tab 3)", _lh);
	_totalHeight += info_add_line(_blocks, "Disciplines", "Shows your psionic broad skills and specialties (Telepathy, TK, ESP, Biokinesis).", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Rolling", "Click any psionic skill to roll it. Modifiers apply automatically.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "PERKS & FLAWS TAB (Tab 4)", _lh);
	_totalHeight += info_add_line(_blocks, "Your perks/flaws", "Listed at top with cost/refund and descriptions.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Add new", "Browse available perks/flaws below. Click to add. Some have quality tiers (O/G/A).", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Active toggles", "Set on the Character tab — active perks/flaws auto-modify rolls.", obj_game.c_warning, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "CYBERTECH TAB (Tab 5)", _lh);
	_totalHeight += info_add_line(_blocks, "Installed", "Your cyberware at top with active/inactive toggles.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Tolerance", "Shows used/max cyber tolerance (based on CON). Don't exceed it.", obj_game.c_warning, _width);
	_totalHeight += info_add_line(_blocks, "Install new", "Browse by category (neural/body/sensory/weapon/utility). Click to expand, pick quality.", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "ROLL LOG TAB (Tab 6)", _lh);
	_totalHeight += info_add_line(_blocks, "History", "Last 100 rolls from your persistent roll log. Color-coded by degree.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Copy", "Click the copy button on any entry to copy it to clipboard.", obj_game.c_muted, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "GRID / CYBERDECK TAB (Tab 8)", _lh);
	_totalHeight += info_add_line(_blocks, "Programs", "Your installed programs. Add from the database filtered by type.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Computer", "Select your cyberdeck hardware. Quality affects available program slots.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Builder", "Create custom homebrew programs.", obj_game.c_warning, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "ABILITY SCORES (top of sheet)", _lh);
	_totalHeight += info_add_line(_blocks, "6 abilities", "STR DEX CON INT WIL PER. Click +/- to adjust. Total should be 60 for humans.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Hover", "Hover over an ability name to see what it does (tooltip).", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "DURABILITY (below abilities)", _lh);
	_totalHeight += info_add_line(_blocks, "Three tracks", "Stun (yellow), Wound (blue), Mortal (red). Circles represent hit points.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Click circles", "Click to mark damage taken. Click the X button to reset a track.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Wound penalty", "Taking wounds adds step penalties to all your rolls. Shown above the durability.", obj_game.c_warning, _width);
	_totalHeight += info_add_line(_blocks, "", "", obj_game.c_muted, _width);

	_totalHeight += info_add_section(_blocks, "DICE REFERENCE", _lh);
	_totalHeight += info_add_line(_blocks, "Control Die", "d20, always rolled. Lower is better.", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Bonus dice (-d4 to -d20)", "SUBTRACTED from d20. Makes checks easier.", obj_game.c_good, _width);
	_totalHeight += info_add_line(_blocks, "Penalty dice (+d4 to +d20)", "ADDED to d20. Makes checks harder.", obj_game.c_failure, _width);
	_totalHeight += info_add_line(_blocks, "Degrees", "Amazing (<=score/4), Good (<=score/2), Ordinary (<=score), Failure (>score).", obj_game.c_text, _width);
	_totalHeight += info_add_line(_blocks, "Damage types", "s=Stun, w=Wound, m=Mortal. e.g. d6+1w means roll d6, add 1, deal wound damage.", obj_game.c_text, _width);

	return _totalHeight;
}

/// @function draw_inspectable_row(lx, ly, lw, lh, text, inspectIdx, inspectType, inspKeyPrefix, btnInfo)
/// @description Draws a row with inspect highlight, hover, and optional remove button.
///   btnInfo = undefined for no button, or [key, label, color] for a button.
///   Returns new _ly.
function draw_inspectable_row(_lx, _ly, _lw, _lh, _text, _inspectIdx, _inspectType, _inspKeyPrefix, _btnInfo) {
	var _isInspected = (obj_game.equip_inspect == _inspectIdx && obj_game.equip_inspect_type == _inspectType);
	draw_inspect_highlight(_lx + 4, _ly - 2, _lw - 8, _lh, _isInspected);

	var _nameX2 = (_btnInfo != undefined) ? _lx + _lw - 60 : _lx + _lw - 8;
	var _inspKey = _inspKeyPrefix + string(_inspectIdx);
	variable_struct_set(obj_game.btn, _inspKey, [_lx + 8, _ly - 2, _nameX2, _ly + _lh - 2]);
	var _hov = mouse_in(_lx + 8, _ly - 2, _nameX2, _ly + _lh - 2);
	draw_set_colour(_isInspected ? obj_game.c_highlight : (_hov ? obj_game.c_highlight : obj_game.c_text));
	draw_text(_lx + 16, _ly, _text);

	if (_btnInfo != undefined)
		ui_btn(_btnInfo[0], _lx + _lw - 50, _ly - 2, _lx + _lw - 8, _ly + _lh - 2, _btnInfo[1], obj_game.c_border, _btnInfo[2]);

	return _ly + _lh;
}

/// @function draw_expandable_catalog_item(lx, ly, lw, lh, name, globalIdx, owned, expandedVar, nameKeyPrefix, extraText, ownedTag)
/// @description Draws an expandable catalog item with arrow, owned tag, and hover. Returns new _ly (just the name row).
function draw_expandable_catalog_item(_lx, _ly, _lw, _lh, _name, _globalIdx, _owned, _expandedVar, _nameKeyPrefix, _extraText, _ownedTag) {
	if (_ownedTag == undefined) _ownedTag = " [INSTALLED]";
	var _isExpanded = (_expandedVar == _globalIdx);
	var _nameKey = _nameKeyPrefix + string(_globalIdx);
	variable_struct_set(obj_game.btn, _nameKey, [_lx + 8, _ly - 2, _lx + 500, _ly + _lh - 2]);
	var _hov = mouse_in(_lx + 8, _ly - 2, _lx + 500, _ly + _lh - 2);
	var _arrow = _isExpanded ? "v " : "> ";
	draw_set_colour(_owned ? obj_game.c_good : (_hov ? obj_game.c_highlight : obj_game.c_text));
	draw_text(_lx + 16, _ly, _arrow + _name + (_owned ? _ownedTag : ""));
	if (_extraText != "") { draw_set_colour(obj_game.c_muted); draw_text(_lx + 340, _ly, _extraText); }
	return _ly + _lh;
}

/// @function draw_combat_skill_row(columns, ly, lh, name, skillName, scoreOrd, scoreGood, scoreAmz, training, trainingColor, totalPenalty, btnKey, btnLabel)
/// @description Draws a single combat-style skill row with score, training, sit die, and optional roll button. Returns new _ly.
function draw_combat_skill_row(_cols, _ly, _lh, _name, _skillName, _scoreOrd, _scoreGood, _scoreAmz, _training, _trainingColor, _totalPenalty, _btnKey, _btnLabel) {
	var _sit = clamp(SIT_STEP_BASE + _totalPenalty, SIT_STEP_MIN, SIT_STEP_MAX);
	draw_set_colour(obj_game.c_text); draw_text(_cols[0], _ly, _name);
	if (_skillName != "") { draw_set_colour(obj_game.c_amazing); draw_text(_cols[1], _ly, _skillName); }
	draw_set_colour(obj_game.c_muted); draw_text(_cols[2], _ly, string(_scoreOrd) + "/" + string(_scoreGood) + "/" + string(_scoreAmz));
	draw_set_colour(_trainingColor); draw_text(_cols[3], _ly, _training);
	draw_set_colour(_totalPenalty > 0 ? obj_game.c_failure : obj_game.c_text); draw_text(_cols[4], _ly, situation_step_name(_sit));
	if (_btnKey != "") ui_btn(_btnKey, _cols[5], _ly - 2, _cols[5] + 60, _ly + _lh - 2, _btnLabel, obj_game.c_border, obj_game.c_highlight);
	return _ly + _lh;
}
