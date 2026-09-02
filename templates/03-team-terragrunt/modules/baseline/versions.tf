terraform {
  # Deliberately provider-free: only the core engine is constrained so the
  # module validates, plans and tests fully offline on every cloud.
  required_version = ">= 1.6.0, < 2.0.0"
}
