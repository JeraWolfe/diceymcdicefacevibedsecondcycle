/// @description Central Data Loader
/// All game data lives in JSON files that ship with the game.
/// Loaded once at startup via read_json(). No fallback generators.
///
/// JSON FILES (datafiles/ — included with build):
///   config.json          - UI colors, dice steps, layout, misc settings
///   professions.json     - Profession mechanics (names, requirements, bonuses, skill lists)
///   skills.json          - Skill tree (broad skills + specialties)
///   species.json         - Playable species (mods, starting skills, traits)
///   careers.json         - Career packages by profession (skills + equipment)
///   names.json           - Random name generation lists
///   fx_database.json     - Unified FX entries (perks, flaws, cybertech)
///   keyword_tree.json    - Master keyword→ability→category mapping
///   tables/skill_rank_benefits.json - PHB rank benefit tables
///   tables/combat_tables.json       - Combat reference tables
///   tables/gm_tables.json           - GM reference tables
///
/// USER-WRITABLE FILES (save directory — created on first run):
///   changelog.json         - Development changelog (load_or_create)
///   recent_characters.json - Recent character list (load_or_create)
///
/// GLOBALS SET:
///   global.config       - Parsed config struct
///   global.professions  - Array of profession structs (indexed by PROFESSION enum)
///   global.skill_tree   - Array of { ability, broad, specialties[] }
///   global.species_data - Array of { name, mods[], starting_broads[], traits }
///   global.career_data  - Array of arrays (indexed by profession), each = [career structs]
///   global.names        - Struct { first_names[], last_names[] }
///   global.fx_database  - Array of FX entry structs
///   global.fx_lookup    - Struct mapping FX name → index
///   global.keyword_tree - Master keyword mapping struct

// ============================================================
// JSON HELPERS
// ============================================================

/// @function read_json(path)
/// @description Reads a JSON file from disk and returns the parsed struct/array, or undefined if missing.
function read_json(_path) {
	if (!file_exists(_path)) return undefined;
	var _contents = "";
	var _fileHandle = file_text_open_read(_path);
	while (!file_text_eof(_fileHandle)) _contents += file_text_readln(_fileHandle);
	file_text_close(_fileHandle);
	return json_parse(_contents);
}

/// @function reload_changelog()
/// @description Read changelog.json into global.changelog. Self-heals against the
/// stale-cache problem: if the file we get back has fewer than CHANGELOG_MIN_EXPECTED
/// entries, we delete the working_directory copy and re-read, forcing GameMaker to
/// re-extract the bundled included file from the asset bundle. The bundled
/// datafiles/changelog.json is the source of truth.
function reload_changelog() {
	var _CHANGELOG_MIN_EXPECTED = 100; // bump this whenever bundled crosses a new floor

	var _cl = read_json("changelog.json");
	var _n  = (_cl != undefined && _cl[$ "entries"] != undefined) ? array_length(_cl.entries) : 0;

	// If the loaded count looks truncated, the working_directory cache is
	// probably stale. Nuke it and re-read so GameMaker falls back to the
	// included-file copy from the asset bundle.
	if (_n < _CHANGELOG_MIN_EXPECTED) {
		var _wdpath = working_directory + "changelog.json";
		if (file_exists(_wdpath)) {
			show_debug_message("[changelog] only " + string(_n) + " entries on disk (< " + string(_CHANGELOG_MIN_EXPECTED) + ") — deleting working_directory cache to force re-extract from bundle");
			file_delete(_wdpath);
			var _fresh = read_json("changelog.json");
			var _fresh_n = (_fresh != undefined && _fresh[$ "entries"] != undefined) ? array_length(_fresh.entries) : 0;
			if (_fresh_n > _n) {
				_cl = _fresh;
				_n = _fresh_n;
				show_debug_message("[changelog] re-read after cache delete — now " + string(_fresh_n) + " entries");
			}
		}
	}

	if (_cl == undefined || _cl[$ "entries"] == undefined || array_length(_cl.entries) == 0) {
		_cl = { _description: "Development changelog. Manually maintained. Newest first.", project: "Dicey McD*ceface - Alternity Edition", entries: [] };
		show_debug_message("[changelog] empty / fallback");
	} else {
		show_debug_message("[changelog] loaded — latest: v" + string(_cl.entries[0].version) + " (" + string(array_length(_cl.entries)) + " entries)");
	}
	global.changelog = _cl;
}

