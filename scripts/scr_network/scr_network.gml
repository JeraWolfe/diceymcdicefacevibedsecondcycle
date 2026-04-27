// ============================================================
// scr_network.gml — Multiplayer relay client
// TCP socket to relay server, newline-delimited JSON messages.
// ============================================================
//
// NOTE: GameMaker's network_connect_raw is non-blocking and may return
// immediately while the underlying TCP handshake is still in progress.
// A return value >= 0 only means the connect attempt was queued — the
// socket may not be fully established when net_init() returns true.
// Code that depends on a live connection should be defensive and treat
// the first send/recv as the real "connected" signal, or wait for the
// async networking event to confirm the link is up.
// ============================================================

#macro NET_PROTOCOL_VERSION 1
// Railway TCP Proxy — production relay for DiceyMcDiceFaces multiplayer.
// To change: redeploy relay_server/ to a new Railway TCP Proxy and update both values.
#macro NET_DEFAULT_RELAY_HOST "centerbeam.proxy.rlwy.net"
#macro NET_DEFAULT_RELAY_PORT 23003

// Message type constants
#macro NET_MSG_CREATE          "CREATE"
#macro NET_MSG_CREATED         "CREATED"
#macro NET_MSG_JOIN_REQ        "JOIN_REQ"
#macro NET_MSG_JOIN_OK         "JOIN_OK"
#macro NET_MSG_JOIN_FAIL       "JOIN_FAIL"
#macro NET_MSG_PLAYER_LIST     "PLAYER_LIST"
#macro NET_MSG_ROLL_RESULT     "ROLL_RESULT"
#macro NET_MSG_CHARACTER_SYNC  "CHARACTER_SYNC"
#macro NET_MSG_CHAR_REQUEST    "CHAR_REQUEST"
#macro NET_MSG_CHAT            "CHAT"
#macro NET_MSG_GM_STATUS       "GM_STATUS"
#macro NET_MSG_HEARTBEAT       "HEARTBEAT"
// Map bridge message types (Phase 3 will add handlers, Phase 1 just defines)
#macro NET_MSG_MAP_TOKEN_MOVE   "MAP_TOKEN_MOVE"
#macro NET_MSG_MAP_TOKEN_ADD    "MAP_TOKEN_ADD"
#macro NET_MSG_MAP_TOKEN_REMOVE "MAP_TOKEN_REMOVE"
#macro NET_MSG_MAP_STATE_REQ    "MAP_STATE_REQUEST"
#macro NET_MSG_MAP_STATE_FULL   "MAP_STATE_FULL"
#macro NET_MSG_CHAR_TOKEN_LINK  "CHAR_TOKEN_LINK"
#macro NET_MSG_ROLL_AT_TOKEN    "ROLL_AT_TOKEN"

// ============================================================
// CONNECTION + STATE MACHINE
// ============================================================
//
// net_handshake_state values:
//   "idle"        — no socket, no pending action, fully reset
//   "connecting"  — socket created, network_connect_raw in flight, awaiting
//                    network_type_non_blocking_connect async event
//   "connected"   — TCP handshake complete, can send messages
//   "in_session"  — we are in a room (have a session code, host or guest)
//   "error"       — connection failed or timed out, needs net_full_reset
//
// net_pending_action: undefined or struct describing what to send once
// the socket reaches "connected" state. Examples:
//   { type: "host", name: "Alice" }
//   { type: "join", code: "ABC123", name: "Alice" }
// ============================================================

#macro NET_CONNECT_TIMEOUT_MS 10000

/// @function net_full_reset()
/// @description Single source of truth for clearing ALL multiplayer state.
/// Tear down socket, clear pending actions, reset state machine, clear inputs.
function net_full_reset() {
    if (obj_game.net_socket != -1) {
        network_destroy(obj_game.net_socket);
        obj_game.net_socket = -1;
    }
    obj_game.net_connected = false;
    obj_game.net_handshake_state = "idle";
    obj_game.net_pending_action = undefined;
    obj_game.net_connect_start_time = 0;
    obj_game.net_session_code = "";
    obj_game.net_is_host_flag = false;
    obj_game.net_player_list = [];
    obj_game.net_recv_buffer = "";
    obj_game.net_player_name_input = "";
    obj_game.net_join_code_input = "";
    obj_game.net_input_focus = "";
    obj_game.net_error_message = "";
}

