/// @description All input — mouse driven. Uses scr_ui_helpers for all rolls and button checks.

var _click = mouse_check_button_pressed(mb_left);
var _wheel = mouse_wheel_up() - mouse_wheel_down();

// GLOBAL EXIT — works on EVERY screen, saves before closing
if (_click && btn_clicked("exit_app")) {
	if (hero != undefined) { save_hero_and_track(hero); hero_dirty = false; }
	game_end();
	exit;
}

if (status_timer > 0) status_timer--;
if (browser_flash_timer > 0) browser_flash_timer--;

// Multiplayer heartbeat — keeps TCP connection alive through idle NATs.
if (net_connected) net_heartbeat_tick();

// Connection timeout — promote stuck "connecting" state to "error".
net_check_timeout();

// Roll animation — just a visual timer, actual roll happens in execute_staged_roll
if (is_rolling) {
	roll_anim_timer--;
	if (roll_anim_timer <= 0) {
		is_rolling = false;
		execute_staged_roll();
	}
}

// ============================================================
// PUSH CHARACTER PICKER — runs BEFORE everything so it intercepts input
// when GM clicks Push on a party row. Eats clicks until closed.
// ============================================================
if (push_picker_open) {
	if (keyboard_check_pressed(vk_escape)) { push_picker_open = false; exit; }
	if (_click) {
		if (btn_clicked("pushpick_cancel")) { push_picker_open = false; exit; }
		var _ppl2 = net_get_players();
		for (var _ppi2 = 0; _ppi2 < array_length(_ppl2); _ppi2++) {
			var _pp2 = _ppl2[_ppi2];
			var _pp_name2 = is_struct(_pp2) ? (_pp2[$ "name"] ?? "") : string(_pp2);
			var _pp_host2 = is_struct(_pp2) ? (_pp2[$ "is_host"] ?? false) : false;
			if (_pp_host2 || _pp_name2 == "") continue;
			if (btn_clicked("pushpick_player_" + string(_ppi2))) {
				if (push_picker_party_idx >= 0 && push_picker_party_idx < array_length(global.party)) {
					var _push_stat = global.party[push_picker_party_idx];
					net_push_character_to(_pp_name2, _push_stat);
					_push_stat.last_pushed_to = _pp_name2; // hook for Phase 5 auto-push
					save_campaign();
					status_msg = "Pushed " + _push_stat.name + " to " + _pp_name2; status_timer = 180;
				}
				push_picker_open = false;
				exit;
			}
		}
	}
	exit; // popup eats input
}

// ============================================================
// CHARGEN WIZARD — runs BEFORE welcome screen so it can intercept input
// when game_state is still "welcome" and hero is undefined.
// ============================================================
if (chargen_open) {
	// Reset hover each frame; per-step draw repopulates if cursor is over a panel
	chargen_hover_species = -1;

	// Escape on any screen = cancel + close
	if (keyboard_check_pressed(vk_escape)) { chargen_reset(); chargen_open = false; exit; }

	// Mouse wheel scrolls the career list on Screen 3
	if (_wheel != 0 && chargen_step == 2 && !chargen_show_diplomat_sub) {
		var _careers_w = (chargen_pick_prof >= 0) ? get_careers_for_profession(chargen_pick_prof) : [];
		chargen_career_scroll = clamp(chargen_career_scroll - _wheel, 0, max(0, array_length(_careers_w) - 4));
	}

	if (_click) {
		// Always-available buttons
		if (btn_clicked("chargen_cancel"))     { chargen_reset(); chargen_open = false; exit; }
		if (btn_clicked("chargen_random_all")) { chargen_finalize(chargen_pick_species, chargen_pick_prof, chargen_pick_career, chargen_pick_sec_prof, chargen_pick_sec_career); exit; }
		if (btn_clicked("chargen_back")) {
			if (chargen_step == 1 && chargen_show_diplomat_sub) {
				chargen_show_diplomat_sub = false;
			} else if (chargen_step == 2) {
				chargen_step = 1;
				if (chargen_pick_prof == PROFESSION.DIPLOMAT) chargen_show_diplomat_sub = true;
			} else if (chargen_step == 1) {
				chargen_step = 0;
				chargen_show_diplomat_sub = false;
			}
			exit;
		}

		// Per-step input
		if (chargen_step == 0) {
			// Race panels
			for (var _ri = 0; _ri < SPECIES.COUNT; _ri++) {
				if (btn_clicked("chargen_race_" + string(_ri))) { chargen_pick_species = _ri; break; }
			}
			if (btn_clicked("chargen_race_random")) chargen_pick_species = -2;
			if (btn_clicked("chargen_next") && chargen_pick_species != -1) {
				chargen_step = 1;
				exit;
			}
		}
		else if (chargen_step == 1) {
			if (chargen_show_diplomat_sub) {
				var _opts = chargen_secondary_prof_options();
				for (var _spi = 0; _spi < array_length(_opts); _spi++) {
					if (btn_clicked("chargen_secprof_" + string(_spi))) { chargen_pick_sec_prof = _opts[_spi]; break; }
				}
				if (btn_clicked("chargen_secprof_random")) chargen_pick_sec_prof = -2;
				if (btn_clicked("chargen_next") && chargen_pick_sec_prof != -1) {
					chargen_step = 2;
					chargen_pick_career = -1; // reset career picks when prof changes
					exit;
				}
			} else {
				for (var _pi = 0; _pi < 5; _pi++) {
					if (btn_clicked("chargen_prof_" + string(_pi))) {
						if (chargen_pick_prof != _pi) {
							chargen_pick_prof = _pi;
							chargen_pick_career = -1;
							chargen_pick_sec_prof = -1;
						}
						break;
					}
				}
				if (btn_clicked("chargen_prof_random")) {
					chargen_pick_prof = -2;
					chargen_pick_career = -1;
					chargen_pick_sec_prof = -1;
				}
				if (btn_clicked("chargen_next") && chargen_pick_prof != -1) {
					if (chargen_pick_prof == PROFESSION.DIPLOMAT) {
						chargen_show_diplomat_sub = true;
					} else {
						chargen_step = 2;
					}
					exit;
				}
			}
		}
		else if (chargen_step == 2) {
			var _careers_step3 = (chargen_pick_prof >= 0) ? get_careers_for_profession(chargen_pick_prof) : [];
			for (var _ci = 0; _ci < array_length(_careers_step3); _ci++) {
				if (btn_clicked("chargen_career_" + string(_ci))) { chargen_pick_career = _ci; break; }
			}
			if (btn_clicked("chargen_career_random")) chargen_pick_career = -2;
			if (btn_clicked("chargen_next") && chargen_pick_career != -1) {
				chargen_finalize(chargen_pick_species, chargen_pick_prof, chargen_pick_career, chargen_pick_sec_prof, chargen_pick_sec_career);
				exit;
			}
		}
	}
	exit; // wizard always swallows input
}

