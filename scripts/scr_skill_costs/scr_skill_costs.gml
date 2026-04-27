/// @description Skill Cost System — PHB Two-Tier Model
///
/// Per Alternity PHB (p.34-36, 62):
///   Two categories: PROFESSION (your code listed) or OTHER (not listed)
///   Broad skill: Profession = 3 pts, Other = 4 pts
///   Specialty rank N (upgrading from N-1): base + (N-1)
///     Profession base = 1:  rank 1→1, rank 2→2, rank 3→3  (total: 1, 3, 6)
///     Other base = 2:       rank 1→2, rank 2→3, rank 3→4  (total: 2, 5, 9)

/// @function get_profession_skill_list(profession)
/// @description Returns array of broad skill names that have this profession's code
function get_profession_skill_list(_prof) {
	if (_prof >= 0 && _prof < array_length(global.professions)) {
		return global.professions[_prof].signature_skills;
	}
	return [];
}

/// @function is_profession_skill(profession, broad_name) → bool
function is_profession_skill(_prof, _broad_name) {
	var _list = get_profession_skill_list(_prof);
	for (var _i = 0; _i < array_length(_list); _i++) {
		if (_list[_i] == _broad_name) return true;
	}
	return false;
}

/// @function is_profession_skill_hero(statblock, broad_name) → bool
/// @description Checks both primary and secondary (diplomat) profession
function is_profession_skill_hero(_stat, _broad_name) {
	if (is_profession_skill(_stat.profession, _broad_name)) return true;
	if (_stat[$ "secondary_profession"] != undefined && _stat.secondary_profession >= 0) {
		if (is_profession_skill(_stat.secondary_profession, _broad_name)) return true;
	}
	return false;
}

// -- Cost Functions --

/// @function get_broad_cost_for_hero(statblock, broad_name)
function get_broad_cost_for_hero(_stat, _broad_name) {
	return is_profession_skill_hero(_stat, _broad_name) ? 3 : 4;
}

/// @function get_spec_base_for_hero(statblock, broad_name)
function get_spec_base_for_hero(_stat, _broad_name) {
	return is_profession_skill_hero(_stat, _broad_name) ? 1 : 2;
}

/// @function get_spec_rank_cost(base, current_rank)
/// @description Cost to upgrade FROM current_rank TO current_rank+1
function get_spec_rank_cost(_base, _current_rank) {
	return _base + _current_rank;
}

/// @function get_spec_total_cost(base, rank)
/// @description Total points spent on a specialty at given rank
///   Sum of (base + i) for i = 0 to rank-1
///   = rank * base + rank*(rank-1)/2
function get_spec_total_cost(_base, _rank) {
	if (_rank <= 0) return 0;
	return _rank * _base + (_rank * (_rank - 1)) div 2;
}

/// @function get_single_skill_cost_hero(statblock, skill)
function get_single_skill_cost_hero(_stat, _sk) {
	if (_sk.specialty == "") {
		return get_broad_cost_for_hero(_stat, _sk.broad_skill);
	} else {
		return get_spec_total_cost(get_spec_base_for_hero(_stat, _sk.broad_skill), _sk.rank);
	}
}

/// @function get_total_skill_cost_hero(statblock)
function get_total_skill_cost_hero(_stat) {
	var _total = 0;
	for (var _i = 0; _i < array_length(_stat.skills); _i++)
		_total += get_single_skill_cost_hero(_stat, _stat.skills[_i]);
	return _total;
}

/// @function get_starting_skill_points(profession)
function get_starting_skill_points(_prof) {
	if (_prof >= 0 && _prof < array_length(global.professions))
		return global.professions[_prof].starting_skill_points;
	return 40;
}

// get_category_tag_hero() REMOVED — inline is_profession_skill_hero(stat, broad) ? "P" : "-"
// get_skill_category() REMOVED — redundant with is_profession_skill
// get_broad_cost_per_rank() REMOVED — redundant
// get_spec_cost_per_rank() REMOVED — redundant
// get_category_short_hero() REMOVED — wrapper chain

// -- Perks & Flaws cost --

/// @function get_perks_cost(statblock) → total skill points spent on perks
function get_perks_cost(_stat) {
	var _total = 0;
	for (var _i = 0; _i < array_length(_stat.fx); _i++) {
		if (_stat.fx[_i].type != "perk") continue;
		var _fxd = get_fx_data(_stat.fx[_i].name);
		if (_fxd == undefined) continue;
		var _base_cost = _fxd[$ "cost"] ?? 0;
		var _quality = _stat.fx[_i][$ "quality"] ?? "";
		// Quality-scaled cost: count tiers (O=1, G=2, A=3)
		if (_quality != "" && _fxd[$ "quality_scale"] != undefined && is_struct(_fxd.quality_scale)) {
			var _tier = (_quality == "A") ? 3 : ((_quality == "G") ? 2 : 1);
			_total += _base_cost * _tier;
		} else {
			_total += _base_cost;
		}
	}
	return _total;
}

