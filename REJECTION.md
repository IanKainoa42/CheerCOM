# Task Rejection

This task has been rejected in accordance with the guidelines set forth in `AGENTS.md` and `CLAUDE.md`.

## Reason for Rejection

The requested task is a recurring, open-ended objective ("Mission: continuously improve the app's realistic human 3D body model and its Center of Mass (CoM) calculation").

As explicitly stated in `AGENTS.md` under the "HARD STOP" section, tasks matching this pattern must be rejected immediately. Specifically, a valid task must contain all of the following, which this task lacks:

1. **A specific failing test name or user-visible defect** (The task provides a general "Baseline Audit" and open-ended "Realism Goals" rather than a specific defect).
2. **A reference to which prior PR attempted this and why it was insufficient** (No prior PRs are referenced).
3. **An acceptance criterion a human can verify in 60 seconds** (The acceptance criteria provided are open-ended and cannot be verified quickly).

Therefore, this PR intentionally contains no code changes to the app itself and only serves to document the rejection of the invalid task.