// ============================================================
// WELCOME SCREEN
// ============================================================
if (game_state == "welcome") {
	if (_wheel != 0) changelog_scroll = max(0, changelog_scroll - _wheel * 40);

	// ---- CHANGELOG MODAL — runs FIRST, eats input, view toggle + page nav + close ----
	if (changelog_open) {
		// Escape closes (and eats the keypress so it doesn't bubble to other handlers)
		if (keyboard_check_pressed(vk_escape)) {
			changelog_open = false;
		}
		// View toggle: Current (latest 10) vs Past (paginated 122)
		if (_click && btn_clicked("changelog_view_current")) { changelog_view = "current"; changelog_scroll = 0; exit; }
		if (_click && btn_clicked("changelog_view_past"))    { changelog_view = "past";    changelog_scroll = 0; changelog_page = 0; exit; }
		// Past-view page navigation (auto-clamps in Draw, but explicitly bounded here too)
		if (changelog_view == "past") {
			var _cl_total = (global.changelog[$ "entries"] != undefined) ? array_length(global.changelog.entries) : 0;
			var _cl_past = max(0, _cl_total - CHANGELOG_CURRENT_COUNT);
			var _cl_max_page = max(0, ceil(_cl_past / CHANGELOG_PAGE_SIZE) - 1);
			if (_click && btn_clicked("changelog_newer")) { changelog_page = max(0, changelog_page - 1); changelog_scroll = 0; exit; }
			if (_click && btn_clicked("changelog_older")) { changelog_page = min(_cl_max_page, changelog_page + 1); changelog_scroll = 0; exit; }
		}
		// Explicit close button — eats the click
		if (_click && btn_clicked("changelog_close")) { changelog_open = false; exit; }
		// Click-outside to close — closes the modal AND lets the click pass through
		// to the menu button underneath. So clicking New/Load while the modal is up
		// dismisses the modal AND opens the wizard / load dialog in one click.
		if (_click && variable_struct_exists(btn, "changelog_modal_area") && !btn_clicked("changelog_modal_area")) {
			changelog_open = false;
			// Do NOT exit — let the click fall through to the welcome button handlers below
		}
		// If the modal is still open after all click checks, eat the click (it landed
		// inside the modal but didn't hit any of its buttons)
		if (changelog_open) exit;
	}

	// ---- MULTIPLAYER POPUPS (must run before other welcome handlers) ----
	// Host popup
	if (net_host_popup_open) {
		if (_click && btn_clicked("net_name_field")) net_input_focus = "name";
		if (keyboard_check_pressed(vk_backspace) && net_input_focus == "name") {
			if (string_length(net_player_name_input) > 0)
				net_player_name_input = string_copy(net_player_name_input, 1, string_length(net_player_name_input)-1);
		}
		if (net_input_focus == "name" && keyboard_string != "") {
			net_player_name_input += keyboard_string;
			if (string_length(net_player_name_input) > 20)
				net_player_name_input = string_copy(net_player_name_input, 1, 20);
			keyboard_string = "";
		}
		// HOST button — only fires when idle/error and a name is typed
		if (_click && btn_clicked("net_host_confirm") && net_player_name_input != "" &&
			(net_handshake_state == "idle" || net_handshake_state == "error")) {
			net_host_session(net_player_name_input);
		}
		// CONTINUE button — appears once we're in_session, dismisses popup but keeps the session
		if (_click && btn_clicked("net_host_continue") && net_handshake_state == "in_session") {
			net_host_popup_open = false;
			net_input_focus = "";
		}
		// CANCEL — full reset, kills the socket and popup
		if (_click && btn_clicked("net_host_cancel")) {
			net_full_reset();
			net_host_popup_open = false;
		}
		exit;
	}

	// Join popup
	if (net_join_popup_open) {
		if (_click && btn_clicked("net_code_field")) net_input_focus = "code";
		if (_click && btn_clicked("net_name_field2")) net_input_focus = "name";
		if (keyboard_check_pressed(vk_backspace)) {
			if (net_input_focus == "code" && string_length(net_join_code_input) > 0)
				net_join_code_input = string_copy(net_join_code_input, 1, string_length(net_join_code_input)-1);
			else if (net_input_focus == "name" && string_length(net_player_name_input) > 0)
				net_player_name_input = string_copy(net_player_name_input, 1, string_length(net_player_name_input)-1);
		}
		if (keyboard_string != "") {
			if (net_input_focus == "code") {
				net_join_code_input += string_upper(keyboard_string);
				if (string_length(net_join_code_input) > 6)
					net_join_code_input = string_copy(net_join_code_input, 1, 6);
			} else if (net_input_focus == "name") {
				net_player_name_input += keyboard_string;
				if (string_length(net_player_name_input) > 20)
					net_player_name_input = string_copy(net_player_name_input, 1, 20);
			}
			keyboard_string = "";
		}
		if (_click && btn_clicked("net_join_confirm") && net_player_name_input != "" && string_length(net_join_code_input) == 6 &&
			(net_handshake_state == "idle" || net_handshake_state == "error")) {
			net_join_session(net_join_code_input, net_player_name_input);
		}
		// Auto-close join popup once we successfully join
		if (net_handshake_state == "in_session") {
			net_join_popup_open = false;
			net_input_focus = "";
		}
		if (_click && btn_clicked("net_join_cancel")) {
			net_full_reset();
			net_join_popup_open = false;
		}
		exit;
	}

	if (!_click) exit;

	// Accessibility popup
	if (accessibility_open) {
		// Window mode buttons
		var _wm_modes = ["fullscreen", "windowed", "half"];
		for (var _wi = 0; _wi < 3; _wi++) {
			if (btn_clicked("wm_"+string(_wi))) {
				window_mode = _wm_modes[_wi];
				// Apply window mode
				var _dw = display_get_width(); var _dh = display_get_height();
				if (window_mode == "fullscreen") {
					window_set_fullscreen(true); gui_w = _dw; gui_h = _dh;
				} else if (window_mode == "half") {
					window_set_fullscreen(false);
					gui_w = floor(_dw/2); gui_h = floor(_dh*0.85);
					window_set_size(gui_w, gui_h);
					window_set_position(floor(_dw/4), floor(_dh*0.05));
				} else {
					window_set_fullscreen(false);
					gui_w = floor(_dw*0.8); gui_h = floor(_dh*0.85);
					window_set_size(gui_w, gui_h); window_center();
				}
				display_set_gui_size(gui_w, gui_h);
				if (surface_exists(application_surface)) surface_resize(application_surface, gui_w, gui_h);
				room_width = gui_w; room_height = gui_h;
				// Rescale layout
				var _pad = 12;
				panel_left_x = _pad;
				panel_left_w = floor(gui_w*0.6) - _pad;
				panel_right_x = panel_left_x + panel_left_w + _pad;
				panel_right_w = gui_w - panel_right_x - _pad;
				max_visible_skills = max(8, floor((gui_h-400)/18));
				// Save preference
				if (global.config[$ "accessibility"] == undefined) global.config.accessibility = {};
				global.config.accessibility.window_mode = window_mode;
				write_json("config.json", global.config);
				status_msg = "Window: " + window_mode; status_timer = 90;
			}
		}

		var _modes = ["normal", "protanopia", "deuteranopia", "tritanopia", "greyscale", "custom"];
		for (var _mi = 0; _mi < 6; _mi++) {
			if (btn_clicked("access_mode"+string(_mi))) {
				colorblind_mode = _modes[_mi];
				apply_color_profile(colorblind_mode);
				status_msg = "Color mode: " + colorblind_mode; status_timer = 90;
			}
		}
		// Custom palette picks
		if (colorblind_mode == "custom") {
			var _palette = ["#53d769","#ff4444","#ffcc00","#00bfff","#ff6b9d","#9b59b6","#e67e22",
			                "#1abc9c","#3498db","#e74c3c","#f39c12","#2ecc71","#ffffff","#cccccc","#888888","#333333"];
			var _ckeys = ["good", "failure", "warning", "amazing", "highlight"];
			if (global.config.color_profiles[$ "custom"] == undefined) {
				global.config.color_profiles.custom = { good: "#53d769", failure: "#ff4444", warning: "#ffcc00", amazing: "#00bfff", highlight: "#53d769" };
			}
			var _custom = global.config.color_profiles.custom;
			for (var _ci = 0; _ci < 5; _ci++) {
				// Click main swatch — cycle to next palette color
				if (btn_clicked("custom_color_"+string(_ci))) {
					var _cur = _custom[$ _ckeys[_ci]];
					var _next_idx = 0;
					for (var _pi = 0; _pi < 16; _pi++) {
						if (_palette[_pi] == _cur) { _next_idx = (_pi + 1) % 16; break; }
					}
					_custom[$ _ckeys[_ci]] = _palette[_next_idx];
					apply_color_profile("custom");
				}
				// Click palette swatch — pick that specific color
				for (var _pi = 0; _pi < 16; _pi++) {
					if (btn_clicked("cpal_"+string(_ci)+"_"+string(_pi))) {
						_custom[$ _ckeys[_ci]] = _palette[_pi];
						apply_color_profile("custom");
					}
				}
			}
		}
		if (btn_clicked("access_close")) accessibility_open = false;
		exit;
	}

	// Accessibility button
	if (btn_clicked("welcome_access")) { accessibility_open = true; exit; }
	if (btn_clicked("welcome_gm_toggle")) { gm_mode = !gm_mode; gm_state = "gm"; status_msg = gm_mode ? "GM Mode activated" : "Player Mode activated"; status_timer = 90; }

	// Multiplayer host/join — open popups (full reset first to clear any stale state)
	if (btn_clicked("welcome_host")) {
		net_full_reset();
		net_host_popup_open = true;
		net_input_focus = "name";
		exit;
	}
	if (btn_clicked("welcome_join")) {
		net_full_reset();
		net_join_popup_open = true;
		net_input_focus = "code";
		exit;
	}

	// Exit Session — disconnects from the active session and clears state
	if (btn_clicked("welcome_exit_session")) {
		var _was_host = net_is_host();
		net_disconnect();
		status_msg = _was_host ? "Stopped hosting" : "Left session"; status_timer = 120;
		exit;
	}

	// v0.62.0: Continue Session (GM) — re-host with the same player name from last_session.json
	if (btn_clicked("welcome_continue_session")) {
		if (variable_global_exists("last_session_data") && global.last_session_data != undefined) {
			var _ls = global.last_session_data;
			var _host_name = _ls[$ "host_name"] ?? "";
			if (_host_name != "") {
				// Restore round counter from saved session
				current_round = _ls[$ "current_round"] ?? 1;
				net_full_reset();
				net_player_name_input = _host_name;
				net_host_session(_host_name);
				net_host_popup_open = true;
				status_msg = "Continuing session as " + _host_name; status_timer = 180;
			} else {
				status_msg = "Continue: no saved host name"; status_timer = 180;
			}
		}
		exit;
	}

	// v0.62.0: Rejoin Session (player) — open join popup with last code + name pre-filled
	if (btn_clicked("welcome_rejoin_session")) {
		if (variable_global_exists("last_join_data") && global.last_join_data != undefined) {
			var _lj = global.last_join_data;
			net_full_reset();
			net_player_name_input = _lj[$ "player_name"] ?? "";
			net_join_code_input = _lj[$ "last_session_code"] ?? "";
			net_join_popup_open = true;
			net_input_focus = "code";
			status_msg = "Rejoin: pre-filled from last session. GM may have a new code."; status_timer = 240;
		}
		exit;
	}

	// Exit handled globally below

	// Continue button — load last character and go to sheet
	if (btn_clicked("welcome_continue") && last_char_path != "") {
		// Try the stored path first, then try relative to save_path
		var _loaded = load_character_from_path(last_char_path);
		if (_loaded == undefined && string_pos(global.save_path, last_char_path) == 0) {
			// Path might be absolute but file moved — try just the filename
			var _fname = string_copy(last_char_path, string_length(global.save_path)+1, string_length(last_char_path));
			_loaded = load_character_from_path(global.save_path + _fname);
		}
		if (_loaded == undefined && !file_exists(last_char_path)) {
			// Try characters/ subfolder as fallback
			var _parts = last_char_path;
			var _slash = max(string_last_pos("/", _parts), string_last_pos("\\", _parts));
			if (_slash > 0) {
				var _just_file = string_copy(_parts, _slash+1, string_length(_parts)-_slash);
				_loaded = load_character_from_path(global.save_path + _just_file);
			}
		}
		if (_loaded != undefined) {
			hero = _loaded;
			update_hero(hero); game_state = "sheet";
			add_to_party(hero);
			selected_skill = 0; scroll_offset = 0; rolllog_dirty = true;
			// Update the stored path to current save location
			var _current_path = global.save_path + sanitize_hero_filename(hero.name) + ".json";
			add_recent_character(hero.name, _current_path);
			last_char_path = _current_path;
			status_msg = "Welcome back, " + hero.name; status_timer = 120;
		} else {
			status_msg = "Could not load: " + last_char_path; status_timer = 180;
			last_char_path = "";  // Clear broken path so button hides
		}
	}

	// Recent character buttons
	var _rc_list = global.recent_characters.recent;
	for (var _ri = 0; _ri < array_length(_rc_list); _ri++) {
		if (btn_clicked("recent" + string(_ri))) {
			var _rpath = _rc_list[_ri].path;
			var _loaded = load_character_from_path(_rpath);
			// Fallback: try just the filename in current save_path
			if (_loaded == undefined) {
				var _slash = max(string_last_pos("/", _rpath), string_last_pos("\\", _rpath));
				if (_slash > 0) _loaded = load_character_from_path(global.save_path + string_copy(_rpath, _slash+1, string_length(_rpath)-_slash));
			}
			if (_loaded != undefined) {
				hero = _loaded; update_hero(hero); game_state = "sheet";
				add_to_party(hero);
				selected_skill = 0; scroll_offset = 0; rolllog_dirty = true;
				var _current_path = global.save_path + sanitize_hero_filename(hero.name) + ".json";
				add_recent_character(hero.name, _current_path);
				status_msg = "Loaded: " + hero.name; status_timer = 90;
			} else {
				status_msg = "Could not load: " + _rc_list[_ri].name; status_timer = 180;
			}
		}
	}

	if (btn_clicked("welcome_new")) {
		chargen_reset();
		chargen_open = true;
		// Stay on welcome screen — wizard renders as overlay. game_state will switch
		// to "sheet" inside chargen_finalize() once the hero is generated.
	}
	if (btn_clicked("welcome_load")) {
		var _imp = statblock_import();
		if (_imp != undefined) { hero = _imp; update_hero(hero); game_state = "sheet"; add_to_party(hero); selected_skill = 0; }
	}
	if (btn_clicked("welcome_voss")) {
		var _voss = load_character_from_path(global.save_path + "voss.json");
		if (_voss != undefined) { hero = _voss; } else { hero = create_statblock("Sergeant Voss", PROFESSION.COMBAT_SPEC, "Infantry Soldier"); }
		update_hero(hero); game_state = "sheet";
		add_to_party(hero);
		selected_skill = 0; scroll_offset = 0;
		var _lp = get_roll_log_path(hero); if (file_exists(_lp)) file_delete(_lp);
		roll_log = []; rolllog_dirty = true;
		add_recent_character(hero.name, "characters/voss.json");
		status_msg = "Loaded Sgt Voss (log reset)"; status_timer = 90;
	}
	// Reopen the changelog modal — re-reads from disk so live edits show up
	if (btn_clicked("changelog_open_btn")) {
		reload_changelog();
		changelog_open = true;
		changelog_view = "current";
		changelog_scroll = 0;
		changelog_page = 0;
	}
	exit;
}

