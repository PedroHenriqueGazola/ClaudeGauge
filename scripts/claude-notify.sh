#!/bin/bash
set -euo pipefail

event="${1:-finished}"
payload="$(cat)"

project="$(printf '%s' "$payload" | plutil -extract cwd raw -o - - 2>/dev/null || true)"
project="${project##*/}"
project_encoded="${project// /%20}"

open "${CLAUDEGAUGE_URL_SCHEME:-claudegauge}://notify?event=${event}&project=${project_encoded}" \
  >/dev/null 2>&1 &

exit 0
