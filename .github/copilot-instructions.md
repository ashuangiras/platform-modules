# platform-modules — Agent Guidelines

This repository is governed by [platform-compliance](https://github.com/ashuangiras/platform-compliance) at `v3.2.0`.
Repository type: `terraform-module` | Profile: `PROF-TERRAFORM-MODULE-V1`

Read the platform-compliance [copilot-instructions](https://github.com/ashuangiras/platform-compliance/blob/main/.github/copilot-instructions.md) for the full governance chain.

## Repository-specific context

- **Technology contexts:** github, github-actions, terraform
- **Compliance workflow:** `.github/workflows/compliance.yml` — runs on every PR
- **Manifest:** `.compliance-manifest.yaml` — declares profile and contexts
- **Purpose:** Reusable Terraform modules governed by platform-compliance

## Quick reference

```bash
forge validate <file> --compliance-dir /path/to/platform-compliance
forge check all --compliance-dir /path/to/platform-compliance
forge gate merge --compliance-dir /path/to/platform-compliance
```
