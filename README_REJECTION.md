# Rejection: CoM Validation Harness Extension

This PR explicitly rejects the task of adding another test pose or "continuously improving" the body model validation harness.

As detailed in `AGENTS.md` (added in commit `e6934c5` for IAN-484):
1. **HARD STOP:** Creating "Test Pose N" and extending the validation harness without a specific defect is prohibited.
2. Open-ended "Missions" like "continuously improve the app's realistic human 3D body model" violate repository guidelines.
3. Over the last 14 days, 15 near-duplicate PRs were created adding test poses 19 through 30 without any underlying failing assertions or specific targets.

Per instructions in `AGENTS.md`, any task fitting this description must be stopped immediately and a PR opened solely explaining the rejection.

The recurring "Mission" session must be cancelled in the web UI (see IAN-398).
