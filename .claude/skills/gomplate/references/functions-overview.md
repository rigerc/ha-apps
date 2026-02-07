# Gomplate Functions Overview

Quick reference for gomplate's built-in function namespaces and commonly-used functions.

## Function Namespaces

Gomplate organizes functions into namespaces for clarity and to avoid naming conflicts.

### `env` - Environment Variables

Access environment variables and system information.

```go
{{ env.Getenv "USER" }}                    # Get env var, error if missing
{{ env.Getenv "VAR" "default" }}          # Get env var with default
{{ env.ExpandEnv "Hello $USER" }}         # Expand env vars in string
```

### `strings` - String Manipulation

String operations (case, trimming, splitting, etc.).

```go
{{ strings.ToUpper "hello" }}             # HELLO
{{ strings.ToLower "HELLO" }}             # hello
{{ strings.Title "hello world" }}         # Hello World
{{ strings.Trim " text " }}               # "text"
{{ strings.TrimSpace "\n text \n" }}      # "text"
{{ strings.TrimPrefix "pre_text" "pre_" }}# "text"
{{ strings.Split "a,b,c" "," }}           # ["a","b","c"]
{{ strings.Join (coll.Slice "a" "b") "," }} # "a,b"
{{ strings.ReplaceAll "hello" "l" "r" }}  # "herro"
{{ strings.Contains "hello" "ll" }}       # true
{{ strings.HasPrefix "hello" "he" }}      # true
{{ strings.Repeat "x" 3 }}                # "xxx"
```

### `coll` - Collection Operations

Work with arrays, slices, and maps.

```go
{{ coll.Slice "a" "b" "c" }}              # ["a","b","c"]
{{ coll.Dict "key1" "val1" "key2" "val2" }} # {"key1":"val1","key2":"val2"}
{{ coll.Has .map "key" }}                 # true/false
{{ coll.Keys .map }}                      # Array of keys
{{ coll.Values .map }}                    # Array of values
{{ index .array 0 }}                      # Get element at index
{{ coll.Append .array "item" }}           # Add to array
{{ coll.Sort "field" .array }}            # Sort by field
{{ coll.Reverse .array }}                 # Reverse array
{{ coll.Merge .map1 .map2 }}             # Merge maps (map2 overrides)
{{ coll.Where .array "field" "value" }}   # Filter array
```

### `conv` - Type Conversion

Convert between types.

```go
{{ conv.ToInt "42" }}                     # 42 (int)
{{ conv.ToInt64 "42" }}                   # 42 (int64)
{{ conv.ToFloat64 "3.14" }}              # 3.14 (float64)
{{ conv.ToBool "true" }}                  # true
{{ conv.ToString 42 }}                    # "42"
{{ conv.Atoi "123" }}                     # 123 (int)
{{ conv.ParseInt "FF" 16 64 }}           # 255 (hex to int)
```

### `data` - Data Parsing

Parse and convert data formats.

```go
{{ data.JSON '{"key":"value"}' }}         # Parse JSON string
{{ data.YAML "key: value" }}              # Parse YAML string
{{ data.TOML "key = \"value\"" }}         # Parse TOML string
{{ data.CSV "a,b\n1,2" }}                 # Parse CSV string
{{ . | data.ToJSON }}                     # Convert to JSON
{{ . | data.ToJSONPretty "  " }}         # Pretty JSON
{{ . | data.ToYAML }}                     # Convert to YAML
{{ . | data.ToTOML }}                     # Convert to TOML
{{ . | data.ToCSV }}                      # Convert to CSV
```

### `file` - File Operations

Read files and check file system.

```go
{{ file.Read "/path/to/file" }}           # Read file as string
{{ file.Exists "/path/to/file" }}         # true/false
{{ file.IsDir "/path/to/dir" }}          # true/false
{{ file.ReadDir "/path/to/dir" }}        # Array of filenames
{{ file.Stat "/path/to/file" }}          # File info (size, mode, etc.)
```

### `filepath` - Path Manipulation

Work with file paths.

```go
{{ filepath.Base "/path/to/file.txt" }}   # "file.txt"
{{ filepath.Dir "/path/to/file.txt" }}    # "/path/to"
{{ filepath.Ext "/path/to/file.txt" }}    # ".txt"
{{ filepath.Join "path" "to" "file" }}    # "path/to/file"
{{ filepath.Split "/path/to/file" }}      # ["/path/to/", "file"]
{{ filepath.Clean "path//to/../file" }}   # "path/file"
```

### `math` - Mathematical Operations

Arithmetic and math functions.