/// @function write_json(path, data)
/// @description Writes a struct/array to disk as pretty-printed JSON.
function write_json(_path, _data) {
	var _fileHandle = file_text_open_write(_path);
	file_text_write_string(_fileHandle, json_stringify(_data, true));
	file_text_close(_fileHandle);
}

/// @function load_or_create(path, default_func)
/// @description Loads JSON from path; if missing, calls default_func to generate data, writes it, and returns it.
function load_or_create(_path, _default_func) {
	var _data = read_json(_path);
	if (_data == undefined) {
		_data = _default_func();
		write_json(_path, _data);
	}
	return _data;
}

// ============================================================
// COLOR HELPERS
// ============================================================

// hex_char_val() and hex2_to_int() REMOVED — inlined into parse_hex_color

/// @function parse_hex_color(hex)
/// @description Converts a "#rrggbb" hex string to a GML color value.
function parse_hex_color(_hex) {
	if (string_char_at(_hex, 1) == "#") _hex = string_delete(_hex, 1, 1);
	// Inline hex pair → int conversion
	var _hexChars = "0123456789abcdef";
	var _rh = string_lower(string_copy(_hex, 1, 2));
	var _gh = string_lower(string_copy(_hex, 3, 2));
	var _bh = string_lower(string_copy(_hex, 5, 2));
	var _red = (string_pos(string_char_at(_rh, 1), _hexChars) - 1) * 16 + (string_pos(string_char_at(_rh, 2), _hexChars) - 1);
	var _green = (string_pos(string_char_at(_gh, 1), _hexChars) - 1) * 16 + (string_pos(string_char_at(_gh, 2), _hexChars) - 1);
	var _blue = (string_pos(string_char_at(_bh, 1), _hexChars) - 1) * 16 + (string_pos(string_char_at(_bh, 2), _hexChars) - 1);
	return make_colour_rgb(_red, _green, _blue);
}

// color_to_hex() REMOVED — never called

/// @function ability_name_to_index(name)
/// @description Maps an ability abbreviation ("STR", "DEX", etc.) to its index (0-5).
function ability_name_to_index(_name) {
	var _map = { STR: 0, DEX: 1, CON: 2, INT: 3, WIL: 4, PER: 5 };
	return _map[$ string_upper(_name)] ?? 0;
}

// ============================================================
// MASTER INIT - call this once at game start
// ============================================================

/// @function init_all_data()
/// @description Master initialization: loads all JSON data files into globals. Called once at game start.
function init_all_data() {
	// Save path: characters folder off the game directory (not AppData)
	global.save_path = working_directory + "characters/";
	if (!directory_exists(global.save_path)) directory_create(global.save_path);

	// Config
	global.config = read_json("config.json");

	// Game data
	global.professions = read_json("professions.json").professions;
	global.skill_tree = read_json("skills.json").skills;
	global.species_data = read_json("species.json").species;
	global.names = read_json("names.json");

	// Equipment database
	var _eq = read_json("equipment.json");
	global.equipment_weapons = _eq.weapons;
	global.equipment_armor = _eq.armor;
	global.equipment_gear = _eq.gear;

	// Programs & computers database
	var _prog = read_json("programs.json");
	global.programs = _prog.programs;
	global.computers = _prog.computers;
	global.processor_quality = _prog.processor_quality;

	// Program lookup table (O(1) by name → index)
	global.program_lookup = {};
	for (var _pi = 0; _pi < array_length(global.programs); _pi++)
		global.program_lookup[$ global.programs[_pi].name] = _pi;

	// NPC templates (GMG Chapter 6)
	global.npc_templates = read_json("npc_templates.json").templates;

	// Careers (need damage type string→enum conversion)
	var _careers_raw = read_json("careers.json");
	global.career_data = [];
	var _prof_keys = ["Combat Spec", "Diplomat", "Free Agent", "Tech Op", "Mindwalker"];
	for (var _profIdx = 0; _profIdx < 5; _profIdx++) {
		if (_careers_raw[$ _prof_keys[_profIdx]] != undefined)
			array_push(global.career_data, careers_from_import(_careers_raw[$ _prof_keys[_profIdx]]));
		else
			array_push(global.career_data, []);
	}

	// Unified FX database
	var _fx = read_json("fx_database.json");
	global.fx_database = _fx.fx;
	global.fx_lookup = {};
	for (var _fi = 0; _fi < array_length(global.fx_database); _fi++)
		global.fx_lookup[$ global.fx_database[_fi].name] = _fi;

	// Keyword tree
	global.keyword_tree = read_json("keyword_tree.json");

	// PHB reference tables
	global.skill_rank_benefits = read_json("tables/skill_rank_benefits.json");
	global.combat_tables = read_json("tables/combat_tables.json");
	global.gm_tables = read_json("tables/gm_tables.json");

	global.settings_library_name = "alternity default settings PHB";

	// Shared constants
	global.ability_keys = ["str", "dex", "con", "int", "wil", "per"];
	global.ability_names = ["STR", "DEX", "CON", "INT", "WIL", "PER"];
	global.ability_full = { str: "Strength", dex: "Dexterity", con: "Constitution", int: "Intelligence", wil: "Will", per: "Personality" };

	// Changelog: load on boot, reloadable on demand via reload_changelog()
	reload_changelog();
	global.recent_characters = load_or_create("recent_characters.json", function() { return { last_character: "", recent: [] }; });
}

