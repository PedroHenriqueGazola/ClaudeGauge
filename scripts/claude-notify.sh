#!/bin/bash
set -euo pipefail

event="${1:-finished}"
payload="$(cat)"

cwd="$(printf '%s' "$payload" | plutil -extract cwd raw -o - - 2>/dev/null || true)"
project="${cwd##*/}"

# O hook Notification traz em `message` o que o Claude precisa (ex.: pedido de
# permissão) e `transcript_path` pro app detalhar o que ele quer. Passa os
# valores crus: o `open` faz o percent-encoding (pré-encodar causa %2520).
# `-g` entrega a URL sem ativar o app; sem ele o `open` traz o ClaudeGauge pra
# frente e rouba o foco da janela em que a pessoa está.
message="$(printf '%s' "$payload" | plutil -extract message raw -o - - 2>/dev/null || true)"
transcript="$(printf '%s' "$payload" | plutil -extract transcript_path raw -o - - 2>/dev/null || true)"

open -g "${CLAUDEGAUGE_URL_SCHEME:-claudegauge}://notify?event=${event}&project=${project}&detail=${message}&transcript=${transcript}" \
  >/dev/null 2>&1 &

exit 0
