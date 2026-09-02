# Bootstrap — Azure (one-time, before the first apply)

Creates the shared remote-state backend every environment in this repo
uses: one resource group containing a storage account and a blob container.
The values you choose here land in the injected backend block in `root.hcl`
(resource group, storage account and container placeholders are substituted
by `scripts/init-project` at project creation).

## Prerequisites

- Azure CLI installed: `az login` then `az account show`

## 1. Resource group

```bash
export LOCATION=westeurope
export RG=<resource-group-name>          # e.g. rg-<project>-tfstate

az group create --name "$RG" --location "$LOCATION"
```

## 2. Storage account + container

IMPORTANT: storage account names are globally unique AND limited to 24
characters — lowercase letters and digits only, no dashes. Keep it short.

```bash
export SA=<storage-account-name>         # <= 24 chars, [a-z0-9] only
export CONTAINER=tfstate

az storage account create \
  --name "$SA" --resource-group "$RG" --location "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 \
  --allow-blob-public-access false --min-tls-version TLS1_2

az storage container create \
  --account-name "$SA" --name "$CONTAINER" --auth-mode login
```

## 3. First run

Authenticate via the `ARM_*` environment variables (template in
`.env.example`):

```bash
export ARM_SUBSCRIPTION_ID=<subscription-id>
export ARM_TENANT_ID=<tenant-id>
export ARM_CLIENT_ID=<client-id>
export ARM_CLIENT_SECRET=<client-secret>
```

then:

```bash
task engine-check
task init-backend ENV=dev      # terragrunt init — wires the remote backend
task plan ENV=dev              # review the plan
task apply ENV=dev             # apply exactly what was reviewed
task run-all-plan ENV=dev      # once more components exist
```

The `azurerm` backend itself authenticates with the same `ARM_*` variables.