/// @function net_init(host, port)
/// @description Open a TCP socket and queue a non-blocking connect attempt.
/// Tears down any existing socket first. Sets handshake_state = "connecting".
/// The actual completion is signaled by the network_type_non_blocking_connect
/// async event, which transitions state to "connected" or "error".
function net_init(_host, _port) {
    // Tear down any existing socket — never refuse, always reset
    if (obj_game.net_socket != -1) {
        network_destroy(obj_game.net_socket);
        obj_game.net_socket = -1;
    }
    obj_game.net_recv_buffer = "";
    obj_game.net_connected = false;

    obj_game.net_socket = network_create_socket(network_socket_tcp);
    if (obj_game.net_socket < 0) {
        obj_game.net_handshake_state = "error";
        obj_game.net_error_message = "Failed to create socket";
        return false;
    }
    var _result = network_connect_raw_async(obj_game.net_socket, _host, _port);
    if (_result < 0) {
        network_destroy(obj_game.net_socket);
        obj_game.net_socket = -1;
        obj_game.net_handshake_state = "error";
        obj_game.net_error_message = "Failed to start connect";
        return false;
    }
    obj_game.net_handshake_state = "connecting";
    obj_game.net_connect_start_time = current_time;
    return true;
}

/// @function net_on_connect_complete(succeeded)
/// @description Called from the Async Networking event when the non-blocking
/// connect attempt finishes. Promotes "connecting" -> "connected" or "error".
function net_on_connect_complete(_succeeded) {
    if (obj_game.net_handshake_state != "connecting") return;
    if (_succeeded) {
        obj_game.net_handshake_state = "connected";
        obj_game.net_connected = true;
        net_flush_pending_action();
    } else {
        obj_game.net_handshake_state = "error";
        obj_game.net_error_message = "Could not reach relay server";
        if (obj_game.net_socket != -1) { network_destroy(obj_game.net_socket); obj_game.net_socket = -1; }
        obj_game.net_connected = false;
    }
}

/// @function net_flush_pending_action()
/// @description If we have a pending action and the socket is connected, send
/// it now and clear the pending slot. Called after net_on_connect_complete.
function net_flush_pending_action() {
    if (obj_game.net_pending_action == undefined) return;
    if (obj_game.net_handshake_state != "connected") return;
    var _action = obj_game.net_pending_action;
    var _action_type = _action[$ "type"] ?? "";
    if (_action_type == "host") {
        net_send(NET_MSG_CREATE, { name: _action[$ "name"] ?? "" });
    } else if (_action_type == "join") {
        net_send(NET_MSG_JOIN_REQ, { code: _action[$ "code"] ?? "", name: _action[$ "name"] ?? "" });
    }
    obj_game.net_pending_action = undefined;
}

/// @function net_check_timeout()
/// @description Called from the Step event. If we've been "connecting" for
/// too long, transition to "error" with a timeout message.
function net_check_timeout() {
    if (obj_game.net_handshake_state != "connecting") return;
    var _elapsed = current_time - obj_game.net_connect_start_time;
    if (_elapsed < 0 || _elapsed > NET_CONNECT_TIMEOUT_MS) {
        obj_game.net_handshake_state = "error";
        obj_game.net_error_message = "Connection timeout (>10s)";
        if (obj_game.net_socket != -1) { network_destroy(obj_game.net_socket); obj_game.net_socket = -1; }
        obj_game.net_connected = false;
        obj_game.net_pending_action = undefined;
    }
}

/// @function net_disconnect()
/// @description Politely close the socket and reset session state. Used for
/// "leave session" — distinct from net_full_reset which also wipes input fields.
function net_disconnect() {
    // v0.62.0: Save final session snapshot BEFORE clearing state, so the
    // Continue Session button has fresh metadata to work with.
    if (obj_game.net_is_host_flag && script_exists(asset_get_index("save_last_session"))) {
        save_last_session();
    }
    if (obj_game.net_socket != -1) {
        network_destroy(obj_game.net_socket);
        obj_game.net_socket = -1;
    }
    obj_game.net_connected = false;
    obj_game.net_handshake_state = "idle";
    obj_game.net_pending_action = undefined;
    obj_game.net_session_code = "";
    obj_game.net_is_host_flag = false;
    obj_game.net_player_list = [];
    obj_game.net_recv_buffer = "";
    obj_game.net_error_message = "";
}

function net_is_connected() {
    return obj_game.net_connected;
}

function net_is_host() {
    return obj_game.net_is_host_flag;
}

function net_get_session_code() {
    return obj_game.net_session_code;
}

function net_get_players() {
    return obj_game.net_player_list;
}

// ============================================================
// CORE SEND / RECV
// ============================================================

