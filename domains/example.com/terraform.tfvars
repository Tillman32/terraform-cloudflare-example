domain   = "example.com"
ssl_mode = "strict"

dns_records = [
  {
    name    = "@"
    type    = "A"
    content = "192.0.2.1"
    proxied = true
    comment = "Root domain"
  },
  {
    name    = "www"
    type    = "CNAME"
    content = "example.com"
    proxied = true
    comment = "WWW redirect"
  },
  {
    name    = "@"
    type    = "MX"
    content = "mail.example.com"
    ttl     = 300
    priority = 10
    comment  = "Primary mail server"
  },
  {
    name    = "@"
    type    = "TXT"
    content = "v=spf1 include:_spf.example.com ~all"
    ttl     = 300
    comment = "SPF record"
  },
]
