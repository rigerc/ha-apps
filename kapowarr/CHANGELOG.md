# Changelog

## 1.0.0 (2026-02-10)

### Added

- Initial release of Kapowarr add-on for Home Assistant
- Ingress support for embedded web UI access
- S6-overlay process supervision
- Nginx reverse proxy for ingress routing
- Volume mapping for `/data` (config) and `/share` (media)
- Health check on ingress port
- Multi-architecture support (amd64, aarch64)

### Notes

- Based on Kapowarr v1.2.0
- Uses Home Assistant Alpine base image
