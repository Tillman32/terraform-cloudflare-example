#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <domain>"
  echo ""
  echo "Scaffold a new domain directory under domains/<domain>/"
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

DOMAIN="$1"
DOMAIN_DIR="$(cd "$(dirname "$0")/.." && pwd)/domains/${DOMAIN}"

if [[ -d "$DOMAIN_DIR" ]]; then
  echo "Error: ${DOMAIN_DIR} already exists"
  exit 1
fi

mkdir -p "$DOMAIN_DIR"

# main.tf
cat > "${DOMAIN_DIR}/main.tf" <<EOF
terraform {
  required_version = ">= 1.5"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state"
    key    = "domains/${DOMAIN}/terraform.tfstate"
    region = "auto"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true

    # Set via env: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
    # Endpoint set via: terraform init -backend-config="endpoint=https://\$TF_VAR_account_id.r2.cloudflarestorage.com"
  }
}

provider "cloudflare" {
  # Set via env: CLOUDFLARE_EMAIL + CLOUDFLARE_API_KEY
}

module "domain" {
  source = "../../modules/domain"

  domain      = var.domain
  account_id  = var.account_id
  dns_records = var.dns_records
  ssl_mode    = var.ssl_mode
}
EOF

# variables.tf
cat > "${DOMAIN_DIR}/variables.tf" <<'EOF'
variable "domain" {
  description = "The domain name"
  type        = string
}

variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "dns_records" {
  description = "List of DNS records to create"
  type = list(object({
    name     = string
    type     = string
    content  = string
    ttl      = optional(number, 1)
    proxied  = optional(bool, false)
    priority = optional(number)
    comment  = optional(string)
  }))
  default = []
}

variable "ssl_mode" {
  description = "SSL/TLS encryption mode"
  type        = string
  default     = "full"
}
EOF

# terraform.tfvars
cat > "${DOMAIN_DIR}/terraform.tfvars" <<EOF
domain   = "${DOMAIN}"
ssl_mode = "strict"

dns_records = [
  # Add your DNS records here, for example:
  # {
  #   name    = "${DOMAIN}"
  #   type    = "A"
  #   content = "192.0.2.1"
  #   proxied = true
  #   comment = "Root domain"
  # },
]
EOF

echo "Scaffolded domain at ${DOMAIN_DIR}/"
echo "Next steps:"
echo "  1. Edit ${DOMAIN_DIR}/terraform.tfvars with your DNS records"
echo "  2. cd ${DOMAIN_DIR}"
echo "  3. terraform init -backend-config=\"endpoint=https://\${TF_VAR_account_id}.r2.cloudflarestorage.com\""
echo "  4. terraform plan"
