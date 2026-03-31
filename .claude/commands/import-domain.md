---
description: Import an existing Cloudflare domain's DNS records into the Terraform monorepo — runs script, init, imports, and plan
---

Import an existing Cloudflare domain into Terraform management. The domain is: $ARGUMENTS

Follow these steps in order. Report status after each. Stop and explain clearly on any failure.

## Step 0: Validate

If `$ARGUMENTS` is empty or contains no dot, stop:
> Usage: /import-domain <domain>  e.g. /import-domain example.com

## Step 1: Verify repo context

Check that `scripts/import-domain.sh` exists in the current working directory. If not:
> Run this command from the repo root: /Users/brandon/Projects/Infrastructure/terraform-cloudflare

## Step 2: Check .env

Check that `.env` exists. If missing, stop:
> .env is missing. It must contain: CLOUDFLARE_EMAIL, CLOUDFLARE_API_KEY, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, TF_VAR_account_id

## Step 3: Run the import script

Check whether `domains/$ARGUMENTS/` already exists.

- If it does NOT exist, run:
  ```bash
  bash scripts/import-domain.sh $ARGUMENTS
  ```
- If it DOES exist, pipe `y` to answer the overwrite prompt automatically:
  ```bash
  echo y | bash scripts/import-domain.sh $ARGUMENTS
  ```

Show all output. The script fetches the zone ID, all DNS records, and zone settings from the Cloudflare API, then writes `terraform.tfvars` and `import-commands.sh`.

If the script fails:
- "Could not find zone" → domain may not exist in this Cloudflare account, or TF_VAR_account_id is wrong
- API auth error → check CLOUDFLARE_EMAIL and CLOUDFLARE_API_KEY in .env

## Step 4: Review generated files

Read and display `domains/$ARGUMENTS/terraform.tfvars`. Tell the user the record count.
Read and display `domains/$ARGUMENTS/import-commands.sh`. Tell the user how many `terraform import` commands will run.

Ask the user to spot-check for anything unexpected before proceeding (wildcards, internal IPs, records that shouldn't be Terraform-managed). Wait for confirmation to continue.

## Step 5: Terraform init

Run (sources .env in same shell so TF_VAR_account_id is available):
```bash
source .env && cd domains/$ARGUMENTS && terraform init -backend-config="endpoint=https://${TF_VAR_account_id}.r2.cloudflarestorage.com"
```
If init fails, check R2 credentials and endpoint. Suggest `-reconfigure` if needed.

## Step 6: Run import commands

From within `domains/$ARGUMENTS/`, run:
```bash
bash import-commands.sh
```

Show all output. If it fails mid-run (the script uses `set -euo pipefail`):
- Run `terraform state list` to see what was already imported
- Remove the conflicting state entry with `terraform state rm '<resource_address>'` if needed, then re-run

## Step 7: Terraform plan

From within `domains/$ARGUMENTS/`, run:
```bash
terraform plan
```

Interpret the result:
- "No changes." → Import complete and clean. Tell the user they're done.
- Zone settings changes only (`cloudflare_zone_settings_override`) → Expected — zone settings don't support import and will be applied on first run. Safe to apply.
- DNS records shown as to-be-destroyed or replaced → Problem. Likely a key mismatch (keys are type_name_index — if import-commands.sh index doesn't match terraform.tfvars order, Terraform sees different resources). Ask the user to review before applying.

## Step 8: Summary

Report:
- How many DNS records were imported
- Whether plan was clean
- Next step: `terraform apply` from `domains/$ARGUMENTS/`
