#!/usr/bin/env bash
# Fast gate (German/docs/e2e-standard.md): format + lint + unit + widget + headless end-to-end
# flows, for the Flutter app and the web app in parallel. Budget: 3 minutes. Run it before every
# commit; CI runs the same script on every push.
#
#   tools/verify.sh          both halves
#   tools/verify.sh app      Flutter: dart format, flutter analyze, flutter test (flows with fakes)
#   tools/verify.sh web      Web: tsc, Vitest, production build, Playwright (phone + tablet)
#
# Tests run in Europe/Berlin, so the DST and midnight cases are the ones learners actually meet.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
BUDGET=180
export TZ=Europe/Berlin
LOGS=$(mktemp -d)
start=$(date +%s)

step() { # step <log> <label> <command…>: run, label the log, stop the half on failure
  local log=$1 label=$2; shift 2
  local t=$(date +%s)
  echo "── $label" >>"$log"
  if "$@" >>"$log" 2>&1; then echo "   ok $(( $(date +%s) - t ))s" >>"$log"; else echo "   FAILED: $label" >>"$log"; return 1; fi
}

app() {
  local log=$LOGS/app.log
  cd "$ROOT/app" &&
    step "$log" "flutter pub get" flutter pub get &&
    step "$log" "dart format" dart format --output=none --set-exit-if-changed lib test integration_test &&
    step "$log" "flutter analyze" flutter analyze --no-pub &&
    step "$log" "release checks (self-test)" python3 tool/check_release.py --self-test &&
    step "$log" "flutter test (unit, widget, headless flows)" flutter test --no-pub
}

web() {
  local log=$LOGS/web.log
  cd "$ROOT" || return 1
  if [ ! -d node_modules ]; then step "$log" "npm ci" npm ci || return 1; fi
  step "$log" "tsc" npx tsc -b &&
    step "$log" "vitest" npx vitest run &&
    step "$log" "vite build" npx vite build &&
    step "$log" "playwright (phone + tablet)" npx playwright test --reporter=line
}

pids=()
case "${1:-all}" in
  app) app & pids+=($!) ;;
  web) web & pids+=($!) ;;
  all) app & pids+=($!); web & pids+=($!) ;;
  *) echo "usage: tools/verify.sh [app|web]" >&2; exit 2 ;;
esac

status=0
for p in "${pids[@]}"; do wait "$p" || status=1; done
for log in "$LOGS"/*.log; do
  half=$(basename "$log" .log)
  if grep -q "FAILED" "$log"; then
    echo "✗ $half"; tail -n 60 "$log"
  else
    echo "✓ $half: $(grep -c '^   ok' "$log") steps — $(grep -E '^(──|   ok)' "$log" | paste - - | sed 's/── //; s/ *ok / /' | tr '\n' ';' | sed 's/;$//')"
  fi
done
elapsed=$(( $(date +%s) - start ))
echo "fast gate: $([ $status = 0 ] && echo PASSED || echo FAILED) in ${elapsed}s (budget ${BUDGET}s)"
if [ "$elapsed" -gt "$BUDGET" ]; then echo "warning: over budget — parallelise or move slow cases to the device tier"; fi
rm -rf "$LOGS"
exit $status
