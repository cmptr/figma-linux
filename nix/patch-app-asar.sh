#!/usr/bin/env bash
set -euo pipefail

repo_root="$1"
app_staging_dir="$2"
asar_bin="$3"

cd "$app_staging_dir"

asar_prefix=$(dirname "$(dirname "$asar_bin")")
export NODE_PATH="$asar_prefix/lib/node_modules${NODE_PATH:+:$NODE_PATH}"

rm -rf app.asar.contents
node <<'NODE'
const asar = require('@electron/asar');
const fs = require('fs');
const path = require('path');

const asarPath = 'app.asar';
const outDir = 'app.asar.contents';
const header = JSON.parse(asar.getRawHeader(asarPath).headerString);
const asarBuf = fs.readFileSync(asarPath);
const headerBufSize = asarBuf.readUInt32LE(4);
const dataStart = 8 + headerBufSize;

function walk(files, prefix = '') {
  for (const [name, entry] of Object.entries(files)) {
    const rel = prefix ? `${prefix}/${name}` : name;
    if (entry.files) {
      walk(entry.files, rel);
      continue;
    }
    if (entry.unpacked || entry.size < 0 || entry.offset === undefined) {
      continue;
    }
    const outPath = path.join(outDir, rel);
    fs.mkdirSync(path.dirname(outPath), { recursive: true });
    const size = entry.size;
    const offset = Number(entry.offset || 0);
    const buf = Buffer.alloc(size);
    asarBuf.copy(buf, 0, dataStart + offset, dataStart + offset + size);
    fs.writeFileSync(outPath, buf);
  }
}

fs.mkdirSync(outDir, { recursive: true });
walk(header.files);
NODE

original_main=$(node -e "const pkg = require('./app.asar.contents/package.json'); console.log(pkg.main);")
cp "$repo_root/scripts/frame-fix-wrapper.js" app.asar.contents/frame-fix-wrapper.js
cat > app.asar.contents/frame-fix-entry.js <<EOF
// Load frame fix first
require('./frame-fix-wrapper.js');
// Then load original main
require('./${original_main}');
EOF

main_js='app.asar.contents/main.js'
if [ -f "$main_js" ]; then
  sed -i 's/frame:!1/frame:true/g' "$main_js"
  sed -i 's/frame:!0/frame:true/g' "$main_js"
  sed -i 's/frame[[:space:]]*:[[:space:]]*false/frame:true/g' "$main_js"
  sed -i 's/titleBarStyle:"hidden"/titleBarStyle:"default"/g' "$main_js"
  sed -i 's|process.platform==="win32"&&(this.windowsAppMenu=|process.platform!=="darwin"\&\&(this.windowsAppMenu=|' "$main_js"
fi

shell_js='app.asar.contents/desktop_shell.js'
if [ -f "$shell_js" ]; then
  sed -i 's/frame:!1/frame:true/g' "$shell_js"
  sed -i 's/frame:!0/frame:true/g' "$shell_js"
  win32_shell_var=$(grep -oP '\b\w{2}="win32"===\w\.platform\b' "$shell_js" | head -1 || true)
  if [ -n "$win32_shell_var" ]; then
    var_name=${win32_shell_var%%=*}
    sed -i "s|${win32_shell_var}|${var_name}=\"darwin\"!==e.platform|" "$shell_js"
  fi
fi

shell_html='app.asar.contents/shell.html'
if [ -f "$shell_html" ]; then
  sed -i 's|</head>|<style>\
#__MINIMIZE_CAPTION_BUTTON__,\
#__MAXIMIZE_CAPTION_BUTTON__,\
#__CLOSE_CAPTION_BUTTON__ { display: none !important; }\
</style>\
</head>|' "$shell_html"
fi

node <<'NODE'
const fs = require('fs');
const pkgPath = './app.asar.contents/package.json';
const pkg = require(pkgPath);
pkg.originalMain = pkg.originalMain || pkg.main;
pkg.main = 'frame-fix-entry.js';
fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2));
NODE

