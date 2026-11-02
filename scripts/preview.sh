#!/usr/bin/env bash
# Uso: bash scripts/preview.sh [pantalla ...]
# Empuja la rama actual, lanza el workflow ios-preview y baja las capturas a previews/run-<id>/.
set -euo pipefail
cd "$(dirname "$0")/.."

BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push -u origin "$BRANCH"

ARGS=()
[ $# -gt 0 ] && ARGS=(-f "screens=$*")

gh workflow run ios-preview.yml --ref "$BRANCH" "${ARGS[@]}"
sleep 8
RUN_ID=$(gh run list --workflow ios-preview.yml --branch "$BRANCH" --limit 1 --json databaseId -q '.[0].databaseId')
echo "Run: $RUN_ID"

STATUS=0
gh run watch "$RUN_ID" --exit-status >/dev/null || STATUS=$?

DEST="previews/run-$RUN_ID"
mkdir -p "$DEST"
gh run download "$RUN_ID" -n ios-preview -D "$DEST/ios-preview" || echo "Sin artefacto"

if [ $STATUS -ne 0 ]; then
  echo "FALLÓ. Errores:"; cat "$DEST/ios-preview/errors.txt" 2>/dev/null || gh run view "$RUN_ID" --log-failed | tail -60
  exit 1
fi
echo "OK: $DEST/ios-preview"
ls "$DEST/ios-preview"
