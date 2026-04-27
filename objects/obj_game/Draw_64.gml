/// @description Full UI: Welcome screen, tabbed character sheet, combat, chargen

draw_set_font(-1);
var _lh = 18;
var _tooltip_text = ""; var _tooltip_x = 0; var _tooltip_y = 0;
var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
// Gradient background: smooth top→bottom with wave swoop
// Draw vertical gradient using horizontal strips
var _grad_steps = 40;
for (var _gs = 0; _gs < _grad_steps; _gs++) {
	var _t = _gs / _grad_steps;
	var _y1 = floor(_gh * _t);
	var _y2 = floor(_gh * (_t + 1/_grad_steps));
	draw_set_colour(merge_colour(c_bg_top, c_bg_bottom, _t));
	draw_rectangle(0, _y1, _gw, _y2, false);
}
// Wave swoop: filled shape that covers the transition zone
var _wave_center = floor(_gh * c_bg_wave_y);
var _wave_amp = 35;
var _wave_thick = 60; // gradient fade thickness above and below wave
// Draw the wave: for each x column, fill from wave line downward with bottom color
// and fill above with blended top color, creating a soft swoop
for (var _wx = 0; _wx < _gw; _wx += 2) {
	var _wy = _wave_center + sin(_wx * 0.005) * _wave_amp + sin(_wx * 0.013) * (_wave_amp * 0.4);
	// Fill above wave with top color (softens the transition)
	draw_set_colour(merge_colour(c_bg_top, c_bg_bottom, 0.15));
	draw_rectangle(_wx, _wy - _wave_thick, _wx+1, _wy - _wave_thick/2, false);
	draw_set_colour(merge_colour(c_bg_top, c_bg_bottom, 0.3));
	draw_rectangle(_wx, _wy - _wave_thick/2, _wx+1, _wy, false);
	// Fill below wave with bottom color
	draw_set_colour(merge_colour(c_bg_top, c_bg_bottom, 0.7));
	draw_rectangle(_wx, _wy, _wx+1, _wy + _wave_thick/2, false);
	draw_set_colour(merge_colour(c_bg_top, c_bg_bottom, 0.85));
	draw_rectangle(_wx, _wy + _wave_thick/2, _wx+1, _wy + _wave_thick, false);
}