if (hero == undefined) exit;

// ============================================================
// SKILL BROWSER
// ============================================================
if (browser_open) {
	if (_wheel != 0) browser_scroll = clamp(browser_scroll - _wheel, 0, max(0, array_length(browser_list) - browser_max_visible));
	if (_click) {
		// Stat group switching inside browser
		var _bsg_keys = global.ability_keys;
		for (var _bai = 0; _bai < 6; _bai++) {
			if (btn_clicked("browser_stat_"+_bsg_keys[_bai])) {
				active_stat_group = _bsg_keys[_bai]; browser_scroll = 0;
				browser_list = build_browser_list(hero, active_stat_group);
			}
		}
		// Remove buttons
		for (var _ri = 0; _ri < array_length(browser_list); _ri++) {
			var _e = browser_list[_ri];
			if (_e.type == "broad" && _e.owned && btn_clicked("brm"+string(_ri))) {
				for (var _j = array_length(hero.skills)-1; _j >= 0; _j--)
					if (hero.skills[_j].broad_skill == _e.broad) array_delete(hero.skills, _j, 1);
				update_hero(hero); hero_dirty = true;
				selected_skill = clamp(selected_skill, 0, max(0, array_length(hero.skills)-1));
				browser_list = build_browser_list(hero, active_stat_group);
				browser_flash_timer = 40; browser_flash_name = "Removed: " + _e.broad; break;
			}
			if (_e.type == "specialty" && btn_clicked("srm"+string(_ri))) {
				var _si = find_skill(hero, _e.broad, _e.specialty);
				if (_si >= 0) array_delete(hero.skills, _si, 1);
				update_hero(hero); hero_dirty = true;
				selected_skill = clamp(selected_skill, 0, max(0, array_length(hero.skills)-1));
				browser_list = build_browser_list(hero, active_stat_group);
				browser_flash_timer = 40; browser_flash_name = "Removed: " + _e.specialty; break;
			}
		}
		// Add skills
		if (btn[$ "browser_list_y"] != undefined) {
			var _ly2 = btn.browser_list_y; var _bx2 = 40; var _bw2 = display_get_gui_width()-80;
			var _mx2 = device_mouse_x_to_gui(0); var _my2 = device_mouse_y_to_gui(0);
			if (_mx2 >= _bx2 && _mx2 <= _bx2+_bw2 && _my2 >= _ly2) {
				var _ci = floor((_my2-_ly2)/18) + browser_scroll;
				if (_ci >= 0 && _ci < array_length(browser_list)) {
					var _e = browser_list[_ci]; browser_selected = _ci;
					if (_e.type == "add") {
						add_specialty_rank0(hero, _e.broad, _e.specialty);
						var _ni = find_skill(hero, _e.broad, _e.specialty);
						if (_ni >= 0) increase_skill_rank(hero, _ni);
						browser_flash_timer = 40; browser_flash_name = _e.specialty;
						update_hero(hero); hero_dirty = true; browser_list = build_browser_list(hero, active_stat_group);
					} else if (_e.type == "broad" && !_e.owned) {
						add_broad_skill_to_hero(hero, _e.broad);
						browser_flash_timer = 40; browser_flash_name = _e.broad;
						update_hero(hero); hero_dirty = true; browser_list = build_browser_list(hero, active_stat_group);
					}
				}
			}
		}
		if (btn_clicked("browser_close")) browser_open = false;
	}
	exit;
}