/// @function get_flaws_benefit(statblock) → total skill points gained from flaws
function get_flaws_benefit(_stat) {
	var _total = 0;
	for (var _i = 0; _i < array_length(_stat.fx); _i++) {
		if (_stat.fx[_i].type != "flaw") continue;
		var _fxd = get_fx_data(_stat.fx[_i].name);
		// FX database stores flaw cost as negative (e.g., -2), benefit = abs(cost)
		if (_fxd != undefined) _total += abs(_fxd[$ "cost"] ?? 0);
	}
	return _total;
}

/// @function get_racial_skill_point_bonus(statblock) → bonus points from active racial fx
/// @description Walks hero.fx for active type=="racial" entries and sums any
/// `bonus_skill_points` field. This is how the "Versatile Human +5" trait realizes
/// its mechanical effect — and how any future race-grants-bonus-points trait will too.
function get_racial_skill_point_bonus(_stat) {
	var _bonus = 0;
	if (_stat[$ "fx"] == undefined) return 0;
	for (var _i = 0; _i < array_length(_stat.fx); _i++) {
		var _e = _stat.fx[_i];
		if (_e.type != "racial") continue;
		if (!(_e[$ "active"] ?? true)) continue;
		var _fxd = get_fx_data(_e.name);
		if (_fxd != undefined) _bonus += (_fxd[$ "bonus_skill_points"] ?? 0);
	}
	return _bonus;
}

/// @function get_adjusted_skill_points(statblock) → starting points adjusted for INT, racial bonuses, perks/flaws
/// @description v0.61.0 formula: base profession points + INT bonus (max 0, INT-9)
/// + racial bonus (Versatile Human +5) + legacy_skill_point_grant (back-compat)
/// - perk costs + flaw benefits. INT 9 = no bonus, INT 10 = +1, INT 14 = +5.
function get_adjusted_skill_points(_stat) {
	var _base       = get_starting_skill_points(_stat.profession);
	var _int_score  = (_stat[$ "int_"] != undefined && _stat.int_[$ "score"] != undefined) ? _stat.int_.score : 9;
	var _int_bonus  = max(0, _int_score - 9);
	var _racial     = get_racial_skill_point_bonus(_stat);
	var _legacy     = _stat[$ "legacy_skill_point_grant"] ?? 0;
	return _base + _int_bonus + _racial + _legacy
	     - get_perks_cost(_stat) + get_flaws_benefit(_stat);
}

/// @function is_chargen_legal(statblock) → bool
/// @description Returns true if the character can legally afford their starting skills,
/// meets profession ability minimums, and has no other validation errors. Used by the
/// chargen wizard to verify generation results before saving.
function is_chargen_legal(_stat) {
	if (_stat == undefined) return false;
	var _spent = get_total_skill_cost_hero(_stat);
	var _budget = get_adjusted_skill_points(_stat);
	if (_spent > _budget) return false;
	if (script_exists(asset_get_index("get_profession_requirements"))) {
		var _reqs = get_profession_requirements(_stat.profession);
		if (get_ability_score_for_skill(_stat, global.ability_keys[_reqs.ab1]) < _reqs.ab1_min) return false;
		if (get_ability_score_for_skill(_stat, global.ability_keys[_reqs.ab2]) < _reqs.ab2_min) return false;
	}
	return true;
}

/// @function find_fx(statblock, name, type, active_only) → fx entry or undefined
/// @description ONE generic FX lookup. All hero_has_* and get_hero_fx are thin wrappers.
function find_fx(_stat, _name, _type, _active_only) {
	for (var _i = 0; _i < array_length(_stat.fx); _i++) {
		var _e = _stat.fx[_i];
		if (_e.name != _name) continue;
		if (_type != "" && _e.type != _type) continue;
		if (_active_only && !(_e[$ "active"] ?? true)) continue;
		return _e;
	}
	return undefined;
}

/// @function has_fx(stat, name, [type], [active_only])
/// @description Unified FX check. Returns true if hero has matching FX entry.
///   type: "perk"/"flaw"/"cybertech"/"" (empty = any type). Default "".
///   active_only: true = skip inactive FX. Default true.
function has_fx(_stat, _name, _type, _active_only) {
	if (_type == undefined) _type = "";
	if (_active_only == undefined) _active_only = true;
	return find_fx(_stat, _name, _type, _active_only) != undefined;
}

