/// @description Per-tab input handlers extracted from Step_0.gml.
/// All functions run in obj_game context — they access instance variables directly.
/// Includes both player tab handlers and GM tab handlers.


// ============================================================
// GM TAB HANDLERS
// ============================================================

/// @function _gm_list_handler(list, prefix, sel_var, edit_source, move_func, remove_func, move_msg, remove_msg)
/// @description Shared handler for GM party/NPC character list operations (select, edit, move, remove).
function _gm_list_handler(_list, _prefix, _selVar, _editSource, _moveFunc, _removeFunc, _moveMsg, _removeMsg) {
	// Select + Edit
	for (var _i = 0; _i < array_length(_list); _i++) {
		if (btn_clicked(_prefix + "sel_" + string(_i))) variable_instance_set(id, _selVar, _i);
		if (btn_clicked(_prefix + "e_" + string(_i))) {
			hero = _list[_i];
			if (_editSource == "party") party_selected = _i;
			update_hero(hero);
			gm_state = "edit"; gm_edit_source = _editSource; gm_edit_index = _i;
			selected_skill = 0; scroll_offset = 0; current_tab = 0;
		}
	}
	// Move + Remove (iterate backward for safe deletion)
	for (var _i = array_length(_list) - 1; _i >= 0; _i--) {
		if (btn_clicked(_prefix + "mv_" + string(_i))) {
			_moveFunc(_i);
			var _sel = variable_instance_get(id, _selVar);
			if (_sel >= array_length(_list)) variable_instance_set(id, _selVar, max(0, array_length(_list) - 1));
			save_campaign(); status_msg = _moveMsg; status_timer = 90;
		}
		if (btn_clicked(_prefix + "rm_" + string(_i))) {
			_removeFunc(_i);
			var _sel = variable_instance_get(id, _selVar);
			if (_sel >= array_length(_list)) variable_instance_set(id, _selVar, max(0, array_length(_list) - 1));
			save_campaign(); status_msg = _removeMsg; status_timer = 90;
		}
	}
}

/// @function _toggle_inspect(index, type_str)
/// @description Toggles equipment inspect panel. If already inspecting this item, close; else open.
function _toggle_inspect(_idx, _type) {
	if (equip_inspect == _idx && equip_inspect_type == _type) { equip_inspect = -1; equip_inspect_type = ""; }
	else { equip_inspect = _idx; equip_inspect_type = _type; }
}

/// @function _gm_import_and_add(add_func, faction, status_prefix)
/// @description Shared import-from-file logic for GM party/NPC tabs.
function _gm_import_and_add(_addFunc, _factionName, _statusPrefix) {
	var _imported = statblock_import();
	if (_imported != undefined) {
		_addFunc(_imported, _factionName);
		save_hero_and_track(_imported);
		roster_add_ref(_imported.name, global.save_path + sanitize_hero_filename(_imported.name) + ".json");
		save_campaign();
		status_msg = _statusPrefix + _imported.name; status_timer = 90;
	}
}

/// @function handle_gm_party()
function handle_gm_party() {
	_gm_list_handler(global.party, "gm_p", "party_selected", "party",
		function(_i) { move_party_to_npcs(_i, "Unaffiliated"); },
		remove_from_party, "Moved to NPCs", "Removed from party");

	// GM action-check rolls per party member — universal rolling without leaving the GM screen.
	for (var _pacIdx = 0; _pacIdx < array_length(global.party); _pacIdx++) {
		if (btn_clicked("gm_pac_" + string(_pacIdx))) {
			var _pacChar = global.party[_pacIdx];
			var _pacRoll = alternity_action_check(_pacChar.action_check.ordinary, _pacChar.action_check.good, _pacChar.action_check.amazing, situation_step);
			log_roll("[GM as " + _pacChar.name + "] Action Check", _pacRoll);
		}
	}

	// Push Character — opens the player picker popup with this party member as the target
	for (var _ppushIdx = 0; _ppushIdx < array_length(global.party); _ppushIdx++) {
		if (btn_clicked("gm_ppush_" + string(_ppushIdx))) {
			if (!net_is_connected()) {
				status_msg = "Not in a session — host or join first to push characters"; status_timer = 180;
			} else {
				push_picker_party_idx = _ppushIdx;
				push_picker_open = true;
			}
			break;
		}
	}

	if (btn_clicked("gm_party_import")) _gm_import_and_add(function(_s,_f){add_to_party(_s);}, "", "Added: ");
	if (btn_clicked("gm_party_new")) { chargen_reset(); chargen_open = true; }
	if (btn_clicked("gm_party_save_all")) {
		for (var _i = 0; _i < array_length(global.party); _i++) save_hero_and_track(global.party[_i]);
		save_campaign(); status_msg = "All party saved"; status_timer = 90;
	}
}

/// @function handle_gm_npcs()
function handle_gm_npcs() {
	_gm_list_handler(global.npcs, "gm_n", "gm_npc_selected", "npc",
		move_npc_to_party, remove_from_npcs, "Moved to Party", "NPC removed");

	// GM action-check rolls per NPC — universal rolling without leaving the GM screen.
	for (var _nacIdx = 0; _nacIdx < array_length(global.npcs); _nacIdx++) {
		if (btn_clicked("gm_nac_" + string(_nacIdx))) {
			var _nacChar = global.npcs[_nacIdx];
			var _nacRoll = alternity_action_check(_nacChar.action_check.ordinary, _nacChar.action_check.good, _nacChar.action_check.amazing, situation_step);
			log_roll("[GM as " + _nacChar.name + "] Action Check", _nacRoll);
		}
	}

	// Clear faction filter (set by Factions tab "View" button)
	if (btn_clicked("gm_npc_clear_filter")) {
		gm_npc_filter_faction = "";
		status_msg = "Filter cleared"; status_timer = 60;
	}

	if (btn_clicked("gm_npc_quick")) {
		var _templateIndex = irandom(array_length(global.npc_templates) - 1);
		var _npc = generate_quick_npc(_templateIndex);
		var _factionName = "Unaffiliated";
		if (gm_npc_selected >= 0 && gm_npc_selected < array_length(global.npcs))
			_factionName = global.npcs[gm_npc_selected][$ "faction"] ?? "Unaffiliated";
		add_to_npcs(_npc, _factionName);
		save_hero_and_track(_npc);
		roster_add_ref(_npc.name, global.save_path + sanitize_hero_filename(_npc.name) + ".json");
		save_campaign();
		status_msg = "NPC: " + _npc.name + " (" + global.npc_templates[_templateIndex].name + ")"; status_timer = 120;
	}
	if (btn_clicked("gm_npc_import")) _gm_import_and_add(add_to_npcs, "Unaffiliated", "NPC added: ");
	if (btn_clicked("gm_npc_add_fac")) {
		// Stage a new faction name in a struct, modal writes to .name in real time,
		// commit pushes to global.factions if not a duplicate.
		faction_edit_stage = { name: "" };
		open_text_modal("Faction/team name:", faction_edit_stage, "name", 50, function() {
			var _n = obj_game.faction_edit_stage.name;
			if (_n == "") return;
			for (var _j = 0; _j < array_length(global.factions); _j++)
				if (global.factions[_j] == _n) return; // dupe
			array_push(global.factions, _n);
			save_campaign();
			obj_game.status_msg = "Faction: " + _n;
			obj_game.status_timer = 90;
		});
	}
}

