/// @description Initialize all data, welcome screen, full game state

// Disable default application surface drawing — we use Draw GUI only
application_surface_draw_enable(false);

init_all_data();

// Portrait system (must init before auto-load since update_hero loads portraits)
global.portrait_sprite = -1;
global.portrait_path = "";
if (!directory_exists("portraits")) directory_create("portraits");
portrait_dropdown_open = false;
portrait_presets = [];

// Generate coded portraits if missing
generate_all_coded_portraits();

// Copy Voss template from datafiles to characters/ if missing
if (!file_exists(global.save_path + "voss.json")) {
	var _vossData = read_json("voss.json");
	if (_vossData != undefined) write_json(global.save_path + "voss.json", _vossData);
}

// Pre-load last character (but don't skip welcome screen)
// Initialize hero to a blank statblock so the sheet never renders undefined
hero = create_statblock("New Character", 0, "None");
update_hero(hero);
last_char_path = "";
if (global.recent_characters.last_character != "") {
	last_char_path = global.recent_characters.last_character;
}

// Always start on welcome/changelog screen
game_state = "welcome";
changelog_scroll = 0;

// Changelog modal — auto-opens once per session, closes via X / Escape / click-off.
// Two views:
//   "current" → always shows the latest 10 entries (1 page, no navigation)
//   "past"    → paginates through entries 10..end, 10 per page
changelog_open = true;       // start visible on first welcome screen visit
changelog_view = "current";   // "current" or "past"
changelog_page = 0;           // page index within the "past" view
#macro CHANGELOG_PAGE_SIZE 10
#macro CHANGELOG_CURRENT_COUNT 10

// Accessibility settings (loaded from config, saved back)
var _acc = global.config[$ "accessibility"] ?? {};
colorblind_mode = _acc[$ "mode"] ?? "normal";
// Modes: "normal", "protanopia", "deuteranopia", "tritanopia", "greyscale"
accessibility_open = false; // populated after hero loads

// Staged roll system: prepare a roll → show computed modifier → player adjusts → click Roll to execute
staged_roll = undefined;  // nil = no roll staged. Struct = { request, computed_step, modifiers[] }
staged_step_override = 0; // player's manual adjustment on top of computed step

// Tabs: 0=Character, 1=Equipment, 2=Combat, 3=Psionics, 4=Perks/Flaws, 5=Cybertech, 6=Roll Log, 7=Info
current_tab = 0;

// Skill list
selected_skill = 0;
scroll_offset = 0;
situation_step = SIT_STEP_BASE;
last_roll = undefined;
roll_log = [];
skill_list_start_y = 0;
active_stat_group = "str";  // Which ability group is shown on Character tab (str/dex/con/int/wil/per)
skill_index_map = [];       // Maps visible filtered row → hero.skills[] index (rebuilt each frame)

// Untrained section (collapsible on Character tab)
untrained_expanded = false;

// Info tab scroll
info_scroll = 0;

// Perks & Flaws tab
pf_view = "perks";
pf_scroll = 0;
pf_max_visible = 14;

// Equipment tab
equip_view = "weapons";      // "weapons", "armor", "gear"
equip_expanded = -1;         // expanded item in available list
equip_adding = false;        // is the add-equipment panel open?
equip_verbose = true;        // verbose or compact inventory display
equip_inspect = -1;          // index of inspected item (-1 = none)
equip_inspect_type = "";     // "weapon" / "armor" / "gear"
campaign_pl = 7;             // progress level filter (7 = Gravity Age default)

// Grid/Cyberdeck tab
grid_view = "programs";      // "programs", "computer", "builder"
grid_expanded = -1;          // expanded program in available list
grid_adding = false;         // is the add-program panel open?
grid_comp_expanded = -1;     // expanded computer index for quality selection (-1 = none)

// Cybertech tab
cyber_expanded = -1; // index of expanded gear in available list, -1 = none

