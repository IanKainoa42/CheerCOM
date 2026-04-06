# CheerCOM Reuse Extraction Map

Date: 2026-04-03

## Executive Summary

CheerCOM is no longer the source of truth for the biomechanics core.

Use this rule:
- If a concept already exists in `ModelRigKit`, use `ModelRigKit`.
- Only extract from CheerCOM where the logic has not yet been promoted.
- Do not copy stale local types from CheerCOM back into shared packages.

Highest-value extraction still living in CheerCOM:
1. Stability / base-of-support math
2. Validation harness patterns
3. Pose persistence workflow
4. SceneKit rig utilities
5. Genericized diagnostics and utility UI

## Package Destination Rules

### ModelRigKit
Good home for:
- COM / body analysis math
- pose definitions and joint constraints
- stability analysis math
- validation fixtures and regression checks
- saved pose domain models
- optional SceneKit addon target if desired

### SwiftIanKit
Good home for:
- generic utilities
- generic UI wrappers
- generic storage helpers
- reusable data structures

Not a good home for:
- cheer domain logic
- SceneKit rig logic
- COM math
- branded UI components

### CheerRulesKit
Good home for:
- pure cheer domain rules
- scoring logic
- rubric models
- future body-position domain enums if scoring needs them

Not a good home for:
- SceneKit
- COM math
- rendering
- pose persistence
- visualization logic

## File-by-File Map

### 1) `CheerComCaluculatorApp/CheerComCaluculatorApp/COMCalculator.swift`
Status: DO NOT EXTRACT

Reason:
- This logic has already been extracted and improved in `ModelRigKit/Sources/ModelRigKit/Biomechanics/COMCalculator.swift`.
- The CheerCOM version is older and string-keyed.
- `ModelRigKit` adds typed `Joint` support, body presets, and tests.

Action:
- Treat this file as deprecated local history.
- Do not reuse for future apps.
- If CheerCOM itself is kept alive, migrate it to import `ModelRigKit.COMCalculator` instead.

Destination:
- None. Replace usages with `ModelRigKit`.

### 2) `CheerComCaluculatorApp/CheerComCaluculatorApp/SharedTypes.swift`
Status: PARTIALLY OBSOLETE

Reason:
- Contains local pose/joint-related enums that overlap with extracted `ModelRigKit` types.
- It is stale: local `PoseType` is missing `.lunge` while other CheerCOM files reference it.

Action:
- Do not extract this file as-is.
- Replace pose-related parts with `ModelRigKit.PoseType`, `PoseCategory`, `JointAxis`, etc.
- Keep only app-specific UI enums if still needed.

Destination:
- Pose/domain pieces: already in `ModelRigKit`
- App-only leftovers: keep local to CheerCOM

### 3) `CheerComCaluculatorApp/CheerComCaluculatorApp/Managers/PosePresets.swift`
Status: DO NOT EXTRACT

Reason:
- Already extracted to `ModelRigKit/Sources/ModelRigKit/Poses/PosePresets.swift`.
- Local version is stale and missing `.lunge`.
- Local version uses raw string keys instead of typed `Joint` keys.

Action:
- Do not reuse this file.
- If CheerCOM continues, replace with `ModelRigKit.PosePresets`.

Destination:
- None. Source of truth is `ModelRigKit`.

### 4) `CheerComCaluculatorApp/CheerComCaluculatorApp/Managers/JointLimits.swift`
Status: DO NOT EXTRACT

Reason:
- Already extracted and improved in `ModelRigKit/Sources/ModelRigKit/Poses/JointLimits.swift`.
- `ModelRigKit` version has broader coverage and tests.

Action:
- Replace usages with `ModelRigKit.JointLimits`.

Destination:
- None. Source of truth is `ModelRigKit`.

### 5) `CheerComCaluculatorApp/CheerComCaluculatorApp/Managers/PoseStorageManager.swift`
Status: EXTRACTABLE WITH REFACTOR

What is reusable:
- Save/load/delete pose workflow
- JSON export/import flow
- merge-on-import behavior

What is not ideal:
- hard-coded `UserDefaults`
- tightly coupled singleton pattern
- storage logic mixed with domain concerns
- string-keyed angle payloads instead of a richer typed storage abstraction

Recommended extraction:
- Keep `SavedPose` as the domain model in `ModelRigKit`
- Create a generic storage abstraction, e.g.:
  - `PoseStore`
  - `UserDefaultsPoseStore`
  - `FilePoseStore`
- Add import/export helpers around `[SavedPose]`

