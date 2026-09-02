# Bootstrap: Azure state backend (once per project)

Creates the SHARED backend - one resource group with one storage account and
one blob container. Every env stores its state under its own key in the same
container. Do NOT create per-env accounts.

```bash
LOCATION=westeurope
RG=my-app-tfstate-rg                   # resource group for state only
ACCOUNT=myapptfstate                   # 3-24 chars, LOWERCASE + digits ONLY (no hyphens!)
CONTAINER=tfstate

az group create --name "$RG" --location "$LOCATION"

az storage account create \
  --name "$ACCOUNT" --resource-group "$RG" --location "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 --allow-shared-key-access true

az storage container create --name "$CONTAINER" --account-name "$ACCOUNT"
```

Note: storage account names are globally unique and limited to 24 lowercase
alphanumeric characters - pick accordingly.

Set `ARM_SUBSCRIPTION_ID` (plus tenant/client variables for a service
principal) in your environment before `task init-backend` - the engine needs
them for both the backend and the provider.

Then substitute these values in every `envs/*/backend.tf` (and the region in
each `envs/*/provider.tf`): the resource group, storage account and container
names replace their placeholder tokens in those files. Run this once - the
backend is shared by all envs.
