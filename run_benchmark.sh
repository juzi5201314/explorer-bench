#!/usr/bin/env bash
# Usage: ./run_benchmark.sh <provider/model_id> [<provider/model_id> ...]
# Runs all given models sequentially. For parallel execution, invoke
# this script once per model via separate bash tool calls.

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 <provider/model_id> [<provider/model_id> ...]" >&2
  exit 1
fi

INPUT=$(cat ./input.md)
DATE=$(date +%F)
TIMEOUT_SEC=600

run_one() {
  local MODEL_ID="$1"
  local SAFE_NAME="${MODEL_ID#*/}"
  local OUTDIR="./outputs/$SAFE_NAME"
  mkdir -p "$OUTDIR"

  local START
  START=$(date +%s)

  echo "[$(date +%T)] Starting $MODEL_ID -> $SAFE_NAME"

  timeout ${TIMEOUT_SEC} \
    omp --model "$MODEL_ID" \
        -p "$INPUT" \
        --thinking high \
        --tools read,bash,find,lsp,search \
        > "$OUTDIR/$DATE.md" 2>&1
  local RC=$?

  local END ELAPSED
  END=$(date +%s)
  ELAPSED=$((END - START))

  echo "{\"model\": \"$MODEL_ID\", \"exit_code\": $RC, \"elapsed_seconds\": $ELAPSED, \"date\": \"$DATE\"}" > "$OUTDIR/$DATE.meta.json"

  if [ $RC -eq 124 ]; then
    echo "[$(date +%T)] $SAFE_NAME: TIMEOUT after ${ELAPSED}s"
  elif [ $RC -eq 0 ]; then
    echo "[$(date +%T)] $SAFE_NAME: DONE in ${ELAPSED}s (exit 0)"
  else
    echo "[$(date +%T)] $SAFE_NAME: FAILED in ${ELAPSED}s (exit $RC)"
  fi
}

for MODEL in "$@"; do
  run_one "$MODEL"
done

echo "===== ALL DONE  $(date +%T) ====="