/// @function _for_all_combatants(func)
/// @description Runs func(stat) on every party member and NPC.
function _for_all_combatants(_func) {
	for (var _i = 0; _i < array_length(global.party); _i++) _func(global.party[_i]);
	for (var _i = 0; _i < array_length(global.npcs); _i++) _func(global.npcs[_i]);
}

/// @function handle_gm_encounter()
function handle_gm_encounter() {
	if (btn_clicked("gm_enc_roll_all")) {
		_for_all_combatants(function(_c) {
			var _roll = alternity_action_check(_c.action_check.ordinary, _c.action_check.good, _c.action_check.amazing, SIT_STEP_BASE);
			_c._init_phase = 3 - _roll.degree; _c._init_degree = _roll.degree;
			_c._actions_left = _c.actions_per_round; log_roll(_c.name + " Init", _roll);
		});
		var _msg_init = "Round " + string(current_round) + " — initiative rolled for all combatants";
		status_msg = _msg_init; status_timer = 90;
		session_log_append(session_log_make_chat_entry("GM", _msg_init, false, ""));
		if (net_is_connected()) net_send_chat(_msg_init);
	}
	if (btn_clicked("gm_enc_new_round")) {
		_for_all_combatants(function(_c) { _c._actions_left = _c.actions_per_round; });
		current_round++;
		var _msg_round = "Round " + string(current_round) + " — actions reset for all combatants";
		status_msg = _msg_round; status_timer = 120;
		session_log_append(session_log_make_chat_entry("GM", _msg_round, false, ""));
		if (net_is_connected()) net_send_chat(_msg_round);
	}
	if (btn_clicked("gm_enc_reset")) {
		_for_all_combatants(function(_c) { _c._init_phase = -1; _c._actions_left = _c.actions_per_round; });
		current_round = 1;
		var _msg_reset = "Initiative cleared — round counter reset to 1";
		status_msg = _msg_reset; status_timer = 90;
		session_log_append(session_log_make_chat_entry("GM", _msg_reset, false, ""));
		if (net_is_connected()) net_send_chat(_msg_reset);
	}
}

/// @function handle_gm_sessionlog()
/// @description Sessionlog tab input — Clear/Save buttons, scroll, chat input.
/// The chat input is processed at the top of Step_0.gml so keystrokes register
/// every frame regardless of click state; this handler covers the buttons.
function handle_gm_sessionlog() {
	if (btn_clicked("gm_sl_clear")) {
		session_log_entries = [];
		session_log_save();
		status_msg = "Session log cleared"; status_timer = 90;
	}
	if (btn_clicked("gm_sl_save")) {
		session_log_save();
		status_msg = "Session log saved (" + string(array_length(session_log_entries)) + " entries)"; status_timer = 90;
	}
	if (btn_clicked("gm_sl_top")) session_log_scroll = 0;
	if (btn_clicked("gm_sl_chat_field")) net_input_focus = "session_chat";

	// Send the typed message
	if (btn_clicked("gm_sl_chat_send") && session_log_chat_buffer != "") {
		_gm_sessionlog_send_chat();
	}
}

/// @function _gm_sessionlog_send_chat()
/// @description Shared send logic — parses /name and /gm whisper prefixes, sends
/// over the relay if connected, mirrors locally to the rolllog stream, and
/// always appends to the persistent session log.
function _gm_sessionlog_send_chat() {
	var _whisper_to = "";
	var _msg_text = session_log_chat_buffer;
	if (string_char_at(_msg_text, 1) == "/") {
		var _space = string_pos(" ", _msg_text);
		if (_space > 1) {
			_whisper_to = string_copy(_msg_text, 2, _space - 2);
			_msg_text = string_copy(_msg_text, _space + 1, string_length(_msg_text) - _space);
		}
	}
	var _sender_name = (net_player_name == "") ? "GM" : net_player_name;
	if (net_is_connected()) {
		if (_whisper_to != "") net_send_whisper(_whisper_to, _msg_text);
		else net_send_chat(_msg_text);
	}
	// Local mirror in the rolllog stream so the GM sees their own message
	var _self_entry = {
		sender_name: _sender_name, character_name: "",
		skill_name: "", degree_name: "", degree: 0, total: 0, mod_str: "",
		modifiers: [], is_remote: false, is_chat: true, is_whisper: _whisper_to != "",
		chat_text: (_whisper_to != "" ? "[whisper to " + _whisper_to + "] " : "") + _msg_text,
		timestamp: current_time
	};
	array_insert(rolllog_entries, 0, _self_entry);
	if (array_length(rolllog_entries) > max_log_entries) array_pop(rolllog_entries);
	// Persistent session log
	session_log_append(session_log_make_chat_entry(_sender_name, _msg_text, _whisper_to != "", _whisper_to));
	session_log_chat_buffer = "";
}