// Roll log tab state
rolllog_entries = []; // loaded from file when tab is shown
rolllog_scroll = 0;
rolllog_dirty = true; // reload next time tab is shown

// Action phase tracker
// Phases: 0=Amazing, 1=Good, 2=Ordinary, 3=Marginal
// actions_total = hero's actions per round (usually 2)
// actions_placed[4] = how many actions placed in each phase
// initiative_phase = which phase you start in (from action check roll)
actions_placed = [0, 0, 0, 0];
actions_total = 2;
initiative_phase = -1; // -1 = not rolled yet
actions_remaining = 0;

// Combat tab - last attack result for damage follow-up
last_combat_weapon = undefined; // weapon struct of last attack roll
last_combat_degree = -1;        // degree of last attack (for damage tier)

// Combat tab state
combat_selected = 0;
combat_range = 0; // 0=short, 1=medium, 2=long
apply_wound_penalty = true;  // radio button: include wound penalty in difficulty
cant_fail_mode = false;      // checkmark: failures become marginal

// Animation
roll_anim_timer = 0;
is_rolling = false;

// Colors from config
var _c = global.config.colors;
// Gradient background (from config)
c_bg_top=parse_hex_color(_c[$ "bg_top"] ?? "#ffffff");
c_bg_bottom=parse_hex_color(_c[$ "bg_bottom"] ?? "#1a6b5a");
c_bg_wave_y=_c[$ "bg_wave_y"] ?? 0.45;
c_panel=parse_hex_color(_c.panel);
c_border=parse_hex_color(_c.border); c_text=parse_hex_color(_c.text);
c_text_dark=parse_hex_color(_c[$ "text_dark"] ?? "#1a1a2e");
c_highlight=parse_hex_color(_c.highlight); c_good=parse_hex_color(_c.good);
c_warning=parse_hex_color(_c.warning); c_amazing=parse_hex_color(_c.amazing);
c_failure=parse_hex_color(_c.failure); c_muted=parse_hex_color(_c.muted);
c_header=parse_hex_color(_c.header);
c_tab_active=parse_hex_color(_c.tab_active); c_tab_inactive=parse_hex_color(_c.tab_inactive);

// Window mode: "fullscreen", "windowed", "half"
// Saved in config, changeable via accessibility menu
var _acc2 = global.config[$ "accessibility"] ?? {};
window_mode = _acc2[$ "window_mode"] ?? "windowed";

var _disp_w = display_get_width();
var _disp_h = display_get_height();

if (window_mode == "fullscreen") {
	window_set_fullscreen(true);
	gui_w = _disp_w;
	gui_h = _disp_h;
} else if (window_mode == "half") {
	window_set_fullscreen(false);
	gui_w = floor(_disp_w / 2);
	gui_h = floor(_disp_h * 0.85);
	window_set_size(gui_w, gui_h);
	window_set_position(floor(_disp_w / 4), floor(_disp_h * 0.05));
} else {
	window_set_fullscreen(false);
	gui_w = floor(_disp_w * 0.8);
	gui_h = floor(_disp_h * 0.85);
	window_set_size(gui_w, gui_h);
	window_center();
}
// Match GUI, application surface, and room to window — eliminates black borders
display_set_gui_size(gui_w, gui_h);
surface_resize(application_surface, gui_w, gui_h);
room_width = gui_w;
room_height = gui_h;

// GM mode
gm_mode = false; // false = player mode, true = GM mode
tabs_horizontal = false; // false = vertical side tabs (default), true = horizontal top tabs
global.party = []; // array of party statblocks (player characters)
global.npcs = [];  // array of NPC statblocks with .faction field
global.roster = []; // array of {name, path} refs for ALL known character files
global.factions = ["Unaffiliated"]; // faction/team names for NPC grouping
party_selected = 0; // index of active character in party
gm_tab = 0;        // 0=Party, 1=NPCs, 2=Encounter, 3=Campaign
gm_state = "gm";   // "gm" = GM tools screen, "edit" = player char edit
gm_edit_source = "party"; // "party" or "npc" — which list the edited char came from
gm_edit_index = -1; // index in source list of character being edited
gm_npc_selected = -1; // selected NPC index
gm_roster_scroll = 0; // scroll offset for campaign roster
gm_party_scroll = 0;
gm_npc_scroll = 0;
gm_add_faction_open = false; // faction name input mode

