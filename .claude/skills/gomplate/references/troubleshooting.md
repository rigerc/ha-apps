# Gomplate Troubleshooting Guide

Common errors, debugging techniques, and solutions for gomplate templates.

## Common Template Errors

### Undefined Variable

**Error:**
```
Error: undefined variable "$var"
```

**Cause:** Variable used outside its scope or not declared.

**Solution:**
```go
{{- /* Bad: variable only exists in if block */ -}}
{{ if true }}
{{ $var := "value" }}
{{ end }}
{{ $var }}  # Error!

{{- /* Good: declare outside control structure */ -}}
{{ $var := "" }}
{{ if true }}
{{ $var = "value" }}
{{ end }}
{{ $var }}  # Works
```

### Map Key Missing

**Error:**
```
Error: map has no entry for key "missing"
```

**Cause:** Accessing non-existent map key with `.` operator.

**Solutions:**

1. Use `--missing-key=zero` flag:
```bash
gomplate --missing-key=zero -f template.tmpl
```

2. Check existence first:
```go
{{ if has .config "key" }}
  {{ .config.key }}
{{ else }}
  default value
{{ end }}
```

3. Use default filter:
```go
{{ .config.key | default "fallback" }}
```

4. Use index function (doesn't error):
```go
{{ index .config "key" }}  # Returns nothing if missing
```

### Function Not Defined

**Error:**
```
Error: function "badFunc" not defined
```

**Cause:** Typo in function name or missing namespace.

**Solution:**
```go
{{- /* Bad */ -}}
{{ toUpper "text" }}  # Error: no namespace

{{- /* Good */ -}}
{{ strings.ToUpper "text" }}
```

### Wrong Number of Arguments

**Error:**
```
Error: wrong number of args for add: want 2 got 1
```

**Cause:** Function called with incorrect number of arguments.

**Solution:**
```go
{{- /* Bad */ -}}
{{ add 1 }}  # Error: add needs 2 arguments

{{- /* Good */ -}}
{{ add 1 2 }}
```

### Unexpected Unclosed Action

**Error:**
```
Error: unexpected unclosed action in command
```

**Cause:** Missing closing delimiter `}}`.

**Solution:**
```go
{{- /* Bad */ -}}
{{ env.Getenv "USER"  # Missing }}

{{- /* Good */ -}}
{{ env.Getenv "USER" }}
```

### Invalid Template Syntax

**Error:**
```
Error: template: unexpected ")" in command
```

**Cause:** Syntax error in template action.

**Solution:**
```go
{{- /* Bad */ -}}
{{ if (eq .val "test" }}  # Extra (

{{- /* Good */ -}}
{{ if eq .val "test" }}
```

## Datasource Errors

### Datasource Not Found

**Error:**
```
Error: no datasource with alias 'config'
```

**Cause:** Datasource not defined with `-d` flag.

**Solution:**
```bash
# Add datasource definition
gomplate -d config=config.yaml -f template.tmpl
```

### Datasource Access Error

**Error:**
```
Error: couldn't read datasource 'config': open config.yaml: no such file
```

**Cause:** File doesn't exist at specified path.

**Solution:**
```bash
# Verify path
ls -la config.yaml

# Use absolute path
gomplate -d config=file:///absolute/path/config.yaml -f template.tmpl

# Or relative to current directory
gomplate -d config=./config.yaml -f template.tmpl
```

### MIME Type Detection Failed

**Error:**
```
Error: unsupported MIME type for datasource
```

**Cause:** Unable to determine data format.

**Solution:**
```bash
# Override MIME type
gomplate -d config=data.txt?type=application/json -f template.tmpl
```

### Vault Authentication Failed

**Error:**
```
Error: error reading vault secret: permission denied
```

**Cause:** Missing or invalid Vault authentication.

**Solution:**
```bash
# Set Vault token
export VAULT_TOKEN=your-token

# Or use other auth methods
export VAULT_ROLE_ID=role-id
export VAULT_SECRET_ID=secret-id
```

## Configuration File Errors

### Config File Not Found

**Error:**
```
Error: config file not found: .gomplate.yaml
```

**Cause:** Default config file doesn't exist.

**Solution:**
```bash
# Create config file
touch .gomplate.yaml

# Or disable config file
gomplate --config="" -f template.tmpl

# Or specify different config
gomplate --config custom.yaml
```

### Invalid YAML Syntax

**Error:**
```
Error: yaml: line 5: did not find expected key
```

**Cause:** YAML syntax error in config file.

**Solution:**
```bash
# Validate YAML
yamllint .gomplate.yaml

# Common issues:
# - Missing colons
# - Incorrect indentation (use spaces, not tabs)
# - Unquoted special characters
```

### Conflicting Options

**Error:**
```
Error: --in and --input-dir are mutually exclusive
```

**Cause:** Incompatible configuration options.

**Solution:**
```yaml
# Bad: both in and inputDir
in: template content
inputDir: templates/

# Good: use only one
in: template content
# OR
inputDir: templates/
outputDir: rendered/
```

## Debugging Techniques

### Enable Verbose Logging

```bash
gomplate --verbose -f template.tmpl -o output.txt
```

Logs show:
- Datasource loading
- Template parsing
- Function calls
- Errors with stack traces

### Test with Minimal Template

Isolate the problem by testing with minimal template:

```bash
# Test datasource access
gomplate -d config=config.yaml -i '{{ ds "config" }}'

# Test specific function
gomplate -i '{{ env.Getenv "USER" }}'

# Test template syntax
gomplate -i '{{ if true }}works{{ end }}'
```

### Inspect Datasource Content

```bash
# Dump entire datasource
gomplate -d config=config.yaml -i '{{ ds "config" | data.ToJSONPretty "  " }}'

# Check specific keys
gomplate -d config=config.yaml -i '{{ coll.Keys (ds "config") }}'
```

### Validate Template Without Rendering

```bash
# Use --missing-key=zero to ignore missing data
gomplate --missing-key=zero -f template.tmpl -o /dev/null
```

### Check Variable Types

```go
{{ $val := ds "config" "key" }}
Type: {{ typeOf $val }}
Is string: {{ typeIs "string" $val }}
Is int: {{ typeIs "int" $val }}
Value: {{ printf "%#v" $val }}
```

### Debug Output

```go
{{- /* Add debug output */ -}}
{{ printf "DEBUG: val = %#v" $val }}

{{- /* Dump entire context */ -}}
{{ . | data.ToJSONPretty "  " }}

{{- /* Check datasource structure */ -}}
{{ ds "config" | data.ToYAML }}
```

## Performance Issues

### Slow Template Rendering

**Cause:** Multiple datasource reads in loops.

**Solution:**
```go
{{- /* Bad: reads datasource N times */ -}}
{{ range seq 1 100 }}
  {{ (ds "config").value }}
{{ end }}

{{- /* Good: read once, cache in variable */ -}}
{{ $config := ds "config" }}
{{ range seq 1 100 }}
  {{ $config.value }}
{{ end }}
```

### Large File Processing

**Cause:** Processing many files with `--input-dir`.

**Solution:**
```bash
# Use excludes to skip unnecessary files
gomplate --input-dir templates/ --output-dir rendered/ \
  --exclude '*.md' --exclude 'draft/**'

# Process files selectively
gomplate -f template1.tmpl -f template2.tmpl \
  -o output1.txt -o output2.txt
```

## Best Practices for Error Prevention

### Always Provide Defaults

```go
{{ .config.optional | default "fallback" }}
{{ env.Getenv "VAR" "default" }}
```

### Check Existence Before Access

```go
{{ if has .config "key" }}
  {{ .config.key }}
{{ end }}
```

### Use Required for Mandatory Values

```go
{{ .apiKey | required "API_KEY is required" }}
```

### Validate Input Data

```go
{{ $port := .config.port }}
{{ if or (lt $port 1) (gt $port 65535) }}
  {{ fail "Invalid port number" }}
{{ end }}
```

### Use Type Checking

```go
{{ if typeIs "string" .value }}
  {{ .value }}
{{ else }}
  {{ fail "Expected string value" }}
{{ end }}
```

## Getting Help

### Check Template Syntax

Use gomplate's `--help` flag for syntax reference:
```bash
gomplate --help
```

### Consult Documentation

Official documentation: https://docs.gomplate.ca

### Enable Debug Mode

```bash
# Verbose output
gomplate --verbose -f template.tmpl

# Dry run (check syntax only)
gomplate --missing-key=zero -f template.tmpl -o /dev/null
```

### Test Individual Components

Break complex templates into smaller parts:

```bash
# Test datasource
gomplate -d cfg=config.yaml -i '{{ ds "cfg" }}'

# Test logic
gomplate -i '{{ if eq 1 1 }}works{{ end }}'

# Test functions
gomplate -i '{{ strings.ToUpper "test" }}'
```