// ============================================================
// WELCOME SCREEN
// ============================================================
if (game_state == "welcome") {
	// EXIT — top right, always visible
	ui_btn("exit_app", _gw-90, 8, _gw-10, 32, "EXIT", c_failure, #ff0000);

	draw_set_halign(fa_center);
	draw_set_colour(c_text_dark);
	draw_text(_gw/2, 20, "DiceyMcDiceFaces");
	draw_set_colour(merge_colour(c_text_dark, c_header, 0.5));
	draw_text(_gw/2, 44, "Charma for Alternity");
	draw_set_halign(fa_left);

	// All main menu buttons in ONE horizontal row across the top.
	// Layout is responsive: if the centered row would overlap the EXIT button at
	// the top-right, the row is shifted left and/or the buttons shrink. The row
	// is clamped to start at x>=8 and end at x<=_gw-100 (leaving room for EXIT).
	var _by = 75;
	var _bh = 34;
	var _bgap = 6;
	// Build button list dynamically (Continue only shown if a recent char exists)
	var _btns = [];
	if (last_char_path != "") array_push(_btns, { key: "welcome_continue", label: "Continue", w: 110, col: c_good });
	array_push(_btns, { key: "welcome_new",        label: "New",          w: 90,  col: c_highlight });
	array_push(_btns, { key: "welcome_load",       label: "Load",         w: 90,  col: c_amazing });
	// Host/Join collapse to a single Exit button when in a session.
	var _in_session = (net_handshake_state == "in_session");
	if (!_in_session) {
		// v0.62.0: Continue Session for GMs (when last_session.json exists)
		var _has_last_session = variable_global_exists("last_session_data") && global.last_session_data != undefined;
		var _has_last_join    = variable_global_exists("last_join_data")    && global.last_join_data    != undefined;
		if (gm_mode && _has_last_session) {
			array_push(_btns, { key: "welcome_continue_session", label: "Continue Session", w: 160, col: c_good });
		}
		// v0.62.0: Rejoin Session for players (when last_join.json exists)
		if (!gm_mode && _has_last_join) {
			array_push(_btns, { key: "welcome_rejoin_session", label: "Rejoin Session", w: 160, col: c_good });
		}
		array_push(_btns, { key: "welcome_host", label: "Host Session", w: 130, col: c_highlight });
		array_push(_btns, { key: "welcome_join", label: "Join Session", w: 130, col: c_amazing });
	} else {
		var _exit_label = net_is_host() ? "Exit Hosting" : "Exit Session";
		array_push(_btns, { key: "welcome_exit_session", label: _exit_label, w: 266, col: c_failure });
	}
	var _gm_label = gm_mode ? "GM Mode" : "Player Mode";
	var _gm_col = gm_mode ? c_failure : c_good;
	array_push(_btns, { key: "welcome_gm_toggle",  label: _gm_label,      w: 130, col: _gm_col });
	array_push(_btns, { key: "welcome_access",     label: "Settings",     w: 100, col: c_warning });

	// Compute total width and available width (gw - 16 left margin - 100 EXIT margin)
	var _avail_w = _gw - 16 - 100;
	var _total_w = -_bgap;
	for (var _bi = 0; _bi < array_length(_btns); _bi++) _total_w += _btns[_bi].w + _bgap;

	// If the row is too wide, scale all button widths proportionally to fit
	if (_total_w > _avail_w) {
		var _scale = _avail_w / _total_w;
		for (var _bi = 0; _bi < array_length(_btns); _bi++) _btns[_bi].w = max(60, floor(_btns[_bi].w * _scale));
		// Recompute after scaling
		_total_w = -_bgap;
		for (var _bi = 0; _bi < array_length(_btns); _bi++) _total_w += _btns[_bi].w + _bgap;
	}

	// Center the row, but clamp so it never overlaps EXIT (right edge <= gw-100) or runs off-screen left
	var _bx = floor(_gw/2 - _total_w/2);
	if (_bx + _total_w > _gw - 100) _bx = _gw - 100 - _total_w;
	if (_bx < 8) _bx = 8;
	for (var _bi = 0; _bi < array_length(_btns); _bi++) {
		var _b = _btns[_bi];
		ui_btn(_b.key, _bx, _by, _bx + _b.w, _by + _bh, _b.label, c_border, _b.col);
		_bx += _b.w + _bgap;
	}

	// Recent Characters panel (right side)
	var _rc_x = _gw - 340;
	var _rc_y = 125;
	var _rc_w = 320;
	var _rc_h = _gh - 145;

	draw_set_colour(c_panel); draw_rectangle(_rc_x, _rc_y, _rc_x+_rc_w, _rc_y+_rc_h, false);
	draw_set_colour(c_border); draw_rectangle(_rc_x, _rc_y, _rc_x+_rc_w, _rc_y+_rc_h, true);
	draw_set_colour(c_header); draw_text(_rc_x+12, _rc_y+8, "RECENT CHARACTERS");

	var _rcy = _rc_y + 30;
	var _rc_list = global.recent_characters.recent;
	if (array_length(_rc_list) == 0) {
		draw_set_colour(c_muted); draw_text(_rc_x+12, _rcy, "No recent characters.");
	} else {
		for (var _ri = 0; _ri < array_length(_rc_list); _ri++) {
			var _rce = _rc_list[_ri];
			var _rck = "recent" + string(_ri);
			ui_btn(_rck, _rc_x+8, _rcy, _rc_x+_rc_w-8, _rcy+24, _rce.name, c_border, c_highlight);
			_rcy += 28;
		}
	}
	// Voss is always the last entry (permanent default template)
	_rcy += 4;
	draw_set_colour(c_muted); draw_text(_rc_x+12, _rcy, "Default Template:");
	_rcy += _lh;
	ui_btn("welcome_voss", _rc_x+8, _rcy, _rc_x+_rc_w-8, _rcy+24, "Sgt Voss (Infantry Soldier)", c_border, c_good);

	// Changelog reopen button (left side, where the panel used to live)
	// The big changelog panel is now a closeable modal overlay (drawn below).
	var _clog_btn_x = 80;
	var _clog_btn_y = 125;
	ui_btn("changelog_open_btn", _clog_btn_x, _clog_btn_y, _clog_btn_x+180, _clog_btn_y+30, "Open Devlog", c_border, c_amazing);
	draw_set_colour(c_muted);
	draw_text(_clog_btn_x, _clog_btn_y+36, "Latest: v" + (global.changelog[$ "entries"] != undefined && array_length(global.changelog.entries) > 0 ? global.changelog.entries[0].version : "?"));

	// ============================================================
	// CHANGELOG MODAL — closeable, two-view (Current / Past).
	//   Current view → latest CHANGELOG_CURRENT_COUNT (10) entries, no paging
	//   Past view    → paginates remaining 122 entries, 10 per page
	// Auto-opens once per session. Closes via X / Escape / click outside.
	// READ-ONLY: pulls from global.changelog.entries (loaded from json).
	// ============================================================
	if (changelog_open && global.changelog[$ "entries"] != undefined) {
		// Dim the background
		draw_set_alpha(0.65); draw_set_colour(#000000); draw_rectangle(0, 0, _gw, _gh, false); draw_set_alpha(1.0);

		// Centered floating box
		var _clx = max(60, _gw/2 - 460);
		var _cly = 80;
		var _clw = min(920, _gw - 120);
		var _clh = _gh - 160;
		draw_set_colour(c_panel); draw_rectangle(_clx, _cly, _clx+_clw, _cly+_clh, false);
		draw_set_colour(c_border); draw_rectangle(_clx, _cly, _clx+_clw, _cly+_clh, true);

		// Header
		draw_set_colour(c_header); draw_text(_clx+16, _cly+10, "DEVELOPMENT LOG");
		var _entries_all = global.changelog.entries;
		var _total_entries = array_length(_entries_all);
		var _current_count = min(CHANGELOG_CURRENT_COUNT, _total_entries);
		var _past_count    = max(0, _total_entries - _current_count);
		var _past_pages    = max(1, ceil(_past_count / CHANGELOG_PAGE_SIZE));

		// Compute the slice for whichever view is active
		var _page_start = 0;
		var _page_end   = 0;
		var _status_str = "";
		if (changelog_view == "current") {
			_page_start = 0;
			_page_end   = _current_count;
			_status_str = "Current — " + string(_current_count) + " latest of " + string(_total_entries);
		} else {
			changelog_page = clamp(changelog_page, 0, _past_pages - 1);
			_page_start = _current_count + changelog_page * CHANGELOG_PAGE_SIZE;
			_page_end   = min(_total_entries, _page_start + CHANGELOG_PAGE_SIZE);
			_status_str = "Past — Page " + string(changelog_page+1) + " / " + string(_past_pages) + "  (" + string(_past_count) + " older entries)";
		}
		draw_set_colour(c_muted);
		draw_text(_clx+16, _cly+30, _status_str);

		// Top-right buttons: Current/Past toggle, Newer, Older, Close
		var _ctrl_x = _clx + _clw - 410;
		var _ctrl_y = _cly + 8;
		var _is_current = (changelog_view == "current");
		ui_btn("changelog_view_current", _ctrl_x,      _ctrl_y, _ctrl_x+90,  _ctrl_y+24, "Current",  _is_current ? c_good : c_border, c_good);
		ui_btn("changelog_view_past",    _ctrl_x+96,   _ctrl_y, _ctrl_x+186, _ctrl_y+24, "Past",     !_is_current ? c_amazing : c_border, c_amazing);
		// Newer/Older only matter in past view
		if (changelog_view == "past") {
			ui_btn("changelog_newer", _ctrl_x+200, _ctrl_y, _ctrl_x+260, _ctrl_y+24, "<- New", c_border, c_good);
			ui_btn("changelog_older", _ctrl_x+264, _ctrl_y, _ctrl_x+324, _ctrl_y+24, "Old ->", c_border, c_amazing);
		}
		ui_btn("changelog_close", _ctrl_x+372,  _ctrl_y, _ctrl_x+402, _ctrl_y+24, "X", c_border, c_failure);

		// Build line blocks for the visible page
		var _max_w_cl = _clw - 40;
		var _blocks_cl = [];
		var _total_h_cl = 0;
		for (var _ei = _page_start; _ei < _page_end; _ei++) {
			var _ent = _entries_all[_ei];
			var _t = "v" + _ent.version + "  -  " + _ent.title;
			var _h = string_height_ext(_t, -1, _max_w_cl);
			array_push(_blocks_cl, { text: _t, color: c_header, indent: 0, h: _h });
			_total_h_cl += _h;
			array_push(_blocks_cl, { text: _ent.date, color: c_muted, indent: 0, h: _lh });
			_total_h_cl += _lh;
			for (var _n = 0; _n < array_length(_ent.notes); _n++) {
				_t = "  - " + _ent.notes[_n];
				_h = string_height_ext(_t, -1, _max_w_cl - 12);
				array_push(_blocks_cl, { text: _t, color: c_text, indent: 12, h: _h });
				_total_h_cl += _h;
			}
			if (_ent[$ "dev_commentary"] != undefined && _ent.dev_commentary != "") {
				array_push(_blocks_cl, { text: "", color: c_muted, indent: 0, h: 6 });
				_total_h_cl += 6;
				_t = _ent.dev_commentary;
				_h = string_height_ext(_t, -1, _max_w_cl - 24);
				array_push(_blocks_cl, { text: _t, color: c_warning, indent: 20, h: _h });
				_total_h_cl += _h;
			}
			array_push(_blocks_cl, { text: "", color: c_muted, indent: 0, h: 14 });
			_total_h_cl += 14;
		}

		// Scroll within the page
		var _list_top_cl = _cly + 60;
		var _list_bot_cl = _cly + _clh - 12;
		var _view_h_cl = _list_bot_cl - _list_top_cl;
		var _max_scroll_cl = max(0, _total_h_cl - _view_h_cl);
		changelog_scroll = clamp(changelog_scroll, 0, _max_scroll_cl);

		// Render with manual clipping
		var _ly_cl = _list_top_cl - changelog_scroll;
		for (var _bi = 0; _bi < array_length(_blocks_cl); _bi++) {
			var _b = _blocks_cl[_bi];
			var _by2 = _ly_cl + _b.h;
			if (_by2 > _list_top_cl && _ly_cl < _list_bot_cl) {
				draw_set_colour(_b.color);
				if (_b.text != "") {
					draw_text_ext(_clx+16 + _b.indent, _ly_cl, _b.text, -1, _max_w_cl - _b.indent);
				}
			}
			_ly_cl = _by2;
			if (_ly_cl > _list_bot_cl + 50) break;
		}

		// Mark the modal area for click-outside detection
		btn.changelog_modal_area = [_clx, _cly, _clx+_clw, _cly+_clh];
	}

	// Accessibility popup (drawn LAST for z-order, on top of everything)
	if (accessibility_open) {
		draw_set_alpha(0.7); draw_set_colour(#000000); draw_rectangle(0,0,_gw,_gh,false); draw_set_alpha(1.0);
		var _ax = _gw/2 - 280; var _ay = 120; var _aw = 560; var _ah = 460;
		draw_set_colour(c_panel); draw_rectangle(_ax, _ay, _ax+_aw, _ay+_ah, false);
		draw_set_colour(c_border); draw_rectangle(_ax, _ay, _ax+_aw, _ay+_ah, true);
		draw_set_colour(c_header); draw_text(_ax+16, _ay+8, "ACCESSIBILITY & DISPLAY");
		ui_btn("access_close", _ax+_aw-36, _ay+4, _ax+_aw-6, _ay+26, "X", c_border, c_failure);

		// Window mode selector
		draw_set_colour(c_text); draw_text(_ax+16, _ay+34, "Window Mode:");
		var _wm_modes = ["fullscreen", "windowed", "half"];
		var _wm_labels = ["Fullscreen", "Windowed (80%)", "Half Monitor"];
		for (var _wi = 0; _wi < 3; _wi++) {
			var _wx = _ax + 140 + _wi * 140;
			var _is_wm = (window_mode == _wm_modes[_wi]);
			var _wmk = "wm_"+string(_wi);
			ui_btn(_wmk, _wx, _ay+30, _wx+120, _ay+52, _wm_labels[_wi], _is_wm ? c_good : c_border, c_highlight);
		}

		draw_set_colour(c_text); draw_text(_ax+16, _ay+62, "Color Vision Mode:");

		// Preset modes
		var _modes = ["normal", "protanopia", "deuteranopia", "tritanopia", "greyscale", "custom"];
		var _labels = ["Normal Vision", "Protanopia (Red-Weak)", "Deuteranopia (Green-Weak)", "Tritanopia (Blue-Weak)", "Greyscale", "Custom"];
		for (var _mi = 0; _mi < 6; _mi++) {
			var _my2 = _ay + 86 + _mi * 28;
			var _is_sel = (colorblind_mode == _modes[_mi]);
			draw_set_colour(_is_sel ? c_good : c_border);
			draw_circle(_ax + 30, _my2 + 8, 8, true);
			if (_is_sel) draw_circle(_ax + 30, _my2 + 8, 4, false);
			draw_set_colour(_is_sel ? c_text : c_muted);
			draw_text(_ax + 46, _my2, _labels[_mi]);
			// Preview swatches for presets
			if (_mi > 0 && _mi < 5 && global.config[$ "color_profiles"] != undefined) {
				var _cp = global.config.color_profiles;
				if (_cp[$ _modes[_mi]] != undefined) {
					var _prof2 = _cp[$ _modes[_mi]];
					var _px2 = _ax + 340;
					draw_set_colour(parse_hex_color(_prof2.good)); draw_rectangle(_px2, _my2, _px2+18, _my2+16, false);
					draw_set_colour(parse_hex_color(_prof2.failure)); draw_rectangle(_px2+22, _my2, _px2+40, _my2+16, false);
					draw_set_colour(parse_hex_color(_prof2.amazing)); draw_rectangle(_px2+44, _my2, _px2+62, _my2+16, false);
					draw_set_colour(parse_hex_color(_prof2.warning)); draw_rectangle(_px2+66, _my2, _px2+84, _my2+16, false);
				}
			}
			var _mk = "access_mode"+string(_mi);
			variable_struct_set(btn, _mk, [_ax+16, _my2-4, _ax+300, _my2+22]);
		}

		// Custom color editor (visible when custom mode is selected)
		if (colorblind_mode == "custom") {
			var _cy2 = _ay + 86 + 6 * 28 + 10;
			draw_set_colour(c_header); draw_text(_ax+16, _cy2, "Custom Colors (click swatch to cycle):");
			_cy2 += 22;

			// Get or create custom profile
			if (global.config.color_profiles[$ "custom"] == undefined) {
				global.config.color_profiles.custom = { good: "#53d769", failure: "#ff4444", warning: "#ffcc00", amazing: "#00bfff", highlight: "#53d769" };
			}
			var _custom = global.config.color_profiles.custom;
			var _ckeys = ["good", "failure", "warning", "amazing", "highlight"];
			var _clabels = ["Good/Success", "Failure/Damage", "Warning/Marginal", "Amazing/Best", "Highlight/Select"];

			// Color cycle palette (16 distinct colors to pick from)
			var _palette = ["#53d769","#ff4444","#ffcc00","#00bfff","#ff6b9d","#9b59b6","#e67e22",
			                "#1abc9c","#3498db","#e74c3c","#f39c12","#2ecc71","#ffffff","#cccccc","#888888","#333333"];

			for (var _ci = 0; _ci < 5; _ci++) {
				var _cry = _cy2 + _ci * 26;
				var _cur_hex = _custom[$ _ckeys[_ci]];
				// Label
				draw_set_colour(c_text); draw_text(_ax+24, _cry, _clabels[_ci]);
				// Current color swatch (clickable — cycles through palette)
				var _sx = _ax + 200;
				draw_set_colour(parse_hex_color(_cur_hex));
				draw_rectangle(_sx, _cry, _sx+40, _cry+18, false);
				draw_set_colour(c_border); draw_rectangle(_sx, _cry, _sx+40, _cry+18, true);
				// Hex value
				draw_set_colour(c_muted); draw_text(_sx+48, _cry, _cur_hex);
				// Click target
				var _cck = "custom_color_"+string(_ci);
				variable_struct_set(btn, _cck, [_sx, _cry-2, _sx+40, _cry+20]);
				// Palette strip (small swatches to pick from)
				for (var _pi = 0; _pi < 16; _pi++) {
					var _ppx = _ax + 320 + (_pi % 8) * 22;
					var _ppy = _cry + ((_pi >= 8) ? 14 : 0);
					draw_set_colour(parse_hex_color(_palette[_pi]));
					draw_rectangle(_ppx, _ppy-1, _ppx+18, _ppy+11, false);
					if (_palette[_pi] == _cur_hex) { draw_set_colour(#ffffff); draw_rectangle(_ppx, _ppy-1, _ppx+18, _ppy+11, true); }
					var _ppk = "cpal_"+string(_ci)+"_"+string(_pi);
					variable_struct_set(btn, _ppk, [_ppx, _ppy-2, _ppx+18, _ppy+12]);
				}
			}
		}
	}

	// HOST SESSION POPUP
	if (net_host_popup_open) {
		draw_set_alpha(0.7); draw_set_colour(#000000); draw_rectangle(0,0,_gw,_gh,false); draw_set_alpha(1.0);
		var _px = _gw/2 - 200; var _py = _gh/2 - 110;
		draw_set_colour(c_panel); draw_rectangle(_px, _py, _px+400, _py+220, false);
		draw_set_colour(c_border); draw_rectangle(_px, _py, _px+400, _py+220, true);
		draw_set_colour(c_header); draw_text(_px+16, _py+12, "HOST MULTIPLAYER SESSION");
		draw_set_colour(c_muted); draw_text(_px+16, _py+40, "Your name:");

		// Name input box
		draw_set_colour(c_panel); draw_rectangle(_px+16, _py+60, _px+384, _py+88, false);
		draw_set_colour(net_input_focus == "name" ? c_highlight : c_border);
		draw_rectangle(_px+16, _py+60, _px+384, _py+88, true);
		draw_set_colour(c_text); draw_text(_px+22, _py+66, net_player_name_input + (net_input_focus == "name" ? "_" : ""));
		btn.net_name_field = [_px+16, _py+60, _px+384, _py+88];

		// Buttons depend on state
		if (net_handshake_state == "in_session" && net_is_host_flag) {
			// Session is live — show code and a Continue button
			draw_set_colour(c_amazing);
			draw_set_halign(fa_center);
			draw_text(_px+200, _py+108, "SESSION CODE: " + net_session_code);
			draw_set_halign(fa_left);
			draw_set_colour(c_muted); draw_text(_px+16, _py+128, "Share this code with your players");
			ui_btn("net_host_continue", _px+16, _py+155, _px+190, _py+185, "Continue", c_border, c_good);
			ui_btn("net_host_cancel",   _px+200, _py+155, _px+384, _py+185, "Disconnect", c_border, c_failure);
		} else if (net_handshake_state == "connecting") {
			// Mid-handshake
			draw_set_colour(c_warning); draw_text(_px+16, _py+108, "Connecting to relay...");
			ui_btn("net_host_cancel", _px+200, _py+155, _px+384, _py+185, "Cancel", c_border, c_failure);
		} else if (net_handshake_state == "error") {
			// Show error and let them retry
			draw_set_colour(c_failure); draw_text_ext(_px+16, _py+108, "Error: " + net_error_message, -1, 368);
			ui_btn("net_host_confirm", _px+16, _py+155, _px+190, _py+185, "RETRY", c_border, c_good);
			ui_btn("net_host_cancel",  _px+200, _py+155, _px+384, _py+185, "Cancel", c_border, c_failure);
		} else {
			// idle — initial state
			ui_btn("net_host_confirm", _px+16, _py+155, _px+190, _py+185, "HOST", c_border, c_good);
			ui_btn("net_host_cancel",  _px+200, _py+155, _px+384, _py+185, "Cancel", c_border, c_failure);
		}
	}

	// JOIN SESSION POPUP
	if (net_join_popup_open) {
		draw_set_alpha(0.7); draw_set_colour(#000000); draw_rectangle(0,0,_gw,_gh,false); draw_set_alpha(1.0);
		var _px = _gw/2 - 200; var _py = _gh/2 - 130;
		draw_set_colour(c_panel); draw_rectangle(_px, _py, _px+400, _py+260, false);
		draw_set_colour(c_border); draw_rectangle(_px, _py, _px+400, _py+260, true);
		draw_set_colour(c_header); draw_text(_px+16, _py+12, "JOIN MULTIPLAYER SESSION");

		draw_set_colour(c_muted); draw_text(_px+16, _py+40, "Session code:");
		draw_set_colour(c_panel); draw_rectangle(_px+16, _py+60, _px+384, _py+88, false);
		draw_set_colour(net_input_focus == "code" ? c_highlight : c_border);
		draw_rectangle(_px+16, _py+60, _px+384, _py+88, true);
		draw_set_colour(c_text); draw_text(_px+22, _py+66, net_join_code_input + (net_input_focus == "code" ? "_" : ""));
		btn.net_code_field = [_px+16, _py+60, _px+384, _py+88];

		draw_set_colour(c_muted); draw_text(_px+16, _py+100, "Your name:");
		draw_set_colour(c_panel); draw_rectangle(_px+16, _py+120, _px+384, _py+148, false);
		draw_set_colour(net_input_focus == "name" ? c_highlight : c_border);
		draw_rectangle(_px+16, _py+120, _px+384, _py+148, true);
		draw_set_colour(c_text); draw_text(_px+22, _py+126, net_player_name_input + (net_input_focus == "name" ? "_" : ""));
		btn.net_name_field2 = [_px+16, _py+120, _px+384, _py+148];

		// State-aware buttons
		if (net_handshake_state == "connecting") {
			draw_set_colour(c_warning); draw_text(_px+16, _py+165, "Connecting to relay...");
			ui_btn("net_join_cancel", _px+200, _py+195, _px+384, _py+225, "Cancel", c_border, c_failure);
		} else if (net_handshake_state == "error") {
			draw_set_colour(c_failure); draw_text_ext(_px+16, _py+165, "Error: " + net_error_message, -1, 368);
			ui_btn("net_join_confirm", _px+16, _py+195, _px+190, _py+225, "RETRY", c_border, c_good);
			ui_btn("net_join_cancel",  _px+200, _py+195, _px+384, _py+225, "Cancel", c_border, c_failure);
		} else {
			ui_btn("net_join_confirm", _px+16, _py+195, _px+190, _py+225, "JOIN", c_border, c_good);
			ui_btn("net_join_cancel",  _px+200, _py+195, _px+384, _py+225, "Cancel", c_border, c_failure);
		}
	}

	// Chargen wizard overlay — must be drawn here too because the welcome block
	// returns early. Without this, clicking "New" on the welcome screen would
	// open the wizard but the wizard would never draw on top.
	if (chargen_open) {
		draw_chargen_wizard(_gw, _gh, _lh);
	}

	return;
}

// ============================================================
// LEFT PANEL
// ============================================================
var _lx=panel_left_x; var _ly=panel_y; var _lw=panel_left_w;

// GM MODE with gm_state="gm" — replace entire character sheet with GM screen
if (gm_mode && gm_state == "gm") {
	// GM tabs on the RIGHT side (just left of right panel)
	var _vtw = 88; var _vth = 22; var _vgap = 2;
	var _grx = panel_right_x - _vtw - 8;
	var _gm_tab_names = ["Party", "NPCs", "Encounter", "Factions", "Campaign", "Sessionlog", "Resources"];
	var _gm_num = 7;
	var _gry_start = _ly;

	draw_set_colour(merge_colour(c_panel, c_border, 0.3));
	draw_rectangle(_grx-2, _gry_start-2, _grx+_vtw+2, _gry_start + _gm_num*(_vth+_vgap)+2, false);
	for (var _gt = 0; _gt < _gm_num; _gt++) {
		var _gty = _gry_start + _gt * (_vth + _vgap);
		var _gk = "gm_tab" + string(_gt);
		variable_struct_set(btn, _gk, [_grx, _gty, _grx+_vtw, _gty+_vth]);
		var _gactive = (gm_tab == _gt);
		draw_set_colour(_gactive ? c_tab_active : c_tab_inactive);
		draw_rectangle(_grx, _gty, _grx+_vtw, _gty+_vth, false);
		if (_gactive) { draw_set_colour(c_warning); draw_rectangle(_grx, _gty, _grx+2, _gty+_vth, false); }
		draw_set_colour(_gactive ? c_warning : c_muted);
		draw_set_halign(fa_center); draw_text(_grx + _vtw/2, _gty+3, _gm_tab_names[_gt]); draw_set_halign(fa_left);
	}
	draw_set_colour(c_warning); draw_text(_grx+4, _gry_start + _gm_num*(_vth+_vgap)+6, "GM TOOLS");

	// GM mode label top-left
	draw_set_colour(c_failure); draw_text(_lx+8, _ly, "GM MODE");
	draw_set_colour(c_muted); draw_text(_lx+90, _ly, "| " + _gm_tab_names[gm_tab]);
	_ly += _lh + 4;

	// Content area fits between left edge and GM tab strip
	_lw = _grx - _lx - 6;

	// Content panel background
	draw_set_colour(c_panel); draw_rectangle(_lx-4,_ly-4,_lx+_lw+4,_gh-12,false);
	draw_set_colour(c_border); draw_rectangle(_lx-4,_ly-4,_lx+_lw+4,_gh-12,true);

	// Dispatch to GM tab draw functions
	if (gm_tab == 0) _ly = draw_gm_party(_lx, _ly, _lw, _lh);
	if (gm_tab == 1) _ly = draw_gm_npcs(_lx, _ly, _lw, _lh);
	if (gm_tab == 2) _ly = draw_gm_encounter(_lx, _ly, _lw, _lh);
	if (gm_tab == 3) _ly = draw_gm_factions(_lx, _ly, _lw, _lh);
	if (gm_tab == 4) _ly = draw_gm_campaign(_lx, _ly, _lw, _lh);
	if (gm_tab == 5) _ly = draw_gm_sessionlog(_lx, _ly, _lw, _lh);
	if (gm_tab == 6) _ly = draw_gm_resources(_lx, _ly, _lw, _lh);

} else {
// PLAYER MODE (or GM edit mode) — normal character sheet with tabs

// In GM edit mode, show a "Back to GM" button
if (gm_mode && gm_state == "edit") {
	ui_btn("gm_back", _lx, _ly-2, _lx+110, _ly+20, "< Back to GM", c_border, c_warning);
	draw_set_colour(c_muted); draw_text(_lx+118, _ly, "Editing: " + hero.name);
	_ly += 26;
}

// Tabs — mode-aware rendering (may adjust _lx and _lw)
var _tab_names = ["Character", "Equipment", "Combat", "Psionics", "Perks/Flaws", "Cybertech", "Roll Log", "Info", "Grid", "Aura"];
var _num_tabs = 10;
var _tabs_horizontal = variable_struct_exists(self, "tabs_horizontal") ? tabs_horizontal : false;

if (_tabs_horizontal) {
	// HORIZONTAL tabs across top — width based on text length
	var _tx_cursor = _lx;
	var _pad_h = 14;
	var _h_start_x = _lx;
	for (var _t = 0; _t < _num_tabs; _t++) {
		var _tw = string_width(_tab_names[_t]) + _pad_h;
		var _tkey = "tab" + string(_t);
		variable_struct_set(btn, _tkey, [_tx_cursor, _ly, _tx_cursor+_tw, _ly+22]);
		var _active = (current_tab == _t);
		draw_set_colour(_active ? c_tab_active : c_tab_inactive);
		draw_rectangle(_tx_cursor, _ly, _tx_cursor+_tw, _ly+22, false);
		// Bottom highlight bar on active horizontal tab
		if (_active) {
			draw_set_colour(c_highlight);
			draw_rectangle(_tx_cursor, _ly+20, _tx_cursor+_tw, _ly+22, false);
		}
		draw_set_colour(_active ? c_header : c_muted);
		draw_set_halign(fa_center); draw_text(_tx_cursor + _tw/2, _ly+3, _tab_names[_t]); draw_set_halign(fa_left);
		_tx_cursor += _tw + 3;
	}
	// Capture tab area bounds (horizontal) for hover-to-scroll
	// _tx_cursor was incremented past the final tab + gap, subtract gap for accurate edge
	tab_area_x1 = _h_start_x;
	tab_area_y1 = _ly;
	tab_area_x2 = _tx_cursor - 3;
	tab_area_y2 = _ly + 22;

	ui_btn("tabs_layout_toggle", _tx_cursor+4, _ly, _tx_cursor+72, _ly+22, "Side", c_border, c_muted);
	_ly += 28;
} else {
	// VERTICAL tabs on left side
	var _vtw = 88; var _vth = 22; var _vgap = 2; var _vtx = 4;
	var _vty_start = _ly;

	draw_set_colour(merge_colour(c_panel, c_border, 0.3));
	draw_rectangle(_vtx-2, _vty_start-2, _vtx+_vtw+2, _vty_start + _num_tabs*(_vth+_vgap)+2, false);

	for (var _t = 0; _t < _num_tabs; _t++) {
		var _vty = _vty_start + _t * (_vth + _vgap);
		var _tkey = "tab" + string(_t);
		variable_struct_set(btn, _tkey, [_vtx, _vty, _vtx+_vtw, _vty+_vth]);
		var _active = (current_tab == _t);
		draw_set_colour(_active ? c_tab_active : c_tab_inactive);
		draw_rectangle(_vtx, _vty, _vtx+_vtw, _vty+_vth, false);
		if (_active) { draw_set_colour(c_highlight); draw_rectangle(_vtx+_vtw-2, _vty, _vtx+_vtw, _vty+_vth, false); }
		draw_set_colour(_active ? c_header : c_muted);
		draw_set_halign(fa_center); draw_text(_vtx + _vtw/2, _vty+3, _tab_names[_t]); draw_set_halign(fa_left);
	}
	// Capture tab area bounds (vertical) for hover-to-scroll
	tab_area_x1 = _vtx - 2;
	tab_area_y1 = _vty_start - 2;
	tab_area_x2 = _vtx + _vtw + 2;
	tab_area_y2 = _vty_start + _num_tabs*(_vth+_vgap) + 2;

	var _tog_y = _vty_start + _num_tabs * (_vth + _vgap) + 4;
	ui_btn("tabs_layout_toggle", _vtx, _tog_y, _vtx+_vtw, _tog_y+18, "Top Tabs", c_border, c_muted);

	_lx = _vtx + _vtw + 6;
	_lw = panel_left_w - _vtw - 10;
}

// Content panel background
draw_set_colour(c_panel); draw_rectangle(_lx-4,_ly-4,_lx+_lw+4,_gh-12,false);
draw_set_colour(c_border); draw_rectangle(_lx-4,_ly-4,_lx+_lw+4,_gh-12,true);

// Identity (with Edit Name button — opens inline modal that renames the file too)
draw_set_colour(c_text);
var _sp_name = hero[$ "species"] != undefined ? get_species_name(hero.species) : "Human";
var _prof_line = get_profession_name(hero.profession);
if (hero[$ "secondary_profession"] != undefined && hero.secondary_profession >= 0)
	_prof_line += " / " + get_profession_name(hero.secondary_profession);
var _id_str = hero.name + "  |  " + _sp_name + "  |  " + _prof_line;
draw_text(_lx+8,_ly, _id_str);
ui_btn("edit_hero_name", _lx + string_width(_id_str) + 16, _ly-2, _lx + string_width(_id_str) + 96, _ly+_lh-2, "Rename", c_border, c_amazing);
_ly += _lh;
draw_set_colour(c_muted);
draw_text(_lx+8,_ly, "Career: " + hero.career);
_ly += _lh + 4;

// TAB CONTENT DISPATCH — stats/AC/durability now drawn inside Character tab only
if (current_tab == 0) { _ly = draw_tab_character(_lx, _ly, _lw, _lh); }
if (current_tab == 1) { _ly = draw_tab_equipment(_lx, _ly, _lw, _lh); }
if (current_tab == 2) { _ly = draw_tab_combat(_lx, _ly, _lw, _lh); }
if (current_tab == 3) { _ly = draw_tab_psionics(_lx, _ly, _lw, _lh); }
if (current_tab == 4) { _ly = draw_tab_perks_flaws(_lx, _ly, _lw, _lh); }
if (current_tab == 5) { _ly = draw_tab_cybertech(_lx, _ly, _lw, _lh); }
if (current_tab == 6) { _ly = draw_tab_rolllog(_lx, _ly, _lw, _lh); }
if (current_tab == 7) { _ly = draw_tab_info(_lx, _ly, _lw, _lh); }
if (current_tab == 8) { _ly = draw_tab_grid(_lx, _ly, _lw, _lh); }
if (current_tab == 9) { _ly = draw_tab_aura(_lx, _ly, _lw, _lh); }

} // end player mode / GM edit mode

// ============================================================
// RIGHT PANEL
// ============================================================
var _rx=panel_right_x; var _ry=panel_y; var _rw=panel_right_w;
draw_set_colour(c_panel); draw_rectangle(_rx-4,_ry-4,_rx+_rw+4,_gh-12,false);
draw_set_colour(c_border); draw_rectangle(_rx-4,_ry-4,_rx+_rw+4,_gh-12,true);

// Character buttons
draw_set_colour(c_header); draw_text(_rx+8,_ry,"CHARACTER"); _ry+=_lh+2;
var _hw=(_rw-16)/2;
ui_btn("new_char",_rx+8,_ry,_rx+8+_hw,_ry+24,"New",c_border,c_highlight);
ui_btn("welcome_btn",_rx+12+_hw,_ry,_rx+_rw-8,_ry+24,"Menu",c_border,c_amazing);
_ry+=30;

// Portrait + info + presets — horizontal layout
// Diplomat dual: main portrait behind, secondary inset in bottom-right corner
var _pw2 = 140; var _port_h = 170;
var _portrait_x = _rx+8; var _portrait_y = _ry;

// Check if diplomat with secondary profession
var _is_dual = (hero != undefined && hero[$ "secondary_profession"] != undefined && hero.secondary_profession >= 0);

if (_is_dual) {
	// Draw primary (diplomat) portrait as the main image
	draw_portrait(_portrait_x, _portrait_y, _pw2, _port_h, c_border);

	// Draw secondary profession portrait inset (bottom-right corner, smaller)
	var _inset_w = floor(_pw2 * 0.45);
	var _inset_h = floor(_port_h * 0.45);
	var _inset_x = _portrait_x + _pw2 - _inset_w - 4;
	var _inset_y = _portrait_y + _port_h - _inset_h - 4;

	// Try to load secondary portrait
	var _sec_sp = hero[$ "species"] != undefined ? get_species_name(hero.species) : "Human";
	var _sec_prof = get_profession_name(hero.secondary_profession);
	var _sec_sp_lower = string_lower(string_replace(_sec_sp, "'", ""));
	var _sec_prof_lower = string_lower(string_replace(_sec_prof, " ", "_"));
	var _sec_path = "portraits/" + _sec_sp_lower + "_" + _sec_prof_lower + ".png";

	// Dark border/shadow behind inset
	draw_set_colour(#000000); draw_set_alpha(0.6);
	draw_rectangle(_inset_x-2, _inset_y-2, _inset_x+_inset_w+2, _inset_y+_inset_h+2, false);
	draw_set_alpha(1.0);

	// Draw inset portrait
	if (file_exists(_sec_path)) {
		var _sec_spr = sprite_add(_sec_path, 0, false, false, 0, 0);
		if (_sec_spr != -1) {
			var _sw2 = sprite_get_width(_sec_spr); var _sh2 = sprite_get_height(_sec_spr);
			var _sc2 = min(_inset_w/_sw2, _inset_h/_sh2);
			draw_sprite_ext(_sec_spr, 0, _inset_x+(_inset_w-_sw2*_sc2)/2, _inset_y+(_inset_h-_sh2*_sc2)/2, _sc2, _sc2, 0, c_white, 1.0);
			sprite_delete(_sec_spr);
		}
	} else {
		draw_set_colour(#222244); draw_rectangle(_inset_x, _inset_y, _inset_x+_inset_w, _inset_y+_inset_h, false);
		draw_set_colour(c_muted); draw_set_halign(fa_center);
		draw_text(_inset_x+_inset_w/2, _inset_y+_inset_h/2-6, _sec_prof);
		draw_set_halign(fa_left);
	}
	draw_set_colour(c_warning); draw_rectangle(_inset_x, _inset_y, _inset_x+_inset_w, _inset_y+_inset_h, true);
} else {
	// Standard single portrait
	draw_portrait(_portrait_x, _portrait_y, _pw2, _port_h, c_border);
}
btn.portrait = [_portrait_x, _portrait_y, _portrait_x+_pw2, _portrait_y+_port_h];

// Character summary to the right of portrait
var _info_x = _portrait_x + _pw2 + 10;
if (hero != undefined) {
	var _iy = _portrait_y + 2;
	draw_set_colour(c_text); draw_text(_info_x, _iy, hero.name); _iy += _lh;
	draw_set_colour(c_muted);
	draw_text(_info_x, _iy, (hero[$ "species"] != undefined ? get_species_name(hero.species) : "Human") + " " + get_profession_name(hero.profession)); _iy += _lh;
	draw_text(_info_x, _iy, hero.career); _iy += _lh;
	draw_set_colour(c_warning);
	draw_text(_info_x, _iy, "Pts:" + string(get_total_skill_cost_hero(hero)) + "/" + string(get_adjusted_skill_points(hero))); _iy += _lh+4;
	// Browse + Presets buttons next to portrait
	ui_btn("portrait_browse", _info_x, _iy, _info_x+80, _iy+20, "Browse", c_border, c_amazing);
	ui_btn("portrait_preset", _info_x+86, _iy, _info_x+166, _iy+20, "Presets", c_border, c_good);
}

// Preset list (scrollable, to the right of info area)
if (portrait_dropdown_open) {
	var _pl_x = _info_x + 176; var _pl_y = _portrait_y;
	var _pl_w = _rw - (_pl_x - _rx) - 8; var _pl_h = _port_h;
	draw_set_colour(c_panel); draw_rectangle(_pl_x, _pl_y, _pl_x+_pl_w, _pl_y+_pl_h, false);
	draw_set_colour(c_border); draw_rectangle(_pl_x, _pl_y, _pl_x+_pl_w, _pl_y+_pl_h, true);
	draw_set_colour(c_header); draw_text(_pl_x+4, _pl_y+2, "Presets:");
	if (array_length(portrait_presets) > 0) {
		var _max_show = min(array_length(portrait_presets), floor((_pl_h-20) / 18));
		for (var _pi = 0; _pi < _max_show; _pi++) {
			var _poy = _pl_y + 18 + _pi * 18;
			var _pp_hov = mouse_in(_pl_x, _poy, _pl_x+_pl_w, _poy+18);
			if (_pp_hov) { draw_set_colour(c_border); draw_rectangle(_pl_x+1, _poy, _pl_x+_pl_w-1, _poy+18, false); }
			draw_set_colour(_pp_hov ? c_highlight : c_text);
			draw_text(_pl_x+4, _poy+1, portrait_presets[_pi].name);
			variable_struct_set(btn, "pp"+string(_pi), [_pl_x, _poy, _pl_x+_pl_w, _poy+18]);
		}
	} else {
		draw_set_colour(c_muted); draw_text(_pl_x+4, _pl_y+22, "No presets found");
	}
}

_ry += _port_h + 8;

// Quick rolls moved to Combat tab (Tab 2)

// Multiplayer status (only when connected)
if (net_is_connected()) {
	draw_set_colour(c_header);
	draw_text(_rx+8, _ry, "MULTIPLAYER");
	_ry += _lh;
	draw_set_colour(c_good); draw_circle(_rx+12, _ry+6, 4, false);
	draw_set_colour(c_text); draw_text(_rx+22, _ry, "Session: " + net_session_code);
	_ry += _lh;
	var _plist = net_get_players();
	for (var _pi = 0; _pi < array_length(_plist); _pi++) {
		var _p = _plist[_pi];
		var _pname = is_struct(_p) ? (_p[$ "name"] ?? "?") : string(_p);
		var _phost = is_struct(_p) ? (_p[$ "is_host"] ?? false) : false;
		draw_set_colour(_phost ? c_amazing : c_text);
		// Truncate long names so they don't bleed past the panel edge
		draw_text_ext(_rx+16, _ry, (_phost ? "[GM] " : "") + _pname, -1, _rw - 24);
		_ry += _lh;
		// GM-only per-player +Camp button (request character from player).
		// The "Push Char" button used to live here too but moved to the GM Party tab
		// in v0.62.0 — it now uses the actual party member statblock instead of obj_game.hero.
		if (gm_mode && net_is_host() && !_phost) {
			ui_btn("gm_add_player_"+string(_pi), _rx+16, _ry-2, _rx+_rw-16, _ry+_lh-2, "+Camp (request character)", c_border, c_good);
			_ry += _lh + 2;
		}
	}
	_ry += 2;

	// Chat input — always available when connected, in BOTH player and GM mode.
	// Click to focus, type, Enter to send. Supports /name and /gm whisper prefixes.
	var _chat_focused = (net_input_focus == "chat");
	var _chat_y = _ry;
	var _chat_h = 22;
	draw_set_colour(_chat_focused ? c_highlight : c_border);
	draw_rectangle(_rx+8, _chat_y, _rx+_rw-8, _chat_y+_chat_h, true);
	draw_set_colour(_chat_focused ? c_text : c_muted);
	var _chat_display = net_chat_buffer;
	if (_chat_display == "") _chat_display = _chat_focused ? "Type message... (/name for whisper)" : "Click to chat";
	// Show cursor when focused
	if (_chat_focused && (current_time mod 1000 < 500) && net_chat_buffer != "") {
		_chat_display = net_chat_buffer + "_";
	}
	draw_text(_rx+12, _chat_y+3, _chat_display);
	btn.sidebar_chat = [_rx+8, _chat_y, _rx+_rw-8, _chat_y+_chat_h];
	_ry += _chat_h + 6;
}

// Dice Roller
draw_set_colour(c_header); draw_text(_rx+8,_ry,"DICE ROLLER"); _ry+=_lh+2;

// ---- GM FREE-FORM DICE PANEL ----
// Only visible in GM mode. Quick buttons for Alternity control dice plus a
// text input for arbitrary expressions like "1d20-4x3" or "3d6x6".
if (gm_mode) {
	draw_set_colour(c_muted); draw_text(_rx+8, _ry, "GM Quick Dice:"); _ry += _lh;
	var _qd_w = floor((_rw - 24) / 3);
	ui_btn("gmd_2d6m2", _rx+8,            _ry, _rx+8+_qd_w,        _ry+20, "2d6-2", c_border, c_amazing);
	ui_btn("gmd_1d8",   _rx+12+_qd_w,     _ry, _rx+12+_qd_w*2,     _ry+20, "1d8",   c_border, c_amazing);
	ui_btn("gmd_2d4m1", _rx+16+_qd_w*2,   _ry, _rx+16+_qd_w*3,     _ry+20, "2d4-1", c_border, c_amazing);
	_ry += 24;
	// Free-form input
	var _gmd_focused = (net_input_focus == "gmdice");
	draw_set_colour(_gmd_focused ? c_highlight : c_border);
	draw_rectangle(_rx+8, _ry, _rx+_rw-8, _ry+22, true);
	var _gmd_disp = gm_dice_buffer;
	if (_gmd_disp == "") _gmd_disp = _gmd_focused ? "e.g. 1d20-4x3" : "Click to type expression";
	if (_gmd_focused && (current_time mod 1000 < 500) && gm_dice_buffer != "") _gmd_disp = gm_dice_buffer + "_";
	draw_set_colour(_gmd_focused ? c_text : c_muted);
	draw_text(_rx+12, _ry+3, _gmd_disp);
	btn.gmd_input = [_rx+8, _ry, _rx+_rw-8, _ry+22];
	_ry += 26;
	ui_btn("gmd_roll", _rx+8, _ry, _rx+_rw-8, _ry+22, "Roll Expression", c_border, c_highlight);
	_ry += 26;
	// Show last result if any
	if (gm_dice_last_result != undefined) {
		var _gdr = gm_dice_last_result;
		if (_gdr.ok) {
			draw_set_colour(c_text);
			var _gdr_line = _gdr.expr + " => ";
			for (var _gri = 0; _gri < array_length(_gdr.results); _gri++) {
				if (_gri > 0) _gdr_line += ", ";
				_gdr_line += string(_gdr.results[_gri]);
			}
			draw_text_ext(_rx+8, _ry, _gdr_line, -1, _rw-16);
			_ry += string_height_ext(_gdr_line, -1, _rw-16) + 2;
		} else {
			draw_set_colour(c_failure); draw_text(_rx+8, _ry, "Error: " + _gdr.error); _ry += _lh;
		}
	}
	_ry += 4;
}

// Show staged roll info OR selected skill
if (staged_roll != undefined) {
	var _sr = staged_roll;
	draw_set_colour(c_highlight); draw_text(_rx+8,_ry,"STAGED: " + _sr.request.name); _ry+=_lh;
	draw_set_colour(c_muted);
	draw_text(_rx+8,_ry,"Score: "+string(_sr.request.score_ord)+"/"+string(_sr.request.score_good)+"/"+string(_sr.request.score_amz));
	_ry+=_lh;
	// Show computed modifiers
	if (array_length(_sr.modifiers) > 0) {
		var _cmstr = "";
		for (var _cmi = 0; _cmi < array_length(_sr.modifiers); _cmi++) {
			if (_cmi > 0) _cmstr += ", ";
			_cmstr += _sr.modifiers[_cmi];
		}
		draw_set_colour(c_warning); draw_text_ext(_rx+8, _ry, "Auto: "+_cmstr, -1, _rw-16);
		_ry += string_height_ext("Auto: "+_cmstr, -1, _rw-16);
	}
	// Show player override if different from computed
	var _pdelta = situation_step - _sr.computed_step;
	if (_pdelta != 0) {
		draw_set_colour(_pdelta > 0 ? c_failure : c_good);
		draw_text(_rx+8, _ry, "Player Adj: " + (_pdelta >= 0 ? "+" : "") + string(_pdelta));
		_ry += _lh;
	}
} else if (hero != undefined && array_length(hero.skills)>0) {
	if (selected_skill >= array_length(hero.skills)) selected_skill = array_length(hero.skills) - 1;
	var _sk=hero.skills[selected_skill];
	var _sn=(_sk.specialty!="")?_sk.specialty:_sk.broad_skill;
	draw_set_colour(c_muted); draw_text(_rx+8,_ry,"Skill:");
	draw_set_colour(c_text); draw_text(_rx+60,_ry,_sn); _ry+=_lh;
	draw_set_colour(c_muted);
	draw_text(_rx+8,_ry,"Score: "+string(_sk.score_ordinary)+"/"+string(_sk.score_good)+"/"+string(_sk.score_amazing));
	_ry+=_lh;
}
_ry += 2;

// Situation die adjuster — positioned relative to panel width
draw_set_colour(c_muted); draw_text(_rx+8,_ry,"Situation:");
var _steps_from_base = situation_step - SIT_STEP_BASE;
var _sc2=c_text; if(_steps_from_base<0)_sc2=c_good; if(_steps_from_base>0)_sc2=c_warning;
var _sit_label_w = string_width("Situation:") + 6;
draw_set_colour(_sc2); draw_text(_rx+8+_sit_label_w,_ry,situation_step_name(situation_step));
// Show step count: "(-2 bonus)" or "(+3 penalty)" or "(base)"
var _die_name_w = string_width(situation_step_name(situation_step)) + 6;
var _step_txt_x = _rx + 8 + _sit_label_w + _die_name_w;
if (_steps_from_base < 0) {
	draw_set_colour(c_good); draw_text(_step_txt_x,_ry, string(_steps_from_base) + " bonus");
} else if (_steps_from_base > 0) {
	draw_set_colour(c_warning); draw_text(_step_txt_x,_ry, "+" + string(_steps_from_base) + " penalty");
} else {
	draw_set_colour(c_muted); draw_text(_step_txt_x,_ry, "(base)");
}
var _sby=_ry-2;
var _btn_w = 28;
var _btn_gap = 4;
var _btn_x = _rx + _rw - (_btn_w*3 + _btn_gap*2 + 60);
ui_btn("sit_left",_btn_x,_sby,_btn_x+_btn_w,_sby+20,"<",c_border,c_good);
ui_btn("sit_right",_btn_x+_btn_w+_btn_gap,_sby,_btn_x+_btn_w*2+_btn_gap,_sby+20,">",c_border,c_warning);
ui_btn("sit_reset",_btn_x+_btn_w*2+_btn_gap*2,_sby,_rx+_rw-8,_sby+20,"Reset",c_border,c_amazing);
_ry+=_lh+6;

// "No fail" toggle in the general roll area — clamps failure to MARGINAL.
// Also exposed on the Combat tab Options row; this duplicate makes it reachable
// from any tab while staging a roll.
var _cf_box_x = _rx+8; var _cf_box_y = _ry; var _cf_box_w = 14;
draw_set_colour(c_border); draw_rectangle(_cf_box_x, _cf_box_y, _cf_box_x+_cf_box_w, _cf_box_y+_cf_box_w, true);
if (cant_fail_mode) {
	draw_set_colour(c_good); draw_rectangle(_cf_box_x+3, _cf_box_y+3, _cf_box_x+_cf_box_w-3, _cf_box_y+_cf_box_w-3, false);
}
draw_set_colour(cant_fail_mode ? c_good : c_muted);
draw_text(_cf_box_x+_cf_box_w+6, _cf_box_y-2, "No fail (clamp to MARGINAL)");
btn.sidebar_cant_fail = [_cf_box_x, _cf_box_y, _rx+_rw-8, _cf_box_y+_cf_box_w];
_ry += _lh + 4;

ui_btn("roll",_rx+30,_ry,_rx+_rw-30,_ry+28,is_rolling?"ROLLING...":"ROLL",c_border,c_highlight); _ry+=36;

// Result
if (is_rolling) {
	draw_set_colour(c_text); draw_set_halign(fa_center);
	draw_text(_rx+_rw/2,_ry+4,string(irandom_range(1,20))); draw_set_halign(fa_left); _ry+=28;
} else if (last_roll != undefined) {
	// Skill name
	draw_set_colour(c_text); draw_text(_rx+8,_ry, last_roll.skill_name); _ry+=_lh;

	// Control die line
	var _ctrl_label = "Control:";
	draw_set_colour(c_muted); draw_text(_rx+8,_ry,_ctrl_label);
	var _ctrl_val_x = _rx + 8 + string_width(_ctrl_label) + 6;
	draw_set_colour(c_text); draw_text(_ctrl_val_x,_ry, string(last_roll.control_roll));
	_ry+=_lh;

	// Situation die line (color-coded)
	var _sit_sides = get_step(last_roll.situation_step).sides;
	if (_sit_sides > 0) {
		var _is_bonus = get_step(last_roll.situation_step).bonus;
		var _sit_label = "Situation";
		draw_set_colour(c_muted); draw_text(_rx+8,_ry,_sit_label);
		var _sit_die_x = _rx + 8 + string_width(_sit_label) + 4;
		var _sit_die_str = "(" + situation_step_name(last_roll.situation_step) + "):";
		// - (bonus, subtracted from roll) = green, + (penalty, added to roll) = yellow
		draw_set_colour(_is_bonus ? c_good : c_warning);
		draw_text(_sit_die_x,_ry, _sit_die_str);
		var _sit_val_x = _sit_die_x + string_width(_sit_die_str) + 6;
		draw_set_colour(c_text); draw_text(_sit_val_x,_ry, string(last_roll.situation_roll));
		_ry+=_lh;
	}

	// Total line with formula
	var _total_label = "Total";
	draw_set_colour(c_muted); draw_text(_rx+8,_ry,_total_label);
	var _total_x = _rx + 8 + string_width(_total_label) + 4;
	draw_set_colour(c_text);
	if (_sit_sides > 0) {
		var _is_bonus2 = get_step(last_roll.situation_step).bonus;
		var _op = _is_bonus2 ? " - " : " + ";
		var _formula_str = "(" + string(last_roll.control_roll) + _op + string(last_roll.situation_roll) + ")";
		draw_text(_total_x,_ry, _formula_str);
		_total_x += string_width(_formula_str) + 4;
	}
	draw_set_colour(c_text); draw_text(_total_x,_ry,"= " + string(last_roll.total));
	_ry+=_lh;

	// Degree of success (color-coded)
	var _dc=c_text; switch(last_roll.degree){case -1:case 0:_dc=c_failure;break;case 1:_dc=c_text;break;case 2:_dc=c_good;break;case 3:_dc=c_amazing;break;}
	draw_set_colour(_dc); draw_set_halign(fa_center);
	draw_text(_rx+_rw/2,_ry,">> "+last_roll.degree_name+" <<"); draw_set_halign(fa_left); _ry+=_lh;
	// Modifiers breakdown
	if (last_roll[$ "modifiers"] != undefined && array_length(last_roll.modifiers) > 0) {
		var _mstr = "";
		for (var _mi = 0; _mi < array_length(last_roll.modifiers); _mi++) {
			if (_mi > 0) _mstr += ", ";
			_mstr += last_roll.modifiers[_mi];
		}
		draw_set_colour(c_warning); draw_text_ext(_rx+8, _ry, "Mods: "+_mstr, -1, _rw-16);
		_ry += string_height_ext("Mods: "+_mstr, -1, _rw-16);
	}
	_ry += 4;
}

// Log — verbose with modifiers
if (array_length(roll_log)>0) {
	draw_set_colour(c_header); draw_text(_rx+8,_ry,"ROLL HISTORY"); _ry+=_lh;
	for (var _i=0; _i<min(array_length(roll_log), 8); _i++) {
		var _e=roll_log[_i]; var _ec=c_muted;
		switch(_e.degree){case -1:case 0:_ec=c_failure;break;case 1:_ec=c_text;break;case 2:_ec=c_good;break;case 3:_ec=c_amazing;break;}
		// Line 1: skill name + result
		draw_set_colour(_ec);
		var _line1 = _e.skill_name + " => " + _e.degree_name + " (" + string(_e.total) + ")";
		draw_text(_rx+8, _ry, _line1); _ry += _lh;
		// Line 2: modifiers (if any)
		var _mods = _e[$ "mod_str"] ?? "";
		if (_mods != "") {
			draw_set_colour(c_warning);
			draw_text_ext(_rx+16, _ry, _mods, -1, _rw-24);
			_ry += string_height_ext(_mods, -1, _rw-24);
		}
	} _ry+=4;
}

// File buttons
draw_set_colour(c_header); draw_text(_rx+8,_ry,"FILE"); _ry+=_lh+2;
var _fhw=(_rw-20)/2;
ui_btn("export",_rx+8,_ry,_rx+8+_fhw,_ry+22,"Export Char",c_border,c_good);
ui_btn("import",_rx+12+_fhw,_ry,_rx+_rw-8,_ry+22,"Import Char",c_border,c_amazing); _ry+=28;

draw_set_colour(c_header); draw_text(_rx+8,_ry,"DATA FILES"); _ry+=_lh+2;
ui_btn("save_lib",_rx+8,_ry,_rx+8+_fhw,_ry+22,"Save Data",c_border,c_good);
ui_btn("load_lib",_rx+12+_fhw,_ry,_rx+_rw-8,_ry+22,"Load Data",c_border,c_amazing); _ry+=28;

// Cost legend (PHB two-tier)
draw_set_colour(c_muted); draw_text(_rx+8,_ry,"Cost:");
draw_set_colour(c_good); draw_text(_rx+50,_ry,"P=Prof: broad 3, spec 1/2/3");
draw_set_colour(c_muted); draw_text(_rx+280,_ry,"-=Other: 4, 2/3/4");
// EXIT — always visible, always available
ui_btn("exit_app", _rx+_rw-80, _ry-2, _rx+_rw-8, _ry+18, "EXIT", c_failure, #ff0000);
_ry+=_lh;

if (status_timer>0) {
	draw_set_alpha(min(1.0,status_timer/30)); draw_set_colour(c_good);
	draw_text(_rx+8,_ry,status_msg); draw_set_alpha(1.0);
}

// ============================================================
// SKILL BROWSER OVERLAY
// ============================================================
if (browser_open) {
	draw_set_alpha(0.75); draw_set_colour(#000000); draw_rectangle(0,0,_gw,_gh,false); draw_set_alpha(1.0);
	var _bx=40;var _byy=40;var _bw=_gw-80;var _bh=_gh-80;
	draw_set_colour(c_panel); draw_rectangle(_bx,_byy,_bx+_bw,_byy+_bh,false);
	draw_set_colour(c_border); draw_rectangle(_bx,_byy,_bx+_bw,_byy+_bh,true);
	draw_set_colour(c_header); draw_text(_bx+12,_byy+8,"SKILL BROWSER");
	var _bSpent=get_total_skill_cost_hero(hero); var _bBudget=get_adjusted_skill_points(hero);
	draw_set_colour((_bSpent<=_bBudget)?c_good:c_failure); draw_text(_bx+180,_byy+8,"Pts: "+string(_bSpent)+"/"+string(_bBudget));
	ui_btn("browser_close", _bx+_bw-36,_byy+4,_bx+_bw-4,_byy+26,"X",c_border,c_failure);
	// Stat group buttons in browser — switch which ability's skills are shown
	var _bsg_y=_byy+30; var _bsg_w=floor((_bw-24)/6);
	var _bsg_keys=global.ability_keys; var _bsg_names=global.ability_names;
	for (var _bai=0;_bai<6;_bai++) {
		var _bsgx=_bx+12+_bai*_bsg_w;
		var _bsg_active=(active_stat_group==_bsg_keys[_bai]);
		ui_btn("browser_stat_"+_bsg_keys[_bai],_bsgx,_bsg_y,_bsgx+_bsg_w-4,_bsg_y+18,_bsg_names[_bai],_bsg_active?c_highlight:c_border,c_highlight);
	}
	draw_set_colour(c_muted); draw_text(_bx+12,_bsg_y+22,"Click to add | Mouse wheel to scroll");
	var _list_y=_bsg_y+40; btn.browser_list_y=_list_y;
	var _bcount=array_length(browser_list); var _bend=min(browser_scroll+browser_max_visible,_bcount);
	// Clear stale browser remove-button rects to prevent index desync when scrolled
	for (var _clr = 0; _clr < _bcount; _clr++) { variable_struct_remove(btn, "brm"+string(_clr)); variable_struct_remove(btn, "srm"+string(_clr)); }
	for(var _i=browser_scroll;_i<_bend;_i++){
		var _e=browser_list[_i]; var _is=(_i==browser_selected); var _row_y=_list_y+(_i-browser_scroll)*_lh;
		if(_is){draw_set_colour(c_border);draw_rectangle(_bx+4,_row_y-1,_bx+_bw-4,_row_y+_lh-3,false);}
		if(_e.type=="broad"){
			if(_e.owned){draw_set_colour(_is?c_highlight:c_amazing);draw_text(_bx+12,_row_y,_e.broad);draw_set_colour(c_good);draw_text(_bx+300,_row_y,"owned");
			var _rmk="brm"+string(_i);ui_btn(_rmk,_bx+370,_row_y,_bx+420,_row_y+_lh-2,"X",c_border,c_failure);}
			else{draw_set_colour(_is?#ffffff:c_text);draw_text(_bx+12,_row_y,_e.broad);draw_set_colour(_is?c_good:c_warning);draw_text(_bx+300,_row_y,"[+Add]");}
			draw_set_colour(c_muted);draw_text(_bx+420,_row_y,string_upper(_e.ability));
		}else if(_e.type=="specialty"){draw_set_colour(_is?c_text:c_muted);draw_text(_bx+36,_row_y,_e.specialty);draw_set_colour(c_good);draw_text(_bx+300,_row_y,"owned");
			var _rmk="srm"+string(_i);ui_btn(_rmk,_bx+370,_row_y,_bx+420,_row_y+_lh-2,"X",c_border,c_failure);
		}else if(_e.type=="add"){draw_set_colour(_is?#ffffff:c_text);draw_text(_bx+36,_row_y,_e.specialty);draw_set_colour(_is?c_good:c_warning);draw_text(_bx+300,_row_y,"[+Add]");}
	}
	if(browser_flash_timer>0){draw_set_alpha(browser_flash_timer/40);draw_set_colour(c_good);draw_set_halign(fa_center);draw_text(_bx+_bw/2,_byy+_bh-30,"Added: "+browser_flash_name);draw_set_halign(fa_left);draw_set_alpha(1.0);}
}

// ============================================================
// CHARGEN WIZARD — 3-screen flow (Race → Profession → Career)
// All draw work happens in scr_chargen.gml — Draw_64 just dispatches.
// ============================================================
if (chargen_open) {
	draw_chargen_wizard(_gw, _gh, _lh);
}

// ============================================================
// PUSH CHARACTER PICKER — opens when GM clicks a Push button on the GM Party tab.
// Centered floating box listing connected non-GM players. Click a player → push.
// ============================================================
if (push_picker_open) {
	// Dim background
	draw_set_alpha(0.65); draw_set_colour(#000000); draw_rectangle(0, 0, _gw, _gh, false); draw_set_alpha(1.0);

	// Centered box (~440x340)
	var _ppw = 440; var _pph = 340;
	var _ppx = (_gw - _ppw) / 2;
	var _ppy = (_gh - _pph) / 2;
	draw_set_colour(c_panel); draw_rectangle(_ppx, _ppy, _ppx+_ppw, _ppy+_pph, false);
	draw_set_colour(c_border); draw_rectangle(_ppx, _ppy, _ppx+_ppw, _ppy+_pph, true);

	// Header
	var _push_char_name = "?";
	if (push_picker_party_idx >= 0 && push_picker_party_idx < array_length(global.party)) {
		_push_char_name = global.party[push_picker_party_idx].name;
	}
	draw_set_colour(c_header); draw_text(_ppx+12, _ppy+10, "PUSH CHARACTER");
	draw_set_colour(c_text);   draw_text(_ppx+12, _ppy+28, _push_char_name);
	draw_set_colour(c_muted);  draw_text(_ppx+12, _ppy+46, "Click a player below to send this character to them only.");

	// Cancel X (top-right)
	ui_btn("pushpick_cancel", _ppx+_ppw-32, _ppy+6, _ppx+_ppw-6, _ppy+28, "X", c_border, c_failure);

	// Player list — only non-GM players
	var _list_y = _ppy + 70;
	var _ppl = net_get_players();
	var _row_h = 28;
	var _shown = 0;
	for (var _ppi = 0; _ppi < array_length(_ppl); _ppi++) {
		var _pp = _ppl[_ppi];
		var _pp_name = is_struct(_pp) ? (_pp[$ "name"] ?? "") : string(_pp);
		var _pp_host = is_struct(_pp) ? (_pp[$ "is_host"] ?? false) : false;
		if (_pp_host || _pp_name == "") continue;
		if (_list_y + _row_h > _ppy + _pph - 16) break;
		ui_btn("pushpick_player_" + string(_ppi), _ppx+12, _list_y, _ppx+_ppw-12, _list_y+_row_h-4, _pp_name, c_border, c_good);
		_list_y += _row_h;
		_shown++;
	}
	if (_shown == 0) {
		draw_set_colour(c_muted);
		draw_set_halign(fa_center);
		draw_text(_ppx + _ppw/2, _ppy + _pph/2, "No other players in this session.");
		draw_set_halign(fa_left);
	}
}

// ============================================================
// INLINE TEXT MODAL — drawn after everything but the tooltip.
// Replaces all get_string() popups. Centered floating box with label, value
// field, Save and Cancel buttons. Real-time saves on every keystroke.
// ============================================================
if (text_modal_open) {
	// Compute centered box position based on screen size
	text_modal_w = min(560, _gw - 80);
	text_modal_h = 160;
	text_modal_x = (_gw - text_modal_w) / 2;
	text_modal_y = (_gh - text_modal_h) / 2;
	var _tmx = text_modal_x; var _tmy = text_modal_y;
	var _tmw = text_modal_w; var _tmh = text_modal_h;

	// Dim ONLY the area directly behind the box (the user said: only lock what's eclipsed)
	draw_set_colour(#000000); draw_set_alpha(0.55);
	draw_rectangle(_tmx-12, _tmy-12, _tmx+_tmw+12, _tmy+_tmh+12, false);
	draw_set_alpha(1.0);

	// Box body
	draw_set_colour(c_panel); draw_rectangle(_tmx, _tmy, _tmx+_tmw, _tmy+_tmh, false);
	draw_set_colour(c_border); draw_rectangle(_tmx, _tmy, _tmx+_tmw, _tmy+_tmh, true);

	// Label
	draw_set_colour(c_header); draw_text(_tmx+12, _tmy+10, text_modal_label);
	draw_set_colour(c_muted); draw_text(_tmx+12, _tmy+30, "Real-time save. Enter or Save = commit. Esc = cancel.");

	// Text field
	var _tfy = _tmy + 56;
	var _tfh = 28;
	draw_set_colour(c_highlight); draw_rectangle(_tmx+12, _tfy, _tmx+_tmw-12, _tfy+_tfh, true);
	draw_set_colour(c_text);
	var _disp = text_modal_buffer;
	if ((current_time mod 1000) < 500) _disp += "_";
	// Wrap long text within the field
	draw_text_ext(_tmx+18, _tfy+5, _disp, -1, _tmw-36);

	// Char count
	draw_set_colour(c_muted);
	draw_text(_tmx+_tmw-90, _tfy+_tfh+4, string(string_length(text_modal_buffer)) + "/" + string(text_modal_max_len));

	// Save / Cancel buttons
	var _btn_y = _tmy + _tmh - 36;
	ui_btn("text_modal_save",   _tmx+_tmw-180, _btn_y, _tmx+_tmw-100, _btn_y+26, "Save",   c_border, c_good);
	ui_btn("text_modal_cancel", _tmx+_tmw-92,  _btn_y, _tmx+_tmw-12,  _btn_y+26, "Cancel", c_border, c_failure);
	// Mark the modal area so click-through detection can know what's eclipsed
	btn.text_modal_area = [_tmx-12, _tmy-12, _tmx+_tmw+12, _tmy+_tmh+12];
}

// ============================================================
// TOOLTIP — drawn absolute last, on top of everything
// ============================================================
if (_tooltip_text != "" && game_state == "sheet") {
	var _tw2 = min(350, string_width_ext(_tooltip_text, -1, 350) + 20);
	var _th2 = string_height_ext(_tooltip_text, -1, 340) + 12;
	// Keep on screen
	var _tx = min(_tooltip_x, _gw - _tw2 - 8);
	var _ty = min(_tooltip_y, _gh - _th2 - 8);
	draw_set_colour(#111122); draw_set_alpha(0.95);
	draw_rectangle(_tx, _ty, _tx+_tw2, _ty+_th2, false);
	draw_set_alpha(1.0);
	draw_set_colour(c_border); draw_rectangle(_tx, _ty, _tx+_tw2, _ty+_th2, true);
	draw_set_colour(c_text);
	draw_text_ext(_tx+8, _ty+6, _tooltip_text, -1, 340);
}
