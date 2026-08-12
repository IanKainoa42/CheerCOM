# Task Rejection

The requested task has been rejected because it violates the repository's `AGENTS.md` guidelines.

## Reason for Rejection

The task is an open-ended objective starting with "Mission: continuously improve the app's realistic human 3D body model and its Center of Mass (CoM) calculation" and includes a "First Step: Baseline Audit" without providing any specific failing test name or user-visible defect.

According to `AGENTS.md`:
- "If your task is any of the following, stop immediately and open a PR that does nothing except explain the rejection."
- Prohibited task patterns include:
  - "Baseline audit" / "architecture summary" / "deliverables audit" with no named defect.
  - "Continuously improve…" / "Mission:" / any open-ended standing objective.

A valid task for this repository must contain:
1. A specific failing test name or user-visible defect.
2. A reference to which prior PR attempted this and why it was insufficient.
3. An acceptance criterion a human can verify in 60 seconds.

This request contains none of these, and therefore, it is out of scope for this repository. No code changes have been made.