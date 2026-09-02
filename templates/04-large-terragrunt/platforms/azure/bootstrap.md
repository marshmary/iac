# platforms/azure - bootstrap one-pager

Run ONCE per Azure organization, before the first `task plan`. Creates the
resource group, storage account and blob container that `root.hcl`'s generated
backend references. These resources are deliberately NOT managed in-tree -
they bootstrap the bootstrap.

## 0. Authenticate

```bash
az login
az account set --subscription "<management-subscription-name-or-id>"   # where state lives
az account show --query id -o tsv
```

For non-interactive environments see the Azure block in `.env.example`
(`ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`, `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`,
and the `ARM_USE_OIDC=true` workload-identity federation note for CI later).

## 1. Create the state backend

```bash
az group create \
  --name __STATE_RESOURCE_GROUP__ \
  --location __REGION__

az storage account create \
  --name __STATE_STORAGE_ACCOUNT__ \
  --resource-group __STATE_RESOURCE_GROUP__ \
  --location __REGION__ \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2

az storage container create \
  --account-name __STATE_STORAGE_ACCOUNT__ \
  --name __STATE_CONTAINER__ \
  --auth-mode login
```

Notes:

- storage account names are globally unique, 3-24 chars, lowercase and digits
  only - the `__STATE_STORAGE_ACCOUNT__` token must respect that;
- enable soft delete / versioning on the account if your org allows it - it is
  your undo button for state incidents (`runbooks/state-incident.md`);
- stuck state = stuck blob lease, see `runbooks/state-incident.md`.

## 2. First run

```bash
task engine-check
task hcl-validate PLATFORM=azure ENV=dev COMPONENT=baseline
task plan PLATFORM=azure ENV=dev COMPONENT=baseline
task policy-check PLATFORM=azure ENV=dev COMPONENT=baseline
task apply PLATFORM=azure ENV=dev COMPONENT=baseline
```

The first `plan` writes the initial state key
`envs/dev/baseline/terraform.tfstate` into the container - no pre-seeding
needed; keys inherit the `envs/<env>/<component>` pattern automatically.

## CI note (for later)

When you wire CI, authenticate via workload identity federation: set
`ARM_USE_OIDC=true` plus `ARM_CLIENT_ID` / `ARM_TENANT_ID` /
`ARM_SUBSCRIPTION_ID` (placeholders in `.env.example`). Never put client
secrets in the pipeline. Permissions floor: Storage Blob Data Contributor on
the state container only.
