# Repository Protection Baseline

This file records the minimum repo-governance baseline that matches the local
protected-branch guard added in this branch.

## In-Repo Controls

The repo now owns these protections directly:

- checked-in Git hooks under `.githooks/`
- a protected-branch commit guard for `master` and `main`
- a GitHub Actions workflow at `.github/workflows/ci.yml`
- a PR checklist at `.github/pull_request_template.md`

The local hooks help prevent accidental direct commits in a clone, but they are
not authoritative server-side protection.

## GitHub Controls To Enable

GitHub must still enforce protected-branch policy on the server.

Configure a branch protection rule or ruleset for:

- `master`
- `main`

Recommended required settings:

- require a pull request before merging
- require conversation resolution before merge
- require branches to be up to date before merging
- disallow force pushes
- disallow branch deletion
- do not require linear history on protected branches

Recommended merge settings:

- allow merge commits
- disable squash merges
- disable rebase merges

Rationale for merge settings:

- preserve visible PR boundaries in the graph
- keep stacked PRs mergeable without repeated ancestry rewrites
- keep the commits that land on `master` aligned with the reviewed branch shape

Recommended once this workflow is merged to the default branch and reporting:

- require the status check `Repo Guardrails / validate`

Optional only when the repo actually has an independent reviewer available:

- require at least 1 approval
- dismiss stale approvals when new commits are pushed

Recommended bypass policy:

- do not allow routine bypass actors
- if an operator-approved exception is needed, handle it as an explicit manual
  repo-setting exception instead of normalizing direct protected-branch pushes

## Why Both Layers Exist

The protections solve different problems:

- local Git hooks stop accidental direct commits in a developer clone
- GitHub branch protection stops direct landing on the remote default branch
- CI provides a required merge gate for shell validity and branch-guard
  validation itself

If GitHub protection is not enabled, the repo can still be changed on the
server without going through the intended PR path.

## Next CI Expansion

Add app-wide required checks only after the protected-branch baseline is green
for those commands on the default branch.

The intended next required checks are:

- `flutter analyze`
- `flutter test`

Do not make those checks required while the baseline is already red, because
that turns branch protection into a blanket merge freeze instead of a sane
governance gate.