// ============================================================
// MAIN SCREEN
// ============================================================

// Scroll handling (mode-aware)
if (gm_mode && gm_state == "gm") {
	// v0.62.0 tab indices: 0=Party 1=NPCs 2=Encounter 3=Factions 4=Campaign 5=Sessionlog 6=Resources
	// Campaign (4) and Resources (6) use the gm_roster_scroll for their scrollable content
	if (_wheel != 0 && (gm_tab == 4 || gm_tab == 6)) gm_roster_scroll = max(0, gm_roster_scroll - _wheel);
	// Sessionlog (5) has its own scroll into the entries
	if (_wheel != 0 && gm_tab == 5) {
		var _max_sl = max(0, array_length(session_log_entries) - session_log_max_visible);
		session_log_scroll = clamp(session_log_scroll - _wheel, 0, _max_sl);
	}
} else {
	// Tab switching via mouse wheel when hovering on tab area
	if (_wheel != 0 && hero != undefined && game_state == "sheet" && !gm_mode) {
		var _mx_tab = device_mouse_x_to_gui(0);
		var _my_tab = device_mouse_y_to_gui(0);
		if (_mx_tab >= tab_area_x1 && _mx_tab <= tab_area_x2 &&
			_my_tab >= tab_area_y1 && _my_tab <= tab_area_y2) {
			// Inverted direction: vertical = standard (down=next), horizontal = reversed (down=prev)
			var _delta = tabs_horizontal ? _wheel : -_wheel;
			var _new_tab = clamp(current_tab + _delta, 0, 9);
			if (_new_tab != current_tab) {
				if (hero_dirty && hero != undefined) { save_hero_and_track(hero); hero_dirty = false; }
				current_tab = _new_tab;
				staged_roll = undefined;
				situation_step = SIT_STEP_BASE;
				if (current_tab == 6) rolllog_dirty = true;
			}
			_wheel = 0; // consume the wheel so it doesn't also scroll the tab content
		}
	}
	var _skill_count = array_length(hero.skills);
	if (_wheel != 0 && current_tab == 0) { scroll_offset = clamp(scroll_offset-_wheel, 0, max(0, _skill_count-max_visible_skills)); selected_skill = clamp(selected_skill, scroll_offset, min(scroll_offset+max_visible_skills-1, _skill_count-1)); }
	if (_wheel != 0 && current_tab == 6) rolllog_scroll = max(0, rolllog_scroll-_wheel);
	if (_wheel != 0 && (current_tab == 7 || current_tab == 9)) info_scroll = max(0, info_scroll-_wheel*30);
	if (_wheel != 0 && current_tab == 4) pf_scroll = max(0, pf_scroll - _wheel);
}

