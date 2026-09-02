# Native test — executed by `task test`, which runs `tofu test`.
# mock_provider keeps this credential-free: the cloud provider is never
# configured or called, only its schema is downloaded by `init`. The run
# applies (locally — terraform_data computes natively, the cloud resource is
# mocked) so asserts see final values, not "known after apply" placeholders.
# `task test` skips with a message when the engine resolves to terraform
# (mock_provider is an OpenTofu extension).

mock_provider "google" {}

run "conventions" {
  command = apply

  # variables.tf gives `project` no default, so every run must supply it.
  variables {
    project = "conventions-check"
  }

  assert {
    condition     = output.conventions != null
    error_message = "output.conventions did not render; check locals and terraform_data in main.tf."
  }

  assert {
    condition     = output.conventions == "conventions-check-dev"
    error_message = "name prefix must be '<project>-<environment>' (environment defaults to dev); check local.name_prefix in main.tf."
  }
}
