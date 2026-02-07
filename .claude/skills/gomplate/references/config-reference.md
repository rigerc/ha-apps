# Gomplate Configuration Reference

Complete reference for `.gomplate.yaml` configuration files.

## Overview

Configuration files provide a structured way to define gomplate settings, especially useful for:
- Projects with multiple datasources
- Teams sharing templates in version control
- Complex rendering scenarios with many options
- Avoiding long command lines

Default config file: `.gomplate.yaml` in current directory

Override with: `--config path/to/config.yaml` or `GOMPLATE_CONFIG=path/to/config.yaml`

Disable config: `--config=""` or `export GOMPLATE_CONFIG=""`

## Configuration Precedence

Command-line arguments > Config file > Environment variables

Example:
```bash
export GOMPLATE_LEFT_DELIM=::
echo "leftDelim: ((" > .gomplate.yaml
gomplate --left-delim "<<"  # Uses <<
```

## Complete Configuration Example

```yaml
# Input/Output Configuration
inputDir: templates/
outputDir: rendered/
excludes:
  - '*.md'
  - 'draft/*'
  - '!important.md'  # Negative pattern (include this)
excludeProcessing:
  - '*.jpg'
  - '*.png'
outputMap: |
  out/{{ .in | strings.ReplaceAll ".tmpl" "" }}

# Alternative: specific files
inputFiles:
  - app.tmpl
  - config.tmpl
outputFiles:
  - app.conf
  - config.ini

# Or inline template
in: |
  Hello {{ .user }}
  Environment: {{ .env }}

# File permissions
chmod: 0644

# Template delimiters
leftDelim: '{{'
rightDelim: '}}'

# Missing key behavior
missingKey: error  # error|default|zero

# Datasources (lazy-loaded)
datasources:
  appConfig:
    url: file:///etc/app/config.yaml
  secrets:
    url: vault:///secret/myapp
  api:
    url: https://api.example.com/data
    header:
      Authorization: ["Bearer abc123"]
      Accept: ["application/json"]
  merged:
    url: merge:prod.yaml|defaults.yaml

# Context (immediately loaded)
context:
  user:
    url: https://api.example.com/user
    header:
      Authorization: ["Bearer abc123"]
  settings:
    url: file://./settings.json

# Nested templates
templates:
  header:
    url: file://./templates/header.tmpl
  footer:
    url: file://./templates/footer.tmpl
  helpers:
    url: file://./templates/helpers/

# Custom functions (plugins)
plugins:
  figlet:
    cmd: /usr/local/bin/figlet
    pipe: true
    timeout: 2s
    args:
      - -f
      - standard
  envsubst: /usr/bin/envsubst

pluginTimeout: 5s

# Post-execution
postExec:
  - cat
  - output.txt
execPipe: false

# Experimental features
experimental: true
```

## Configuration Fields

### Input/Output

#### `in`

Inline template content (alternative to `inputFiles` or `inputDir`).

```yaml
in: Hello {{ env.Getenv "USER" }}
```

Multi-line:
```yaml
in: |
  # Configuration
  user: {{ .user.name }}
  email: {{ .user.email }}
```

Cannot be used with `inputFiles` or `inputDir`.

#### `inputFiles`

Array of input template file paths. Special value `-` means stdin.

```yaml
inputFiles:
  - first.tmpl
  - second.tmpl
outputFiles:
  - first.out
  - second.out
```

Requires matching number of `outputFiles` entries.

Cannot be used with `in` or `inputDir`.

#### `inputDir`

Directory containing input templates. All files processed recursively.

```yaml
inputDir: templates/
outputDir: rendered/
```

Requires `outputDir` or `outputMap`.

Cannot be used with `in` or `inputFiles`.

#### `outputFiles`

Array of output file paths. Special value `-` means stdout.

```yaml
outputFiles:
  - output.txt
  - -
```

Can be used with `inputFiles` or `in`.

Cannot be used with `inputDir`.

#### `outputDir`

Directory for rendered output. Created if missing with same permissions as `inputDir`.

```yaml
outputDir: config/
```

Requires `inputDir`.

Cannot be used with `outputFiles`.

#### `outputMap`

Template string for mapping input filenames to output filenames.

Context available:
- `.in` - Input filename
- `.ctx` - Original template context

```yaml
outputMap: |
  out/{{ .in | strings.ReplaceAll ".yaml.tmpl" ".yaml" }}
```

Requires `inputDir`.

Example with datasource:
```yaml
outputMap: |
  {{ $base := filepath.Base .in }}
  out/{{ index .filemap $base }}.conf
```

#### `excludes`

