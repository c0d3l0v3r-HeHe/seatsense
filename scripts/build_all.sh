#!/usr/bin/env bash
# Rebuild everything from the raw ticket file: crowding tables, validation, figures, Flutter web app.
# Usage: scripts/build_all.sh [path/to/October-Delhi.csv.zip]
set -euo pipefail
cd "$(dirname "$0")/.."
export PYTHONPATH="$PWD/src${PYTHONPATH:+:$PYTHONPATH}"
RAW="${1:-October-Delhi.csv.zip}"
python -m crowding.pipeline --raw "$RAW"
python -m crowding.validate
if command -v flutter >/dev/null; then
  (cd app && flutter pub get && flutter build web --release --no-web-resources-cdn)
fi
echo "Done. Start the demo with: scripts/run_api.sh  ->  http://localhost:8000"