/// @function handle_gm_factions()
/// @description Factions tab input — add/view/rename/delete factions.
/// Closure state (`faction_rename_old_name`, `faction_rename_target_idx`) lives on
/// obj_game (initialized in Create_0.gml) so the after-callback can read it.
function handle_gm_factions() {
	// + Faction button — reuses the same inline-modal pattern as gm_npc_add_fac
	if (btn_clicked("gm_fac_add")) {
		faction_edit_stage = { name: "" };
		open_text_modal("Faction/team name:", faction_edit_stage, "name", 50, function() {
			var _newName = obj_game.faction_edit_stage.name;
			if (_newName == "") return;
			for (var _fchk = 0; _fchk < array_length(global.factions); _fchk++) {
				if (global.factions[_fchk] == _newName) return; // dupe
			}
			array_push(global.factions, _newName);
			save_campaign();
			obj_game.status_msg = "Faction added: " + _newName;
			obj_game.status_timer = 90;
		});
	}

	// Per-row buttons
	for (var _facIdx = 0; _facIdx < array_length(global.factions); _facIdx++) {
		var _facName = global.factions[_facIdx];

		// View — switch to NPCs tab and apply filter
		if (btn_clicked("gm_fac_view_" + string(_facIdx))) {
			gm_tab = 1; // NPCs tab
			gm_npc_filter_faction = _facName;
			status_msg = "Filtering NPCs by faction: " + _facName; status_timer = 120;
		}

		// Rename — open inline modal targeting the faction string slot
		if (btn_clicked("gm_fac_rename_" + string(_facIdx))) {
			if (_facName == "Unaffiliated") {
				status_msg = "Cannot rename the default Unaffiliated faction"; status_timer = 120;
			} else {
				faction_rename_old_name = _facName;
				faction_rename_target_idx = _facIdx;
				faction_edit_stage = { name: _facName };
				open_text_modal("Rename faction:", faction_edit_stage, "name", 50, function() {
					var _newName = obj_game.faction_edit_stage.name;
					var _oldName = obj_game.faction_rename_old_name;
					var _targetIdx = obj_game.faction_rename_target_idx;
					if (_newName == "" || _newName == _oldName) return;
					// Dupe check
					for (var _fchk = 0; _fchk < array_length(global.factions); _fchk++) {
						if (_fchk != _targetIdx && global.factions[_fchk] == _newName) return;
					}
					global.factions[_targetIdx] = _newName;
					// Walk NPCs and update their .faction field
					for (var _renIdx = 0; _renIdx < array_length(global.npcs); _renIdx++) {
						if (global.npcs[_renIdx][$ "faction"] == _oldName) {
							global.npcs[_renIdx].faction = _newName;
						}
					}
					save_campaign();
					obj_game.status_msg = "Renamed faction: " + _oldName + " → " + _newName;
					obj_game.status_timer = 120;
				});
			}
		}

		// Delete — confirm then reassign affected NPCs to "Unaffiliated"
		if (btn_clicked("gm_fac_del_" + string(_facIdx)) && _facName != "Unaffiliated") {
			for (var _delIdx = 0; _delIdx < array_length(global.npcs); _delIdx++) {
				if (global.npcs[_delIdx][$ "faction"] == _facName) {
					global.npcs[_delIdx].faction = "Unaffiliated";
				}
			}
			array_delete(global.factions, _facIdx, 1);
			save_campaign();
			status_msg = "Deleted faction: " + _facName + " (NPCs moved to Unaffiliated)";
			status_timer = 150;
			break; // index changed, bail out of loop
		}
	}
}

/// @function handle_gm_campaign()
/// @description Campaign sub-tab input — roster scroll, scan directory, import, export, and load-to-party/NPCs.
function handle_gm_campaign() {
	// Scroll
	var _wheel = mouse_wheel_up() - mouse_wheel_down();
	if (_wheel != 0) gm_roster_scroll = max(0, gm_roster_scroll - _wheel);

	// Scan characters directory
	if (btn_clicked("gm_camp_scan")) {
		scan_characters_directory();
		save_campaign();
		status_msg = "Found " + string(array_length(global.roster)) + " characters"; status_timer = 90;
	}

	// Import file to roster
	if (btn_clicked("gm_camp_import")) {
		var _imported = statblock_import();
		if (_imported != undefined) {
			save_hero_and_track(_imported);
			var _path = global.save_path + sanitize_hero_filename(_imported.name) + ".json";
			roster_add_ref(_imported.name, _path);
			save_campaign();
			status_msg = "Rostered: " + _imported.name; status_timer = 90;
		}
	}

	// Export all (save everything)
	if (btn_clicked("gm_camp_export")) {
		export_campaign_full();
		status_msg = "Campaign exported — " + string(array_length(global.party)) + " party, " + string(array_length(global.npcs)) + " NPCs"; status_timer = 120;
	}

	// Load from roster into party. Tries the stored path first; if that fails,
	// falls back to global.save_path + sanitized filename. Surfaces success or
	// failure via status_msg so the user can SEE what happened.
	for (var _rosterArrayIndex = 0; _rosterArrayIndex < array_length(global.roster); _rosterArrayIndex++) {
		if (btn_clicked("gm_r2p_" + string(_rosterArrayIndex))) {
			var _rosterRef = global.roster[_rosterArrayIndex];
			var _ok = import_player_to_party(_rosterRef.path);
			if (!_ok) {
				// Fallback: try the canonical path under save_path
				var _fallback = global.save_path + sanitize_hero_filename(_rosterRef.name) + ".json";
				if (_fallback != _rosterRef.path) {
					_ok = import_player_to_party(_fallback);
					if (_ok) {
						// Repair the roster entry so future loads use the correct path
						global.roster[_rosterArrayIndex].path = _fallback;
					}
				}
			}
			if (_ok) {
				save_campaign();
				status_msg = "Loaded to Party: " + _rosterRef.name; status_timer = 120;
			} else {
				status_msg = "Load failed: " + _rosterRef.name + " (file missing or invalid)";
				status_timer = 240;
			}
		}
		if (btn_clicked("gm_r2n_" + string(_rosterArrayIndex))) {
			var _rosterRef = global.roster[_rosterArrayIndex];
			var _ok = import_to_npcs(_rosterRef.path, "Unaffiliated");
			if (!_ok) {
				// Fallback: try canonical path
				var _fallback = global.save_path + sanitize_hero_filename(_rosterRef.name) + ".json";
				if (_fallback != _rosterRef.path) {
					_ok = import_to_npcs(_fallback, "Unaffiliated");
					if (_ok) global.roster[_rosterArrayIndex].path = _fallback;
				}
			}
			if (_ok) {
				save_campaign();
				status_msg = "Loaded to NPCs: " + _rosterRef.name; status_timer = 120;
			} else {
				status_msg = "Load failed: " + _rosterRef.name + " (file missing or invalid)";
				status_timer = 240;
			}
		}
	}
}


// ============================================================
// PLAYER TAB HANDLERS

/// @function _toggle_pill_list(lore_data, field_key, btn_prefix, options, max_picks, max_label)
/// @description Shared toggle logic for lore pill buttons (temperament, motivations).
function _toggle_pill_list(_loreData, _fieldKey, _btnPrefix, _options, _maxPicks, _maxLabel) {
	if (!is_array(_loreData[$ _fieldKey])) _loreData[$ _fieldKey] = [];
	var _list = _loreData[$ _fieldKey];
	for (var _i = 0; _i < array_length(_options); _i++) {
		if (btn_clicked(_btnPrefix + string(_i))) {
			var _found = -1;
			for (var _j = 0; _j < array_length(_list); _j++)
				if (_list[_j] == _options[_i]) { _found = _j; break; }
			if (_found >= 0) array_delete(_list, _found, 1);
			else if (array_length(_list) < _maxPicks) array_push(_list, _options[_i]);
			else { status_msg = "Max " + string(_maxPicks) + " " + _maxLabel; status_timer = 60; }
			hero_dirty = true;
		}
	}
}