// Load saved campaign if exists
load_campaign();

// Layout scales to actual GUI size
var _l = global.config.layout;
var _pad = 12;
panel_left_x = _pad;
panel_left_w = floor(gui_w * 0.6) - _pad;
panel_right_x = panel_left_x + panel_left_w + _pad;
panel_right_w = gui_w - panel_right_x - _pad;
panel_y = _l.panel_y;
// Scale visible skills to available height
max_visible_skills = max(8, floor((gui_h - 400) / 18));
roll_anim_duration=global.config.roll_animation_frames;
max_log_entries=global.config.max_log_entries;

// Status
status_msg = ""; status_timer = 0;

// ============================================================
// Multiplayer networking state
// ============================================================
net_socket = -1;
net_connected = false;
net_session_code = "";
net_is_host_flag = false;
net_player_name = "";
net_player_list = [];
net_recv_buffer = "";
net_chat_buffer = "";
net_last_heartbeat = 0;

// GM dice roller (free-form expressions like "1d20-4x3")
gm_dice_buffer = "";
gm_dice_last_result = undefined;     // struct from parse_dice_expression, or undefined

// ============================================================
// Inline modal text editor — replaces ALL get_string() popups.
// In-game floating box that takes a label, current value, max length, and a
// callback. Real-time saves on every keystroke. Escape or Cancel exits.
// Only blocks input that overlaps the box; the rest of the UI stays interactive.
// ============================================================
text_modal_open = false;
text_modal_label = "";              // shown above the field
text_modal_buffer = "";             // current edited value
text_modal_max_len = 200;
text_modal_target_struct = undefined; // struct to write into on every keystroke
text_modal_target_key = "";           // key on the struct to write to
text_modal_after = undefined;         // optional zero-arg callback fired on Save
text_modal_x = 0; text_modal_y = 0; text_modal_w = 480; text_modal_h = 140;

// Push Character picker — opens when GM clicks Push on a party row
push_picker_open = false;
push_picker_party_idx = -1;   // index into global.party of the character to push

// Encounter round counter — incremented by gm_enc_new_round, reset by gm_enc_reset
current_round = 1;

// NPCs tab faction filter — set by Factions tab "View" button, cleared via "Clear filter"
gm_npc_filter_faction = "";

// Faction rename closure state — captured before opening the rename modal
faction_rename_old_name = "";
faction_rename_target_idx = -1;
// Staging slots for modals that edit array entries (gear, etc.)
gear_edit_index = -1; gear_edit_stage = undefined;
faction_edit_stage = undefined;
hero_rename_old = "";  // captures the pre-edit name so rename_hero() can do the file move

// GM Sessionlog tab — persistent session-wide history of every roll and chat.
// Loaded from working_directory/session_log.json on boot, appended on each
// new roll/chat (local or remote), saved to disk every append.
session_log_entries = [];            // array of {kind, sender, character, text, total, degree, timestamp_ms, ts_str}
session_log_scroll = 0;              // scroll offset into the entries (newest = index 0)
session_log_max_visible = 18;        // recomputed by the draw function each frame
session_log_chat_buffer = "";        // typing buffer for the GM-side chat field on the Sessionlog tab
session_log_load();                  // pull persistent history off disk if it exists

// Session continuity (v0.62.0) — last_session.json + last_join.json
load_last_session();   // populates global.last_session_data (or undefined)
load_last_join();      // populates global.last_join_data (or undefined)
auto_pushed_this_session = {};  // tracks which players received an auto-push this connection

