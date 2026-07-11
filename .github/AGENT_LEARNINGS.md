# Agent Learnings & Improvements Ledger

This ledger records meaningful updates to the agent configuration in `platform-modules`. Governed by **AGT-013**: every pull request must add an entry here.

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
