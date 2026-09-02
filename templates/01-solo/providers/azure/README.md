# Azure provider addendum

These files are merged into the project root when the template is
instantiated with `-Provider azure`: `backend.tf` (azurerm blob state),
`provider.tf` (azurerm 4.x) and `starter.tf` (example resource group).

Auth is environment-variable based: `ARM_SUBSCRIPTION_ID`, `ARM_CLIENT_ID`,
`ARM_CLIENT_SECRET`, `ARM_TENANT_ID` — see `.env.example`.

Create the state storage first: `bootstrap/azure.md`.