Best destination:
- If pose storage is intended for multiple biomechanics apps: `ModelRigKit` addon target or small companion package
- If you want a generic persistence pattern: `SwiftIanKit`

Recommendation:
- Extract behavior, not the singleton file.

### 6) `CheerComCaluculatorApp/CheerComCaluculatorApp/Managers/CoMValidationHarness.swift`
Status: HIGH-VALUE EXTRACT CANDIDATE

What is reusable:
- deterministic pose validation workflow
- baseline pose comparisons
- validation criteria per pose
- structured logging for regression checks

What is not ideal:
- tightly coupled to SceneKit scene manager and visualization manager
- references mixed old/new APIs
- currently exposes migration drift (`.lunge`, `SegmentData`, `JointLimits.constrainedJoints` mismatch)

Recommended extraction:
Split into two layers:
1. Pure validation core
   - pose expectation structs
   - baseline comparison helpers
   - validation result types
2. Optional app/demo harness
   - pose application timing
   - on-screen logs
   - visualization hookups

Best destination:
- Validation core: `ModelRigKit` tests or test-support target
- Demo harness: local app or sample app target

Recommendation:
- Extract the idea immediately.
- Do not extract the file verbatim.

### 7) `CheerComCaluculatorApp/CheerComCaluculatorApp/Managers/CheerCOMSceneManager.swift`
Status: EXTRACTABLE TO A SCENEKIT-SPECIFIC MODULE

What is reusable:
- rig loading
- animation stripping
- bone caching
- joint lookup
- character framing
- body-part coloring pattern

What is not ideal:
- app-specific scene styling mixed in
- uses UIKit view setup directly
- tied to this specific character/scene assumptions

Recommended extraction:
Split into:
1. `RigSceneLoader` / `RigNodeCache`
2. `SceneCharacterFramer`
3. optional `RigDebugStyling`

Best destination:
- New target: `ModelRigKitSceneKit`
- Or new package: `SceneRigKit`

Recommendation:
- Worth extracting if you expect more 3D rig tools.
- Do not dump this into `SwiftIanKit`.

### 8) `CheerComCaluculatorApp/CheerComCaluculatorApp/Managers/VisualizationsManager.swift`
Status: BEST REMAINING EXTRACTION TARGET

What is reusable:
- circular history buffer pattern
- COM trail management
- gravity line rendering logic
- BOS polygon generation
- point-in-polygon stability classification
- margin-to-edge computation
- unstable-direction heuristic

What is not ideal:
- math and rendering are mixed together
- SceneKit nodes are deeply interleaved with pure calculations
- some naming is app-centric

Recommended extraction:
Split into two layers.

Layer A: pure analysis math
- `SupportPolygon`
- `StabilityAnalyzer`
- `StabilityResult`
- point-in-polygon
- edge distance
- instability direction

Layer B: rendering
- `COMTrailRenderer`
- `GravityLineRenderer`
- `BOSRenderer`
- `SegmentHighlightRenderer`

Best destination:
- Layer A: `ModelRigKit`
- Layer B: `ModelRigKitSceneKit` or local app support module

Recommendation:
- This is the first file I’d actually mine next.

### 9) `CheerComCaluculatorApp/CheerComCaluculatorApp/Views/DiagnosticsOverlay.swift`
Status: GENERICIZE THEN EXTRACT

What is reusable:
- live scrolling diagnostics/log console overlay
- closeable instrumentation panel

What is not ideal:
- depends on branded Cheer UI primitives
- currently UIKit-specific and app-branded

Recommended extraction:
Create a neutral component such as:
- `LogConsoleView`
- `DiagnosticsPanelView`

Best destination:
- `SwiftIanKit`

Recommendation:
- Extract only after stripping branding and Cheer-specific naming.

### 10) `CheerComCaluculatorApp/CheerComCaluculatorApp/Views/PoseLibraryPanel.swift`
Status: MIXED / PARTIAL EXTRACTION ONLY

What is reusable:
- UX pattern for grouped preset browsing
- saved pose list UX
- import/export/save/mirror command surface

What is not ideal:
- heavily coupled to app delegates and branded components
- contains stale assumptions around pose type parity
- layout is app-specific

Recommended extraction:
Do not extract the whole view.
Instead extract:
- underlying pose library data source concepts
- maybe a generic preset browser later if reused in 2+ apps

Best destination:
- Mostly local
- storage/data hooks may belong with pose storage abstractions

Recommendation:
- Rebuild from shared data models, don’t reuse this UI directly.