/// @function handle_tab_aura()
/// @description Aura/Lore tab input — trait selection, field editing. Voss is read-only.
function handle_tab_aura() {
	if (hero.name == "Sergeant Voss") return;
	if (hero[$ "lore"] == undefined) hero.lore = { height:"",weight:"",hair:"",gender:"",moral_attitude:"",temperament:[],motivations:[],personality:"",lifepath:"" };
	var _loreData = hero.lore;

	// Identity field edits — open the inline modal, real-time saves into _loreData
	var _id_fields = ["gender", "height", "weight", "hair"];
	var _id_labels = ["Gender:", "Height:", "Weight:", "Hair:"];
	for (var _fieldIndex = 0; _fieldIndex < 4; _fieldIndex++) {
		if (btn_clicked("aura_id_" + _id_fields[_fieldIndex])) {
			open_text_modal(_id_labels[_fieldIndex], _loreData, _id_fields[_fieldIndex], 50, function() { obj_game.hero_dirty = true; });
		}
	}

	// Moral attitude edit
	if (btn_clicked("aura_moral")) {
		open_text_modal("Moral Attitude (freeform — e.g. Principled, Pragmatic, Conflicted):", _loreData, "moral_attitude", 100, function() { obj_game.hero_dirty = true; });
	}

	// Temperament toggles (pick 2-3)
	_toggle_pill_list(_loreData, "temperament", "aura_tmp_",
		["Aggressive","Cautious","Competitive","Confident","Curious","Disciplined",
		 "Easygoing","Energetic","Friendly","Honest","Humble","Impulsive","Loyal","Moody",
		 "Optimistic","Paranoid","Patient","Quiet","Rebellious","Reserved","Sarcastic",
		 "Serious","Stubborn","Suspicious","Vengeful"], 3, "temperament traits");

	// Motivation toggles (pick 1-2)
	_toggle_pill_list(_loreData, "motivations", "aura_mot_",
		["Achievement","Belonging","Discovery","Fame","Greed","Honor","Justice",
		 "Knowledge","Loyalty","Power","Protection","Rebellion","Revenge","Service","Survival","Wealth"], 2, "motivations");

	// Personality edit — THIS was the call that caused the alt-tab black screen
	// in fullscreen. The inline modal is fullscreen-safe.
	if (btn_clicked("aura_pers_edit")) {
		open_text_modal("Personality (traits, quirks, habits):", _loreData, "personality", 500, function() { obj_game.hero_dirty = true; });
	}

	// Lifepath edit
	if (btn_clicked("aura_life_edit")) {
		// Seed lifepath from background if empty
		if ((_loreData[$ "lifepath"] ?? "") == "") _loreData.lifepath = hero.background;
		open_text_modal("Lifepath / Backstory:", _loreData, "lifepath", 500, function() { obj_game.hero_dirty = true; });
	}
}

// ============================================================

// toggle_inspect() REMOVED — inlined at callsites

// ---- EQUIPMENT TAB (Tab 1) ----
/// @function handle_tab_equipment()
/// @description Equipment tab input — weapon/armor/gear sub-tabs, add/remove/inspect items, PL filter, custom creation.
function handle_tab_equipment() {
	// Sub-tab switching (reset inspect on tab change)
	if (btn_clicked("eq_weapons_tab")) { equip_view = "weapons"; equip_inspect = -1; equip_inspect_type = ""; equip_expanded = -1; }
	if (btn_clicked("eq_armor_tab"))   { equip_view = "armor";   equip_inspect = -1; equip_inspect_type = ""; equip_expanded = -1; }
	if (btn_clicked("eq_gear_tab"))    { equip_view = "gear";    equip_inspect = -1; equip_inspect_type = ""; equip_expanded = -1; }

	// Toggle add panel
	if (btn_clicked("eq_toggle_add")) { equip_adding = !equip_adding; equip_expanded = -1; equip_inspect = -1; equip_inspect_type = ""; }

	// Toggle verbose/compact
	if (btn_clicked("eq_toggle_verbose")) equip_verbose = !equip_verbose;

	// PL adjustment (clamp 0-8)
	if (btn_clicked("eq_pl_down")) campaign_pl = max(0, campaign_pl - 1);
	if (btn_clicked("eq_pl_up"))   campaign_pl = min(8, campaign_pl + 1);

	// ======== WEAPONS ========
	if (equip_view == "weapons") {
		if (!equip_adding) {
			for (var _i = 0; _i < array_length(hero.weapons); _i++) {
				if (hero.weapons[_i].name != "Unarmed" && btn_clicked("eq_wrm_" + string(_i))) {
					remove_weapon(hero, _i); update_hero(hero); hero_dirty = true;
					if (equip_inspect >= _i && equip_inspect_type == "weapon") { equip_inspect = -1; equip_inspect_type = ""; }
					break;
				}
				if (btn_clicked("eq_winsp_" + string(_i))) _toggle_inspect(_i, "weapon");
			}
		} else {
			var _gi = 0;
			var _categories = ["ranged", "melee", "heavy"];
			for (var _cat = 0; _cat < 3; _cat++) {
				for (var _di = 0; _di < array_length(global.equipment_weapons); _di++) {
					if ((global.equipment_weapons[_di][$ "category"] ?? "") != _categories[_cat]) continue;
					if ((global.equipment_weapons[_di][$ "pl"] ?? 0) == campaign_pl) {
						if (btn_clicked("eq_wname_" + string(_gi))) equip_expanded = (equip_expanded == _gi) ? -1 : _gi;
						if (btn_clicked("eq_wadd_" + string(_gi)) && !hero_has_weapon(hero, global.equipment_weapons[_di].name)) {
							var _entry = global.equipment_weapons[_di];
							add_weapon(hero, _entry.name, _entry.skill_keyword, _entry.dmg_ordinary, _entry.dmg_good, _entry.dmg_amazing, _entry.range, string_to_damage_type(_entry.damage_type));
							update_hero(hero); hero_dirty = true;
						}
					}
					_gi++;
				}
			}
			if (btn_clicked("eq_custom_weapon")) {
				// Add a sensible default weapon, then open the inline editor on its name.
				// Player can then click any other weapon row to inspect/rename. Replaces
				// the chain of 7 get_string popups that caused alt-tab black screens.
				var _stub = { name: "Custom Weapon" };
				add_weapon(hero, _stub.name, "rifle", "d4s", "d4+1s", "d4+2s", "Personal", DAMAGE_TYPE.LI);
				update_hero(hero); hero_dirty = true;
				// Open inline editor on the just-added weapon's name
				var _newIdx = array_length(hero.weapons) - 1;
				if (_newIdx >= 0) {
					open_text_modal("Weapon name:", hero.weapons[_newIdx], "name", 50, function() { obj_game.hero_dirty = true; });
				}
			}
		}
	}

	// ======== ARMOR ========
	if (equip_view == "armor") {
		if (!equip_adding) {
			if (btn_clicked("eq_ainsp_0")) _toggle_inspect(0, "armor");
		} else {
			for (var _i = 0; _i < array_length(global.equipment_armor); _i++) {
				if ((global.equipment_armor[_i][$ "pl"] ?? 0) != campaign_pl) continue;
				if (btn_clicked("eq_aset_" + string(_i))) {
					var _arEntry = global.equipment_armor[_i]; set_armor(hero, _arEntry.name, _arEntry.li, _arEntry.hi, _arEntry.en);
					hero_dirty = true;
				}
				if (btn_clicked("eq_ainsp_" + string(_i))) _toggle_inspect(_i, "armor");
			}
		}
	}

	// ======== GEAR ========
	if (equip_view == "gear") {
		if (!equip_adding) {
			for (var _i = 0; _i < array_length(hero.gear); _i++) {
				if (btn_clicked("eq_grm_" + string(_i))) {
					remove_gear(hero, _i); hero_dirty = true;
					if (equip_inspect >= _i && equip_inspect_type == "gear") { equip_inspect = -1; equip_inspect_type = ""; }
					break;
				}
				if (btn_clicked("eq_ginsp_" + string(_i))) _toggle_inspect(_i, "gear");
			}
		} else {
			for (var _i = 0; _i < array_length(global.equipment_gear); _i++) {
				if ((global.equipment_gear[_i][$ "pl"] ?? 0) != campaign_pl) continue;
				if (btn_clicked("eq_gadd_" + string(_i))) { array_push(hero.gear, global.equipment_gear[_i].name); hero_dirty = true; }
				if (btn_clicked("eq_ginsp_" + string(_i))) _toggle_inspect(_i, "gear");
			}
			if (btn_clicked("eq_custom_gear")) {
				// Add a stub gear slot, then open the inline editor pointing at a
				// staging struct. Commit copies back into the gear array.
				array_push(hero.gear, "Custom Gear");
				hero_dirty = true;
				var _gIdx = array_length(hero.gear) - 1;
				gear_edit_index = _gIdx;
				gear_edit_stage = { name: "Custom Gear" };
				open_text_modal("Gear name:", gear_edit_stage, "name", 60, function() {
					if (obj_game.gear_edit_index >= 0 && obj_game.gear_edit_index < array_length(obj_game.hero.gear)) {
						obj_game.hero.gear[obj_game.gear_edit_index] = obj_game.gear_edit_stage.name;
					}
					obj_game.hero_dirty = true;
				});
			}
		}
	}
}

