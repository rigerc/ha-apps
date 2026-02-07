---
paths: [".github/workflows/*", ".github/actions/*"]
---

## HA Add-ons CI/CD

### Workflow Flow

```
PR to main → ci.yaml → lint.yaml + builder.yaml
                   ↓
                Validates add-ons

Merge to main → release-please.yaml → Creates release PR
                  ↓
                Merge release PR → deploy.yaml → Build + push to GHCR
                                          ↓
                                    addon-metadata.yaml → Update manifest.json/README
```

### Add-on Discovery

Workflows use custom actions to find add-ons:
- `.github/actions/find-addons` - Scans for `config.{json,yaml,yml}`
- `.github/actions/find-changed-addons` - Filters by `git diff` against monitored files

**Monitored files**: `build.yaml`, `config.yaml`, `Dockerfile`, `rootfs/`, `apparmor.txt`

### CI Workflow (.github/workflows/ci.yaml)

- Triggers: PR to `main` with changes to add-on paths
- Calls: `lint.yaml` and `builder.yaml` (reusable workflows)
- Path filters: `romm/**`, `profilarr/**`, `huntarr/**`, `cleanuparr/**`

### Lint Workflow (.github/workflows/lint.yaml)

Reusable workflow that validates:
- Rootfs file permissions (executable check)
- Shell scripts via shellcheck
- Markdown (excludes README.md, CHANGELOG.md, DOCS.md)
- JSON/YAML syntax
- HA add-on spec via `frenck/action-addon-linter@v2`
- Dockerfile via hadolint (uses `.github/.hadolint.yaml`)
- build.yaml has `labels.project` key

### Builder Workflow (.github/workflows/builder.yaml)

- Matrix builds: `aarch64`, `amd64`
- Uses `home-assistant/builder@2025.11.0` with `--test` flag
- Caches Docker layers in `/tmp/.buildx-cache`
- Skips arch if not in add-on's supported architectures

### Deploy Workflow (.github/workflows/deploy.yaml)

Triggered by release-please after release PR merge:

**Build job**: Builds both arch, pushes to `ghcr.io/{owner}/{addon}`

**On success**:
- Updates release notes with build info
- Publishes draft release
- Triggers `addon-metadata.yaml`

**On failure**:
- Creates GitHub issue with build failure details
- Deletes draft release and tag

### Release Please (.github/workflows/release-please.yaml)

- Triggers on push to `main` when add-on files change
- Creates separate release PR per add-on
- Updates `config.yaml` and `build.yaml` with version
- Excludes: README.md, manifest.json, dependabot.yml (prevents loops)

**Config**: `.github/release-please-config.json`

### Addon Metadata (.github/workflows/addon-metadata.yaml)

- Triggers: config/Dockerfile changes, PR to main, or weekly (Tue 06:00 UTC)
- Runs `.github/scripts/manifest.sh` with gomplate
- Generates `manifest.json` and add-on README files
- Commits with `[skip ci]` to prevent workflow loops

### Actionlinter (.github/workflows/actionlinter.yml)

- Validates workflow syntax via `raven-actions/actionlint@v2`
- **Only validates metadata job** for Dependabot PRs (optimization)
- Runs full validation for all other PRs

### Fix Permissions (.github/workflows/fix-permissions.yaml)

- Auto-fixes executable bits on `.sh` files and `*/rootfs/*` files
- Triggers on push to `main` when these paths change

### Release Automation

1. Developer merges feature to `main` with conventional commit
2. `release-please.yaml` creates release PR: `chore(repo): 🚀 Release {addon} {version}`
3. Merge release PR → `deploy.yaml` builds and pushes images
4. `addon-metadata.yaml` updates repository metadata
