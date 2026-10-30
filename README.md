# ramen-workflows

Shared GitHub Actions for the RAMEN-Suite repositories.

- `.github/workflows/`: reusable workflows (`on: workflow_call`). Files starting with `_` are this repository's own (see [Development](#development)).
- `actions/<name>/`: composite actions, used by the reusable workflows.

| Workflow | What it does |
|---|---|
| [`actions-lint.yml`](#actions-lintyml) | zizmor and actionlint over the workflows and actions |
| [`commitlint-node.yml`](#commitlint-nodeyml-and-pr-title-nodeyml) | commitlint over pushed commits |
| [`pr-title-node.yml`](#commitlint-nodeyml-and-pr-title-nodeyml) | commitlint over pull request titles |
| [`security.yml`](#securityyml) | trivy, gitleaks, semgrep, CodeQL |
| [`supply-chain.yml`](#supply-chainyml) | npm registry signatures and licenses |
| [`node-ci.yml`](#node-ciyml) | lint, unit tests, end-to-end tests and package checks for an npm project |
| [`npm-release.yml`](#npm-releaseyml-and-npm-publishyml) | version, build, tag and GitHub release of an npm package |
| [`npm-publish.yml`](#npm-releaseyml-and-npm-publishyml) | stage the released package on npm and verify it once approved |
| [`pages.yml`](#pagesyml) | build a site and deploy it to GitHub Pages |

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

### `commitlint-node.yml` and `pr-title-node.yml`

commitlint with the repository's own commitlint config: `commitlint-node.yml` over the pushed commits (call it on `push`), `pr-title-node.yml` over the pull request title (call it on `pull_request`).
With squash merges the title becomes the commit on `main`, so require `Lint PR title`.
Needs `@commitlint/cli` and a commitlint config in the devDependencies, and `package-lock.json` and `.nvmrc` in the repository root.

```yaml
name: Commitlint

on:
  push:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref_name }}
  cancel-in-progress: true

permissions: {}

jobs:
  commitlint:
    name: Conventional
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/commitlint-node.yml@<full commit sha> # vX.Y.Z
    permissions:
      contents: read # required for actions/checkout to fetch repo contents if this repo is private
```

```yaml
name: PR title

on:
  pull_request:
    branches: [main]
    types: [opened, edited, synchronize, reopened] # edited: re-check when the title changes

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number }}
  cancel-in-progress: true

permissions: {}

jobs:
  pr-title:
    name: Conventional
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/pr-title-node.yml@<full commit sha> # vX.Y.Z
    permissions:
      contents: read # required for actions/checkout to fetch repo contents if this repo is private
```

Checks: `Conventional / Lint commits`, `Conventional / Lint PR title`.

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

### `npm-release.yml` and `npm-publish.yml`

A manual release of an npm package, in two steps: `npm-release.yml` versions the repository with commit-and-tag-version, builds and packs the package, pushes the release commit and tag, attests the tarball (build provenance and SBOM) and creates the GitHub release. `npm-publish.yml` stages that tarball on npm (trusted publishing, `npm stage publish`); a maintainer approves it with 2FA, then the job waits for the version and verifies it.
Call both from one workflow with `workflow_dispatch`, after the repository's own CI. Keep that workflow's file name: npm's trusted publisher matches the **calling** workflow (file name and environment `npm`), not this repository's.
Needs:

- `commit-and-tag-version` in the devDependencies, with its default `v` tag prefix and `CHANGELOG.md` in the repository root;
- `package-lock.json` and `.nvmrc` in the repository root;
- the environments `release` (variable `RELEASE_GITHUB_CLIENT_ID`, secret `RELEASE_APP_PRIVATE_KEY`, deployments from `main`) and `npm`;
- the release App as a bypass actor on `main` and the `v*` tags. Releases run from `main` only.

```yaml
name: Release

on:
  workflow_dispatch:
    inputs:
      release_as:
        description: "Force a specific version, e.g. 1.0.0. Leave blank for automatic bump."
        required: false
        type: string
      dry_run:
        description: "Run everything without pushing, publishing or deploying."
        required: false
        default: false
        type: boolean

concurrency:
  group: release
  cancel-in-progress: false

permissions: {}

jobs:
  guard:
    name: Check branch
    runs-on: ubuntu-latest
    steps:
      - name: Only release from main # before CI, so a wrong dispatch fails fast
        run: |
          if [ "$GITHUB_REF" != "refs/heads/main" ]; then
            echo "::error::Releases must run on main, got $GITHUB_REF"
            exit 1
          fi

  ci:
    name: CI
    needs: [guard]
    uses: $/.github/workflows/ci.yml # the repository's own CI, with on: workflow_call
    permissions:
      contents: read # required for actions/checkout to fetch repo contents if this repo is private

  release:
    name: Release
    needs: [ci]
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/npm-release.yml@<full commit sha> # vX.Y.Z
    with:
      build-script: package:check
      release-as: ${{ inputs.release_as }}
      dry-run: ${{ inputs.dry_run }}
    secrets:
      RELEASE_APP_PRIVATE_KEY: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
    permissions:
      contents: read # checkout; the release App token does every write
      id-token: write # required to sign the provenance and SBOM attestations
      attestations: write # required to persist the attestations

  npm:
    name: npm
    needs: [release]
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/npm-publish.yml@<full commit sha> # vX.Y.Z
    with:
      dry-run: ${{ inputs.dry_run }}
    permissions:
      contents: read # required for actions/checkout to fetch repo contents if this repo is private
      id-token: write # required for npm trusted publishing (OIDC)
```

`npm-release.yml`:

| Input | Default | |
|---|---|---|
| `build-script` | (required) | npm script that builds and checks the package, run after the version bump: it must build from the bumped `package.json` |
| `package-dir` | `.` | What `npm pack` packs, e.g. `dist/<package>` |
| `extra-assets` | | More files for the GitHub release, space-separated paths without spaces |
| `release-as` | | Force a version `X.Y.Z` (`commit-and-tag-version --release-as`); pre-releases are not supported |
| `dry-run` | `false` | Version, build and pack without pushing, attesting or releasing |

| Secret | |
|---|---|
| `RELEASE_APP_PRIVATE_KEY` | Private key of the release App; pass it by name, the job reads it in the environment `release` |

Outputs: `version` (without `v`), `tarball`. Artifact: `release-artifacts` (tarball, SBOM, extra assets).

`npm-publish.yml`:

| Input | Default | |
|---|---|---|
| `install-check-script` | | npm script that installs `<name>@<version>` (its argument) and checks it; runs without `npm ci` |
| `dry-run` | `false` | `npm stage publish --dry-run`, no verification |

The attestations are signed by `npm-release.yml`, so verify the release assets with `--signer-repo`:

```sh
gh release download vX.Y.Z --repo <owner>/<repo> --pattern '*.tgz'
gh attestation verify <package>-X.Y.Z.tgz --repo <owner>/<repo> --signer-repo RAMEN-Suite/ramen-workflows
```

Use gh 2.102.0 or later. For npm installs, `npm audit signatures` is enough.

### `pages.yml`

Builds a site with an npm script and deploys it to GitHub Pages (environment `github-pages`). Pages must use the build type "GitHub Actions".
Needs `.nvmrc` in the repository root and `package-lock.json` in `working-directory`.

```yaml
  pages:
    name: Pages
    needs: [release]
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/pages.yml@<full commit sha> # vX.Y.Z
    with:
      build-script: build:pages
      path: dist/site
      ref: v${{ needs.release.outputs.version }}
    permissions:
      contents: read # required for actions/checkout to fetch repo contents if this repo is private
      pages: write # required to deploy to GitHub Pages
      id-token: write # required for actions/deploy-pages to verify the deployment origin
```

| Input | Default | |
|---|---|---|
| `build-script` | (required) | npm script that builds the site |
| `path` | (required) | Built site, relative to `working-directory` |
| `ref` | the run's commit | Git ref to build, e.g. the release tag |
| `working-directory` | `.` | Directory of the npm project |
| `dry-run` | `false` | Build and upload, don't deploy |

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