// ---- COMBAT TAB (Tab 2) ----
/// @function handle_tab_combat()
/// @description Combat tab input — initiative, phase placement, weapon attacks/damage, punch/kick, defensive skills, feat checks.
function handle_tab_combat() {
	// Wounds handled inside quick_roll_skill — only pass range penalty here
	var _rangePenalty = clamp(combat_range, 0, 2);

	// Durability reset X buttons — restore each track to full and log the heal.
	// Tagged as GM-assigned when the GM is editing a player character.
	var _is_gm_edit_combat = (gm_mode && gm_state == "edit");
	var _gm_target_combat = _is_gm_edit_combat ? hero.name : "";
	if (btn_clicked("reset_stun") && hero.stun.current != hero.stun.max) {
		var _so = hero.stun.current;
		hero.stun.current = hero.stun.max;
		log_health_change("Stun", _so, hero.stun.current, _is_gm_edit_combat, _gm_target_combat);
	}
	if (btn_clicked("reset_wound") && hero.wound.current != hero.wound.max) {
		var _wo = hero.wound.current;
		hero.wound.current = hero.wound.max;
		log_health_change("Wound", _wo, hero.wound.current, _is_gm_edit_combat, _gm_target_combat);
	}
	if (btn_clicked("reset_mortal") && hero.mortal.current != hero.mortal.max) {
		var _mo = hero.mortal.current;
		hero.mortal.current = hero.mortal.max;
		log_health_change("Mortal", _mo, hero.mortal.current, _is_gm_edit_combat, _gm_target_combat);
	}

	// Initiative & reset
	if (btn_clicked("roll_init_combat")) {
		var _roll = meta_roll(hero, build_initiative_request(hero));
		initiative_phase = 3 - _roll.degree;
		actions_total = hero.actions_per_round; actions_remaining = actions_total;
		actions_placed = [0,0,0,0];
		status_msg = "Initiative: " + _roll.degree_name; status_timer = 90;
	}
	if (btn_clicked("reset_round")) { actions_placed = [0,0,0,0]; actions_remaining = actions_total; }

	// Phase clicks
	for (var _phaseIdx = 0; _phaseIdx < 4; _phaseIdx++) {
		if (btn_clicked("phase"+string(_phaseIdx)) && initiative_phase >= 0 && _phaseIdx >= initiative_phase && actions_remaining > 0) {
			actions_placed[_phaseIdx]++; actions_remaining--;
		}
	}

	// Wound/cant-fail/range toggles
	if (btn_clicked("toggle_wound_pen")) apply_wound_penalty = !apply_wound_penalty;
	if (btn_clicked("toggle_cant_fail")) cant_fail_mode = !cant_fail_mode;
	for (var _rangeIdx = 0; _rangeIdx < 3; _rangeIdx++) { if (btn_clicked("range"+string(_rangeIdx))) combat_range = _rangeIdx; }

	// Weapon attacks, damage, info
	for (var _weapIdx = 0; _weapIdx < array_length(hero.weapons); _weapIdx++) {
		if (btn_clicked("watk"+string(_weapIdx))) quick_roll_skill(hero, build_attack_request(hero, hero.weapons[_weapIdx], _rangePenalty));
		// "Roll Dmg" button only appears after a successful attack with this weapon —
		// rolls damage at the achieved degree (Ordinary/Good/Amazing).
		if (btn_clicked("wdmgall"+string(_weapIdx))) {
			var _dw = hero.weapons[_weapIdx];
			if (last_combat_weapon == _dw && last_combat_degree >= 1) {
				var _dn = ["", "Ordinary", "Good", "Amazing"];
				var _dt_str = "";
				switch (last_combat_degree) {
					case 1: _dt_str = _dw.dmg_ordinary; break;
					case 2: _dt_str = _dw.dmg_good;     break;
					case 3: _dt_str = _dw.dmg_amazing;  break;
				}
				var _dr = parse_and_roll_damage(_dt_str);
				log_roll(_dw.name + " " + _dn[last_combat_degree] + " dmg", {
					degree_name: _dr.text, degree: 1, total: _dr.total,
					control_roll: _dr.roll, situation_roll: 0,
					situation_step: SIT_STEP_BASE, is_critical_failure: false
				});
			}
		}
		if (btn_clicked("winfo"+string(_weapIdx))) {
			var _wep = hero.weapons[_weapIdx]; var _best = find_best_skill_for_weapon(hero, _wep);
			log_info(_wep.name+": "+_best.skill_name+" ("+_best.use_type+") | "+_wep.dmg_ordinary+"/"+_wep.dmg_good+"/"+_wep.dmg_amazing+" | "+_wep.range_str);
		}
	}
	if (btn_clicked("roll_hit_dmg")) do_hit_damage_roll();

	// Punch/Kick
	var _punch_wep = { name: "Punch", dmg_ordinary: "d4s", dmg_good: "d4+1s", dmg_amazing: "d4+2s", damage_type: DAMAGE_TYPE.LI };
	var _kick_wep = { name: "Kick", dmg_ordinary: "d4+1s", dmg_good: "d4+2s", dmg_amazing: "d4+3s", damage_type: DAMAGE_TYPE.LI };
	var _unarmed_idx = array_length(hero.weapons);
	if (btn_clicked("combat"+string(_unarmed_idx))) quick_roll_skill(hero, build_attack_request(hero, _punch_wep, _rangePenalty));
	if (btn_clicked("combat"+string(_unarmed_idx+1))) quick_roll_skill(hero, build_attack_request(hero, _kick_wep, _rangePenalty));

	// Defensive skills
	var _defSkills = [["Acrobatics","Dodge","dex"],["Unarmed Attack","Power martial arts","str"]];
	for (var _defIdx = 0; _defIdx < 2; _defIdx++) {
		if (btn_clicked("combat"+string(_unarmed_idx+2+_defIdx))) {
			var _didx = find_skill(hero, _defSkills[_defIdx][0], _defSkills[_defIdx][1]);
			if (_didx >= 0) { quick_roll_skill(hero, build_skill_request(hero, _defSkills[_defIdx][0], _defSkills[_defIdx][1], _rangePenalty)); }
			else { var _bidx = find_skill(hero, _defSkills[_defIdx][0], "");
				if (_bidx >= 0) quick_roll_skill(hero, build_skill_request(hero, _defSkills[_defIdx][0], "", _rangePenalty));
				else quick_roll_skill(hero, build_feat_request(hero, _defSkills[_defIdx][2], _defSkills[_defIdx][1], _rangePenalty));
			}
		}
	}

	// Feat checks
	var _feat_names = global.ability_names;
	var _feat_keys = global.ability_keys;
	for (var _statIdx = 0; _statIdx < 6; _statIdx++) {
		if (btn_clicked("feat"+string(_statIdx))) quick_roll_skill(hero, build_feat_request(hero, _feat_keys[_statIdx], _feat_names[_statIdx], _rangePenalty));
	}
}