// get_default_recent() REMOVED — inlined at callsite

// ============================================================
// RECENT CHARACTERS TRACKING
// ============================================================

/// @function add_recent_character(name, path)
/// @description Adds a character to the recent list. Removes duplicates, caps at 10.
function add_recent_character(_name, _path) {
	var _rc = global.recent_characters;
	_rc.last_character = _path;

	// Remove any existing entry with same path
	for (var _i = array_length(_rc.recent) - 1; _i >= 0; _i--) {
		if (_rc.recent[_i].path == _path) array_delete(_rc.recent, _i, 1);
	}

	// Insert at front
	array_insert(_rc.recent, 0, { name: _name, path: _path });

	// Cap at 10
	while (array_length(_rc.recent) > 10) array_pop(_rc.recent);

	write_json("recent_characters.json", _rc);
}

/// @function save_hero_and_track(statblock)
/// @description Saves the hero to characters/ dir and tracks in recents
function save_hero_and_track(_stat) {
	var _safe = sanitize_hero_filename(_stat.name);
	var _path = global.save_path + _safe + ".json";
	write_json(_path, build_statblock_export(_stat));
	add_recent_character(_stat.name, _path);

	// Broadcast character to multiplayer session if hosting
	if (variable_instance_exists(obj_game, "net_connected") && obj_game.net_connected && obj_game.net_is_host_flag) {
		net_send_character(_stat);
	}
}

/// @function rename_hero(stat, old_name, new_name)
/// @description Rename a character on disk: writes the new file at the new
/// sanitized path, deletes the old file (if names differ), updates the
/// recent_characters list, the roster, the campaign reference, the rolllog
/// file, and last_char_path. Safe to call even when only the display name
/// changes (no file rename happens unless the sanitized filename changes).
function rename_hero(_stat, _old_name, _new_name) {
	if (_new_name == "" || _new_name == undefined) return false;
	if (_old_name == _new_name) {
		// No-op rename — but still save and track in case other fields changed
		save_hero_and_track(_stat);
		return true;
	}
	var _old_safe = sanitize_hero_filename(_old_name);
	var _new_safe = sanitize_hero_filename(_new_name);
	var _old_path = global.save_path + _old_safe + ".json";
	var _new_path = global.save_path + _new_safe + ".json";

	// Apply the new name to the struct, then write to the new path
	_stat.name = _new_name;
	write_json(_new_path, build_statblock_export(_stat));

	// Delete the old file if its sanitized name actually changed
	if (_old_safe != _new_safe && file_exists(_old_path)) {
		file_delete(_old_path);
	}

	// Move the rolllog file too if present
	var _old_rolllog = global.save_path + _old_safe + "_rolllog.log";
	var _new_rolllog = global.save_path + _new_safe + "_rolllog.log";
	if (_old_safe != _new_safe && file_exists(_old_rolllog)) {
		file_copy(_old_rolllog, _new_rolllog);
		file_delete(_old_rolllog);
	}

	// Update the recent_characters list — remove old path, add new
	var _rc = global.recent_characters;
	for (var _i = array_length(_rc.recent) - 1; _i >= 0; _i--) {
		if (_rc.recent[_i].path == _old_path) array_delete(_rc.recent, _i, 1);
	}
	array_insert(_rc.recent, 0, { name: _new_name, path: _new_path });
	while (array_length(_rc.recent) > 10) array_pop(_rc.recent);
	if (_rc.last_character == _old_path) _rc.last_character = _new_path;
	write_json("recent_characters.json", _rc);

	// Update the campaign roster reference
	if (variable_global_exists("roster")) {
		for (var _ri = 0; _ri < array_length(global.roster); _ri++) {
			if (global.roster[_ri].path == _old_path) {
				global.roster[_ri].name = _new_name;
				global.roster[_ri].path = _new_path;
			}
		}
	}
	// Persist the campaign so the roster change survives restart
	if (script_exists(asset_get_index("save_campaign"))) save_campaign();

	// Update last_char_path on the game object
	if (variable_instance_exists(obj_game, "last_char_path") && obj_game.last_char_path == _old_path) {
		obj_game.last_char_path = _new_path;
	}

	// Broadcast character to multiplayer session if hosting
	if (variable_instance_exists(obj_game, "net_connected") && obj_game.net_connected && obj_game.net_is_host_flag) {
		net_send_character(_stat);
	}
	return true;
}

