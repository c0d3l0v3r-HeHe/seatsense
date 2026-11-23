#!/usr/bin/env bash
# Start the SeatSense API (and the Flutter web app if built) on http://localhost:8000
# Activate your Python environment first (conda base works).
set -euo pipefail
cd "$(dirname "$0")/.."
export PYTHONPATH="$PWD/src${PYTHONPATH:+:$PYTHONPATH}"
exec python -m crowding.api
