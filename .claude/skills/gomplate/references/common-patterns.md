# Gomplate Common Patterns

Practical patterns and recipes for common gomplate use cases.

## Configuration File Generation

### Environment-Based Configuration

```go
{{- $env := env.Getenv "ENV" | default "development" -}}
# {{ $env | strings.ToUpper }} Configuration

database:
  host: {{ if eq $env "production" }}prod-db.example.com{{ else }}localhost{{ end }}
  port: {{ if eq $env "production" }}5432{{ else }}5433{{ end }}
  ssl: {{ eq $env "production" }}

log_level: {{ if eq $env "production" }}WARN{{ else }}DEBUG{{ end }}
```

### Merging Defaults with Overrides

```bash
# Merge environment-specific config over defaults
gomplate -d config=merge:config.prod.yaml|config.defaults.yaml
```

Template:
```go
{{ $cfg := ds "config" }}
database:
  host: {{ $cfg.database.host }}
  pool_size: {{ $cfg.database.pool_size | default 10 }}
```

## Secret Management

### Vault Integration

```go
{{- $dbCreds := ds "vault" "database/creds/app" -}}
DB_USER={{ $dbCreds.data.username }}
DB_PASS={{ $dbCreds.data.password }}
DB_HOST={{ ds "config" "database.host" }}
```

Command:
```bash
gomplate -d vault=vault:/// -d config=config.yaml -f db.env.tmpl -o db.env
```

### AWS Secrets Manager

```go
{{- $secret := ds "aws-secret" | data.JSON -}}
api_key={{ $secret.api_key }}
webhook_url={{ $secret.webhook_url }}
```

Command:
```bash
gomplate -d aws-secret=aws+sm:///app/production/api-keys -f config.tmpl
```

## Data Transformation

### JSON to YAML

```bash
echo '{"name": "app", "version": "1.0"}' | \
  gomplate -d in=stdin:///data.json -i '{{ ds "in" | data.ToYAML }}'
```

### YAML to Environment Variables

Template:
```go
{{ range $key, $value := ds "config" -}}
export {{ $key | strings.ToUpper }}="{{ $value }}"
{{ end }}
```

Command:
```bash
gomplate -d config=config.yaml -f env.sh.tmpl -o env.sh
source env.sh
```

### CSV Processing

```go
{{- $csv := ds "data" -}}
{{- range $idx, $row := $csv -}}
{{- if ne $idx 0 -}}
User: {{ index $row 0 }}, Email: {{ index $row 1 }}
{{ end -}}
{{- end -}}
```

## Loops and Iteration

### Iterating Arrays

```go
{{- $servers := coll.Slice "web1" "web2" "web3" -}}
{{- range $idx, $server := $servers }}
server_{{ add $idx 1 }}:
  hostname: {{ $server }}.example.com
  priority: {{ add $idx 1 }}
{{- end }}
```

### Iterating Maps

```go
{{- $config := ds "config" -}}
{{- range $key, $value := $config.services }}
[{{ $key }}]
{{ range $setting, $val := $value -}}
{{ $setting }} = {{ $val }}
{{ end }}
{{- end }}
```

### Filtering Collections

```go
{{- $servers := ds "servers" -}}
{{- range $server := $servers -}}
{{- if has $server.tags "production" -}}
- {{ $server.name }} ({{ $server.ip }})
{{ end -}}
{{- end -}}
```

## Conditional Logic

### Multi-Way Conditionals

```go
{{- $env := env.Getenv "ENV" -}}
{{- if eq $env "production" -}}
log_level: WARN
replicas: 5
{{- else if eq $env "staging" -}}
log_level: INFO
replicas: 2
{{- else -}}
log_level: DEBUG
replicas: 1
{{- end }}
```

### Checking Key Existence

```go
{{- $config := ds "config" -}}
{{ if has $config "optional_feature" -}}
feature_enabled: {{ $config.optional_feature }}
{{- else -}}
feature_enabled: false
{{- end }}
```

### Default Values

```go
timeout: {{ env.Getenv "TIMEOUT" | default "30" }}
max_connections: {{ (ds "config").max_connections | default 100 }}
api_url: {{ (ds "config").api.url | required "API URL is required" }}
```

## String Manipulation

### Case Conversion

```go
{{ "hello_world" | strings.ToUpper }}               # HELLO_WORLD
{{ "HELLO_WORLD" | strings.ToLower }}               # hello_world
{{ "hello world" | strings.Title }}                 # Hello World
{{ "hello-world" | strings.ReplaceAll "-" "_" }}    # hello_world
```

### String Splitting and Joining

```go
{{- $path := "/usr/local/bin" -}}
{{- $parts := strings.Split $path "/" -}}
{{- $parts | strings.Join ":" }}  # :usr:local:bin

{{- $items := coll.Slice "a" "b" "c" -}}
{{ $items | strings.Join ", " }}  # a, b, c
```

### Templates as Strings

```go
{{- $template := "Hello {{ . }}" -}}
{{- tmpl.Inline $template "World" }}  # Hello World
```

## Working with Files

### Reading and Parsing Files

```go
{{- $config := file.Read "/etc/app/config.json" | data.JSON -}}
{{ $config.database.host }}
```

### Checking File Existence