/// @function load_character_from_path(path)
/// @description Loads a character from a specific file path. Returns statblock or undefined.
function load_character_from_path(_path) {
	var _data = read_json(_path);
	if (_data == undefined) return undefined;
	if (_data[$ "_format"] == undefined || _data._format != "alternity_statblock") return undefined;

	// Use the existing import logic by calling statblock_import_data
	return statblock_import_data(_data);
}

// ============================================================
// CAMPAIGN PERSISTENCE
// ============================================================

/// @function save_campaign()
/// @description Saves campaign state: roster refs, party refs, NPC refs with factions
function save_campaign() {
	write_json("campaign.json", {
		_format: "alternity_campaign", _version: 1,
		factions: global.factions, roster: global.roster,
		party: _build_char_refs(global.party, false),
		npcs: _build_char_refs(global.npcs, true)
	});
}

/// @function load_campaign()
/// @description Loads campaign state from campaign.json if it exists
function load_campaign() {
	var _data = read_json("campaign.json");
	if (_data == undefined || _data[$ "_format"] != "alternity_campaign") return;
	global.factions = _data[$ "factions"] ?? ["Unaffiliated"];
	if (array_length(global.factions) == 0) global.factions = ["Unaffiliated"];
	global.roster = _data[$ "roster"] ?? [];
	global.party = _load_chars_from_refs(_data[$ "party"] ?? [], false);
	global.npcs = _load_chars_from_refs(_data[$ "npcs"] ?? [], true);
}

/// @function scan_characters_directory()
/// @description Scans characters/ folder and rebuilds roster with all found files
function scan_characters_directory() {
	global.roster = [];
	if (!directory_exists(global.save_path)) return;
	var _fileName = file_find_first(global.save_path + "*.json", 0);
	while (_fileName != "") {
		var _path = global.save_path + _fileName;
		var _data = read_json(_path);
		if (_data != undefined && _data[$ "_format"] == "alternity_statblock") {
			var _name = _data[$ "name"] ?? _fileName;
			// Check not already in roster
			var _isDuplicate = false;
			for (var _j = 0; _j < array_length(global.roster); _j++)
				if (global.roster[_j].path == _path) { _isDuplicate = true; break; }
			if (!_isDuplicate) array_push(global.roster, { name: _name, path: _path });
		}
		_fileName = file_find_next();
	}
	file_find_close();
}

/// @function roster_add_ref(name, path)
/// @description Adds a character reference to the roster (dedupes by path)
function roster_add_ref(_name, _path) {
	for (var _i = 0; _i < array_length(global.roster); _i++)
		if (global.roster[_i].path == _path) return; // already there
	array_push(global.roster, { name: _name, path: _path });
}

// ============================================================
// SESSION LOG — persistent GM-side history of every roll and chat.
// File: working_directory + "session_log.json" (next to characters/)
// Cap: 2000 entries, oldest get pruned. Saved on every append.
// ============================================================

