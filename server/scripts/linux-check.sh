#!/bin/sh
# linux-check (FR-53.35): the release gate. In node:26-trixie-slim (/bin/sh is dash, awk is mawk)
# it runs sdd's test suite (with the `time` package t_perf times with), the server's tests and
# the smoke test against the packed tarball. Any failure exits non-zero: then nothing is published.
# Needs Docker and the network (apt, npm). The checkout is mounted read-only and copied.
set -eu
repo=$(cd "$(dirname "$0")/../.." && pwd -P)
image=${SDD_LINUX_IMAGE:-node:26-trixie-slim}
exec docker run --rm -e DEBIAN_FRONTEND=noninteractive -e npm_config_update_notifier=false -v "$repo:/src:ro" "$image" sh -euc '
	apt-get update -qq
	apt-get install -y -qq --no-install-recommends git openssh-client openssh-server ca-certificates curl jq time >/dev/null
	mkdir -p /run/sshd
	ls -l /bin/sh /usr/bin/awk /etc/alternatives/awk
	git config --global user.name linux-check
	git config --global user.email linux-check@example.com
	git config --global init.defaultBranch main
	git config --global --add safe.directory "*"
	mkdir /work
	(cd /src && git ls-files -z -co --exclude-standard | tar --null -T - -cf -) | tar -xf - -C /work
	cd /work
	git init -q && git add -A && git commit -qm linux-check
	echo "== sdd suite (dash, mawk)"
	sh tests/run.sh /bin/sh
	echo "== server tests"
	cd server
	npm ci --no-audit --no-fund
	npm test
	echo "== smoke"
	sh scripts/smoke.sh
'
