# Journal registry landing — 2026-10-18

Owner ruled the landing on 2026-10-18; the journal authoring unit landed
as commit a875e5f3 on main:

- `lua/research/journal.lua`: registry 13 → 29 profiles (16 new +
  requirements for the 10 thin profiles), every limit traced to
  official guidelines with `requirements_source` provenance in-file;
  unstated limits recorded as `not_stated_by_journal`, never invented.
  Partial provenance: ijscr, jove, jbjs. Name-only by design: corr,
  academic_medicine, medical_teacher (guideline sources unreachable;
  gap recorded in-profile). Live file sha256 11605bf0…; byte-identical
  to the authored live tree.
- `tests/research/research_journal_workflow.lua`: two fixture lines
  only — registry count 13 → 29, and the no-requirements adversarial
  fixture moved from cureus (now has real requirements) to corr (no
  requirements by design). No assertion logic changed.

Gates on the landed tree: LuaLS 0 (VIMRUNTIME set), StyLua canonical
clean, luacheck 0/0, workflow suite 208/208, zotero suite 56/56.
Fix driver (scratch, not in-repo) 54/54; authoring driver 210/210.