#macro SESSION_LOG_FILE "session_log.json"
#macro SESSION_LOG_MAX  2000

/// @function session_log_load()
/// @description Load the persistent session log into obj_game.session_log_entries.
/// Returns silently if the file doesn't exist (first run).
function session_log_load() {
	var _path = working_directory + SESSION_LOG_FILE;
	if (!file_exists(_path)) return;
	var _file = file_text_open_read(_path);
	if (_file < 0) return;
	var _content = "";
	while (!file_text_eof(_file)) _content += file_text_readln(_file);
	file_text_close(_file);
	if (_content == "") return;
	try {
		var _data = json_parse(_content);
		if (is_array(_data)) obj_game.session_log_entries = _data;
		else if (is_struct(_data) && _data[$ "entries"] != undefined) obj_game.session_log_entries = _data.entries;
	} catch (_e) {
		show_debug_message("session_log_load parse error: " + string(_e));
	}
}

/// @function session_log_save()
/// @description Persist obj_game.session_log_entries to disk.
function session_log_save() {
	var _path = working_directory + SESSION_LOG_FILE;
	var _wrap = { version: 1, saved_at: current_time, entries: obj_game.session_log_entries };
	var _json = json_stringify(_wrap);
	var _file = file_text_open_write(_path);
	if (_file < 0) { show_debug_message("session_log_save: failed to open " + _path); return; }
	file_text_write_string(_file, _json);
	file_text_close(_file);
}

/// @function session_log_append(entry)
/// @description Push a new entry to the front, prune to SESSION_LOG_MAX, save.
/// Entry should be a struct with { kind, sender, character, text, total, degree, timestamp_ms, ts_str }.
function session_log_append(_entry) {
	if (!variable_instance_exists(obj_game, "session_log_entries")) return;
	array_insert(obj_game.session_log_entries, 0, _entry);
	if (array_length(obj_game.session_log_entries) > SESSION_LOG_MAX) {
		array_resize(obj_game.session_log_entries, SESSION_LOG_MAX);
	}
	session_log_save();
}

/// @function session_log_format_time(ms)
/// @description Convert a current_time-ish ms value into a "HH:MM:SS" string
/// using the system clock as the reference (so old entries show wall time).
function session_log_format_time(_ms) {
	// We don't have absolute timestamps, so format as h:m:s of CURRENT moment
	// for fresh entries. Stored entries keep their ts_str baked in.
	return string(current_hour) + ":" + string(current_minute) + ":" + string(current_second);
}

/// @function session_log_make_roll_entry(sender, character, skill, degree, total, mod_str)
/// @description Build a roll entry struct for session_log_append.
function session_log_make_roll_entry(_sender, _character, _skill, _degree, _total, _mod_str) {
	return {
		kind: "roll",
		sender: _sender,
		character: _character,
		skill: _skill,
		degree: _degree,
		total: _total,
		mod_str: _mod_str,
		text: "",
		ts_str: session_log_format_time(current_time),
		timestamp_ms: current_time
	};
}

/// @function session_log_make_chat_entry(sender, text, is_whisper, whisper_to)
/// @description Build a chat entry struct for session_log_append.
function session_log_make_chat_entry(_sender, _text, _is_whisper, _whisper_to) {
	return {
		kind: "chat",
		sender: _sender,
		character: "",
		skill: "",
		degree: 0,
		total: 0,
		mod_str: "",
		text: _text,
		is_whisper: _is_whisper,
		whisper_to: _whisper_to,
		ts_str: session_log_format_time(current_time),
		timestamp_ms: current_time
	};
}

// ============================================================
// SESSION CONTINUITY (v0.62.0) — last_session.json + last_join.json
// Persistent metadata for the GM "Continue Session" + Player "Rejoin Session" buttons.
// The relay is stateless so we can't truly resume — we just make re-entry painless
// by pre-filling join inputs and auto-pushing characters on player join.
// ============================================================

#macro LAST_SESSION_FILE "last_session.json"
#macro LAST_JOIN_FILE    "last_join.json"

