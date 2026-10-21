#!/usr/bin/env bash
# Starts the launcher twice on the host build with a zipped Freedoom: Phase 2 in the WAD folder:
# the first start adds the game, the second (launcher.cfg forgotten) finds it already here.
set -euo pipefail
cd "$(dirname "$0")/../.."

test=build/test
wads=$test/wads
save=$test/save
out=$test/out
bin=build/host/bin/doom

rm -rf "$test"
mkdir -p "$wads" "$save" "$out/first" "$out/second" "$test/stage"
wget -q -O "$test/freedoom.zip" https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip
echo "3f9b264f3e3ce503b4fb7f6bdcb1f419d93c7b546f4df3e874dd878db9688f59  $test/freedoom.zip" | sha256sum --check --quiet
unzip -q -j "$test/freedoom.zip" freedoom-0.13.0/freedoom2.wad -d "$test/stage"
# the launcher draws with the first game's graphics, and the console always ships the shareware
bash tools/fetch-shareware.sh "$wads/doom1.wad"
python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED).write(sys.argv[2], "freedoom2.wad")' "$wads/freedoom2.zip" "$test/stage/freedoom2.wad"

run() {
    local name=$1
    if ! env DOOM_WADDIR="$wads" DOOM_SAVEDIR="$save" DOOM_OUT="$out/$name" DOOM_FRAMES=300 "$bin" \
            > "$out/$name/stdout.txt" 2> "$out/$name/stderr.txt"; then
        echo "$name: doom failed"
        tail -n 20 "$out/$name/stderr.txt"
        return 1
    fi
    grep "^launcher: \|^import: " "$out/$name/stderr.txt" || true
}

echo "== first start: the archive is new"
run first
grep -q "^launcher: added FREEDOOM: PHASE 2$" "$out/first/stderr.txt"
! grep -q "^launcher: already here" "$out/first/stderr.txt"
test -f "$wads/freedoom2.wad"

echo "== second start, launcher.cfg forgotten: the archive is pending again, its game already here"
rm -f "$save/launcher.cfg"
run second
grep -q "^launcher: already here: FREEDOOM: PHASE 2$" "$out/second/stderr.txt"
! grep -q "^launcher: added" "$out/second/stderr.txt"
echo "host test passed"