// ---- PSIONICS TAB (Tab 3) ----
/// @function handle_tab_psionics()
/// @description Psionics tab input — wound/cant-fail toggles, broad and specialty psionic skill rolls.
function handle_tab_psionics() {
	if (btn_clicked("psi_wound_pen")) apply_wound_penalty = !apply_wound_penalty;
	if (btn_clicked("psi_cant_fail")) cant_fail_mode = !cant_fail_mode;

	var _fx_broads = ["Telepathy","Telekinesis","ESP","Biokinesis"];
	var _psi_idx = 0;
	// Wounds handled inside quick_roll_skill
	for (var _broadIdx = 0; _broadIdx < 4; _broadIdx++) {
		if (find_skill(hero, _fx_broads[_broadIdx], "") < 0) continue;
		// Broad roll
		if (btn_clicked("psi"+string(_psi_idx))) quick_roll_skill(hero, build_skill_request(hero, _fx_broads[_broadIdx], "", 0));
		_psi_idx++;
		// Specialty rolls
		for (var _i = 0; _i < array_length(hero.skills); _i++) {
			var _sk = hero.skills[_i];
			if (_sk.broad_skill != _fx_broads[_broadIdx] || _sk.specialty == "") continue;
			if (btn_clicked("psi"+string(_psi_idx))) quick_roll_skill(hero, build_skill_request(hero, _sk.broad_skill, _sk.specialty, 0));
			_psi_idx++;
		}
	}
}

// ---- PERKS & FLAWS TAB (Tab 4) — reads from hero.fx + global.fx_database ----
/// @function handle_tab_perks_flaws()
/// @description Perks/Flaws tab input — sub-tab switch, remove/toggle installed perks/flaws, add from database.
function handle_tab_perks_flaws() {
	if (btn_clicked("pf_perks_tab"))  { pf_view = "perks";  pf_scroll = 0; }
	if (btn_clicked("pf_flaws_tab"))  { pf_view = "flaws";  pf_scroll = 0; }
	if (btn_clicked("pf_racial_tab")) { pf_view = "racial"; pf_scroll = 0; }

	// Racial trait active toggles — for what-if rolls on conditional traits.
	// Indexed by draw order in the hero.fx racial subgroup.
	var _ri2 = 0;
	for (var _fxi = 0; _fxi < array_length(hero.fx); _fxi++) {
		if (hero.fx[_fxi].type != "racial") continue;
		if (btn_clicked("rf_toggle_" + string(_ri2))) {
			hero.fx[_fxi].active = !(hero.fx[_fxi][$ "active"] ?? true);
			hero_dirty = true;
			break;
		}
		_ri2++;
	}

	// Remove perk/flaw buttons (indexed by draw order, same as Draw_64)
	var _pi2 = 0; var _fi2 = 0;
	for (var _fxi = 0; _fxi < array_length(hero.fx); _fxi++) {
		if (hero.fx[_fxi].type == "perk") { if (btn_clicked("prm"+string(_pi2))) { remove_perk_from_hero(hero, hero.fx[_fxi].name); hero_dirty = true; break; } _pi2++; }
		if (hero.fx[_fxi].type == "flaw") { if (btn_clicked("frm"+string(_fi2))) { toggle_flaw_on_hero(hero, hero.fx[_fxi].name); hero_dirty = true; break; } _fi2++; }
	}
	// Add from available list (indexed by fx_database draw order) — gated by active view to prevent stale rect cross-fire
	var _avail_p = 0; var _avail_f = 0;
	for (var _di = 0; _di < array_length(global.fx_database); _di++) {
		if (global.fx_database[_di].type == "perk") { if (pf_view == "perks" && btn_clicked("padd"+string(_avail_p))) { add_perk_to_hero(hero, global.fx_database[_di].name); hero_dirty = true; break; } _avail_p++; }
		if (global.fx_database[_di].type == "flaw") { if (pf_view == "flaws" && btn_clicked("fadd"+string(_avail_f))) { toggle_flaw_on_hero(hero, global.fx_database[_di].name); hero_dirty = true; break; } _avail_f++; }
	}
}

