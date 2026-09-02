# Module tests - run with `tofu test` from modules/baseline/, or `task test`
# from the repo root. Terraform users: rely on `task check` / `task plan`
# (this tier standardizes module tests on OpenTofu - see AGENTS.md).

run "naming" {
  command = plan

  variables {
    project     = "my-app"
    environment = "dev"
  }

  assert {
    condition     = output.name_prefix != null
    error_message = "name_prefix must be produced at plan time."
  }

  assert {
    condition     = output.name_prefix == "my-app-dev"
    error_message = "name_prefix must render as \"<project>-<environment>\"."
  }

  assert {
    condition     = output.tags["Env"] == "dev" && output.tags["ManagedBy"] == "iac"
    error_message = "tags must carry Env and ManagedBy."
  }
}
