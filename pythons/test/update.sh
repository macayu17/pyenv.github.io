#!/usr/bin/env bash

set -e

fail() {
  echo "$1" >&2
  exit 1
}

write_meta() {
  cat > binaries/3.14.0-ubuntu-24.04-x86_64.meta <<EOF
# pyenv-binary metadata
version=3.14.0
os=Linux
arch=x86_64
platform=linux-x86_64
distro=ubuntu 24.04
libc=glibc 2.39
build_prefix=/tmp/pyenv/versions/3.14.0-ubuntu-24.04-x86_64
archive=$1
EOF
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cp update.sh index.html "$tmpdir"
mkdir "$tmpdir/binaries"
printf archive-data > "$tmpdir/binaries/3.14.0-ubuntu-24.04-x86_64.tar.gz"
printf definition > "$tmpdir/binaries/3.14.0-ubuntu-24.04-x86_64"

cd "$tmpdir"
write_meta 3.14.0-ubuntu-24.04-x86_64.tar.gz
bash ./update.sh >/dev/null 2>&1 || fail "update failed"

sha=8a6111c3ca752ed6d5f8e8a6daa3ba4b8c3b0bf55f00a87ac2b285024ef87e5f
[ "binaries/3.14.0-ubuntu-24.04-x86_64.tar.gz" -ef "$sha" ] ||
  fail "checksum path is not a hardlink to the archive"

entry='<li><a href="binaries/3.14.0-ubuntu-24.04-x86_64.tar.gz">3.14.0-ubuntu-24.04-x86_64.tar.gz</a> (<a href="binaries/3.14.0-ubuntu-24.04-x86_64">definition</a>)</li>'
grep -Fqx "$entry" index.html || fail "prebuilt archive is missing from index.html"

cp index.html index.before
bash ./update.sh >/dev/null 2>&1 || fail "second update failed"
cmp -s index.before index.html || fail "second update changed index.html"
[ "$(grep -Fxc "$entry" index.html)" -eq 1 ] || fail "prebuilt archive is listed more than once"

write_meta ../outside.tar.gz
printf outside > outside.tar.gz
if bash ./update.sh >/dev/null 2>&1; then
  fail "update accepted an archive outside binaries"
fi

write_meta 3.14.0-ubuntu-24.04-x86_64.tar.gz
rm binaries/3.14.0-ubuntu-24.04-x86_64
if bash ./update.sh >/dev/null 2>&1; then
  fail "update accepted a missing definition"
fi

echo "ok"
