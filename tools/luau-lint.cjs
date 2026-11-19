// Local Luau lint over place/ with the downloaded luau-analyze (see docs/TOOLS.md).
// Usage: node tools/luau-lint.cjs [path-to-luau-analyze.exe]
// Output: work/luau-lint.txt (lint warnings only) and a count per rule. Type errors are dropped on purpose:
// this analyzer build has no Roblox definitions option, so every Vector3/game/Enum shows as "Unknown global".
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const repo = path.resolve(__dirname, '..');
const exe = process.argv[2] || 'C:/Users/yarik/tools/luau/0.747/luau-analyze.exe';
if (!fs.existsSync(exe)) throw new Error('luau-analyze not found: ' + exe + ' (see docs/TOOLS.md)');
function walk(dir, out) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out); else if (e.name.endsWith('.luau')) out.push(p);
  }
  return out;
}
const files = walk(path.join(repo, 'place'), []).map(f => path.relative(repo, f).split(String.fromCharCode(92)).join('/'));
const r = spawnSync(exe, ['--formatter=gnu', ...files], { cwd: repo, encoding: 'utf8', maxBuffer: 1 << 26 });
const lines = ((r.stdout || '') + (r.stderr || '')).split(/\r?\n/);
const rule = /^(.+?):(\d+)\.\d+-\d+\.\d+: ([A-Za-z]+): (.*)$/;
const kept = [], counts = {};
for (const l of lines) {
  const m = rule.exec(l);
  if (!m || m[3] === 'TypeError' || m[3] === 'SyntaxError') continue;
  kept.push(l); counts[m[3]] = (counts[m[3]] || 0) + 1;
}
fs.mkdirSync(path.join(repo, 'work'), { recursive: true });
fs.writeFileSync(path.join(repo, 'work', 'luau-lint.txt'), kept.join('\n') + '\n');
console.log('files', files.length, 'lint warnings', kept.length);
for (const [k, v] of Object.entries(counts).sort((a, b) => b[1] - a[1])) console.log(' ', k, v);
