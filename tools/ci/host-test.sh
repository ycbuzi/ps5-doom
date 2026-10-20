#!/usr/bin/env bash
# Starts Freedoom: Phase 2 with a one-lump test add-on (a title in four flat colours) on the host
# build: named by the plan, chosen in the launcher, and left out as a control. Runs in the build image.
set -euo pipefail
cd "$(dirname "$0")/../.."

test=build/test
wads=$test/wads
save=$test/save
out=$test/out
bin=build/host/bin/doom
freedoom=https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip
freedoom_sha256=3f9b264f3e3ce503b4fb7f6bdcb1f419d93c7b546f4df3e874dd878db9688f59

rm -rf "$test"
mkdir -p "$wads/addons" "$save" "$out/plan" "$out/launcher" "$out/plain"
wget -q -O "$test/freedoom.zip" "$freedoom"
echo "$freedoom_sha256  $test/freedoom.zip" | sha256sum --check --quiet
unzip -q -j "$test/freedoom.zip" freedoom-0.13.0/freedoom2.wad -d "$wads"
python3 tools/ci/make-test-addon.py "$wads/freedoom2.wad" "$wads/addons/anyps5-test.wad" "$test/addon.json" > /dev/null

run() {
    local name=$1
    shift
    if ! env DOOM_WADDIR="$wads" DOOM_SAVEDIR="$save" DOOM_OUT="$out/$name" "$@" "$bin" \
            > "$out/$name/stdout.txt" 2> "$out/$name/stderr.txt"; then
        echo "$name: doom failed"
        tail -n 20 "$out/$name/stderr.txt"
        return 1
    fi
    grep "^launcher: \|^import: " "$out/$name/stderr.txt" || true
}

echo "== plan: the game and the add-on named"
run plan DOOM_IWAD=freedoom2.wad DOOM_ADDON=anyps5-test.wad DOOM_CAPTURE=100 DOOM_FRAMES=110
grep -q "^launcher: starting .* with .*anyps5-test.wad" "$out/plan/stderr.txt"
python3 tools/ci/check-frame.py "$out/plan/frame00100.raw" "$test/addon.json"

echo "== launcher: the game's row, then the add-on under it"
run launcher DOOM_INPUT="20:CROSS:3;50:DOWN:3;80:CROSS:3" DOOM_CAPTURE=60,200 DOOM_FRAMES=210
python3 tools/ci/check-frame.py "$out/launcher/frame00200.raw" "$test/addon.json"
grep -qx "addon anyps5-test.wad" "$save/launcher.cfg"

echo "== plain: the game alone keeps its own title"
run plain DOOM_IWAD=freedoom2.wad DOOM_CAPTURE=100 DOOM_FRAMES=110
if python3 tools/ci/check-frame.py "$out/plain/frame00100.raw" "$test/addon.json" > /dev/null 2>&1; then
    echo "the add-on's title showed without the add-on"
    exit 1
fi
echo "host tests passed"
