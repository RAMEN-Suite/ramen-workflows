# Changelog

All notable changes to this project are documented here.

## [0.2.9](https://github.com/RAMEN-Suite/ramen-workflows/compare/v0.2.8...v0.2.9) (2026-11-09)

## [0.2.8](https://github.com/RAMEN-Suite/ramen-workflows/compare/v0.2.7...v0.2.8) (2026-11-07)

### Features

* optionally rebuild container after file sync ([648f5a3](https://github.com/RAMEN-Suite/ramen-workflows/commit/648f5a37defed84d23c2c976973f6500c93b6536))

## [0.2.7](https://github.com/RAMEN-Suite/ramen-workflows/compare/v0.2.6...v0.2.7) (2026-11-07)

### Features

* sync files over ssh ([3ea4122](https://github.com/RAMEN-Suite/ramen-workflows/commit/3ea4122d369a2e63ab46c7c93640b800f73e210c))

## [0.2.6](https://github.com/RAMEN-Suite/ramen-workflows/compare/v0.2.5...v0.2.6) (2026-11-06)

### Bug Fixes

* only release once ([2d300ed](https://github.com/RAMEN-Suite/ramen-workflows/commit/2d300edd30a96dcf59c4c76bc6c6ddfdcb18da3f))

## [0.2.5](https://github.com/RAMEN-Suite/ramen-workflows/compare/v0.2.4...v0.2.5) (2026-11-05)

### Bug Fixes

* write scan summaries only once ([932dea4](https://github.com/RAMEN-Suite/ramen-workflows/commit/932dea4f4dbec14a0eee387b1a4a650426bf64bb))

## [0.2.4](https://github.com/RAMEN-Suite/ramen-workflows/compare/v0.2.3...v0.2.4) (2026-11-02)

### Bug Fixes

* do never fail on vulns; only report ([2f67b06](https://github.com/RAMEN-Suite/ramen-workflows/commit/2f67b06119e6aabbce0b4c3cd390c9097fcf894b))

## [0.2.3](https://github.com/RAMEN-Suite/ramen-workflows/compare/v0.2.2...v0.2.3) (2026-11-02)

### Features

* add ssh deploy ([086cd5f](https://github.com/RAMEN-Suite/ramen-workflows/commit/086cd5f673da0e0e580830ff012457828c8f3fbd))
* container publish, auto-back-merge and promote dev image to staging ([0b4a16a](https://github.com/RAMEN-Suite/ramen-workflows/commit/0b4a16a6f1cec0bcffdae2789b0781bf08208c03))
* release docker apps ([adaa64c](https://github.com/RAMEN-Suite/ramen-workflows/commit/adaa64cb06a2fb70adf1ebb6d87f4580bd77fbcb))

### Bug Fixes

* make sure there are no npm steps inside the release environment ([f127362](https://github.com/RAMEN-Suite/ramen-workflows/commit/f12736251e52be37bd0318a6e3f96a851c752e85))

## [0.2.2](https://github.com/RAMEN-Suite/ramen-workflows/compare/v0.2.1...v0.2.2) (2026-11-01)

### Features

* add container and config lint workflows ([#4](https://github.com/RAMEN-Suite/ramen-workflows/issues/4)) ([f884a55](https://github.com/RAMEN-Suite/ramen-workflows/commit/f884a55d0cc28e23ab9bf6b0dced97c4db52c1b3))

## [0.2.1](https://github.com/RAMEN-Suite/ramen-workflows/compare/v0.2.0...v0.2.1) (2026-10-30)

### Features

* add npm release, publish and pages ([5af4512](https://github.com/RAMEN-Suite/ramen-workflows/commit/5af451269b02701e87d567020e22a58093fe830f))

## [0.2.0](https://github.com/RAMEN-Suite/ramen-workflows/compare/v0.1.2...v0.2.0) (2026-10-30)

### ⚠ BREAKING CHANGES

* split conventional-node into commitlint-node and pr-title-node

### Features

* split conventional-node into commitlint-node and pr-title-node ([a6ebaa1](https://github.com/RAMEN-Suite/ramen-workflows/commit/a6ebaa1abb36d2a3c22d419ec8281b735f736a7f))

## [0.1.2](https://github.com/RAMEN-Suite/ramen-workflows/compare/v0.1.1...v0.1.2) (2026-10-30)

### Bug Fixes

* give skipped conventional jobs their own name ([0d2024d](https://github.com/RAMEN-Suite/ramen-workflows/commit/0d2024d8ac2ee22e83d2ab187f7ef43ac086bf30))

### Documentation

* readme ([ce966c3](https://github.com/RAMEN-Suite/ramen-workflows/commit/ce966c37109aa5462f63a9bfefe78713c15ee444))

## [0.1.1](https://github.com/RAMEN-Suite/ramen-workflows/compare/v0.1.0...v0.1.1) (2026-10-30)

### Features

* add reusable workflows for actions lint, conventional commits, security, supply chain and node CI ([#2](https://github.com/RAMEN-Suite/ramen-workflows/issues/2)) ([d41b93d](https://github.com/RAMEN-Suite/ramen-workflows/commit/d41b93de0535a8648ddb4655ec410d8eb62815be))

## 0.1.0 (2026-10-27)

