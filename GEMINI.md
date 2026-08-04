# CheerCOM — Agent Instructions (mirrors AGENTS.md — edit all three together)

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
