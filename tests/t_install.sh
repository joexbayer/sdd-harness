# FR-59.1 install.sh puts a release's .sdd/ in the data folder and links sdd into the bin folder;
# FR-59.2 it says how to add the bin folder to PATH; FR-59.3 a rerun repoints the link; FR-59.4 a
# failed download changes nothing.
. "$SRC/tests/lib.sh"
mkdir -p "$T/dl"
for v in v0.1.0 v0.2.0; do git -C "$SRC" archive --prefix="sdd-harness-${v#v}/" HEAD | gzip >"$T/dl/$v.tar.gz"; done
inst() { XDG_DATA_HOME="$T/data" SDD_BIN="$T/bin" SDD_INSTALL_URL="file://$T/dl" "$SH" "$SRC/install.sh" "$@"; }

# FR-59.1, FR-59.2: installed, linked, and told how to reach it.
out=$(inst v0.1.0 2>&1) || fail "install failed: $out"
assert_contains "$out" "installed sdd v0.1.0 in $T/data/sdd/v0.1.0"
assert_contains "$out" 'next: cd your-repo && sdd init && sdd sync claude'
assert_contains "$out" "add $T/bin to your PATH"
assert_eq "$(readlink "$T/bin/sdd")" "$T/data/sdd/v0.1.0/.sdd/bin/sdd"
[ ! -e "$T/data/sdd/v0.1.0/README.md" ] || fail "only .sdd/ is kept"
# The linked command installs into a fresh repo.
mkdir -p "$T/app" && cd "$T/app" && git init -q && echo x >x && git add x && git commit -qm init
out=$("$T/bin/sdd" init 2>&1) || fail "sdd init through the link failed: $out"
assert_file .sdd/bin/sdd
assert_contains "$out" 'installed sdd'

# FR-59.3: another version repoints the link; the old folder stays. On PATH: no hint.
out=$(PATH="$T/bin:$PATH" inst v0.2.0 2>&1) || fail "install v0.2.0 failed: $out"
assert_eq "$(readlink "$T/bin/sdd")" "$T/data/sdd/v0.2.0/.sdd/bin/sdd"
[ -d "$T/data/sdd/v0.1.0/.sdd" ] || fail "v0.1.0 should stay"
assert_not_contains "$out" 'to your PATH'

# FR-59.3: the same version again replaces its folder.
touch "$T/data/sdd/v0.2.0/marker"
inst v0.2.0 >/dev/null 2>&1 || fail "reinstall failed"
[ ! -e "$T/data/sdd/v0.2.0/marker" ] || fail "a rerun should replace the version folder"

# FR-59.4: no curl and no wget: says so and writes nothing.
mkdir -p "$T/nonet" && for c in mktemp rm; do ln -s "$(command -v "$c")" "$T/nonet/$c"; done
out=$(PATH="$T/nonet" XDG_DATA_HOME="$T/data2" SDD_BIN="$T/bin2" "$(command -v "$SH")" "$SRC/install.sh" v0.1.0 2>&1)
assert_eq $? 1 "(no curl or wget)"
assert_contains "$out" 'sdd install: needs curl or wget'
[ ! -e "$T/bin2/sdd" ] || fail "nothing should be linked without a download tool"

# FR-59.4: a missing version fails and touches nothing.
out=$(inst v9.9.9 2>&1)
assert_eq $? 1 "(missing version)"
assert_contains "$out" "sdd install: could not download v9.9.9 from file://$T/dl/v9.9.9.tar.gz"
assert_eq "$(readlink "$T/bin/sdd")" "$T/data/sdd/v0.2.0/.sdd/bin/sdd"
exit 0
