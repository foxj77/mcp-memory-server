# Changelog

All notable changes to this project will be documented in this file.
Versions are managed automatically by [release-please](https://github.com/googleapis/release-please) from [Conventional Commits](https://www.conventionalcommits.org/).

<!-- next-release-here -->

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
