# Instructions for an AI agent reviewing a contributor's changes.
# Invoke with: "Apply REVIEW.md to my changes."

## Procedure

1. **Identify scope.** Run `git status` and `git diff --staged` (fall back to `git diff` if nothing staged). If both are empty, halt and tell the user there is nothing to review.

2. **Sync docs with the change.** For every changed recipe or workaround file, confirm the matching docs were updated in the same diff:
   - `README.md` — "What's Included" package lists, "Known issues / workarounds", "Dependency updates".
   - Inline comments in touched `recipes/*.yml` and `files/system/**` drop-ins (`.toml`, `.conf`).
   - Comments in `.github/workflows/image-contract.yml` and the checks in `test/image-contract.sh`.
   Halt if a behavior changed but any of the above still describes the old behavior.

3. **Check `dnf` repo/key and version pinning.** New `repos.files` entry must have a matching `repos.keys` entry. New direct release/RPM URL under `install.packages` must carry a `# renovate: datasource=... depName=...` comment on the line above. Base `image-version` in `recipes/recipe.yml` must keep the `tag@sha256:...` form. To confirm a new annotation actually matches, read the existing `customManagers` regex in `.github/renovate.json5`; if the pattern is unfamiliar, web-search the current Renovate custom-manager idiom before approving. Halt on any missing key, missing annotation, or broken digest form.

4. **Challenge new additions (KISS/YAGNI).** This is a personal, single-user image. Every new package, module, repo, or `files/` entry must be used now, not added speculatively. Do not introduce `files/` or `modules/` assets a module does not consume. Halt if an addition is unjustified.

5. **Verify the `initramfs` ordering invariant.** If `recipes/recipe.yml` modules were added or reordered, `initramfs` must remain the last module, after the `files` module that drops the keymap `kargs.d` drop-in. Misordering builds successfully but ships a broken initramfs; `mise run check` catches it locally, the `image-contract` workflow only post-merge. Halt if `initramfs` is not last.

## Output

Produce a report with this structure, in this order:

### Summary
- Files reviewed: N
- Blocking issues: N
- Suggestions: N

### Blocking issues
For each: `<file>:<line> — <one-line description>. <required fix>.`
If none: write "None."

### Suggestions
For each: `<file>:<line> — <one-line description>.`
If none: write "None."

## Rules

- Do not invent checks not listed above.
- Do not restate what the BlueBuild image build, `mise run verify`, `image-contract.yml`, or Renovate already enforce.
- Do not modify code. This is review only.
- If a step cannot be executed (missing tool, no network, etc.), report it under "Blocking issues" and continue with the remaining steps.
