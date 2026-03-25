terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

data "cloudflare_zones" "this" {
  filter {
    account_id = var.account_id
    name       = var.domain
  }
}

data "cloudflare_zone" "this" {
  zone_id = data.cloudflare_zones.this.zones[0].id
}

locals {
  zone_id = data.cloudflare_zone.this.id

  dns_records_map = {
    for idx, r in var.dns_records :
    "${r.type}_${r.name}_${idx}" => r
  }
}

resource "cloudflare_record" "this" {
  for_each = local.dns_records_map

  zone_id  = local.zone_id
  name     = each.value.name
  type     = each.value.type
  content  = each.value.content
  ttl      = each.value.ttl
  proxied  = each.value.proxied
  priority = each.value.priority
  comment  = each.value.comment
}

resource "cloudflare_zone_settings_override" "this" {
  zone_id = local.zone_id

  settings {
    ssl                      = var.ssl_mode
    always_use_https         = var.always_use_https
    min_tls_version          = var.min_tls_version
    tls_1_3                  = var.tls_1_3
    automatic_https_rewrites = "on"
  }
}
