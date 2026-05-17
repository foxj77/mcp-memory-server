# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A thin packaging project — no application source code. It builds a container image that wraps the upstream `@modelcontextprotocol/server-memory` (stdio) with `supergateway` to expose it as an MCP **Streamable HTTP** endpoint suitable for Kubernetes workloads. The knowledge graph is persisted to `/data/memory.jsonl` on a mounted volume.

The entire runtime is two `npm install -g` packages plus a single `CMD` line — there is no application build step or lint config. Changes are almost always to `Dockerfile`, `chart/`, `examples/*.yaml`, `README.md`, or `tests/smoke-test.sh`.

### Chart layout

```
chart/
├── Chart.yaml              # metadata; version stamped by CI at publish time
├── values.yaml             # all tunable values with inline constraint docs
├── values.schema.json      # JSON Schema — Helm validates values against this on install
└── templates/
    ├── _helpers.tpl        # name/label/image helpers
    ├── deployment.yaml     # replicas hardcoded to 1 — see inline comment for why
    ├── pvc.yaml            # accessMode hardcoded to ReadWriteOnce — see inline comment
    ├── service.yaml
    └── NOTES.txt           # post-install endpoint instructions
```

## Build / run / test

```bash
# Local build + run
docker build -t mcp-memory-server .
docker run -p 3000:3000 -v $(pwd)/data:/data mcp-memory-server

# Smoke test (exercises all 7 MCP tools, verifies responses, then cleans up)
./tests/smoke-test.sh

# Against a remote deployment
MCP_URL=http://mcp-memory-server.my-namespace.svc.cluster.local:3000/mcp ./tests/smoke-test.sh
```

Requires `curl` and `jq`. The test is idempotent — safe to re-run against a live graph as it uses `smoke-test/` prefixed entity names and cleans up after itself.

Images are published to `ghcr.io/foxj77/mcp-memory-server` by `.github/workflows/publish.yaml` when a GitHub Release is created. Multi-arch (amd64 + arm64). Manual builds (no release) can be triggered via `workflow_dispatch` and receive `edge` + `sha-` tags only.

**npm package versions** are pinned in both `Dockerfile` (the `RUN npm install -g` line) and `package.json` (for Dependabot). When Dependabot raises a PR bumping a version in `package.json`, the matching version in the Dockerfile must be updated in the same PR before merging.

## Critical configuration constraints

These are non-obvious and have already bitten this project — preserve them when editing `Dockerfile` or example manifests:

- **`MEMORY_FILE_PATH` must be set.** The upstream `@modelcontextprotocol/server-memory` package reads the storage path from this env var only — a positional argv path is silently ignored. Without this var the graph is written to the npm package's `dist/` directory and lost on every pod restart. The `Dockerfile` sets `ENV MEMORY_FILE_PATH=/data/memory.jsonl` as a default; all example manifests set it explicitly. Never remove it.
- **`--stateful` on supergateway is required.** Stateless mode spawns a new stdio child per HTTP request, which breaks MCP's `initialize` → `tools/call` session continuity. Do not remove this flag.
- **Memory limit ≥ 768Mi.** Two Node processes run in the container (supergateway + the memory server child); 512Mi OOMKills under load. `NODE_OPTIONS=--max-old-space-size=256` caps each heap.
- **`imagePullPolicy: Always`** is needed in example manifests because they reference mutable tags (`:latest` / `:main`). Kubernetes' default `IfNotPresent` would serve a stale cached image after a new build.
- **`--outputTransport streamableHttp`** is the transport kagent and most modern MCP clients expect. SSE is legacy.
- **Upstream write atomicity caveat.** `saveGraph()` in the upstream package writes directly to `memory.jsonl` without an atomic rename. An OOM-kill or eviction mid-write can corrupt the file, causing all tool calls to fail with a JSON parse error. Recovery: copy the file from the PVC, strip the bad line, copy back, restart the pod.

## Commit messages — conventional commits (required)

All commits **must** follow the [Conventional Commits](https://www.conventionalcommits.org/) spec. `release-please` reads commit history to determine the next SemVer version and generate the changelog automatically — non-conforming commits are silently ignored by the tool and will not appear in release notes.

| Prefix | Changelog section | Version bump |
|--------|-------------------|-------------|
| `feat:` | Features | minor |
| `fix:` | Bug Fixes | patch |
| `perf:` | Performance | patch |
| `docs:` | Documentation | patch |
| `refactor:` | Refactors | patch |
| `chore:` | (hidden) | patch |
| `feat!:` or `BREAKING CHANGE:` footer | Features | major |

Examples:
```
feat: expose SSE transport as an alternative to streamableHttp
fix: prevent OOMKill by capping NODE_OPTIONS heap at 256Mi
docs: add kubectl port-forward example to smoke test instructions
chore: update supergateway to latest minor release
```

## Release process

Releases are fully automated via `release-please`:

1. Merge conventional commits to `main` → `release-please.yaml` creates or updates a **release PR** that bumps `version.txt` and `CHANGELOG.md`.
2. Merge the release PR → release-please creates a **GitHub Release** with the SemVer tag (e.g. `v1.2.0`) and an auto-generated changelog.
3. The published release event triggers `publish.yaml` → builds multi-arch image and pushes to GHCR with tags `1.2.0`, `1.2`, `1`, `latest`, and `sha-<short>`.

Manual image builds (no release, no version bump) can be triggered via `workflow_dispatch` — these receive `edge` and `sha-` tags only.

## Repo conventions

- Update `CLAUDE.md` and any relevant docs in the same commit as code changes — never leave docs stale.
- When changing the `Dockerfile` CMD or supergateway flags, mirror the change in `README.md` (Architecture / Key configuration notes section) and in any affected `examples/*.yaml`.
- The Kubernetes manifest in `README.md` and `examples/kubernetes-deployment.yaml` must stay in sync.
