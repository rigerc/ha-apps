---
paths: [".github/workflows/*.yaml", ".github/workflows/*.yml"]
---

## When Editing Workflows

### Action Versions (REQUIRED)

- `actions/checkout@v5` (not v4)
- `actions/cache@v4`
- `docker/login-action@v4` (not v3)
- `home-assistant/builder@2025.11.0`

Never use unpinned versions like `@master`.

### Path Filters

When adding triggers, use specific paths to avoid unnecessary runs:

```yaml
on:
  pull_request:
    paths:
      - "addon-name/**"  # For specific add-on
      - ".github/workflows/**"  # For workflow changes
```

### Reusable Workflow Pattern

If creating a workflow called by others, use `workflow_call` + `workflow_dispatch`:

```yaml
on:
  workflow_call:
    inputs:
      addon:
        required: true
        type: string
  workflow_dispatch:
    inputs:
      addon:
        required: true
        type: string
```

### Release-Please Config

When adding new add-on to `.github/release-please-config.json`:
1. Add to `packages` object with `release-type: "simple"`
2. Add `extra-files` for version updates (config.yaml, build.yaml)
3. Add path filter to `.github/workflows/release-please.yaml`

### Skip CI Pattern

When committing generated files (manifest.json, README), use `[skip ci]` to prevent workflow loops.

### Adding New Add-ons

After adding a new add-on directory:
1. Run `.github/scripts/manifest.sh -d -r` to update both dependabot.yml and release-please.yaml paths
2. Update `.github/release-please-config.json` to add the new add-on package config
3. Verify workflow path filters include the new add-on
