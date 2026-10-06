#!/bin/bash
# Builds the mobile web prototype into build/web/ (open index.html over http(s)).
# The .wasm is split into <15 MB parts and reassembled in the browser, so the build can be
# hosted on file hosts with per-file limits. Requires Godot 4.7.2 + web export template.
set -e
cd "$(dirname "$0")/.."
rm -rf build/web && mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
cd build/web
size=$(stat -c %s index.wasm)
split -b 14000000 -d -a 1 index.wasm index.wasm.part
parts=$(ls index.wasm.part* | wc -l)
rm index.wasm
# Static hosts with strict MIME allowlists serve .wasm but not .pck — ship both as .wasm.
for f in index.wasm.part*; do mv "$f" "${f/index.wasm.part/index.part}.wasm"; done
mv index.pck index.pck.wasm
python3 - "$parts" <<'PY'
import sys, re
n = int(sys.argv[1])
loader = """<script>
(function(){var N=%d,of=window.fetch.bind(window);
window.fetch=function(u,o){var s=String(u&&u.url||u);
 if(/\\.wasm(\\?|$)/.test(s)){var base=s.split('?')[0];
  var stem=base.replace(/\.wasm$/,'');
  return Promise.all(Array.from({length:N},function(_,i){return of(stem+'.part'+i+'.wasm').then(function(r){if(!r.ok)throw new Error('part '+i);return r.arrayBuffer();});}))
  .then(function(b){return new Response(new Blob(b,{type:'application/wasm'}),{status:200,headers:{'Content-Type':'application/wasm'}});});}
 if(/\.pck(\?|$)/.test(s)){return of(s.split('?')[0]+'.wasm',o);}
 return of(u,o);};})();
</script>""" % n
h = open("index.html", encoding="utf-8").read()
h = h.replace("<script src=\"index.js\"></script>", loader + "\n<script src=\"index.js\"></script>", 1)
open("index.html", "w", encoding="utf-8").write(h)
print("wasm parts:", n)
PY
ls -la
