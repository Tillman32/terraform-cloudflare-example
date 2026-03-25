terraform {
  required_version = ">= 1.5"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  # Local backend — this config creates the R2 bucket that all other
  # configs use for remote state, so it can't store its own state there.
}

provider "cloudflare" {
  # Set via env: CLOUDFLARE_EMAIL + CLOUDFLARE_API_KEY
}

resource "cloudflare_r2_bucket" "terraform_state" {
  account_id = var.account_id
  name       = "terraform-state"
}
