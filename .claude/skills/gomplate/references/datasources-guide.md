# Gomplate Datasources Guide

Complete reference for working with gomplate datasources - external data sources that can be referenced in templates.

## Overview

Datasources provide template access to external data. They are:
- Defined with `--datasource`/`-d` flag or `defineDatasource` function
- Referenced by alias using `datasource`/`ds` or `include` functions
- Lazy-loaded (only read when accessed in template)
- Alternatively loaded into context with `--context`/`-c` (loaded before rendering)

## URL Format

All datasources use URL format:

```
scheme://authority/path?query#fragment
```

Components:
- **scheme** - Identifies datasource type (file, http, vault, consul, etc.)
- **authority** - Server hostname and port (for remote datasources)
- **path** - Locator for the data (file path, API endpoint, secret path)
- **query** - Parameters (MIME type override, dynamic secret params)
- **fragment** - Access subset of data

## Supported Datasource Types

### File Datasources

**Scheme:** `file://` or relative path

**Usage:**
```bash
# Absolute path
gomplate -d config=file:///etc/app/config.json

# Relative path
gomplate -d config=./config.json

# Implicit alias (uses filename without extension)
gomplate -d config.json
```

**Directory support:**
```bash
# List files in directory
gomplate -d configs=file:///etc/app/configs/
```

**MIME type override:**
```bash
# Force JSON parsing for .txt file
gomplate -d data=file:///tmp/data.txt?type=application/json
```

### HTTP/HTTPS Datasources

**Scheme:** `http://`, `https://`

**Usage:**
```bash
gomplate -d api=https://api.example.com/data.json
```

**With headers:**
```bash
gomplate -d api=https://api.example.com/data \
  -H 'api=Authorization: Bearer token123' \
  -H 'api=Accept: application/json'
```

**Example in template:**
```
{{ (ds "api").results }}
```

### Environment Variable Datasources

**Scheme:** `env:`

**Usage:**
```bash
# Single environment variable
gomplate -d user=env:USER
gomplate -d home=env:///HOME

# With type override for structured data
export CONFIG='{"db":"localhost"}'
gomplate -d cfg=env:/CONFIG?type=application/json
```

**Template usage:**
```
User: {{ include "user" }}
Database: {{ (ds "cfg").db }}
```

### Stdin Datasources

**Scheme:** `stdin:`

**Usage:**
```bash
# Unstructured input
echo 'hello world' | gomplate -d in=stdin: -i '{{ include "in" }}'

# Structured input (provide fake filename with extension)
echo '{"name":"Alice"}' | gomplate -d user=stdin:///data.json -i '{{ (ds "user").name }}'

# Or with explicit MIME type
echo '["a","b"]' | gomplate -d items=stdin:?type=application/array%2Bjson -i '{{ index (ds "items") 0 }}'
```

### Vault Datasources

**Scheme:** `vault://`, `vault+https://`, `vault+http://`

**Prerequisites:**
- Vault server accessible
- Authentication configured (see Authentication section)

**Usage:**
```bash
# Read secret (path in URL)
gomplate -d secret=vault:///secret/app/password

# Read secret (path in template)
gomplate -d vault=vault:/// -i '{{ (ds "vault" "secret/app/password").value }}'

# Specify Vault server
gomplate -d secret=vault://vault.example.com:8200/secret/app/password

# Dynamic secrets with parameters
gomplate -d ssh=vault:///ssh/creds/role?ip=10.1.2.3&username=user
```

**KV v2 secret versioning:**
```bash
# Get specific version
gomplate -d secret=vault:///secret/data/app?version=2

# Latest version (default)
gomplate -d secret=vault:///secret/data/app
```

**Directory listing:**
```bash
# List secrets under path
gomplate -d secrets=vault:///secret/app/ -i '{{ range (ds "secrets") }}{{ . }}{{ end }}'
```

**Authentication:**

Vault authentication uses environment variables (in precedence order):

1. **AppRole** - `VAULT_ROLE_ID` and `VAULT_SECRET_ID`
2. **GitHub** - `VAULT_AUTH_GITHUB_TOKEN`
3. **Userpass** - `VAULT_AUTH_USERNAME` and `VAULT_AUTH_PASSWORD`
4. **Token** - `VAULT_TOKEN` or `~/.vault-token` file
5. **AWS** - `VAULT_AUTH_AWS_ROLE` (defaults to AMI ID)

