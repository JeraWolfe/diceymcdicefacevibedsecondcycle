/// @description Alternity Dice System
/// Reads die step config from global.config.dice.steps
/// PHB scale: -d20 -d12 -d8 -d6 -d4 +d0 +d4 +d6 +d8 +d12 +d20 +2d20 +3d20 +4d20

#macro SIT_STEP_MIN  0
#macro SIT_STEP_BASE 5
#macro SIT_STEP_MAX  13

/// @function get_step(index) → step config struct { sides, count, bonus, name }
function get_step(_step) {
	_step = clamp(_step, 0, array_length(global.config.dice.steps) - 1);
	return global.config.dice.steps[_step];
}

// situation_die_sides() REMOVED — no callsites
// situation_step_is_bonus() REMOVED — inlined into alternity_check

/// @function situation_step_name(step) → display string like "+d8" or "+2d20"
function situation_step_name(_step) { return get_step(_step).name; }

/// @function roll_die(sides) → 1..sides, or 0 if sides <= 0
function roll_die(_sides) { return (_sides > 0) ? irandom_range(1, _sides) : 0; }

/// @function roll_situation(step) → total situation die roll (handles multi-die: +2d20 etc.)
function roll_situation(_step) {
	var _s = get_step(_step);
	var _total = 0;
	var _count = _s[$ "count"] ?? 1;
	for (var _i = 0; _i < _count; _i++) _total += roll_die(_s.sides);
	return _total;
}

/// @function alternity_check(score_ord, score_good, score_amz, situation_step)
/// @description THE core dice check. d20 control + situation die. Lower is better.
function alternity_check(_score_ord, _score_good, _score_amz, _situation_step) {
	var _control = roll_die(20);
	var _sit = roll_situation(_situation_step);
	var _total = max(1, get_step(_situation_step).bonus ? _control - _sit : _control + _sit);
	var _crit = (_control == 20);

	var _degree = _crit ? -1 : (_total > _score_ord ? 0 : (_total > _score_good ? 1 : (_total > _score_amz ? 2 : 3)));
	var _names = ["FAILURE", "ORDINARY", "GOOD", "AMAZING"];
	var _dname = _crit ? "CRITICAL FAILURE" : _names[_degree];

	return {
		control_roll: _control, situation_roll: _sit, situation_step: _situation_step,
		total: _total, degree: _degree, degree_name: _dname, is_critical_failure: _crit
	};
}

/// @function alternity_action_check(ac_ord, ac_good, ac_amz, situation_step)
/// @description Action check — failures become MARGINAL (degree 0)
function alternity_action_check(_ac_ord, _ac_good, _ac_amz, _situation_step) {
	var _r = alternity_check(_ac_ord, _ac_good, _ac_amz, _situation_step);
	if (_r.degree <= 0) { _r.degree = 0; _r.degree_name = "MARGINAL"; _r.is_critical_failure = false; }
	return _r;
}

