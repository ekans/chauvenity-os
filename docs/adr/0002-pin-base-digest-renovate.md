# ADR 0002 — Pin base image by digest, drive rebuilds via Renovate

Status: Accepted
Date: 2026-05-31

## Context

The image is rebuilt by a daily `schedule` cron in
`.github/workflows/build.yml`, even when the upstream base image
(`ghcr.io/ublue-os/bluefin-dx:stable`) has not changed. Most scheduled runs
are no-ops that rebuild an identical image and burn CI minutes.

An interim mitigation was prototyped: a `check-upstream` gate job that, on the
scheduled run, compares the live upstream digest against the
`org.opencontainers.image.base.digest` label baked into the last published
image and skips the build when they match. It works but it polls on a fixed
clock, adds ~25 lines of bespoke `skopeo`/`jq` workflow logic, and base bumps
leave no auditable trace.

The repo already runs Renovate (`.github/renovate.json5`, with a custom regex
manager and digest automerge), so an event-driven alternative is available
without new infrastructure.

## Decision

Pin the base image **by digest** in `recipes/recipe.yml`, let Renovate bump
that digest when upstream `:stable` moves, and **remove both the daily cron and
the `check-upstream` gate**. The build then runs only when:

- repo source changes (push / PR / `workflow_dispatch`), or
- the base digest changes — Renovate opens a digest-bump PR which auto-merges
  (existing `packageRules`), the merge pushes to `main`, and the push triggers
  the build.

This is event-driven (no polling), produces auditable base-bump PRs, and builds
from the exact reviewed digest.

## Evidence it works

Load-bearing facts, verified against `blue-build/cli@76196f6` (2026-05-31) and
crate sources — do not drop on edit:

- **BlueBuild already builds FROM a digest.** Its Containerfile template is
  `ARG BASE_IMAGE="{{ recipe.base_image }}@{{ base_digest }}"`; the CLI resolves
  `base-image:image-version` to `base_digest` at build time
  (`src/commands/generate.rs`).
- **`image-version` accepts a digest, and the build pins to it.** The field type
  is `Tag`, validated by an *unanchored* regex `[\w][\w.-]{0,127}` via `is_match`
  (`utils/src/container.rs`), so `stable@sha256:<d>` passes. The CLI parses
  `base-image:image-version` as an `oci_client::Reference` (the crate actually
  imported in `src/commands/generate.rs`), which retains **both** tag and digest.
  It then computes `base_digest = Driver::get_metadata(...).digest()`, where
  `OciClientDriver::get_metadata` calls `client.pull_manifest(reference, ...)`
  (`process/drivers/oci_client_driver.rs`). `oci_client` resolves a reference
  that carries a digest **by that digest** (digest takes precedence over tag),
  so `base_digest == <d>`. The Containerfile then renders
  `FROM ghcr.io/ublue-os/bluefin-dx@<d>`, building from exactly `<d>`.
- **Renovate digest tracking is current idiom.** A custom regex manager with
  `currentValue` + `currentDigest` + `datasourceTemplate: docker` +
  `autoReplaceStringTemplate` using `{{#if newDigest}}@{{newDigest}}{{/if}}` is
  the documented, widely-used pattern (Renovate docs 2026-04-01; devcontainer
  guide 2025-10-31; podman quadlet 2025-09-12; renovate discussions #40052
  2025-12-17 and #40443 2026-01-15).

## Implementation

### Files changed

**`recipes/recipe.yml`** — pin the digest (current `:stable` digest shown;
Renovate maintains it thereafter):

```yaml
base-image: ghcr.io/ublue-os/bluefin-dx
image-version: stable@sha256:a81bde003edbf62014a2fdd1a6ad2811ad1350e74c56cc11dd7dbdeeccb589d7
```

**`.github/renovate.json5`** — add one custom manager (alongside the existing
`customManagers` entry):

```json5
{
  customType: "regex",
  managerFilePatterns: ["/^recipes/recipe\\.ya?ml$/"],
  matchStrings: [
    "image-version:\\s*(?<currentValue>[^@\\s]+)@(?<currentDigest>sha256:[a-f0-9]+)",
  ],
  depNameTemplate: "ghcr.io/ublue-os/bluefin-dx",
  datasourceTemplate: "docker",
  versioningTemplate: "docker",
  autoReplaceStringTemplate: "image-version: {{{currentValue}}}@{{{newDigest}}}",
}
```

The existing `packageRules` (`automerge` on `pin`/`pinDigest`/`digest`) already
cover the resulting digest updates.

**`.github/workflows/build.yml`** — remove polling/gate:

- delete the `schedule:` cron block under `on:`;
- delete the `check-upstream` job entirely;
- delete `needs: check-upstream` and the
  `if: needs.check-upstream.outputs.should_build == 'true'` from the `bluebuild`
  job.

Keep `push` (with the `paths-ignore: **.md`), `pull_request`, and
`workflow_dispatch` triggers.

### Acceptance criteria

- A `push` to `main` builds the image.
- When upstream `:stable` digest changes, Renovate opens a digest PR that
  auto-merges and the merge triggers a build.
- No scheduled no-op builds occur (the cron is gone).
- The built image's `FROM` resolves to the pinned digest.

## Alternatives rejected

- **`skopeo`/`jq` gate job on a daily cron** (the prototype). Self-contained and
  needs no Renovate, but polls on a fixed clock, adds bespoke workflow logic,
  and leaves base bumps unaudited. Superseded by this ADR.
- **Plain daily cron, no gate** (the BlueBuild stock template). Simplest, but
  rebuilds an identical image most days.
- **Registry webhook / `repository_dispatch`.** Not feasible: GHCR has no
  package-push webhook and the base lives in a third-party repo we cannot hook.
- **Phantom digest anchor** (keep `image-version: stable`, have Renovate manage
  an unused digest comment/sidecar solely to trigger builds). Kept only as a
  fallback if the digest-in-`image-version` behavior breaks; the anchored digest
  would not be the one actually built, which is less honest.

## Risks / Removal criteria

- **Undocumented BlueBuild usage.** Digest-in-`image-version` works via lenient
  `Tag` parsing, not a documented feature. If a future CLI anchors the `Tag`
  regex and rejects it, builds will fail fast at the templating step. Mitigation:
  revert to `image-version: stable` and adopt the phantom-anchor fallback (or the
  `skopeo` gate). Revisit this ADR if BlueBuild documents a first-class
  digest-pin field, in which case migrate to it.
- **Renovate dependency / no safety-net rebuild.** With the cron gone, if
  Renovate is paused or down the base is never rebuilt and base security updates
  stall silently. Accepted for a personal image (KISS). If missed-update risk
  ever matters, add a low-frequency (e.g. weekly) `schedule` cron back — at the
  cost of reintroducing occasional no-op builds.
- **Trigger latency** is bounded by Renovate's run cadence (hosted app ~hourly)
  rather than a fixed 06:00 cron — acceptable for a personal image.
- **Two builds per digest bump.** With both `pull_request` and `push` triggers,
  a digest PR builds once on the PR and again on the post-merge push. Functionally
  fine; if minimizing CI matters, use Renovate branch automerge (no PR) so only
  the push build runs. Not worth the complexity here.
