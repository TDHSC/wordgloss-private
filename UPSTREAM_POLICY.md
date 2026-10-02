# Upstream auto-bump policy

Upstream: `https://github.com/GangYe293/wordgloss.koplugin`
Branch: `main`

`.upstream-base` records the exact upstream commit already absorbed by this private downstream.

## Goal

Keep the private downstream current with upstream with a strong preference for unattended
updates. Escalate only when there is concrete evidence that upstream conflicts with
downstream behavior or the automated integration cannot be verified.

## SAFE

Classify a bump as `safe` when the update can be integrated cleanly and no concrete
downstream incompatibility is identified.

The following are review signals and are allowed in a safe bump when they do not actually
conflict with downstream customizations:

- upstream and downstream touching the same file;
- settings or UI changes;
- cache/database/schema changes that remain internally compatible;
- updater/install/packaging changes;
- lifecycle-hook or public-interface changes;
- dependency or generated-data updates;
- broad refactors or file moves.

A bump is safe when:

1. The requested upstream SHA descends from `.upstream-base`.
2. Git can integrate the requested upstream SHA without an unresolved merge conflict.
3. Amp identifies no specific semantic conflict with the downstream delta.
4. Fixed post-merge validation in GitHub Actions passes.
5. Protected auto-bumper infrastructure remains under downstream control.

When the downstream has no customization in an affected behavior, prefer `safe`.

File overlap alone never requires human review.

## NEEDS_HUMAN

Use `needs-human` only when there is a specific actionable reason, including:

- a real semantic conflict between upstream behavior and a downstream customization;
- a merge conflict with more than one behaviorally plausible resolution;
- a required data/settings migration that the automation cannot safely perform;
- a license or security decision that requires owner judgment;
- fixed post-merge validation failure;
- upstream modification of protected auto-bumper infrastructure;
- evidence that auto-merging would remove, bypass, or materially change an intentional
  downstream behavior.

General uncertainty, large diffs, refactors, file overlap, API changes, settings changes,
or cache/schema changes are not sufficient by themselves. Identify a concrete downstream
impact before returning `needs-human`.

## Protected auto-bumper files

Any upstream change to these paths always requires human review:

- `.github/workflows/upstream-auto-bump.yml`
- `.upstream-base`
- `AGENTS.md`
- `UPSTREAM_POLICY.md`
- `tools/upstream-impact.sh`

## Current downstream invariants

Until explicit downstream product changes are added, preserve the imported upstream
behavior exactly. The current downstream product delta is empty, so ordinary upstream
product changes should normally be classified `safe`.

Add intentional downstream behavior here when custom product logic is introduced.
