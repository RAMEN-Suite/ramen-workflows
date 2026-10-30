# ramen-workflows

Shared GitHub Actions for the RAMEN-Suite repositories.

- `.github/workflows/`: reusable workflows (`on: workflow_call`). Files starting with `_` are this repository's own (see [Development](#development)).
- `actions/<name>/`: composite actions, used by the reusable workflows.

| Workflow | What it does |
|---|---|
| [`actions-lint.yml`](#actions-lintyml) | zizmor and actionlint over the workflows and actions |
| [`conventional-node.yml`](#conventional-nodeyml) | commitlint over pushed commits and PR titles |
| [`security.yml`](#securityyml) | trivy, gitleaks, semgrep, CodeQL |
| [`supply-chain.yml`](#supply-chainyml) | npm registry signatures and licenses |
| [`node-ci.yml`](#node-ciyml) | lint, unit tests, end-to-end tests and package checks for an npm project |

## Usage

Call a reusable workflow from a thin workflow in your repository, pinned to the commit of a release:

```yaml
jobs:
  ci:
    name: CI
    permissions:
      contents: read # required for actions/checkout to fetch repo contents if this repo is private
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/<workflow>.yml@<full commit sha> # vX.Y.Z
```

- Pin the full commit SHA of a release, with the version as a comment.
- The calling job grants the permissions. A reusable workflow can only reduce them, so each one documents what it needs.
- Pass each secret by name under `secrets:`, never `secrets: inherit`.
- Status checks are named `<caller job name> / <job name>`.
- Run the workflows on `push` to `main` and `renovate/**` and on pull requests, without a `paths` filter: a required check whose workflow was filtered out stays pending.

## Workflows

### `actions-lint.yml`

zizmor (security) and actionlint (correctness) over the calling repository's workflows and actions. Require both checks.

```yaml
name: Actions lint

on:
  push:
    branches: [main, "renovate/**"] # renovate/**: Renovate automerges a branch only after its checks passed
  pull_request:
    branches: [main]

permissions: {}

jobs:
  actions-lint:
    name: Actions lint
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/actions-lint.yml@<full commit sha> # vX.Y.Z
    permissions:
      security-events: write # required for uploading zizmor results to code scanning
      contents: read # required for actions/checkout to fetch repo contents if this repo is private
      actions: read # required for upload-sarif to read workflow run info in private repos
```

| Input | Default | |
|---|---|---|
| `advanced-security` | `true` | Public repositories: upload zizmor findings to code scanning (gate them with a code scanning rule for tool `zizmor`) instead of failing the job. Private repositories always fail on findings. |

Checks: `Actions lint / Run Zizmor`, `Actions lint / Run actionlint`.
If the repository uses `$/`, add a `.github/actionlint.yaml` like [this repository's](.github/actionlint.yaml).

### `conventional-node.yml`

commitlint over pushed commits (`Lint commits`, on `push`) and pull request titles (`Lint PR title`, on `pull_request`), with the repository's own commitlint config.
With squash merges the title becomes the commit on `main`, so require `Lint PR title`.
Needs `@commitlint/cli` and a commitlint config in the devDependencies, and `package-lock.json` and `.nvmrc` in the repository root.

```yaml
name: Conventional commits

on:
  push:
  pull_request:
    branches: [main]
    types: [opened, edited, synchronize, reopened] # edited: re-check when the title changes

concurrency:
  group: ${{ github.workflow }}-${{ github.event_name }}-${{ github.ref_name }}
  cancel-in-progress: true

permissions: {}

jobs:
  conventional:
    name: Conventional
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/conventional-node.yml@<full commit sha> # vX.Y.Z
    permissions:
      contents: read # required for actions/checkout to fetch repo contents if this repo is private
```

Checks: `Conventional / Lint commits` (on push), `Conventional / Lint PR title` (on pull requests). For the other event each job is skipped under a different name (`… (push only)`, `… (pull request only)`), so a skipped run can't satisfy a required check.

### `security.yml`

Dependency vulnerabilities (trivy), secrets in the git history (gitleaks), SAST (semgrep) and CodeQL.
gitleaks (any leak) and semgrep (`ERROR` findings) fail their job; trivy only reports. Reports go to code scanning on public repositories; CodeQL runs only there.

```yaml
name: Security

on:
  push:
    branches: [main, "renovate/**"]
  pull_request:
    branches: [main]

permissions: {}

jobs:
  security:
    name: Security
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/security.yml@<full commit sha> # vX.Y.Z
    with:
      semgrep-configs: p/security-audit p/secrets p/typescript p/javascript
      codeql-config-file: ./.github/codeql/codeql-config.yml
    permissions:
      contents: read # required for actions/checkout to fetch repo contents if this repo is private
      security-events: write # required for uploading results to code scanning
```

| Input | Default | |
|---|---|---|
| `semgrep-configs` | `p/security-audit p/secrets` | Semgrep rulesets, space-separated |
| `codeql-languages` | `javascript-typescript` | Comma-separated; interpreted languages only (`build-mode: none`), e.g. `javascript-typescript,actions` |
| `codeql-config-file` | | CodeQL config file in the calling repository, starting with `./` |

Checks: `Security / Vulnerability and secret scan`, `Security / SAST scan`, `Security / CodeQL`.
Code scanning tools (for code scanning rules): `Trivy`, `Gitleaks`, `Semgrep OSS`, `CodeQL`; categories `trivy-fs`, `gitleaks`, `sast`, `/language:<codeql-languages>`.
A `.gitleaks.toml` in the repository root is picked up.
CodeQL default setup must be off in the repository (Settings → Code security → CodeQL analysis), or GitHub rejects the uploads.

### `supply-chain.yml`

`npm audit signatures` and a license scan (trivy) on the npm project in the repository root; the scan fails on restricted or forbidden licenses (`HIGH`/`CRITICAL`).
Needs `package-lock.json` and `.nvmrc` in the repository root. Package sources are not linted: keep a hardened `.npmrc` (`allow-git=none`, `allow-remote=none`) in the repository.

```yaml
jobs:
  supply-chain:
    name: Supply chain
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/supply-chain.yml@<full commit sha> # vX.Y.Z
    permissions:
      contents: read # required for actions/checkout to fetch repo contents if this repo is private
```

| Input | Default | |
|---|---|---|
| `include-dev-deps` | `false` | Also scan the licenses of devDependencies (by default only what ships) |

Check: `<caller job name> / Supply chain`.

### `node-ci.yml`

Lint, unit tests, end-to-end tests (Playwright) and package checks for an npm project. Pass npm script names; an empty input skips its job.
Needs `.nvmrc` in the repository root and `package-lock.json` in `working-directory`.

```yaml
jobs:
  ci:
    name: CI
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/node-ci.yml@<full commit sha> # vX.Y.Z
    with:
      test-scripts: test:coverage test:tools
      coverage-summary: coverage/sushi/coverage-summary.json
      e2e-script: test:e2e
      package-script: package:check
    permissions:
      contents: read # required for actions/checkout to fetch repo contents if this repo is private
```

| Input | Default | |
|---|---|---|
| `working-directory` | `.` | Directory of the npm project (`package.json`, `package-lock.json`) |
| `lint-scripts` | `lint format typecheck` | Job `Lint and format`, run in order |
| `test-scripts` | `test` | Job `Unit tests`, run in order |
| `coverage-summary` | | `coverage-summary.json` (istanbul `json-summary`), relative to `working-directory`; `coverage/` is uploaded |
| `e2e-script` | | Job `End-to-end tests` with Playwright |
| `package-script` | | Job `Package checks` |

Checks: `CI / Lint and format`, `CI / Unit tests`, `CI / End-to-end tests`, `CI / Package checks` (with the caller job name `CI`).

## Actions

Helpers of the reusable workflows; they write job summaries.

| Action | Input |
|---|---|
| `actions/sarif-summary` | a SARIF report (trivy, gitleaks, semgrep) |
| `actions/license-summary` | a trivy license report (JSON) |
| `actions/coverage-summary` | an istanbul `coverage-summary.json` |

## Versioning

A release is a tag `vX.Y.Z` with an immutable GitHub release. It versions the whole repository: every workflow and action.

- **Major**: callers have to change something. A workflow, action, input, output or secret is removed or renamed, a new input or permission is required, or a job name changes (job names are the status checks that rulesets require).
- **Minor**: a new workflow, action or optional input.
- **Patch**: fixes and dependency updates that callers don't notice.

Reusable workflows use this repository's actions as `$/actions/<name>`. GitHub resolves `$/` to the commit the workflow runs from, so a workflow and its actions always come from the same release.
`$/` takes no `@ref`, and needs GitHub.com with GitHub-hosted runners or self-hosted runners 2.336.0 or later.

### Releases

The release is immutable and carries the source tarball with its build provenance. A manual run of the Release workflow can force a version (`release_as`) or do a dry run.

Verify a release:

```sh
gh release verify vX.Y.Z --repo RAMEN-Suite/ramen-workflows
gh release download vX.Y.Z --repo RAMEN-Suite/ramen-workflows --pattern '*.tar.gz'
gh attestation verify ramen-workflows-vX.Y.Z.tar.gz --repo RAMEN-Suite/ramen-workflows
```

## Development

Workflows whose file name starts with `_` serve only this repository: `_test-<workflow>.yml` runs the reusable `<workflow>.yml` against this repository the way a caller would (its self-test; `fixtures/` holds test projects), `_release.yml` and `_scorecard.yml` are this repository's own.
Only files without `_` are meant to be called, and only they (and `actions/`) trigger a release.

Set up once per clone:

```sh
npm install                          # commitlint for the commit-msg hook
git config core.hooksPath .githooks  # .npmrc sets ignore-scripts, so "prepare" doesn't do it
```

Commits and pull request titles follow [Conventional Commits](https://www.conventionalcommits.org); only `deps` (Renovate) and `release` (release bot) are used as scopes.
Pull requests are squash-merged, so the title is what ends up on `main` and in the changelog.

Check locally, from the repository root:

```sh
actionlint
zizmor .
```

actionlint 1.7.12 doesn't know `$/` yet. `.github/actionlint.yaml` ignores exactly those errors; remove it once actionlint supports `$/` ([rhysd/actionlint#732](https://github.com/rhysd/actionlint/issues/732)).

## License

[MIT](LICENSE)