// ---- CYBERTECH TAB (Tab 5) — reads from hero.fx + global.fx_database ----
/// @function handle_tab_cybertech()
/// @description Cybertech tab input — toggle/remove installed implants, expand/add from database at quality tiers.
function handle_tab_cybertech() {
	// Toggle/remove installed cybertech (indexed by cybertech draw order in hero.fx)
	var _ci2 = 0;
	for (var _fxi = 0; _fxi < array_length(hero.fx); _fxi++) {
		if (hero.fx[_fxi].type != "cybertech") continue;
		if (btn_clicked("cyber_toggle_"+string(_ci2))) {
			hero.fx[_fxi].active = !(hero.fx[_fxi][$ "active"] ?? true);
			hero_dirty = true;
		}
		if (btn_clicked("cyber_rm_"+string(_ci2))) { remove_cybertech_from_hero(hero, hero.fx[_fxi].name); hero_dirty = true; break; }
		_ci2++;
	}
	// Expand/collapse + add from fx_database (indexed by cybertech draw order)
	var _gi2 = 0;
	for (var _di = 0; _di < array_length(global.fx_database); _di++) {
		if (global.fx_database[_di].type != "cybertech") { continue; }
		if (btn_clicked("cyber_name_"+string(_gi2)))
			cyber_expanded = (cyber_expanded == _gi2) ? -1 : _gi2;
		var _quals = ["O", "G", "A"];
		for (var _qi = 0; _qi < 3; _qi++) {
			if (btn_clicked("cyber_add_"+string(_gi2)+"_"+_quals[_qi])) {
				add_cybertech_to_hero(hero, global.fx_database[_di].name, _quals[_qi]);
				hero_dirty = true;
			}
		}
		_gi2++;
	}
}

// handle_tab_info() REMOVED — empty function, info tab is display-only

// ---- ROLL LOG TAB (Tab 6) ----
/// @function handle_tab_rolllog()
/// @description Roll Log tab input — scroll, copy, and (when connected) chat send.
function handle_tab_rolllog() {
	if (btn_clicked("rl_scroll_up")) rolllog_scroll = max(0, rolllog_scroll-1);
	if (btn_clicked("rl_scroll_dn")) rolllog_scroll++;
	// Copy buttons for each visible entry
	var _rl_total = array_length(rolllog_entries);
	var _rl_vis = min(30, _rl_total);
	for (var _ci = 0; _ci < _rl_vis; _ci++) {
		if (btn_clicked("rl_copy" + string(_ci))) {
			var _cidx = _rl_total - 1 - _ci - rolllog_scroll;
			if (_cidx >= 0 && _cidx < _rl_total) {
				var _entry = rolllog_entries[_cidx];
				if (is_string(_entry)) {
					clipboard_set_text(_entry);
				} else if (is_struct(_entry)) {
					if (_entry.is_chat) {
						clipboard_set_text("[" + _entry.sender_name + "]: " + _entry.chat_text);
					} else {
						clipboard_set_text(_entry.sender_name + " - " + _entry.skill_name + " " + _entry.degree_name + " (" + string(_entry.total) + ")");
					}
				}
				status_msg = "Copied to clipboard!"; status_timer = 90;
			}
		}
	}

	// Chat input (multiplayer only)
	if (net_is_connected()) {
		if (btn_clicked("rl_chat_field")) net_input_focus = "chat";
		if (btn_clicked("rl_chat_send") && net_chat_buffer != "") {
			net_send_chat(net_chat_buffer);
			// Also log locally as our own chat so the sender sees it too
			var _self_entry = {
				sender_name: net_player_name == "" ? "Local" : net_player_name,
				character_name: "",
				skill_name: "",
				degree_name: "",
				degree: 0,
				total: 0,
				mod_str: "",
				modifiers: [],
				is_remote: false,
				is_chat: true,
				chat_text: net_chat_buffer,
				timestamp: current_time
			};
			array_insert(rolllog_entries, 0, _self_entry);
			if (array_length(rolllog_entries) > max_log_entries) array_pop(rolllog_entries);
			net_chat_buffer = "";
		}
	}
}

// ---- SKILLS TAB (Tab 0) ----
/// @function handle_tab_character()
/// @description Character/Skills tab input — skill list click/+/-, perk/flaw radio toggles, scroll, skill browser, untrained feat rolls.
function handle_tab_character() {
	// Click any durability text to jump to the Combat tab
	if (btn_clicked("char_durability_goto_combat")) {
		current_tab = 2;
		staged_roll = undefined;
		situation_step = SIT_STEP_BASE;
		exit;
	}

	// Stat group button clicks — switch which ability's skills are shown
	var _ab_keys = global.ability_keys;
	for (var _ai = 0; _ai < 6; _ai++) {
		if (btn_clicked("stat_group_"+_ab_keys[_ai])) { active_stat_group = _ab_keys[_ai]; scroll_offset = 0; }
	}

	// Filtered skill list — use skill_index_map built during draw
	var _fsc = array_length(skill_index_map); // filtered skill count
	var _lineHeight = 18;
	var _fend = min(scroll_offset + max_visible_skills, _fsc);

	// Skill +/-/Roll buttons — visible index maps to hero.skills via skill_index_map
	var _btn_handled = false;
	for (var _vi = scroll_offset; _vi < _fend; _vi++) {
		if (btn_clicked("skp"+string(_vi))) {
			var _real = skill_index_map[_vi];
			increase_skill_rank(hero, _real); update_hero(hero); hero_dirty = true; _btn_handled = true; break;
		}
		if (btn_clicked("skm"+string(_vi))) {
			var _real = skill_index_map[_vi];
			decrease_skill_rank(hero, _real); update_hero(hero); hero_dirty = true;
			if (selected_skill >= array_length(hero.skills)) selected_skill = max(0, array_length(hero.skills)-1);
			_btn_handled = true; break;
		}
		if (btn_clicked("skroll"+string(_vi))) {
			var _real = skill_index_map[_vi];
			var _sk_roll = hero.skills[_real];
			quick_roll_skill(hero, build_skill_request(hero, _sk_roll.broad_skill, _sk_roll.specialty, 0));
			_btn_handled = true; break;
		}
	}
	// Row selection — click on name area (not +/- buttons)
	if (!_btn_handled && device_mouse_y_to_gui(0) >= skill_list_start_y) {
		var _clickedRow = floor((device_mouse_y_to_gui(0) - skill_list_start_y) / _lineHeight) + scroll_offset;
		if (_clickedRow >= 0 && _clickedRow < _fsc && device_mouse_x_to_gui(0) < panel_left_x + panel_left_w - 60)
			selected_skill = skill_index_map[_clickedRow];
	}
	// Perk/flaw/racial radio toggles (reads from hero.fx, indexed by per-type draw order)
	var _ptog = 0; var _ftog = 0; var _rtog = 0;
	for (var _fxi = 0; _fxi < array_length(hero.fx); _fxi++) {
		var _fxEntry = hero.fx[_fxi];
		if (_fxEntry.type == "perk") {
			if (btn_clicked("pf_toggle_p"+string(_ptog))) { _fxEntry.active = !_fxEntry.active; hero_dirty = true; }
			_ptog++;
		} else if (_fxEntry.type == "flaw") {
			if (btn_clicked("pf_toggle_f"+string(_ftog))) { _fxEntry.active = !_fxEntry.active; hero_dirty = true; }
			_ftog++;
		} else if (_fxEntry.type == "racial") {
			if (btn_clicked("pf_toggle_r"+string(_rtog))) { _fxEntry.active = !_fxEntry.active; hero_dirty = true; }
			_rtog++;
		}
	}

	if (btn_clicked("scroll_up")) scroll_offset = max(0, scroll_offset-1);
	if (btn_clicked("scroll_dn")) scroll_offset = min(max(0, _fsc-max_visible_skills), scroll_offset+1);
	if (btn_clicked("add_skills")) { browser_open = true; browser_list = build_browser_list(hero, active_stat_group); browser_selected = 0; browser_scroll = 0; }
	if (btn_clicked("untrained_toggle")) untrained_expanded = !untrained_expanded;
	if (untrained_expanded) {
		var _sg_idx = array_get_index(global.ability_keys, active_stat_group);
		if (_sg_idx >= 0) {
			if (btn_clicked("utfeat0")) prepare_roll(hero, build_feat_request(hero, global.ability_keys[_sg_idx], global.ability_names[_sg_idx], 0));
		}
	}
}


