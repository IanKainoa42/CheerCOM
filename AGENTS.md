# CheerCOM — Agent Instructions

## HARD STOP: the CoM Validation Harness test-pose train

**Do NOT add another "Test Pose N" to the validation harness.** As of 2026-08-04 a recurring
Jules session ("Mission: continuously improve the app's realistic human 3D body model & CoM")
has merged **15 near-duplicate PRs in 14 days** — PRs #176 (Jul 21) through #190 (Aug 3), adding
test poses 19 through 30, one per day, with no stated end condition and no target pose count.

Each PR is individually plausible and collectively worthless: they add fixtures to the same
harness without any failing assertion driving them, and no one has reviewed the accumulated
result.

**If your task is any of the following, stop immediately and open a PR that does nothing except
explain the rejection.** An explicit, reviewable refusal is the desired output — do not silently
produce an empty diff, and do not "find something else to improve" instead. (Prior art: the
sibling ScoreBin repo has PRs #92–#95 titled "Reject … Optimization Task per AGENTS.md".)

- "Add Test Pose N" / "Add another test pose" / "extend the validation harness"
- "Baseline audit" / "architecture summary" / "deliverables audit" with no named defect
- "Continuously improve…" / "Mission:" / any open-ended standing objective
- "Optimize", "refactor", "consolidate", "clean up", or "improve" without a failing assertion

## Post-guardrail status (updated 2026-08-27)

This guardrail landed 2026-08-04 16:10 UTC. It was **not immediately effective**: PR #191
("Test Pose 31") was opened 4h45m later and merged the same day — an automated `/sync` pass
verified the diff and a Python mirror build but never checked this file. Reverted in `cd6a649`.
PRs #192–195 (Aug 5–8, plus re-attempts of the same shape closed 2026-08-23: "Baseline Audit &
Validation Harness Expansion", "Add CoM Validation Harness", "Add Test Pose 31 for CoM
Validation") repeated the same violation. **Resolved 2026-08-23: all of #192–195 are now closed
unmerged** — the "remain open, do not merge" warning from 08-20 no longer applies; no action
needed on them.

**Self-reject PRs are ALSO forbidden to merge — this rule was violated 9 times in a row, then
fixed.** Starting with #196 (Aug 10), the recurring session began producing self-rejecting PRs
whose entire diff is a single `REJECTION.md` stub explaining the refusal — that is the correct
*agent* response to a HARD STOP task. But an automated `/sync` merge pass did not distinguish
"clean self-reject stub" from "safe to merge": it merged **#196 through #204 (9 for 9,
Aug 10–20)** anyway, landing `REJECTION.md` on `main` — a repo-root **artifact file prohibited
by global CLAUDE.md's artifact-file rule**. It is still unreverted on `main` as of 2026-08-27
(nobody has removed the file itself — only stopped re-merging it).
**The fix held: #205–#211 (Aug 20–26) were all correctly closed unmerged, zero further
mis-merges.** Treat "9 for 9" as a historical count, not an ongoing streak.
**Never merge a PR whose diff is `REJECTION.md` — close it unmerged instead**, the same
handling as #192–195. `mergeStateStatus: CLEAN` is not authorization here any more than it was
for #191.

**No CI, no build signal:** `ManualCoMValidationTest.swift` — the file this entire PR train
edits — is confirmed **not present in any Xcode target** (0 references in
`CheerComCaluculatorApp.xcodeproj/project.pbxproj`). It has never compiled or run. A green
`gh pr view --json mergeStateStatus` or a passing Python mirror check proves nothing about
these PRs.

**IAN-398 (cancel the recurring "Mission" session) auto-closed itself 2026-08-20 — this is
NOT a real fix, and the underlying session is still unresolved.** Linear's GitHub integration
matched PR #204's branch name (which happened to contain the string "ian-398") and
auto-transitioned the issue to Done. The session was never cancelled at jules.google.com and
kept firing daily through at least #211 (Aug 26 — which was itself just the agent editing its
own `REJECTION.md` template text to sharpen this exact warning, not a new task shape). **This
is blocked on a human action (cancelling the session at jules.google.com) — no prompt or config
change here can fix it.** Do not treat `IAN-398: Done` as evidence this is resolved — verify
directly with `gh pr list --repo IanKainoa42/CheerCOM --state all`.

## What a valid CheerCOM task looks like

A task targeting this repo must contain **all three**:

1. **A specific failing test name or user-visible defect** — e.g. "CoM gravity line renders
   outside the base of support for pose 12; expected within, see `CoMTests.testPose12`".
2. **A reference to which prior PR attempted this and why it was insufficient** — the #176–#190
   range is presumed to have already touched anything harness-related.
3. **An acceptance criterion a human can verify in 60 seconds.**

If your task does not contain all three, it is out of scope for this repo. Reject it.

## Scope limits

- **Max 3 files per PR.** A PR touching more than 3 files will be closed unread.
- **No new test poses without a defect they reproduce.** Fixtures are not progress.
- **Do not restructure `BASELINE_AUDIT.md`** — it is a record, not a work queue. Its presence is
  not an instruction to generate more audits.

## Why this file exists

Tracked as **IAN-484** ("CheerCOM: add Jules vague-scope guardrail"), open since 2026-06-26 and
unresolved for 40 days while the train ran daily. The root cause is a vague-scope recurring
session, which is prohibited by the operator's standing rule:

> Never prompt Jules with "find inefficiencies", "optimize the codebase", or "clean up technical
> debt" without a file-and-function scope. Required format: "Optimize [function] in [file] so
> that [specific measurable condition]."

**This file is only half the fix.** It makes the agent *refuse* the task; it does not stop the
task from being *created*. The recurring "Mission" session must also be cancelled in the Jules
web UI, or this repo will keep generating one rejection PR per day instead of one near-duplicate
PR per day. See IAN-398.