### 11) `CheerComCaluculatorApp/CheerComCaluculatorApp/Views/CheerUI.swift`
Status: POSSIBLY EXTRACTABLE, BUT ONLY AFTER DE-BRANDING

What is reusable:
- button wrapper
- panel container
- gradient backdrop
- segmented control styling
- typography helpers
- color-from-hex helper

What is not ideal:
- explicitly Cheer-branded naming
- hard-coded palette and visual identity
- not yet proven as multi-app design system

Recommended extraction:
If reused across multiple tools, convert into neutral primitives:
- `AppButton`
- `PanelView`
- `GradientBackdropView`
- `AppTheme`
- `SegmentedControlFactory`

Best destination:
- `SwiftIanKit`

Recommendation:
- Only extract after neutralizing names and removing brand assumptions.

### 12) `CheerComCaluculatorApp/CheerComCaluculatorApp/Views/COMInfoPanel.swift`
Status: LOCAL ONLY

Reason:
- Primarily app-specific presentation for COM readouts.

Action:
- Keep local unless a broader analysis dashboard product emerges.

### 13) `CheerComCaluculatorApp/CheerComCaluculatorApp/Views/JointControlPanel.swift`
Status: PARTIAL IDEA REUSE ONLY

What is reusable:
- manual rig manipulation workflow
- joint-axis control UX pattern

What is not ideal:
- specific to this tool’s editing surface

Recommendation:
- Keep local.
- Reuse concepts, not code.

### 14) `CheerComCaluculatorApp/CheerComCaluculatorApp/Views/TransformControlPanel.swift`
Status: PARTIAL IDEA REUSE ONLY

What is reusable:
- transform tweaking workflow for debug tools

Recommendation:
- Keep local unless you build a generic rig editor package.

### 15) `CheerComCaluculatorApp/CheerComCaluculatorApp/SceneViewController.swift`
Status: LOCAL ONLY

Reason:
- Heavy app composition layer.
- Coordinates app lifecycle, panels, scene setup, and interactions.

Action:
- Do not extract as shared code.
- Instead consume shared extracted modules from here.

### 16) `CheerComCaluculatorApp/CheerComCaluculatorApp/CheerCOMApp.swift`
Status: LOCAL ONLY

Reason:
- App entry point.

### 17) `CheerComCaluculatorApp/CheerComCaluculatorApp/COMCalculatorBenchmark.swift`
Status: EXTRACTABLE AS TEST/DEV TOOLING

What is reusable:
- performance benchmarking pattern for COM calculations

Best destination:
- `ModelRigKit` benchmark or perf test support

Recommendation:
- Useful, but secondary priority.

### 18) `tests/verify_com_math.py`
Status: HIGH-VALUE REFERENCE

What is reusable:
- independent verification of mass ratios and fallback logic
- non-UI regression safety for biomechanics math

Best destination:
- Keep as reference or migrate equivalent logic into `ModelRigKit` test coverage

Recommendation:
- Preserve the intent even if implementation moves.

## Concrete Extraction Backlog

### Priority 1
1. Extract pure stability math from `VisualizationsManager.swift`
2. Create `StabilityAnalyzer` + `StabilityResult` in `ModelRigKit`
3. Add tests around BOS inclusion and edge-margin calculations

### Priority 2
1. Refactor `CoMValidationHarness.swift` into pure validation utilities
2. Move regression expectations into `ModelRigKit` tests
3. Keep optional visual harness local

### Priority 3
1. Extract pose persistence abstractions from `PoseStorageManager.swift`
2. Reuse `SavedPose` from `ModelRigKit`
3. Decide whether store implementation lives in `SwiftIanKit` or a ModelRigKit companion target

### Priority 4
1. Extract SceneKit rig helpers from `CheerCOMSceneManager.swift`
2. Build `ModelRigKitSceneKit` or equivalent target

### Priority 5
1. Genericize `DiagnosticsOverlay.swift` and `CheerUI.swift`
2. Move only neutral components into `SwiftIanKit`

## Anti-Extraction List

Do not move these into shared packages as-is:
- `COMCalculator.swift` (local CheerCOM version)
- `SharedTypes.swift` pose types
- `Managers/PosePresets.swift` (local version)
- `Managers/JointLimits.swift` (local version)
- `SceneViewController.swift`
- branded UIKit components under `CheerUI.swift` without renaming/generalizing

## Immediate Recommended Next Step

If continuing from this audit, do this next:
- Extract `StabilityAnalyzer` from `VisualizationsManager.swift` into `ModelRigKit`

That gives the highest-value new shared capability with the least contamination from stale app code.
