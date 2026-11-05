#!/bin/sh
# Put sdd on your PATH (FR-59.1):
#   curl -fsSL https://raw.githubusercontent.com/joexbayer/sdd-harness/main/install.sh | sh
#   … | sh -s -- v0.2.0            another version
# Keeps a release's .sdd/ in ${XDG_DATA_HOME:-~/.local/share}/sdd/<version>/ and links
# ${SDD_BIN:-~/.local/bin}/sdd to it. No sudo; nothing else is written. Inside a repo with its own
# .sdd/, the linked command runs that repo's copy. Uninstall: rm ~/.local/bin/sdd and the folder.
set -eu
version=${1:-v0.1.3}
case $version in v*) ;; *) version=v$version ;; esac
url=${SDD_INSTALL_URL:-https://github.com/joexbayer/sdd-harness/archive/refs/tags}/$version.tar.gz
data=${XDG_DATA_HOME:-$HOME/.local/share}/sdd
bin=${SDD_BIN:-$HOME/.local/bin}
die() { printf 'sdd install: %s\n' "$*" >&2; exit 1; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/sdd-install.XXXXXX") || die "could not make a temp folder"
trap 'rm -rf "$tmp"' EXIT
if command -v curl >/dev/null 2>&1; then
	curl -fsSL "$url" -o "$tmp/sdd.tar.gz" 2>/dev/null || die "could not download $version from $url"
elif command -v wget >/dev/null 2>&1; then
	wget -qO "$tmp/sdd.tar.gz" "$url" || die "could not download $version from $url"
else
	die "needs curl or wget"
fi
mkdir "$tmp/x" && tar -xzf "$tmp/sdd.tar.gz" -C "$tmp/x" 2>/dev/null || die "could not unpack $url"
src=
for d in "$tmp"/x/*/.sdd; do [ -x "$d/bin/sdd" ] && src=$d; done
[ -n "$src" ] || die "no .sdd/ in $url"

# Swap in the new folder, then repoint the link (FR-59.3); other versions stay.
mkdir -p "$data" "$bin"
rm -rf "${data:?}/$version.new"
mkdir "$data/$version.new" && mv "$src" "$data/$version.new/.sdd"
rm -rf "${data:?}/${version:?}" && mv "$data/$version.new" "$data/$version"
ln -sf "$data/$version/.sdd/bin/sdd" "$bin/sdd"

echo "installed sdd $version in $data/$version"
case ":$PATH:" in
*":$bin:"*) ;;
*) echo "add $bin to your PATH: export PATH=\"$bin:\$PATH\"" ;; # FR-59.2
esac
echo "next: cd your-repo && sdd init && sdd sync claude"