/// @function handle_tab_grid()
/// @description Grid tab input — programs/computer/builder sub-tabs, install/remove programs, select computer+processor, custom builds.
function handle_tab_grid() {
	if (btn_clicked("grid_programs_tab")) { grid_view = "programs"; grid_expanded = -1; grid_comp_expanded = -1; }
	if (btn_clicked("grid_computer_tab")) { grid_view = "computer"; grid_expanded = -1; grid_comp_expanded = -1; }
	if (btn_clicked("grid_builder_tab")) { grid_view = "builder"; grid_expanded = -1; grid_comp_expanded = -1; }
	if (btn_clicked("grid_toggle_add")) { grid_adding = !grid_adding; grid_expanded = -1; grid_comp_expanded = -1; }

	if (grid_view == "programs") {
		// Remove installed program
		for (var _i = 0; _i < array_length(hero.deck.programs); _i++) {
			if (btn_clicked("grid_prm_"+string(_i))) {
				array_delete(hero.deck.programs, _i, 1);
				hero_dirty = true; break;
			}
		}
		// Available programs (when adding)
		if (grid_adding) {
			var _types = ["operator", "hacking", "utility"];
			var _gi = 0;
			for (var _tc = 0; _tc < 3; _tc++) {
				for (var _di = 0; _di < array_length(global.programs); _di++) {
					var _prog = global.programs[_di];
					if (_prog.type != _types[_tc]) continue;
					if ((_prog[$ "pl"] ?? 0) > campaign_pl) { _gi++; continue; }
					if (btn_clicked("grid_pname_"+string(_gi)))
						grid_expanded = (grid_expanded == _gi) ? -1 : _gi;
					// Add at quality
					var _quals = ["M","O","G","A"];
					for (var _qi = 0; _qi < 4; _qi++) {
						if (btn_clicked("grid_padd_"+string(_gi)+"_"+_quals[_qi])) {
							// Check not already installed
							var _already = false;
							for (var _k = 0; _k < array_length(hero.deck.programs); _k++) {
								if (hero.deck.programs[_k].name == _prog.name) { _already = true; break; }
							}
							if (!_already) {
								// Check slot capacity
								var _slots = get_deck_slots(hero);
								var _used = _slots.used;
								var _mem = _slots.total;
								var _slots_needed = _prog[$ "slots"] ?? 1;
								if (is_string(_slots_needed)) _slots_needed = 1;
								if (_used + _slots_needed <= _mem) {
									array_push(hero.deck.programs, { name: _prog.name, quality: _quals[_qi] });
									hero_dirty = true;
								}
							}
						}
					}
					_gi++;
				}
			}
		}
	}

	if (grid_view == "computer") {
		for (var _ci = 0; _ci < array_length(global.computers); _ci++) {
			var _cd = global.computers[_ci];
			var _is_cur = ((hero.deck[$ "computer"] ?? "None") == _cd.name);
			if (_is_cur) continue;
			// Toggle expand/collapse on Select click
			if (btn_clicked("grid_csel_"+string(_ci))) {
				grid_comp_expanded = (grid_comp_expanded == _ci) ? -1 : _ci;
			}
			// Quality buttons (only when this computer is expanded)
			if (grid_comp_expanded == _ci) {
				for (var _pi = 0; _pi < array_length(_cd.processors); _pi++) {
					if (btn_clicked("grid_cqual_"+string(_ci)+"_"+_cd.processors[_pi])) {
						hero.deck.computer = _cd.name;
						hero.deck.processor = _cd.processors[_pi];
						hero_dirty = true;
						grid_comp_expanded = -1;
					}
				}
			}
		}
	}

	if (grid_view == "builder") {
		// Remove homebrew programs (same button keys as programs view)
		for (var _i = 0; _i < array_length(hero.deck.programs); _i++) {
			if (btn_clicked("grid_prm_"+string(_i))) {
				array_delete(hero.deck.programs, _i, 1);
				hero_dirty = true; break;
			}
		}
		if (btn_clicked("grid_build_custom")) {
			// Build a default custom program, then open the inline editor on its name.
			// Replaces the chain of 4 get_string popups.
			var _default_name = "Custom Program " + string(array_length(hero.deck.programs) + 1);
			array_push(hero.deck.programs, { name: _default_name, quality: "custom" });
			array_push(global.programs, { name: _default_name, type: "utility", pl: 0, slots: 1, description: "Custom program." });
			global.program_lookup[$ _default_name] = array_length(global.programs) - 1;
			hero_dirty = true;
			var _newProgIdx = array_length(hero.deck.programs) - 1;
			open_text_modal("Program name:", hero.deck.programs[_newProgIdx], "name", 50, function() { obj_game.hero_dirty = true; });
		}
	}
}
