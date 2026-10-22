#!/bin/bash
# crash-install.sh — drive the REAL ./setup files, and kill it in the middle.
#
#   crash-install.sh <repo> <crash-after-op|0> <workdir>
#
# Installs the repo into a throwaway HOME with a PATH shim in front of the
# filesystem commands. The shim counts every copy/mkdir/rm/chmod the
# installer makes; when the count reaches the given number it kills the
# installer, leaving the half-finished state on disk. <0> means "no crash".
#
# Prints, on stdout, one line per observation, so the caller can read the
# result without re-deriving it.
set -u
REPO=$(cd "${1:?repo}" && pwd)
CRASH_AFTER=${2:-0}
WORK=${3:?workdir}
SHIM="$WORK/shim"
COUNTER="$WORK/counter"

rm -rf "$WORK"
mkdir -p "$SHIM" "$WORK/home"
: > "$COUNTER"

# The shim: count the operation, and kill the installer when the budget runs
# out. It kills its own parent, which is the installer's shell, so the
# installer dies mid-run with no chance to tidy up.
for cmd in cp mkdir rm chmod ln; do
    real=/usr/bin/$cmd
    [ -x "$real" ] || real=/bin/$cmd
    cat > "$SHIM/$cmd" <<SHIMEOF
#!/bin/sh
n=\$(cat "$COUNTER" 2>/dev/null || echo 0)
n=\$((n+1))
echo "\$n" > "$COUNTER"
if [ "$CRASH_AFTER" -gt 0 ] && [ "\$n" -ge "$CRASH_AFTER" ]; then
    kill -TERM "\$PPID" 2>/dev/null
    sleep 1
    exit 143
fi
exec "$real" "\$@"
SHIMEOF
    chmod +x "$SHIM/$cmd"
done

export CRASH_COUNTER="$COUNTER"
run_install() {
    PATH="$SHIM:$PATH" HOME="$WORK/home" \
        XDG_STATE_HOME="$WORK/home/.local/state" \
        XDG_DATA_HOME="$WORK/home/.local/share" \
        sh "$REPO/setup" files >"$WORK/install-$1.log" 2>&1
    echo $?
}

rc=$(run_install crash)
ops=$(cat "$COUNTER" 2>/dev/null || echo 0)
echo "crash_rc=$rc ops=$ops"

# What the manifest says, and whether every path in it exists.
manifest="$WORK/home/.local/state/notch/files"
missing=0
if [ -f "$manifest" ]; then
    while read -r rel; do
        [ -z "${rel:-}" ] && continue
        [ -e "$WORK/home/$rel" ] || { echo "manifest_lies=$rel"; missing=$((missing+1)); }
    done < "$manifest"
fi
echo "manifest_missing=$missing"
