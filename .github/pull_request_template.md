<!--
  Pull request template for platform-modules.
  Governed by platform-compliance v3.3.2, profile PROF-TERRAFORM-MODULE-V1.
-->

## Summary

<!-- What this change does and why. -->

## Change Record

Change Record: CHG-YYYYMMDD-NNN

<!--
  Replace the placeholder above with the actual change record ID.
  CHG-001 policy requires the format "Change Record: CHG-YYYYMMDD-NNN" on one line.
-->

---

## Agent Readiness & Retro (required — AGT-014)

**Readiness check** — confirm before merge:

- [ ] `terraform fmt -check -recursive .` exits 0
- [ ] `tfsec .` shows no unresolved HIGH/CRITICAL findings
- [ ] `module-reviewer` has reviewed this change
- [ ] Compliance gate CI is green (or BLOCK failures are waived)

**Retrospective** — what did this change teach us, and how did the agents improve?

- <!-- Replace this with at least one substantive bullet describing what was learned.
     AGT-014 gate requires real prose here, not just checkboxes. -->

-