/// @function net_send(msg_type, payload, [to])
/// @description Wraps payload in the standard envelope and sends it as a
/// newline-delimited JSON line over the TCP socket. Optional _to argument
/// targets a single recipient (used by whispers); relay routes by player name.
function net_send(_msg_type, _payload, _to = "") {
    if (!net_is_connected()) return false;
    var _msg = {
        v: NET_PROTOCOL_VERSION,
        type: _msg_type,
        session: obj_game.net_session_code,
        sender: obj_game.net_player_name,
        to: _to,
        ts: current_time,
        payload: _payload
    };
    var _json = json_stringify(_msg) + "\n";
    // CRITICAL: buffer_text does NOT write a null terminator, but buffer_create
    // would over-allocate if we asked for +1, and network_send_raw uses the FULL
    // buffer size. Send EXACTLY string_byte_length(_json) bytes, no padding.
    var _len = string_byte_length(_json);
    var _buf = buffer_create(_len, buffer_fixed, 1);
    buffer_write(_buf, buffer_text, _json);
    network_send_raw(obj_game.net_socket, _buf, _len);
    buffer_delete(_buf);
    show_debug_message("[NET] -> " + _msg_type + " (" + string(_len) + " bytes)");
    return true;
}

/// @function net_recv_from_buffer(buf, size)
/// @description Called from the Async Networking event with the incoming
/// buffer. Appends bytes to the rolling recv buffer, then splits on newlines
/// and parses any complete JSON messages. Returns an array of parsed structs.
function net_recv_from_buffer(_buf, _size) {
    // Read raw bytes from buffer — buffer_text is unsafe (no null guarantee)
    buffer_seek(_buf, buffer_seek_start, 0);
    var _chunk = "";
    repeat (_size) {
        _chunk += chr(buffer_read(_buf, buffer_u8));
    }
    obj_game.net_recv_buffer += _chunk;
    var _messages = [];
    var _nl = string_pos("\n", obj_game.net_recv_buffer);
    while (_nl > 0) {
        var _line = string_copy(obj_game.net_recv_buffer, 1, _nl - 1);
        obj_game.net_recv_buffer = string_delete(obj_game.net_recv_buffer, 1, _nl);
        if (_line != "") {
            try {
                var _msg = json_parse(_line);
                array_push(_messages, _msg);
            } catch (_e) {
                show_debug_message("net_recv parse error: " + string(_e));
            }
        }
        _nl = string_pos("\n", obj_game.net_recv_buffer);
    }
    return _messages;
}

// ============================================================
// SESSION
// ============================================================
//
// Both net_host_session and net_join_session use the pending action queue.
// They do NOT call net_send directly — instead they set net_pending_action
// and call net_init. The Async Networking event will eventually fire
// network_type_non_blocking_connect, which calls net_on_connect_complete,
// which calls net_flush_pending_action, which finally fires the message.
// This avoids the race condition where send() is called before the TCP
// handshake completes.
// ============================================================

function net_host_session(_player_name) {
    obj_game.net_player_name = _player_name;
    obj_game.net_pending_action = { type: "host", name: _player_name };
    return net_init(NET_DEFAULT_RELAY_HOST, NET_DEFAULT_RELAY_PORT);
}

function net_join_session(_code, _player_name) {
    obj_game.net_player_name = _player_name;
    obj_game.net_session_code = _code; // shown in UI immediately, will be confirmed by JOIN_OK
    obj_game.net_pending_action = { type: "join", code: _code, name: _player_name };
    return net_init(NET_DEFAULT_RELAY_HOST, NET_DEFAULT_RELAY_PORT);
}

function net_leave_session() {
    net_disconnect();
}

// ============================================================
// ROLL PROTOCOL
// ============================================================

/// @function net_send_roll(roll_result, char_name)
/// @description Broadcast a completed roll to the session.
function net_send_roll(_roll_result, _char_name) {
    if (!net_is_connected()) return false;
    var _payload = {
        char_name: _char_name,
        skill_name: _roll_result[$ "skill_name"] ?? "",
        control_roll: _roll_result[$ "control_roll"] ?? 0,
        situation_roll: _roll_result[$ "situation_roll"] ?? 0,
        situation_step: _roll_result[$ "situation_step"] ?? 0,
        total: _roll_result[$ "total"] ?? 0,
        degree: _roll_result[$ "degree"] ?? 0,
        degree_name: _roll_result[$ "degree_name"] ?? "",
        modifiers: _roll_result[$ "modifiers"] ?? [],
        difficulty: _roll_result[$ "difficulty"] ?? ""
    };
    return net_send(NET_MSG_ROLL_RESULT, _payload);
}

