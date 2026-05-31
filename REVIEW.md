# Instructions for an AI agent reviewing a contributor's changes.
# Invoke with: "Apply REVIEW.md to my changes."

## Procedure

1. **Identify scope.** Run `git status` and `git diff --staged` (fall back to `git diff` if nothing staged). If both are empty, halt and tell the user there is nothing to review.

2. **Sync docs with the change.** For every changed recipe or workaround file, confirm the matching docs were updated in the same diff:
   - `CLAUDE.md` — module lists, project structure, recipe composition.
   - Inline comments in touched `files/system/**` drop-ins (`.toml`, `.conf`).
   - Watcher comments in `.github/workflows/upstream-initramfs-check.yml`.
   - ADR cross-references (`Supersedes`, `Superseded by`, "Removal criteria").
   Halt if a behavior changed but any of the above still describes the old behavior.

3. **Decide whether an ADR is required.** An ADR (new file under `docs/adr/`, or an update) is required when ALL THREE hold: the change is hard to reverse, surprising without context, and the result of a real trade-off with rejected alternatives. Halt if all three hold and no ADR is added or updated. Separately: if the change alters a workaround governed by an existing ADR, that ADR's `Status` and `Removal criteria` must be updated in the same diff — halt if not.

4. **Check `dnf` repo/key and version pinning.** New `repos.files` entry must have a matching `repos.keys` entry. New direct release/RPM URL under `install.packages` must carry a `# renovate: datasource=... depName=...` comment on the line above. Base `image-version` in `recipes/recipe.yml` must keep the `tag@sha256:...` form. To confirm a new annotation actually matches, read the existing `customManagers` regex in `.github/renovate.json5`; if the pattern is unfamiliar, web-search the current Renovate custom-manager idiom before approving. Halt on any missing key, missing annotation, or broken digest form.

5. **Challenge new additions (KISS/YAGNI).** This is a personal, single-user image. Every new package, module, repo, or `files/` entry must be used now, not added speculatively. Do not introduce `files/` or `modules/` assets a module does not consume. Halt if an addition is unjustified.

6. **Verify the `initramfs` ordering invariant.** If `recipes/recipe.yml` modules were added or reordered, `initramfs` must remain the last module, after the `files` module that drops the dracut keymap config. Misordering builds successfully but ships a broken initramfs; CI Job B catches it only post-merge. Halt if `initramfs` is not last.

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
- Do not restate what the BlueBuild image build, `upstream-initramfs-check.yml`, or Renovate already enforce.
- Do not modify code. This is review only.
- If a step cannot be executed (missing tool, no network, etc.), report it under "Blocking issues" and continue with the remaining steps.
