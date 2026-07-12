# Agent Learnings & Improvements Ledger

This ledger records meaningful updates to the agent configuration in `platform-modules`. Governed by **AGT-013**: every pull request must add an entry here.

---

## 2026-07-12 — feat(security): P0 security tier — localhost binding + TLS + idempotency

**Change Record:** CHG-20260712-002

- **Localhost binding (P0-2):** added a `bind_address` variable (default `127.0.0.1`) to postgresql, redis, consul, vault, minio, and authentik, wiring it to the `ip=` field of every externally-published container port so services no longer bind `0.0.0.0` by default. Operators opt into wider exposure explicitly.
- **TLS capability (P0-1):** added `tls_enabled` plus certificate-path variables to vault, consul, minio, and authentik, with listener config and cert-volume mounts wired through. postgres/redis TLS is intentionally deferred and documented in their READMEs rather than half-implemented.
- **Scheme-aware outputs:** vault `api_address` / `api_address_internal` and minio `api_endpoint` / `console_url` now emit `https://` when `tls_enabled` is set (previously hardcoded `http://`, which silently broke downstream integrations the moment TLS was turned on).
- **Vault memory 256 → 512 MiB:** raised the `memory_limit_mib` default because 256 MiB OOM-killed Vault on a live staging deploy; added an inline comment explaining the floor.
- **Idempotency (macOS docker provider):** added `lifecycle { ignore_changes = [memory_swap, capabilities] }` to all 7 `docker_container` resources (vault, consul, minio, postgresql, redis, authentik server + worker). Without it the provider reported perpetual diffs on `memory_swap`/`capabilities`, churning/restarting containers every apply and re-sealing Vault.
- **minio TLS healthcheck:** switched the healthcheck to a `CMD-SHELL` that re-points the built-in `local` mc alias to `https://127.0.0.1:9000` with `--insecure` before running `mc ready`; the default alias is `http` and falsely reported "not ready" under TLS.
- **NET-002 remediation (postgres/redis):** pinned the postgresql (5432) and redis (6379) published ports to the byte-literal `ip = "127.0.0.1"` and removed the now-dead `bind_address` variable from both `data/*` modules (variables.tf + README inputs row + prose). The v4.0.3 NET-002 collector is name-scoped to `docker_container` resources matching postgres/postgresql/redis and matches on a literal `127.0.0.1` only — it does not resolve `ip = var.bind_address`, so the parameterized pattern read as non-compliant for these two internal data stores. vault/consul/minio/authentik are out of NET-002 scope and keep their `bind_address` variable unchanged.
- Proven on a live staging deploy: 7/7 containers healthy, TLS terminated, configuration converged and idempotent across repeated applies.

**Rule learned:** On the macOS docker provider, `memory_swap` and `capabilities` are re-computed on every apply, so any long-lived `docker_container` resource MUST `ignore_changes` them or the module is non-idempotent — the churn silently restarts stateful containers and re-seals Vault, which looks like a runtime bug but is really a module-authoring omission. Second: the instant you introduce a `tls_enabled` toggle, every output that emits a URL must become scheme-aware in the same change — a hardcoded `http://` output is a latent break that only surfaces downstream when a consumer follows the address over the wire. Third: the v4.0.3 NET-002 collector is name-scoped to postgres/redis `docker_container` resources and matches a literal `127.0.0.1` only (it does not resolve `var`/locals), so internal data stores that must never be off-host bindable have to use a hardcoded localhost bind rather than a parameterized `bind_address`; the parameterized pattern is fine and stays for vault/consul/minio/authentik, which NET-002 does not inspect.

---

## 2026-07-12 — chore: bump platform-compliance ref v4.0.0 → v4.0.3 (patch)

**Change Record:** CHG-20260712-001

- Bumped the compliance gate from platform-compliance **v4.0.0 → v4.0.3** in `.github/workflows/compliance.yml` in all three spots: the reusable-workflow `uses:` ref, the `platform-compliance-ref` input, and the stale "pinned to v4.0.0" header comment. Also corrected the stale `Compliance ref pinned to: v4.0.0` line in `.github/copilot-instructions.md`. `technology-contexts` was already correct and was left untouched.
- v4.0.3 is a PATCH that (a) makes **SEC-001** (secret scanning) and **SUP-001** (Terraform dependency pinning) genuinely `block` — previously they were silently inert — and (b) fixes a **SUP-001** Terraform false-positive so pinned providers, `git::…?ref=<immutable-tag>` modules, and local `./` modules are correctly recognised as pinned.
- **SUP-001 verified pass**: all 10 `versions.tf` (root + 9 modules) pin `required_version = "~> 1.9"` and every provider uses a `~>` constraint (docker `~> 3.0`, postgresql `~> 1.22`, null `~> 3.0`); the engine reported "All 12 provider(s) and 0 module(s) pinned" — no false-positive under v4.0.3, no fix needed.
- **SEC-001 verified pass**: repo `secret_scanning` and `secret_scanning_push_protection` are both `enabled` (checked via `gh api`); no PATCH needed.
- **SRC-001/002 confirmed** hardened at the branch-protection layer (strict status checks, ≥1 required review, code-owner reviews, `dismiss_stale_reviews=true`).
- Full local merge-gate simulation (PROF-TERRAFORM-MODULE-V1 / merge_gate / contexts `github,github-actions,terraform,agent`) against the v4.0.3 policy bundle exited **0** — every BLOCK control passes; the only non-pass is the pre-existing warn-level IAC-005 (drift detection), which is non-blocking and unrelated to this bump.