/// @function add_perk(statblock, perk_name) → true if added/upgraded
function add_perk_to_hero(_stat, _name) {
	var _fxd = get_fx_data(_name);

	// Determine available quality tiers from quality_scale keys
	var _tiers = [""];  // default: single-tier (no quality)
	if (_fxd != undefined && _fxd[$ "quality_scale"] != undefined && is_struct(_fxd.quality_scale)) {
		var _qs = _fxd.quality_scale;
		_tiers = [];
		if (_qs[$ "O"] != undefined) array_push(_tiers, "O");
		if (_qs[$ "G"] != undefined) array_push(_tiers, "G");
		if (_qs[$ "A"] != undefined) array_push(_tiers, "A");
	}

	// Check if already owned
	for (var _i = 0; _i < array_length(_stat.fx); _i++) {
		if (_stat.fx[_i].name == _name && _stat.fx[_i].type == "perk") {
			// Already owned — try to upgrade quality tier
			var _cur_q = _stat.fx[_i][$ "quality"] ?? "";
			if (array_length(_tiers) <= 1) return false;  // single-tier, can't upgrade
			// Find next tier
			var _cur_idx = -1;
			for (var _t = 0; _t < array_length(_tiers); _t++) {
				if (_tiers[_t] == _cur_q) { _cur_idx = _t; break; }
			}
			if (_cur_idx < 0) { _stat.fx[_i].quality = _tiers[0]; return true; }  // wasn't on a tier yet
			if (_cur_idx >= array_length(_tiers) - 1) return false;  // already max tier
			_stat.fx[_i].quality = _tiers[_cur_idx + 1];
			return true;
		}
	}

	// Not owned — add with first tier quality
	var _init_q = (array_length(_tiers) > 0) ? _tiers[0] : "";
	array_push(_stat.fx, { name: _name, type: "perk", quality: _init_q, active: true });
	return true;
}

/// @function remove_perk(statblock, perk_name)
function remove_perk_from_hero(_stat, _name) {
	for (var _i = array_length(_stat.fx)-1; _i >= 0; _i--) {
		if (_stat.fx[_i].name == _name && _stat.fx[_i].type == "perk") { array_delete(_stat.fx, _i, 1); return; }
	}
}

/// @function toggle_flaw(statblock, flaw_name)
function toggle_flaw_on_hero(_stat, _name) {
	// Check if already has it via fx
	for (var _i = array_length(_stat.fx)-1; _i >= 0; _i--) {
		if (_stat.fx[_i].name == _name && _stat.fx[_i].type == "flaw") { array_delete(_stat.fx, _i, 1); return; }
	}
	// Add it
	array_push(_stat.fx, { name: _name, type: "flaw", quality: "", active: true });
}

// -- Cybertech helpers --

/// @function get_cyber_tolerance(statblock)
/// @description Returns max cyber tolerance. CON + mechalus bonus + perk bonus.
function get_cyber_tolerance(_stat) {
	var _tol = _stat.con.score;
	// Mechalus: +4
	if (_stat[$ "species"] != undefined && _stat.species == SPECIES.MECHALUS)
		_tol += 4;
	// Cyber Tolerance perk: +2 if owned
	if (has_fx(_stat, "Cyber Tolerance", "perk", false))
		_tol += 2;
	return _tol;
}

/// @function get_cyber_used(statblock)
/// @description Returns total cyber size installed (reads from fx array)
function get_cyber_used(_stat) {
	var _total = 0;
	for (var _i = 0; _i < array_length(_stat.fx); _i++) {
		if (_stat.fx[_i].type != "cybertech") continue;
		var _fxd = get_fx_data(_stat.fx[_i].name);
		if (_fxd != undefined) _total += _fxd[$ "size"] ?? 0;
	}
	return _total;
}

// All hero_has_* wrappers consolidated into has_fx() above

/// @function add_cybertech_to_hero(statblock, name, quality)
/// @description Adds cyberware via fx array. Auto-adds prereqs. Returns true if added.
function add_cybertech_to_hero(_stat, _name, _quality) {
	if (has_fx(_stat, _name, "cybertech", false)) return false;
	// Find gear data from fx_database
	var _fxd = get_fx_data(_name);
	if (_fxd == undefined) return false;
	// Auto-add prerequisites
	var _prereqs = _fxd[$ "prereqs"] ?? [];
	for (var _p = 0; _p < array_length(_prereqs); _p++) {
		if (!has_fx(_stat, _prereqs[_p], "cybertech", false))
			add_cybertech_to_hero(_stat, _prereqs[_p], "O");
	}
	// Check tolerance
	var _size = _fxd[$ "size"] ?? 0;
	var _tol = get_cyber_tolerance(_stat);
	var _used = get_cyber_used(_stat);
	if (_used + _size > _tol) return false;
	// Add to fx array
	array_push(_stat.fx, { name: _name, type: "cybertech", quality: _quality, active: true });
	return true;
}

