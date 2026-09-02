# Shared Terragrunt configuration (Gruntwork include pattern).
#
# Every unit (envs/<env>/<component>/terragrunt.hcl) includes this file, so
# project-wide naming, tags and cloud plumbing live here exactly once.
# Locals defined here reach the units through the `expose = true` include
# block each unit declares (include.root.locals.*).
locals {
  project = "__PROJECT_NAME__"

  # Derive the environment from the env.hcl found in the unit's parent
  # directories, e.g. envs/dev/env.hcl -> "dev".
  env = basename(dirname(find_in_parent_folders("env.hcl")))

  common_tags = {
    Project   = local.project
    Env       = local.env
    ManagedBy = "terragrunt"
  }
}

# ---------------------------------------------------------------------------
# Cloud provider injection contract
#
# The lines between the two CLOUD PROVIDER markers below are REPLACED by
# scripts/init-project.{sh,ps1} with the contents of
# providers/<cloud>/root-provider.hcl (-Provider aws|azure|gcp) at project
# creation time; the providers/ directory is deleted afterwards. The
# injected payload contains Terragrunt `generate` blocks that write
# backend.tf and provider.tf into every unit's runtime working directory.
#
# To switch clouds by hand later: paste the desired payload between the
# markers and fill in its placeholder tokens (see providers/README.md for
# the full contract while the raw template still has it).
# ---------------------------------------------------------------------------

# >>> CLOUD PROVIDER (injected by init-project — edit below this line) <<<
# <<< END CLOUD PROVIDER (injected by init-project) <<<