// ============================================================
// INLINE TEXT MODAL — handles keyboard input + buttons + Escape.
// Real-time save: every keystroke writes through to the target struct.
// Runs every frame independent of click state so keys register.
// ============================================================
if (text_modal_open) {
	// Backspace
	if (keyboard_check_pressed(vk_backspace) && string_length(text_modal_buffer) > 0) {
		text_modal_buffer = string_copy(text_modal_buffer, 1, string_length(text_modal_buffer)-1);
		// Real-time save
		if (text_modal_target_struct != undefined && text_modal_target_key != "") {
			text_modal_target_struct[$ text_modal_target_key] = text_modal_buffer;
		}
	}
	// Enter = commit
	if (keyboard_check_pressed(vk_enter)) {
		close_text_modal(true);
	}
	// Escape = cancel
	else if (keyboard_check_pressed(vk_escape)) {
		close_text_modal(false);
	}
	// Type
	if (keyboard_string != "") {
		text_modal_buffer += keyboard_string;
		if (string_length(text_modal_buffer) > text_modal_max_len) {
			text_modal_buffer = string_copy(text_modal_buffer, 1, text_modal_max_len);
		}
		// Real-time save
		if (text_modal_target_struct != undefined && text_modal_target_key != "") {
			text_modal_target_struct[$ text_modal_target_key] = text_modal_buffer;
		}
		keyboard_string = "";
	}
	// Button clicks (Save / Cancel)
	if (mouse_check_button_pressed(mb_left)) {
		if (btn_clicked("text_modal_save"))   close_text_modal(true);
		if (btn_clicked("text_modal_cancel")) close_text_modal(false);
	}
	// Block all other input from running while the modal is open — eat the click,
	// run nothing else this frame. The modal eclipses the field being edited.
	exit;
}

