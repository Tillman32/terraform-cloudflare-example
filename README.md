# terraform-cloudflare

Terraform monorepo for managing DNS records and zone settings across multiple Cloudflare domains.

Each domain gets its own isolated state file stored in Cloudflare R2, while sharing a common module for consistent configuration.

## Repository Structure

```
.
├── bootstrap/               # One-time setup: creates the R2 state bucket
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars
├── modules/
│   └── domain/              # Shared module: zone lookup, DNS records, SSL/TLS settings
├── domains/
│   └── example.com/         # Per-domain config (one directory per domain)
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
└── scripts/
    ├── new-domain.sh        # Scaffold a new domain directory
    └── import-domain.sh     # Import an existing domain from Cloudflare
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- A Cloudflare account with a [Global API Key](https://developers.cloudflare.com/fundamentals/api/get-started/keys/)
- An R2 API token with read/write access to the state bucket (generates an access key ID and secret)

## Environment Variables

| Variable | Used by | Description |
|---|---|---|
| `CLOUDFLARE_EMAIL` | Terraform provider, import script | Cloudflare account email |
| `CLOUDFLARE_API_KEY` | Terraform provider, import script | [Global API Key](https://developers.cloudflare.com/fundamentals/api/get-started/keys/) |
| `AWS_ACCESS_KEY_ID` | Terraform backend | R2 API token access key ID (R2 uses S3-compatible auth) |
| `AWS_SECRET_ACCESS_KEY` | Terraform backend | R2 API token secret access key |
| `TF_VAR_account_id` | Terraform variable | Cloudflare account ID (auto-mapped to `var.account_id`) |

All five are Cloudflare credentials. The `AWS_*` variables are named that way because Terraform's S3 backend reads them automatically, and R2 exposes an S3-compatible API. The `TF_VAR_` prefix is a Terraform convention that auto-maps environment variables to input variables.

Export these before running any Terraform or script commands:

```sh
export CLOUDFLARE_EMAIL="your-email@example.com"
export CLOUDFLARE_API_KEY="your-global-api-key"
export AWS_ACCESS_KEY_ID="your-r2-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-r2-secret-access-key"
export TF_VAR_account_id="your-cloudflare-account-id"
```

## Usage

### Recommended: Claude Commands (Primary Workflow)

Use the built-in Claude slash commands from the repo root. This is the primary and preferred way to work in this repository.

```text
/new-domain example.com
/import-domain example.com
```

What these commands handle for you:

1. Validate input and repository context
2. Verify `.env` exists with required credentials
3. Run the appropriate scaffolding/import script
4. Run `terraform init` with the required R2 backend endpoint
5. Surface generated files and next steps

`/new-domain <domain>`

- Creates `domains/<domain>/`
- Runs `terraform init -backend-config="endpoint=https://${TF_VAR_account_id}.r2.cloudflarestorage.com"`
- Shows generated `terraform.tfvars`

`/import-domain <domain>`

- Imports existing Cloudflare DNS and zone settings into Terraform config
- Generates `terraform.tfvars` and `import-commands.sh`
- Runs init, import commands, and a final plan

### Manual Workflow (Advanced / Fallback)

### Bootstrap (first-time setup)

Before adding any domains, create the R2 bucket that stores Terraform state. This only needs to be done once.

1. Edit `bootstrap/terraform.tfvars` with your Cloudflare account ID
2. Run:

```sh
cd bootstrap
terraform init
terraform apply
```

The bootstrap config uses local state (stored in `bootstrap/terraform.tfstate`) since the R2 bucket it creates is the remote backend for everything else.

### Add a new domain (from scratch)

If you are not using Claude commands, run the manual script directly:

```sh
./scripts/new-domain.sh example.com
```

This scaffolds `domains/example.com/` with `main.tf`, `variables.tf`, and a starter `terraform.tfvars`. Edit the tfvars to add your DNS records, then:

```sh
cd domains/example.com
terraform init -backend-config="endpoint=https://${TF_VAR_account_id}.r2.cloudflarestorage.com"
terraform plan
terraform apply
```

### Import an existing domain

If you are not using Claude commands, run the manual import path:

For domains already configured in Cloudflare, the import script fetches all current DNS records and zone settings via the API and generates the Terraform configuration to match:

```sh
./scripts/import-domain.sh example.com
```

This will:
1. Scaffold the domain directory (or prompt before overwriting an existing one)
2. Fetch all DNS records and zone settings from the Cloudflare API
3. Generate `terraform.tfvars` matching the current state
4. Generate `import-commands.sh` with the `terraform import` commands for every resource

Then run the imports:

```sh
cd domains/example.com
terraform init -backend-config="endpoint=https://${TF_VAR_account_id}.r2.cloudflarestorage.com"
bash import-commands.sh
terraform plan  # should show no changes
```

### Day-to-day changes

Edit `domains/<domain>/terraform.tfvars` to add, modify, or remove DNS records:

```hcl
dns_records = [
  {
    name    = "example.com"
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
  },
  {
    name    = "example.com"
    type    = "MX"
    content = "mail.example.com"
    ttl      = 300
    priority = 10
  },
]
```

Then apply:

```sh
cd domains/example.com
terraform plan
terraform apply
```

### DNS record fields

| Field | Type | Default | Description |
|---|---|---|---|
| `name` | string | required | Record name (FQDN like `example.com` for root, or subdomain like `www`) |
| `type` | string | required | Record type (`A`, `AAAA`, `CNAME`, `MX`, `TXT`, etc.) |
| `content` | string | required | Record value |
| `ttl` | number | `1` (auto) | TTL in seconds. Use `1` for automatic (required when proxied) |
| `proxied` | bool | `false` | Whether to proxy through Cloudflare |
| `priority` | number | `null` | Priority (required for MX records) |
| `comment` | string | `null` | Optional comment visible in Cloudflare dashboard |

### Zone settings

The `ssl_mode` variable controls the SSL/TLS encryption mode. Valid values: `off`, `flexible`, `full`, `strict`.

Additional zone settings (always_use_https, min_tls_version, tls_1_3) use secure defaults defined in the module and can be overridden by adding the corresponding variables to the domain's `variables.tf` and `terraform.tfvars`.
