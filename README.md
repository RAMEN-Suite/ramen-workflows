# ramen-workflows

Shared GitHub Actions for the RAMEN-Suite repositories.

- `.github/workflows/`: reusable workflows (`on: workflow_call`), and this repository's own CI.
- `actions/<name>/`: composite actions, used by the reusable workflows.

Nothing is callable yet.

## Usage

Call a reusable workflow from a thin workflow in your repository, pinned to the commit of a release:

```yaml
jobs:
  ci:
    name: CI
    permissions:
      contents: read # required for actions/checkout to fetch repo contents if this repo is private
    uses: RAMEN-Suite/ramen-workflows/.github/workflows/<workflow>.yml@<full commit sha> # vX.Y.Z
    secrets:
      token: ${{ secrets.TOKEN }}
```

- Pin the full commit SHA of a release, with the version as a comment. Renovate updates both. Never `@main` or a bare tag.
- The calling job grants the permissions. A reusable workflow can only reduce them, so each one documents what it needs.
- Pass each secret by name under `secrets:`, never `secrets: inherit`.

## Versioning

A release is a tag `vX.Y.Z` with an immutable GitHub release. It versions the whole repository: every workflow and action.

- **Major**: callers have to change something. A workflow, action, input, output or secret is removed or renamed, a new input or permission is required, or a job name changes (job names are the status checks that rulesets require).
- **Minor**: a new workflow, action or optional input.
- **Patch**: fixes and dependency updates that callers don't notice.

Reusable workflows use this repository's actions as `$/actions/<name>`. GitHub resolves `$/` to the commit the workflow runs from, so a workflow and its actions always come from the same release.
`$/` takes no `@ref`, and needs GitHub.com with GitHub-hosted runners or self-hosted runners 2.336.0 or later.

## Development

CI runs zizmor and actionlint on every pull request and every push to `main` (`.github/workflows/zizmor.yml`).
Locally, from the repository root:

```sh
actionlint
zizmor .
```

actionlint 1.7.12 doesn't know `$/` yet. `.github/actionlint.yaml` ignores exactly those errors; remove it once actionlint supports `$/` ([rhysd/actionlint#732](https://github.com/rhysd/actionlint/issues/732)).

## License

[MIT](LICENSE)
