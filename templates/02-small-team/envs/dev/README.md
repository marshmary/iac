# dev

Scratch environment for fast iteration - anything here is disposable and may be destroyed without notice.
State is fully isolated from staging/prod: this directory owns its backend key and lock.
Bootstrap the shared backend once (`../bootstrap/<cloud>.md`), then run `task init-backend ENV=dev` before the first plan.
