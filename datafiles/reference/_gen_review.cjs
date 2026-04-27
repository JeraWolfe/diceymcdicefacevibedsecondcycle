// Generates codebase + function review snapshot files for any version.
// Walks every .gml file under scripts/ and objects/obj_game/, parses function
// definitions + their /// doc comments, emits both .txt and .json formats.
// Also produces a codebase overview with file inventory and state machine map.
// Run with: node datafiles/reference/_gen_review.cjs <PRE|POST> [version]
//   Examples:
//     node _gen_review.cjs PRE v0.62
//     node _gen_review.cjs POST v0.62
// Default version is v0.61 for back-compat with the original script.

const fs = require('fs');
const path = require('path');

const ROOT = 'C:/Users/calvin/GameMakerProjects/diceymcdicefacevibed';
const STAGE = (process.argv[2] || 'PRE').toUpperCase();
const VERSION = process.argv[3] || 'v0.61';

const SCRIPT_FILES = [
  'scripts/scr_alternity_statblock/scr_alternity_statblock.gml',
  'scripts/scr_chargen/scr_chargen.gml',
  'scripts/scr_data_loader/scr_data_loader.gml',
  'scripts/scr_dice/scr_dice.gml',
  'scripts/scr_draw_tabs/scr_draw_tabs.gml',
  'scripts/scr_network/scr_network.gml',
  'scripts/scr_skill_costs/scr_skill_costs.gml',
  'scripts/scr_tab_handlers/scr_tab_handlers.gml',
  'scripts/scr_ui_helpers/scr_ui_helpers.gml',
];

const OBJ_EVENTS = [
  'objects/obj_game/Create_0.gml',
  'objects/obj_game/Step_0.gml',
  'objects/obj_game/Draw_64.gml',
  'objects/obj_game/Other_68.gml',
];

const DATAFILES = [
  'datafiles/careers.json',
  'datafiles/changelog.json',
  'datafiles/config.json',
  'datafiles/equipment.json',
  'datafiles/fx_database.json',
  'datafiles/keyword_tree.json',
  'datafiles/names.json',
  'datafiles/npc_templates.json',
  'datafiles/professions.json',
  'datafiles/programs.json',
  'datafiles/skills.json',
  'datafiles/species.json',
  'datafiles/voss.json',
  'datafiles/reference/Master-Sidebar.json',
  'datafiles/tables/combat_tables.json',
  'datafiles/tables/gm_tables.json',
  'datafiles/tables/skill_rank_benefits.json',
];

// ============================================================
// Function parser — extracts each function with its preceding /// comments
// ============================================================
function parseGmlFunctions(filepath) {
  const abs = path.join(ROOT, filepath);
  if (!fs.existsSync(abs)) return [];
  const text = fs.readFileSync(abs, 'utf8');
  const lines = text.split('\n');
  const fns = [];
  let pendingDoc = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();
    if (trimmed.startsWith('///')) {
      pendingDoc.push(trimmed.substring(3).trim());
      continue;
    }
    const fnMatch = line.match(/^function\s+(\w+)\s*\(([^)]*)\)/);
    if (fnMatch) {
      fns.push({
        name: fnMatch[1],
        signature: `${fnMatch[1]}(${fnMatch[2]})`,
        params: fnMatch[2].split(',').map(p => p.trim()).filter(Boolean),
        line: i + 1,
        doc: pendingDoc.join(' ').trim(),
        docLines: [...pendingDoc],
      });
      pendingDoc = [];
    } else if (trimmed && !trimmed.startsWith('//')) {
      // Reset pending doc if we hit non-comment non-function content
      if (!trimmed.startsWith('#') && trimmed !== '') pendingDoc = [];
    }
  }
  return fns;
}

// ============================================================
// State machine inventory — finds *_open booleans
// ============================================================
function findStateMachines() {
  const text = fs.readFileSync(path.join(ROOT, 'objects/obj_game/Create_0.gml'), 'utf8');
  const lines = text.split('\n');
  const states = [];
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^\s*(\w+_open)\s*=\s*(.+?);/);
    if (m) {
      states.push({
        name: m[1],
        initial: m[2].split('//')[0].trim(),
        line: i + 1,
        comment: (lines[i].split('//')[1] || '').trim(),
      });
    }
  }
  return states;
}