/// @function save_last_session()
/// @description Persists the current session metadata for the GM "Continue Session" feature.
/// Called from net_host_session() success path and net_disconnect().
function save_last_session() {
	if (!variable_instance_exists(obj_game, "net_player_name")) return;
	if (obj_game.net_player_name == "") return;

	var _players_seen = [];
	if (variable_instance_exists(obj_game, "net_player_list") && is_array(obj_game.net_player_list)) {
		for (var _i = 0; _i < array_length(obj_game.net_player_list); _i++) {
			var _pl = obj_game.net_player_list[_i];
			var _pl_name = is_struct(_pl) ? (_pl[$ "name"] ?? "") : string(_pl);
			var _pl_host = is_struct(_pl) ? (_pl[$ "is_host"] ?? false) : false;
			if (_pl_host || _pl_name == "") continue;
			// Look up which character was last pushed to this player
			var _last_char = "";
			if (variable_global_exists("party")) {
				for (var _pi = 0; _pi < array_length(global.party); _pi++) {
					if ((global.party[_pi][$ "last_pushed_to"] ?? "") == _pl_name) {
						_last_char = global.party[_pi].name;
						break;
					}
				}
			}
			array_push(_players_seen, { name: _pl_name, last_pushed_character: _last_char });
		}
	}

	var _data = {
		_format: "alternity_last_session",
		_version: 1,
		host_name: obj_game.net_player_name,
		saved_at_ms: current_time,
		current_round: variable_instance_exists(obj_game, "current_round") ? obj_game.current_round : 1,
		players_seen: _players_seen
	};
	write_json(LAST_SESSION_FILE, _data);
}

/// @function load_last_session()
/// @description Loads last_session.json into global.last_session_data. Returns silently if missing.
function load_last_session() {
	global.last_session_data = read_json(LAST_SESSION_FILE);
}

/// @function save_last_join()
/// @description Persists the most recent join metadata for the player "Rejoin Session" feature.
function save_last_join() {
	if (!variable_instance_exists(obj_game, "net_player_name")) return;
	if (obj_game.net_player_name == "") return;
	// Find the GM name from the player list
	var _gm_name = "";
	if (variable_instance_exists(obj_game, "net_player_list") && is_array(obj_game.net_player_list)) {
		for (var _i = 0; _i < array_length(obj_game.net_player_list); _i++) {
			var _pl = obj_game.net_player_list[_i];
			var _pl_name = is_struct(_pl) ? (_pl[$ "name"] ?? "") : string(_pl);
			var _pl_host = is_struct(_pl) ? (_pl[$ "is_host"] ?? false) : false;
			if (_pl_host) { _gm_name = _pl_name; break; }
		}
	}
	var _data = {
		_format: "alternity_last_join",
		_version: 1,
		player_name: obj_game.net_player_name,
		last_session_code: obj_game.net_session_code,
		last_gm_name: _gm_name,
		saved_at_ms: current_time
	};
	write_json(LAST_JOIN_FILE, _data);
}

/// @function load_last_join()
/// @description Loads last_join.json into global.last_join_data. Returns silently if missing.
function load_last_join() {
	global.last_join_data = read_json(LAST_JOIN_FILE);
}

/// @function lookup_last_pushed_character(player_name)
/// @description Returns the party member statblock that was most recently pushed to
/// the named player, or undefined if none. Used by the auto-push hook on PLAYER_LIST.
function lookup_last_pushed_character(_player_name) {
	if (_player_name == "") return undefined;
	if (!variable_global_exists("party")) return undefined;
	for (var _i = 0; _i < array_length(global.party); _i++) {
		if ((global.party[_i][$ "last_pushed_to"] ?? "") == _player_name) {
			return global.party[_i];
		}
	}
	// Fallback: check global.last_session_data.players_seen for a name match
	if (variable_global_exists("last_session_data") && global.last_session_data != undefined) {
		var _seen = global.last_session_data[$ "players_seen"] ?? [];
		for (var _si = 0; _si < array_length(_seen); _si++) {
			if (_seen[_si].name == _player_name && _seen[_si].last_pushed_character != "") {
				// Match by character name
				for (var _pi = 0; _pi < array_length(global.party); _pi++) {
					if (global.party[_pi].name == _seen[_si].last_pushed_character) {
						return global.party[_pi];
					}
				}
			}
		}
	}
	return undefined;
}

// ============================================================
// CHANGELOG
// ============================================================

// get_timestamp_string() REMOVED — inlined at callsite in append_roll_log_file
// get_default_changelog() REMOVED — inlined at callsite