Array of exclude patterns for `inputDir` (`.gitignore` syntax).

```yaml
excludes:
  - '*.txt'
  - 'draft/**'
  - '!important.txt'  # Negative pattern
```

Prefix with `!` to create include pattern (negates exclusion).

#### `excludeProcessing`

Array of patterns for files to copy without processing.

```yaml
excludeProcessing:
  - '*.jpg'
  - '*.png'
  - 'static/**'
```

Files matching patterns are copied to output directory unchanged.

#### `chmod`

Output file permissions (octal).

```yaml
chmod: 0755  # Owner: rwx, Group: r-x, Others: r-x
chmod: 0644  # Owner: rw-, Group: r--, Others: r--
```

Windows: Only read/write (0666) and read-only (0444) supported.

### Template Configuration

#### `leftDelim` / `rightDelim`

Override template delimiters (default: `{{` and `}}`).

```yaml
leftDelim: '{%'
rightDelim: '%}'
```

Now use: `{% env.Getenv "USER" %}`

#### `missingKey`

Behavior when accessing missing map keys.

Values:
- `error` (default) - Stop with error
- `default` or `invalid` - Continue, print `<no value>`
- `zero` - Return zero value

```yaml
missingKey: zero
```

Template behavior:
```
# missingKey: error
{{ .undefined }}  → Error

# missingKey: default
{{ .undefined }}  → <no value>

# missingKey: zero
{{ .undefined | default "fallback" }}  → fallback
```

### Datasources

#### `datasources`

Define lazy-loaded datasources (read when accessed in template).

```yaml
datasources:
  config:
    url: file:///etc/app/config.yaml
  secrets:
    url: vault:///secret/app
    header:
      X-Vault-Token: ["token123"]
  api:
    url: https://example.com/api
    header:
      Authorization: ["Bearer abc"]
```

Each datasource:
- `url` (required) - Datasource URL
- `header` (optional) - HTTP headers (for HTTP/HTTPS datasources)

Template usage:
```
{{ (ds "config").setting }}
{{ (ds "secrets").password }}
```

#### `context`

Define immediately-loaded datasources (loaded before rendering).

```yaml
context:
  user:
    url: https://api.example.com/user.json
  config:
    url: file://./config.yaml
  .:
    url: data.json  # Override entire context
```

Template usage:
```
{{ .user.name }}
{{ .config.database.host }}
```

### Templates

#### `templates`

Define nested templates (reusable template fragments).

```yaml
templates:
  header:
    url: file://./templates/header.tmpl
  footer:
    url: file://./templates/footer.tmpl
  helpers:
    url: file://./templates/helpers/
    header:
      Custom-Header: ["value"]
```

Template usage:
```
{{ template "header" "Page Title" }}
{{ template "footer" }}
{{ template "helpers/format.tmpl" .data }}
```

Directory references include all files, accessible as `alias/filename`.

### Plugins

#### `plugins`

Define custom template functions via external commands.

**Simple form (command only):**
```yaml
plugins:
  echo: /bin/echo
  upper: /usr/local/bin/to-upper
```

**Full form (with options):**
```yaml
plugins:
  figlet:
    cmd: /usr/local/bin/figlet
    pipe: true
    timeout: 2s
    args:
      - -f
      - banner
```

Plugin configuration:

**`cmd`** (required) - Path to executable

**`pipe`** (optional, default false) - Pipe last argument to stdin

```yaml
plugins:
  myfunc:
    cmd: /bin/myfunc
    pipe: true
```

Template: `{{ "input" | myfunc "arg1" }}`

- If `pipe: true` → `/bin/myfunc arg1` with "input" on stdin
- If `pipe: false` → `/bin/myfunc arg1 input`

**`timeout`** (optional, default 5s) - Plugin execution timeout

```yaml
plugins:
  slow:
    cmd: /usr/local/bin/slow-command
    timeout: 30s
```

**`args`** (optional) - Arguments always passed to plugin

```yaml
plugins:
  echo:
    cmd: /bin/echo
    args:
      - prefix
      - header
```

Template: `{{ echo "foo" "bar" }}`
Command: `/bin/echo prefix header foo bar`

#### `pluginTimeout`

Default timeout for all plugins (overrides 5s default).

```yaml
pluginTimeout: 10s
plugins:
  cmd1: /bin/cmd1  # Uses 10s timeout
  cmd2:
    cmd: /bin/cmd2
    timeout: 30s   # Overrides pluginTimeout
```

### Post-Execution

#### `postExec`

Command to run after successful template rendering.

```yaml
postExec:
  - cat
  - output.txt
```

Or:
```yaml
postExec: [bash, -c, "echo 'Done!'"]
```

