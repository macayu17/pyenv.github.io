#!/usr/bin/env bash

set -e

cd "${BASH_SOURCE%/*}/.."

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

bad_name=$'bad\nname'
printf 'archive=bad\narchive=name.tar.gz\n' > "binaries/$bad_name.meta"
printf archive-data > "binaries/$bad_name.tar.gz"
printf definition > "binaries/$bad_name"
rm "$sha"
if output="$(bash ./update.sh 2>&1)"; then
  fail "update accepted a control character in an archive name"
fi
case "$output" in
*"Invalid archive name in binaries/"*) ;;
*) fail "update did not reject the invalid archive name during validation" ;;
esac
[ ! -e "$sha" ] || fail "update created a checksum link before name validation completed"
rm "binaries/$bad_name.meta" "binaries/$bad_name.tar.gz" "binaries/$bad_name"

mkdir source
printf source-data > source/example.tar.gz
printf '<li><a href="">example.tar.gz</a></li>\n' >> index.html
cp index.html index.before
cp binaries/3.14.0-ubuntu-24.04-x86_64.meta binaries/z-invalid.meta
sed -i 's/^archive=.*/archive=invalid.tar.gz/' binaries/z-invalid.meta
if bash ./update.sh >/dev/null 2>&1; then
  fail "update accepted invalid metadata"
fi
[ ! -e "$sha" ] || fail "update created a binary checksum link before validation completed"
source_sha=6bb69d845f4a714ca982e2903d2c03fabeb2448b67185bca413d3efddea9397c
[ ! -e "$source_sha" ] || fail "update created a source checksum link before validation completed"
cmp -s index.before index.html || fail "update changed index.html before validation completed"
rm -rf source binaries/z-invalid.meta

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

printf definition > binaries/3.14.0-ubuntu-24.04-x86_64
rm binaries/3.14.0-ubuntu-24.04-x86_64.tar.gz
if bash ./update.sh >/dev/null 2>&1; then
  fail "update accepted a missing archive"
fi

echo "ok"