// GM Sessionlog chat input — active when focused on the Sessionlog chat field.
// Enter sends. Same /name and /gm whisper prefix syntax as the sidebar chat.
if (gm_mode && net_input_focus == "session_chat") {
	if (keyboard_check_pressed(vk_backspace) && string_length(session_log_chat_buffer) > 0) {
		session_log_chat_buffer = string_copy(session_log_chat_buffer, 1, string_length(session_log_chat_buffer)-1);
	}
	if (keyboard_check_pressed(vk_enter) && session_log_chat_buffer != "") {
		_gm_sessionlog_send_chat();
	}
	if (keyboard_string != "") {
		session_log_chat_buffer += keyboard_string;
		if (string_length(session_log_chat_buffer) > 200) session_log_chat_buffer = string_copy(session_log_chat_buffer, 1, 200);
		keyboard_string = "";
	}
}

// GM dice roller text input — active when focused on the GM dice field.
// Runs every frame (independent of _click) so keys register. Enter rolls.
if (gm_mode && net_input_focus == "gmdice") {
	if (keyboard_check_pressed(vk_backspace) && string_length(gm_dice_buffer) > 0) {
		gm_dice_buffer = string_copy(gm_dice_buffer, 1, string_length(gm_dice_buffer)-1);
	}
	if (keyboard_check_pressed(vk_enter) && gm_dice_buffer != "") {
		gm_run_dice_expression(gm_dice_buffer);
	}
	if (keyboard_string != "") {
		gm_dice_buffer += keyboard_string;
		if (string_length(gm_dice_buffer) > 64) gm_dice_buffer = string_copy(gm_dice_buffer, 1, 64);
		keyboard_string = "";
	}
}

// Chat input — active when focused on the chat field. Works in BOTH player and GM mode.
// Runs every frame (independent of _click) so keys register. Supports /name and /gm
// whisper syntax: "/Bob private message" or "/gm secret to gm".
if (net_is_connected() && net_input_focus == "chat") {
	if (keyboard_check_pressed(vk_backspace) && string_length(net_chat_buffer) > 0) {
		net_chat_buffer = string_copy(net_chat_buffer, 1, string_length(net_chat_buffer)-1);
	}
	if (keyboard_check_pressed(vk_enter) && net_chat_buffer != "") {
		// Parse for whisper prefix
		var _whisper_to = "";
		var _msg_text = net_chat_buffer;
		if (string_char_at(_msg_text, 1) == "/") {
			var _space = string_pos(" ", _msg_text);
			if (_space > 1) {
				_whisper_to = string_copy(_msg_text, 2, _space - 2);
				_msg_text = string_copy(_msg_text, _space + 1, string_length(_msg_text) - _space);
			}
		}
		if (_whisper_to != "") {
			net_send_whisper(_whisper_to, _msg_text);
		} else {
			net_send_chat(_msg_text);
		}
		// Mirror locally so the sender sees their own message in the stream
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
			chat_text: (_whisper_to != "" ? "[whisper to " + _whisper_to + "] " : "") + _msg_text,
			timestamp: current_time
		};
		array_insert(rolllog_entries, 0, _self_entry);
		if (array_length(rolllog_entries) > max_log_entries) array_pop(rolllog_entries);
		// Persistent session log — local chat (whispers included)
		session_log_append(session_log_make_chat_entry(net_player_name == "" ? "Local" : net_player_name, _msg_text, _whisper_to != "", _whisper_to));
		net_chat_buffer = "";
	}
	if (keyboard_string != "") {
		net_chat_buffer += keyboard_string;
		if (string_length(net_chat_buffer) > 200) net_chat_buffer = string_copy(net_chat_buffer, 1, 200);
		keyboard_string = "";
	}
}

if (!_click) exit;

// ---- RIGHT PANEL BUTTONS (always active in all modes) ----
// Sidebar chat focus — clicking the chat field grabs keyboard focus.
// Clicking anywhere else with focus held will lose focus naturally on the next
// click that hits another field/button.
if (net_is_connected() && btn_clicked("sidebar_chat")) {
	net_input_focus = "chat";
}

// GM dice roller — quick buttons + free-form expression input.
if (gm_mode) {
	if (btn_clicked("gmd_2d6m2")) gm_run_dice_expression("2d6-2");
	if (btn_clicked("gmd_1d8"))   gm_run_dice_expression("1d8");
	if (btn_clicked("gmd_2d4m1")) gm_run_dice_expression("2d4-1");
	if (btn_clicked("gmd_input")) net_input_focus = "gmdice";
	if (btn_clicked("gmd_roll") && gm_dice_buffer != "") gm_run_dice_expression(gm_dice_buffer);
}

