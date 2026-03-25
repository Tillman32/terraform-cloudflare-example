output "zone_id" {
  description = "The Cloudflare zone ID"
  value       = local.zone_id
}

output "domain" {
  description = "The domain name"
  value       = var.domain
}

output "name_servers" {
  description = "Cloudflare nameservers for the zone"
  value       = data.cloudflare_zone.this.name_servers
}

output "dns_record_ids" {
  description = "Map of DNS record keys to their IDs"
  value       = { for k, r in cloudflare_record.this : k => r.id }
}

output "ssl_mode" {
  description = "The configured SSL/TLS mode"
  value       = var.ssl_mode
}