**Rule learned:** A "silently inert" control being promoted to `block` in a PATCH release is a real gate-tightening event even when the version delta looks trivial — re-simulate the whole gate with the new bundle rather than assuming a patch is a no-op. When bumping a pinned compliance ref, sweep for the version string in ALL locations (uses ref, ref input, header comments, and doc lines like copilot-instructions.md), not just the two functional spots, so `grep -rn <oldref> .github/` comes back clean (excluding historical ledger entries).

---

## 2026-07-11 — chore: migrate to platform-compliance v4.0.0 (agent-context enforcement)

**Change Record:** CHG-20260711-060

- Bumped the compliance gate from platform-compliance **v3.3.2 → v4.0.0** in `.github/workflows/compliance.yml` (both the reusable-workflow `uses:` ref and `platform-compliance-ref`), and added `agent` to the workflow's `technology-contexts` input so the AGT-001..015 controls run with evidence (the manifest already declares `agent`; a workflow-input mismatch would leave those controls in-scope with no evidence and FAIL the gate).
- v4.0.0 promotes AGT-001..015 to `block` and adds CAT-003 (manifest completeness) + newly enforces SEC-004 (Actions least-privilege) via the profile `inherits` chain.
- Added an explicit `## Safety` section to `.github/copilot-instructions.md` to satisfy AGT-012 robustly (literal `do not` guidance rather than an incidental keyword match).
- Renamed the display `name:` of the compliance-gate and pr-engineer agents to "Module Compliance Gate" / "Module PR Engineer" to avoid cross-repo agent name collisions.
- Added a `.github/hooks/` PreToolUse safety guard (`guard-destructive-ops.json` + executable `scripts/guard-destructive-ops.sh`) to satisfy AGT-008, which v4.0.0 promoted to `block` for `agent`-context repos; the collector's `hooks.guard_ok` was `false` because the hooks directory was absent.
- MinIO module now sets `CI=true` in the container `env` so the RUN-008 512 MiB memory cap doesn't OOM-kill the container before its healthcheck goes ready (P1 review finding).

**Rule learned:** When adopting a MAJOR platform-compliance release, the manifest `technology_contexts` and the CI workflow's `technology-contexts` input must be kept in lock-step — declaring a context in the manifest without feeding it to the reusable workflow puts controls in-scope with zero evidence and hard-fails the gate. Agent instruction files must satisfy AGT-012 with explicit, literal safety language, not incidental keyword hits.

---

## 2026-07-11 — fix: resolve policy failures (SEC-005, LIC-001, SUP-004, IAC-005)

**Change Record:** CHG-20260711-048

- **LIC-001**: Added MIT LICENSE. Libraries and modules should carry an explicit license so consumers know the terms.
- **SEC-005**: Added Semgrep SAST scan (`p/terraform` ruleset). Catches HCL security misconfigurations that tfsec may miss.
- **SUP-004**: Added release workflow with `anchore/sbom-action`. Every tagged release now produces a `sbom.cdx.json` SBOM artifact.
- **IAC-005**: Added daily drift detection workflow. Validates all module directories with `terraform validate` on a daily schedule. A failed validation means a provider schema change or broken reference — the operator must investigate.

**Rule learned:** The same set of baseline fixes (LICENSE, SAST, SBOM, drift-detection) applies to every platform repo. In the future, `forge new repo` should scaffold these from the start — the `forge improvement` backlog should include adding them to the templates for each repo type.

---

## 2026-07-11 — feat: data infrastructure modules (postgresql, redis) + identity module (authentik)

**Change Record:** CHG-20260711-056

- **modules/data/postgresql**: shared PostgreSQL with `cyrilgdn/postgresql` provider for per-service database + role creation. Superuser and per-service credentials output as sensitive map — caller writes to Vault. Default user is never shared with application code.
- **modules/data/redis**: shared Redis 7 with ACL-based per-service user isolation. `users.acl` generated from `acl_users` map and mounted read-only. `default` user always disabled. ACL changes trigger container replacement via `replace_triggered_by`.
- **modules/identity/authentik**: Authentik server + worker. Takes external database_url and redis_url — does not embed its own database. Bootstrap admin credentials written to Vault. `run_as_user` variable follows the pattern established for Vault/Consul macOS compatibility.
- Rule learned: modules that produce sensitive outputs (database credentials, connection strings) must always document that the caller is responsible for writing outputs to Vault immediately. The module should never be responsible for Vault writes — that belongs in the calling integration layer.

---

## 2026-07-11 — fix: optional user + capabilities for macOS Docker Desktop (CHG-20260711-053)

**Change Record:** CHG-20260711-053

- Vault module: `drop_capabilities` (default `["ALL"]`, set `[]` on macOS) and `run_as_user` (default `"100:1000"`, set `""` on macOS). The `drop = ["ALL"]` caused `CAP_SETFCAP: Operation not permitted` on macOS Docker Desktop.
- Consul module: `run_as_user` variable (default `""`). The hashicorp/consul image uses `su-exec` internally — setting explicit user conflicts on macOS with `setgroups: Operation not permitted`.
- Rule learned: security-hardening variables must be exposed. Production posture is the default; staging/macOS overrides come from the calling configuration.
