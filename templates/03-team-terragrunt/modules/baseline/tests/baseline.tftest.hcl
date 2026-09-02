# Native test-framework suite for the baseline module.
# Run from the module directory: tofu test  (or terraform test when the
# terraform engine is selected — the `task test` wrapper handles the guard).
run "baseline" {
  command = plan

  variables {
    project     = "example"
    environment = "dev"
  }

  assert {
    condition     = output.name_prefix != null
    error_message = "name_prefix must not be null."
  }

  assert {
    condition     = output.name_prefix == "example-dev"
    error_message = "name_prefix should render as <project>-<environment>."
  }

  assert {
    condition     = output.tags != null
    error_message = "tags must not be null."
  }
}