```go
{{ if file.Exists "/etc/app/config.json" -}}
Config file found
{{- else -}}
Config file missing
{{- end }}
```

### Directory Listing

```bash
gomplate -d files=file:///etc/app/configs/ -i '{{ range (ds "files") }}{{ . }}{{ print "\n" }}{{ end }}'
```

## HTTP API Integration

### GET Request with Headers

```bash
gomplate -d api=https://api.github.com/repos/user/repo \
  -H 'api=Authorization: token ghp_xxxx' \
  -H 'api=Accept: application/vnd.github.v3+json' \
  -i '{{ (ds "api").stargazers_count }}'
```

### Chaining API Calls

```go
{{- $user := ds "user-api" -}}
{{- $userId := $user.id -}}
{{- $repos := ds "repo-api" (print "users/" $userId "/repos") -}}
User {{ $user.name }} has {{ len $repos }} repositories
```

## Nested Templates

### Define and Use Templates

```go
{{- define "server" -}}
server {
  hostname: {{ .hostname }}
  ip: {{ .ip }}
}
{{- end -}}

{{- $servers := ds "servers" -}}
{{- range $servers }}
{{ template "server" . }}
{{- end }}
```

### External Template Files

```bash
gomplate -t header=header.tmpl -t footer=footer.tmpl -f main.tmpl
```

main.tmpl:
```go
{{ template "header" "My Application" }}

Application content here

{{ template "footer" }}
```

## Advanced Patterns

### Generate Multiple Files from Single Datasource

```bash
gomplate --input-dir templates/ --output-dir config/ \
  -d apps=apps.yaml
```

templates/app.conf.tmpl:
```go
{{- $app := index (ds "apps") (env.Getenv "APP_NAME") -}}
[{{ $app.name }}]
port = {{ $app.port }}
workers = {{ $app.workers }}
```

Run for each app:
```bash
for app in web api worker; do
  APP_NAME=$app gomplate -f templates/app.conf.tmpl -o config/${app}.conf
done
```

### Recursive Data Structures

```go
{{- define "render_object" -}}
{{- range $key, $value := . -}}
{{- if coll.IsMap $value -}}
{{ $key }}:
{{ tmpl.Exec "render_object" $value | strings.Indent 2 }}
{{- else -}}
{{ $key }}: {{ $value }}
{{ end -}}
{{- end -}}
{{- end -}}

{{ template "render_object" (ds "config") }}
```

### Pipeline Transformations

```go
{{- $users := ds "users" -}}
{{- $activeUsers := coll.Where $users "status" "active" -}}
{{- $sortedUsers := coll.Sort "name" $activeUsers -}}
Active Users:
{{- range $sortedUsers }}
- {{ .name }} ({{ .email }})
{{- end }}
```

### Dynamic Datasource Definition

```go
{{- $region := env.Getenv "AWS_REGION" -}}
{{- $bucket := print "s3://my-bucket-" $region "/config.json" -}}
{{- defineDatasource "config" $bucket -}}
{{ (ds "config").setting }}
```

## Error Handling

### Graceful Degradation

```go
{{- $config := coll.Dict -}}
{{- if file.Exists "config.yaml" -}}
{{-   $config = file.Read "config.yaml" | data.YAML -}}
{{- end -}}

database:
  host: {{ $config.database.host | default "localhost" }}
  port: {{ $config.database.port | default 5432 }}
```

### Required Values

```go
{{- $apiKey := env.Getenv "API_KEY" | required "API_KEY environment variable must be set" -}}
api_key: {{ $apiKey }}
```

### Type Checking

```go
{{- $value := ds "config" "setting" -}}
{{- if typeIs "string" $value -}}
String value: {{ $value }}
{{- else if typeIs "int" $value -}}
Integer value: {{ $value }}
{{- else -}}
Unknown type
{{- end }}
```

## Testing and Debugging

### Debug Output

```go
{{- /* Debug: dump entire context */ -}}
{{ . | data.ToJSONPretty "  " }}

{{- /* Debug: specific value */ -}}
{{ printf "DEBUG: config = %v" (ds "config") }}
```

### Validation

```go
{{- $config := ds "config" -}}
{{- if not (has $config "required_field") -}}
{{-   fail "Missing required field: required_field" -}}
{{- end -}}

{{- if lt $config.pool_size 1 -}}
{{-   fail "pool_size must be at least 1" -}}
{{- end -}}
```

## Performance Optimization

### Cache Datasource Reads

```go
{{- /* Bad: reads datasource multiple times */ -}}
{{ (ds "config").setting1 }}
{{ (ds "config").setting2 }}

{{- /* Good: read once, store in variable */ -}}
{{- $config := ds "config" -}}
{{ $config.setting1 }}
{{ $config.setting2 }}
```

### Minimize Template Complexity

```go
{{- /* Bad: complex nested logic */ -}}
{{ if eq (env.Getenv "ENV") "prod" }}{{ if has (ds "config") "feature" }}enabled{{ end }}{{ end }}

{{- /* Good: use variables and whitespace */ -}}
{{- $env := env.Getenv "ENV" -}}
{{- $config := ds "config" -}}
{{- if and (eq $env "prod") (has $config "feature") -}}
enabled
{{- end }}
```
