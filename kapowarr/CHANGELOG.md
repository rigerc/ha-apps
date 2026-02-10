# Changelog

## [1.1.1](https://github.com/rigerc/ha-apps/compare/kapowarr-1.1.0...kapowarr-1.1.1) (2026-02-10)


### 🐛 Bug Fixes

* **Dockerfile:** add build dependencies and fixes ([c8385d2](https://github.com/rigerc/ha-apps/commit/c8385d294f86cf7fa38e2f2f8c5454260eb65625))
* **Dockerfile:** combine cargo and pip install into single RUN command ([72a9525](https://github.com/rigerc/ha-apps/commit/72a95251a9e92141d92dd8bb23c97343c638db01))


### 🧰 Maintenance

* update manifest and configs [skip ci] ([4db8fb9](https://github.com/rigerc/ha-apps/commit/4db8fb96ce5e300b8d2327f4274acaf05923c3ae))

## [1.1.0](https://github.com/rigerc/ha-apps/compare/kapowarr-1.0.0...kapowarr-1.1.0) (2026-02-10)


### ✨ Features

* **kapowarr:** initial release of Kapowarr add-on with documentation, Dockerfile, and configuration ([84dcfb9](https://github.com/rigerc/ha-apps/commit/84dcfb9dd23097b3e1037f7dcbd8cf02f14fec99))


### 🐛 Bug Fixes

* **builder:** improve image detection and error handling in healthcheck step ([993cda5](https://github.com/rigerc/ha-apps/commit/993cda562bbc8a39914cf7fa80463b6df35cedbd))
* **config:** comment out ingress_port in configuration ([e55b9d9](https://github.com/rigerc/ha-apps/commit/e55b9d9891cefb9802afdcf116d6eb067ab657bc))
* **Dockerfile:** fix tag case with upstream ([d9ecf81](https://github.com/rigerc/ha-apps/commit/d9ecf81c732ad94dae6d5813dd90fac58eb1c854))
* make shell scripts executable ([afcd9e0](https://github.com/rigerc/ha-apps/commit/afcd9e0c648c198fb5a7d58eb249fd20dab90f10))


### 🧰 Maintenance

* **repo:** test ([90154a6](https://github.com/rigerc/ha-apps/commit/90154a6b3d1076e7b54c7ab5d9fe95aa17bc9756))
* update manifest and configs ([8c26da1](https://github.com/rigerc/ha-apps/commit/8c26da1c9c4ba39eceb6b1ce01ee06edf78f1ba7))
* update manifest and configs [skip ci] ([a2288df](https://github.com/rigerc/ha-apps/commit/a2288dfb46340d48a51217c687765c220bf432cd))
* update manifest and configs [skip ci] ([39baa8f](https://github.com/rigerc/ha-apps/commit/39baa8fe44bcd26160bb6294956fb5f9dd94ddc8))

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
