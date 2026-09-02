# staging

Pre-production environment - changes are rehearsed here (coming from dev) before they reach prod.
State is fully isolated from dev/prod: this directory owns its backend key and lock.
Bootstrap the shared backend once (`../bootstrap/<cloud>.md`), then run `task init-backend ENV=staging` before the first plan.
