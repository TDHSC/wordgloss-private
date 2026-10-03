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

Preserve these intentional private downstream behaviors across upstream bumps:

1. KOReader Vocabulary Builder words are forced WordGloss candidates. A saved surface
   form or its lemma bypasses the normal rank and proper-name filters.
2. Saved Vocabulary Builder words receive priority within the per-page annotation cap.
3. Vocabulary Builder changes are detected from the SQLite database together with its
   WAL/SHM files, so newly saved words become visible on subsequent page refreshes.
4. Current-chapter translation, whole-book incremental translation, whole-book overwrite,
   and reading-time auto-prefetch all use the same Vocabulary Builder override.
5. Enabling reading-time auto-prefetch refreshes the current page immediately so a newly
   saved vocabulary word can trigger translation without waiting for another page turn.
6. Inflection difficulty uses a separate lemma relationship. Ranked inflections use the
   more common effective difficulty rank while keeping their own gloss/cache identity.
   Example: `said` inherits the frequency of `say` without redirecting its gloss to
   `say`.
7. The compact lexicon schema v2 keeps `base` for gloss fallback and `lemma` for
   difficulty/vocabulary matching. Future data-pack rebuilds must preserve that separation.
8. WordGloss keeps a global `known_words` set in its own SQLite database. A known word
   has higher priority than Vocabulary Builder forcing, rank, and proper-name rules.
9. The dictionary popup exposes a WordGloss known-word toggle. Marking a word known
   refreshes the current page immediately and keeps existing gloss cache entries intact.
10. Known-word canonicalization uses `base` only when the form already shares its gloss
    with that base; ranked forms with their own gloss keep an exact-word known key.
