# prod

Production environment - applies require a reviewed tfplan and two reviewers (see `../CODEOWNERS.example`).
State is fully isolated from dev/staging: this directory owns its backend key and lock.
Bootstrap the shared backend once (`../bootstrap/<cloud>.md`), then run `task init-backend ENV=prod` before the first plan.
