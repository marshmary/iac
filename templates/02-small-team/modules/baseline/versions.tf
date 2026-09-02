# Pure module: no required_providers on purpose - nothing here touches a
# cloud, which keeps validate/test offline and fast.
terraform {
  required_version = ">= 1.11.0, < 2.0.0"
}
