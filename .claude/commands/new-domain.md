---
description: Scaffold a new Cloudflare domain in the Terraform monorepo and run terraform init
---

Scaffold a new domain for the Terraform Cloudflare monorepo. The domain is: $ARGUMENTS

Follow these steps in order. Report status after each. Stop and explain clearly on any failure.

## Step 0: Validate

If `$ARGUMENTS` is empty or contains no dot, stop:
> Usage: /new-domain <domain>  e.g. /new-domain example.com

## Step 1: Verify repo context

Check that `scripts/new-domain.sh` exists in the current working directory. If not:
> Run this command from the repo root: /Users/brandon/Projects/Infrastructure/terraform-cloudflare

## Step 2: Check .env

Check that `.env` exists. If missing, stop:
> .env is missing. Create it with: CLOUDFLARE_EMAIL, CLOUDFLARE_API_KEY, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, TF_VAR_account_id

## Step 3: Check for collision

If `domains/$ARGUMENTS/` already exists, stop:
> domains/$ARGUMENTS already exists. To import existing Cloudflare records into it, run /import-domain $ARGUMENTS instead.

## Step 4: Scaffold

Run:
```bash
bash scripts/new-domain.sh $ARGUMENTS
```
Show output. Stop on non-zero exit.

## Step 5: Terraform init

Run (sources .env in same shell so TF_VAR_account_id is available):
```bash
source .env && cd domains/$ARGUMENTS && terraform init -backend-config="endpoint=https://${TF_VAR_account_id}.r2.cloudflarestorage.com"
```
If init fails, check that TF_VAR_account_id, AWS_ACCESS_KEY_ID, and AWS_SECRET_ACCESS_KEY are set in .env. Suggest re-running with `-reconfigure` if the backend was previously initialized incorrectly.

## Step 6: Show generated tfvars

Read and display `domains/$ARGUMENTS/terraform.tfvars`.

Tell the user:
> Domain scaffolded and initialized. Edit domains/$ARGUMENTS/terraform.tfvars to add your DNS records.
> Record order matters — once applied, do not reorder records (keys are type_name_index and reordering triggers replacements).
> When ready:
>   cd domains/$ARGUMENTS
>   terraform plan
>   terraform apply
