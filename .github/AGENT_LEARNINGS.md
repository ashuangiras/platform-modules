# Agent Learnings & Improvements Ledger

This ledger records meaningful updates to the agent configuration in `platform-modules`. Governed by **AGT-013**: every pull request must add an entry here.

---

## 2026-07-11 — fix: resolve policy failures (SEC-005, LIC-001, SUP-004, IAC-005)

**Change Record:** CHG-20260711-048

- **LIC-001**: Added MIT LICENSE. Libraries and modules should carry an explicit license so consumers know the terms.
- **SEC-005**: Added Semgrep SAST scan (`p/terraform` ruleset). Catches HCL security misconfigurations that tfsec may miss.
- **SUP-004**: Added release workflow with `anchore/sbom-action`. Every tagged release now produces a `sbom.cdx.json` SBOM artifact.
- **IAC-005**: Added daily drift detection workflow. Validates all module directories with `terraform validate` on a daily schedule. A failed validation means a provider schema change or broken reference — the operator must investigate.

**Rule learned:** The same set of baseline fixes (LICENSE, SAST, SBOM, drift-detection) applies to every platform repo. In the future, `forge new repo` should scaffold these from the start — the `forge improvement` backlog should include adding them to the templates for each repo type.