// ============================================================
// FREE-FORM DICE EXPRESSIONS — for the GM dice roller panel.
// ============================================================
//
// Supported syntax: NdX±M xR
//   N  = number of dice (default 1)
//   X  = sides per die (required, must be > 0)
//   ±M = flat modifier added to total (optional, signed integer)
//   xR = repeat the whole roll R times (optional)
//
// Examples:
//   "1d20"        → roll 1d20
//   "2d6-2"       → roll 2d6, subtract 2 (Alternity control die "marginal good")
//   "1d8"         → roll 1d8
//   "2d4-1"       → roll 2d4, subtract 1
//   "1d20+5"      → roll 1d20, add 5
//   "1d20-4x3"    → roll (1d20-4) three times
//   "3d6x6"       → roll 3d6 six times (classic stat block)
//
// Returns a struct: {
//   ok: bool,                  // false on parse error
//   error: string,             // populated when ok=false
//   expr: string,              // normalized expression
//   results: [int, ...],       // one entry per repeat
//   rolls:   [[int,...], ...], // raw die rolls per repeat
//   modifier: int,             // the ±M part (0 if absent)
//   repeats: int,              // R (1 if absent)
//   total_sum: int             // sum of all results (handy for stat rolls)
// }
// ============================================================
function parse_dice_expression(_str) {
	var _result = {
		ok: false, error: "", expr: "",
		results: [], rolls: [], modifier: 0, repeats: 1, total_sum: 0
	};
	if (_str == undefined || _str == "") {
		_result.error = "Empty expression";
		return _result;
	}
	// Strip whitespace and lowercase
	var _clean = "";
	for (var _ci = 1; _ci <= string_length(_str); _ci++) {
		var _ch = string_char_at(_str, _ci);
		if (_ch != " " && _ch != "\t") _clean += string_lower(_ch);
	}
	if (_clean == "") { _result.error = "Empty expression"; return _result; }
	_result.expr = _clean;

	// Split off the repeat suffix "xR" if present
	var _repeats = 1;
	var _x_pos = string_pos("x", _clean);
	if (_x_pos > 0) {
		var _r_str = string_copy(_clean, _x_pos + 1, string_length(_clean) - _x_pos);
		_clean = string_copy(_clean, 1, _x_pos - 1);
		var _r_val = real_or_zero(_r_str);
		if (_r_val < 1 || _r_val > 100) { _result.error = "Repeat must be 1-100"; return _result; }
		_repeats = floor(_r_val);
	}
	_result.repeats = _repeats;

	// Locate 'd' (the only required character)
	var _d_pos = string_pos("d", _clean);
	if (_d_pos == 0) { _result.error = "Missing 'd' (e.g. 1d20)"; return _result; }

	// Number of dice (left of 'd', default 1 if blank)
	var _n_str = string_copy(_clean, 1, _d_pos - 1);
	var _num_dice = (_n_str == "") ? 1 : floor(real_or_zero(_n_str));
	if (_num_dice < 1 || _num_dice > 100) { _result.error = "Dice count must be 1-100"; return _result; }

	// Right of 'd' is sides[±modifier]
	var _rest = string_copy(_clean, _d_pos + 1, string_length(_clean) - _d_pos);
	if (_rest == "") { _result.error = "Missing die sides"; return _result; }

	// Find the modifier sign if any (must be after the sides number)
	var _sides_str = _rest;
	var _mod = 0;
	var _plus_pos = string_pos("+", _rest);
	var _minus_pos = string_pos("-", _rest);
	var _sign_pos = 0;
	if (_plus_pos > 0 && (_minus_pos == 0 || _plus_pos < _minus_pos)) _sign_pos = _plus_pos;
	else if (_minus_pos > 0) _sign_pos = _minus_pos;
	if (_sign_pos > 0) {
		_sides_str = string_copy(_rest, 1, _sign_pos - 1);
		var _mod_str = string_copy(_rest, _sign_pos, string_length(_rest) - _sign_pos + 1);
		_mod = floor(real_or_zero(_mod_str));
	}
	var _sides = floor(real_or_zero(_sides_str));
	if (_sides < 1 || _sides > 1000) { _result.error = "Die sides must be 1-1000"; return _result; }
	_result.modifier = _mod;

	// Roll
	for (var _ri = 0; _ri < _repeats; _ri++) {
		var _rolls_one = [];
		var _sum = 0;
		for (var _di = 0; _di < _num_dice; _di++) {
			var _v = irandom_range(1, _sides);
			array_push(_rolls_one, _v);
			_sum += _v;
		}
		var _total = _sum + _mod;
		array_push(_result.rolls, _rolls_one);
		array_push(_result.results, _total);
		_result.total_sum += _total;
	}
	_result.ok = true;
	return _result;
}

/// @function real_or_zero(str)
/// @description Safe string→real that returns 0 on failure instead of throwing.
function real_or_zero(_s) {
	if (_s == "" || _s == undefined) return 0;
	try { return real(_s); } catch (_e) { return 0; }
}

/// @function gm_run_dice_expression(expr)
/// @description Parse + roll a free-form dice expression. On success, store
/// the result struct on obj_game.gm_dice_last_result, push a chat-style entry
/// into the party stream, and broadcast to the session as a chat line so all
/// players see "[GM rolls 1d20-4x3]: 12, 7, 18".
function gm_run_dice_expression(_expr) {
	var _r = parse_dice_expression(_expr);
	obj_game.gm_dice_last_result = _r;
	if (!_r.ok) return _r;

	// Build the display line: "1d20-4 x3 => 12, 7, 18"
	var _line = _r.expr + " => ";
	for (var _i = 0; _i < array_length(_r.results); _i++) {
		if (_i > 0) _line += ", ";
		_line += string(_r.results[_i]);
	}
	var _full = "[GM dice] " + _line;

	// Local stream entry so the GM sees it immediately
	var _entry = {
		sender_name: variable_instance_exists(obj_game, "net_player_name") ? (obj_game.net_player_name == "" ? "GM" : obj_game.net_player_name) : "GM",
		character_name: "",
		skill_name: "",
		degree_name: "",
		degree: 0,
		total: _r.total_sum,
		mod_str: "",
		modifiers: [],
		is_remote: false,
		is_chat: true,
		chat_text: _full,
		timestamp: current_time
	};
	array_insert(obj_game.rolllog_entries, 0, _entry);
	if (array_length(obj_game.rolllog_entries) > obj_game.max_log_entries) array_pop(obj_game.rolllog_entries);

	// Broadcast as chat so all players see the GM's roll inline.
	if (variable_instance_exists(obj_game, "net_connected") && obj_game.net_connected) {
		net_send_chat(_full);
	}
	return _r;
}
