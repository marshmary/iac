# dev/baseline unit — the convention-only component applied once per
# environment. New components copy this shape: include root.hcl (with
# expose), point `source` at the module, map shared locals into inputs.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  # Locals from the included root.hcl (available because expose = true):
  project     = include.root.locals.project
  env         = include.root.locals.env
  common_tags = include.root.locals.common_tags
}

terraform {
  # <repo-root>//modules/baseline — Terragrunt copies the tree before the
  # `//` into the unit's .terragrunt-cache and runs the module after it.
  source = "${find_in_parent_folders("root.hcl")}//modules/baseline"
}

inputs = {
  project     = local.project
  environment = local.env
  tags        = local.common_tags
}

# ---------------------------------------------------------------------------
# Dependency management (reference for future components)
#
# A component consuming this unit's outputs declares:
#
#   dependency "baseline" {
#     config = "../baseline"
#   }
#
# ...then references e.g. dependency.baseline.outputs.name_prefix in its
# inputs. Terragrunt derives plan/apply ordering across units from these
# blocks; `task graph` renders the resulting DAG to deps.dot / deps.png.
# ---------------------------------------------------------------------------
