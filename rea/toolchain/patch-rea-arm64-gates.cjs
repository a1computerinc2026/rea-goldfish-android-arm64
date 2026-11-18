// Remove REA's unnecessary Linux-x64-only capability gates on arm64.
// The gated implementations are architecture-independent:
//   - EVM uses a bundled WASM (evmole_bg.wasm)
//   - Wakaru is a JS CLI distributed on npm
//   - pwntools/pyelftools/Unicorn are Python packages with arm64 builds
// This patch only widens the host check; it does not fake tool availability.
// Re-run after upgrading rea-agents (npm install -g rea-agents@x.y.z).
const fs = require("node:fs");
const path = require("node:path");

const file = process.argv[2] || "/data/data/com.termux/files/usr/lib/node_modules/rea-agents/dist/cli-runtime/cli.js";
const backup = file + ".arm64-backup";
if (!fs.existsSync(backup)) fs.copyFileSync(file, backup);

let src = fs.readFileSync(file, "utf8");
const names = ["evmHostSupported", "pwntoolsHostSupported", "wakaruHostSupported"];
let changed = 0;
for (const name of names) {
  const from = `${name} = (platform, arch) => platform === "linux" && arch === "x64";`;
  const to = `${name} = (platform, arch) => platform === "linux" && (arch === "x64" || arch === "arm64");`;
  if (src.includes(to)) continue;
  if (!src.includes(from)) {
    console.error(`WARN: gate not found for ${name} (REA version may have changed)`);
    continue;
  }
  src = src.replace(from, to);
  changed++;
}
if (changed > 0) {
  fs.writeFileSync(file, src);
  console.log(`Patched ${changed} host gate(s). Backup: ${backup}`);
} else {
  console.log("No changes needed (already patched or gates not present).");
}
