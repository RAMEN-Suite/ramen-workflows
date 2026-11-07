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
| [`config-lint.yml`](#config-lintyml) | hadolint and trivy misconfiguration scan |
| [`container-check.yml`](#container-checkyml-and-container-publishyml) | build and scan a container image (pull requests) |
| [`container-publish.yml`](#container-checkyml-and-container-publishyml) | build, scan, push and attest a container image |
| [`deploy-ssh.yml`](#deploy-sshyml) | deploy images to an environment through the deploy gateway (ssh) |
| [`sync-files.yml`](#sync-filesyml) | copy files from the repository to an environment with rsync, restart or recreate what reads them |
| [`promote.yml`](#promoteyml) | deploy the images of an existing commit, e.g. the dev HEAD to staging |
| [`back-merge.yml`](#back-mergeyml) | merge `main` into `dev` after a release |
| [`release-hosted.yml`](#release-hostedyml) | version, notices, tag and GitHub release of a hosted app (images and deploy in the caller) |

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
- Run the workflows on `push` to `main` and `deps/**` (Renovate's branches) and on pull requests, without a `paths` filter: a required check whose workflow was filtered out stays pending. Renovate automerges a branch once every check run on it passed, so a workflow that skips its branches lets the merge through untested.

## Workflows

### `actions-lint.yml`

zizmor (security) and actionlint (correctness) over the calling repository's workflows and actions. Require both checks.

```yaml
name: Actions lint

on:
  push:
    branches: [main, "deps/**"] # deps/**: Renovate's branches; it automerges one only after its checks passed
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
    branches: [main, "deps/**"]
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
| `working-directories` | `.` | npm projects (each with `package-lock.json`), space-separated: `npm ci` and `npm audit signatures` run in each. The license scan always covers the whole repository |
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

`npm-release.yml` runs in two jobs, so the release App key never meets npm or the build: `Version, build and tag` (npm, build, pack, attestations; no secrets) hands the release commit on as a git bundle, and `Push and release` (environment `release`, no npm) checks that the commit only changes `CHANGELOG.md`, `package.json` and `package-lock.json` files, then pushes it and creates the GitHub release.

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

### `config-lint.yml`

hadolint over the given Dockerfiles (with the repository's `.hadolint.yml`; its `failure-threshold` decides) and a trivy misconfiguration scan of the repository (fails on `HIGH`/`CRITICAL`). Reports go to code scanning on public repositories.

```yaml
jobs:
  config-lint:
    name: Config lint
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/config-lint.yml@<full commit sha> # vX.Y.Z
    with:
      dockerfiles: client/Dockerfile server/Dockerfile
    permissions:
      contents: read # required for actions/checkout to fetch repo contents if this repo is private
      security-events: write # required for uploading results to code scanning
```

Checks: `Config lint / Dockerfile lint`, `Config lint / Misconfiguration scan`. Code scanning tools: `Hadolint`, `Trivy`; categories `hadolint`, `trivy-config`.

### `container-check.yml` and `container-publish.yml`

Both build an image and scan it with [`actions/image-scan`](#actions): a CycloneDX SBOM, a vulnerability report and a license report.
Vulnerabilities are only reported (code scanning and the job summary), never gated: most come from the base image, and their fixes arrive through Renovate after the cooldown.
The image fails on licenses matching `license-deny` (default `AGPL`): an image ships its OS, and Alpine alone brings GPL packages, so the stricter rule for the project's own dependencies lives in `supply-chain.yml`.

- `container-check.yml` (pull requests): builds and scans. No push token: only `contents: read` and `security-events: write`.
- `container-publish.yml` (pushes): builds and scans the same way (license gate, SBOM), then pushes all tags to `ghcr.io/<owner>/<repo>-<name>` and attaches build provenance and the SBOM as attestations. It needs `packages: write`, so it is a separate workflow: a pull request job never holds a push token. It refuses to run for `pull_request` events. It writes only its push summary; the scan reports stay in its artifact. Run `container-check.yml` in the same run (e.g. in the CI it calls first) for the summaries and code scanning.

Pull requests, both images as a matrix:

```yaml
jobs:
  image:
    name: ${{ matrix.name }} image
    strategy:
      matrix:
        name: [client, server]
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/container-check.yml@<full commit sha> # vX.Y.Z
    with:
      name: ${{ matrix.name }}
      dockerfile: ${{ matrix.name }}/Dockerfile
    permissions:
      contents: read # required for actions/checkout to fetch repo contents if this repo is private
      security-events: write # required for uploading the image scan to code scanning
```

Pushes: one job per image when later jobs need its outputs (outputs of matrix legs overwrite each other):

```yaml
jobs:
  client-image:
    name: Client image
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/container-publish.yml@<full commit sha> # vX.Y.Z
    with:
      name: client
      dockerfile: client/Dockerfile
      tags: |
        type=raw,value=dev
        type=sha,format=short
    permissions:
      contents: read # required for actions/checkout to fetch repo contents if this repo is private
      packages: write # push the image and its attestations
      id-token: write # required to sign the attestations
      attestations: write # required to persist the attestations
      artifact-metadata: write # actions/attest records the pushed image as an artifact of the repository
```

| Input | Default | |
|---|---|---|
| `name` | (required) | Short name: image `ghcr.io/<owner>/<repo>-<name>`, report names, build cache scope |
| `dockerfile` | (required) | Dockerfile path |
| `context` | `.` | Build context |
| `tags` | (required, publish only) | Tag rules for [docker/metadata-action](https://github.com/docker/metadata-action#tags-input) |
| `license-deny` | `AGPL` | Regular expression (case-insensitive) of license names that fail the image |
| `ref` | | Commit, branch or tag to build (publish only), e.g. the release tag; `sha-<commit>` then names that commit |

`container-publish.yml` outputs: `image`, `digest`, `sha-tag` (the `sha-<short commit>` tag if the tag rules create one).
Checks: `<caller job name> / Build and scan`, `<caller job name> / Build, scan and push`. Code scanning category `trivy-image-<name>`.

### `deploy-ssh.yml`

Deploys images to one GitHub environment through the deploy gateway of its host (`ssh deploy <stack> <service> <tag@digest>`).
Images are deployed by digest, so the host pulls exactly what was built. Pass the digests from `container-publish.yml` outputs; a digest looked up by tag in the registry should be verified first (`gh attestation verify`).
Everything host-specific comes from the environment, written by the `deploy-gateway` Ansible role: the secrets `SSH_HOST`, `SSH_USER`, `SSH_KNOWN_HOSTS`, `SSH_DEPLOY_KEY` and the variable `DEPLOY_STACKS` (JSON list of the host's stacks for the repository). No host or stack name lives in a workflow.

1. The deploy key goes into `ssh-agent` only, and ssh accepts only the host keys in `SSH_KNOWN_HOSTS`.
2. Each service is deployed to each stack, in the order of `images`. The gateway waits for health and rolls a service back by itself if it doesn't become healthy (exit 70); the first failure stops the job.

The job pipes its token (`packages: read`) to the gateway so the host can pull from ghcr.io. One deploy per environment runs at a time: a running deploy is never cancelled, and of several waiting ones only the newest runs. The job times out after 30 minutes.

The SSH secrets must be passed by name, although they live in the environment: an unpassed secret is silently empty in a reusable workflow. The job's `environment` then supplies the environment's values.

```yaml
jobs:
  deploy:
    name: Development
    needs: [client-image, server-image]
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/deploy-ssh.yml@<full commit sha> # vX.Y.Z
    with:
      environment: development
      images: >-
        {"server": "${{ needs.server-image.outputs.sha-tag }}@${{ needs.server-image.outputs.digest }}",
         "client": "${{ needs.client-image.outputs.sha-tag }}@${{ needs.client-image.outputs.digest }}"}
    secrets:
      SSH_HOST: ${{ secrets.SSH_HOST }}
      SSH_USER: ${{ secrets.SSH_USER }}
      SSH_KNOWN_HOSTS: ${{ secrets.SSH_KNOWN_HOSTS }}
      SSH_DEPLOY_KEY: ${{ secrets.SSH_DEPLOY_KEY }}
    permissions:
      packages: read # the token piped to the gateway lets the host pull the images
```

| Input | Default | |
|---|---|---|
| `environment` | (required) | GitHub environment with the SSH secrets and `DEPLOY_STACKS` |
| `images` | (required) | JSON object service → `tag@sha256:digest`; the image is `ghcr.io/<owner>/<repo>-<service>` |

Check: `<caller job name> / Deploy`.

### `sync-files.yml`

Copies files from the repository to one GitHub environment with rsync, for content that the apps read from the host
(project configuration, guidelines). The host pins the rsync key to `rrsync -wo <files dir>`, so paths are relative to
that directory and CI can only write there. Everything host-specific comes from the environment, written by the
`deploy-gateway` Ansible role (repository `keys: [deploy, rsync]`): `SSH_HOST`, `SSH_USER`, `SSH_KNOWN_HOSTS`,
`SSH_RSYNC_KEY` and, for restarts and ups, `SSH_DEPLOY_KEY`.

1. Each transfer rsyncs `paths` from `from` to `to` (`--checksum`, `--mkpath`; `delete: true` also removes files that
   no longer exist in the repository). Content decides, not timestamps: unchanged files are neither sent nor reported.
2. A transfer that changed something on the host runs its `up` entries, then its `restart` entries (each
   `<stack> [service]`, without a service the whole stack) through the deploy gateway, with a second ssh agent holding
   only the deploy key. `restart` keeps the container and its environment: use it for files the app reads at start
   (configuration, guidelines). `up` (`docker compose up -d --pull never`) recreates the container when its compose
   configuration changed: use it for files compose reads, such as env files. A re-run ("Re-run jobs") runs them even
   without changes, because the failed or cancelled attempt may have copied the files but not restarted.

Every run syncs the full state of its commit, so a newer run waiting for the environment may replace an older one
without losing a change. One sync per environment runs at a time; the job times out after 15 minutes.

```yaml
jobs:
  sync:
    name: Sync
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/sync-files.yml@<full commit sha> # vX.Y.Z
    with:
      environment: staging
      transfers: >-
        [{"from": "projects/abbw/shoyu", "paths": ["config", "i18n"], "to": "shoyu/", "delete": true},
         {"from": "projects/abbw", "paths": ["project.gcore.json"], "to": "gcore/", "restart": ["dev/tori server"]},
         {"from": "config/dev", "paths": ["tori.env"], "to": "_config/dev/", "up": ["dev/tori"]}]
    secrets:
      SSH_HOST: ${{ secrets.SSH_HOST }}
      SSH_USER: ${{ secrets.SSH_USER }}
      SSH_KNOWN_HOSTS: ${{ secrets.SSH_KNOWN_HOSTS }}
      SSH_RSYNC_KEY: ${{ secrets.SSH_RSYNC_KEY }}
      SSH_DEPLOY_KEY: ${{ secrets.SSH_DEPLOY_KEY }}
    permissions:
      contents: read # checkout
```

| Input | Default | |
|---|---|---|
| `environment` | | GitHub environment with the SSH secrets |
| `transfers` | | JSON list of `{from, paths, to, delete, restart, up}` |

### `promote.yml`

Deploys the images of an existing commit to an environment (default `staging`): it finds `ghcr.io/<owner>/<repo>-<service>:sha-<commit>`, verifies the attestation (a tag can be moved, so only images built by `container-publish.yml` for the repository pass), then calls [`deploy-ssh.yml`](#deploy-sshyml). Without `sha`, it takes the commit the run is on, so a manual run on `dev` promotes the dev HEAD.

```yaml
on:
  workflow_dispatch:
    inputs:
      sha:
        description: "Commit to promote (default: the dev HEAD)"

jobs:
  staging:
    name: Promote
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/promote.yml@<full commit sha> # vX.Y.Z
    with:
      services: server client
      sha: ${{ inputs.sha }}
    secrets:
      SSH_HOST: ${{ secrets.SSH_HOST }}
      SSH_USER: ${{ secrets.SSH_USER }}
      SSH_KNOWN_HOSTS: ${{ secrets.SSH_KNOWN_HOSTS }}
      SSH_DEPLOY_KEY: ${{ secrets.SSH_DEPLOY_KEY }}
    permissions:
      packages: read # read and pull the images
      attestations: read # verify the images
```

### `back-merge.yml`

Merges `main` into `dev` with a merge commit, pushed by the release App (exempt from the `dev` ruleset). On a conflict it fails and says how to merge by hand: a branch off `dev`, `git merge origin/main`, resolve, then a pull request into `dev` merged with a merge commit. Runs in the environment `release` (`RELEASE_GITHUB_CLIENT_ID`, `RELEASE_APP_PRIVATE_KEY`).

```yaml
jobs:
  back-merge:
    name: Back-merge
    needs: [release]
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/back-merge.yml@<full commit sha> # vX.Y.Z
    secrets:
      RELEASE_APP_PRIVATE_KEY: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
    permissions:
      contents: read # checkout; the push goes through the App token
```

### `release-hosted.yml`

Releases a hosted app (client/server images, deployed by the caller) from `main`:

Job `Version and notes`, without secrets (it runs third-party npm code):

1. Fails if the commit already carries a `v*` tag and `release-as` is empty: the second guard next to `[skip ci]` against releasing a release commit again (also catches a manual run right after a release).
2. `npm ci` at the root (it needs `commit-and-tag-version` and, with `notices`, `generate-license-file` as devDependencies).
3. For each directory in `notices`: `npm ci` there and regenerate `<dir>/NOTICES.md` (third-party licenses stay part of the source).
4. `commit-and-tag-version --commit-all`: version bump, `CHANGELOG.md` and the notices in one commit `chore(release): X.Y.Z [skip ci]`, tag `vX.Y.Z`. `[skip ci]`: the push starts no workflows.
5. Hands the commit and tag on as a git bundle (artifact).

Job `Push and release`, in the environment `release` (`RELEASE_GITHUB_CLIENT_ID`, `RELEASE_APP_PRIVATE_KEY`, deploys only from `main`), with no npm at all: it checks that the release commit only changes `CHANGELOG.md`, `package.json` and `NOTICES.md` files, then the release App pushes commit and tag atomically to `main` and creates the GitHub release with the changelog section. Output: `version`. The caller builds the images from `v<version>` (`container-publish.yml` with `ref`), deploys them and back-merges.

```yaml
jobs:
  release:
    name: Release
    needs: [ci]
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/release-hosted.yml@<full commit sha> # vX.Y.Z
    with:
      notices: client server
      release-as: ${{ inputs.release_as }}
      dry-run: ${{ inputs.dry_run == true }}
    secrets:
      RELEASE_APP_PRIVATE_KEY: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
    permissions:
      contents: read # checkout; the push and the release go through the App token
```

| Input | Default | |
|---|---|---|
| `notices` | | Directories whose `NOTICES.md` is regenerated, space-separated |
| `release-as` | | Force a version `X.Y.Z`; also releases a commit that already carries a tag |
| `dry-run` | `false` | Bump and build the notes, push and release nothing |

## Actions

Helpers of the reusable workflows; they write job summaries.

| Action | Input |
|---|---|
| `actions/sarif-summary` | a SARIF report (trivy, gitleaks, semgrep) |
| `actions/license-summary` | a trivy license report (JSON) |
| `actions/coverage-summary` | an istanbul `coverage-summary.json` |
| `actions/image-scan` | a local container image: SBOM, vulnerability and license reports, license gate (no summary) |
| `actions/ssh-setup` | a host, user, known_hosts and private key: loads the key into `ssh-agent`, writes an ssh config (alias `deploy-target`, strict host keys) |
| `actions/ssh-deploy` | an ssh config, stacks and images: deploys through the gateway |
| `actions/ssh-sync` | an ssh config (rsync key) and transfers: rsyncs them, outputs the restarts and ups of transfers that changed something |

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