Mount point overrides: `VAULT_AUTH_APPROLE_MOUNT`, `VAULT_AUTH_GITHUB_MOUNT`, etc.

**Template usage:**
```
# KV v1
Password: {{ (ds "secret").value }}

# KV v2
Password: {{ (ds "secret").data.password }}
```

### Consul Datasources

**Scheme:** `consul://`, `consul+http://`, `consul+https://`

**Usage:**
```bash
# Read key
gomplate -d config=consul:///app/config

# Specify server
gomplate -d config=consul://consul.example.com:8500/app/config

# Key prefix (directory)
gomplate -d configs=consul:///app/configs/
```

**Authentication:**
```bash
# ACL token
export CONSUL_HTTP_TOKEN=your-token
gomplate -d config=consul:///app/config

# Basic auth
export CONSUL_HTTP_AUTH=username:password
gomplate -d config=consul:///app/config

# Vault-generated token
export CONSUL_VAULT_ROLE=app-role
gomplate -d config=consul:///app/config
```

**Template usage:**
```
{{ ds "config" }}
{{ range (ds "configs") }}{{ . }}{{ end }}
```

### AWS Systems Manager Parameter Store

**Scheme:** `aws+smp://`

**URL format:**
```
aws+smp:///path/to/parameter
aws+smp:parameter-name
```

**Usage:**
```bash
# Hierarchical parameter
gomplate -d param=aws+smp:///app/production/db-password

# Non-hierarchical parameter
gomplate -d param=aws+smp:myparameter

# Directory listing
gomplate -d params=aws+smp:///app/production/
```

**Template output structure:**
```
{{ $p := ds "param" }}
Name: {{ $p.Name }}
Type: {{ $p.Type }}
Value: {{ $p.Value }}
Version: {{ $p.Version }}
```

**Authentication:**
Uses standard AWS credential chain (environment variables, IAM role, etc.)

Required IAM permissions: `ssm:GetParameter`, `ssm:GetParameters` (for directory)

### AWS Secrets Manager

**Scheme:** `aws+sm://`

**Usage:**
```bash
# Read secret
gomplate -d secret=aws+sm:///app/db-credentials
gomplate -d secret=aws+sm:mysecret
```

**Template output:**
Returns `SecretString` or `SecretBinary` content directly (not wrapped in object).

```
{{ ds "secret" }}
```

### Amazon S3

**Scheme:** `s3://`

**URL format:**
```
s3://bucket-name/path/to/object?region=us-east-1&endpoint=...
```

**Usage:**
```bash
# Basic
gomplate -d config=s3://my-bucket/config/app.json

# With region
gomplate -d config=s3://my-bucket/config/app.json?region=eu-west-1

# Directory listing
gomplate -d configs=s3://my-bucket/config/

# S3-compatible server (MinIO, etc.)
gomplate -d data=s3://my-bucket/data.json?endpoint=localhost:9000&disableSSL=true&s3ForcePathStyle=true
```

**Query parameters:**
- `region` - AWS region (overrides `AWS_REGION`)
- `endpoint` - Custom endpoint for S3-compatible servers
- `s3ForcePathStyle` - Use path-style access (required for some servers)
- `disableSSL` - Disable SSL (testing only!)
- `type` - MIME type override

### Google Cloud Storage

**Scheme:** `gs://`

**Prerequisites:**
Set `GOOGLE_APPLICATION_CREDENTIALS` to JSON key file path.

**Usage:**
```bash
# Read object
gomplate -d config=gs://my-bucket/config/app.json

# Directory listing
gomplate -d configs=gs://my-bucket/config/
```

### Git Datasources

**Scheme:** `git://`, `git+file://`, `git+http://`, `git+https://`, `git+ssh://`

**URL format:**
```
git+https://host/repo-path//file-path#branch-or-tag
```

The `//` separates repository path from file path within repo.

**Usage:**
```bash
# GitHub file
gomplate -d readme=git+https://github.com/user/repo//README.md

# Specific branch
gomplate -d config=git+https://github.com/user/repo//config/app.yaml#develop

# Specific tag
gomplate -d config=git+https://github.com/user/repo//config/app.yaml#refs/tags/v1.0.0

# Local repo
gomplate -d config=git+file:///path/to/repo//config/app.yaml

# Directory
gomplate -d configs=git+https://github.com/user/repo//configs/

# SSH with authentication
gomplate -d config=git+ssh://git@github.com/user/private-repo//config.yaml
```