// "No fail" toggle in the right-sidebar dice roller area
if (btn_clicked("sidebar_cant_fail")) cant_fail_mode = !cant_fail_mode;

// GM per-player buttons in the multiplayer roster
if (gm_mode && net_is_host() && net_is_connected()) {
	var _gm_players = net_get_players();
	for (var _gpi = 0; _gpi < array_length(_gm_players); _gpi++) {
		var _gp = _gm_players[_gpi];
		var _gp_name = is_struct(_gp) ? (_gp[$ "name"] ?? "") : string(_gp);
		var _gp_host = is_struct(_gp) ? (_gp[$ "is_host"] ?? false) : false;
		if (_gp_host || _gp_name == "") continue;
		if (btn_clicked("gm_add_player_"+string(_gpi))) {
			// Ask that player to send their character — Other_68 auto-responds with
			// their hero, which lands in global.npcs via log_remote_character.
			net_request_character_from(_gp_name);
			status_msg = "Requested character from " + _gp_name; status_timer = 120;
		}
		// gm_push_char_* button removed in v0.62.0 — Push Character now lives on the
		// GM Party tab where it uses the actual party member statblock, not obj_game.hero.
	}
}

// Character buttons — new char and menu work in every mode
if (btn_clicked("new_char")) { chargen_reset(); chargen_open = true; }
if (btn_clicked("welcome_btn")) {
	if (hero != undefined) { save_hero_and_track(hero); hero_dirty = false; }
	if (gm_mode) save_campaign();
	game_state = "welcome";
}

// Portrait
if (btn_clicked("portrait_browse") && hero != undefined) { load_custom_portrait_dialog(hero); status_msg = "Portrait updated"; status_timer = 90; portrait_dropdown_open = false; }
if (btn_clicked("portrait_preset")) { portrait_dropdown_open = !portrait_dropdown_open; if (portrait_dropdown_open) portrait_presets = scan_portrait_directory(); }
if (portrait_dropdown_open) {
	for (var _pi = 0; _pi < min(array_length(portrait_presets), 10); _pi++) {
		if (btn_clicked("pp"+string(_pi))) {
			if (global.portrait_sprite != -1) sprite_delete(global.portrait_sprite);
			global.portrait_sprite = sprite_add(portrait_presets[_pi].path, 0, false, false, 0, 0);
			global.portrait_path = portrait_presets[_pi].path;
			if (hero != undefined) hero.portrait_path = portrait_presets[_pi].path;
			portrait_dropdown_open = false; status_msg = "Portrait: "+portrait_presets[_pi].name; status_timer = 90; break;
		}
	}
}

// Rename character — opens inline modal targeting hero.name. After commit,
// rename_hero() renames the file on disk and updates recents/roster/last_char_path.
if (btn_clicked("edit_hero_name")) {
	if (hero == undefined || hero.name == "Sergeant Voss") {
		status_msg = "Sgt Voss is a read-only template"; status_timer = 120;
	} else {
		hero_rename_old = hero.name;
		open_text_modal("Character name:", hero, "name", 50, function() {
			var _new = obj_game.hero.name;
			// The modal already wrote the new name into hero.name in real time.
			// Restore the old value temporarily so rename_hero() can do the move.
			obj_game.hero.name = obj_game.hero_rename_old;
			rename_hero(obj_game.hero, obj_game.hero_rename_old, _new);
			update_hero(obj_game.hero);
			obj_game.hero_dirty = false; // rename_hero already saved
			obj_game.status_msg = "Renamed to: " + _new;
			obj_game.status_timer = 150;
		});
	}
}

// File operations — work in all modes
if (btn_clicked("export")) { var _ok = statblock_export(hero); status_msg = _ok ? "Exported!" : "Cancelled."; status_timer = 120; }
if (btn_clicked("import")) {
	var _imp = statblock_import();
	if (_imp != undefined) {
		hero = _imp; update_hero(hero); save_hero_and_track(hero); add_to_party(hero);
		var _ipath = global.save_path + sanitize_hero_filename(hero.name) + ".json";
		roster_add_ref(hero.name, _ipath);
		if (gm_mode) save_campaign();
		selected_skill = 0; scroll_offset = 0; status_msg = "Imported: "+hero.name;
	} else status_msg = "Cancelled.";
	status_timer = 120;
}
if (btn_clicked("save_lib")) { var _n = save_all_data_dialog(); status_msg = (_n != "") ? "Saved: "+_n : "Cancelled."; status_timer = 120; }
if (btn_clicked("load_lib")) { var _n = load_all_data_dialog(); status_msg = (_n != "") ? "Loaded: "+_n : "Cancelled."; status_timer = 120; }

// Situation die adjuster — works in all modes
if (btn_clicked("sit_left")) situation_step = max(SIT_STEP_MIN, situation_step-1);
if (btn_clicked("sit_right")) situation_step = min(SIT_STEP_MAX, situation_step+1);
if (btn_clicked("sit_reset")) {
	situation_step = (staged_roll != undefined) ? staged_roll.computed_step : SIT_STEP_BASE;
}

