1. **Extend `TransformDirection` Enum**
   - In `SharedTypes.swift`, add `.forward` and `.backward` to `TransformDirection`.
2. **Update `TransformControlPanel` UI**
   - Add "forward" (↗) and "backward" (↙) buttons to the D-pad in `TransformControlPanel.swift`.
   - Update `topRow` to include `forwardButton` on the right side and `backwardButton` on the left side of `bottomRow`. Alternatively, maybe top right for forward, bottom left for backward to reflect depth visually.
3. **Handle New Directions in `SceneViewController`**
   - Update `didTapTransform` to handle `.forward` and `.backward`.
   - Add `transformForward()` and `transformBackward()` methods.
   - For `.position`, `.forward` modifies `z` (e.g. `+= transformStep` or `-=`), `.backward` does the opposite.
   - For `.rotation`, handle `z` axis rotation.
   - For `.scale`, maybe do nothing or apply scale identically.
4. **Complete Pre-Commit Steps**
   - Call `pre_commit_instructions` tool to get required checks.
5. **Submit Change**
   - Commit and submit.
