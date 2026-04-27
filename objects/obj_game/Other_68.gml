/// @description Async Networking event — receives data from net_socket
var _type = async_load[? "type"];

// Non-blocking connect completion (state machine: connecting -> connected/error)
if (_type == network_type_non_blocking_connect && async_load[? "id"] == net_socket) {
    var _ok = async_load[? "succeeded"];
    net_on_connect_complete(_ok == 1 || _ok == true);
}
else if (_type == network_type_data && async_load[? "id"] == net_socket) {
    var _buf = async_load[? "buffer"];
    var _size = async_load[? "size"];
    var _messages = net_recv_from_buffer(_buf, _size);

    for (var _i = 0; _i < array_length(_messages); _i++) {
        var _msg = _messages[_i];
        var _msg_type = _msg[$ "type"] ?? "";
        switch (_msg_type) {
            case NET_MSG_CREATED:
                net_session_code = _msg.payload[$ "code"] ?? "";
                net_is_host_flag = true;
                net_player_list = [{name: net_player_name, is_host: true}];
                net_handshake_state = "in_session";
                status_msg = "Hosting session: " + net_session_code; status_timer = 180;
                // v0.62.0: persist session metadata so the GM can Continue Session later
                auto_pushed_this_session = {};
                save_last_session();
                break;
            case NET_MSG_JOIN_OK:
                net_is_host_flag = false;
                net_player_list = _msg.payload[$ "players"] ?? [];
                net_handshake_state = "in_session";
                status_msg = "Joined session " + net_session_code; status_timer = 180;
                // v0.62.0: persist join metadata so the player can Rejoin Session later
                save_last_join();
                break;
            case NET_MSG_JOIN_FAIL:
                // Map relay reason codes to friendly UI text
                var _reason = _msg.payload[$ "reason"] ?? "unknown";
                if (_reason == "No such session") {
                    net_error_message = "Session does not exist";
                } else if (_reason == "Session full") {
                    net_error_message = "Session is full";
                } else {
                    net_error_message = "Join failed: " + _reason;
                }
                status_msg = net_error_message; status_timer = 240;
                net_handshake_state = "error";
                net_disconnect();
                break;
            case NET_MSG_PLAYER_LIST:
                net_player_list = _msg.payload[$ "players"] ?? [];
                // v0.62.0: GM auto-push for Continue Session — when a player joins,
                // look up their last_pushed_character and push it again automatically.
                // Only fires once per player per connection (tracked in auto_pushed_this_session).
                if (gm_mode && net_is_host_flag) {
                    for (var _pli = 0; _pli < array_length(net_player_list); _pli++) {
                        var _pl = net_player_list[_pli];
                        var _pl_name = is_struct(_pl) ? (_pl[$ "name"] ?? "") : string(_pl);
                        var _pl_host = is_struct(_pl) ? (_pl[$ "is_host"] ?? false) : false;
                        if (_pl_host || _pl_name == "") continue;
                        if (auto_pushed_this_session[$ _pl_name] != undefined) continue;
                        var _matched_char = lookup_last_pushed_character(_pl_name);
                        if (_matched_char != undefined) {
                            net_push_character_to(_pl_name, _matched_char);
                            auto_pushed_this_session[$ _pl_name] = true;
                        }
                    }
                }
                break;
            case NET_MSG_ROLL_RESULT:
                log_remote_roll(_msg);
                break;
            case NET_MSG_CHAT:
                log_remote_chat(_msg);
                break;
            case NET_MSG_CHARACTER_SYNC:
                log_remote_character(_msg);
                break;
            case NET_MSG_CHAR_REQUEST:
                // Someone (typically the GM) is asking for our current character.
                // Respond by broadcasting our active hero so it lands in their roster.
                if (hero != undefined) net_send_character(hero);
                break;
            case NET_MSG_GM_STATUS:
                status_msg = "[GM] " + (_msg.payload[$ "text"] ?? "");
                status_timer = 240;
                break;
            // Map bridge messages — no-op in dice manager, relay forwards them
            case NET_MSG_MAP_TOKEN_MOVE:
            case NET_MSG_MAP_TOKEN_ADD:
            case NET_MSG_MAP_TOKEN_REMOVE:
            case NET_MSG_MAP_STATE_FULL:
                break;
        }
    }
}
else if (_type == network_type_disconnect && async_load[? "id"] == net_socket) {
    net_disconnect();
    status_msg = "Disconnected from session"; status_timer = 240;
}
