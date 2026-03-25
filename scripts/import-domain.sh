#!/usr/bin/env bash
set -euo pipefail

API_BASE="https://api.cloudflare.com/client/v4"

usage() {
  echo "Usage: $0 <domain> [account_id]"
  echo ""
  echo "Import an existing Cloudflare domain into the Terraform monorepo."
  echo "Generates terraform.tfvars and import-commands.sh for the domain."
  echo ""
  echo "  account_id defaults to TF_VAR_account_id from .env or environment"
  echo "  If not found, you will be prompted to enter it"
  echo ""
  echo "Prerequisites:"
  echo "  CLOUDFLARE_EMAIL and CLOUDFLARE_API_KEY must be set (via .env or environment)"
  echo "  curl and jq must be installed"
  exit 1
}

# ---- Validate inputs ----
if [[ $# -lt 1 ]]; then
  usage
fi

DOMAIN="$1"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Load .env if it exists (provides TF_VAR_account_id, CLOUDFLARE_EMAIL, etc.)
if [[ -f "${REPO_ROOT}/.env" ]]; then
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/.env"
fi

ACCOUNT_ID="${2:-${TF_VAR_account_id:-}}"

if [[ -z "$ACCOUNT_ID" ]]; then
  read -rp "Cloudflare Account ID: " ACCOUNT_ID
  if [[ -z "$ACCOUNT_ID" ]]; then
    echo "Error: account_id is required"
    exit 1
  fi
fi
DOMAIN_DIR="${REPO_ROOT}/domains/${DOMAIN}"

if [[ -z "${CLOUDFLARE_EMAIL:-}" ]] || [[ -z "${CLOUDFLARE_API_KEY:-}" ]]; then
  echo "Error: CLOUDFLARE_EMAIL and CLOUDFLARE_API_KEY environment variables must be set"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed"
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo "Error: curl is required but not installed"
  exit 1
fi

# ---- Helper: Cloudflare API call ----
cf_api() {
  local endpoint="$1"
  local response
  response=$(curl -sf -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" \
    -H "X-Auth-Key: ${CLOUDFLARE_API_KEY}" \
    -H "Content-Type: application/json" \
    "${API_BASE}${endpoint}") || {
    echo "Error: API request failed for ${endpoint}"
    exit 1
  }

  local success
  success=$(echo "$response" | jq -r '.success')
  if [[ "$success" != "true" ]]; then
    echo "Error: API returned failure for ${endpoint}"
    echo "$response" | jq -r '.errors'
    exit 1
  fi

  echo "$response"
}

# ---- Scaffold domain directory if needed ----
if [[ -d "$DOMAIN_DIR" ]]; then
  echo "Domain directory ${DOMAIN_DIR} already exists."
  read -rp "Overwrite terraform.tfvars? [y/N] " confirm
  if [[ "$confirm" != [yY] ]]; then
    echo "Aborted."
    exit 0
  fi
else
  echo "Scaffolding domain directory..."
  "${REPO_ROOT}/scripts/new-domain.sh" "$DOMAIN"
fi

# ---- Get zone ID ----
echo "Fetching zone ID for ${DOMAIN}..."
ZONE_RESPONSE=$(cf_api "/zones?name=${DOMAIN}&account.id=${ACCOUNT_ID}")
ZONE_ID=$(echo "$ZONE_RESPONSE" | jq -r '.result[0].id // empty')

if [[ -z "$ZONE_ID" ]]; then
  echo "Error: Could not find zone for ${DOMAIN}"
  echo "Response: $(echo "$ZONE_RESPONSE" | jq '.errors // .messages')"
  exit 1
fi
echo "Zone ID: ${ZONE_ID}"

# ---- Fetch DNS records ----
echo "Fetching DNS records..."
DNS_RESPONSE=$(cf_api "/zones/${ZONE_ID}/dns_records?per_page=1000")
RECORD_COUNT=$(echo "$DNS_RESPONSE" | jq '.result | length')
echo "Found ${RECORD_COUNT} DNS records"

# ---- Fetch zone settings ----
echo "Fetching zone settings..."
SETTINGS_RESPONSE=$(cf_api "/zones/${ZONE_ID}/settings")

SSL_MODE=$(echo "$SETTINGS_RESPONSE" | jq -r '.result[] | select(.id == "ssl") | .value')
echo "SSL mode: ${SSL_MODE}"

# ---- Sort records and shorten subdomain names ----
# Keep root domain as FQDN (not @) since the provider stores FQDNs in state
SORTED_RECORDS=$(echo "$DNS_RESPONSE" | jq --arg domain "$DOMAIN" '
  [.result[] | {
    id:       .id,
    name:     (if .name == $domain then $domain else (.name | sub("\\." + $domain + "$"; "")) end),
    type:     .type,
    content:  .content,
    ttl:      .ttl,
    proxied:  .proxied,
    priority: .priority,
    comment:  (.comment // "")
  }] | sort_by(.type, .name)
')

# ---- Generate terraform.tfvars ----
echo "Generating terraform.tfvars..."

RECORDS_HCL=$(echo "$SORTED_RECORDS" | jq -r '
  def escape_hcl: gsub("\\\\"; "\\\\") | gsub("\""; "\\\"");

  [to_entries[] |
    "  {\n" +
    "    name    = \"" + .value.name + "\"\n" +
    "    type    = \"" + .value.type + "\"\n" +
    "    content = \"" + (.value.content | escape_hcl) + "\"\n" +
    "    ttl     = " + (.value.ttl | tostring) + "\n" +
    "    proxied = " + (.value.proxied | tostring) +
    (if .value.priority != null then "\n    priority = " + (.value.priority | tostring) else "" end) +
    (if .value.comment != "" then "\n    comment  = \"" + (.value.comment | escape_hcl) + "\"" else "" end) +
    "\n  },"
  ] | join("\n")
')

cat > "${DOMAIN_DIR}/terraform.tfvars" <<EOF
domain   = "${DOMAIN}"
ssl_mode = "${SSL_MODE}"

dns_records = [
${RECORDS_HCL}
]
EOF

echo "Wrote ${DOMAIN_DIR}/terraform.tfvars"

# ---- Generate import commands ----
echo "Generating import commands..."

IMPORT_CMDS=$(echo "$SORTED_RECORDS" | jq -r --arg zone_id "$ZONE_ID" '
  to_entries[] |
  "terraform import '\''module.domain.cloudflare_record.this[\"" +
    .value.type + "_" + .value.name + "_" + (.key | tostring) +
    "\"]'\'' " + $zone_id + "/" + .value.id
')

cat > "${DOMAIN_DIR}/import-commands.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail

# Import commands for ${DOMAIN}
# Generated on $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Zone ID: ${ZONE_ID}

# Zone settings override doesn't support import — Terraform will apply current settings on first run

# Import DNS records
${IMPORT_CMDS}
EOF

chmod +x "${DOMAIN_DIR}/import-commands.sh"
echo "Wrote ${DOMAIN_DIR}/import-commands.sh"

# ---- Next steps ----
echo ""
echo "=== Done ==="
echo ""
echo "Next steps:"
echo "  1. Review ${DOMAIN_DIR}/terraform.tfvars"
echo "  2. cd ${DOMAIN_DIR}"
echo "  3. terraform init -backend-config=\"endpoint=https://\${TF_VAR_account_id}.r2.cloudflarestorage.com\""
echo "  4. bash import-commands.sh"
echo "  5. terraform plan   # should show no changes"
