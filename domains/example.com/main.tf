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
    key    = "domains/example.com/terraform.tfstate"
    region = "auto"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true

    # Set via env: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
    # Endpoint set via: terraform init -backend-config="endpoint=https://$TF_VAR_account_id.r2.cloudflarestorage.com"
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