**Authentication:**

HTTP(S): Set `GIT_HTTP_PASSWORD` or use token in `GIT_HTTP_TOKEN`.

SSH: Set `GIT_SSH_KEY` or use SSH agent.

### GCP Compute Metadata

**Scheme:** `gcp+meta://`

**Usage (only on GCP VMs):**
```bash
# Instance metadata
gomplate -d meta=gcp+meta:/// -i '{{ include "meta" "instance/id" }}'

# Project metadata
gomplate -d meta=gcp+meta:/// -i '{{ include "meta" "project/project-id" }}'

# Directory listing
gomplate -d meta=gcp+meta:///instance/ -i '{{ ds "meta" }}'
```

### Merge Datasources

**Scheme:** `merge:`

Merge multiple datasources, with left values overriding right.

**URL format:**
```
merge:source1|source2|source3
```

**Usage:**
```bash
# Merge separately-defined sources
gomplate -d prod=prod.yaml -d defaults=defaults.yaml \
  -d config=merge:prod|defaults

# Merge in-line
gomplate -d config=merge:./prod.yaml|./defaults.yaml|./base.yaml
```

**Template usage:**
```
{{ (ds "config").setting }}
```

Values from `prod.yaml` override `defaults.yaml`, which override `base.yaml`.

## MIME Types and Parsing

Gomplate auto-detects formats based on file extension or Content-Type header.

**Supported formats:**

| Format | MIME Type | Extensions | Function |
|--------|-----------|------------|----------|
| JSON | `application/json` | `.json` | `data.JSON` |
| JSON Array | `application/array+json` | - | `data.JSONArray` |
| YAML | `application/yaml` | `.yml`, `.yaml` | `data.YAML` |
| TOML | `application/toml` | `.toml` | `data.TOML` |
| CSV | `text/csv` | `.csv` | `data.CSV` |
| .env | `application/x-env` | `.env` | Special parser |
| Plain Text | `text/plain` | - | No parsing |

**Override MIME type:**
```bash
# Force JSON for .txt file
gomplate -d data=file:///data.txt?type=application/json

# Force array parsing
gomplate -d items=stdin:?type=application/array%2Bjson
```

## Directory Datasources

When path ends with `/`, directory semantics apply (where supported).

**Supported types:**
- File
- Vault (translates to LIST)
- Consul
- S3
- Google Cloud Storage
- Git
- AWS Systems Manager Parameter Store

**Usage:**
```bash
gomplate -d configs=file:///etc/app/configs/ -i '{{ range (ds "configs") }}{{ . }}{{ end }}'
```

Returns array of key/file names, which can be iterated and accessed individually.

## Context vs Datasource

**Datasource (`-d`):**
- Lazy-loaded (read only when accessed)
- Referenced by alias: `{{ ds "alias" }}`
- Good for conditional data

**Context (`-c`):**
- Immediately loaded before rendering
- Available as context property: `{{ .alias }}`
- Required for template execution

**Example:**
```bash
# Datasource (lazy)
gomplate -d config=config.yaml -i '{{ (ds "config").value }}'

# Context (immediate)
gomplate -c config=config.yaml -i '{{ .config.value }}'

# Override entire context
gomplate -c .=config.yaml -i '{{ .value }}'
```

## Best Practices

**Use meaningful aliases:**
```bash
# Good
-d appConfig=config.yaml -d dbSecrets=vault:///db/creds

# Avoid
-d c=config.yaml -d s=vault:///db/creds
```

**Scope Vault/Consul datasources:**
```bash
# Good - scope to app namespace
-d vault=vault:///secret/myapp

# Use in template
{{ (ds "vault" "database/password").value }}
```

**Test with file datasources first:**
Before connecting to Vault/Consul/AWS, test templates with JSON/YAML files.

**Handle missing data:**
```
{{ if has (ds "config") "optional_key" }}
  {{ (ds "config").optional_key }}
{{ else }}
  default value
{{ end }}
```

**Use merge for defaults:**
```bash
-d config=merge:prod.yaml|defaults.yaml
```

**Secure credentials:**
Use `_FILE` suffix for environment variables containing credentials:
```bash
export VAULT_TOKEN_FILE=/run/secrets/vault-token
export GIT_SSH_KEY_FILE=/run/secrets/git-key
```
