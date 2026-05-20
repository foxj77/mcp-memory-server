# Changelog

All notable changes to this project will be documented in this file.
Versions are managed automatically by [release-please](https://github.com/googleapis/release-please) from [Conventional Commits](https://www.conventionalcommits.org/).

<!-- next-release-here -->

## [0.2.6](https://github.com/foxj77/mcp-memory-server/compare/v0.2.5...v0.2.6) (2026-05-20)


### Bug Fixes

* invoke installed mcp-server-memory binary directly instead of npx ([3cc788a](https://github.com/foxj77/mcp-memory-server/commit/3cc788a213e46aec4a770a79e580f7b221e39769))

## [0.2.5](https://github.com/foxj77/mcp-memory-server/compare/v0.2.4...v0.2.5) (2026-05-17)


### Documentation

* **examples:** add pattern-advisor kagent agent example ([50cc0f4](https://github.com/foxj77/mcp-memory-server/commit/50cc0f48186509514f1f9317b23abde05b554163))
* **examples:** add resource-health-recorder kagent agent example ([5089344](https://github.com/foxj77/mcp-memory-server/commit/508934487409721c3fbe5452f0fadce8fe0c437c))

## [0.2.4](https://github.com/foxj77/mcp-memory-server/compare/v0.2.3...v0.2.4) (2026-05-17)


### Bug Fixes

* suppress CVE-2026-33671 in Trivy scan with documented rationale ([5cdae92](https://github.com/foxj77/mcp-memory-server/commit/5cdae920189518e30d278a8e092847b5358b64c6))


### Documentation

* make AGENTS.md redirect to CLAUDE.md to eliminate drift risk ([48fdba1](https://github.com/foxj77/mcp-memory-server/commit/48fdba139631a472376f100b28329a63ee201ab0))

## [0.2.3](https://github.com/foxj77/mcp-memory-server/compare/v0.2.2...v0.2.3) (2026-05-17)


### Bug Fixes

* set MEMORY_FILE_PATH env var and remove silently-ignored argv path ([8761772](https://github.com/foxj77/mcp-memory-server/commit/87617721f383a76885e3c15af73119902f020910))

## [0.2.2](https://github.com/foxj77/mcp-memory-server/compare/v0.2.1...v0.2.2) (2026-05-16)


### Documentation

* update README with Helm install, upgrade, uninstall, and kagent wiring ([72b9d7c](https://github.com/foxj77/mcp-memory-server/commit/72b9d7cf63fed4d2ea83d7b04a9098dafa048772))

## [0.2.1](https://github.com/foxj77/mcp-memory-server/compare/v0.2.0...v0.2.1) (2026-05-16)


### Bug Fixes

* allow workflow_dispatch to publish versioned Docker + Helm artifacts ([0909dfc](https://github.com/foxj77/mcp-memory-server/commit/0909dfc7551657a8002c930b5746e7689b110be7))

## [0.2.0](https://github.com/foxj77/mcp-memory-server/compare/v0.1.0...v0.2.0) (2026-05-16)


### Features

* add Helm chart with OCI publish and lint/template CI gates ([50d5a13](https://github.com/foxj77/mcp-memory-server/commit/50d5a13bf3a0af3eaf014ff22d341369700408e8))
* add optional kagent RemoteMCPServer to Helm chart ([669c79c](https://github.com/foxj77/mcp-memory-server/commit/669c79c6fb78fa873ad0d3aa90dd203467e10ed5))
* pin deps, add Dependabot, CI integration test, Trivy scan, and k8s probes ([836c2b0](https://github.com/foxj77/mcp-memory-server/commit/836c2b0b7ec70a0b0ce633a764153db5a0caca21))


### Bug Fixes

* gate publish on smoke test and bump codeql-action to v4 ([86caaa8](https://github.com/foxj77/mcp-memory-server/commit/86caaa8626b89afaae879c2b0c2608d43ec65a0e))
* run integration test on release-please branches to satisfy branch protection ([73222bf](https://github.com/foxj77/mcp-memory-server/commit/73222bffcec27a7771163a1640f34769295421f4))
* upgrade all GitHub Actions to Node.js 24-compatible versions and fix release-please PR permissions ([985937b](https://github.com/foxj77/mcp-memory-server/commit/985937b87eceeaa8e1c9a7ca310281289da11b2b))


### Documentation

* add CHANGELOG.md with v0.1.0 history ([b017af2](https://github.com/foxj77/mcp-memory-server/commit/b017af23109613313d6e798d581e8917b2d1cee6))

## 0.1.0 (2026-05-16)


### Features

* add smoke tests, SemVer releases, and conventional commit workflow ([3a1e5d0](https://github.com/foxj77/mcp-memory-server/commit/3a1e5d090a4fc6a8e4f1629bf6541dab07e30c6d))
* initial release — MCP memory server with knowledge graph persistence over Streamable HTTP ([e158398](https://github.com/foxj77/mcp-memory-server/commit/e158398c3e6a0d4b3b04c32c2e1f97b1d6e2cd2e))


### Bug Fixes

* simplify Mermaid diagrams to fix GitHub rendering ([ecc3e12](https://github.com/foxj77/mcp-memory-server/commit/ecc3e12))


### Documentation

* add motivation paragraph and examples/ folder with deployment manifests ([4499e7d](https://github.com/foxj77/mcp-memory-server/commit/4499e7d))
* replace ASCII diagram with Mermaid ([7dafd7c](https://github.com/foxj77/mcp-memory-server/commit/7dafd7c))