// ============================================================
// Datafile inventory — sizes, line counts, top-level keys
// ============================================================
function inventoryDatafile(filepath) {
  const abs = path.join(ROOT, filepath);
  if (!fs.existsSync(abs)) return null;
  const stat = fs.statSync(abs);
  const content = fs.readFileSync(abs, 'utf8');
  const info = {
    path: filepath,
    bytes: stat.size,
    lines: content.split('\n').length,
    schema: 'unknown',
    entry_count: 0,
    top_keys: [],
  };
  try {
    const json = JSON.parse(content);
    if (Array.isArray(json)) {
      info.schema = 'array';
      info.entry_count = json.length;
    } else if (typeof json === 'object') {
      info.schema = 'object';
      info.top_keys = Object.keys(json).filter(k => !k.startsWith('_')).slice(0, 20);
      // Count entries field if present (e.g. changelog)
      if (json.entries && Array.isArray(json.entries)) {
        info.entry_count = json.entries.length;
      } else if (info.top_keys.length > 0) {
        info.entry_count = info.top_keys.length;
      }
    }
  } catch (e) {
    info.schema = 'parse_error: ' + e.message.substring(0, 100);
  }
  return info;
}

// ============================================================
// Build the function review
// ============================================================
function buildFunctionReview() {
  const review = { stage: STAGE, generated_at: new Date().toISOString(), files: [] };
  let totalFns = 0;
  for (const sf of SCRIPT_FILES) {
    const fns = parseGmlFunctions(sf);
    totalFns += fns.length;
    const abs = path.join(ROOT, sf);
    const lineCount = fs.readFileSync(abs, 'utf8').split('\n').length;
    review.files.push({
      file: sf,
      line_count: lineCount,
      function_count: fns.length,
      functions: fns,
    });
  }
  // Object events get listed but with no function definitions (events use bare GML)
  for (const oe of OBJ_EVENTS) {
    const abs = path.join(ROOT, oe);
    if (!fs.existsSync(abs)) continue;
    const lineCount = fs.readFileSync(abs, 'utf8').split('\n').length;
    review.files.push({
      file: oe,
      line_count: lineCount,
      function_count: 0,
      functions: [],
      event_type: oe.split('/').pop().replace('.gml', ''),
    });
  }
  review.total_functions = totalFns;
  return review;
}

// ============================================================
// Build the codebase review
// ============================================================
function buildCodebaseReview() {
  const review = { stage: STAGE, generated_at: new Date().toISOString() };

  // File inventory
  review.scripts = SCRIPT_FILES.map(sf => {
    const abs = path.join(ROOT, sf);
    const text = fs.readFileSync(abs, 'utf8');
    const fns = parseGmlFunctions(sf);
    return {
      path: sf,
      lines: text.split('\n').length,
      bytes: fs.statSync(abs).size,
      function_count: fns.length,
    };
  });

  review.object_events = OBJ_EVENTS.map(oe => {
    const abs = path.join(ROOT, oe);
    if (!fs.existsSync(abs)) return null;
    const text = fs.readFileSync(abs, 'utf8');
    return {
      path: oe,
      event: oe.split('/').pop().replace('.gml', ''),
      lines: text.split('\n').length,
      bytes: fs.statSync(abs).size,
    };
  }).filter(Boolean);

  // Datafile inventory
  review.datafiles = DATAFILES.map(inventoryDatafile).filter(Boolean);

  // State machines
  review.state_machines = findStateMachines();

  // Tab system map
  review.tab_system = {
    player_tabs: {
      0: 'Character',
      1: 'Equipment',
      2: 'Combat',
      3: 'Psionics',
      4: 'Perks/Flaws',
      5: 'Cybertech',
      6: 'Roll Log',
      7: 'Info',
      8: 'Grid',
      9: 'Aura/Lore',
    },
    gm_tabs: {
      0: 'Party',
      1: 'NPCs',
      2: 'Encounter',
      3: 'Campaign',
      4: 'Sessionlog',
      5: 'Resources',
    },
  };

  // Build version (top of changelog)
  try {
    const cl = JSON.parse(fs.readFileSync(path.join(ROOT, 'datafiles/changelog.json'), 'utf8'));
    review.build_version = {
      latest: cl.entries[0].version,
      title: cl.entries[0].title,
      date: cl.entries[0].date,
      total_entries: cl.entries.length,
    };
  } catch (e) {
    review.build_version = { error: e.message };
  }

  // Multiplayer relay info
  review.multiplayer = {
    relay_host: 'centerbeam.proxy.rlwy.net',
    relay_port: 23003,
    protocol_version: 1,
    message_types: ['CREATE','CREATED','JOIN_REQ','JOIN_OK','JOIN_FAIL','PLAYER_LIST','ROLL_RESULT','CHARACTER_SYNC','CHAR_REQUEST','CHAT','GM_STATUS','HEARTBEAT','MAP_TOKEN_MOVE','MAP_TOKEN_ADD','MAP_TOKEN_REMOVE','MAP_STATE_REQUEST','MAP_STATE_FULL','CHAR_TOKEN_LINK','ROLL_AT_TOKEN'],
    server: 'relay_server/server.js (Node.js TCP)',
  };

  // Persistent file paths
  review.persistence = {
    working_directory: '%LOCALAPPDATA%/diceymcdicefacevibed/',
    files_written_to_working_dir: [
      'characters/<sanitized_name>.json',
      'characters/<sanitized_name>_rolllog.log',
      'recent_characters.json',
      'campaign.json',
      'session_log.json',
      'changelog.json (cache, can be stale)',
    ],
    bundled_datafiles: 'embedded via .yyp IncludedFiles, accessible via relative paths',
  };

  return review;
}

