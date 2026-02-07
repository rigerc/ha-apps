---
name: gomplate
description: This skill should be used when the user asks to "create a gomplate template", "work with gomplate", "use gomplate datasources", "configure gomplate", "fix gomplate template", "debug gomplate syntax", "create .gomplate.yaml", or mentions gomplate templating, Go templates with datasources, or template rendering with external data.
version: 0.1.0
---

# Gomplate Templating Skill

## Purpose

Provide comprehensive guidance for creating, debugging, and managing gomplate templates. Gomplate is a powerful template renderer that uses Go's text/template syntax enhanced with extensive functions and support for multiple datasource types (JSON, YAML, Vault, Consul, AWS, HTTP, and more).

## When to Use This Skill

Use this skill when:
- Creating new gomplate templates from scratch
- Working with datasources (file, HTTP, Vault, Consul, AWS S3, etc.)
- Debugging template syntax errors or function usage
- Creating or modifying `.gomplate.yaml` configuration files
- Converting environment variables or data files into structured output
- Generating configuration files from templates and external data

## Core Workflow

### Step 1: Understand Template Basics

Gomplate uses Go's `text/template` syntax with `{{` and `}}` delimiters. Templates combine static text with dynamic actions.

**Basic syntax:**
```
Hello, {{ env.Getenv "USER" }}!
```

**Key concepts:**
- Actions are delimited by `{{` and `}}`
- Variables start with `$` (e.g., `{{ $name := "value" }}`)
- The context is accessed with `.` (period)
- Functions perform operations (e.g., `{{ add 1 2 }}`)

**Whitespace control:**
- `{{-` removes leading whitespace/newlines
- `-}}` removes trailing whitespace/newlines
- Use both to suppress newlines entirely: `{{- action -}}`

### Step 2: Working with Datasources

Datasources are the primary way to inject external data into templates.

**Define datasources with `-d` flag:**
```bash
gomplate -d config=./config.json -i 'value: {{ (ds "config").key }}'
gomplate -d data=https://api.example.com/data.json -i '{{ (ds "data").field }}'
```

**Common datasource schemes:**
- `file://` or relative path - Local files
- `http://`, `https://` - HTTP endpoints
- `vault://` - HashiCorp Vault secrets
- `consul://` - HashiCorp Consul KV store
- `aws+smp://` - AWS Systems Manager Parameter Store
- `aws+sm://` - AWS Secrets Manager
- `s3://` - Amazon S3 objects
- `env:` - Environment variables
- `stdin:` - Standard input

**Access datasources in templates:**
```
{{ $config := ds "config" }}
{{ $config.database.host }}
```

**Use context datasources (loaded before rendering):**
```bash
gomplate -c user=./user.json -i 'Hello {{ .user.name }}'
```

Consult **`references/datasources-guide.md`** for comprehensive datasource documentation.

### Step 3: Create Templates

**Simple variable substitution:**
```
Name: {{ env.Getenv "USER" }}
Home: {{ env.Getenv "HOME" }}
```

**Conditionals:**
```
{{ if eq (env.Getenv "ENV") "production" -}}
Production configuration
{{- else -}}
Development configuration
{{- end }}
```

**Loops:**
```
{{ range $key, $value := ds "config" -}}
{{ $key }}: {{ $value }}
{{ end }}
```

**Functions:**
Gomplate provides extensive built-in functions across namespaces:
- `env` - Environment variables
- `strings` - String manipulation
- `coll` - Collection operations
- `conv` - Type conversion
- `data` - Data parsing
- `file` - File operations
- `math` - Mathematical operations

Example:
```
{{ $data := file.Read "/etc/config.json" | data.JSON }}
{{ $data.setting | strings.ToUpper }}
```

See **`examples/basic-template.tmpl`** and **`examples/advanced-template.tmpl`** for working examples.

### Step 4: Configure with .gomplate.yaml

For complex scenarios with multiple datasources, create a `.gomplate.yaml` configuration file.

**Basic structure:**
```yaml
inputDir: templates/
outputDir: rendered/

datasources:
  config:
    url: file:///etc/app/config.yaml
  secrets:
    url: vault:///secret/app

context:
  user:
    url: https://api.example.com/user.json
    header:
      Authorization: ["Bearer token123"]
```

**Common configuration options:**
- `inputFiles` / `outputFiles` - Specify input/output file pairs
- `inputDir` / `outputDir` - Process entire directories
- `datasources` - Define lazy-loaded datasources
- `context` - Define immediately-loaded datasources
- `excludes` - Exclude patterns for inputDir
- `leftDelim` / `rightDelim` - Override default delimiters
- `plugins` - Define custom function plugins

Consult **`references/config-reference.md`** for complete configuration details and **`examples/gomplate-config.yaml`** for a working example.

### Step 5: Handle Common Patterns

**Merge multiple datasources:**
```bash
gomplate -d merged=merge:prod.yaml|defaults.yaml -i '{{ (ds "merged").setting }}'
```

**Use pipes for data transformation:**
```
{{ "hello world" | strings.ToUpper | strings.ReplaceAll " " "-" }}
```

