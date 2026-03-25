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
