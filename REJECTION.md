# Reject Vague Optimization Task per AGENTS.md

The current task ("Mission: continuously improve the app's realistic human 3D body model and its Center of Mass (CoM) calculation") has been rejected based on the explicit `HARD STOP` directive in `AGENTS.md`.

## Reason for Rejection
The task is an open-ended "Mission" and a "Baseline audit" request that fails all three requirements for a valid CheerCOM task:
1. **No specific failing test name or user-visible defect** is provided.
2. **No reference to prior PRs** attempting this is provided.
3. **No 60-second verifiable acceptance criterion** is provided.

As documented in `AGENTS.md` (Tracked as **IAN-484**), this repo prohibits adding more "Test Pose N" fixtures to the validation harness to satisfy vague-scope objectives without a specific failing assertion driving them.

## Required Operator Action
The operator must cancel the recurring "Mission" session directly at `jules.google.com` (tracked as **IAN-398**) to prevent these daily tasks from being generated. Closing this PR without fixing the root cause will result in another task generation tomorrow.
