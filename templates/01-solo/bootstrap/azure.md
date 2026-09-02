# Bootstrap: Azure state backend (run once)

Creates the resource group, storage account and blob container that
`backend.tf` expects. Do this BEFORE the first `task init-backend`. Requires
the az CLI and `az login` already done.

```bash
export PROJECT=<your-project-name>       # the slug you instantiated with
export LOCATION=<your-location>          # Azure region, e.g. westeurope
export RG="${PROJECT}-tfstate-rg"
export ACCOUNT="${PROJECT}tfstate"       # lowercase+digits only, 3-24 chars; adjust if taken
export CONTAINER="tfstate"

# 1) Resource group that holds the state storage.
az group create --name "$RG" --location "$LOCATION"
# Expected output: JSON with "provisioningState": "Succeeded"

# 2) Storage account — LRS is enough for state; public access disabled.
az storage account create \
  --name "$ACCOUNT" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false
# Expected output: JSON with "provisioningState": "Succeeded" (~30s)

# 3) Container that holds the .tfstate blobs.
az storage container create \
  --account-name "$ACCOUNT" \
  --name "$CONTAINER" \
  --auth-mode login
# Expected output: {"created": true}

echo "STATE_RG=$RG  STORAGE_ACCOUNT=$ACCOUNT  CONTAINER=$CONTAINER"
```

Then substitute these values in `backend.tf`:

| backend.tf field | value |
| ---------------- | ----- |
| `resource_group_name` | `$RG` |
| `storage_account_name` | `$ACCOUNT` |
| `container_name` | `$CONTAINER` |

Also set your region in `starter.tf` (`location`). Then run: `task init-backend`.
