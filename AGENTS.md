# Agent instructions

This repository is a private downstream of
`https://github.com/GangYe293/wordgloss.koplugin`.

Read `UPSTREAM_POLICY.md` before processing an automated upstream bump.

## Automated GitHub Actions review

When the prompt contains `AUTOMATED_UPSTREAM_BUMP`, you are an analysis gate inside
an ephemeral GitHub Actions checkout.

The workflow provides `.amp-bump-context/` with:

- `meta.txt`: BASE_SHA, NEW_SHA, and current downstream HEAD;
- `upstream-commits.txt`: upstream commits in the bump;
- `upstream-files.txt`: files changed by upstream;
- `downstream-files.txt`: files changed privately since BASE_SHA;
- `overlap-files.txt`: direct path overlap;
- `upstream.diff`: complete BASE_SHA..NEW_SHA patch;
- `downstream.diff`: complete BASE_SHA..downstream-HEAD patch.

Your task is analysis only.

1. Inspect the complete upstream delta and the downstream delta.
2. Trace semantic dependencies across files. File overlap alone does not decide safety.
3. Apply `UPSTREAM_POLICY.md`.
4. Classify the exact requested update as `safe` or `needs-human`.
5. Treat uncertainty as `needs-human`.
6. Do not implement features, resolve conflicts, refactor, run external commands,
   contact remote services, push, create PRs/issues, or change GitHub state.
7. Do not modify product files or auto-bumper infrastructure.
8. The only file you may create or edit is `.amp-bump-result.json`.

Write `.amp-bump-result.json` with this schema:

```json
{
  "decision": "safe",
  "summary": "short factual explanation",
  "risks": [],
  "reviewed_files": ["path"]
}
```

or:

```json
{
  "decision": "needs-human",
  "summary": "exact behavior or compatibility concern",
  "risks": ["specific risk"],
  "reviewed_files": ["path"]
}
```
