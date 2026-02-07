# Dockerfile Instructions Reference

Complete reference for all Dockerfile instructions and their usage.

## Overview

The Dockerfile supports the following instructions:

| Instruction | Description |
| :--- | :--- |
| `ADD` | Add local or remote files and directories |
| `ARG` | Use build-time variables |
| `CMD` | Specify default commands |
| `COPY` | Copy files and directories |
| `ENTRYPOINT` | Specify default executable |
| `ENV` | Set environment variables |
| `EXPOSE` | Describe which ports your application is listening on |
| `FROM` | Create a new build stage from a base image |
| `HEALTHCHECK` | Check a container's health on startup |
| `LABEL` | Add metadata to an image |
| `MAINTAINER` | Specify the author of an image (deprecated) |
| `ONBUILD` | Specify instructions for when the image is used in a build |
| `RUN` | Execute build commands |
| `SHELL` | Set the default shell of an image |
| `STOPSIGNAL` | Specify the system call signal for exiting a container |
| `USER` | Set user and group ID |
| `VOLUME` | Create volume mounts |
| `WORKDIR` | Change working directory |

## Format

```dockerfile
# Comment
INSTRUCTION arguments
```

Instructions are case-insensitive but conventionally UPPERCASE. A Dockerfile must begin with a `FROM` instruction, optionally preceded by parser directives, comments, and globally scoped `ARG`s.

## Parser Directives

### syntax

Declares the Dockerfile syntax version:

```dockerfile
# syntax=docker/dockerfile:1
```

### escape

