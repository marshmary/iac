# Native test — executed by `task test`, which runs `tofu test`.
# No mock_provider needed: the only resource (terraform_data) is built into
# the engine, so this suite runs with zero cloud credentials. `task test`
# skips with a message when the engine resolves to plain terraform.

run "conventions" {
  command = plan

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