// Quick rolls — work in all modes (roll for current hero)
if (btn_clicked("roll_awareness")) {
	// Best awareness: Perception > Intuition > broad > untrained
	var _aw_req;
	if (find_skill(hero, "Awareness", "Perception") >= 0) _aw_req = build_skill_request(hero, "Awareness", "Perception", 0);
	else if (find_skill(hero, "Awareness", "Intuition") >= 0) _aw_req = build_skill_request(hero, "Awareness", "Intuition", 0);
	else if (find_skill(hero, "Awareness", "") >= 0) _aw_req = build_skill_request(hero, "Awareness", "", 0);
	else _aw_req = build_feat_request(hero, "wil", "Senses", 0);
	quick_roll_skill(hero, _aw_req);
}
if (btn_clicked("roll_mental")) { var _rq = build_skill_request(hero, "Resolve", "Mental resolve", 0); _rq.name = "Mental Resolve"; quick_roll_skill(hero, _rq); }
if (btn_clicked("roll_physical")) { var _rq = build_skill_request(hero, "Resolve", "Physical resolve", 0); _rq.name = "Physical Resolve"; quick_roll_skill(hero, _rq); }
if (btn_clicked("roll_initiative")) {
	var _roll = meta_roll(hero, build_initiative_request(hero));
	initiative_phase = 3 - _roll.degree;
	actions_total = hero.actions_per_round; actions_remaining = actions_total;
	actions_placed = [0,0,0,0];
	if (!gm_mode) current_tab = 2;
	status_msg = "Initiative: " + _roll.degree_name; status_timer = 90;
}

// ROLL button — execute staged roll or stage+execute selected skill
if (btn_clicked("roll") && !is_rolling) {
	var _sc = array_length(hero.skills);
	if (staged_roll != undefined) {
		is_rolling = true; roll_anim_timer = roll_anim_duration;
	} else if (_sc > 0) {
		if (selected_skill >= _sc) selected_skill = _sc - 1;
		var _sk2 = hero.skills[selected_skill];
		prepare_roll(hero, build_skill_request(hero, _sk2.broad_skill, _sk2.specialty, 0));
		is_rolling = true; roll_anim_timer = roll_anim_duration;
	}
}

// ---- GM MODE: GM TOOLS SCREEN ----
if (gm_mode && gm_state == "gm") {
	// GM tab clicks (7 tabs in v0.62.0: Party, NPCs, Encounter, Factions, Campaign, Sessionlog, Resources)
	for (var _gt = 0; _gt < 7; _gt++) {
		if (btn_clicked("gm_tab" + string(_gt))) gm_tab = _gt;
	}
	// Dispatch to GM tab handlers
	if (gm_tab == 0) handle_gm_party();
	if (gm_tab == 1) handle_gm_npcs();
	if (gm_tab == 2) handle_gm_encounter();
	if (gm_tab == 3) handle_gm_factions();
	if (gm_tab == 4) handle_gm_campaign();
	if (gm_tab == 5) handle_gm_sessionlog();
	// gm_tab == 6 (Resources) is display-only, scroll handled above
	exit;
}

// ---- GM EDIT MODE: "Back to GM" button ----
if (gm_mode && gm_state == "edit") {
	if (btn_clicked("gm_back")) {
		if (hero_dirty && hero != undefined) { save_hero_and_track(hero); hero_dirty = false; }
		gm_state = "gm";
		exit;
	}
}

// ---- PLAYER MODE (or GM edit mode) ----
// Tab layout toggle (vertical ↔ horizontal) — clear stale button rects so old positions
// don't survive into the new layout and create phantom click areas.
if (btn_clicked("tabs_layout_toggle")) {
	tabs_horizontal = !tabs_horizontal;
	for (var _t = 0; _t < 10; _t++) variable_struct_remove(btn, "tab"+string(_t));
	var _ab_keys_clr = global.ability_keys;
	for (var _ki = 0; _ki < 6; _ki++) {
		variable_struct_remove(btn, "stat_group_"+_ab_keys_clr[_ki]);
		variable_struct_remove(btn, "ab_m"+string(_ki));
		variable_struct_remove(btn, "ab_p"+string(_ki));
	}
	tab_area_x1 = 0; tab_area_y1 = 0; tab_area_x2 = 0; tab_area_y2 = 0;
}

// Tab clicks — auto-save when switching tabs if hero was modified
for (var _t = 0; _t < 10; _t++) {
	if (btn_clicked("tab"+string(_t))) {
		if (hero_dirty && hero != undefined) { save_hero_and_track(hero); hero_dirty = false; }
		current_tab = _t;
		staged_roll = undefined;        // Clear orphaned staged roll on tab switch
		situation_step = SIT_STEP_BASE;  // Reset die to neutral on tab switch
		if (_t == 6) rolllog_dirty = true;
	}
}

// Ability +/- buttons
var _ab_keys = global.ability_keys;
for (var _ai = 0; _ai < 6; _ai++) {
	if (btn_clicked("ab_m"+string(_ai))) { var _c = get_ability_score_for_skill(hero, _ab_keys[_ai]); if (_c > 4) { set_ability(hero, _ab_keys[_ai], _c-1); update_hero(hero); hero_dirty = true; } }
	if (btn_clicked("ab_p"+string(_ai))) { var _c = get_ability_score_for_skill(hero, _ab_keys[_ai]); if (_c < 14) { set_ability(hero, _ab_keys[_ai], _c+1); update_hero(hero); hero_dirty = true; } }
}

// Durability resets
if (btn_clicked("reset_stun")) { hero.stun.current = hero.stun.max; hero_dirty = true; }
if (btn_clicked("reset_wound")) { hero.wound.current = hero.wound.max; hero_dirty = true; }
if (btn_clicked("reset_mortal")) { hero.mortal.current = hero.mortal.max; hero_dirty = true; }

// ---- TAB HANDLERS ----
if (current_tab == 0) handle_tab_character();
if (current_tab == 1) handle_tab_equipment();
if (current_tab == 2) handle_tab_combat();
if (current_tab == 3) handle_tab_psionics();
if (current_tab == 4) handle_tab_perks_flaws();
if (current_tab == 5) handle_tab_cybertech();
if (current_tab == 6) handle_tab_rolllog();
// Tab 7 (Info) is display-only — no input handler needed
if (current_tab == 8) handle_tab_grid();
if (current_tab == 9) handle_tab_aura();
