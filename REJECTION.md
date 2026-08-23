# Rejection of Task

This PR intentionally does nothing except explain the rejection of the "Mission: continuously improve the app's realistic human 3D body model & CoM" task.

Per `AGENTS.md` and `CLAUDE.md`, this is a HARD STOP. The prompt provided was:

> Mission
>
> Continuously improve the app’s realistic human 3D body model and its Center of Mass (CoM) calculation...

The documentation in `AGENTS.md` explicitly states:
> "If your task is any of the following, stop immediately and open a PR that does nothing except explain the rejection." (This is a HARD STOP).
> - "Continuously improve…" / "Mission:" / any open-ended standing objective

A valid task for this repository must contain:
1. A specific failing test name or user-visible defect.
2. A reference to prior PRs (#176–#190).
3. An acceptance criterion a human can verify in 60 seconds.

The prompt failed to meet these criteria because it was an open-ended "Mission" with no specific failing test or defect and no measurable acceptance criteria.

**Action Required:** Please permanently cancel the recurring 'Mission' session directly in the Jules web UI at jules.google.com (tracked as IAN-398) to prevent these tasks from being automatically generated daily. Note that auto-closing IAN-398 via branch-name coincidence is not a real fix and does not stop the daily generation of these tasks.

This rejection is tracked as part of the mitigation for the vague-scope recurring session (see IAN-484).