// ============================================================
// CHARACTER (DATASOUL) PROTOCOL
// ============================================================

/// @function net_send_character(stat)
/// @description Broadcast a full statblock export to the session.
function net_send_character(_stat) {
    if (!net_is_connected()) return false;
    if (_stat == undefined) return false;
    var _export = build_statblock_export(_stat);
    return net_send(NET_MSG_CHARACTER_SYNC, { statblock: _export });
}

/// @function net_request_character(char_name)
/// @description Ask the host (or peers) for a named character's full data.
function net_request_character(_char_name) {
    if (!net_is_connected()) return false;
    return net_send(NET_MSG_CHAR_REQUEST, { char_name: _char_name });
}

/// @function net_request_character_from(target_player)
/// @description Ask a specific player (by name) to send back their current
/// character. Used by the GM "+Camp" button so a player joining the session
/// can be auto-rostered.
function net_request_character_from(_target_player) {
    if (!net_is_connected()) return false;
    return net_send(NET_MSG_CHAR_REQUEST, { from: _target_player }, _target_player);
}

/// @function net_push_character_to(target_player, stat)
/// @description Send a full character export targeted at a single player so
/// the GM can push a pre-built character into a player's slot.
function net_push_character_to(_target_player, _stat) {
    if (!net_is_connected()) return false;
    if (_stat == undefined) return false;
    var _export = build_statblock_export(_stat);
    return net_send(NET_MSG_CHARACTER_SYNC, { statblock: _export, pushed: true }, _target_player);
}

// ============================================================
// CHAT
// ============================================================

/// @function net_send_chat(text)
/// @description Send a plain chat line into the party stream.
function net_send_chat(_text) {
    if (!net_is_connected()) return false;
    if (_text == "") return false;
    return net_send(NET_MSG_CHAT, { text: _text });
}

/// @function net_send_whisper(target_name, text)
/// @description Send a private chat line targeted at one player by name.
/// Special target "gm" routes to the session host. Relay forwards only to the
/// matching recipient (and silently echoes to GMs for moderation).
function net_send_whisper(_target_name, _text) {
    if (!net_is_connected()) return false;
    if (_text == "") return false;
    if (_target_name == "") return false;
    return net_send(NET_MSG_CHAT, { text: _text, whisper: true, whisper_to: _target_name }, _target_name);
}

// ============================================================
// GM STATUS (host only)
// ============================================================

/// @function net_send_status(text)
/// @description Host-only broadcast of a GM status message.
function net_send_status(_text) {
    if (!net_is_connected() || !net_is_host()) return false;
    return net_send(NET_MSG_GM_STATUS, { text: _text });
}

// ============================================================
// MAP BRIDGE
// ============================================================

/// @function net_send_token_link(char_name, token_id)
/// @description Link a character to a map token.
function net_send_token_link(_char_name, _token_id) {
    if (!net_is_connected()) return false;
    return net_send(NET_MSG_CHAR_TOKEN_LINK, { char_name: _char_name, token_id: _token_id });
}

/// @function net_send_roll_at_token(roll_result, char_name, token_id)
/// @description Send a roll result tagged with a token id for the map bridge.
function net_send_roll_at_token(_roll_result, _char_name, _token_id) {
    if (!net_is_connected()) return false;
    return net_send(NET_MSG_ROLL_AT_TOKEN, {
        char_name: _char_name,
        token_id: _token_id,
        skill_name: _roll_result[$ "skill_name"] ?? "",
        total: _roll_result[$ "total"] ?? 0,
        degree: _roll_result[$ "degree"] ?? 0,
        degree_name: _roll_result[$ "degree_name"] ?? ""
    });
}

// ============================================================
// HEARTBEAT — called from Step event every frame, fires every 30s
// ============================================================

/// @function net_heartbeat_tick()
/// @description Send a no-op heartbeat message if 30 seconds have elapsed.
function net_heartbeat_tick() {
    if (!net_is_connected()) return;
    var _elapsed = current_time - obj_game.net_last_heartbeat;
    // Handle current_time wrap-around (every ~24.8 days on 32-bit)
    if (_elapsed < 0 || _elapsed > 30000) {
        net_send(NET_MSG_HEARTBEAT, {});
        obj_game.net_last_heartbeat = current_time;
    }
}

// ============================================================
// RECEIVE HELPERS — called from Other_68.gml (Async Networking)
// ============================================================

