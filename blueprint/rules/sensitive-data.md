## Sensitive data

Sensitive material goes in `encrypted/`, which git-crypt encrypts on the remote while it stays readable on the owner's machine. Only `encrypted/README.md` stays in clear; the check fails if anything else there is committed unencrypted. Without git there is no encryption at all: keep sensitive material out, or use storage with end-to-end encryption.

Keep only what agents need: whatever an agent reads reaches the model provider, encrypted on the remote or not. Identity and account data (ID numbers, bank accounts, passwords) belong in a password manager; for the rest, a summary beats the whole document. Use neutral file names, because git-crypt does not encrypt names.
