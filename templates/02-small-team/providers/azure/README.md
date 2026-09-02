# Azure provider layer (raw template)

These files are raw template layers with placeholder tokens - they are NOT
used directly. The project initializer copies `backend.tf`, `provider.tf` and
`starter.tf` from here into EVERY `envs/*/` directory (replacing the env
placeholder with each directory name) and then deletes this directory.
After init, edit the copies under `envs/<env>/`, never here.

## Required environment variables

Authentication via service principal or CLI - set in the environment, never
commit (see `.env.example` at the repo root):

- `ARM_SUBSCRIPTION_ID` - required by azurerm v4 (backend AND provider)
- `ARM_TENANT_ID`, `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET` - service principal
- Interactive: `az login`, with `ARM_SUBSCRIPTION_ID` still set.

## State backend

Resource group, storage account and container are created once per project -
see `bootstrap/azure.md` in the repo root. One container, one key per env.
