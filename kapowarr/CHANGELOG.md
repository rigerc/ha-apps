# Changelog

## [1.7.3](https://github.com/rigerc/ha-apps/compare/kapowarr-1.7.2...kapowarr-1.7.3) (2026-02-12)


### 🐛 Bug Fixes

* **kapowarr:** pre-seed database with url_base and log_level before startup ([07b2b2e](https://github.com/rigerc/ha-apps/commit/07b2b2e2910021802217aaabb8c5f738990fb967))

## [1.7.2](https://github.com/rigerc/ha-apps/compare/kapowarr-1.7.1...kapowarr-1.7.2) (2026-02-12)


### 🐛 Bug Fixes

* **scaffold:** use APP_LOG_LEVEL instead of LOG_LEVEL for consistency ([e9df56f](https://github.com/rigerc/ha-apps/commit/e9df56f4c6204d44e3a09c73fff857f0c24620ef))

## [1.7.1](https://github.com/rigerc/ha-apps/compare/kapowarr-1.7.0...kapowarr-1.7.1) (2026-02-12)


### 🐛 Bug Fixes

* initialize bashio log level early in setup scripts ([5c29e73](https://github.com/rigerc/ha-apps/commit/5c29e73a69618ef0ed96afdd5d48ca5c7d82fe31))

## [1.7.0](https://github.com/rigerc/ha-apps/compare/kapowarr-1.6.1...kapowarr-1.7.0) (2026-02-11)


### ✨ Features

* **kapowarr:** add docker image config and improve log level handling ([e3acc99](https://github.com/rigerc/ha-apps/commit/e3acc9917b962e631fdb608f3dba7bde3d617fc3))
* **kapowarr:** initial release of Kapowarr add-on with documentation, Dockerfile, and configuration ([84dcfb9](https://github.com/rigerc/ha-apps/commit/84dcfb9dd23097b3e1037f7dcbd8cf02f14fec99))
* **kapowarr:** migrate to s6-overlay v3 service management ([a6d63b7](https://github.com/rigerc/ha-apps/commit/a6d63b7093073d53a1ed5191b5ee48d3474fd510))


### 🐛 Bug Fixes

* **builder:** improve image detection and error handling in healthcheck step ([993cda5](https://github.com/rigerc/ha-apps/commit/993cda562bbc8a39914cf7fa80463b6df35cedbd))
* **config:** comment out ingress_port in configuration ([e55b9d9](https://github.com/rigerc/ha-apps/commit/e55b9d9891cefb9802afdcf116d6eb067ab657bc))
* **Dockerfile:** add build dependencies and fixes ([c8385d2](https://github.com/rigerc/ha-apps/commit/c8385d294f86cf7fa38e2f2f8c5454260eb65625))
* **Dockerfile:** add sqlite3 and reinstall Python dependencies ([874e6e4](https://github.com/rigerc/ha-apps/commit/874e6e43496dd47727f43dd3ba0c4ad637a1ea90))
* **Dockerfile:** combine cargo and pip install into single RUN command ([72a9525](https://github.com/rigerc/ha-apps/commit/72a95251a9e92141d92dd8bb23c97343c638db01))
* **Dockerfile:** fix tag case with upstream ([d9ecf81](https://github.com/rigerc/ha-apps/commit/d9ecf81c732ad94dae6d5813dd90fac58eb1c854))
* fix manifest ([e6aa8e2](https://github.com/rigerc/ha-apps/commit/e6aa8e2a7c1d0ae37befb247301e92f1bba78c95))
* **ha-log:** sync log level with bashio to enable debug/trace ([b00bc62](https://github.com/rigerc/ha-apps/commit/b00bc6243f0946a9ce93080ddfc4d3b25e97ca6f))
* **HA:** update HA framework source to single entrypoint ([b00ca47](https://github.com/rigerc/ha-apps/commit/b00ca4786810ab644551b2dce1dd2e134539b9f9))
* **ingress:** add sub_filter rules for HA ingress compatibility ([c1fc22f](https://github.com/rigerc/ha-apps/commit/c1fc22f87b1229fe42437e46f219128454518b1f))
* **ingress:** update ingress path to use ingress_entry instead of ingress_path ([1c067de](https://github.com/rigerc/ha-apps/commit/1c067de3f12ef00c21fbbb6f197d499bf7dc54c2))
* **kapowarr:** refactor ([1de216e](https://github.com/rigerc/ha-apps/commit/1de216e27ee44e809795fcb373dab6a48e2609fb))
* make shell scripts executable ([afcd9e0](https://github.com/rigerc/ha-apps/commit/afcd9e0c648c198fb5a7d58eb249fd20dab90f10))
* make shell scripts executable [skip ci] ([520d98e](https://github.com/rigerc/ha-apps/commit/520d98e167f7cdf10efda3aa43ab1e228a35a4e2))
* make shell scripts executable [skip ci] ([438c6f1](https://github.com/rigerc/ha-apps/commit/438c6f1d81ef153182f0c3dc04880a8038f89bec))
* **nginx:** add daemon off to nginx config ([82e0935](https://github.com/rigerc/ha-apps/commit/82e0935258e52122ab307a79c0f8fcd057a7cb7c))
* **nginx:** improve API path rewriting in ingress template ([3a9e8fe](https://github.com/rigerc/ha-apps/commit/3a9e8fe795bb2eb2b98b24b707b601f9cd0bbc38))
* **nginx:** remove unused sub_filter rewrites for ingress paths and use url_base setting ([c98b16c](https://github.com/rigerc/ha-apps/commit/c98b16ce8ef9c6209c91c82626ad6993be075f24))
* **nginx:** suppress nginx test output in container init script ([7286810](https://github.com/rigerc/ha-apps/commit/7286810e0534d90165e990e493cff8965ed78a3b))
* remove unused environment variables and ingress configuration check ([09fe26c](https://github.com/rigerc/ha-apps/commit/09fe26c1752d675aed87759b5f186305ad9b4c22))
* update ingress port to 9919 ([89bf029](https://github.com/rigerc/ha-apps/commit/89bf029e407fbe4db3ea9367c8eeaddf80d58eb6))

## [1.6.1](https://github.com/rigerc/ha-apps/compare/kapowarr-1.6.0...kapowarr-1.6.1) (2026-02-11)


### 🐛 Bug Fixes

* **HA:** update HA framework source to single entrypoint ([b00ca47](https://github.com/rigerc/ha-apps/commit/b00ca4786810ab644551b2dce1dd2e134539b9f9))

## [1.6.0](https://github.com/rigerc/ha-apps/compare/kapowarr-1.5.0...kapowarr-1.6.0) (2026-02-11)


### ✨ Features

* **kapowarr:** add docker image config and improve log level handling ([e3acc99](https://github.com/rigerc/ha-apps/commit/e3acc9917b962e631fdb608f3dba7bde3d617fc3))
* **kapowarr:** initial release of Kapowarr add-on with documentation, Dockerfile, and configuration ([84dcfb9](https://github.com/rigerc/ha-apps/commit/84dcfb9dd23097b3e1037f7dcbd8cf02f14fec99))
* **kapowarr:** migrate to s6-overlay v3 service management ([a6d63b7](https://github.com/rigerc/ha-apps/commit/a6d63b7093073d53a1ed5191b5ee48d3474fd510))


### 🐛 Bug Fixes

* **builder:** improve image detection and error handling in healthcheck step ([993cda5](https://github.com/rigerc/ha-apps/commit/993cda562bbc8a39914cf7fa80463b6df35cedbd))
* **config:** comment out ingress_port in configuration ([e55b9d9](https://github.com/rigerc/ha-apps/commit/e55b9d9891cefb9802afdcf116d6eb067ab657bc))
* **Dockerfile:** add build dependencies and fixes ([c8385d2](https://github.com/rigerc/ha-apps/commit/c8385d294f86cf7fa38e2f2f8c5454260eb65625))
* **Dockerfile:** add sqlite3 and reinstall Python dependencies ([874e6e4](https://github.com/rigerc/ha-apps/commit/874e6e43496dd47727f43dd3ba0c4ad637a1ea90))
* **Dockerfile:** combine cargo and pip install into single RUN command ([72a9525](https://github.com/rigerc/ha-apps/commit/72a95251a9e92141d92dd8bb23c97343c638db01))
* **Dockerfile:** fix tag case with upstream ([d9ecf81](https://github.com/rigerc/ha-apps/commit/d9ecf81c732ad94dae6d5813dd90fac58eb1c854))
* fix manifest ([e6aa8e2](https://github.com/rigerc/ha-apps/commit/e6aa8e2a7c1d0ae37befb247301e92f1bba78c95))
* **ha-log:** sync log level with bashio to enable debug/trace ([b00bc62](https://github.com/rigerc/ha-apps/commit/b00bc6243f0946a9ce93080ddfc4d3b25e97ca6f))
* **ingress:** add sub_filter rules for HA ingress compatibility ([c1fc22f](https://github.com/rigerc/ha-apps/commit/c1fc22f87b1229fe42437e46f219128454518b1f))
* **ingress:** update ingress path to use ingress_entry instead of ingress_path ([1c067de](https://github.com/rigerc/ha-apps/commit/1c067de3f12ef00c21fbbb6f197d499bf7dc54c2))
* **kapowarr:** refactor ([1de216e](https://github.com/rigerc/ha-apps/commit/1de216e27ee44e809795fcb373dab6a48e2609fb))
* make shell scripts executable ([afcd9e0](https://github.com/rigerc/ha-apps/commit/afcd9e0c648c198fb5a7d58eb249fd20dab90f10))
* make shell scripts executable [skip ci] ([520d98e](https://github.com/rigerc/ha-apps/commit/520d98e167f7cdf10efda3aa43ab1e228a35a4e2))
* make shell scripts executable [skip ci] ([438c6f1](https://github.com/rigerc/ha-apps/commit/438c6f1d81ef153182f0c3dc04880a8038f89bec))
* **nginx:** add daemon off to nginx config ([82e0935](https://github.com/rigerc/ha-apps/commit/82e0935258e52122ab307a79c0f8fcd057a7cb7c))
* **nginx:** improve API path rewriting in ingress template ([3a9e8fe](https://github.com/rigerc/ha-apps/commit/3a9e8fe795bb2eb2b98b24b707b601f9cd0bbc38))
* **nginx:** remove unused sub_filter rewrites for ingress paths and use url_base setting ([c98b16c](https://github.com/rigerc/ha-apps/commit/c98b16ce8ef9c6209c91c82626ad6993be075f24))
* **nginx:** suppress nginx test output in container init script ([7286810](https://github.com/rigerc/ha-apps/commit/7286810e0534d90165e990e493cff8965ed78a3b))
* remove unused environment variables and ingress configuration check ([09fe26c](https://github.com/rigerc/ha-apps/commit/09fe26c1752d675aed87759b5f186305ad9b4c22))
* update ingress port to 9919 ([89bf029](https://github.com/rigerc/ha-apps/commit/89bf029e407fbe4db3ea9367c8eeaddf80d58eb6))

## [1.5.0](https://github.com/rigerc/ha-apps/compare/kapowarr-1.4.8...kapowarr-1.5.0) (2026-02-11)


### ✨ Features

* **kapowarr:** migrate to s6-overlay v3 service management ([a6d63b7](https://github.com/rigerc/ha-apps/commit/a6d63b7093073d53a1ed5191b5ee48d3474fd510))


### 🐛 Bug Fixes

* **kapowarr:** refactor ([1de216e](https://github.com/rigerc/ha-apps/commit/1de216e27ee44e809795fcb373dab6a48e2609fb))
* make shell scripts executable [skip ci] ([520d98e](https://github.com/rigerc/ha-apps/commit/520d98e167f7cdf10efda3aa43ab1e228a35a4e2))

## [1.4.8](https://github.com/rigerc/ha-apps/compare/kapowarr-1.4.7...kapowarr-1.4.8) (2026-02-11)


### 🐛 Bug Fixes

* **ha-log:** sync log level with bashio to enable debug/trace ([b00bc62](https://github.com/rigerc/ha-apps/commit/b00bc6243f0946a9ce93080ddfc4d3b25e97ca6f))

## [1.4.7](https://github.com/rigerc/ha-apps/compare/kapowarr-1.4.6...kapowarr-1.4.7) (2026-02-11)


### 🐛 Bug Fixes

* **ingress:** update ingress path to use ingress_entry instead of ingress_path ([1c067de](https://github.com/rigerc/ha-apps/commit/1c067de3f12ef00c21fbbb6f197d499bf7dc54c2))

## [1.4.6](https://github.com/rigerc/ha-apps/compare/kapowarr-1.4.5...kapowarr-1.4.6) (2026-02-11)


### 🐛 Bug Fixes

* **nginx:** remove unused sub_filter rewrites for ingress paths and use url_base setting ([c98b16c](https://github.com/rigerc/ha-apps/commit/c98b16ce8ef9c6209c91c82626ad6993be075f24))


### 🧰 Maintenance

* update manifest and configs [skip ci] ([f5cbe00](https://github.com/rigerc/ha-apps/commit/f5cbe00c9b73fa6ee82ec3a17a4424c80b049c2e))

## [1.4.5](https://github.com/rigerc/ha-apps/compare/kapowarr-1.4.4...kapowarr-1.4.5) (2026-02-11)


### 🐛 Bug Fixes

* **nginx:** improve API path rewriting in ingress template ([3a9e8fe](https://github.com/rigerc/ha-apps/commit/3a9e8fe795bb2eb2b98b24b707b601f9cd0bbc38))


### 🧰 Maintenance

* update manifest and configs [skip ci] ([7844c75](https://github.com/rigerc/ha-apps/commit/7844c75b89c4538723c323ceeea13ebbfeebc73b))

## [1.4.4](https://github.com/rigerc/ha-apps/compare/kapowarr-1.4.3...kapowarr-1.4.4) (2026-02-11)


### 🐛 Bug Fixes

* **ingress:** add sub_filter rules for HA ingress compatibility ([c1fc22f](https://github.com/rigerc/ha-apps/commit/c1fc22f87b1229fe42437e46f219128454518b1f))


### 🧰 Maintenance

* update manifest and configs [skip ci] ([dfaf3c8](https://github.com/rigerc/ha-apps/commit/dfaf3c833d3a385d5a3b0a6028cd5fd188b358bb))

## [1.4.3](https://github.com/rigerc/ha-apps/compare/kapowarr-1.4.2...kapowarr-1.4.3) (2026-02-11)


### 🐛 Bug Fixes

* **Dockerfile:** add sqlite3 and reinstall Python dependencies ([874e6e4](https://github.com/rigerc/ha-apps/commit/874e6e43496dd47727f43dd3ba0c4ad637a1ea90))


### 🧰 Maintenance

* update manifest and configs [skip ci] ([8b0e3bc](https://github.com/rigerc/ha-apps/commit/8b0e3bce8be25910499bdcda980783e9ca42e673))

## [1.4.2](https://github.com/rigerc/ha-apps/compare/kapowarr-1.4.1...kapowarr-1.4.2) (2026-02-11)


### 🐛 Bug Fixes

* **nginx:** suppress nginx test output in container init script ([7286810](https://github.com/rigerc/ha-apps/commit/7286810e0534d90165e990e493cff8965ed78a3b))


### 🧰 Maintenance

* update manifest and configs [skip ci] ([db7087b](https://github.com/rigerc/ha-apps/commit/db7087b31fae41c722290f4388bcc077917e4981))

## [1.4.1](https://github.com/rigerc/ha-apps/compare/kapowarr-1.4.0...kapowarr-1.4.1) (2026-02-11)


### 🐛 Bug Fixes

* remove unused environment variables and ingress configuration check ([09fe26c](https://github.com/rigerc/ha-apps/commit/09fe26c1752d675aed87759b5f186305ad9b4c22))


### 🧰 Maintenance

* update manifest and configs [skip ci] ([3181f62](https://github.com/rigerc/ha-apps/commit/3181f62e9579c50c16ac692d11709fcf38ef0779))

## [1.4.0](https://github.com/rigerc/ha-apps/compare/kapowarr-1.3.0...kapowarr-1.4.0) (2026-02-11)


### ✨ Features

* **kapowarr:** add docker image config and improve log level handling ([e3acc99](https://github.com/rigerc/ha-apps/commit/e3acc9917b962e631fdb608f3dba7bde3d617fc3))
* **kapowarr:** initial release of Kapowarr add-on with documentation, Dockerfile, and configuration ([84dcfb9](https://github.com/rigerc/ha-apps/commit/84dcfb9dd23097b3e1037f7dcbd8cf02f14fec99))


### 🐛 Bug Fixes

* **builder:** improve image detection and error handling in healthcheck step ([993cda5](https://github.com/rigerc/ha-apps/commit/993cda562bbc8a39914cf7fa80463b6df35cedbd))
* **config:** comment out ingress_port in configuration ([e55b9d9](https://github.com/rigerc/ha-apps/commit/e55b9d9891cefb9802afdcf116d6eb067ab657bc))
* **Dockerfile:** add build dependencies and fixes ([c8385d2](https://github.com/rigerc/ha-apps/commit/c8385d294f86cf7fa38e2f2f8c5454260eb65625))
* **Dockerfile:** combine cargo and pip install into single RUN command ([72a9525](https://github.com/rigerc/ha-apps/commit/72a95251a9e92141d92dd8bb23c97343c638db01))
* **Dockerfile:** fix tag case with upstream ([d9ecf81](https://github.com/rigerc/ha-apps/commit/d9ecf81c732ad94dae6d5813dd90fac58eb1c854))
* fix manifest ([e6aa8e2](https://github.com/rigerc/ha-apps/commit/e6aa8e2a7c1d0ae37befb247301e92f1bba78c95))
* make shell scripts executable ([afcd9e0](https://github.com/rigerc/ha-apps/commit/afcd9e0c648c198fb5a7d58eb249fd20dab90f10))
* make shell scripts executable [skip ci] ([438c6f1](https://github.com/rigerc/ha-apps/commit/438c6f1d81ef153182f0c3dc04880a8038f89bec))
* **nginx:** add daemon off to nginx config ([82e0935](https://github.com/rigerc/ha-apps/commit/82e0935258e52122ab307a79c0f8fcd057a7cb7c))
* update ingress port to 9919 ([89bf029](https://github.com/rigerc/ha-apps/commit/89bf029e407fbe4db3ea9367c8eeaddf80d58eb6))


### 🧰 Maintenance

* fixes ([0e71dfe](https://github.com/rigerc/ha-apps/commit/0e71dfef2163857c618be72b7aa54713f1e050cd))
* **repo:** 🚀 Release  kapowarr 1.1.0 ([#28](https://github.com/rigerc/ha-apps/issues/28)) ([98c3df9](https://github.com/rigerc/ha-apps/commit/98c3df9ceaf1ca35d1c29d92ebf06b4af2ac4c9e))
* **repo:** 🚀 Release  kapowarr 1.1.1 ([#29](https://github.com/rigerc/ha-apps/issues/29)) ([81f2298](https://github.com/rigerc/ha-apps/commit/81f22989ff4ba8326803104f34ead73d563585b8))
* **repo:** 🚀 Release  kapowarr 1.1.2 ([#30](https://github.com/rigerc/ha-apps/issues/30)) ([146efea](https://github.com/rigerc/ha-apps/commit/146efeadcc9be5ca3a04b4e887210c2a5627bc7c))
* **repo:** 🚀 Release  kapowarr 1.1.3 ([#31](https://github.com/rigerc/ha-apps/issues/31)) ([4ad5173](https://github.com/rigerc/ha-apps/commit/4ad51738bf9722248b89a8f0a80ba86642060ac5))
* **repo:** 🚀 Release  kapowarr 1.3.0 ([#32](https://github.com/rigerc/ha-apps/issues/32)) ([f6033fa](https://github.com/rigerc/ha-apps/commit/f6033fa0f22fb7d8f4dee694b37354dc0c12c684))
* **repo:** 🚀 Release  kapowarr 1.3.0 ([#33](https://github.com/rigerc/ha-apps/issues/33)) ([3339868](https://github.com/rigerc/ha-apps/commit/3339868cce77af724ab9acba63a7075eee1c965a))
* **repo:** test ([90154a6](https://github.com/rigerc/ha-apps/commit/90154a6b3d1076e7b54c7ab5d9fe95aa17bc9756))
* stuff ([2514c7b](https://github.com/rigerc/ha-apps/commit/2514c7b76f5799fc713aa71ddbaea5a5ec903797))
* stuff ([919bb61](https://github.com/rigerc/ha-apps/commit/919bb619f6422fb08286a85beae663293ce07ddc))
* update manifest and configs ([5d3d1d4](https://github.com/rigerc/ha-apps/commit/5d3d1d4ab9311e9be4bad839691cd0942eb927e5))
* update manifest and configs ([8c26da1](https://github.com/rigerc/ha-apps/commit/8c26da1c9c4ba39eceb6b1ce01ee06edf78f1ba7))
* update manifest and configs [skip ci] ([41de8ce](https://github.com/rigerc/ha-apps/commit/41de8ce65693c3f7499c5d44b4b3c685cb950af8))
* update manifest and configs [skip ci] ([e32b10f](https://github.com/rigerc/ha-apps/commit/e32b10f571ced5cae12de54ce58a76aff0bf5c44))
* update manifest and configs [skip ci] ([5ef6ebe](https://github.com/rigerc/ha-apps/commit/5ef6ebe18c2737cca6d7e61101bea282181f4aaa))
* update manifest and configs [skip ci] ([812a6a6](https://github.com/rigerc/ha-apps/commit/812a6a6417f46a3da0d0dace2476721611053697))
* update manifest and configs [skip ci] ([e3bf456](https://github.com/rigerc/ha-apps/commit/e3bf456441f506fb4d995e71d1120160beb3e471))
* update manifest and configs [skip ci] ([f96f596](https://github.com/rigerc/ha-apps/commit/f96f596821b5e9538d56c336782f7c5f62a7bca0))
* update manifest and configs [skip ci] ([4db8fb9](https://github.com/rigerc/ha-apps/commit/4db8fb96ce5e300b8d2327f4274acaf05923c3ae))
* update manifest and configs [skip ci] ([a2288df](https://github.com/rigerc/ha-apps/commit/a2288dfb46340d48a51217c687765c220bf432cd))
* update manifest and configs [skip ci] ([39baa8f](https://github.com/rigerc/ha-apps/commit/39baa8fe44bcd26160bb6294956fb5f9dd94ddc8))

## [1.3.0](https://github.com/rigerc/ha-apps/compare/kapowarr-1.2.0...kapowarr-1.3.0) (2026-02-11)


### ✨ Features

* **kapowarr:** initial release of Kapowarr add-on with documentation, Dockerfile, and configuration ([84dcfb9](https://github.com/rigerc/ha-apps/commit/84dcfb9dd23097b3e1037f7dcbd8cf02f14fec99))


### 🐛 Bug Fixes

* **builder:** improve image detection and error handling in healthcheck step ([993cda5](https://github.com/rigerc/ha-apps/commit/993cda562bbc8a39914cf7fa80463b6df35cedbd))
* **config:** comment out ingress_port in configuration ([e55b9d9](https://github.com/rigerc/ha-apps/commit/e55b9d9891cefb9802afdcf116d6eb067ab657bc))
* **Dockerfile:** add build dependencies and fixes ([c8385d2](https://github.com/rigerc/ha-apps/commit/c8385d294f86cf7fa38e2f2f8c5454260eb65625))
* **Dockerfile:** combine cargo and pip install into single RUN command ([72a9525](https://github.com/rigerc/ha-apps/commit/72a95251a9e92141d92dd8bb23c97343c638db01))
* **Dockerfile:** fix tag case with upstream ([d9ecf81](https://github.com/rigerc/ha-apps/commit/d9ecf81c732ad94dae6d5813dd90fac58eb1c854))
* fix manifest ([e6aa8e2](https://github.com/rigerc/ha-apps/commit/e6aa8e2a7c1d0ae37befb247301e92f1bba78c95))
* make shell scripts executable ([afcd9e0](https://github.com/rigerc/ha-apps/commit/afcd9e0c648c198fb5a7d58eb249fd20dab90f10))
* make shell scripts executable [skip ci] ([438c6f1](https://github.com/rigerc/ha-apps/commit/438c6f1d81ef153182f0c3dc04880a8038f89bec))
* **nginx:** add daemon off to nginx config ([82e0935](https://github.com/rigerc/ha-apps/commit/82e0935258e52122ab307a79c0f8fcd057a7cb7c))
* update ingress port to 9919 ([89bf029](https://github.com/rigerc/ha-apps/commit/89bf029e407fbe4db3ea9367c8eeaddf80d58eb6))


### 🧰 Maintenance

* fixes ([0e71dfe](https://github.com/rigerc/ha-apps/commit/0e71dfef2163857c618be72b7aa54713f1e050cd))
* **repo:** 🚀 Release  kapowarr 1.1.0 ([#28](https://github.com/rigerc/ha-apps/issues/28)) ([98c3df9](https://github.com/rigerc/ha-apps/commit/98c3df9ceaf1ca35d1c29d92ebf06b4af2ac4c9e))
* **repo:** 🚀 Release  kapowarr 1.1.1 ([#29](https://github.com/rigerc/ha-apps/issues/29)) ([81f2298](https://github.com/rigerc/ha-apps/commit/81f22989ff4ba8326803104f34ead73d563585b8))
* **repo:** 🚀 Release  kapowarr 1.1.2 ([#30](https://github.com/rigerc/ha-apps/issues/30)) ([146efea](https://github.com/rigerc/ha-apps/commit/146efeadcc9be5ca3a04b4e887210c2a5627bc7c))
* **repo:** 🚀 Release  kapowarr 1.1.3 ([#31](https://github.com/rigerc/ha-apps/issues/31)) ([4ad5173](https://github.com/rigerc/ha-apps/commit/4ad51738bf9722248b89a8f0a80ba86642060ac5))
* **repo:** 🚀 Release  kapowarr 1.3.0 ([#32](https://github.com/rigerc/ha-apps/issues/32)) ([f6033fa](https://github.com/rigerc/ha-apps/commit/f6033fa0f22fb7d8f4dee694b37354dc0c12c684))
* **repo:** test ([90154a6](https://github.com/rigerc/ha-apps/commit/90154a6b3d1076e7b54c7ab5d9fe95aa17bc9756))
* stuff ([2514c7b](https://github.com/rigerc/ha-apps/commit/2514c7b76f5799fc713aa71ddbaea5a5ec903797))
* stuff ([919bb61](https://github.com/rigerc/ha-apps/commit/919bb619f6422fb08286a85beae663293ce07ddc))
* update manifest and configs ([5d3d1d4](https://github.com/rigerc/ha-apps/commit/5d3d1d4ab9311e9be4bad839691cd0942eb927e5))
* update manifest and configs ([8c26da1](https://github.com/rigerc/ha-apps/commit/8c26da1c9c4ba39eceb6b1ce01ee06edf78f1ba7))
* update manifest and configs [skip ci] ([5ef6ebe](https://github.com/rigerc/ha-apps/commit/5ef6ebe18c2737cca6d7e61101bea282181f4aaa))
* update manifest and configs [skip ci] ([812a6a6](https://github.com/rigerc/ha-apps/commit/812a6a6417f46a3da0d0dace2476721611053697))
* update manifest and configs [skip ci] ([e3bf456](https://github.com/rigerc/ha-apps/commit/e3bf456441f506fb4d995e71d1120160beb3e471))
* update manifest and configs [skip ci] ([f96f596](https://github.com/rigerc/ha-apps/commit/f96f596821b5e9538d56c336782f7c5f62a7bca0))
* update manifest and configs [skip ci] ([4db8fb9](https://github.com/rigerc/ha-apps/commit/4db8fb96ce5e300b8d2327f4274acaf05923c3ae))
* update manifest and configs [skip ci] ([a2288df](https://github.com/rigerc/ha-apps/commit/a2288dfb46340d48a51217c687765c220bf432cd))
* update manifest and configs [skip ci] ([39baa8f](https://github.com/rigerc/ha-apps/commit/39baa8fe44bcd26160bb6294956fb5f9dd94ddc8))

## [1.3.0](https://github.com/rigerc/ha-apps/compare/kapowarr-1.2.5...kapowarr-1.3.0) (2026-02-11)


### ✨ Features

* **kapowarr:** initial release of Kapowarr add-on with documentation, Dockerfile, and configuration ([84dcfb9](https://github.com/rigerc/ha-apps/commit/84dcfb9dd23097b3e1037f7dcbd8cf02f14fec99))


### 🐛 Bug Fixes

* **builder:** improve image detection and error handling in healthcheck step ([993cda5](https://github.com/rigerc/ha-apps/commit/993cda562bbc8a39914cf7fa80463b6df35cedbd))
* **config:** comment out ingress_port in configuration ([e55b9d9](https://github.com/rigerc/ha-apps/commit/e55b9d9891cefb9802afdcf116d6eb067ab657bc))
* **Dockerfile:** add build dependencies and fixes ([c8385d2](https://github.com/rigerc/ha-apps/commit/c8385d294f86cf7fa38e2f2f8c5454260eb65625))
* **Dockerfile:** combine cargo and pip install into single RUN command ([72a9525](https://github.com/rigerc/ha-apps/commit/72a95251a9e92141d92dd8bb23c97343c638db01))
* **Dockerfile:** fix tag case with upstream ([d9ecf81](https://github.com/rigerc/ha-apps/commit/d9ecf81c732ad94dae6d5813dd90fac58eb1c854))
* make shell scripts executable ([afcd9e0](https://github.com/rigerc/ha-apps/commit/afcd9e0c648c198fb5a7d58eb249fd20dab90f10))
* make shell scripts executable [skip ci] ([438c6f1](https://github.com/rigerc/ha-apps/commit/438c6f1d81ef153182f0c3dc04880a8038f89bec))
* **nginx:** add daemon off to nginx config ([82e0935](https://github.com/rigerc/ha-apps/commit/82e0935258e52122ab307a79c0f8fcd057a7cb7c))
* update ingress port to 9919 ([89bf029](https://github.com/rigerc/ha-apps/commit/89bf029e407fbe4db3ea9367c8eeaddf80d58eb6))


### 🧰 Maintenance

* fixes ([0e71dfe](https://github.com/rigerc/ha-apps/commit/0e71dfef2163857c618be72b7aa54713f1e050cd))
* **repo:** 🚀 Release  kapowarr 1.1.0 ([#28](https://github.com/rigerc/ha-apps/issues/28)) ([98c3df9](https://github.com/rigerc/ha-apps/commit/98c3df9ceaf1ca35d1c29d92ebf06b4af2ac4c9e))
* **repo:** 🚀 Release  kapowarr 1.1.1 ([#29](https://github.com/rigerc/ha-apps/issues/29)) ([81f2298](https://github.com/rigerc/ha-apps/commit/81f22989ff4ba8326803104f34ead73d563585b8))
* **repo:** 🚀 Release  kapowarr 1.1.2 ([#30](https://github.com/rigerc/ha-apps/issues/30)) ([146efea](https://github.com/rigerc/ha-apps/commit/146efeadcc9be5ca3a04b4e887210c2a5627bc7c))
* **repo:** 🚀 Release  kapowarr 1.1.3 ([#31](https://github.com/rigerc/ha-apps/issues/31)) ([4ad5173](https://github.com/rigerc/ha-apps/commit/4ad51738bf9722248b89a8f0a80ba86642060ac5))
* **repo:** test ([90154a6](https://github.com/rigerc/ha-apps/commit/90154a6b3d1076e7b54c7ab5d9fe95aa17bc9756))
* stuff ([2514c7b](https://github.com/rigerc/ha-apps/commit/2514c7b76f5799fc713aa71ddbaea5a5ec903797))
* stuff ([919bb61](https://github.com/rigerc/ha-apps/commit/919bb619f6422fb08286a85beae663293ce07ddc))
* update manifest and configs ([5d3d1d4](https://github.com/rigerc/ha-apps/commit/5d3d1d4ab9311e9be4bad839691cd0942eb927e5))
* update manifest and configs ([8c26da1](https://github.com/rigerc/ha-apps/commit/8c26da1c9c4ba39eceb6b1ce01ee06edf78f1ba7))
* update manifest and configs [skip ci] ([812a6a6](https://github.com/rigerc/ha-apps/commit/812a6a6417f46a3da0d0dace2476721611053697))
* update manifest and configs [skip ci] ([e3bf456](https://github.com/rigerc/ha-apps/commit/e3bf456441f506fb4d995e71d1120160beb3e471))
* update manifest and configs [skip ci] ([f96f596](https://github.com/rigerc/ha-apps/commit/f96f596821b5e9538d56c336782f7c5f62a7bca0))
* update manifest and configs [skip ci] ([4db8fb9](https://github.com/rigerc/ha-apps/commit/4db8fb96ce5e300b8d2327f4274acaf05923c3ae))
* update manifest and configs [skip ci] ([a2288df](https://github.com/rigerc/ha-apps/commit/a2288dfb46340d48a51217c687765c220bf432cd))
* update manifest and configs [skip ci] ([39baa8f](https://github.com/rigerc/ha-apps/commit/39baa8fe44bcd26160bb6294956fb5f9dd94ddc8))
