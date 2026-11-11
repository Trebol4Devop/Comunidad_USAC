#!/usr/bin/env bash
# Aplica la configuración de Auth del proyecto compartido (Zanate + PEMTREE).
#
# Requiere un Personal Access Token de Supabase:
#   https://supabase.com/dashboard/account/tokens
#
# Uso:
#   SUPABASE_ACCESS_TOKEN=sbp_xxx ./scripts/configure-auth.sh
#
# Opcional (verificación previa/después):
#   SUPABASE_ACCESS_TOKEN=sbp_xxx ./scripts/configure-auth.sh --show
set -euo pipefail

: "${SUPABASE_ACCESS_TOKEN:?Exporta SUPABASE_ACCESS_TOKEN (sbp_...) antes de ejecutar}"
REF="${SUPABASE_PROJECT_REF:-hfvsstkfqszpjrsrwhql}"
API="https://api.supabase.com/v1/projects/${REF}/config/auth"

if [[ "${1:-}" == "--show" ]]; then
  curl -sS "$API" -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" |
    python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps({k:d.get(k) for k in ("site_url","uri_allow_list","external_google_enabled","mailer_autoconfirm","disable_signup")}, indent=2, ensure_ascii=False))'
  exit 0
fi

payload=$(cat <<'JSON'
{
  "site_url": "https://zanate.pages.dev",
  "uri_allow_list": "https://zanate.pages.dev/**,https://*.zanate.pages.dev/**,https://pemtree.netlify.app/**,https://*--pemtree.netlify.app/**,http://localhost:3000/**,http://localhost:5173/**,http://127.0.0.1:3000/**,http://127.0.0.1:5173/**,comunidadusac://login-callback/"
}
JSON
)

echo "Aplicando configuración a ${REF}..."
curl -sS -X PATCH "$API" \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "$payload" |
  python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps({k:d.get(k) for k in ("site_url","uri_allow_list","external_google_enabled","mailer_autoconfirm")}, indent=2, ensure_ascii=False))'