```go
{{ add 1 2 }}                             # 3
{{ sub 5 3 }}                             # 2
{{ mul 3 4 }}                             # 12
{{ div 10 2 }}                            # 5
{{ mod 10 3 }}                            # 1
{{ math.Abs -5 }}                         # 5
{{ math.Ceil 1.1 }}                       # 2
{{ math.Floor 1.9 }}                      # 1
{{ math.Round 1.5 }}                      # 2
{{ math.Max 1 2 3 }}                      # 3
{{ math.Min 1 2 3 }}                      # 1
{{ math.Pow 2 3 }}                        # 8
{{ math.Seq 1 5 }}                        # [1,2,3,4,5]
```

### `time` - Time and Date

Work with dates and times.

```go
{{ time.Now }}                            # Current time
{{ time.Now | time.Format "2006-01-02" }} # "2024-01-15"
{{ time.Parse "2006-01-02" "2024-01-15" }} # Parse date
{{ time.Unix 1234567890 }}                # Unix timestamp to time
{{ time.Now | time.Unix }}                # Time to Unix timestamp
{{ time.ZoneName }}                       # "UTC"
```

### `crypto` - Cryptographic Functions

Hashing and encryption.

```go
{{ crypto.SHA1 "text" }}                  # SHA1 hash
{{ crypto.SHA256 "text" }}                # SHA256 hash
{{ crypto.SHA512 "text" }}                # SHA512 hash
{{ crypto.MD5 "text" }}                   # MD5 hash (not secure!)
{{ crypto.BCRYPT "password" }}            # BCrypt hash
```

### `net` - Networking

Network and IP operations.

```go
{{ net.LookupIP "example.com" }}          # Resolve hostname
{{ net.LookupSRV "service" "tcp" "domain" }} # SRV record lookup
{{ net.ParseIP "192.168.1.1" }}          # Parse IP address
```

### `regexp` - Regular Expressions

Pattern matching and replacement.

```go
{{ regexp.Match "[0-9]+" "abc123" }}      # true
{{ regexp.Find "[0-9]+" "abc123def" }}    # "123"
{{ regexp.FindAll "[0-9]+" "a1b2c3" -1 }} # ["1","2","3"]
{{ regexp.Replace "[0-9]+" "x" "a1b2" }}  # "axbx"
{{ regexp.Split ":" "a:b:c" -1 }}        # ["a","b","c"]
```

## Commonly Used Functions

### Default Values

```go
{{ .value | default "fallback" }}         # Use fallback if .value is empty
{{ env.Getenv "VAR" "default" }}         # Env var with default
```

### Required Values

```go
{{ .value | required "error message" }}   # Error if .value is empty
```

### Type Checking

```go
{{ typeIs "string" .value }}              # true/false
{{ typeOf .value }}                       # "string", "int", etc.
```

### Ternary

```go
{{ ternary "yes" "no" (eq .val "test") }} # "yes" if condition true
```

### Comparison

```go
{{ eq .a .b }}                            # Equal
{{ ne .a .b }}                            # Not equal
{{ lt .a .b }}                            # Less than
{{ le .a .b }}                            # Less than or equal
{{ gt .a .b }}                            # Greater than
{{ ge .a .b }}                            # Greater than or equal
```

### Logical Operations

```go
{{ and true false }}                      # false
{{ or true false }}                       # true
{{ not true }}                            # false
```

### Datasource Functions

```go
{{ ds "alias" }}                          # Load datasource
{{ ds "alias" "key" }}                    # Load specific key
{{ include "alias" }}                     # Include raw content
{{ defineDatasource "alias" "url" }}     # Define datasource dynamically
```

### Template Functions

```go
{{ template "name" . }}                   # Execute named template
{{ tmpl.Inline "{{.}}" "value" }}        # Execute inline template
{{ tmpl.Exec "name" . }}                  # Execute template by name
```

## Function Composition

Functions can be chained using pipes:

```go
{{ "hello world" | strings.ToUpper | strings.ReplaceAll " " "-" }}
# Result: "HELLO-WORLD"

{{ env.Getenv "PATH" | strings.Split ":" | coll.Slice | len }}
# Count PATH entries

{{ file.Read "config.json" | data.JSON | coll.Has "key" }}
# Read and parse JSON, check for key
```

## Advanced Patterns

### Conditional Execution

```go
{{ if eq (env.Getenv "ENV") "prod" -}}
  {{ include "prod-config" }}
{{- else -}}
  {{ include "dev-config" }}
{{- end }}
```

### Looping with Functions

```go
{{ range $idx, $item := coll.Sort "name" (ds "users") -}}
{{ add $idx 1 }}. {{ $item.name }}
{{ end }}
```

### Error Handling

```go
{{ $val := env.Getenv "OPTIONAL" | default "" }}
{{ if ne $val "" -}}
  Value: {{ $val }}
{{- else -}}
  No value provided
{{- end }}
```

For complete function documentation, see the official gomplate functions reference at https://docs.gomplate.ca/functions/