#### `execPipe`

Pipe rendered output to `postExec` command's stdin.

```yaml
execPipe: true
postExec:
  - tr
  - a-z
  - A-Z
```

Overrides `outputFiles` when enabled.

Cannot use with multiple inputs.

### Advanced Options

#### `experimental`

Enable experimental features and functions.

```yaml
experimental: true
```

Enables functions marked as "(experimental)" in documentation.

## Complete Workflows

### Multi-Environment Configuration

```yaml
# .gomplate.yaml
inputDir: templates/
outputDir: config/{{ env.Getenv "ENV" }}/

datasources:
  config:
    url: merge:config/{{ env.Getenv "ENV" }}.yaml|config/defaults.yaml
  secrets:
    url: vault:///secret/{{ env.Getenv "ENV" }}/app

context:
  env:
    url: env:ENV
```

Usage:
```bash
ENV=production gomplate
ENV=staging gomplate
```

### API-Driven Configuration

```yaml
# .gomplate.yaml
in: |
  # Generated Configuration
  {{ range $key, $value := .api.settings }}
  {{ $key }}={{ $value }}
  {{ end }}

outputFiles:
  - app.conf

context:
  api:
    url: https://api.example.com/settings
    header:
      Authorization:
        - "Bearer {{ env.Getenv \"API_TOKEN\" }}"
```

### Batch File Processing

```yaml
# .gomplate.yaml
inputDir: templates/
outputMap: |
  {{ $dir := filepath.Dir .in }}
  {{ $base := filepath.Base .in }}
  config/{{ $dir }}/{{ $base | strings.TrimSuffix ".tmpl" }}

excludes:
  - '*.md'
  - '_*'

datasources:
  config:
    url: file://./data/config.json
  secrets:
    url: vault:///secret/app
```

Structure:
```
templates/
  app/service.yaml.tmpl
  db/connection.ini.tmpl

Output:
config/
  app/service.yaml
  db/connection.ini
```

### Plugin-Enhanced Templates

```yaml
# .gomplate.yaml
in: |
  {{ "App Banner" | figlet }}

  Configuration:
  {{ .config | toJSON | jq ".formatted" }}

plugins:
  figlet:
    cmd: /usr/local/bin/figlet
    pipe: true
    args: [-f, banner]
  jq:
    cmd: /usr/bin/jq
    pipe: true
    args: [-r]

context:
  config:
    url: config.json

outputFiles:
  - banner.txt
```

## Best Practices

**Use version control for config files:**
Commit `.gomplate.yaml` to share configuration across team.

**Environment-specific configs:**
```bash
.gomplate.yaml        # Shared defaults
.gomplate.dev.yaml    # Development overrides
.gomplate.prod.yaml   # Production overrides

gomplate --config .gomplate.prod.yaml
```

**Organize datasources by purpose:**
```yaml
datasources:
  # Application configuration
  appConfig: file://./config/app.yaml

  # Secrets (production)
  dbSecrets: vault:///secret/production/db
  apiKeys: vault:///secret/production/api

  # Reference data
  regions: https://api.example.com/regions
```

**Use merge for environment layering:**
```yaml
datasources:
  config:
    url: merge:config.{{ env.Getenv "ENV" }}.yaml|config.defaults.yaml
```

**Document datasource requirements:**
```yaml
# .gomplate.yaml
# Required environment variables:
# - API_TOKEN: Authentication token for api.example.com
# - VAULT_TOKEN: Vault authentication
# - ENV: Environment name (dev|staging|production)

datasources:
  api:
    url: https://api.example.com/data
    header:
      Authorization: ["Bearer {{ env.Getenv \"API_TOKEN\" }}"]
```

**Validate before committing:**
Create validation script:
```bash
#!/bin/bash
# validate-gomplate.sh
gomplate --config .gomplate.yaml -i '{{ env.Getenv "USER" }}' > /dev/null
echo "Config valid!"
```

## Troubleshooting

**Config file not found:**
```
Error: config file not found: .gomplate.yaml
```
Solution: Create config or specify path with `--config` or disable with `--config=""`.

**Invalid YAML syntax:**
```
Error: yaml: line 5: did not find expected key
```
Solution: Validate YAML syntax. Common issues:
- Missing quotes for special characters
- Incorrect indentation
- Missing colons

**Conflicting input options:**
```
Error: --in and --input-dir are mutually exclusive
```
Solution: Use only one of: `in`, `inputFiles`, or `inputDir`.

**Missing required pairing:**
```
Error: --input-dir requires --output-dir or --output-map
```
Solution: Specify output configuration for input directory.
