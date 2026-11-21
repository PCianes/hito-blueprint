## Secrets

Secrets (keys, tokens, `.env` files) never enter the repository, not even encrypted. They live outside it, for example in `~/.secrets/`. Keep them out with `.gitignore` (`.env`, `*.env`, `.env.*`, `*.key`, `*.pem`).