// ============================================================
// TXT formatters
// ============================================================
function formatFunctionReviewTxt(review) {
  const out = [];
  out.push('============================================================');
  out.push(`DICEYMCDICEFACES — FUNCTION REVIEW (${review.stage})`);
  out.push(`Generated: ${review.generated_at}`);
  out.push(`Total functions: ${review.total_functions}`);
  out.push('============================================================');
  out.push('');
  for (const f of review.files) {
    out.push('');
    out.push('=== ' + f.file + ' ===');
    out.push(`    ${f.line_count} lines, ${f.function_count} functions`);
    out.push('');
    if (f.functions.length === 0 && f.event_type) {
      out.push(`    [Object event: ${f.event_type}] (no top-level functions)`);
      continue;
    }
    for (const fn of f.functions) {
      out.push(`  L${fn.line}  ${fn.signature}`);
      if (fn.doc) {
        // Wrap doc to ~100 chars per line
        const words = fn.doc.split(' ');
        let line = '        ';
        for (const w of words) {
          if (line.length + w.length + 1 > 100) {
            out.push(line);
            line = '        ' + w;
          } else {
            line += (line === '        ' ? '' : ' ') + w;
          }
        }
        if (line.trim()) out.push(line);
      }
      out.push('');
    }
  }
  return out.join('\n');
}

