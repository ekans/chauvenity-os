# Local agent instruction

All implementation must follow strict TDD loop.

All changes must be done on a new worktree.
When the implementation is done, ask to the user a confirmation to conventionnal commit and ff merge.

Before asking to commit, all the gates must pass. Run `mise run verify`: it chains
`check` (recipe schema, shellcheck, module order), `build`, `test:contract` and `test:boot`,
stopping at the first failure. Do not ask to commit, and do not commit, while any gate fails or
was skipped; fix the cause and rerun `mise run verify` until it is fully green.