/// @function log_remote_roll(msg)
/// @description Turn a received ROLL_RESULT message into a struct entry and
/// prepend it to obj_game.rolllog_entries.
function log_remote_roll(_msg) {
    var _payload = _msg.payload;
    var _entry = {
        sender_name: _msg.sender,
        character_name: _payload[$ "char_name"] ?? "?",
        skill_name: _payload[$ "skill_name"] ?? "",
        degree_name: _payload[$ "degree_name"] ?? "",
        degree: _payload[$ "degree"] ?? 0,
        total: _payload[$ "total"] ?? 0,
        mod_str: "",
        modifiers: _payload[$ "modifiers"] ?? [],
        is_remote: true,
        is_chat: false,
        chat_text: "",
        timestamp: _msg[$ "ts"] ?? current_time
    };
    array_insert(obj_game.rolllog_entries, 0, _entry);
    if (array_length(obj_game.rolllog_entries) > obj_game.max_log_entries) {
        array_pop(obj_game.rolllog_entries);
    }
    // Persistent session log — remote rolls
    session_log_append(session_log_make_roll_entry(_entry.sender_name, _entry.character_name, _entry.skill_name, _entry.degree, _entry.total, ""));
}

/// @function log_remote_chat(msg)
/// @description Turn a received CHAT message into a struct entry and prepend
/// it to obj_game.rolllog_entries. Whispers are marked with a [whisper] prefix
/// so the receiver can see who it was meant for.
function log_remote_chat(_msg) {
    var _payload = _msg.payload;
    var _text = _payload[$ "text"] ?? "";
    var _is_whisper = _payload[$ "whisper"] ?? false;
    var _whisper_to = _payload[$ "whisper_to"] ?? "";
    var _display_text = _text;
    if (_is_whisper) {
        // From the recipient's POV: "[whisper from Alice] hi"
        // From a snooping GM's POV: "[whisper Alice -> Bob] hi"
        if (obj_game.net_player_name == _whisper_to) {
            _display_text = "[whisper from " + _msg.sender + "] " + _text;
        } else {
            _display_text = "[whisper " + _msg.sender + " -> " + _whisper_to + "] " + _text;
        }
    }
    var _entry = {
        sender_name: _msg.sender,
        character_name: "",
        skill_name: "",
        degree_name: "",
        degree: 0,
        total: 0,
        mod_str: "",
        modifiers: [],
        is_remote: true,
        is_chat: true,
        is_whisper: _is_whisper,
        chat_text: _display_text,
        timestamp: _msg[$ "ts"] ?? current_time
    };
    array_insert(obj_game.rolllog_entries, 0, _entry);
    if (array_length(obj_game.rolllog_entries) > obj_game.max_log_entries) {
        array_pop(obj_game.rolllog_entries);
    }
    // Persistent session log — remote chat (whispers included)
    session_log_append(session_log_make_chat_entry(_msg.sender, _text, _is_whisper, _whisper_to));
}

/// @function log_remote_character(msg)
/// @description Receive a CHARACTER_SYNC message — apply via import logic.
/// If the sender flagged the message as `pushed: true` and we're not the host,
/// the character is loaded as our active hero (GM is pushing a character to a
/// specific player). Otherwise it lands in global.npcs as a roster entry.
function log_remote_character(_msg) {
    var _payload = _msg.payload;
    var _statblock_data = _payload[$ "statblock"];
    if (_statblock_data == undefined) return;
    var _imported = statblock_import_data(_statblock_data);
    if (_imported == undefined) return;
    // Guard against early async event firing before init_all_data
    if (!variable_global_exists("npcs") || global.npcs == undefined) return;
    // Tag as shared
    _imported.shared_from = _msg.sender;

    var _is_pushed = _payload[$ "pushed"] ?? false;
    if (_is_pushed && !net_is_host()) {
        // GM pushed this character to us — make it our active hero.
        if (obj_game.hero != undefined) save_hero_and_track(obj_game.hero);
        obj_game.hero = _imported;
        update_hero(obj_game.hero);
        obj_game.hero_dirty = true;
        obj_game.status_msg = "GM pushed character: " + _imported.name;
        obj_game.status_timer = 240;
        return;
    }

    // Default: add to global.npcs (dedupe by name)
    var _exists = false;
    for (var _i = 0; _i < array_length(global.npcs); _i++) {
        if (global.npcs[_i].name == _imported.name) {
            global.npcs[_i] = _imported;
            _exists = true;
            break;
        }
    }
    if (!_exists) array_push(global.npcs, _imported);
}
