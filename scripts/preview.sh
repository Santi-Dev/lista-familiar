#!/usr/bin/env bash
# Uso: bash scripts/preview.sh [pantalla ...]
# Empuja la rama actual y espera al workflow ios-preview; baja las capturas a previews/run-<id>/.
# - Si el workflow ya está en la rama por defecto: lo lanza con workflow_dispatch (admite pantallas).
# - Si no: el push lo dispara solo (todas las pantallas). Requiere cambios bajo swift_space/.
set -euo pipefail
cd "$(dirname "$0")/.."

BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push -u origin "$BRANCH"
SHA=$(git rev-parse HEAD)

if gh workflow view ios-preview.yml --ref "$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)" >/dev/null 2>&1; then
  ARGS=(); [ $# -gt 0 ] && ARGS=(-f "screens=$*")
  gh workflow run ios-preview.yml --ref "$BRANCH" "${ARGS[@]}"
fi

RUN_ID=""
for _ in $(seq 1 12); do
  sleep 5
  RUN_ID=$(gh run list --workflow ios-preview.yml --branch "$BRANCH" --limit 5 --json databaseId,headSha -q "[.[]|select(.headSha==\"$SHA\")][0].databaseId // empty")
  [ -n "$RUN_ID" ] && break
done
[ -n "$RUN_ID" ] || { echo "No apareció ningún run para $SHA"; exit 1; }
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
echo "OK: $DEST/ios-preview"; ls "$DEST/ios-preview"