Sets the escape character (default `\`):

```dockerfile
# escape=`
```

Useful on Windows where `\` is the path separator.

### check

Configures build checks:

```dockerfile
# check=skip=JSONArgsRecommended
# check=error=true
```

## Shell and Exec Form

Instructions `RUN`, `CMD`, and `ENTRYPOINT` support two forms:

**Exec form** (JSON array, recommended):
```dockerfile
CMD ["nginx", "-g", "daemon off;"]
```

**Shell form**:
```dockerfile
CMD nginx -g "daemon off;"
```

The exec form doesn't invoke a shell and handles signals properly. Use it for most cases.

## Instruction Details

### FROM

Creates a new build stage from a base image:

```dockerfile
FROM [--platform=<platform>] <image>[:<tag>] [@<digest>] [AS <name>]
```

Examples:
```dockerfile
FROM alpine:3.21
FROM node:20-alpine AS build
FROM --platform=linux/arm64 golang:1.23
FROM ubuntu@sha256:abc123...
```

A Dockerfile must begin with `FROM`. Multiple `FROM` instructions create multi-stage builds.

### RUN

Executes build commands:

```dockerfile
RUN <command>           # shell form
RUN ["executable", "param"]  # exec form
```

Examples:
```dockerfile
RUN apt-get update && apt-get install -y curl
RUN ["/bin/bash", "-c", "echo hello"]
```

Chain commands with `&&` to create a single layer. Use here documents for multi-line scripts:

```dockerfile
RUN <<EOF
apt-get update
apt-get install -y curl git
rm -rf /var/lib/apt/lists/*
EOF
```

### CMD

Specifies the default command to run when the container starts:

```dockerfile
CMD ["executable", "param1", "param2"]  # exec form (preferred)
CMD command param1 param2               # shell form
CMD ["param1", "param2"]                # as default params to ENTRYPOINT
```

Only the last `CMD` takes effect. Use exec form for proper signal handling.

Examples:
```dockerfile
CMD ["node", "server.js"]
CMD ["nginx", "-g", "daemon off;"]
```

### LABEL

Adds metadata to an image:

```dockerfile
LABEL <key>=<value> <key>=<value> ...
```

Examples:
```dockerfile
LABEL version="1.0.0"
LABEL vendor="ACME Incorporated" \
      com.example.is-production="" \
      com.example.version="1.0.0"
```

Use labels for project identification, licensing information, and automation.

### EXPOSE

Documents which ports the container listens on:

```dockerfile
EXPOSE <port> [<port>/<protocol>...]
```

Examples:
```dockerfile
EXPOSE 80
EXPOSE 443/tcp
EXPOSE 53/udp
```

This is documentation only. Use `-p` when running to actually publish ports.

### ENV

Sets environment variables:

```dockerfile
ENV <key>=<value> ...
ENV <key> <value>
```

Examples:
```dockerfile
ENV NODE_ENV=production
ENV PATH="/usr/local/bin:${PATH}"
ENV APP_VERSION=1.0 \
    APP_PORT=8080
```

Each `ENV` creates a new layer. For temporary variables, use `RUN export` instead.

### ADD

Adds files from URLs or build context, with automatic tar extraction:

```dockerfile
ADD [--chown=<user>:<group>] [--checksum=<checksum>] <src>... <dest>
ADD [--chown=<user>:<group>] ["<src>",... "<dest>"]
```

Examples:
```dockerfile
ADD https://example.com/file.tar.gz /usr/src/
ADD --chown=node:node app.tar.gz /home/node
```

Prefer `COPY` for local files. Use `ADD` only for remote URLs with automatic extraction or Git URLs.

### COPY

Copies files from build context or stages:

```dockerfile
COPY [--chown=<user>:<group>] [--from=<stage|image>] <src>... <dest>
COPY [--chown=<user>:<group>] ["<src>",... "<dest>"]
```

Examples:
```dockerfile
COPY . /app
COPY --from=builder /src/app .
COPY --chown=node:node package*.json ./
```

Use `COPY` instead of `ADD` for local files. Use `--from` for multi-stage builds.

### ENTRYPOINT

Configures the container to run as an executable:

```dockerfile
ENTRYPOINT ["executable", "param1", "param2"]  # exec form (preferred)
ENTRYPOINT command param1 param2               # shell form
```

Examples:
```dockerfile
ENTRYPOINT ["docker-entrypoint.sh"]
ENTRYPOINT ["s3cmd"]
CMD ["--help"]
```

`CMD` provides default arguments to `ENTRYPOINT`. Use exec form for signal handling.

### VOLUME

Creates a mount point for volumes:

```dockerfile
VOLUME ["/data"]
VOLUME /var/log /var/db
```

Examples:
```dockerfile
VOLUME /app/data
VOLUME ["/var/log/app", "/var/db/app"]
```

Use for any mutable or user-serviceable data.

### USER

Sets the user name (or UID) and group name (or GID):

```dockerfile
USER <user>[:<group>]
USER <UID>[:<GID>]
USER <user>:<group>
USER <UID>:<GID>
```

Examples:
```dockerfile
USER node
USER 1000:1000
```

Create the user first if needed. Avoid switching `USER` frequently.

### WORKDIR

Sets the working directory:

```dockerfile
WORKDIR /path/to/workdir
```

Examples:
```dockerfile
WORKDIR /app
WORKDIR ${HOME}/app
```

Use absolute paths. Creates the directory if it doesn't exist.

### ARG

Defines build-time variables:

```dockerfile
ARG <name>[=<default value>]
```

Examples:
```dockerfile
ARG VERSION=1.0.0
ARG TARGETPLATFORM
FROM alpine:3.21
ARG VERSION
```

Build arguments declared globally aren't inherited into stages without being declared again.

### ONBUILD

Adds triggers for when the image is used as a base:

```dockerfile
ONBUILD [INSTRUCTION]
```

Examples:
```dockerfile
ONBUILD COPY . /src
ONBUILD RUN npm install
```

Use for images meant to be used as base images. Tag separately (e.g., `ruby:1.9-onbuild`).

### HEALTHCHECK

Defines how to check container health:

```dockerfile
HEALTHCHECK [OPTIONS] CMD command
HEALTHCHECK NONE
```

Options:
- `--interval=DURATION` (default 30s)
- `--timeout=DURATION` (default 30s)
- `--start-period=DURATION` (default 0s)
- `--start-interval=DURATION` (default 5s)
- `--retries=N` (default 3)

Examples:
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost:8080/health || exit 1
HEALTHCHECK CMD pg_isready -U postgres || exit 1
HEALTHCHECK NONE
```

### SHELL

Overrides the default shell:

```dockerfile
SHELL ["executable", "parameters"]
```

Examples:
```dockerfile
SHELL ["/bin/bash", "-c", "-o", "pipefail"]
SHELL ["powershell", "-command"]
```

Affects subsequent `RUN`, `CMD`, `ENTRYPOINT` in shell form.

### STOPSIGNAL

Sets the system call signal to send to exit the container:

```dockerfile
STOPSIGNAL signal
```

Examples:
```dockerfile
STOPSIGNAL SIGTERM
STOPSIGNAL 9
```

Signals can be specified by name (e.g., `SIGTERM`) or number (e.g., `15`).

## Environment Replacement

Environment variables can be used in instructions:

```dockerfile
FROM busybox
ENV FOO=/bar
WORKDIR ${FOO}    # WORKDIR /bar
ADD . $FOO        # ADD . /bar
```

Supported modifiers:
- `${variable:-word}` - Use `word` if not set
- `${variable:+word}` - Use `word` if set

## Pre-Defined Build Arguments

BuildKit provides these automatically:

- `BUILDPLATFORM` - Platform of the builder
- `BUILDOS` - OS of the builder
- `BUILDARCH` - Architecture of the builder
- `BUILDVARIANT` - Variant of the builder
- `TARGETPLATFORM` - Target platform
- `TARGETOS` - Target OS
- `TARGETARCH` - Target architecture
- `TARGETVARIANT` - Target variant

Example:
```dockerfile
FROM --platform=$BUILDPLATFORM golang:alpine AS build
ARG TARGETOS
RUN GOOS=$TARGETOS go build -o app .
```
