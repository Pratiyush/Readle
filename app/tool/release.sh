#!/bin/bash
# The Play upload: a signed, obfuscated release bundle with Readle's ads on, checked before it
# leaves the Mac. Run from anywhere:
#
#   app/tool/release.sh [--bump] [--skip-gate] [--cdn]
#
#   --bump       raise the build number in pubspec.yaml first (every Play upload needs a new one)
#   --skip-gate  don't run the fast gate first (only when it just passed on this commit)
#   --cdn        build with CONTENT_CDN_ENABLED (only once the privacy policy covers downloads)
#   LEGAL_SLUG=… passed through when set (Settings links the hosted privacy policy and Impressum)
#
# Needs the upload key: android/key.properties (git-ignored) or READLE_KEY_PROPERTIES=<path>.
# Writes build/release/readle-<version>.aab and the matching -symbols.zip (keep both, never in
# git: the symbols turn obfuscated crash traces back into code).
set -euo pipefail
cd "$(dirname "$0")/.."
APP=$PWD
BUMP= GATE=1 DEFINES=(--dart-define=ADS_ENABLED=true)
for a in "$@"; do
  case $a in
    --bump) BUMP=1 ;;
    --skip-gate) GATE= ;;
    --cdn) DEFINES+=(--dart-define=CONTENT_CDN_ENABLED=true) ;;
    *) echo "unknown option $a"; sed -n 5,10p "$0"; exit 2 ;;
  esac
done
[ -n "${LEGAL_SLUG:-}" ] && DEFINES+=(--dart-define=LEGAL_SLUG=$LEGAL_SLUG)
die() { echo "✗ $*" >&2; exit 1; }

[ -z "${ADS_TEST:-}" ] || die "ADS_TEST is set: a release never uses Google's test ad units"
KEY=${READLE_KEY_PROPERTIES:-$APP/android/key.properties}
[ -f "$KEY" ] || die "no upload key ($KEY). Create one once and keep it in the password manager:
  keytool -genkeypair -v -keystore ~/keys/readle-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
then write android/key.properties with storeFile, storePassword, keyAlias=upload, keyPassword."
git -C "$APP" diff --quiet HEAD -- . || die "uncommitted changes in app/: release from a commit, so the symbols match it"

if [ -n "$BUMP" ]; then
  python3 - "$APP/pubspec.yaml" <<'EOF'
import re, sys
p = sys.argv[1]; s = open(p).read()
s, n = re.subn(r"^version: (\d+\.\d+\.\d+)\+(\d+)$", lambda m: f"version: {m[1]}+{int(m[2]) + 1}", s, flags=re.M)
assert n == 1, "no version: x.y.z+n line in pubspec.yaml"
open(p, "w").write(s)
EOF
fi
VERSION=$(sed -n 's/^version: *//p' pubspec.yaml)
echo "Readle $VERSION"

[ -z "$GATE" ] || "$APP/../tools/verify.sh"

SYMBOLS=build/symbols/$VERSION
AAB=build/app/outputs/bundle/release/app-release.aab
rm -f "$AAB"
LOG=$(mktemp)
if ! flutter build appbundle --release --obfuscate --split-debug-info="$SYMBOLS" "${DEFINES[@]}" 2>&1 | tee "$LOG"; then
  # Flutter's own strip check needs the SDK's cmdline-tools (apkanalyzer); without them it fails a
  # good bundle. check_release.py runs the same test, so only that failure, with a fresh bundle, goes on.
  grep -q "failed to strip debug symbols" "$LOG" && [ -f "$AAB" ] || die "the build failed (log: $LOG)"
  echo "(Flutter couldn't check the stripping without Android cmdline-tools; check_release.py does it)"
fi
MANIFEST=$(ls -t $(find build/app/intermediates/merged_manifest/release -name AndroidManifest.xml) | head -1)
python3 tool/check_release.py "$AAB" "$MANIFEST" "$VERSION" "$APP/../docs/release-notes.md"

mkdir -p build/release
cp "$AAB" "build/release/readle-$VERSION.aab"
(cd "$SYMBOLS" && zip -qr "$APP/build/release/readle-$VERSION-symbols.zip" .)
echo "✓ build/release/readle-$VERSION.aab ($(du -h "$AAB" | cut -f1)), symbols in build/release/readle-$VERSION-symbols.zip"
[ -z "$BUMP" ] || echo "  pubspec.yaml now says $VERSION: commit it."
echo "  Next: Play Console → Internal testing → Create release → upload the .aab; paste the '## $VERSION' notes from docs/release-notes.md."