/// @function remove_cybertech_from_hero(statblock, name)
/// @description Removes cyberware from fx array. Won't remove if it's a prereq for something else.
function remove_cybertech_from_hero(_stat, _name) {
	// Check if anything depends on this
	for (var _i = 0; _i < array_length(_stat.fx); _i++) {
		if (_stat.fx[_i].type != "cybertech" || _stat.fx[_i].name == _name) continue;
		var _fxd = get_fx_data(_stat.fx[_i].name);
		if (_fxd != undefined && _fxd[$ "prereqs"] != undefined) {
			for (var _p = 0; _p < array_length(_fxd.prereqs); _p++) {
				if (_fxd.prereqs[_p] == _name) return false;
			}
		}
	}
	// Safe to remove
	for (var _i = array_length(_stat.fx)-1; _i >= 0; _i--) {
		if (_stat.fx[_i].name == _name && _stat.fx[_i].type == "cybertech") { array_delete(_stat.fx, _i, 1); return true; }
	}
	return false;
}

// -- Ability score helper --

function get_ability_score_for_skill(_stat, _ability) {
	switch (_ability) {
		case "str": return _stat.str.score; case "dex": return _stat.dex.score;
		case "con": return _stat.con.score; case "int": return _stat.int_.score;
		case "wil": return _stat.wil.score; case "per": return _stat.per.score;
	}
	return 10;
}

// -- Skill score recalculation --

function recalc_skill_scores(_stat) {
	for (var _i = 0; _i < array_length(_stat.skills); _i++) {
		var _sk = _stat.skills[_i];
		var _ab_score = get_ability_score_for_skill(_stat, _sk.ability);
		if (_sk.specialty == "") {
			var _base = (_sk.rank <= 0) ? (_ab_score div 2) : (_ab_score + (_sk.rank - 1));
		} else {
			var _bi = get_broad_skill_scores(_stat, _sk.broad_skill);
			var _bo = (_bi != undefined) ? _bi.ordinary : (_ab_score div 2);
			var _base = _bo + _sk.rank;
		}
		_sk.score_ordinary = _base;
		_sk.score_good = _base div 2;
		_sk.score_amazing = _base div 4;
	}
}

// -- Skill rank manipulation --

function increase_skill_rank(_stat, _idx) {
	if (_idx < 0 || _idx >= array_length(_stat.skills)) return 0;
	var _sk = _stat.skills[_idx];
	if (_sk.specialty == "") return 0; // broads don't rank up
	if (_sk.rank >= 3) return 0;
	var _base = get_spec_base_for_hero(_stat, _sk.broad_skill);
	var _cost = get_spec_rank_cost(_base, _sk.rank); // cost to go from current to current+1
	_sk.rank++;
	recalc_skill_scores(_stat);
	return _cost;
}

function decrease_skill_rank(_stat, _idx) {
	if (_idx < 0 || _idx >= array_length(_stat.skills)) return 0;
	var _sk = _stat.skills[_idx];
	if (_sk.specialty == "") {
		// Broad skill: pressing - removes the entire broad + all its specialties
		var _bn = _sk.broad_skill;
		for (var _j = array_length(_stat.skills)-1; _j >= 0; _j--) {
			if (_stat.skills[_j].broad_skill == _bn) array_delete(_stat.skills, _j, 1);
		}
		return 0;
	} else {
		if (_sk.rank <= 0) { array_delete(_stat.skills, _idx, 1); return 0; }
		var _base = get_spec_base_for_hero(_stat, _sk.broad_skill);
		var _cost = get_spec_rank_cost(_base, _sk.rank - 1);
		_sk.rank--;
		recalc_skill_scores(_stat);
		return _cost;
	}
}

function add_broad_skill_to_hero(_stat, _broad_name) {
	if (find_skill(_stat, _broad_name, "") >= 0) return false;
	var _tree = global.skill_tree;
	var _ability = "str";
	for (var _i = 0; _i < array_length(_tree); _i++) {
		if (_tree[_i].broad == _broad_name) { _ability = _tree[_i].ability; break; }
	}
	var _ab = get_ability_score_for_skill(_stat, _ability);
	// Broad skills have NO rank (specialties get ranked); pass rank=0 to keep
	// data consistent with increase_skill_rank()'s "broads don't rank up" guard.
	add_skill(_stat, _ability, _broad_name, "", 0, _ab, _ab div 2, _ab div 4);
	return true;
}
