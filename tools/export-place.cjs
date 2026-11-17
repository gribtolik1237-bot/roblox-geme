// Usage: node tools/export-place.cjs --mcp "C:/.../StudioMCP.exe"
// Reads the TRAP LAB Edit datamodel through the installed official MCP server.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const readline = require('node:readline');
const { spawn } = require('node:child_process');

const repo = path.resolve(__dirname, '..');
const executable = process.argv[process.argv.indexOf('--mcp') + 1];
if (!process.argv.includes('--mcp') || !fs.existsSync(executable)) {
  throw new Error('Supply --mcp with the installed StudioMCP.exe path');
}
const child = spawn(executable, [], { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
const pending = new Map();
let sequence = 0;
readline.createInterface({ input: child.stdout }).on('line', line => {
  let message;
  try { message = JSON.parse(line); } catch { return; }
  const job = pending.get(message.id);
  if (!job) return;
  clearTimeout(job.timer);
  pending.delete(message.id);
  if (message.error) job.reject(new Error(JSON.stringify(message.error)));
  else job.resolve(message.result);
});
child.stderr.on('data', () => {});
function failPending(error) {
  for (const job of pending.values()) { clearTimeout(job.timer); job.reject(error); }
  pending.clear();
}
child.on('error', failPending);
child.on('exit', code => failPending(new Error(`Studio MCP exited (${code})`)));
function rpc(method, params) {
  return new Promise((resolve, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`${method} timed out`)); }, 55000);
    pending.set(id, { resolve, reject, timer });
    child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
  });
}
async function call(name, args) {
  const result = await rpc('tools/call', { name, arguments: args });
  if (result.isError) throw new Error(JSON.stringify(result));
  const text = result.content.filter(item => item.type === 'text').map(item => item.text).join('\n');
  return JSON.parse(text);
}
const inventoryCode = `
local function checksum(source)
  local a, b = 1, 0
  for i = 1, #source do a = (a + string.byte(source, i)) % 65521 b = (b + a) % 65521 end
  return b * 65536 + a
end
local rows = {}
for _, rootName in {"ReplicatedStorage", "ReplicatedFirst", "ServerScriptService", "ServerStorage", "StarterPlayer", "StarterGui", "StarterPack", "Workspace"} do
  for _, object in game:GetService(rootName):GetDescendants() do
    if object:IsA("LuaSourceContainer") then
      local parts = {} local current = object
      while current ~= game do table.insert(parts, 1, current.Name) current = current.Parent end
      local source = object.Source
      table.insert(rows, {parts=parts, path=table.concat(parts,"/"), class=object.ClassName, bytes=#source, checksum=checksum(source)})
    end
  end
end
table.sort(rows, function(a,b) return a.path < b.path end)
return game:GetService("HttpService"):JSONEncode({placeId=game.PlaceId, version=game.PlaceVersion, scripts=rows})
`;
function checksum(buffer) {
  let a = 1, b = 0;
  for (const byte of buffer) { a = (a + byte) % 65521; b = (b + a) % 65521; }
  return b * 65536 + a;
}
function localPath(row) {
  for (const part of row.parts) {
    if (!part || part === '.' || part === '..' || /[<>:"/\\|?*\x00-\x1f]/.test(part) || /[. ]$/.test(part)) {
      throw new Error(`Unsupported Studio name: ${row.path}`);
    }
  }
  const suffix = { Script: '.server.luau', LocalScript: '.client.luau', ModuleScript: '.luau' }[row.class];
  if (!suffix) throw new Error(`Unsupported class: ${row.class}`);
  return row.parts.join('/') + suffix;
}
async function main() {
  await rpc('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'trap-lab-export', version: '1.0' } });
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n');
  const instances = await call('list_roblox_studios', {});
  const matches = instances.studios.filter(studio => studio.placeId === 135937017652181 && studio.mode === 'Edit');
  if (matches.length !== 1) throw new Error(`Expected one TRAP LAB Edit session, found ${matches.length}`);
  const studioId = matches[0].id;
  // Discovery provides available datamodel state. All following calls target Edit.
  const execute = code => call('execute_luau', { studio_id: studioId, datamodel_type: 'Edit', code });
  const before = await execute(inventoryCode);
  const names = before.scripts.map(row => localPath(row).toLowerCase());
  if (new Set(names).size !== names.length) throw new Error('Duplicate or case-colliding script paths');
  const batches = [];
  let batch = [], size = 0;
  for (const row of before.scripts) {
    if (row.bytes > 48000) throw new Error(`Script exceeds batch limit, export in source slices: ${row.path}`);
    if (size + row.bytes > 48000) { batches.push(batch); batch = []; size = 0; }
    batch.push(row); size += row.bytes;
  }
  if (batch.length) batches.push(batch);
  const sources = new Map();
  for (let index = 0; index < batches.length; index++) {
    const encodedPaths = JSON.stringify(batches[index].map(row => row.parts));
    // JSON is embedded as a JSON-escaped Luau string, never as executable Source.
    const code = `local paths = game:GetService("HttpService"):JSONDecode(${JSON.stringify(encodedPaths)})
local rows = {} for _, parts in paths do local object = game for _, name in parts do object = object:FindFirstChild(name) assert(object, "Missing script") end table.insert(rows, {path=table.concat(parts,"/"),source=object.Source}) end
return game:GetService("HttpService"):JSONEncode(rows)`;
    for (const row of await execute(code)) sources.set(row.path, row.source);
    console.log(`Read batch ${index + 1}/${batches.length}`);
  }
  const after = await execute(inventoryCode);
  if (JSON.stringify(before) !== JSON.stringify(after)) throw new Error('Studio changed during export. Retry a stable snapshot.');
  if (sources.size !== before.scripts.length) throw new Error('Incomplete source response');
  const manifest = { exportedAt: new Date().toISOString(), placeId: before.placeId, placeVersion: before.version,
    source: 'Live Studio Edit datamodel; Source includes current editor state',
    verification: 'Inventory and Adler-32 before/after export, UTF-8 byte counts, local SHA-256',
    scope: 'LuaSourceContainer under the eight game services listed in export-place.cjs; geometry and assets are separate', scripts: [] };
  for (const row of before.scripts) {
    const buffer = Buffer.from(sources.get(row.path), 'utf8');
    if (buffer.length !== row.bytes || checksum(buffer) !== row.checksum) throw new Error(`Source verification failed: ${row.path}`);
    manifest.scripts.push({ studioPath: row.path, file: localPath(row), class: row.class, bytes: row.bytes,
      adler32: row.checksum, sha256: crypto.createHash('sha256').update(buffer).digest('hex') });
  }
  // Verify everything before changing the export. The manifest is written last.
  // On a partial filesystem failure the old manifest exposes the mismatch, and rerunning is safe.
  for (const row of manifest.scripts) {
    const destination = path.join(repo, 'place', row.file);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.writeFileSync(destination, sources.get(row.studioPath), 'utf8');
  }
  fs.writeFileSync(path.join(repo, 'place/EXPORT_MANIFEST.json'), JSON.stringify(manifest, null, 2) + '\n');
  console.log(`Verified ${manifest.scripts.length} scripts from Studio version ${before.version}. Update EXPORT_STATUS after checking git diff.`);
}
main().catch(error => { console.error(error.message); process.exitCode = 1; }).finally(() => child.kill());
