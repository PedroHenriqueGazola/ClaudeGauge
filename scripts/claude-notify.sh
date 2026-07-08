#!/bin/bash
set -euo pipefail

event="${1:-finished}"
payload="$(cat)"

cwd="$(printf '%s' "$payload" | plutil -extract cwd raw -o - - 2>/dev/null || true)"
project="${cwd##*/}"

# O hook Notification traz em `message` o que o Claude precisa (ex.: pedido de
# permissão) — repassa como detalhe da notificação. Passa os valores crus: o
# `open` faz o percent-encoding (pré-encodar causaria double-encoding, %2520).
message="$(printf '%s' "$payload" | plutil -extract message raw -o - - 2>/dev/null || true)"

open "${CLAUDEGAUGE_URL_SCHEME:-claudegauge}://notify?event=${event}&project=${project}&detail=${message}" \
  >/dev/null 2>&1 &

exit 0
