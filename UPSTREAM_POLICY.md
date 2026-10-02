# Upstream auto-bump policy

Upstream: `https://github.com/GangYe293/wordgloss.koplugin`
Branch: `main`

`.upstream-base` records the exact upstream commit already absorbed by this private downstream.

## Goal

Keep the private downstream current with upstream while preserving downstream behavior.

## SAFE

Amp may classify a bump as `safe` only when all of these are true:

1. The requested upstream SHA descends from `.upstream-base`.
2. The upstream delta has no unresolved semantic interaction with downstream changes.
3. Settings, persisted data, caches/databases, update/install behavior, public plugin
   interfaces, and KOReader lifecycle hooks remain compatible.
4. No dependency, license, security, generated-data, or migration change needs a
   human policy decision.
5. The update can be integrated by Git without a merge conflict.
6. The fixed post-merge validation in GitHub Actions passes.

File overlap is a review signal. It does not by itself decide safety.

## NEEDS_HUMAN

Use `needs-human` whenever a behavior decision is required, including:

- upstream changes code relied on by downstream customizations;
- an API, settings, schema, cache/database, lifecycle, packaging, or updater change
  that could affect downstream behavior;
- a merge conflict;
- insufficient evidence for unattended integration;
- dependency, license, security, or migration changes needing an explicit decision;
- confidence below the threshold for unattended merge.

For `needs-human`, GitHub Actions creates an issue containing the exact upstream SHA
and Amp's analysis. Product code remains unchanged.

## Protected auto-bumper files

Any upstream change to these paths always requires human review:

- `.github/workflows/upstream-auto-bump.yml`
- `.upstream-base`
- `AGENTS.md`
- `UPSTREAM_POLICY.md`
- `tools/upstream-impact.sh`

## Current downstream invariants

Until explicit downstream product changes are added, preserve the imported upstream
behavior exactly. Add intentional downstream behavior here before relying on unattended
bumps to preserve it.