function formatCodebaseReviewTxt(review) {
  const out = [];
  out.push('============================================================');
  out.push(`DICEYMCDICEFACES — CODEBASE REVIEW (${review.stage})`);
  out.push(`Generated: ${review.generated_at}`);
  out.push('============================================================');
  out.push('');

  if (review.build_version) {
    out.push('=== BUILD VERSION ===');
    out.push(`Latest: v${review.build_version.latest} — ${review.build_version.title}`);
    out.push(`Date: ${review.build_version.date}`);
    out.push(`Total changelog entries: ${review.build_version.total_entries}`);
    out.push('');
  }

  out.push('=== SCRIPT FILES ===');
  let scriptTotal = 0;
  let fnTotal = 0;
  for (const s of review.scripts) {
    out.push(`  ${s.path.padEnd(60)} ${String(s.lines).padStart(6)} lines  ${String(s.function_count).padStart(4)} fns  ${s.bytes} bytes`);
    scriptTotal += s.lines;
    fnTotal += s.function_count;
  }
  out.push(`  ${'TOTAL'.padEnd(60)} ${String(scriptTotal).padStart(6)} lines  ${String(fnTotal).padStart(4)} fns`);
  out.push('');

  out.push('=== OBJECT EVENTS ===');
  let objTotal = 0;
  for (const o of review.object_events) {
    out.push(`  ${o.path.padEnd(60)} ${String(o.lines).padStart(6)} lines`);
    objTotal += o.lines;
  }
  out.push(`  ${'TOTAL'.padEnd(60)} ${String(objTotal).padStart(6)} lines`);
  out.push('');

  out.push('=== DATAFILES ===');
  for (const d of review.datafiles) {
    let info = `${d.bytes} bytes, ${d.lines} lines, ${d.schema}`;
    if (d.entry_count) info += `, ${d.entry_count} entries`;
    out.push(`  ${d.path.padEnd(50)} ${info}`);
    if (d.top_keys && d.top_keys.length > 0) {
      out.push(`    keys: ${d.top_keys.join(', ')}`);
    }
  }
  out.push('');

  out.push('=== STATE MACHINES (modal/popup state vars on obj_game) ===');
  for (const s of review.state_machines) {
    out.push(`  L${s.line}  ${s.name} = ${s.initial}` + (s.comment ? `  // ${s.comment}` : ''));
  }
  out.push('');

  out.push('=== TAB SYSTEM ===');
  out.push('  Player tabs (current_tab 0-9):');
  for (const [k, v] of Object.entries(review.tab_system.player_tabs)) {
    out.push(`    ${k}: ${v}`);
  }
  out.push('  GM tabs (gm_tab 0-5):');
  for (const [k, v] of Object.entries(review.tab_system.gm_tabs)) {
    out.push(`    ${k}: ${v}`);
  }
  out.push('');

  out.push('=== MULTIPLAYER ===');
  out.push(`  Relay: ${review.multiplayer.relay_host}:${review.multiplayer.relay_port}`);
  out.push(`  Protocol version: ${review.multiplayer.protocol_version}`);
  out.push(`  Server: ${review.multiplayer.server}`);
  out.push(`  Message types: ${review.multiplayer.message_types.length}`);
  out.push('');
  for (const m of review.multiplayer.message_types) {
    out.push(`    - ${m}`);
  }
  out.push('');

  out.push('=== PERSISTENCE ===');
  out.push(`  Working directory: ${review.persistence.working_directory}`);
  out.push(`  Files written to working_directory:`);
  for (const f of review.persistence.files_written_to_working_dir) {
    out.push(`    - ${f}`);
  }
  out.push(`  Bundled datafiles: ${review.persistence.bundled_datafiles}`);
  out.push('');

  return out.join('\n');
}

// ============================================================
// Run
// ============================================================
const fnReview = buildFunctionReview();
const cbReview = buildCodebaseReview();

const refDir = path.join(ROOT, 'datafiles/reference');
fs.writeFileSync(path.join(refDir, `FUNCTION_REVIEW_${VERSION}_${STAGE}.json`), JSON.stringify(fnReview, null, 2));
fs.writeFileSync(path.join(refDir, `FUNCTION_REVIEW_${VERSION}_${STAGE}.txt`), formatFunctionReviewTxt(fnReview));
fs.writeFileSync(path.join(refDir, `CODEBASE_REVIEW_${VERSION}_${STAGE}.json`), JSON.stringify(cbReview, null, 2));
fs.writeFileSync(path.join(refDir, `CODEBASE_REVIEW_${VERSION}_${STAGE}.txt`), formatCodebaseReviewTxt(cbReview));

console.log(`Wrote 4 files (${VERSION}_${STAGE}):`);
console.log(`  FUNCTION_REVIEW_${VERSION}_${STAGE}.json — ${fnReview.total_functions} functions across ${fnReview.files.length} files`);
console.log(`  FUNCTION_REVIEW_${VERSION}_${STAGE}.txt`);
console.log(`  CODEBASE_REVIEW_${VERSION}_${STAGE}.json — ${cbReview.scripts.length} scripts, ${cbReview.datafiles.length} datafiles, ${cbReview.state_machines.length} state machines`);
console.log(`  CODEBASE_REVIEW_${VERSION}_${STAGE}.txt`);
