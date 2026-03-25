variable "domain" {
  description = "The domain name (e.g. example.com)"
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

  validation {
    condition     = contains(["off", "flexible", "full", "strict"], var.ssl_mode)
    error_message = "ssl_mode must be one of: off, flexible, full, strict"
  }
}

variable "always_use_https" {
  description = "Always redirect HTTP to HTTPS"
  type        = string
  default     = "on"
}

variable "min_tls_version" {
  description = "Minimum TLS version"
  type        = string
  default     = "1.2"
}

variable "tls_1_3" {
  description = "Enable TLS 1.3"
  type        = string
  default     = "on"
}