cp "$repo_root/scripts/figma-native-stub.js" app.asar.contents/figma-native-stub.js
mkdir -p app.asar.contents/font-enum
for js_file in "$repo_root"/scripts/font-enum/*.js; do
  [ -f "$js_file" ] || continue
  cp "$js_file" app.asar.contents/font-enum/
done

if [ -f "$main_js" ]; then
  sed -i 's|require("./bindings.node")|require("./figma-native-stub.js")|g' "$main_js"
  sed -i 's|require("../build/Debug/bindings.node")|require("./figma-native-stub.js")|g' "$main_js"
  sed -i 's|require("../build/Release/bindings.node")|require("./figma-native-stub.js")|g' "$main_js"
  sed -i 's|require("./desktop_rust.node")|require("./figma-native-stub.js").desktop_rust|g' "$main_js"
  sed -i 's|require("../rust/desktop_rust.node")|require("./figma-native-stub.js").desktop_rust|g' "$main_js"

  node <<'NODE'
const fs = require('fs');
const main_js = 'app.asar.contents/main.js';
let code = fs.readFileSync(main_js, 'utf8');
const pattern = /async handleCommandLineArgs\((\w+)\)\{let (\w+)=(\w+)\.app\.isPackaged\?1:2;if\(\1\.length>\2\)\{let (\w+)=\1\[\2\];if\((\w+)\(\4,\{isExternalOpen:!0\}\)\)return!0;if\((\w+)\.default\.statSync\(\4,\{throwIfNoEntry:!1\}\)\)return await (\w+)\(\4\)\}return!1\}/;
const m = code.match(pattern);
if (!m) {
  console.error('handleCommandLineArgs pattern not found; auth redirects may not work with Linux argv layout');
  process.exit(1);
}
const [fullMatch, arg, , , innerVar, urlFn, statMod, openFn] = m;
const replacement = 'async handleCommandLineArgs(' + arg + '){for(let _i=1;_i<' + arg + '.length;_i++){let ' + innerVar + '=' + arg + '[_i];if(' + innerVar + '.startsWith("-")||' + innerVar + '.endsWith(".asar")||' + innerVar + '.endsWith(".js"))continue;if(' + urlFn + '(' + innerVar + ',{isExternalOpen:!0}))return!0;if(' + statMod + '.default.statSync(' + innerVar + ',{throwIfNoEntry:!1}))return await ' + openFn + '(' + innerVar + ')}return!1}';
code = code.replace(fullMatch, replacement);
fs.writeFileSync(main_js, code);
NODE

  node <<'NODE'
const fs = require('fs');
const main_js = 'app.asar.contents/main.js';
let code = fs.readFileSync(main_js, 'utf8');
const pattern = /this\.electronTray\.setToolTip\((\w+)\.name\),this\.electronTray\.on\("right-click",\(\)=>\{var (\w+);\(\2=this\.electronTray\)==null\|\|\2\.popUpContextMenu\((\w+)\(\)\)\}\)/;
const m = code.match(pattern);
if (m) {
  const [fullMatch, modName, varName, menuFn] = m;
  const replacement = 'this.electronTray.setToolTip(' + modName + '.name),this.electronTray.setContextMenu(' + menuFn + '()),this.electronTray.on("right-click",()=>{var ' + varName + ';(' + varName + '=this.electronTray)==null||' + varName + '.popUpContextMenu(' + menuFn + '())})';
  code = code.replace(fullMatch, replacement);
  fs.writeFileSync(main_js, code);
}
NODE
fi

worker_js='app.asar.contents/bindings_worker.js'
if [ -f "$worker_js" ]; then
  sed -i 's|require("./desktop_rust.node")|require("./figma-native-stub.js").desktop_rust|g' "$worker_js"
  sed -i 's|require("../rust/desktop_rust.node")|require("./figma-native-stub.js").desktop_rust|g' "$worker_js"
fi

rm -f app.asar
"$asar_bin" pack app.asar.contents app.asar
