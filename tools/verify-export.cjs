const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../place');
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'EXPORT_MANIFEST.json'), 'utf8'));
const expected = new Set();
for (const row of manifest.scripts) {
  const absolute = path.resolve(root, row.file);
  if (!absolute.startsWith(root + path.sep)) throw new Error(`Invalid path: ${row.file}`);
  if (expected.has(row.file)) throw new Error(`Duplicate path: ${row.file}`);
  expected.add(row.file);
  const source = fs.readFileSync(absolute);
  if (source.length !== row.bytes || crypto.createHash('sha256').update(source).digest('hex') !== row.sha256) {
    throw new Error(`Export differs from manifest: ${row.file}`);
  }
}
function inspect(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) inspect(absolute);
    else if (entry.name.endsWith('.luau') && !expected.has(path.relative(root, absolute).split(path.sep).join('/'))) {
      throw new Error(`Untracked by export manifest: ${absolute}`);
    }
  }
}
inspect(root);
console.log(`PASS: ${expected.size} script files match the manifest for Studio version ${manifest.placeVersion}.`);
