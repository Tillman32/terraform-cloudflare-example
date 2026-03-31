<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&height=220&color=F38020&text=terraform-cloudflare&fontColor=ffffff&fontAlignY=40&desc=Multi-domain%20Cloudflare%20DNS%20with%20isolated%20Terraform%20state&descAlignY=62&descAlign=50" alt="terraform-cloudflare banner" />
</p>

<p align="center">
  <a href="https://developer.hashicorp.com/terraform/install"><img src="https://img.shields.io/badge/Terraform-%3E%3D%201.5-623CE4?logo=terraform&logoColor=white" alt="Terraform >= 1.5" /></a>
  <a href="https://www.cloudflare.com/"><img src="https://img.shields.io/badge/Cloudflare-DNS%20%2B%20Zone%20Settings-F38020?logo=cloudflare&logoColor=white" alt="Cloudflare" /></a>
  <img src="https://img.shields.io/badge/State-Isolated%20Per%20Domain-1F6FEB" alt="State per domain" />
</p>

# terraform-cloudflare

Terraform monorepo for managing DNS records and zone settings across multiple Cloudflare domains.

Each domain has its own isolated Terraform state in Cloudflare R2, while sharing a common module for consistent behavior.

## Table of Contents

- [Why this repo](#why-this-repo)
- [Quick start](#quick-start)
- [Primary workflow: Claude commands](#primary-workflow-claude-commands)
- [Manual workflow (advanced)](#manual-workflow-advanced)
- [Configuration reference](#configuration-reference)
- [Repository layout](#repository-layout)
- [Design notes](#design-notes)

## Why this repo

- 🚀 Manage many domains with one repeatable Terraform pattern
- 🧱 Keep state isolated per domain to reduce blast radius
- 🔁 Reuse a single shared module for DNS records and zone settings
- ☁️ Store remote state in Cloudflare R2 (S3-compatible backend)

## Quick start

1. Export required credentials.
2. Use slash commands (recommended) or run scripts directly.
3. Plan and apply from the target domain folder.

```sh
export CLOUDFLARE_EMAIL="your-email@example.com"
export CLOUDFLARE_API_KEY="your-global-api-key"
export AWS_ACCESS_KEY_ID="your-r2-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-r2-secret-access-key"
export TF_VAR_account_id="your-cloudflare-account-id"
```

## Primary workflow: Claude commands

Use built-in slash commands from the repo root:

```text
/new-domain example.com
/import-domain example.com
```

What these commands do for you:

1. Validate input and repo context
2. Verify `.env` exists with required credentials
3. Run scaffolding/import logic
4. Run `terraform init` with the required R2 endpoint
5. Show generated files and next steps

### /new-domain <domain>

- Creates `domains/<domain>/`
- Runs:

```sh
terraform init -backend-config="endpoint=https://${TF_VAR_account_id}.r2.cloudflarestorage.com"
```

- Shows generated `terraform.tfvars`

### /import-domain <domain>

- Imports existing Cloudflare DNS and zone settings
- Generates `terraform.tfvars` and `import-commands.sh`
- Runs init, imports, and final plan

## Manual workflow (advanced)

### 1) Bootstrap (one-time)

Create the R2 bucket that stores Terraform state:

1. Edit `bootstrap/terraform.tfvars` with your account ID
2. Run:

```sh
cd bootstrap
terraform init
terraform apply
```

Note: bootstrap intentionally uses local state because it creates the remote state bucket.

### 2) Add a new domain

```sh
./scripts/new-domain.sh example.com
cd domains/example.com
terraform init -backend-config="endpoint=https://${TF_VAR_account_id}.r2.cloudflarestorage.com"
terraform plan
terraform apply
```

### 3) Import an existing domain

```sh
./scripts/import-domain.sh example.com
cd domains/example.com
terraform init -backend-config="endpoint=https://${TF_VAR_account_id}.r2.cloudflarestorage.com"
bash import-commands.sh
terraform plan
```

Expected result: plan should be empty (or only intentional drift).

### 4) Day-to-day changes

Edit `domains/<domain>/terraform.tfvars` and apply:

```sh
cd domains/example.com
terraform plan
terraform apply
```

## Configuration reference

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- Cloudflare account + [Global API Key](https://developers.cloudflare.com/fundamentals/api/get-started/keys/)
- R2 API token with read/write access to state bucket

### Required environment variables

| Variable | Used by | Description |
|---|---|---|
| `CLOUDFLARE_EMAIL` | Terraform provider, import script | Cloudflare account email |
| `CLOUDFLARE_API_KEY` | Terraform provider, import script | Cloudflare global API key |
| `AWS_ACCESS_KEY_ID` | Terraform backend | R2 API token access key ID |
| `AWS_SECRET_ACCESS_KEY` | Terraform backend | R2 API token secret access key |
| `TF_VAR_account_id` | Terraform variables | Cloudflare account ID |

`AWS_*` naming is required because Terraform's S3 backend reads those automatically, and R2 is S3-compatible.

### DNS record fields

| Field | Type | Default | Description |
|---|---|---|---|
| `name` | string | required | Record name (`example.com` or `www`) |
| `type` | string | required | Record type (`A`, `AAAA`, `CNAME`, `MX`, `TXT`, etc.) |
| `content` | string | required | Record value |
| `ttl` | number | `1` | TTL in seconds (`1` = automatic) |
| `proxied` | bool | `false` | Proxy through Cloudflare |
| `priority` | number | `null` | Priority (required for MX) |
| `comment` | string | `null` | Optional dashboard comment |

Example:

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
    name     = "example.com"
    type     = "MX"
    content  = "mail.example.com"
    ttl      = 300
    priority = 10
  },
]
```

### Zone settings

`ssl_mode` valid values: `off`, `flexible`, `full`, `strict`.

Other settings (such as `always_use_https`, `min_tls_version`, `tls_1_3`) inherit secure module defaults and can be overridden in each domain's variables/tfvars.

## Repository layout

```text
.
├── bootstrap/               # One-time setup: creates the R2 state bucket
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars
├── modules/
│   └── domain/              # Shared module: zone lookup, DNS records, SSL/TLS settings
├── domains/
│   └── example.com/         # Per-domain Terraform root module
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
└── scripts/
    ├── new-domain.sh
    └── import-domain.sh
```

## Design notes

- 🔐 Per-domain isolation: each `domains/<domain>/` folder has independent state
- 🧭 Day-to-day edits usually happen only in `terraform.tfvars`
- 📌 Record key stability uses index-based keys; reordering DNS entries can trigger resource replacement
- ⚠️ If backend endpoint/account config changes, rerun init with `-reconfigure`

## 💡 Bonus tip: Visualize your Terraform

Check out [tfviz](https://github.com/Tillman32/tfviz) — a tool for visualizing Terraform infrastructure as interactive diagrams. Handy for understanding module relationships and reviewing changes before applying.
