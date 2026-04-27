/// @description Tab drawing functions extracted from Draw_64.gml
/// Each function draws one tab's content and returns the updated _ly position.
/// These run in obj_game context (GML scripts do this automatically),
/// so hero, btn, c_* colors, and all state variables are accessible directly.

/// @function draw_tab_character(_lx, _ly, _lw, _lh)
/// @description TAB 0: CHARACTER — stats + skills, layout adapts to tabs orientation.
/// Vertical tabs => stats horizontal across the top, skills below in single column.
/// Horizontal tabs => stats vertical column on the left, skills in second column on the right.
function draw_tab_character(_lx, _ly, _lw, _lh) {
	var _ab_names = global.ability_names;
	var _ab_keys = global.ability_keys;
	var _ab_vals = [hero.str.score, hero.dex.score, hero.con.score, hero.int_.score, hero.wil.score, hero.per.score];
	var _stats_vertical = tabs_horizontal; // when tabs are on top, stats go in a column

	// ── STAT GROUP BUTTONS — orientation depends on tabs_horizontal ──
	var _skill_x = _lx + 8;       // where the skill column starts (overridden if stats vertical)
	var _skill_w = _lw - 16;      // width available for skill column
	var _post_stats_y = _ly;      // y after the stat block

	if (_stats_vertical) {
		// Stats column on the left, ~140px wide
		var _stat_col_w = 140;
		var _stat_x = _lx + 8;
		for (var _ai = 0; _ai < 6; _ai++) {
			var _stat_y = _ly + _ai * 24;
			var _is_active = (active_stat_group == _ab_keys[_ai]);
			draw_set_colour(_is_active ? c_border : c_panel);
			draw_rectangle(_stat_x, _stat_y-2, _stat_x+_stat_col_w, _stat_y+20, false);
			draw_set_colour(_is_active ? c_highlight : c_border);
			draw_rectangle(_stat_x, _stat_y-2, _stat_x+_stat_col_w, _stat_y+20, true);
			draw_set_colour(_is_active ? c_highlight : c_text);
			draw_text(_stat_x+24, _stat_y+2, _ab_names[_ai] + " " + string(_ab_vals[_ai]));
			ui_btn("ab_m"+string(_ai), _stat_x+2,                  _stat_y, _stat_x+18,                _stat_y+18, "-", c_border, c_failure);
			ui_btn("ab_p"+string(_ai), _stat_x+_stat_col_w-18,     _stat_y, _stat_x+_stat_col_w-2,     _stat_y+18, "+", c_border, c_good);
			variable_struct_set(btn, "stat_group_"+_ab_keys[_ai], [_stat_x+19, _stat_y-2, _stat_x+_stat_col_w-19, _stat_y+20]);
		}
		// Compact durability text under stats
		var _dur_y = _ly + 6 * 24 + 8;
		draw_set_colour(c_warning);   draw_text(_stat_x, _dur_y,        "Stun: "  + string(hero.stun.current)   + "/" + string(hero.stun.max));
		draw_set_colour(c_highlight); draw_text(_stat_x, _dur_y+_lh,    "Wound: " + string(hero.wound.current)  + "/" + string(hero.wound.max));
		draw_set_colour(c_failure);   draw_text(_stat_x, _dur_y+_lh*2,  "Mortal: "+ string(hero.mortal.current) + "/" + string(hero.mortal.max));
		// Click any of the durability lines to jump to Combat tab
		variable_struct_set(btn, "char_durability_goto_combat", [_stat_x-2, _dur_y-2, _stat_x+_stat_col_w, _dur_y+_lh*3+2]);
		// Skill column starts to the right of stats
		_skill_x = _stat_x + _stat_col_w + 12;
		_skill_w = _lx + _lw - _skill_x - 8;
		_post_stats_y = _ly; // skills start at the same y as stats
	} else {
		// Stats horizontal across the top
		var _sgw = floor((_lw - 16) / 6);
		for (var _ai = 0; _ai < 6; _ai++) {
			var _sgx = _lx + 8 + _ai * _sgw;
			var _is_active = (active_stat_group == _ab_keys[_ai]);
			draw_set_colour(_is_active ? c_border : c_panel);
			draw_rectangle(_sgx, _ly-2, _sgx+_sgw-4, _ly+20, false);
			draw_set_colour(_is_active ? c_highlight : c_border);
			draw_rectangle(_sgx, _ly-2, _sgx+_sgw-4, _ly+20, true);
			draw_set_colour(_is_active ? c_highlight : c_text);
			draw_text(_sgx+20, _ly+2, _ab_names[_ai] + ":" + string(_ab_vals[_ai]));
			ui_btn("ab_m"+string(_ai), _sgx+2,        _ly, _sgx+16,         _ly+18, "-", c_border, c_failure);
			ui_btn("ab_p"+string(_ai), _sgx+_sgw-20,  _ly, _sgx+_sgw-6,     _ly+18, "+", c_border, c_good);
			variable_struct_set(btn, "stat_group_"+_ab_keys[_ai], [_sgx+17, _ly-2, _sgx+_sgw-21, _ly+20]);
		}
		_post_stats_y = _ly + 26;
		// Compact durability row + click hitbox — dynamic widths to avoid collisions
		var _dx = _lx + 8;
		var _stun_str   = "Stun: "   + string(hero.stun.current)   + "/" + string(hero.stun.max);
		var _wound_str  = "Wound: "  + string(hero.wound.current)  + "/" + string(hero.wound.max);
		var _mortal_str = "Mortal: " + string(hero.mortal.current) + "/" + string(hero.mortal.max);
		var _hint_str   = "(click for Combat tab)";
		draw_set_colour(c_warning);   draw_text(_dx, _post_stats_y, _stun_str);   _dx += string_width(_stun_str)   + 12;
		draw_set_colour(c_highlight); draw_text(_dx, _post_stats_y, _wound_str);  _dx += string_width(_wound_str)  + 12;
		draw_set_colour(c_failure);   draw_text(_dx, _post_stats_y, _mortal_str); _dx += string_width(_mortal_str) + 12;
		draw_set_colour(c_muted);     draw_text(_dx, _post_stats_y, _hint_str);
		var _hit_right = _dx + string_width(_hint_str) + 4;
		variable_struct_set(btn, "char_durability_goto_combat", [_lx+6, _post_stats_y-2, _hit_right, _post_stats_y+_lh]);
		_post_stats_y += _lh + 4;
	}

	// ── SKILL HEADER — points + Add/Browse ──
	var _sky = _post_stats_y;
	draw_set_colour(c_header); draw_text(_skill_x, _sky, "SKILLS ("+string_upper(active_stat_group)+")");
	var _spent = get_total_skill_cost_hero(hero);
	var _budget = get_adjusted_skill_points(hero);
	draw_set_colour((_spent<=_budget) ? c_good : c_failure);
	draw_text(_skill_x + 130, _sky, "Pts:"+string(_spent)+"/"+string(_budget));
	ui_btn("add_skills", _skill_x + _skill_w - 130, _sky-2, _skill_x + _skill_w - 4, _sky+_lh-2, "+ Add/Browse", c_border, c_highlight);
	_sky += _lh;

	// Active Perks, Flaws & Racial Traits with radio toggles
	var _has_pf = false;
	for (var _fxi = 0; _fxi < array_length(hero.fx); _fxi++) {
		var _t = hero.fx[_fxi].type;
		if (_t == "perk" || _t == "flaw" || _t == "racial") { _has_pf = true; break; }
	}
	if (_has_pf) {
		draw_set_colour(c_muted); draw_text(_skill_x, _sky, "Active FX:");
		var _pfx = _skill_x + 92;
		var _pfi = 0; var _ffi = 0; var _rfi = 0;
		for (var _fxi = 0; _fxi < array_length(hero.fx); _fxi++) {
			var _fe = hero.fx[_fxi];
			var _t = _fe.type;
			if (_t != "perk" && _t != "flaw" && _t != "racial") continue;
			var _is_active = _fe[$ "active"] ?? true;
			var _is_perk = (_t == "perk");
			var _is_racial = (_t == "racial");
			var _color = _is_racial ? c_amazing : (_is_perk ? c_good : c_failure);
			var _rx2 = _pfx; var _ry2 = _sky + 2;
			draw_set_colour(_is_active ? _color : c_border);
			draw_circle(_rx2 + 6, _ry2 + 6, 6, true);
			if (_is_active) draw_circle(_rx2 + 6, _ry2 + 6, 3, false);
			draw_set_colour(_is_active ? _color : c_muted);
			// For racial entries, strip the species prefix from the displayed label
			var _plabel = _fe.name;
			if (_is_racial) {
				var _fxd = get_fx_data(_fe.name);
				if (_fxd != undefined) {
					var _sp = _fxd[$ "species"] ?? "";
					if (_sp != "") {
						var _prefix = string_upper(string_char_at(_sp, 1)) + string_copy(_sp, 2, string_length(_sp)-1) + " ";
						if (string_pos(_prefix, _plabel) == 1) _plabel = string_copy(_plabel, string_length(_prefix)+1, string_length(_plabel) - string_length(_prefix));
					}
				}
			} else {
				_plabel += ((_fe[$ "quality"] ?? "") != "" ? " [" + _fe.quality + "]" : "");
			}
			draw_text(_rx2 + 16, _sky, _plabel);
			var _ptk = _is_racial ? ("pf_toggle_r" + string(_rfi)) : (_is_perk ? "pf_toggle_p" + string(_pfi) : "pf_toggle_f" + string(_ffi));
			var _tw2 = string_width(_plabel) + 20;
			variable_struct_set(btn, _ptk, [_rx2, _ry2-2, _rx2 + _tw2, _ry2 + 16]);
			_pfx += _tw2 + 8;
			if (_is_racial) _rfi++; else if (_is_perk) _pfi++; else _ffi++;
			// Wrap to next row if approaching the right edge
			if (_pfx > _skill_x + _skill_w - 40) {
				_pfx = _skill_x + 92;
				_sky += _lh;
			}
		}
		_sky += _lh;
	}

	// Header line
	draw_set_colour(c_muted); draw_text(_skill_x, _sky, "Skill / Specialty");
	ui_btn("scroll_up", _skill_x + _skill_w - 55, _sky, _skill_x + _skill_w - 4, _sky+_lh-2, "^", c_border, c_amazing);
	_sky += _lh;
	skill_list_start_y = _sky;

	// Build index map: filtered visible rows → hero.skills[] indices
	skill_index_map = [];
	for (var _i = 0; _i < array_length(hero.skills); _i++) {
		if (hero.skills[_i].ability == active_stat_group)
			array_push(skill_index_map, _i);
	}
	var _fsc = array_length(skill_index_map);
	scroll_offset = clamp(scroll_offset, 0, max(0, _fsc - max_visible_skills));
	var _fend = min(scroll_offset + max_visible_skills, _fsc);

	// Clear stale skill +/-/roll button rects
	for (var _clr = 0; _clr < _fsc + 20; _clr++) {
		variable_struct_remove(btn, "skp"+string(_clr));
		variable_struct_remove(btn, "skm"+string(_clr));
		variable_struct_remove(btn, "skroll"+string(_clr));
	}

	// ── FILTERED SKILL ROWS ──
	// Broad skills get 1 line: name + Roll button (no rank, no +/-)
	// Specialty skills get 2 lines: "Broad: Specialty" then indented "score r# -+ [Roll]"
	for (var _vi = scroll_offset; _vi < _fend; _vi++) {
		var _real_idx = skill_index_map[_vi];
		var _sk = hero.skills[_real_idx];
		var _is_spec = (_sk.specialty != "");
		var _sel = (_real_idx == selected_skill);

		if (_is_spec) {
			// Line 1: name "Broad: Specialty" indented
			if (_sel) { draw_set_colour(c_border); draw_rectangle(_skill_x, _sky-1, _skill_x + _skill_w - 4, _sky+_lh*2-2, false); }
			var _name_col = _sel ? c_highlight : (_sk.rank == 0 ? c_muted : c_text);
			draw_set_colour(_name_col);
			draw_text(_skill_x + 12, _sky, _sk.broad_skill + ": " + _sk.specialty);
			_sky += _lh;
			// Line 2: indented "score r# -+ [Roll]"
			draw_set_colour(_sel ? #ffffff : c_muted);
			draw_text(_skill_x + 28, _sky, string(_sk.score_ordinary) + "/" + string(_sk.score_good) + "/" + string(_sk.score_amazing));
			draw_set_colour(c_warning);
			draw_text(_skill_x + 110, _sky, "r" + string(_sk.rank));
			ui_btn("skm"+string(_vi),   _skill_x + 140, _sky, _skill_x + 158, _sky+_lh-3, "-", c_border, c_failure);
			ui_btn("skp"+string(_vi),   _skill_x + 162, _sky, _skill_x + 180, _sky+_lh-3, "+", c_border, c_good);
			ui_btn("skroll"+string(_vi),_skill_x + _skill_w - 60, _sky-2, _skill_x + _skill_w - 4, _sky+_lh-2, "Roll", c_border, c_highlight);
			var _cost = get_single_skill_cost_hero(hero, _sk);
			if (_cost > 0) { draw_set_colour(c_muted); draw_text(_skill_x + _skill_w - 100, _sky, string(_cost)+"p"); }
			_sky += _lh;
		} else {
			// Broad skill: 1 line, no rank, no +/-
			if (_sel) { draw_set_colour(c_border); draw_rectangle(_skill_x, _sky-1, _skill_x + _skill_w - 4, _sky+_lh-2, false); }
			draw_set_colour(_sel ? c_highlight : c_amazing);
			draw_text(_skill_x + 4, _sky, _sk.broad_skill);
			ui_btn("skroll"+string(_vi), _skill_x + _skill_w - 60, _sky-2, _skill_x + _skill_w - 4, _sky+_lh-2, "Roll", c_border, c_highlight);
			_sky += _lh;
		}
	}
	ui_btn("scroll_dn", _skill_x + _skill_w - 55, _sky, _skill_x + _skill_w - 4, _sky+_lh-2, "v", c_border, c_amazing);
	_sky += _lh + 4;

	// Collapsible untrained skills (for active stat group only)
	var _ut_label = untrained_expanded ? "v Untrained Check" : "> Untrained Check";
	btn.untrained_toggle = [_skill_x, _sky, _skill_x + 200, _sky+_lh];
	draw_set_colour(c_warning); draw_text(_skill_x, _sky, _ut_label);
	_sky += _lh;

	if (untrained_expanded) {
		var _sg_idx = array_get_index(global.ability_keys, active_stat_group);
		if (_sg_idx >= 0) {
			var _usc = get_ability_score_for_skill(hero, _ab_keys[_sg_idx]) div 2;
			var _ug = _usc div 2; var _ua = _usc div 4;
			draw_set_colour(c_muted); draw_text(_skill_x + 8, _sky, _ab_names[_sg_idx] + " check");
			draw_text(_skill_x + 122, _sky, string(_usc)+"/"+string(_ug)+"/"+string(_ua));
			draw_set_colour(c_failure); draw_text(_skill_x + 212, _sky, "+2 step");
			ui_btn("utfeat0", _skill_x + 280, _sky-2, _skill_x + 340, _sky+_lh-2, "Roll", c_border, c_highlight);
			_sky += _lh;
		}
	}

	// Return the lower edge so the panel knows how tall the content is.
	// In vertical-stats mode the stat column may extend below the skill column.
	var _stats_bottom = _stats_vertical ? (_ly + 6*24 + _lh*4 + 8) : _post_stats_y;
	return max(_sky, _stats_bottom);
}

/// @function draw_tab_equipment(_lx, _ly, _lw, _lh)
/// @description TAB 1: EQUIPMENT — interactive weapons/armor/gear management
/// Full-featured: verbose/compact display, PL filter, add panel toggle, inspect highlight,
/// custom weapon/gear creation, category grouping for weapons.
function draw_tab_equipment(_lx, _ly, _lw, _lh) {
	var _pl_names = ["Stone","Bronze","Medieval","Reason","Industrial","Information","Fusion","Gravity","Energy"];

	// ---- TOP BAR: Sub-tabs, Verbose toggle, Add toggle, PL filter ----
	ui_btn("eq_weapons_tab", _lx+8, _ly, _lx+100, _ly+22, "Weapons", equip_view=="weapons"?c_amazing:c_border, c_amazing);
	ui_btn("eq_armor_tab", _lx+108, _ly, _lx+188, _ly+22, "Armor", equip_view=="armor"?c_good:c_border, c_good);
	ui_btn("eq_gear_tab", _lx+196, _ly, _lx+266, _ly+22, "Gear", equip_view=="gear"?c_warning:c_border, c_warning);

	var _verb_label = equip_verbose ? "Verbose" : "Compact";
	ui_btn("eq_toggle_verbose", _lx+280, _ly, _lx+370, _ly+22, _verb_label, c_border, c_highlight);

	var _add_label = equip_adding ? "Close" : "Add Equipment";
	var _add_w = equip_adding ? 70 : 120;
	ui_btn("eq_toggle_add", _lx+384, _ly, _lx+384+_add_w, _ly+22, _add_label, equip_adding?c_failure:c_border, equip_adding?c_failure:c_good);

	// PL filter
	var _pl_x = _lx + 384 + _add_w + 20;
	draw_set_colour(c_muted); draw_text(_pl_x, _ly+3, "PL:");
	ui_btn("eq_pl_down", _pl_x+30, _ly, _pl_x+52, _ly+22, "<", c_border, c_highlight);
	draw_set_colour(c_text); draw_set_halign(fa_center);
	draw_text(_pl_x+90, _ly+3, string(campaign_pl) + " " + _pl_names[campaign_pl]);
	draw_set_halign(fa_left);
	ui_btn("eq_pl_up", _pl_x+128, _ly, _pl_x+150, _ly+22, ">", c_border, c_highlight);

	// Custom button (only when adding)
	if (equip_adding) {
		if (equip_view == "weapons") {
			ui_btn("eq_custom_weapon", _lx+_lw-110, _ly, _lx+_lw-8, _ly+22, "+ Custom", c_border, c_warning);
		} else if (equip_view == "gear") {
			ui_btn("eq_custom_gear", _lx+_lw-110, _ly, _lx+_lw-8, _ly+22, "+ Custom", c_border, c_warning);
		}
	}

	_ly += 28;

	// ================================================================
	// WEAPONS VIEW
	// ================================================================
	if (equip_view == "weapons") {
		if (!equip_adding) {
			// ---- YOUR WEAPONS (inventory) ----
			draw_set_colour(c_header); draw_text(_lx+8, _ly, "YOUR WEAPONS"); _ly += _lh;

			for (var _i = 0; _i < array_length(hero.weapons); _i++) {
				var _w = hero.weapons[_i];
				var _dt_names = ["LI", "HI", "En"]; var _dt = _dt_names[clamp(_w.damage_type, 0, 2)];
				var _is_inspected = (equip_inspect == _i && equip_inspect_type == "weapon");

				// Inspect highlight box
				draw_inspect_highlight(_lx+4, _ly-2, _lw-8, equip_verbose ? _lh*3 : _lh, _is_inspected);

				// Clickable name area for inspect
				var _name_x2 = equip_verbose ? _lx+_lw-60 : _lx+250;
				var _insp_key = "eq_winsp_"+string(_i);
				variable_struct_set(btn, _insp_key, [_lx+8, _ly-2, _name_x2, _ly+_lh-2]);

				if (equip_verbose) {
					// ---- Verbose: multi-line ----
					var _hov = mouse_in(_lx+8, _ly-2, _name_x2, _ly+_lh-2);
					draw_set_colour(_is_inspected ? c_highlight : (_hov ? c_highlight : c_text));
					draw_text(_lx+8, _ly, _w.name);
					// Remove button (skip Unarmed)
					if (_w.name != "Unarmed") {
						ui_btn("eq_wrm_"+string(_i), _lx+_lw-50, _ly-2, _lx+_lw-8, _ly+_lh-2, "X", c_border, c_failure);
					}
					_ly += _lh;
					draw_set_colour(c_muted);
					draw_text(_lx+24, _ly, "Skill: " + (_w[$ "skill_keyword"] ?? ""));
					draw_text(_lx+180, _ly, "| Type: " + _dt);
					draw_text(_lx+310, _ly, "| Range: " + _w.range_str);
					draw_text(_lx+520, _ly, "| PL " + string(_w[$ "pl"] ?? "?"));
					_ly += _lh;
					draw_set_colour(c_text); draw_text(_lx+24, _ly, "Ordinary: " + _w.dmg_ordinary);
					draw_set_colour(c_good); draw_text(_lx+200, _ly, "| Good: " + _w.dmg_good);
					draw_set_colour(c_amazing); draw_text(_lx+380, _ly, "| Amazing: " + _w.dmg_amazing);
					_ly += _lh + 4;
				} else {
					// ---- Compact: one line ----
					var _hov = mouse_in(_lx+8, _ly-2, _name_x2, _ly+_lh-2);
					draw_set_colour(_is_inspected ? c_highlight : (_hov ? c_highlight : c_text));
					draw_text(_lx+8, _ly, _w.name);
					draw_set_colour(c_muted);
					draw_text(_lx+260, _ly, _w.dmg_ordinary + "/" + _w.dmg_good + "/" + _w.dmg_amazing);
					draw_text(_lx+500, _ly, _w.range_str);
					draw_text(_lx+620, _ly, _dt);
					// Remove button (skip Unarmed)
					if (_w.name != "Unarmed") {
						ui_btn("eq_wrm_"+string(_i), _lx+_lw-50, _ly-2, _lx+_lw-8, _ly+_lh-2, "X", c_border, c_failure);
					}
					_ly += _lh;
				}
			}
		} else {
			// ---- ADD PANEL: Available weapons filtered by PL ----
			draw_set_colour(c_header);
			draw_text(_lx+8, _ly, "AVAILABLE WEAPONS (PL " + string(campaign_pl) + " — " + _pl_names[campaign_pl] + " Age)");
			draw_set_colour(c_muted); draw_text(_lx+520, _ly, "(click to expand, then Add)");
			_ly += _lh;

			var _categories = ["ranged", "melee", "heavy"];
			var _cat_labels = ["RANGED", "MELEE", "HEAVY"];
			var _gi = 0;

			for (var _cat = 0; _cat < 3; _cat++) {
				// Check if any items exist in this category at or below campaign_pl
				var _cat_has_items = false;
				for (var _di = 0; _di < array_length(global.equipment_weapons); _di++) {
					var _e2 = global.equipment_weapons[_di];
					if ((_e2[$ "category"] ?? "") == _categories[_cat] && (_e2[$ "pl"] ?? 0) <= campaign_pl) {
						_cat_has_items = true; break;
					}
				}
				if (!_cat_has_items) {
					// Still increment _gi for items in this category (so indices stay consistent with handler)
					for (var _di = 0; _di < array_length(global.equipment_weapons); _di++) {
						if ((global.equipment_weapons[_di][$ "category"] ?? "") == _categories[_cat]) _gi++;
					}
					continue;
				}

				draw_set_colour(c_warning); draw_text(_lx+8, _ly, _cat_labels[_cat]); _ly += _lh;

				for (var _di = 0; _di < array_length(global.equipment_weapons); _di++) {
					var _entry = global.equipment_weapons[_di];
					if ((_entry[$ "category"] ?? "") != _categories[_cat]) continue;

					var _entry_pl = _entry[$ "pl"] ?? 0;
					// Filter by campaign PL
					if (_entry_pl != campaign_pl) { _gi++; continue; }

					var _owned = hero_has_weapon(hero, _entry.name);
					_ly = draw_expandable_catalog_item(_lx, _ly, _lw, _lh, _entry.name, _gi, _owned, equip_expanded, "eq_wname_", "", " [OWNED]");
					draw_set_colour(c_muted); draw_text(_lx+400, _ly-_lh, "PL " + string(_entry_pl));

					if (equip_expanded == _gi) {
						draw_set_colour(c_muted);
						draw_text(_lx+32, _ly, "Skill: " + (_entry[$ "skill_keyword"] ?? ""));
						draw_text(_lx+200, _ly, "| Type: " + (_entry[$ "damage_type"] ?? "LI"));
						draw_text(_lx+380, _ly, "| Range: " + (_entry[$ "range"] ?? ""));
						_ly += _lh;
						draw_set_colour(c_text); draw_text(_lx+32, _ly, "Ordinary: " + _entry.dmg_ordinary);
						draw_set_colour(c_good); draw_text(_lx+200, _ly, "Good: " + _entry.dmg_good);
						draw_set_colour(c_amazing); draw_text(_lx+380, _ly, "Amazing: " + _entry.dmg_amazing);
						if (!_owned) {
							ui_btn("eq_wadd_"+string(_gi), _lx+_lw-80, _ly-2, _lx+_lw-8, _ly+_lh-2, "Add", c_border, c_good);
						}
						_ly += _lh + 4;
					}
					_gi++;
				}
				_ly += 4;
			}
		}
	}

	// ================================================================
	// ARMOR VIEW
	// ================================================================
	if (equip_view == "armor") {
		if (!equip_adding) {
			// ---- YOUR ARMOR (inventory) ----
			draw_set_colour(c_header); draw_text(_lx+8, _ly, "YOUR ARMOR"); _ly += _lh;

			var _ar = hero.armor;
			var _is_inspected = (equip_inspect == 0 && equip_inspect_type == "armor");

			// Inspect highlight
			draw_inspect_highlight(_lx+4, _ly-2, _lw-8, _lh, _is_inspected);

			var _ainsp_key = "eq_ainsp_0";
			variable_struct_set(btn, _ainsp_key, [_lx+8, _ly-2, _lx+500, _ly+_lh-2]);
			var _ahov = mouse_in(_lx+8, _ly-2, _lx+500, _ly+_lh-2);

			draw_set_colour(_is_inspected ? c_highlight : (_ahov ? c_highlight : c_text));
			draw_text(_lx+8, _ly, _ar.name);
			draw_set_colour(c_muted);
			draw_text(_lx+280, _ly, "LI: " + _ar.li);
			draw_text(_lx+400, _ly, "HI: " + _ar.hi);
			draw_text(_lx+520, _ly, "En: " + _ar.en);
			_ly += _lh;
		} else {
			// ---- ADD PANEL: Available armor filtered by PL ----
			draw_set_colour(c_header);
			draw_text(_lx+8, _ly, "AVAILABLE ARMOR (PL " + string(campaign_pl) + " — " + _pl_names[campaign_pl] + " Age)");
			_ly += _lh;

			// Column headers
			draw_set_colour(c_muted);
			draw_text(_lx+8, _ly, "Name"); draw_text(_lx+280, _ly, "LI"); draw_text(_lx+380, _ly, "HI");
			draw_text(_lx+480, _ly, "En"); draw_text(_lx+580, _ly, "PL");
			_ly += _lh;

			for (var _i = 0; _i < array_length(global.equipment_armor); _i++) {
				var _ar = global.equipment_armor[_i];
				var _ar_pl = _ar[$ "pl"] ?? 0;
				if (_ar_pl != campaign_pl) continue;

				var _is_equipped = (hero.armor.name == _ar.name);

				// Inspect highlight
				var _ainsp = (equip_inspect == _i && equip_inspect_type == "armor");
				draw_inspect_highlight(_lx+4, _ly-2, _lw-8, _lh, _ainsp);

				var _ainsp_key = "eq_ainsp_"+string(_i);
				variable_struct_set(btn, _ainsp_key, [_lx+8, _ly-2, _lx+270, _ly+_lh-2]);
				var _hov = mouse_in(_lx+8, _ly-2, _lx+270, _ly+_lh-2);

				draw_set_colour(_is_equipped ? c_good : (_ainsp ? c_highlight : (_hov ? c_highlight : c_text)));
				draw_text(_lx+8, _ly, _ar.name + (_is_equipped ? " [EQUIPPED]" : ""));
				draw_set_colour(c_muted);
				draw_text(_lx+280, _ly, _ar.li); draw_text(_lx+380, _ly, _ar.hi);
				draw_text(_lx+480, _ly, _ar.en); draw_text(_lx+580, _ly, string(_ar_pl));
				if (!_is_equipped) {
					ui_btn("eq_aset_"+string(_i), _lx+_lw-80, _ly-2, _lx+_lw-8, _ly+_lh-2, "Equip", c_border, c_good);
				}
				_ly += _lh;
			}
		}
	}

	// ================================================================
	// GEAR VIEW
	// ================================================================
	if (equip_view == "gear") {
		if (!equip_adding) {
			// ---- YOUR GEAR (inventory) ----
			draw_set_colour(c_header); draw_text(_lx+8, _ly, "YOUR GEAR"); _ly += _lh;

			for (var _i = 0; _i < array_length(hero.gear); _i++) {
				_ly = draw_inspectable_row(_lx, _ly, _lw, _lh, "- " + hero.gear[_i], _i, "gear", "eq_ginsp_", ["eq_grm_"+string(_i), "X", c_failure]);
			}

			if (array_length(hero.gear) == 0) {
				draw_set_colour(c_muted); draw_text(_lx+16, _ly, "(no gear — use Add Equipment to browse)");
				_ly += _lh;
			}
		} else {
			// ---- ADD PANEL: Available gear filtered by PL ----
			draw_set_colour(c_header);
			draw_text(_lx+8, _ly, "AVAILABLE GEAR (PL " + string(campaign_pl) + " — " + _pl_names[campaign_pl] + " Age)");
			draw_set_colour(c_muted); draw_text(_lx+520, _ly, "(click Add to equip)");
			_ly += _lh;

			// Column headers
			draw_set_colour(c_muted);
			draw_text(_lx+8, _ly, "Name"); draw_text(_lx+400, _ly, "Category"); draw_text(_lx+550, _ly, "PL");
			_ly += _lh;

			for (var _i = 0; _i < array_length(global.equipment_gear); _i++) {
				var _ge = global.equipment_gear[_i];
				var _ge_pl = _ge[$ "pl"] ?? 0;
				if (_ge_pl != campaign_pl) continue;

				// Check if hero already has this gear
				var _has_gear = false;
				for (var _gi2 = 0; _gi2 < array_length(hero.gear); _gi2++) {
					if (hero.gear[_gi2] == _ge.name) { _has_gear = true; break; }
				}

				var _ginsp = (equip_inspect == _i && equip_inspect_type == "gear");
				draw_inspect_highlight(_lx+4, _ly-2, _lw-8, _lh, _ginsp);

				var _ginsp_key = "eq_ginsp_"+string(_i);
				variable_struct_set(btn, _ginsp_key, [_lx+8, _ly-2, _lx+390, _ly+_lh-2]);
				var _hov = mouse_in(_lx+8, _ly-2, _lx+390, _ly+_lh-2);

				draw_set_colour(_has_gear ? c_good : (_ginsp ? c_highlight : (_hov ? c_highlight : c_text)));
				draw_text(_lx+8, _ly, _ge.name + (_has_gear ? " [OWNED]" : ""));
				draw_set_colour(c_muted);
				draw_text(_lx+400, _ly, _ge[$ "category"] ?? "");
				draw_text(_lx+550, _ly, string(_ge_pl));
				ui_btn("eq_gadd_"+string(_i), _lx+_lw-80, _ly-2, _lx+_lw-8, _ly+_lh-2, "Add", c_border, c_good);
				_ly += _lh;
			}
		}
	}

	return _ly;
}

/// @function draw_tab_combat(_lx, _ly, _lw, _lh)
/// @description TAB 2: COMBAT
function draw_tab_combat(_lx, _ly, _lw, _lh) {
	// ---- QUICK ROLLS (moved from sidebar) — auto-fit to remaining width to avoid header overlap ----
	draw_set_colour(c_header); draw_text(_lx+8,_ly,"QUICK ROLLS");
	var _qr_x = _lx + 8 + string_width("QUICK ROLLS") + 12;
	var _qr_avail = (_lx + _lw - 4) - _qr_x;
	var _qw = floor((_qr_avail - 12) / 4); // 4 buttons + 3 gaps of 4px
	ui_btn("roll_awareness",   _qr_x,              _ly-2, _qr_x+_qw,        _ly+_lh-2, "Senses",       c_border, c_amazing);
	ui_btn("roll_mental",      _qr_x+_qw+4,        _ly-2, _qr_x+_qw*2+4,    _ly+_lh-2, "Mental Res.",  c_border, c_warning);
	ui_btn("roll_physical",    _qr_x+_qw*2+8,      _ly-2, _qr_x+_qw*3+8,    _ly+_lh-2, "Physical Res.",c_border, c_warning);
	ui_btn("roll_initiative",  _qr_x+_qw*3+12,     _ly-2, _lx+_lw-4,        _ly+_lh-2, "Initiative",   c_border, c_good);
	_ly+=_lh+4;

	// ---- ACTION CHECK + DURABILITY HEADER ----
	// Layout walks left-to-right with dynamic widths to avoid collisions on narrow panels.
	var _hx = _lx + 8;
	draw_set_colour(c_header); draw_text(_hx, _ly, "AC:"); _hx += string_width("AC:") + 6;
	var _ac_pieces = [
		{ col: c_warning, txt: "M:" + string(hero.action_check.marginal) + "+" },
		{ col: c_text,    txt: "O:" + string(hero.action_check.ordinary) },
		{ col: c_good,    txt: "G:" + string(hero.action_check.good) },
		{ col: c_amazing, txt: "A:" + string(hero.action_check.amazing) }
	];
	for (var _aci = 0; _aci < 4; _aci++) {
		draw_set_colour(_ac_pieces[_aci].col); draw_text(_hx, _ly, _ac_pieces[_aci].txt);
		_hx += string_width(_ac_pieces[_aci].txt) + 10;
	}
	_hx += 8;
	var _dur_pieces = [
		{ col: c_warning,   txt: "Stun: "   + string(hero.stun.current)   + "/" + string(hero.stun.max) },
		{ col: c_highlight, txt: "Wound: "  + string(hero.wound.current)  + "/" + string(hero.wound.max) },
		{ col: c_failure,   txt: "Mortal: " + string(hero.mortal.current) + "/" + string(hero.mortal.max) }
	];
	for (var _dpi = 0; _dpi < 3; _dpi++) {
		draw_set_colour(_dur_pieces[_dpi].col); draw_text(_hx, _ly, _dur_pieces[_dpi].txt);
		_hx += string_width(_dur_pieces[_dpi].txt) + 10;
	}
	var _wp_combat = get_wound_penalty(hero);
	if (_wp_combat > 0) { draw_set_colour(c_failure); draw_text(_hx, _ly, "+"+string(_wp_combat)+" wound"); }
	_ly += _lh + 4;

	// ---- CLICKABLE DURABILITY BUBBLES ----
	// One row per category. Click a circle to take damage / heal back. Every
	// click logs to the roll log with natural-language messaging via
	// log_health_change(). This is the ONLY place in the app that mutates
	// stun/wound/mortal — every other tab reads the same hero.stun/wound/mortal
	// values but displays them numerically (read-only). Reset X buttons
	// restore each track to full and also log the heal.
	// When the GM is editing a player character (gm_mode + gm_state == "edit"),
	// changes are tagged as GM-assigned in the log.
	var _dur_x = _lx + 8;
	var _reset_x = _lx + 112;
	var _is_gm_edit = (gm_mode && gm_state == "edit");
	var _gm_target = _is_gm_edit ? hero.name : "";

	// Stun row
	var _rx_hover = mouse_in(_reset_x-9, _ly, _reset_x+9, _ly+18);
	draw_set_colour(_rx_hover ? #ffffff : c_muted);
	draw_circle(_reset_x, _ly+9, 8, true);
	draw_set_halign(fa_center); draw_set_valign(fa_middle);
	draw_text(_reset_x, _ly+9, "x");
	draw_set_halign(fa_left); draw_set_valign(fa_top);
	btn.reset_stun = [_reset_x-9, _ly, _reset_x+9, _ly+18];
	var _stun_old = hero.stun.current;
	var _stun_new = draw_durability_circles(_dur_x, _ly, "Stun", hero.stun.current, hero.stun.max, c_warning, c_text);
	if (_stun_new >= 0 && _stun_new != _stun_old) {
		hero.stun.current = clamp(_stun_new, 0, hero.stun.max);
		log_health_change("Stun", _stun_old, hero.stun.current, _is_gm_edit, _gm_target);
	}
	_ly += _lh + 4;

	// Wound row
	_rx_hover = mouse_in(_reset_x-9, _ly, _reset_x+9, _ly+18);
	draw_set_colour(_rx_hover ? #ffffff : c_muted);
	draw_circle(_reset_x, _ly+9, 8, true);
	draw_set_halign(fa_center); draw_set_valign(fa_middle);
	draw_text(_reset_x, _ly+9, "x");
	draw_set_halign(fa_left); draw_set_valign(fa_top);
	btn.reset_wound = [_reset_x-9, _ly, _reset_x+9, _ly+18];
	var _wound_old = hero.wound.current;
	var _wound_new = draw_durability_circles(_dur_x, _ly, "Wound", hero.wound.current, hero.wound.max, c_highlight, c_text);
	if (_wound_new >= 0 && _wound_new != _wound_old) {
		hero.wound.current = clamp(_wound_new, 0, hero.wound.max);
		log_health_change("Wound", _wound_old, hero.wound.current, _is_gm_edit, _gm_target);
	}
	_ly += _lh + 4;

	// Mortal row
	_rx_hover = mouse_in(_reset_x-9, _ly, _reset_x+9, _ly+18);
	draw_set_colour(_rx_hover ? #ffffff : c_muted);
	draw_circle(_reset_x, _ly+9, 8, true);
	draw_set_halign(fa_center); draw_set_valign(fa_middle);
	draw_text(_reset_x, _ly+9, "x");
	draw_set_halign(fa_left); draw_set_valign(fa_top);
	btn.reset_mortal = [_reset_x-9, _ly, _reset_x+9, _ly+18];
	var _mortal_old = hero.mortal.current;
	var _mortal_new = draw_durability_circles(_dur_x, _ly, "Mortal", hero.mortal.current, hero.mortal.max, c_failure, c_text);
	if (_mortal_new >= 0 && _mortal_new != _mortal_old) {
		hero.mortal.current = clamp(_mortal_new, 0, hero.mortal.max);
		log_health_change("Mortal", _mortal_old, hero.mortal.current, _is_gm_edit, _gm_target);
	}
	_ly += _lh + 6;

	// ---- ACTION PHASE TRACKER ----
	draw_set_colour(c_header); draw_text(_lx+8,_ly,"ACTION PHASES");
	// Roll Initiative button
	ui_btn("roll_init_combat",_lx+160,_ly-2,_lx+300,_ly+_lh-2,"Roll Initiative",c_border,c_good);
	// Reset round button
	ui_btn("reset_round",_lx+310,_ly-2,_lx+410,_ly+_lh-2,"New Round",c_border,c_warning);

	// Show actions remaining
	draw_set_colour(c_muted);
	draw_text(_lx+430,_ly,"Actions: "+string(actions_remaining)+"/"+string(actions_total));
	_ly+=_lh+4;

	// Phase boxes: Amazing, Good, Ordinary, Marginal
	var _phase_names = ["Amazing","Good","Ordinary","Marginal"];
	var _phase_colors = [c_amazing, c_good, c_text, c_warning];
	var _phase_w = 200;
	var _phase_h = 40;
	var _phase_gap = 8;
	var _phase_start_x = _lx + 8;

	for (var _p = 0; _p < 4; _p++) {
		var _px2 = _phase_start_x + _p * (_phase_w + _phase_gap);
		var _py2 = _ly;

		// Phase box background
		var _is_active = (initiative_phase >= 0 && _p >= initiative_phase); // can act in this phase and later
		var _is_start = (_p == initiative_phase);

		if (_is_active) {
			draw_set_colour(merge_colour(c_panel, _phase_colors[_p], 0.3));
		} else {
			draw_set_colour(c_panel);
		}
		draw_rectangle(_px2, _py2, _px2+_phase_w, _py2+_phase_h, false);

		// Border - highlight starting phase
		draw_set_colour(_is_start ? _phase_colors[_p] : c_border);
		draw_rectangle(_px2, _py2, _px2+_phase_w, _py2+_phase_h, true);

		// Phase name
		draw_set_colour(_is_active ? _phase_colors[_p] : c_muted);
		draw_set_halign(fa_center);
		draw_text(_px2+_phase_w/2, _py2+2, _phase_names[_p]);

		// Action count placed in this phase
		var _placed = actions_placed[_p];
		if (_placed > 0) {
			draw_set_colour(_phase_colors[_p]);
			draw_text(_px2+_phase_w/2, _py2+18, string(_placed) + " action" + (_placed>1?"s":""));
		} else if (_is_active && actions_remaining > 0) {
			draw_set_colour(merge_colour(_phase_colors[_p], c_muted, 0.5));
			draw_text(_px2+_phase_w/2, _py2+18, "click to act");
		}
		draw_set_halign(fa_left);

		// Click target
		var _apk = "phase"+string(_p);
		variable_struct_set(btn, _apk, [_px2, _py2, _px2+_phase_w, _py2+_phase_h]);
	}

	_ly += _phase_h + 8;

	// Options row
	draw_set_colour(c_muted); draw_text(_lx+8,_ly,"Options:");
	draw_checkbox_inline(_lx+80, _ly, apply_wound_penalty, "Wound penalty", "toggle_wound_pen");
	draw_checkbox_inline(_lx+230, _ly, cant_fail_mode, "Can't-fail (marginal)", "toggle_cant_fail");
	draw_set_colour(c_muted); draw_text(_lx+500,_ly,"Range:");
	var _range_names=["Short","Medium","Long"];
	for (var _r=0;_r<3;_r++) {
		var _rx=_lx+560+_r*80;
		var _rkey="range"+string(_r);
		ui_btn(_rkey,_rx,_ly-2,_rx+60,_ly+_lh-2,_range_names[_r],(combat_range==_r)?c_good:c_border,c_highlight);
	}
	_ly+=_lh+6;

	var _base_pen = (apply_wound_penalty ? get_wound_penalty(hero) : 0) + clamp(combat_range, 0, 2);

	// Column positions for wide layout
	var _c1=_lx+8;    // Weapon (clickable = roll skill)
	var _c2=_lx+220;  // Skill
	var _c3=_lx+370;  // Score
	var _c4=_lx+470;  // Training
	var _c5=_lx+570;  // Sit.Die
	var _c6=_lx+660;  // Damage (clickable die codes)
	var _c7=_lx+_lw-130; // Dmg button
	var _c8=_lx+_lw-65;  // Info button

	// WEAPONS with proper skill matching
	draw_set_colour(c_header); draw_text(_c1,_ly,"WEAPON ATTACKS"); _ly+=_lh;
	draw_set_colour(c_muted);
	draw_text(_c1,_ly,"Weapon (click=roll)"); draw_text(_c2,_ly,"Skill"); draw_text(_c3,_ly,"Score");
	draw_text(_c4,_ly,"Training"); draw_text(_c5,_ly,"Sit.Die"); draw_text(_c6,_ly,"Damage"); _ly+=_lh;

	var _combat_idx = 0;
	for (var _w=0; _w<array_length(hero.weapons); _w++) {
		var _wep = hero.weapons[_w];
		var _best = find_best_skill_for_weapon(hero, _wep);
		var _pen = _base_pen + _best.penalty;
		var _sit = clamp(SIT_STEP_BASE+_pen, SIT_STEP_MIN, SIT_STEP_MAX);

		// Weapon name — clickable to roll attack
		var _wnk = "watk"+string(_w);
		variable_struct_set(btn, _wnk, [_c1, _ly-2, _c2-4, _ly+_lh-2]);
		var _wn_hov = mouse_in(_c1, _ly-2, _c2-4, _ly+_lh-2);
		draw_set_colour(_wn_hov ? c_highlight : c_text); draw_text(_c1,_ly,_wep.name);

		draw_set_colour(c_amazing); draw_text(_c2,_ly,_best.skill_name);
		draw_set_colour(c_muted);
		draw_text(_c3,_ly,string(_best.score_ord)+"/"+string(_best.score_good)+"/"+string(_best.score_amz));
		draw_set_colour(_best.penalty>0?c_warning:c_text); draw_text(_c4,_ly,_best.use_type);
		draw_set_colour(_pen>0?c_failure:c_text); draw_text(_c5,_ly,situation_step_name(_sit));

		// Damage display — CONDITIONAL.
		// Default: dash placeholder. After a successful roll for THIS weapon, show
		// only the damage at the achieved degree (Ordinary/Good/Amazing).
		var _is_last_hit = (last_combat_weapon != undefined && last_combat_weapon == _wep && last_combat_degree >= 1);
		if (_is_last_hit) {
			var _hit_str = "";
			var _hit_col = c_text;
			switch (last_combat_degree) {
				case 1: _hit_str = _wep.dmg_ordinary; _hit_col = c_text; break;
				case 2: _hit_str = _wep.dmg_good;     _hit_col = c_good; break;
				case 3: _hit_str = _wep.dmg_amazing;  _hit_col = c_amazing; break;
			}
			draw_set_colour(_hit_col);
			draw_text(_c6, _ly, _hit_str);
			// Roll-damage button for the achieved tier
			var _dmgk2 = "wdmgall"+string(_w);
			ui_btn(_dmgk2, _c7, _ly-2, _c7+55, _ly+_lh-2, "Roll Dmg", c_border, c_failure);
		} else {
			draw_set_colour(c_muted); draw_text(_c6, _ly, "—");
		}

		// Info button
		var _infk = "winfo"+string(_w);
		ui_btn(_infk, _c8, _ly-2, _c8+55, _ly+_lh-2, "Info", c_border, c_amazing);

		_combat_idx++; _ly+=_lh;
	}

	// Post-success damage prompt
	if (last_combat_weapon != undefined && last_combat_degree >= 1) {
		var _dmg_tier = "";
		switch (last_combat_degree) {
			case 1: _dmg_tier = last_combat_weapon.dmg_ordinary; break;
			case 2: _dmg_tier = last_combat_weapon.dmg_good; break;
			case 3: _dmg_tier = last_combat_weapon.dmg_amazing; break;
		}
		var _deg_names = ["","Ordinary","Good","Amazing"];
		draw_set_colour(c_good);
		draw_text(_c1, _ly, "Hit! " + _deg_names[last_combat_degree] + " → " + _dmg_tier);
		ui_btn("roll_hit_dmg", _c6, _ly-2, _c6+120, _ly+_lh-2, "Roll Damage", c_border, c_failure);
		_ly += _lh;
	}

	_ly+=8;

	// UNARMED (always available)
	draw_set_colour(c_header); draw_text(_c1,_ly,"UNARMED & MELEE"); _ly+=_lh;
	var _punch_best = find_best_skill_for_weapon(hero, { name: "Punch", damage_type: DAMAGE_TYPE.LI });
	var _unarmed_cols = [_c1, _c2, _c3, _c4, _c5, _c7];

	var _punch_pen = _base_pen + _punch_best.penalty;
	var _punch_train_col = _punch_best.penalty > 0 ? c_warning : c_text;
	_ly = draw_combat_skill_row(_unarmed_cols, _ly, _lh, "Punch", _punch_best.skill_name, _punch_best.score_ord, _punch_best.score_good, _punch_best.score_amz, _punch_best.use_type, _punch_train_col, _punch_pen, "combat"+string(_combat_idx), "Roll");
	draw_set_colour(c_muted); draw_text(_c6, _ly-_lh, "d4s / d4+1s / d4+2s");
	_combat_idx++;

	_ly = draw_combat_skill_row(_unarmed_cols, _ly, _lh, "Kick", _punch_best.skill_name, _punch_best.score_ord, _punch_best.score_good, _punch_best.score_amz, _punch_best.use_type, _punch_train_col, _punch_pen, "combat"+string(_combat_idx), "Roll");
	draw_set_colour(c_muted); draw_text(_c6, _ly-_lh, "d4+1s / d4+2s / d4+3s");
	_combat_idx++;
	_ly+=8;

	// DEFENSIVE SKILLS
	draw_set_colour(c_header); draw_text(_c1,_ly,"DEFENSIVE"); _ly+=_lh;
	var _def_skills = [["Acrobatics","Dodge","dex"],["Unarmed Attack","Power martial arts","str"]];
	var _def_cols = [_c1, _c2, _c3, _c4, _c5, _c7];
	for (var _d=0;_d<array_length(_def_skills);_d++) {
		var _db=_def_skills[_d][0]; var _ds=_def_skills[_d][1]; var _dab=_def_skills[_d][2];
		var _didx=find_skill(hero,_db,_ds);
		var _sc_o, _sc_g, _sc_a, _dpen, _dtype;
		if (_didx>=0) {
			var _dsk=hero.skills[_didx]; _sc_o=_dsk.score_ordinary; _sc_g=_dsk.score_good; _sc_a=_dsk.score_amazing; _dpen=0; _dtype="Trained";
		} else {
			var _bidx=find_skill(hero,_db,"");
			if (_bidx>=0) { var _dsk=hero.skills[_bidx]; _sc_o=_dsk.score_ordinary; _sc_g=_dsk.score_good; _sc_a=_dsk.score_amazing; _dpen=1; _dtype="Broad (+1)"; }
			else { _sc_o=get_ability_score_for_skill(hero,_dab) div 2; _sc_g=_sc_o div 2; _sc_a=_sc_o div 4; _dpen=2; _dtype="Untrained (+2)"; }
		}
		var _d_total_pen = _base_pen + _dpen;
		_ly = draw_combat_skill_row(_def_cols, _ly, _lh, _ds, _db, _sc_o, _sc_g, _sc_a, _dtype, _dpen>0?c_warning:c_text, _d_total_pen, "combat"+string(_combat_idx), "Roll");
		_combat_idx++;
	}
	_ly += 8;

	// FEAT CHECKS — PHB: full ability score, +d4 base
	draw_set_colour(c_header); draw_text(_c1,_ly,"FEAT CHECKS (Full Ability +d4)"); _ly+=_lh;
	var _feat_names = global.ability_names;
	var _feat_keys = global.ability_keys;
	var _feat_cols = [_c1, "", _c3, _c4, _c5, _c7];
	for (var _s = 0; _s < 6; _s++) {
		var _fsc = get_ability_score_for_skill(hero, _feat_keys[_s]);
		_ly = draw_combat_skill_row(_feat_cols, _ly, _lh, _feat_names[_s] + " feat", "", _fsc, _fsc div 2, _fsc div 4, "Feat", c_highlight, _base_pen + 1, "feat"+string(_s), "Roll");
	}

	return _ly;
}

/// @function draw_tab_psionics(_lx, _ly, _lw, _lh)
/// @description TAB 3: PSIONICS
function draw_tab_psionics(_lx, _ly, _lw, _lh) {
	// Psionic FX skill categories
	var _fx_broads = ["Telepathy", "Telekinesis", "ESP", "Biokinesis"];
	var _fx_abilities = ["wil", "wil", "wil", "con"];

	var _base_pen = (apply_wound_penalty ? get_wound_penalty(hero) : 0);

	// Check if hero has any psionic skills
	var _has_any_fx = false;
	for (var _f=0; _f<array_length(_fx_broads); _f++) {
		if (find_skill(hero, _fx_broads[_f], "") >= 0) { _has_any_fx = true; break; }
	}

	if (!_has_any_fx) {
		draw_set_colour(c_muted);
		draw_text_ext(_lx+8, _ly, "This character has no psionic (FX) skills. Psionics require the Mindwalker profession or purchasing FX broad skills (Telepathy, Telekinesis, ESP, Biokinesis) as cross-class.", -1, _lw-16);
		_ly += _lh * 3;
		draw_set_colour(c_warning);
		draw_text(_lx+8, _ly, "Add FX skills via the Skill Browser on the Character tab.");
	} else {
		// Options (same as combat)
		_ly = draw_combat_options_row(_lx, _ly, _lh, "psi_wound_pen", "psi_cant_fail");

		// Column positions
		var _pc1=_lx+8;    // Discipline / Skill
		var _pc2=_lx+280;  // Score
		var _pc3=_lx+420;  // Training
		var _pc4=_lx+560;  // Sit.Die
		var _pc5=_lx+680;  // Description
		var _pc6=_lx+_lw-70; // Roll

		var _psi_idx = 0;

		for (var _f=0; _f<array_length(_fx_broads); _f++) {
			var _fb = _fx_broads[_f];
			var _fab = _fx_abilities[_f];

			if (find_skill(hero, _fb, "") < 0) continue;

			// Discipline header
			draw_set_colour(c_header);
			draw_text(_pc1, _ly, _fb + " (" + string_upper(_fab) + ")");
			_ly += _lh;

			// Column headers
			draw_set_colour(c_muted);
			draw_text(_pc1, _ly, "Power"); draw_text(_pc2, _ly, "Score O/G/A");
			draw_text(_pc3, _ly, "Training"); draw_text(_pc4, _ly, "Sit.Die");
			_ly += _lh;

			// Broad skill entry
			var _bidx = find_skill(hero, _fb, "");
			if (_bidx >= 0) {
				var _bsk = hero.skills[_bidx];
				var _bpen = _base_pen + 1; // broad = +1
				var _bsit = clamp(SIT_STEP_BASE+_bpen, SIT_STEP_MIN, SIT_STEP_MAX);

				draw_set_colour(c_amazing); draw_text(_pc1, _ly, _fb + " (broad)");
				draw_set_colour(c_muted);
				draw_text(_pc2, _ly, string(_bsk.score_ordinary)+"/"+string(_bsk.score_good)+"/"+string(_bsk.score_amazing));
				draw_set_colour(c_warning); draw_text(_pc3, _ly, "Broad (+1)");
				draw_set_colour(_bpen>0?c_failure:c_text); draw_text(_pc4, _ly, situation_step_name(_bsit));

				var _pbk = "psi"+string(_psi_idx);
				ui_btn(_pbk, _pc6, _ly-2, _pc6+60, _ly+_lh-2, "Roll", c_border, c_highlight);
				_psi_idx++; _ly += _lh;
			}

			// Specialties
			for (var _i=0; _i<array_length(hero.skills); _i++) {
				var _sk = hero.skills[_i];
				if (_sk.broad_skill != _fb || _sk.specialty == "") continue;

				var _spen = _base_pen + 0; // trained specialty
				var _ssit = clamp(SIT_STEP_BASE+_spen, SIT_STEP_MIN, SIT_STEP_MAX);

				draw_set_colour(c_text); draw_text(_pc1, _ly, "  " + _sk.specialty);
				draw_set_colour(c_muted);
				draw_text(_pc2, _ly, string(_sk.score_ordinary)+"/"+string(_sk.score_good)+"/"+string(_sk.score_amazing));
				draw_set_colour(c_good); draw_text(_pc3, _ly, "Trained");
				draw_set_colour(_spen>0?c_failure:c_text); draw_text(_pc4, _ly, situation_step_name(_ssit));

				// Psionic power descriptions
				var _desc = "";
				switch (_sk.specialty) {
					case "Contact": _desc = "Establish mental link"; break;
					case "Mind blast": _desc = "Psionic attack (stun)"; break;
					case "Mind reading": _desc = "Read surface thoughts"; break;
					case "Illusion": _desc = "Create false sensory input"; break;
					case "Mind shield": _desc = "Resist psionic attacks"; break;
					case "Suggest": _desc = "Implant suggestion"; break;
					case "Levitate": _desc = "Lift objects/self"; break;
					case "Telekinetic strike": _desc = "Kinetic force attack"; break;
					case "Kinetic shield": _desc = "Deflect physical attacks"; break;
					case "Empathy": _desc = "Sense emotions"; break;
					case "Clairaudience": _desc = "Remote hearing"; break;
					case "Clairvoyance": _desc = "Remote seeing"; break;
					case "Precognition": _desc = "Glimpse the future"; break;
					case "Psychometry": _desc = "Read object history"; break;
					case "Bioshift": _desc = "Alter own biology"; break;
					case "Body armor": _desc = "Toughen skin vs damage"; break;
					case "Heal": _desc = "Mend wounds psionically"; break;
					case "Harm": _desc = "Inflict internal damage"; break;
				}
				if (_desc != "") { draw_set_colour(c_muted); draw_text(_pc5, _ly, _desc); }

				var _pbk = "psi"+string(_psi_idx);
				ui_btn(_pbk, _pc6, _ly-2, _pc6+60, _ly+_lh-2, "Roll", c_border, c_highlight);
				_psi_idx++; _ly += _lh;
			}
			_ly += 6; // gap between disciplines
		}
	}

	return _ly;
}

/// @function draw_tab_perks_flaws(_lx, _ly, _lw, _lh)
/// @description TAB 4: PERKS & FLAWS — three-view (Perks / Flaws / Racial).
/// YOUR section always shows: Racial Traits (read-only), Perks, Flaws.
/// AVAILABLE list switches based on the active sub-tab. Racial traits are
/// auto-granted, never costable, and never removable.
function draw_tab_perks_flaws(_lx, _ly, _lw, _lh) {
	if (self[$ "pf_view"] == undefined) pf_view = "perks";

	// Three sub-tab buttons
	ui_btn("pf_perks_tab",  _lx+8,   _ly, _lx+120, _ly+22, "Perks",  pf_view=="perks"  ? c_good    : c_border, c_good);
	ui_btn("pf_flaws_tab",  _lx+128, _ly, _lx+240, _ly+22, "Flaws",  pf_view=="flaws"  ? c_failure : c_border, c_failure);
	ui_btn("pf_racial_tab", _lx+248, _ly, _lx+360, _ly+22, "Racial", pf_view=="racial" ? c_amazing : c_border, c_amazing);
	_ly += 28;

	// YOUR section header
	draw_set_colour(c_header); draw_text(_lx+8, _ly, "YOUR PERKS, FLAWS & RACIAL TRAITS");
	var _pcost = get_perks_cost(hero);
	var _fbenefit = get_flaws_benefit(hero);
	draw_set_colour(c_muted); draw_text(_lx+330, _ly, "Perks cost: " + string(_pcost) + "  Flaws refund: +" + string(_fbenefit) + "  Net: " + string(_fbenefit - _pcost));
	_ly += _lh;

	// Racial traits subgroup — always visible regardless of sub-tab.
	// Auto-granted by species, no remove buttons, name displayed without species prefix.
	var _racial_idx = 0;
	for (var _fxi = 0; _fxi < array_length(hero.fx); _fxi++) {
		var _fe = hero.fx[_fxi];
		if (_fe.type != "racial") continue;
		if (_racial_idx == 0) { draw_set_colour(c_amazing); draw_text(_lx+8, _ly, "Racial Traits:"); _ly += _lh; }
		var _fxd = get_fx_data(_fe.name);
		// Strip species prefix from displayed name (e.g. "Sesheyan Wings" -> "Wings")
		var _disp_name = _fe.name;
		var _sp_name = (_fxd != undefined && _fxd[$ "species"] != undefined) ? _fxd.species : "";
		if (_sp_name != "") {
			var _prefix = string_upper(string_char_at(_sp_name, 1)) + string_copy(_sp_name, 2, string_length(_sp_name)-1) + " ";
			if (string_pos(_prefix, _disp_name) == 1) _disp_name = string_copy(_disp_name, string_length(_prefix)+1, string_length(_disp_name) - string_length(_prefix));
		}
		// Active toggle pip — click to flip active flag (for what-if rolls on conditional traits)
		var _is_active = _fe[$ "active"] ?? true;
		var _pip_x = _lx+16; var _pip_y = _ly+5;
		draw_set_colour(_is_active ? c_amazing : c_border);
		draw_circle(_pip_x+5, _pip_y+5, 5, true);
		if (_is_active) draw_circle(_pip_x+5, _pip_y+5, 3, false);
		variable_struct_set(btn, "rf_toggle_" + string(_racial_idx), [_pip_x, _pip_y, _pip_x+12, _pip_y+12]);

		draw_set_colour(_is_active ? c_amazing : c_muted);
		draw_text(_lx+32, _ly, _disp_name);
		// Conditional traits get a [CONDITIONAL: ...] muted suffix
		if (_fxd != undefined && _fxd[$ "requires"] != undefined) {
			var _req = _fxd.requires;
			var _req_str = "[CONDITIONAL: " + (_req[$ "skill"] ?? "?") + ": " + (_req[$ "specialty"] ?? "?") + " r" + string(_req[$ "rank_min"] ?? 1) + "]";
			draw_set_colour(c_muted); draw_text(_lx+260, _ly, _req_str);
		} else if (_fxd != undefined && _fxd[$ "bonus_skill_points"] != undefined && _fxd.bonus_skill_points > 0) {
			draw_set_colour(c_good); draw_text(_lx+260, _ly, "+" + string(_fxd.bonus_skill_points) + " skill pts");
		} else if (_fxd != undefined && _fxd.modifier != 0) {
			draw_set_colour(_fxd.modifier < 0 ? c_good : c_warning);
			draw_text(_lx+260, _ly, (_fxd.modifier < 0 ? "" : "+") + string(_fxd.modifier) + " step");
		}
		_ly += _lh; _racial_idx++;
	}
	if (_racial_idx > 0) _ly += 4;

	// Perks list (existing logic, kept compact)
	var _perk_idx = 0; var _flaw_idx = 0;
	for (var _fxi = 0; _fxi < array_length(hero.fx); _fxi++) {
		var _fe = hero.fx[_fxi];
		if (_fe.type == "perk") {
			if (_perk_idx == 0) { draw_set_colour(c_good); draw_text(_lx+8, _ly, "Perks:"); _ly += _lh; }
			var _fxd = get_fx_data(_fe.name);
			var _q_tag = ((_fe[$ "quality"] ?? "") != "") ? " [" + _fe.quality + "]" : "";
			draw_set_colour(c_text); draw_text(_lx+16, _ly, _fe.name + _q_tag);
			if (_fxd != undefined) { draw_set_colour(c_warning); draw_text(_lx+350, _ly, "-" + string(_fxd.cost) + " pts"); }
			var _prk = "prm" + string(_perk_idx);
			ui_btn(_prk, _lx+450, _ly-2, _lx+500, _ly+_lh-2, "X", c_border, c_failure);
			_ly += _lh; _perk_idx++;
		}
	}
	for (var _fxi = 0; _fxi < array_length(hero.fx); _fxi++) {
		var _fe = hero.fx[_fxi];
		if (_fe.type == "flaw") {
			if (_flaw_idx == 0) { draw_set_colour(c_failure); draw_text(_lx+8, _ly, "Flaws:"); _ly += _lh; }
			var _fxd = get_fx_data(_fe.name);
			draw_set_colour(c_text); draw_text(_lx+16, _ly, _fe.name);
			if (_fxd != undefined) { draw_set_colour(c_good); draw_text(_lx+350, _ly, "+" + string(abs(_fxd.cost)) + " pts"); }
			var _frk = "frm" + string(_flaw_idx);
			ui_btn(_frk, _lx+450, _ly-2, _lx+500, _ly+_lh-2, "X", c_border, c_failure);
			_ly += _lh; _flaw_idx++;
		}
	}

	_ly += 8;
	draw_set_colour(c_border); draw_line(_lx+8, _ly, _lx+_lw-8, _ly); _ly += 8;

	// AVAILABLE list — filtered by sub-tab
	var _view_type;
	var _avail_label;
	if (pf_view == "perks")       { _view_type = "perk";   _avail_label = "AVAILABLE PERKS"; }
	else if (pf_view == "flaws")  { _view_type = "flaw";   _avail_label = "AVAILABLE FLAWS"; }
	else                          { _view_type = "racial"; _avail_label = "ALL RACIAL TRAITS (auto-granted by species — read-only)"; }

	draw_set_colour(c_header); draw_text(_lx+8, _ly, _avail_label); _ly += _lh;
	draw_set_colour(c_muted);
	if (pf_view == "perks")       { draw_text(_lx+8, _ly, "Name"); draw_text(_lx+300, _ly, "Cost");   draw_text(_lx+450, _ly, "Description"); }
	else if (pf_view == "flaws")  { draw_text(_lx+8, _ly, "Name"); draw_text(_lx+300, _ly, "Refund"); draw_text(_lx+450, _ly, "Description"); }
	else                          { draw_text(_lx+8, _ly, "Name"); draw_text(_lx+300, _ly, "Species"); draw_text(_lx+450, _ly, "Description"); }
	_ly += _lh;

	// Count total items of this type for scroll clamping
	var _type_total = 0;
	for (var _di = 0; _di < array_length(global.fx_database); _di++) { if (global.fx_database[_di].type == _view_type) _type_total++; }
	pf_scroll = clamp(pf_scroll, 0, max(0, _type_total - pf_max_visible));

	var _avail_idx = 0;
	var _btn_prefix = (pf_view == "perks") ? "padd" : ((pf_view == "flaws") ? "fadd" : "racd");
	// Clear all button rects for this type to prevent stale hits
	for (var _clr = 0; _clr < _type_total; _clr++) { variable_struct_remove(btn, _btn_prefix + string(_clr)); }
	for (var _di = 0; _di < array_length(global.fx_database); _di++) {
		var _fxd = global.fx_database[_di];
		if (_fxd.type != _view_type) { continue; }

		// Only draw items within the scroll window
		if (_avail_idx >= pf_scroll && _avail_idx < pf_scroll + pf_max_visible) {
			if (pf_view == "racial") {
				// Read-only display: name, species, description. No add buttons.
				draw_set_colour(c_amazing); draw_text(_lx+8, _ly, _fxd.name);
				draw_set_colour(c_warning); draw_text(_lx+300, _ly, string_upper(_fxd[$ "species"] ?? "?"));
				draw_set_colour(c_muted); draw_text_ext(_lx+450, _ly, _fxd.description, -1, _lw-470);
				_ly += max(_lh, string_height_ext(_fxd.description, -1, _lw-470));
			} else {
				var _owned = has_fx(hero, _fxd.name, _view_type, true) ? 1 : 0;
				var _can_add = (_owned == 0);
				if (_owned > 0 && _view_type == "perk") {
					var _hero_fe = find_fx(hero, _fxd.name, "", false);
					var _cur_q = (_hero_fe != undefined) ? (_hero_fe[$ "quality"] ?? "") : "";
					if (_fxd[$ "quality_scale"] != undefined && is_struct(_fxd.quality_scale)) {
						if (_cur_q == "" || (_cur_q == "O" && _fxd.quality_scale[$ "G"] != undefined)
							|| (_cur_q == "G" && _fxd.quality_scale[$ "A"] != undefined))
							_can_add = true;
					}
				}
				var _bk = _btn_prefix + string(_avail_idx);
				variable_struct_set(btn, _bk, [_lx+8, _ly-2, _lx+290, _ly+_lh-2]);
				var _hov = mouse_in(_lx+8, _ly-2, _lx+290, _ly+_lh-2);

				if (_owned > 0) {
					draw_set_colour(_hov && _can_add ? c_highlight : (pf_view == "perks" ? c_good : c_failure));
					var _tag = _can_add ? " [UPGRADE]" : " [OWNED]";
					if (pf_view != "perks") _tag = " [TAKEN]";
					draw_text(_lx+8, _ly, _fxd.name + _tag);
				} else {
					draw_set_colour(_hov ? c_highlight : c_text);
					draw_text(_lx+8, _ly, _fxd.name);
				}

				if (pf_view == "perks") {
					draw_set_colour(c_warning); draw_text(_lx+300, _ly, string(_fxd.cost) + " pts");
				} else {
					draw_set_colour(c_good); draw_text(_lx+300, _ly, "+" + string(abs(_fxd.cost)) + " pts");
				}
				draw_set_colour(c_muted); draw_text_ext(_lx+450, _ly, _fxd.description, -1, _lw-470);
				_ly += max(_lh, string_height_ext(_fxd.description, -1, _lw-470));
			}
		}
		_avail_idx++;
	}
	// Scroll indicator
	if (_type_total > pf_max_visible) {
		draw_set_colour(c_muted); draw_text(_lx+8, _ly, "Scroll: " + string(pf_scroll+1) + "-" + string(min(pf_scroll+pf_max_visible, _type_total)) + " of " + string(_type_total));
		_ly += _lh;
	}

	return _ly;
}

/// @function draw_tab_cybertech(_lx, _ly, _lw, _lh)
/// @description TAB 5: CYBERTECH
function draw_tab_cybertech(_lx, _ly, _lw, _lh) {
	draw_set_colour(c_header); draw_text(_lx+8, _ly, "CYBERTECH");

	// Tolerance display
	var _tol = get_cyber_tolerance(hero);
	var _used = get_cyber_used(hero);
	var _tol_col = (_used <= _tol/2) ? c_good : ((_used <= _tol) ? c_warning : c_failure);
	draw_set_colour(_tol_col);
	draw_text(_lx+130, _ly, "Tolerance: " + string(_used) + "/" + string(_tol));
	if (hero[$ "species"] != undefined && hero.species == SPECIES.MECHALUS) {
		draw_set_colour(c_amazing); draw_text(_lx+320, _ly, "(Mechalus +4)");
	}
	_ly += _lh + 4;

	// Installed cyberware (reads from hero.fx where type == "cybertech")
	var _cyber_count = 0;
	for (var _fxi = 0; _fxi < array_length(hero.fx); _fxi++) { if (hero.fx[_fxi].type == "cybertech") _cyber_count++; }
	if (_cyber_count > 0) {
		draw_set_colour(c_header); draw_text(_lx+8, _ly, "INSTALLED"); _ly += _lh;
		draw_set_colour(c_muted);
		draw_text(_lx+8, _ly, "Name"); draw_text(_lx+250, _ly, "Quality"); draw_text(_lx+330, _ly, "Size");
		draw_text(_lx+380, _ly, "Active"); draw_text(_lx+450, _ly, "Description"); _ly += _lh;

		var _ci = 0;
		for (var _fxi = 0; _fxi < array_length(hero.fx); _fxi++) {
			var _fe = hero.fx[_fxi];
			if (_fe.type != "cybertech") continue;
			var _is_active = _fe[$ "active"] ?? true;
			var _cq = _fe[$ "quality"] ?? "O";
			var _fxd = get_fx_data(_fe.name);

			draw_set_colour(c_text); draw_text(_lx+8, _ly, _fe.name);
			draw_set_colour(c_amazing); draw_text(_lx+250, _ly, _cq);
			if (_fxd != undefined) { draw_set_colour(c_muted); draw_text(_lx+330, _ly, string(_fxd[$ "size"] ?? 0)); }

			draw_set_colour(_is_active ? c_good : c_border);
			draw_circle(_lx+390, _ly+8, 6, true);
			if (_is_active) draw_circle(_lx+390, _ly+8, 3, false);
			var _ctk = "cyber_toggle_"+string(_ci);
			variable_struct_set(btn, _ctk, [_lx+382, _ly, _lx+400, _ly+_lh]);

			if (_fxd != undefined) { draw_set_colour(c_muted); draw_text_ext(_lx+450, _ly, _fxd.description, -1, _lw-470); }

			var _crk = "cyber_rm_"+string(_ci);
			ui_btn(_crk, _lx+_lw-50, _ly-2, _lx+_lw-8, _ly+_lh-2, "X", c_border, c_failure);

			_ly += _lh; _ci++;
		}
	}

	_ly += 8;
	draw_set_colour(c_border); draw_line(_lx+8, _ly, _lx+_lw-8, _ly); _ly += 8;

	// Available cyberware from fx_database (categorized, expandable)
	draw_set_colour(c_header); draw_text(_lx+8, _ly, "AVAILABLE CYBERWARE");
	draw_set_colour(c_muted); draw_text(_lx+250, _ly, "(click to expand details)");
	_ly += _lh;
	var _categories = ["neural", "body", "sensory", "weapon", "utility"];
	var _cat_labels = ["NEURAL", "BODY", "SENSORY", "WEAPONS", "UTILITY"];

	for (var _cat = 0; _cat < 5; _cat++) {
		draw_set_colour(c_warning); draw_text(_lx+8, _ly, _cat_labels[_cat]); _ly += _lh;

		var _gi = 0;
		for (var _di = 0; _di < array_length(global.fx_database); _di++) {
			var _fxd = global.fx_database[_di];
			if (_fxd.type != "cybertech") continue;
			var _fxcat = _fxd[$ "category"] ?? "";
			if (_fxcat != _categories[_cat]) { _gi++; continue; }

			var _owned = has_fx(hero, _fxd.name, "cybertech", false);
			var _is_expanded = (cyber_expanded == _gi);
			var _fxsize = _fxd[$ "size"] ?? 0;
			var _fxprereqs = _fxd[$ "prereqs"] ?? [];

			_ly = draw_expandable_catalog_item(_lx, _ly, _lw, _lh, _fxd.name, _gi, _owned, cyber_expanded, "cyber_name_", "Size:" + string(_fxsize), " [INSTALLED]");
			if (array_length(_fxprereqs) > 0) {
				var _pstr = "Req: ";
				for (var _pr = 0; _pr < array_length(_fxprereqs); _pr++) { if (_pr > 0) _pstr += ", "; _pstr += _fxprereqs[_pr]; }
				draw_set_colour(c_muted); draw_text(_lx+500, _ly-_lh, _pstr);
			}

			if (_is_expanded) {
				var _quals = ["O", "G", "A"];
				var _qual_names = ["Ordinary", "Good", "Amazing"];
				var _qual_colors = [c_text, c_good, c_amazing];
				for (var _qi = 0; _qi < 3; _qi++) {
					draw_set_colour(_qual_colors[_qi]);
					draw_text(_lx+32, _ly, _qual_names[_qi] + ":");
					draw_set_colour(c_muted);
					draw_text_ext(_lx+130, _ly, _fxd.description, -1, _lw - 290);
					var _desc_h = max(_lh, string_height_ext(_fxd.description, -1, _lw - 290));
					if (!_owned) {
						var _qk = "cyber_add_"+string(_gi)+"_"+_quals[_qi];
						ui_btn(_qk, _lx+_lw-80, _ly-2, _lx+_lw-8, _ly+_desc_h-2, "Add "+_quals[_qi], c_border, _qual_colors[_qi]);
					}
					_ly += _desc_h + 2;
				}
				_ly += 4;
			}
			_gi++;
		}
		_ly += 4;
	}

	return _ly;
}

/// @function draw_tab_rolllog(_lx, _ly, _lw, _lh)
/// @description TAB 6: ROLL LOG / PARTY STREAM
/// Offline: displays the local per-hero roll log file (strings).
/// Multiplayer: displays the in-memory rolllog_entries struct stream (rolls + chat).
/// Handles both struct entries and legacy string entries in the same array.
function draw_tab_rolllog(_lx, _ly, _lw, _lh) {
	var _connected = net_is_connected();

	// Reload local file if dirty (offline mode only — online mode keeps the in-memory stream)
	if (!_connected && rolllog_dirty && hero != undefined) {
		rolllog_entries = load_roll_log_tail(hero, max_log_entries);
		rolllog_dirty = false;
		rolllog_scroll = 0;
	}

	// Header
	draw_set_colour(c_header);
	if (_connected) {
		var _pcount = array_length(net_get_players());
		draw_text(_lx+8, _ly, "PARTY STREAM (" + string(_pcount) + " players)");
		draw_set_colour(c_muted);
		draw_text(_lx+280, _ly, "Session: " + net_get_session_code());
	} else {
		draw_text(_lx+8, _ly, "ROLL LOG");
		draw_set_colour(c_muted);
		draw_text(_lx+150, _ly, "Last " + string(max_log_entries) + " rolls  |  File: " + get_roll_log_path(hero));
	}
	_ly += _lh + 4;

	var _total = array_length(rolllog_entries);
	if (_total == 0) {
		draw_set_colour(c_muted);
		if (_connected) {
			draw_text(_lx+8, _ly, "Party stream is empty. Make a roll or send a chat.");
		} else {
			draw_text(_lx+8, _ly, "No rolls recorded yet. Make a roll and it will appear here.");
		}
	} else {
		var _vis = min(30, _total);
		var _max_scroll = max(0, _total - _vis);
		rolllog_scroll = clamp(rolllog_scroll, 0, _max_scroll);

		// Scroll buttons — above the list
		ui_btn("rl_scroll_up", _lx+_lw-110, _ly-_lh, _lx+_lw-60, _ly-2, "^", c_border, c_amazing);
		ui_btn("rl_scroll_dn", _lx+_lw-55, _ly-_lh, _lx+_lw-4, _ly-2, "v", c_border, c_amazing);

		for (var _ci = 0; _ci < _vis; _ci++) {
			var _idx = _total - 1 - _ci - rolllog_scroll;
			if (_idx < 0 || _idx >= _total) break;
			var _entry = rolllog_entries[_idx];

			// Copy button rect (right side)
			var _cb_x2 = _lx + _lw - 4;
			var _cb_x1 = _cb_x2 - 46;
			ui_btn("rl_copy"+string(_ci), _cb_x1, _ly, _cb_x2, _ly+_lh-2, "Copy", c_border, c_highlight);

			if (is_struct(_entry)) {
				// Structured entry (party stream: rolls or chat)
				if (_entry.is_chat) {
					draw_set_colour(c_amazing);
					draw_text_ext(_lx+8, _ly, "[" + _entry.sender_name + "]: " + _entry.chat_text, -1, _lw - 120);
				} else {
					// Remote rolls get a subtle outlined background tint
					if (_entry.is_remote) {
						draw_set_colour(c_border);
						draw_rectangle(_lx+4, _ly-1, _lx+_lw-60, _ly+_lh-2, true);
					}
					// Alternity degree: 3=AMAZING, 2=GOOD, 1=ORDINARY, 0=FAILURE, -1=CRITICAL FAILURE
					var _color = c_text;
					switch (_entry.degree) {
						case 3: _color = c_amazing; break;
						case 2: _color = c_good; break;
						case 1: _color = c_text; break;
						case 0: _color = c_failure; break;
						case -1: _color = c_failure; break;
					}
					var _label = "[" + _entry.sender_name + "] ";
					if (_entry.character_name != "") _label += _entry.character_name + ": ";
					_label += _entry.skill_name + " -> " + _entry.degree_name + " (" + string(_entry.total) + ")";
					if (_entry.is_remote) _label += "  [remote]";
					draw_set_colour(_color);
					draw_text_ext(_lx+8, _ly, _label, -1, _lw - 120);
				}
			} else if (is_string(_entry)) {
				// Legacy plain string (file-loaded offline entry)
				var _ec = c_text;
				if (string_pos("AMAZING", _entry) > 0) _ec = c_amazing;
				else if (string_pos("GOOD", _entry) > 0) _ec = c_good;
				else if (string_pos("ORDINARY", _entry) > 0) _ec = c_text;
				else if (string_pos("MARGINAL", _entry) > 0) _ec = c_warning;
				else if (string_pos("FAILURE", _entry) > 0) _ec = c_failure;
				else if (string_pos("CRITICAL", _entry) > 0) _ec = c_failure;

				draw_set_colour(c_muted);
				draw_text(_lx+8, _ly, string(_total - _ci - rolllog_scroll));
				draw_set_colour(_ec);
				draw_text_ext(_lx+40, _ly, _entry, -1, _lw - 120);
			}
			_ly += _lh;
		}
	}

	// Chat input box at bottom (only when connected)
	if (_connected) {
		_ly += 8;
		draw_set_colour(c_muted);
		draw_text(_lx+8, _ly, "Chat:");
		_ly += _lh;
		draw_set_colour(c_panel);
		draw_rectangle(_lx+8, _ly, _lx+_lw-80, _ly+22, false);
		draw_set_colour(net_input_focus == "chat" ? c_highlight : c_border);
		draw_rectangle(_lx+8, _ly, _lx+_lw-80, _ly+22, true);
		draw_set_colour(c_text);
		draw_text(_lx+14, _ly+4, net_chat_buffer + (net_input_focus == "chat" ? "_" : ""));
		btn.rl_chat_field = [_lx+8, _ly, _lx+_lw-80, _ly+22];
		ui_btn("rl_chat_send", _lx+_lw-72, _ly, _lx+_lw-8, _ly+22, "Send", c_border, c_good);
		_ly += 28;
	}

	return _ly;
}

/// @function draw_tab_info(_lx, _ly, _lw, _lh)
/// @description TAB 7: INFO/REFERENCE
function draw_tab_info(_lx, _ly, _lw, _lh) {
	var _infoBlocks = [];
	var _infoTotalHeight = 0;
	var _infoWidth = _lw - 40;

	if (gm_mode) {
		draw_set_colour(c_header); draw_text(_lx+8, _ly, "GM RESOURCES & CUSTOMIZATION"); _ly += _lh+4;
		_infoTotalHeight = build_gm_resource_blocks(_infoBlocks, _lh, _infoWidth);
	} else {
		draw_set_colour(c_header); draw_text(_lx+8, _ly, "HOW TO USE YOUR CHARACTER"); _ly += _lh+4;
		_infoTotalHeight = build_player_info_blocks(_infoBlocks, _lh, _infoWidth);
	}

	return draw_scrollable_info_blocks(_lx, _ly, _lw, _lh, _infoBlocks, _infoTotalHeight, "info_scroll");
}


// ============================================================
// TAB 8: GRID / CYBERDECK
// ============================================================

/// @function draw_tab_grid(_lx, _ly, _lw, _lh)
/// @description TAB 8: GRID/CYBERDECK — programs, computer selection, and custom program builder
function draw_tab_grid(_lx, _ly, _lw, _lh) {
	var _pl_names = ["Stone","Bronze","Medieval","Reason","Industrial","Information","Fusion","Gravity","Energy"];

	// Sub-tab buttons
	ui_btn("grid_programs_tab", _lx+8, _ly, _lx+110, _ly+22, "Programs", grid_view=="programs"?c_amazing:c_border, c_amazing);
	ui_btn("grid_computer_tab", _lx+118, _ly, _lx+220, _ly+22, "Computer", grid_view=="computer"?c_good:c_border, c_good);
	ui_btn("grid_builder_tab", _lx+228, _ly, _lx+320, _ly+22, "Builder", grid_view=="builder"?c_warning:c_border, c_warning);

	if (grid_view == "programs") {
		var _add_label = grid_adding ? "Close" : "Add Program";
		ui_btn("grid_toggle_add", _lx+340, _ly, _lx+460, _ly+22, _add_label, c_border, grid_adding?c_failure:c_highlight);
	}

	// Deck summary
	var _proc = hero.deck[$ "processor"] ?? "";
	var _comp = hero.deck[$ "computer"] ?? "None";
	var _slots = get_deck_slots(hero);
	var _used = _slots.used;
	var _mem = _slots.total;
	draw_circuit_border(_lx, _ly-4, _lw, 30, c_amazing);
	draw_set_colour(c_muted);
	draw_text(_lx+500, _ly, "Deck: " + _comp + " (" + _proc + ") | Slots: " + string(_used) + "/" + string(_mem));
	_ly += 28;

	// ======== PROGRAMS VIEW ========
	if (grid_view == "programs") {
		if (!grid_adding) {
			draw_set_colour(c_header); draw_text(_lx+8, _ly, "YOUR PROGRAMS"); _ly += _lh;
			draw_set_colour(c_muted);
			draw_text(_lx+8, _ly, "Name"); draw_text(_lx+250, _ly, "Type"); draw_text(_lx+350, _ly, "Quality");
			draw_text(_lx+430, _ly, "Slots"); draw_text(_lx+490, _ly, "Description"); _ly += _lh;

			for (var _i = 0; _i < array_length(hero.deck.programs); _i++) {
				var _hp = hero.deck.programs[_i];
				var _pd = get_program_data(_hp.name);
				draw_set_colour(c_text); draw_text(_lx+8, _ly, _hp.name);
				draw_set_colour(c_muted);
				if (_pd != undefined) {
					draw_text(_lx+250, _ly, _pd.type);
					draw_text(_lx+430, _ly, string(_pd[$ "slots"] ?? 1));
					draw_text_ext(_lx+490, _ly, _pd.description, -1, _lw - 560);
				}
				var _qc = (_hp.quality == "A") ? c_amazing : ((_hp.quality == "G") ? c_good : c_text);
				draw_set_colour(_qc); draw_text(_lx+350, _ly, _hp.quality);
				ui_btn("grid_prm_"+string(_i), _lx+_lw-50, _ly-2, _lx+_lw-8, _ly+_lh-2, "X", c_border, c_failure);
				_ly += _lh;
			}
			if (array_length(hero.deck.programs) == 0) {
				draw_set_colour(c_muted); draw_text(_lx+8, _ly, "No programs installed."); _ly += _lh;
			}
			draw_set_colour(c_muted); draw_text(_lx+8, _ly, "Slots: " + string(_used) + "/" + string(_mem)); _ly += _lh;
		} else {
			// AVAILABLE PROGRAMS
			var _pl_label = (campaign_pl >= 0 && campaign_pl < 9) ? _pl_names[campaign_pl] : "";
			draw_set_colour(c_header); draw_text(_lx+8, _ly, "AVAILABLE PROGRAMS (PL " + string(campaign_pl) + " " + _pl_label + ")"); _ly += _lh;
			var _types = ["operator", "hacking", "utility"];
			var _type_labels = ["OPERATOR", "HACKING", "UTILITY"];
			var _gi = 0;
			for (var _tc = 0; _tc < 3; _tc++) {
				draw_set_colour(c_warning); draw_text(_lx+8, _ly, _type_labels[_tc]); _ly += _lh;
				for (var _di = 0; _di < array_length(global.programs); _di++) {
					var _prog = global.programs[_di];
					if (_prog.type != _types[_tc]) continue;
					if ((_prog[$ "pl"] ?? 0) > campaign_pl) { _gi++; continue; }
					var _installed = false;
					for (var _k = 0; _k < array_length(hero.deck.programs); _k++) {
						if (hero.deck.programs[_k].name == _prog.name) { _installed = true; break; }
					}
					_ly = draw_expandable_catalog_item(_lx, _ly, _lw, _lh, _prog.name, _gi, _installed, grid_expanded, "grid_pname_", "", " [INSTALLED]");
					draw_set_colour(c_muted);
					draw_text(_lx+350, _ly-_lh, string(_prog[$ "slots"] ?? 1) + " slot");
					draw_text(_lx+430, _ly-_lh, "PL " + string(_prog[$ "pl"] ?? 0));
					if (grid_expanded == _gi) {
						draw_set_colour(c_muted);
						draw_text_ext(_lx+32, _ly, _prog.description, -1, _lw - 100);
						_ly += max(_lh, string_height_ext(_prog.description, -1, _lw - 100));
						if (!_installed) {
							var _quals = ["M","O","G","A"];
							var _qcols = [c_text, c_muted, c_good, c_amazing];
							var _qx = _lx + 32;
							for (var _qi = 0; _qi < 4; _qi++) {
								ui_btn("grid_padd_"+string(_gi)+"_"+_quals[_qi], _qx, _ly-2, _qx+50, _ly+_lh-2, "Add "+_quals[_qi], c_border, _qcols[_qi]);
								_qx += 58;
							}
							_ly += _lh;
						}
						_ly += 4;
					}
					_gi++;
				}
				_ly += 4;
			}
		}
	}

	// ======== COMPUTER VIEW ========
	if (grid_view == "computer") {
		draw_set_colour(c_header); draw_text(_lx+8, _ly, "YOUR COMPUTER"); _ly += _lh;
		draw_set_colour(c_text); draw_text(_lx+8, _ly, _comp);
		if (_proc != "" && global.processor_quality[$ _proc] != undefined) {
			var _pq = global.processor_quality[$ _proc];
			draw_set_colour(c_muted);
			draw_text(_lx+250, _ly, _pq.name + " processor | Bonus: " + string(_pq.bonus) + " | Memory: " + string(_pq.memory_base) + " slots");
		}
		_ly += _lh + 8;
		draw_set_colour(c_border); draw_line(_lx+8, _ly, _lx+_lw-8, _ly); _ly += 8;
		draw_set_colour(c_header); draw_text(_lx+8, _ly, "AVAILABLE COMPUTERS"); _ly += _lh;
		draw_set_colour(c_muted); draw_text(_lx+8, _ly, "Name"); draw_text(_lx+300, _ly, "Processors"); draw_text(_lx+450, _ly, "PL"); _ly += _lh;
		for (var _ci = 0; _ci < array_length(global.computers); _ci++) {
			var _cd = global.computers[_ci];
			if ((_cd[$ "pl"] ?? 0) > campaign_pl) continue;
			var _is_cur = (_comp == _cd.name);
			draw_set_colour(_is_cur ? c_good : c_text);
			draw_text(_lx+8, _ly, _cd.name + (_is_cur ? " [CURRENT]" : ""));
			draw_set_colour(c_muted);
			var _ps = "";
			for (var _pi = 0; _pi < array_length(_cd.processors); _pi++) { if (_pi > 0) _ps += "/"; _ps += _cd.processors[_pi]; }
			draw_text(_lx+300, _ly, _ps);
			draw_text(_lx+450, _ly, "PL " + string(_cd[$ "pl"] ?? 0));
			if (!_is_cur) {
				var _is_exp = (grid_comp_expanded == _ci);
				ui_btn("grid_csel_"+string(_ci), _lx+_lw-80, _ly-2, _lx+_lw-8, _ly+_lh-2, _is_exp ? "Cancel" : "Select", c_border, _is_exp ? c_failure : c_good);
			}
			_ly += _lh;
			// Show inline quality buttons when expanded
			if (!_is_cur && grid_comp_expanded == _ci) {
				var _qx = _lx + 32;
				var _qcols = { M: c_text, O: c_muted, G: c_good, A: c_amazing };
				for (var _pi = 0; _pi < array_length(_cd.processors); _pi++) {
					var _q = _cd.processors[_pi];
					var _qc = _qcols[$ _q] ?? c_highlight;
					ui_btn("grid_cqual_"+string(_ci)+"_"+_q, _qx, _ly-2, _qx+50, _ly+_lh-2, _q, c_border, _qc);
					_qx += 58;
				}
				_ly += _lh + 2;
			}
		}
	}

	// ======== BUILDER VIEW ========
	if (grid_view == "builder") {
		draw_set_colour(c_header); draw_text(_lx+8, _ly, "CUSTOM PROGRAM BUILDER"); _ly += _lh;
		draw_set_colour(c_muted);
		draw_text_ext(_lx+8, _ly, "Create a homebrew program. Define name, type, slot cost, and description.", -1, _lw-16);
		_ly += _lh + 8;
		ui_btn("grid_build_custom", _lx+8, _ly, _lx+220, _ly+26, "Build Custom Program", c_border, c_highlight);
		_ly += 34;
		var _has_custom = false;
		for (var _i = 0; _i < array_length(hero.deck.programs); _i++) {
			if (hero.deck.programs[_i].quality == "custom") {
				if (!_has_custom) { draw_set_colour(c_header); draw_text(_lx+8, _ly, "HOMEBREW PROGRAMS"); _ly += _lh; _has_custom = true; }
				draw_set_colour(c_warning); draw_text(_lx+16, _ly, hero.deck.programs[_i].name);
				ui_btn("grid_prm_"+string(_i), _lx+_lw-50, _ly-2, _lx+_lw-8, _ly+_lh-2, "X", c_border, c_failure);
				_ly += _lh;
			}
		}
		if (!_has_custom) { draw_set_colour(c_muted); draw_text(_lx+8, _ly, "No homebrew programs yet."); _ly += _lh; }
	}

	return _ly;
}


// _gm_get_skill_score() REMOVED — inlined at callsites

/// @function _gm_get_best_awareness_score(stat)
/// @description Returns best awareness score string: Perception > Intuition > broad > untrained
function _gm_get_best_awareness_score(_stat) {
	var _specs = ["Perception", "Intuition"];
	for (var _i = 0; _i < 2; _i++) {
		var _idx = find_skill(_stat, "Awareness", _specs[_i]);
		if (_idx >= 0) {
			var _sk = _stat.skills[_idx];
			return _specs[_i] + " " + string(_sk.score_ordinary) + "/" + string(_sk.score_good) + "/" + string(_sk.score_amazing);
		}
	}
	var _idx = find_skill(_stat, "Awareness", "");
	if (_idx >= 0) {
		var _sk = _stat.skills[_idx];
		return "Aware(B) " + string(_sk.score_ordinary) + "/" + string(_sk.score_good) + "/" + string(_sk.score_amazing);
	}
	return "Untrained " + string(_stat.wil.untrained);
}

// _gm_get_psi_summary() REMOVED — inlined at callsite

// _gm_get_enhanced_senses() REMOVED — inlined at callsite


// ============================================================
// GM TAB 0: PARTY
// ============================================================
/// @function draw_gm_party(lx, ly, lw, lh)
/// @description GM TAB 0: Draws party roster with HP, senses, resolve, res mods, and management buttons
function draw_gm_party(_lx, _ly, _lw, _lh) {
	draw_set_colour(c_header); draw_text(_lx+8, _ly, "PARTY MANAGEMENT"); _ly += _lh + 2;

	// Action buttons row
	var _bw = 90;
	ui_btn("gm_party_import", _lx+8, _ly, _lx+8+_bw, _ly+24, "Import", c_border, c_amazing);
	ui_btn("gm_party_new", _lx+12+_bw, _ly, _lx+12+_bw*2, _ly+24, "New Char", c_border, c_highlight);
	ui_btn("gm_party_save_all", _lx+16+_bw*2, _ly, _lx+16+_bw*3, _ly+24, "Save All", c_border, c_good);
	_ly += 28;

	draw_set_colour(c_border); draw_line(_lx+8, _ly, _lx+_lw-8, _ly); _ly += 4;

	if (array_length(global.party) == 0) {
		draw_set_colour(c_muted); draw_text(_lx+16, _ly, "No party members yet. Import or create characters."); _ly += _lh;
	} else {
		for (var _i = 0; _i < array_length(global.party); _i++) {
			var _partyChar = global.party[_i];
			var _isSelected = (_i == obj_game.party_selected);
			var _rowStartY = _ly;

			// Highlight selected row background
			if (_isSelected) {
				draw_set_colour(merge_colour(c_panel, c_good, 0.12));
				draw_rectangle(_lx+8, _rowStartY-2, _lx+_lw-8, _rowStartY + _lh*3 + 6, false);
			}

			// ROW 1: Name | species/prof | HP | buttons (right-anchored, packed tight)
			// Buttons go first so we know where the HP/info area ends.
			// Layout: AC (38) | Edit (40) | Push (40) | >NPC (50) | X (30) = 198px + 4px padding
			var _buttonW_total = 220;
			var _buttonX = _lx + _lw - _buttonW_total - 4;
			ui_btn("gm_pac_"   + string(_i), _buttonX,     _ly-2, _buttonX+38,  _ly+_lh-2, "AC",   c_border, c_amazing);
			ui_btn("gm_pe_"    + string(_i), _buttonX+42,  _ly-2, _buttonX+82,  _ly+_lh-2, "Edit", c_border, c_highlight);
			ui_btn("gm_ppush_" + string(_i), _buttonX+86,  _ly-2, _buttonX+126, _ly+_lh-2, "Push", c_border, c_good);
			ui_btn("gm_pmv_"   + string(_i), _buttonX+130, _ly-2, _buttonX+180, _ly+_lh-2, ">NPC", c_border, c_warning);
			ui_btn("gm_prm_"   + string(_i), _buttonX+184, _ly-2, _buttonX+214, _ly+_lh-2, "X",    c_border, c_failure);

			// Now name + species/prof + HP, all in the area to the LEFT of the buttons
			var _row_right = _buttonX - 8;
			var _name_w = 140;
			var _hp_w = 200;
			var _sp_x = _lx + 16 + _name_w + 4;
			var _hp_x = _row_right - _hp_w;
			var _sp_max_w = _hp_x - _sp_x - 8;
			draw_set_colour(_isSelected ? c_good : c_text);
			draw_text_ext(_lx+16, _ly, _partyChar.name, -1, _name_w);
			draw_set_colour(c_muted);
			var _speciesName = _partyChar[$ "species"] != undefined ? get_species_name(_partyChar.species) : "?";
			draw_text_ext(_sp_x, _ly, _speciesName + " " + get_profession_name(_partyChar.profession), -1, _sp_max_w);
			// HP summary
			var _healthStr = "S:" + string(_partyChar.stun.current) + "/" + string(_partyChar.stun.max) +
			              " W:" + string(_partyChar.wound.current) + "/" + string(_partyChar.wound.max) +
			              " M:" + string(_partyChar.mortal.current) + "/" + string(_partyChar.mortal.max);
			draw_set_colour(_partyChar.wound.current < _partyChar.wound.max ? c_warning : c_good);
			draw_text(_hp_x, _ly, _healthStr);

			variable_struct_set(btn, "gm_psel_" + string(_i), [_lx+8, _rowStartY-2, _buttonX-4, _rowStartY + _lh*3 + 6]);
			_ly += _lh;

			// ROW 2: Senses + Resolve
			draw_set_colour(c_muted); draw_text(_lx+24, _ly, "Senses:");
			draw_set_colour(c_text); draw_text(_lx+80, _ly, _gm_get_best_awareness_score(_partyChar));
			draw_set_colour(c_muted); draw_text(_lx+280, _ly, "Mental Res:");
			var _mr_idx = find_skill(_partyChar, "Resolve", "Mental resolve"); if (_mr_idx < 0) _mr_idx = find_skill(_partyChar, "Resolve", "");
			draw_set_colour(c_text); draw_text(_lx+365, _ly, _mr_idx >= 0 ? string(_partyChar.skills[_mr_idx].score_ordinary) + "/" + string(_partyChar.skills[_mr_idx].score_good) + "/" + string(_partyChar.skills[_mr_idx].score_amazing) : "--");
			draw_set_colour(c_muted); draw_text(_lx+430, _ly, "Physical Res:");
			var _pr_idx = find_skill(_partyChar, "Resolve", "Physical resolve"); if (_pr_idx < 0) _pr_idx = find_skill(_partyChar, "Resolve", "");
			draw_set_colour(c_text); draw_text(_lx+520, _ly, _pr_idx >= 0 ? string(_partyChar.skills[_pr_idx].score_ordinary) + "/" + string(_partyChar.skills[_pr_idx].score_good) + "/" + string(_partyChar.skills[_pr_idx].score_amazing) : "--");
			_ly += _lh;

			// ROW 3: Enhanced senses, psionics, resistance mods
			// Enhanced senses inline
			var _enhancedSenses = "";
			if (_partyChar[$ "species"] != undefined && _partyChar.species == SPECIES.SESHEYAN) _enhancedSenses += "Infrared";
			var _sense_fx = ["Observant", "Heightened Ability", "Optic Enhancements", "Audio Enhancements", "Sensor Link", "Optic Screen"];
			for (var _fxIndex = 0; _fxIndex < array_length(_partyChar.fx); _fxIndex++) { var _fxEntry = _partyChar.fx[_fxIndex]; if (!(_fxEntry[$ "active"] ?? true)) continue; for (var _searchIndex = 0; _searchIndex < array_length(_sense_fx); _searchIndex++) { if (_fxEntry.name == _sense_fx[_searchIndex]) { if (_enhancedSenses != "") _enhancedSenses += ", "; _enhancedSenses += _fxEntry.name; if ((_fxEntry[$ "quality"] ?? "") != "") _enhancedSenses += "(" + _fxEntry.quality + ")"; break; } } }
			var _psi_broads = ["Telepathy", "Telekinesis", "ESP", "Biokinesis"]; var _psionicSummary = "";
			for (var _psiIndex = 0; _psiIndex < 4; _psiIndex++) { if (find_skill(_partyChar, _psi_broads[_psiIndex], "") >= 0) { if (_psionicSummary != "") _psionicSummary += ", "; _psionicSummary += _psi_broads[_psiIndex]; } }
			draw_set_colour(c_muted); draw_text(_lx+24, _ly, "Res:");
			draw_set_colour(c_text);
			draw_text(_lx+52, _ly, "STR:" + ((_partyChar.str.res_mod > 0 ? "+" : "") + string(_partyChar.str.res_mod)) + "  DEX:" + ((_partyChar.dex.res_mod > 0 ? "+" : "") + string(_partyChar.dex.res_mod)) + "  WIL:" + ((_partyChar.wil.res_mod > 0 ? "+" : "") + string(_partyChar.wil.res_mod)));
			if (_enhancedSenses != "") { draw_set_colour(c_amazing); draw_text(_lx+260, _ly, _enhancedSenses); }
			if (_psionicSummary != "") { draw_set_colour(c_highlight); draw_text(_lx+460, _ly, "Psi: " + _psionicSummary); }
			_ly += _lh + 6;

			// Separator between entries
			draw_set_colour(merge_colour(c_panel, c_border, 0.5)); draw_line(_lx+16, _ly, _lx+_lw-16, _ly); _ly += 4;
		}
	}
	return _ly;
}


// ============================================================
// GM TAB 1: NPCs
// ============================================================
/// @function draw_gm_npcs(lx, ly, lw, lh)
/// @description GM TAB 1: Draws NPC list grouped by faction with edit/move/remove controls
function draw_gm_npcs(_lx, _ly, _lw, _lh) {
	draw_set_colour(c_header); draw_text(_lx+8, _ly, "NPC MANAGEMENT"); _ly += _lh + 2;
	draw_set_colour(c_muted); draw_text(_lx+8, _ly, "Non-player characters organized by faction/team."); _ly += _lh + 4;

	// Action buttons
	var _bw = 90;
	ui_btn("gm_npc_quick", _lx+8, _ly, _lx+8+_bw, _ly+24, "Quick NPC", c_border, c_warning);
	ui_btn("gm_npc_import", _lx+12+_bw, _ly, _lx+12+_bw*2, _ly+24, "Import", c_border, c_amazing);
	ui_btn("gm_npc_add_fac", _lx+16+_bw*2, _ly, _lx+16+_bw*3, _ly+24, "+ Faction", c_border, c_highlight);
	_ly += 30;

	// Filter indicator (set by Factions tab "View" button)
	if (gm_npc_filter_faction != "") {
		draw_set_colour(c_warning); draw_text(_lx+8, _ly, "Filter: " + gm_npc_filter_faction);
		ui_btn("gm_npc_clear_filter", _lx+8+string_width("Filter: " + gm_npc_filter_faction)+12, _ly-2, _lx+8+string_width("Filter: " + gm_npc_filter_faction)+102, _ly+_lh-2, "Clear filter", c_border, c_failure);
		_ly += _lh + 4;
	}

	draw_set_colour(c_border); draw_line(_lx+8, _ly, _lx+_lw-8, _ly); _ly += 6;

	if (array_length(global.npcs) == 0) {
		draw_set_colour(c_muted); draw_text(_lx+16, _ly, "No NPCs yet. Use Quick NPC or Import."); _ly += _lh;
	} else {
		// Draw NPCs grouped by faction (filtered if gm_npc_filter_faction is set)
		for (var _factionIndex = 0; _factionIndex < array_length(global.factions); _factionIndex++) {
			var _factionName = global.factions[_factionIndex];
			if (gm_npc_filter_faction != "" && _factionName != gm_npc_filter_faction) continue;
			var _members = get_npcs_by_faction(_factionName);
			if (array_length(_members) == 0) continue;

			// Faction header
			draw_set_colour(c_warning); draw_text(_lx+8, _ly, "[ " + _factionName + " ]");
			draw_set_colour(c_muted); draw_text(_lx + string_width("[ " + _factionName + " ]") + 16, _ly, "(" + string(array_length(_members)) + ")");
			_ly += _lh + 2;

			// Column headers
			draw_set_colour(c_muted);
			draw_text(_lx+24, _ly, "Name"); draw_text(_lx+200, _ly, "Species"); draw_text(_lx+300, _ly, "Prof");
			_ly += _lh;

			for (var _memberIndex = 0; _memberIndex < array_length(_members); _memberIndex++) {
				var _npcEntry = _members[_memberIndex];
				var _npc = _npcEntry.stat;
				var _globalNpcIndex = _npcEntry.idx; // global index in global.npcs
				var _isSelected = (_globalNpcIndex == obj_game.gm_npc_selected);

				if (_isSelected) {
					draw_set_colour(merge_colour(c_panel, c_warning, 0.15));
					draw_rectangle(_lx+16, _ly-1, _lx+_lw-8, _ly+_lh, false);
				}

				// Buttons first (right-anchored), then name/species/prof in remaining space
				var _nbtn_total = 220;
				var _buttonX = _lx + _lw - _nbtn_total - 4;
				ui_btn("gm_nac_" + string(_globalNpcIndex), _buttonX,     _ly-2, _buttonX+38,  _ly+_lh-2, "AC",    c_border, c_amazing);
				ui_btn("gm_ne_"  + string(_globalNpcIndex), _buttonX+42,  _ly-2, _buttonX+82,  _ly+_lh-2, "Edit",  c_border, c_highlight);
				ui_btn("gm_nmv_" + string(_globalNpcIndex), _buttonX+86,  _ly-2, _buttonX+150, _ly+_lh-2, ">Party",c_border, c_good);
				ui_btn("gm_nrm_" + string(_globalNpcIndex), _buttonX+154, _ly-2, _buttonX+184, _ly+_lh-2, "X",     c_border, c_failure);

				var _row_right_n = _buttonX - 8;
				var _name_w_n = 160;
				var _sp_x_n = _lx + 24 + _name_w_n + 4;
				var _prof_x_n = _sp_x_n + 110;
				draw_set_colour(_isSelected ? c_warning : c_text);
				draw_text_ext(_lx+24, _ly, _npc.name, -1, _name_w_n);
				draw_set_colour(c_muted);
				var _speciesName = _npc[$ "species"] != undefined ? get_species_name(_npc.species) : "?";
				draw_text_ext(_sp_x_n, _ly, _speciesName, -1, 100);
				draw_text_ext(_prof_x_n, _ly, get_profession_name(_npc.profession), -1, max(60, _row_right_n - _prof_x_n - 4));

				variable_struct_set(btn, "gm_nsel_" + string(_globalNpcIndex), [_lx+16, _ly-1, _buttonX-4, _ly+_lh]);
				_ly += _lh + 3;
			}
			_ly += 4;
		}
	}
	return _ly;
}


// ============================================================
// GM TAB 2: ENCOUNTER
// ============================================================

// _enc_draw_char_row() REMOVED — merged into draw_gm_encounter

/// @function draw_gm_encounter(lx, ly, lw, lh)
/// @description GM TAB 2: Draws encounter tracker with initiative bar, phase columns, and party/NPC status rows
function draw_gm_encounter(_lx, _ly, _lw, _lh) {
	draw_set_colour(c_header); draw_text(_lx+8, _ly, "ENCOUNTER");
	// Round counter — right of the header
	draw_set_colour(c_warning);
	draw_text(_lx+150, _ly, "Round: " + string(current_round));
	_ly += _lh + 2;

	// Buttons
	ui_btn("gm_enc_roll_all", _lx+8, _ly, _lx+130, _ly+24, "Roll All Init", c_border, c_amazing);
	ui_btn("gm_enc_new_round", _lx+136, _ly, _lx+256, _ly+24, "New Round", c_border, c_warning);
	ui_btn("gm_enc_reset", _lx+262, _ly, _lx+362, _ly+24, "Clear Init", c_border, c_muted);
	_ly += 28;

	// ---- INITIATIVE BAR ----
	var _phase_names = ["AMAZING", "GOOD", "ORDINARY", "MARGINAL"];
	var _phase_cols = [c_amazing, c_good, c_text, c_warning];
	var _bar_x = _lx + 8;
	var _bar_w = _lw - 16;
	var _col_w = floor(_bar_w / 4);

	// Phase header row
	for (var _p = 0; _p < 4; _p++) {
		var _cx = _bar_x + _p * _col_w;
		draw_set_colour(merge_colour(c_panel, _phase_cols[_p], 0.2));
		draw_rectangle(_cx, _ly, _cx + _col_w - 2, _ly + _lh, false);
		draw_set_colour(_phase_cols[_p]);
		draw_set_halign(fa_center); draw_text(_cx + _col_w/2, _ly + 1, _phase_names[_p]); draw_set_halign(fa_left);
	}
	_ly += _lh + 2;

	// Collect names per phase
	var _phase_lists = [[], [], [], []]; // 0=Amazing, 1=Good, 2=Ordinary, 3=Marginal
	for (var _i = 0; _i < array_length(global.party); _i++) {
		var _initPhase = global.party[_i][$ "_init_phase"] ?? -1;
		if (_initPhase >= 0 && _initPhase < 4) array_push(_phase_lists[_initPhase], { name: global.party[_i].name, is_party: true });
	}
	for (var _i = 0; _i < array_length(global.npcs); _i++) {
		var _initPhase = global.npcs[_i][$ "_init_phase"] ?? -1;
		if (_initPhase >= 0 && _initPhase < 4) array_push(_phase_lists[_initPhase], { name: global.npcs[_i].name, is_party: false });
	}

	// Draw names in columns
	var _max_rows = 0;
	for (var _p = 0; _p < 4; _p++) _max_rows = max(_max_rows, array_length(_phase_lists[_p]));

	for (var _r = 0; _r < _max_rows; _r++) {
		for (var _p = 0; _p < 4; _p++) {
			if (_r < array_length(_phase_lists[_p])) {
				var _entry = _phase_lists[_p][_r];
				var _cx = _bar_x + _p * _col_w + 4;
				draw_set_colour(_entry.is_party ? c_good : c_failure);
				draw_text(_cx, _ly, _entry.name);
			}
		}
		_ly += _lh;
	}
	if (_max_rows == 0) { draw_set_colour(c_muted); draw_text(_bar_x+4, _ly, "No initiative rolled yet."); _ly += _lh; }
	_ly += 4;

	draw_set_colour(c_border); draw_line(_lx+8, _ly, _lx+_lw-8, _ly); _ly += 6;

	// Column headers for detailed view
	draw_set_colour(c_muted);
	draw_text(_lx+16, _ly, "Name"); draw_text(_lx+140, _ly, "AC"); draw_text(_lx+280, _ly, "Phase");
	draw_text(_lx+320, _ly, "Acts"); draw_text(_lx+370, _ly, "Res Mods"); draw_text(_lx+530, _ly, "S/W/M Status");
	_ly += _lh;
	draw_set_colour(c_border); draw_line(_lx+8, _ly, _lx+_lw-8, _ly); _ly += 4;

	// Party
	if (array_length(global.party) > 0) {
		draw_set_colour(c_good); draw_text(_lx+8, _ly, "PARTY"); _ly += _lh;
		for (var _i = 0; _i < array_length(global.party); _i++)
			_ly = draw_encounter_char_row(_lx, _ly, _lh, global.party[_i], c_good, true);
	}

	if (array_length(global.npcs) > 0) {
		_ly += 4;
		draw_set_colour(c_failure); draw_text(_lx+8, _ly, "HOSTILES / NPCs"); _ly += _lh;
		for (var _i = 0; _i < array_length(global.npcs); _i++)
			_ly = draw_encounter_char_row(_lx, _ly, _lh, global.npcs[_i], c_failure, false);
	}

	return _ly;
}


// ============================================================
// GM TAB 3: FACTIONS
// ============================================================
/// @function draw_gm_factions(lx, ly, lw, lh)
/// @description GM TAB 3: Manage factions — list, add, rename, delete, view-NPCs-by-faction.
function draw_gm_factions(_lx, _ly, _lw, _lh) {
	draw_set_colour(c_header); draw_text(_lx+8, _ly, "FACTIONS"); _ly += _lh + 2;
	draw_set_colour(c_muted); draw_text(_lx+8, _ly, "Manage groups for organizing NPCs. Click View to filter the NPCs tab to a faction."); _ly += _lh + 4;

	// + Faction button
	ui_btn("gm_fac_add", _lx+8, _ly, _lx+128, _ly+24, "+ Faction", c_border, c_good);
	_ly += 30;

	draw_set_colour(c_border); draw_line(_lx+8, _ly, _lx+_lw-8, _ly); _ly += 6;

	// Faction list
	if (array_length(global.factions) == 0) {
		draw_set_colour(c_muted); draw_text(_lx+16, _ly, "No factions yet. Click + Faction to add one."); _ly += _lh;
	} else {
		for (var _facIdx = 0; _facIdx < array_length(global.factions); _facIdx++) {
			var _facName = global.factions[_facIdx];
			var _facMembers = get_npcs_by_faction(_facName);
			var _facCount = array_length(_facMembers);

			draw_set_colour(c_text); draw_text(_lx+16, _ly, _facName);
			draw_set_colour(c_muted); draw_text(_lx+250, _ly, string(_facCount) + " NPC" + (_facCount == 1 ? "" : "s"));

			// Buttons right-anchored: View | Rename | Delete (delete hidden for "Unaffiliated")
			var _facBtnX = _lx + _lw - 200;
			ui_btn("gm_fac_view_"   + string(_facIdx), _facBtnX,      _ly-2, _facBtnX+50,   _ly+_lh-2, "View",   c_border, c_amazing);
			ui_btn("gm_fac_rename_" + string(_facIdx), _facBtnX+54,   _ly-2, _facBtnX+126,  _ly+_lh-2, "Rename", c_border, c_highlight);
			if (_facName != "Unaffiliated") {
				ui_btn("gm_fac_del_" + string(_facIdx), _facBtnX+130, _ly-2, _facBtnX+182, _ly+_lh-2, "Delete", c_border, c_failure);
			}
			_ly += _lh + 4;
		}
	}
	return _ly;
}


// ============================================================
// GM TAB 4: CAMPAIGN
// ============================================================
/// @function draw_gm_campaign(lx, ly, lw, lh)
/// @description GM TAB 4: Draws campaign roster with scan/import/export and load-to-party/NPC buttons
function draw_gm_campaign(_lx, _ly, _lw, _lh) {
	draw_set_colour(c_header); draw_text(_lx+8, _ly, "CAMPAIGN ROSTER"); _ly += _lh + 2;
	draw_set_colour(c_muted); draw_text(_lx+8, _ly, "All known character files. Load into Party or NPCs on demand."); _ly += _lh + 4;

	// Action buttons
	var _bw = 100;
	ui_btn("gm_camp_scan", _lx+8, _ly, _lx+8+_bw, _ly+24, "Scan Files", c_border, c_amazing);
	ui_btn("gm_camp_import", _lx+12+_bw, _ly, _lx+12+_bw*2, _ly+24, "Import File", c_border, c_highlight);
	ui_btn("gm_camp_export", _lx+16+_bw*2, _ly, _lx+16+_bw*3, _ly+24, "Export All", c_border, c_good);
	_ly += 30;

	draw_set_colour(c_border); draw_line(_lx+8, _ly, _lx+_lw-8, _ly); _ly += 6;

	// Summary
	draw_set_colour(c_muted);
	draw_text(_lx+8, _ly, "Party: " + string(array_length(global.party)) + "  |  NPCs: " + string(array_length(global.npcs)) + "  |  Roster: " + string(array_length(global.roster)));
	_ly += _lh + 4;

	if (array_length(global.roster) == 0) {
		draw_set_colour(c_muted); draw_text(_lx+16, _ly, "No characters in roster. Click 'Scan Files' to find saved characters."); _ly += _lh;
	} else {
		// Column headers
		draw_set_colour(c_muted);
		draw_text(_lx+16, _ly, "Name"); draw_text(_lx+200, _ly, "File Path"); draw_text(_lx+_lw-180, _ly, "Actions");
		_ly += _lh;
		draw_set_colour(c_border); draw_line(_lx+8, _ly, _lx+_lw-8, _ly); _ly += 4;

		var _camp_gh = display_get_gui_height();
		var _max_vis = max(4, floor((_camp_gh - _ly - 40) / (_lh + 3)));
		var _scroll = obj_game.gm_roster_scroll;
		var _total = array_length(global.roster);

		for (var _vi = 0; _vi < min(_max_vis, _total - _scroll); _vi++) {
			var _rosterIndex = _scroll + _vi;
			var _rosterRef = global.roster[_rosterIndex];

			// Check if already loaded in party or NPCs
			var _in_party = false; var _in_npcs = false;
			for (var _j = 0; _j < array_length(global.party); _j++)
				if (global.party[_j].name == _rosterRef.name) { _in_party = true; break; }
			for (var _j = 0; _j < array_length(global.npcs); _j++)
				if (global.npcs[_j].name == _rosterRef.name) { _in_npcs = true; break; }

			draw_set_colour(c_text); draw_text(_lx+16, _ly, _rosterRef.name);
			draw_set_colour(c_muted); draw_text(_lx+200, _ly, _rosterRef.path);

			// Status indicator
			var _btn_x = _lx + _lw - 180;
			if (_in_party) {
				draw_set_colour(c_good); draw_text(_btn_x, _ly, "[Party]");
			} else if (_in_npcs) {
				draw_set_colour(c_warning); draw_text(_btn_x, _ly, "[NPC]");
			} else {
				ui_btn("gm_r2p_" + string(_rosterIndex), _btn_x, _ly-2, _btn_x+55, _ly+_lh-2, "Party", c_border, c_good);
				ui_btn("gm_r2n_" + string(_rosterIndex), _btn_x+59, _ly-2, _btn_x+110, _ly+_lh-2, "NPC", c_border, c_warning);
			}
			_ly += _lh + 3;
		}

		// Scroll indicators
		if (_scroll > 0) { draw_set_colour(c_muted); draw_text(_lx+_lw-40, _ly, "^ more"); }
		if (_scroll + _max_vis < _total) { draw_set_colour(c_muted); draw_text(_lx+_lw-40, _ly + _lh, "v more"); }
	}

	return _ly;
}


// ============================================================
// PLAYER TAB 9: AURA / LORE
// ============================================================
/// @function draw_tab_aura(lx, ly, lw, lh)
/// @description TAB 9: AURA/LORE — identity fields, temperament/motivation pills, personality, and lifepath
function draw_tab_aura(_lx, _ly, _lw, _lh) {
	var _gh = display_get_gui_height();
	var _loreData = hero[$ "lore"] ?? {};
	var _info_w = _lw - 40;
	var _is_voss = (hero.name == "Sergeant Voss");
	var _editable = !_is_voss;

	// === FIXED-HEIGHT: IDENTITY ===
	draw_set_colour(c_header); draw_text(_lx+8, _ly, hero.name + " — AURA / LORE");
	if (_is_voss) { draw_set_colour(c_muted); draw_text(_lx + string_width(hero.name + " — AURA / LORE") + 16, _ly, "(Template — read only)"); }
	_ly += _lh + 4;

	draw_set_colour(c_header); draw_text(_lx+8, _ly, "IDENTITY"); _ly += _lh;
	var _speciesName = hero[$ "species"] != undefined ? get_species_name(hero.species) : "Human";
	draw_set_colour(c_muted); draw_text(_lx+16, _ly, "Species:"); draw_set_colour(c_text); draw_text(_lx+80, _ly, _speciesName);
	draw_text(_lx+200, _ly, get_profession_name(hero.profession) + " — " + hero.career);
	_ly += _lh;

	// Editable identity fields: gender, height, weight, hair
	var _id_fields = [["gender", "Gender"], ["height", "Height"], ["weight", "Weight"], ["hair", "Hair"]];
	var _idx = 0;
	for (var _fieldIndex = 0; _fieldIndex < 4; _fieldIndex += 2) {
		for (var _col = 0; _col < 2; _col++) {
			var _fieldDef = _id_fields[_fieldIndex + _col];
			var _fieldX = _lx + 16 + _col * floor(_info_w / 2);
			var _val = _loreData[$ _fieldDef[0]] ?? "";
			draw_set_colour(c_muted); draw_text(_fieldX, _ly, _fieldDef[1] + ":");
			draw_set_colour(_val != "" ? c_text : c_muted);
			draw_text(_fieldX + 65, _ly, _val != "" ? _val : "(not set)");
			if (_editable) ui_btn("aura_id_" + _fieldDef[0], _fieldX + _info_w/2 - 45, _ly-2, _fieldX + _info_w/2 - 10, _ly+_lh-2, "Edit", c_border, c_highlight);
		}
		_ly += _lh + 2;
	}
	_ly += 4;

	// === FIXED-HEIGHT: CHARACTER TRAITS ===
	draw_set_colour(c_header); draw_text(_lx+8, _ly, "CHARACTER TRAITS (PHB Step 8)"); _ly += _lh + 2;

	// Moral Attitude
	var _moralAttitude = _loreData[$ "moral_attitude"] ?? "";
	draw_set_colour(c_muted); draw_text(_lx+16, _ly, "Moral Attitude:");
	draw_set_colour(_moralAttitude != "" ? c_good : c_muted); draw_text(_lx+140, _ly, _moralAttitude != "" ? _moralAttitude : "(not set)");
	if (_editable) ui_btn("aura_moral", _lx+_info_w-40, _ly-2, _lx+_info_w, _ly+_lh-2, "Edit", c_border, c_highlight);
	_ly += _lh + 4;

	// Temperament — clickable pill buttons (pick 2-3)
	var _temp_opts = ["Aggressive","Cautious","Competitive","Confident","Curious","Disciplined",
		"Easygoing","Energetic","Friendly","Honest","Humble","Impulsive","Loyal","Moody",
		"Optimistic","Paranoid","Patient","Quiet","Rebellious","Reserved","Sarcastic",
		"Serious","Stubborn","Suspicious","Vengeful"];
	var _sel_temps = _loreData[$ "temperament"] ?? [];
	if (!is_array(_sel_temps)) _sel_temps = [];

	draw_set_colour(c_muted); draw_text(_lx+16, _ly, "Temperament (pick 2-3):");
	// Show selected
	var _temperamentStr = "";
	for (var _tempIndex = 0; _tempIndex < array_length(_sel_temps); _tempIndex++) { if (_tempIndex > 0) _temperamentStr += ", "; _temperamentStr += _sel_temps[_tempIndex]; }
	if (_temperamentStr != "") { draw_set_colour(c_warning); draw_text(_lx+175, _ly, _temperamentStr); }
	_ly += _lh + 2;

	if (_editable) {
		// Draw pill buttons in rows
		var _pillX = _lx + 24; var _pillY = _ly;
		for (var _tempIndex = 0; _tempIndex < array_length(_temp_opts); _tempIndex++) {
			var _traitName = _temp_opts[_tempIndex];
			var _traitWidth = string_width(_traitName) + 10;
			if (_pillX + _traitWidth > _lx + _info_w - 8) { _pillX = _lx + 24; _pillY += _lh + 2; }
			var _isSelected = false;
			for (var _searchIndex = 0; _searchIndex < array_length(_sel_temps); _searchIndex++) if (_sel_temps[_searchIndex] == _traitName) { _isSelected = true; break; }
			var _baseColor = _isSelected ? c_warning : c_border;
			var _hoverColor = _isSelected ? c_warning : c_muted;
			ui_btn("aura_tmp_" + string(_tempIndex), _pillX, _pillY, _pillX+_traitWidth, _pillY+_lh, _traitName, _baseColor, _hoverColor);
			_pillX += _traitWidth + 4;
		}
		_ly = _pillY + _lh + 6;
	} else { _ly += 2; }

	// Motivations — clickable pill buttons (pick 1-2)
	var _mot_opts = ["Achievement","Belonging","Discovery","Fame","Greed","Honor","Justice",
		"Knowledge","Loyalty","Power","Protection","Rebellion","Revenge","Service","Survival","Wealth"];
	var _sel_mots = _loreData[$ "motivations"] ?? [];
	if (!is_array(_sel_mots)) _sel_mots = [];

	draw_set_colour(c_muted); draw_text(_lx+16, _ly, "Motivations (pick 1-2):");
	var _motivationsStr = "";
	for (var _motIndex = 0; _motIndex < array_length(_sel_mots); _motIndex++) { if (_motIndex > 0) _motivationsStr += ", "; _motivationsStr += _sel_mots[_motIndex]; }
	if (_motivationsStr != "") { draw_set_colour(c_amazing); draw_text(_lx+175, _ly, _motivationsStr); }
	_ly += _lh + 2;

	if (_editable) {
		var _pillX = _lx + 24; var _pillY = _ly;
		for (var _motIndex = 0; _motIndex < array_length(_mot_opts); _motIndex++) {
			var _motivName = _mot_opts[_motIndex];
			var _motivWidth = string_width(_motivName) + 10;
			if (_pillX + _motivWidth > _lx + _info_w - 8) { _pillX = _lx + 24; _pillY += _lh + 2; }
			var _isSelected = false;
			for (var _searchIndex = 0; _searchIndex < array_length(_sel_mots); _searchIndex++) if (_sel_mots[_searchIndex] == _motivName) { _isSelected = true; break; }
			var _baseColor = _isSelected ? c_amazing : c_border;
			var _hoverColor = _isSelected ? c_amazing : c_muted;
			ui_btn("aura_mot_" + string(_motIndex), _pillX, _pillY, _pillX+_motivWidth, _pillY+_lh, _motivName, _baseColor, _hoverColor);
			_pillX += _motivWidth + 4;
		}
		_ly = _pillY + _lh + 6;
	} else { _ly += 2; }

	_ly += 4;

	// === SHORT FREEFORM: PERSONALITY ===
	draw_set_colour(c_header); draw_text(_lx+8, _ly, "PERSONALITY");
	if (_editable) ui_btn("aura_pers_edit", _lx+_info_w-40, _ly-2, _lx+_info_w, _ly+_lh-2, "Edit", c_border, c_highlight);
	_ly += _lh;
	var _pers = _loreData[$ "personality"] ?? "";
	if (_pers != "") {
		draw_set_colour(c_text); draw_text_ext(_lx+16, _ly, _pers, -1, _info_w - 24);
		_ly += string_height_ext(_pers, -1, _info_w - 24) + 4;
	} else {
		draw_set_colour(c_muted); draw_text(_lx+16, _ly, _editable ? "(Click Edit to add personality notes)" : "(none)");
		_ly += _lh;
	}
	_ly += 4;

	// === VARIABLE-LENGTH: LIFEPATH (scrollable portion starts here) ===
	draw_set_colour(c_header); draw_text(_lx+8, _ly, "LIFEPATH");
	if (_editable) ui_btn("aura_life_edit", _lx+_info_w-40, _ly-2, _lx+_info_w, _ly+_lh-2, "Edit", c_border, c_highlight);
	_ly += _lh;

	var _lifepathText = _loreData[$ "lifepath"] ?? "";
	if (_lifepathText == "") _lifepathText = hero.background;
	if (_lifepathText != "") {
		var _lines = string_split(_lifepathText, "\n");
		for (var _li = 0; _li < array_length(_lines); _li++) {
			if (_ly > _gh - 20) break;
			var _line = _lines[_li];
			if (_line == "") { _ly += 6; continue; }
			var _is_hdr = (string_upper(_line) == _line && string_length(_line) > 3 && string_length(_line) < 30);
			draw_set_colour(_is_hdr ? c_warning : c_text);
			var _ind = _is_hdr ? 0 : 12;
			draw_text_ext(_lx + 8 + _ind, _ly, _line, -1, _info_w - _ind);
			_ly += string_height_ext(_line, -1, _info_w - _ind);
		}
	} else {
		draw_set_colour(c_muted); draw_text(_lx+16, _ly, _editable ? "(Click Edit to write your character's story)" : "(none)");
		_ly += _lh;
	}

	return _ly;
}


// ============================================================
// GM TAB 4: SESSIONLOG
// ============================================================
/// @function draw_gm_sessionlog(lx, ly, lw, lh)
/// @description GM TAB 4: Persistent session-wide history of every roll and chat.
/// Top: scrollable list of entries (newest first, color-coded by degree).
/// Bottom: chat input that types out to all players (Enter to send).
/// Buttons: Clear (wipes the persistent file), Save Now (forces flush).
function draw_gm_sessionlog(_lx, _ly, _lw, _lh) {
	draw_set_colour(c_header); draw_text(_lx+8, _ly, "SESSIONLOG"); _ly += _lh + 2;
	draw_set_colour(c_muted);
	draw_text(_lx+8, _ly, "Persistent history — every roll and chat across the entire campaign. Saved to disk.");
	_ly += _lh + 2;

	// Action buttons row: Clear, Save, Refresh
	var _bw = 90;
	ui_btn("gm_sl_clear", _lx+8, _ly, _lx+8+_bw, _ly+22, "Clear All", c_border, c_failure);
	ui_btn("gm_sl_save",  _lx+12+_bw, _ly, _lx+12+_bw*2, _ly+22, "Save Now", c_border, c_good);
	ui_btn("gm_sl_top",   _lx+16+_bw*2, _ly, _lx+16+_bw*3, _ly+22, "Jump to Top", c_border, c_amazing);
	draw_set_colour(c_muted);
	draw_text(_lx+16+_bw*3+12, _ly+3, "Total: " + string(array_length(obj_game.session_log_entries)) + " entries");
	_ly += 28;

	draw_set_colour(c_border); draw_line(_lx+8, _ly, _lx+_lw-8, _ly); _ly += 4;

	// Reserve the bottom 60px for the chat input row
	var _chat_area_h = 60;
	var _list_top = _ly;
	var _gh_local = display_get_gui_height();
	var _list_bot = _gh_local - _chat_area_h - 24;
	if (_list_bot < _list_top + 60) _list_bot = _list_top + 60;

	// Compute how many rows fit (each row is 2 lines)
	var _row_h = _lh * 2 + 2;
	var _visible = max(1, floor((_list_bot - _list_top) / _row_h));
	obj_game.session_log_max_visible = _visible;

	// Clamp scroll
	var _entries = obj_game.session_log_entries;
	var _max_scroll = max(0, array_length(_entries) - _visible);
	if (obj_game.session_log_scroll > _max_scroll) obj_game.session_log_scroll = _max_scroll;
	if (obj_game.session_log_scroll < 0) obj_game.session_log_scroll = 0;

	if (array_length(_entries) == 0) {
		draw_set_colour(c_muted); draw_text(_lx+16, _ly+8, "No entries yet. Rolls and chat from this and prior sessions will appear here.");
	} else {
		var _cy = _list_top + 2;
		var _start = obj_game.session_log_scroll;
		var _end = min(array_length(_entries), _start + _visible);
		for (var _ei = _start; _ei < _end; _ei++) {
			var _entry = _entries[_ei];
			var _kind = _entry[$ "kind"] ?? "roll";
			var _ts = _entry[$ "ts_str"] ?? "--:--:--";
			// Time stamp on the left
			draw_set_colour(c_muted); draw_text(_lx+12, _cy, _ts);

			if (_kind == "roll") {
				// Color by degree
				var _deg = _entry[$ "degree"] ?? 0;
				var _dc = c_text;
				switch (_deg) {
					case -1: case 0: _dc = c_failure; break;
					case 1: _dc = c_text; break;
					case 2: _dc = c_good; break;
					case 3: _dc = c_amazing; break;
				}
				var _sender = _entry[$ "sender"] ?? "?";
				var _char = _entry[$ "character"] ?? "";
				var _skill = _entry[$ "skill"] ?? "";
				var _total = _entry[$ "total"] ?? 0;
				var _deg_names = ["FAIL", "MARGINAL", "ORDINARY", "GOOD", "AMAZING"];
				var _dn_idx = clamp(_deg + 1, 0, 4);
				draw_set_colour(c_text);
				var _who = (_char != "" ? _char : _sender);
				draw_text(_lx+90, _cy, _who + " — " + _skill);
				draw_set_colour(_dc);
				draw_text(_lx+_lw-200, _cy, _deg_names[_dn_idx] + " (" + string(_total) + ")");
			} else if (_kind == "chat") {
				var _sender2 = _entry[$ "sender"] ?? "?";
				var _text = _entry[$ "text"] ?? "";
				var _is_w = _entry[$ "is_whisper"] ?? false;
				var _w_to = _entry[$ "whisper_to"] ?? "";
				draw_set_colour(_is_w ? c_warning : c_amazing);
				var _prefix = _is_w ? ("[whisper " + _sender2 + " -> " + _w_to + "] ") : (_sender2 + ": ");
				draw_text(_lx+90, _cy, _prefix);
				draw_set_colour(c_text);
				draw_text_ext(_lx+90, _cy + _lh, _text, -1, _lw - 100);
			}
			_cy += _row_h;
		}

		// Scrollbar hint
		if (_max_scroll > 0) {
			draw_set_colour(c_muted);
			draw_text(_lx+_lw-100, _list_top, string(_start+1) + "-" + string(_end) + "/" + string(array_length(_entries)));
		}
	}

	// ---- Chat input row at the bottom of the tab ----
	var _chat_y = _list_bot + 6;
	draw_set_colour(c_muted); draw_text(_lx+8, _chat_y, "GM Chat (Enter to send, /name for whisper, /gm to GM):");
	_chat_y += _lh + 2;
	var _focused = (obj_game.net_input_focus == "session_chat");
	draw_set_colour(_focused ? c_highlight : c_border);
	draw_rectangle(_lx+8, _chat_y, _lx+_lw-110, _chat_y+22, true);
	var _disp = obj_game.session_log_chat_buffer;
	if (_disp == "") _disp = _focused ? "Type message..." : "Click to type";
	if (_focused && (current_time mod 1000 < 500) && obj_game.session_log_chat_buffer != "") _disp = obj_game.session_log_chat_buffer + "_";
	draw_set_colour(_focused ? c_text : c_muted);
	draw_text(_lx+12, _chat_y+3, _disp);
	btn.gm_sl_chat_field = [_lx+8, _chat_y, _lx+_lw-110, _chat_y+22];
	ui_btn("gm_sl_chat_send", _lx+_lw-100, _chat_y, _lx+_lw-8, _chat_y+22, "Send", c_border, c_good);

	return _chat_y + 26;
}


// ============================================================
// GM TAB 5: RESOURCES
// ============================================================
/// @function draw_gm_resources(lx, ly, lw, lh)
/// @description GM TAB 5: Draws scrollable GM customization guide for JSON data files
function draw_gm_resources(_lx, _ly, _lw, _lh) {
	var _blocks = [];
	var _totalHeight = build_gm_resource_blocks(_blocks, _lh, _lw - 40);
	return draw_scrollable_info_blocks(_lx, _ly, _lw, _lh, _blocks, _totalHeight, "gm_roster_scroll");
}
