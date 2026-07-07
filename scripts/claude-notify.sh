#!/bin/bash
set -euo pipefail

event="${1:-finished}"
payload="$(cat)"

cwd="$(printf '%s' "$payload" | plutil -extract cwd raw -o - - 2>/dev/null || true)"
project="${cwd##*/}"
project_encoded="${project// /%20}"
cwd_encoded="${cwd// /%20}"

open "${CLAUDEGAUGE_URL_SCHEME:-claudegauge}://notify?event=${event}&project=${project_encoded}&cwd=${cwd_encoded}" \
  >/dev/null 2>&1 &

exit 0
