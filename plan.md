1. **Address Missing `SegmentData` Struct**: Since `CoMValidationHarness` is currently trying to use `SegmentData.standard` from a missing `ModelRigKit` dependency, I will create a `SegmentData` struct internally in `CoMValidationHarness.swift` (or `SharedTypes.swift`) with the correct definitions (matching the tuple list in `COMCalculator`).
2. **Review COMCalculator logic**: Verify if `COMCalculator` is calculating segment masses appropriately based on the 17-segment model using known anthropometric proportions. It currently appears to have the anthropometric values encoded directly inside. I will refactor `COMCalculator` to utilize the new `SegmentData` struct, making the segment definitions shared and robust.
3. **Verify Baseline Audit Tools**:
    *  A fixed "T-pose" baseline and a few known poses exist.
    *  Output CoM (x,y,z) with consistent coordinate space rules exists.
    *  A visible "CoM marker" in 3D view exists.
    *  Documentation in `docs/com_model.md` exists.
4. **Implement Pose Validator warning in `JointLimits.swift`**: Add a `print` or logger call inside `clampAngles` when an out-of-range angle is detected to warn the user, fulfilling "Implement a simple 'pose validator' that warns/clamps out-of-range angles". Wait, `JointLimits.swift` already prints a warning. I will confirm if there's anything else needed for this.
5. **Run tests**: Execute `python3 tests/verify_com_math.py` to ensure it passes.
6. **Pre-commit and Submit**: Call `pre_commit_instructions` tool and submit PR.