// Connection state machine — see scr_network.gml header
net_handshake_state = "idle";        // idle / connecting / connected / in_session / error
net_pending_action = undefined;       // queued send waiting for connection complete
net_connect_start_time = 0;           // for connect timeout
net_error_message = "";               // last error string for UI display

// Multiplayer popup UI state
net_host_popup_open = false;
net_join_popup_open = false;
net_join_code_input = "";
net_player_name_input = "";
net_input_focus = ""; // "name" or "code" — which field has keyboard focus

// Tab area bounds (for hover-to-scroll tab switching, set in Draw_64 each frame)
tab_area_x1 = 0;
tab_area_y1 = 0;
tab_area_x2 = 0;
tab_area_y2 = 0;

// Auto-save dirty flag — set true when hero is modified, cleared on save
hero_dirty = false;

// Skill browser
browser_open=false; browser_list=[]; browser_selected=0;
browser_scroll=0; browser_max_visible=22;
browser_flash_timer=0; browser_flash_name="";

// Chargen popup — dropdown system (LEGACY: kept for back-compat with older entry points)
chargen_open=false;

// Chargen WIZARD state — 3-screen flow (Race → Profession → Career)
// chargen_open is the master gate. chargen_step picks which screen to draw.
// Selections accumulate across screens; -1 = not chosen, -2 = user picked Random panel.
chargen_step              = 0;     // 0=race, 1=profession, 2=career
chargen_pick_species      = -1;
chargen_pick_prof         = -1;
chargen_pick_career       = -1;
chargen_pick_sec_prof     = -1;    // for Diplomat
chargen_pick_sec_career   = -1;
chargen_show_diplomat_sub = false;
chargen_career_scroll     = 0;
chargen_hover_species     = -1;    // for the center panel detail text on Screen 1

// Build option lists from loaded data
var _sp_opts = ["Random"];
for (var _i=0;_i<array_length(global.species_data);_i++) array_push(_sp_opts, global.species_data[_i].name);
var _pr_opts = ["Random"];
for (var _i=0;_i<array_length(global.professions);_i++) array_push(_pr_opts, global.professions[_i].name);
var _sec_pr_opts = ["Random"];
for (var _i=0;_i<array_length(global.professions);_i++) { if (global.professions[_i].name != "Diplomat") array_push(_sec_pr_opts, global.professions[_i].name); }

// Callbacks: profession change rebuilds career list
var _rebuild_careers = function(_dd_self, _val) {
	obj_game.dd.career.set_options(["Random"]);
	if (_val > 0) { var _n = get_career_names_for_profession(_val-1); for (var _j=0;_j<array_length(_n);_j++) array_push(obj_game.dd.career.options, _n[_j]); }
};
var _rebuild_sec_careers = function(_dd_self, _val) {
	obj_game.dd.sec_career.set_options(["Random"]);
	var _sm = [-1,0,2,3,4]; if (_val > 0 && _val < array_length(_sm)) { var _n = get_career_names_for_profession(_sm[_val]); for (var _j=0;_j<array_length(_n);_j++) array_push(obj_game.dd.sec_career.options, _n[_j]); }
};

dd = {
	species:    dropdown("dd_species",    "Species:",    _sp_opts,      99, undefined),
	prof:       dropdown("dd_prof",       "Profession:", _pr_opts,      99, _rebuild_careers),
	career:     dropdown("dd_career",     "Career:",     ["Random"],    8,  undefined),
	sec_prof:   dropdown("dd_sec_prof",   "2nd Prof:",   _sec_pr_opts,  99, _rebuild_sec_careers),
	sec_career: dropdown("dd_sec_career", "2nd Career:", ["Random"],    8,  undefined)
};
chargen_dds = [dd.species, dd.prof, dd.career, dd.sec_prof, dd.sec_career];

// Button rects
btn = {};

// Apply saved colorblind mode (after colors are initialized)
if (colorblind_mode != "normal") apply_color_profile(colorblind_mode);
