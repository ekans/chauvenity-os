---
name: land
description: >-
  Land changes in chauvenity-os only when the user explicitly requests landing,
  such as through Land Changes or a direct merge request. Do not invoke for
  review, preparation, passing checks, or installing this skill alone.
disable-model-invocation: true
metadata:
  delta-action: land
---

# Land changes

Carry an explicit landing request through the repository's required review,
verification, pull request, merge, and destination checks. The request that
invoked this skill is permission to carry out those steps; do not ask the user
again whether to merge. Stop only for a genuine blocker, unclear scope,
ambiguous conflict, or a newly applicable requirement that needs the user's
input.

## 1. Establish scope and repository state

1. Confirm this is the `ekans/chauvenity-os` repository, inspect the `origin`
   URL, current branch, default branch, and worktree status. The current
   destination is `main`; verify it again rather than assuming it has not
   changed.
2. Check GitHub CLI authentication without printing credentials. If GitHub
   access is unavailable, stop and report the blocker; do not attempt to
   install tools or access tokens.
3. Identify the exact requested changes from the current branch and worktree
   diff. Include only changes that belong to this request. Preserve unrelated
   edits, untracked files, and staged changes. Do not reset, discard, stash, or
   overwrite them.
4. If the worktree contains ambiguous or partially staged changes, or unrelated
   staged changes that cannot be safely kept out of the requested commit, stop
   and ask the user to clarify. Do not silently widen the landing scope.
5. If the current branch is the protected destination branch and the requested
   changes are uncommitted or committed locally, create a descriptive topic
   branch before committing or publishing. If changes are already on a topic
   branch, confirm its base and PR scope. Stop if unrelated commits would enter
   the PR or if the branch is part of a stack whose landing order is unclear.
6. Use a concise commit and PR title. Existing project history commonly uses
   Conventional Commit prefixes such as `docs:`, `fix:`, and `feat:`, but there
   is no required title format or PR template. Do not invent an issue number or
   a changelog entry.

## 2. Check contribution requirements and destination rules

Before publishing, verify the current GitHub repository and default-branch
settings. Check active rulesets and branch protection for the destination,
including required reviews, code-owner approval, required status checks,
linear history, merge queues, signature requirements, and allowed merge
methods. Also check for contribution instructions and PR templates in the
current checkout.

The repository currently has no `CONTRIBUTING` guide or PR template, and no
documented CLA, DCO, changelog, or commit-signature requirement. `CODEOWNERS`
names `@ekans`, but the current rules do not require a review. These are
observations, not permanent policy: obey any applicable requirements found at
execution time. If a new rule requires human-authored text, obtain that text
from the user instead of writing it on their behalf.

At setup time, the `main` ruleset required linear history and a strict
`Build Custom Image (recipe.yml)` status check; the repository allowed squash
merges only and deleted remote branches after merging. Do not assume these
settings remain unchanged. Do not push directly to `main`, use administrator
bypass, disable rules, or circumvent a required review, check, or merge queue.
If current destination rules cannot be inspected, stop.

## 3. Verify the requested changes

- For code, recipe, image, or system configuration changes, run
  `mise run verify` before opening the PR. This task runs `check`, `build`,
  `test:contract`, and `test:boot` in order and stops at the first failure.
  `mise run check` is the static-only task when diagnosing a failure.
  (Definitions: `mise.toml`.)
- For documentation-only changes, run `git diff --check`; do not run the full
  image build solely for prose changes. There is no repository Markdown lint
  task.
- If a change touches `files/system/etc/niri/**`,
  `files/system/etc/xdg/quickshell/**`, or `files/system/etc/greetd/**`, also
  verify that the PR's `niri-session-config-check` workflow runs and passes.
  It validates both niri configs and type-checks shipped QML.
  (Trigger and checks: `.github/workflows/niri-session-config-check.yml`.)
- The `image-contract` workflow is a weekly check of the published image, not a
  pre-merge PR gate. Do not substitute it for `mise run verify` or for required
  PR checks. (Definition: `.github/workflows/image-contract.yml`.)

If a local check fails, stop without publishing or merging. Report the failing
check and its evidence. Fix only changes clearly within the request, then rerun
the relevant verification. If the fix would expand or alter scope, ask first.

## 4. Prepare and publish a pull request

1. Fetch `origin` and ensure the topic branch is based on the current
   destination. Preserve unrelated work while doing so. When updating a topic
   branch, prefer a normal merge of the destination rather than rewriting a
   published branch or force-pushing.
2. Resolve conflicts automatically only when the intended result is clear from
   the changes and surrounding code. Never choose `ours` or `theirs` wholesale
   as a shortcut. If intent is ambiguous, stop and ask the user. Rerun relevant
   verification after any resolution.
3. Commit only the requested changes, using a non-interactive commit message.
   If the user has unrelated staged changes, do not include or unstage them.
   If the requested files cannot be committed separately without changing the
   user's staging, stop and ask.
4. Push the topic branch to `origin` and open a PR targeting the verified
   default branch. Provide a concise title and a body describing the change and
   actual checks run. Use explicit CLI flags; do not open an editor or rely on
   interactive prompts.
5. If GitHub reports that the PR needs an update, merge the current destination
   into the topic branch, resolve conflicts by the rule above, rerun
   verification, push, and wait for checks on the updated PR head.

The `bluebuild` workflow runs on every pull request, and the active ruleset
currently requires `Build Custom Image (recipe.yml)`, even for documentation
changes. The niri workflow is path-triggered as described above.
(Workflow definition: `.github/workflows/build.yml`.)

## 5. Wait for checks, then merge

1. Confirm the PR targets the verified default branch and its head commit is
   exactly the commit being landed. Review the PR diff to ensure it contains
   only the requested scope.
2. Wait for every currently required status check and every applicable
   change-triggered CI check to complete successfully on that exact PR head.
   Pending, failing, cancelled, missing, or unverifiable checks are not
   success. Do not use auto-merge as a substitute for verifying completion.
3. Satisfy any currently required review or conversation-resolution rules.
   Lack of a required review in the initial repository settings does not
   override a rule that may be added later.
4. If a merge queue is required, follow the queue and verify its final result.
   Otherwise, merge using the currently allowed method; at setup time that was
   squash only. Never use an admin bypass.
5. Verify GitHub reports the PR as merged, fetch `origin`, and confirm the
   resulting merge commit is an ancestor of the destination branch. The
   repository currently deletes remote topic branches after merging. Do not
   delete local branches or switch away from unrelated local work merely for
   cleanup.

If any prerequisite or final-state check cannot be verified, report that the
changes have not been confirmed as landed and explain the blocker.
