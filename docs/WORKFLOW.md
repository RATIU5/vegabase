# Workflow

How to commit, open a PR and release. Humans and agents follow the same rules. The checks below enforce them.

## Rules
1. Branch from `main`. Open a PR. Never push to `main`.
2. Write Conventional Commit messages and PR titles: `type(scope): summary`. The PR title becomes the squash commit on `main`.
3. Every PR adds one changeset file or records the changelog.
4. Merge the release PR to ship. Never tag or publish by hand.
5. Only a person merges a PR. Agents never merge and never enable auto-merge.

## Commits
- Format: `type(scope): summary`. Scope is required: the component or area, such as `api`, `ci`, `docs` or `deps`. Add `!` before the colon for a breaking change.
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
- Lowercase type, imperative summary, no trailing period.
- The commit-msg hook checks each local commit. Install it once per clone: `mise x -- cog install-hook commit-msg`.
- Never commit with `--no-verify`. CI checks the PR title either way.
- Revert with a title like `revert(api): add x`.

## Pull requests
- CI labels the PR with its title type.
- Small and focused: one concern per PR.
- Fill in the PR template. Squash merge only.
- Agents open PRs with `r5-util:pr`, as drafts.
- PRs with no activity for 45 days are closed after a warning. Add the `keep-open` label to stop that.
- Workflows on pull requests never get secrets. Do not add any.

## Changesets
A changeset is a file `.changeset/<short-name>.md`. Every PR from a person or an agent needs one. PRs created by bots or apps (Renovate) do not. A PR that records the changelog (a new version heading in `CHANGELOG.md`, no changesets left) also passes; a changelog edit alone does not. Pending changesets are the unreleased changes. The release PR turns them into the next version heading in `CHANGELOG.md` and deletes them.
```
---
vegabase: minor
---

# Add the thing
```
- Create one with `mise run logchange`, or write the file.
- Use one line per component: `<component>: <type>`.
- Types: `major`, `minor`, `patch` bump the version. `docs` and `chore` get their own changelog section and bump the patch version.
- The commit or PR type never changes the version. Only the changeset does.
- The title line is the changelog entry. Write it for a user, not a developer.
- Keep only changeset files in `.changeset/`.
- Record locally instead: commit the changeset, push, open the PR, then run `mise run changelog` and commit `CHANGELOG.md`, the version bump and the deleted changesets in the same PR.
- Entries link to the PR when recorded after the PR is open, else to the commit that added the changeset.

## Checks
| Check | Enforces | Run locally |
|---|---|---|
| `pr-title` | PR title is a Conventional Commit (the release PR is exempt) | `mise run lint:title -- "feat(api): x"` |
| `changeset` | PR adds a changeset or records the changelog (bot and app PRs are exempt) | `mise run lint:changeset -- main` |
| `check` | lint and tests pass | `mise run lint`, `mise run test` |
| commit-msg hook | each local commit message | runs on `git commit` |

Once the repository ruleset requires these checks, a red check blocks the merge.

## Release
1. Changes merge to `main`. A bot opens or updates one release PR with versions and the changelog for the pending changesets.
2. Review the version bump and the changelog. Merge the release PR.
3. CI builds, attests, tags `<component>/vX.Y.Z` and creates the GitHub release for every version with no tag. A version recorded locally in a feature PR is released the same way when it merges.
4. Pre-releases: until 1.0.0, versions run `1.0.0-alpha.N`, then `1.0.0-beta.N`, then `1.0.0-rc.N`. `RELEASE_STAGE` in `prepare-release.yml` sets the label for the release PR opened on merge; change it in a PR to move to the next stage, and set it to `''` for 1.0.0. A manual `prepare-release` run can pick another label, or `none` for a stable release. Pre-releases keep their changesets, so do not record the changelog locally during a pre-release stage.
5. Fix a bad release by merging a new fix PR and releasing forward. There are no support branches.

## Setup
- Install mise (https://mise.jdx.dev/getting-started.html), then `mise install` for the pinned tools.
- `mise tasks` lists every task.

## When a check fails
- `pr-title`: edit the PR title. The check reruns on edit.
- `changeset`: add `.changeset/<name>.md`, then push.