**Access nested data:**
```
{{ (ds "config").database.connections.primary.host }}
{{ index (ds "config") "database" "connections" "primary" "host" }}
```

**Iterate with index:**
```
{{ range $idx, $item := coll.Slice "one" "two" "three" -}}
{{ add 1 $idx }}: {{ $item }}
{{ end }}
```

**Handle missing keys safely:**
```bash
# Error on missing keys (default)
gomplate --missing-key error -i '{{ .name }}'

# Return zero value
gomplate --missing-key zero -i '{{ .name | default "Unknown" }}'
```

See **`references/common-patterns.md`** for more examples.

### Step 6: Debug Templates

**Common error: undefined variable**
```
Error: undefined variable "$foo"
```
Fix: Declare variable outside control structure or use `:=` for first assignment.

**Common error: missing datasource**
```
Error: no datasource with alias 'config'
```
Fix: Verify datasource is defined with `-d` flag or in `.gomplate.yaml`.

**Common error: invalid function**
```
Error: function "doesnotexist" not defined
```
Fix: Check function namespace and syntax in function reference.

**Enable verbose logging:**
```bash
gomplate --verbose -f template.tmpl -o output.txt
```

Consult **`references/troubleshooting.md`** for comprehensive debugging guidance.

### Step 7: Process Multiple Files

**Using input-dir and output-dir:**
```bash
gomplate --input-dir ./templates --output-dir ./config
```

**Exclude patterns:**
```bash
gomplate --input-dir ./templates --output-dir ./config \
  --exclude '*.md' --exclude 'draft/*'
```

**Output mapping (rename files):**
```bash
gomplate --input-dir templates \
  --output-map 'out/{{ .in | strings.ReplaceAll ".tmpl" "" }}'
```

**Preserve directory structure:**
All files in input directory are processed recursively, maintaining directory structure in output.

## Best Practices

**Use descriptive datasource aliases:**
```bash
# Good
gomplate -d appConfig=config.yaml -d dbSecrets=vault:///db/creds

# Avoid
gomplate -d c=config.yaml -d d=vault:///db/creds
```

**Leverage progressive disclosure:**
Keep templates focused. Move complex logic to datasources or helper templates.

**Use nested templates for reusability:**
```
{{ define "header" }}
=== {{ . }} ===
{{ end }}

{{ template "header" "Configuration" }}
```

**Handle errors gracefully:**
Use `default`, `has`, and `required` functions to handle missing data:
```
{{ .user.email | default "no-email@example.com" }}
{{ if has .config "debug" }}Debug: {{ .config.debug }}{{ end }}
{{ .apiKey | required "API key is required" }}
```

**Test templates with sample data:**
Create test JSON/YAML files before connecting to live datasources like Vault or Consul.

## Additional Resources

### Reference Files

For detailed information, consult:
- **`references/datasources-guide.md`** - Complete datasource documentation
- **`references/config-reference.md`** - Configuration file options
- **`references/functions-overview.md`** - Function namespaces and usage
- **`references/syntax-guide.md`** - Template syntax details
- **`references/common-patterns.md`** - Practical template patterns
- **`references/troubleshooting.md`** - Debugging and error resolution

### Example Files

Working examples in `examples/`:
- **`examples/basic-template.tmpl`** - Simple template with variables and functions
- **`examples/advanced-template.tmpl`** - Complex template with datasources and loops
- **`examples/gomplate-config.yaml`** - Complete configuration file example
- **`examples/vault-template.tmpl`** - Vault datasource usage
- **`examples/multi-datasource.tmpl`** - Merging multiple datasources

### Scripts

Utility scripts in `scripts/`:
- **`scripts/validate-template.sh`** - Validate template syntax
- **`scripts/test-template.sh`** - Test template with sample data
- **`scripts/render-all.sh`** - Batch render templates with common config

## Quick Reference

**Common commands:**
```bash
# Inline template
gomplate -i 'Hello {{ env.Getenv "USER" }}'

# File input/output
gomplate -f template.tmpl -o output.txt

# With datasource
gomplate -d config=config.yaml -f template.tmpl -o output.txt

# Multiple files
gomplate -f app.tmpl -f db.tmpl -o app.conf -o db.conf

# Directory processing
gomplate --input-dir templates/ --output-dir config/

# With config file
gomplate --config .gomplate.yaml

# Stdin input
echo "Hello {{ env.Getenv "USER" }}" | gomplate
```

**Common functions:**
```
{{ env.Getenv "VAR" }}           - Get environment variable
{{ strings.ToUpper "text" }}     - Uppercase string
{{ coll.Has .map "key" }}        - Check if key exists
{{ data.JSON (file.Read "x.json") }} - Parse JSON file
{{ ds "datasource" }}            - Load datasource
{{ ds "datasource" "key" }}      - Load specific key from datasource
{{ index .map "key" }}           - Access map with complex key
{{ default "fallback" .value }}  - Provide default value
{{ required "msg" .value }}      - Require value or error
```
