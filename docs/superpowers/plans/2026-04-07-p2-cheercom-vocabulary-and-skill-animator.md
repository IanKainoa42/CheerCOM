# P2 — CheerCOM Vocabulary + Skill Animator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn CheerCOM into a tumbling-skill training-data generator. Add a user-editable vocabulary manifest (atoms + bodylines + tags), a Skill Animator mode that authors keyframed animations on the existing rigged 3D character, and a batch orbital exporter that produces ~96 JSON files per animation in the schema consumed by Plan 3's Python training pipeline.

**Architecture:** Two phases with a clean seam.
- **Phase A (Tasks 1–7) — Data and export layer.** All of the vocabulary model, animation model, interpolation, camera sampling, keypoint projection, and JSON export. Unit-testable without any UI. Produces a working "author an animation programmatically → export 96 JSON files" pipeline on its own.
- **Phase B (Tasks 8–11) — iPad UI.** Mode switcher, Skill Animator view controller, timeline keyframe bar, bodyline tag picker, Vocabulary Management panel, and a manual end-to-end test authoring a real animation on iPad.

Phase A can ship independently if Phase B stalls — Plan 3 can train on animations authored via test fixtures that call the Phase A exporter directly. Phase B just makes the authoring ergonomic on an iPad.

**Tech Stack:** Swift 5.9, UIKit + SwiftUI hybrid (matches CheerCOM's existing architecture), SceneKit for the 3D viewport, ModelRigKit (KinematicFeatures, PoseAdapter, COMCalculator, Joint, COCOKeypoint), Foundation FileManager for Documents-directory JSON storage.

**Working directory:** `/Users/ianrichardson/Projects/CheerCOM`
**Target:** `CheerComCaluculatorApp/CheerComCaluculatorApp/` (iOS app)
**Build command:** Build in Xcode via `xcodebuild` (details per task)
**Test command:** `swift test --package-path CheerComCaluculatorApp` for SPM tests, Xcode test runner for app target tests

---

## File Structure

All new files for P2. Paths relative to `CheerCOM/CheerComCaluculatorApp/CheerComCaluculatorApp/` unless noted.

### Phase A — Data and export layer

| File | Role |
|---|---|
| `Models/VocabularyManifest.swift` | `VocabularyAtom`, `VocabularyBodyline`, `VocabularyManifest` Codable structs |
| `Managers/VocabularyManager.swift` | Singleton: load, save, add, rename, delete atoms/bodylines; hashes manifest content |
| `Models/BodylineTaggedPose.swift` | Extension wrapper adding `bodyline: String?` to `SavedPose` without breaking existing storage |
| `Managers/PoseStorageManager.swift` | **Modified**: add bodyline field to persisted pose format (backward-compatible) |
| `Models/SkillKeyframe.swift` | `SkillKeyframe` Codable struct: frame index + reference to a saved pose + bodyline |
| `Models/SkillAnimation.swift` | `SkillAnimation` Codable struct: metadata + `[SkillKeyframe]` + atom id |
| `Managers/SkillAnimationStorage.swift` | File-based load/save for animations in `Documents/CheerCOMAnimations/` |
| `Export/OrbitalCameraSampler.swift` | Pure data: generates the 24×4 = 96 `CameraSample` grid |
| `Export/KeyframeInterpolator.swift` | SLERP between keyframes → per-frame joint-angle dictionaries |
| `Export/MixamoCOCOProjector.swift` | Given a rigged SceneKit scene + virtual camera → 17-element `[COCOKeypoint]` |
| `Export/SkillAnimationExporter.swift` | Combines the above + `KinematicFeatures` + JSON writing → 96 files per animation |

### Phase B — iPad UI

| File | Role |
|---|---|
| `ModeContainerViewController.swift` | Parent container VC owning the mode switcher and the two child VCs |
| `SceneViewController.swift` | **Modified**: stays as the Pose Mode child, no breaking changes |
| `Views/SkillAnimatorViewController.swift` | Root VC for Skill Animator mode |
| `Views/SkillTimelineView.swift` | Horizontal scrubber + keyframe diamond track + play/pause |
| `Views/KeyframeBarView.swift` | Reusable keyframe marker component used inside `SkillTimelineView` |
| `Views/BodylineTagPickerViewController.swift` | Modal picker for tagging a saved pose with a bodyline (with "+ New bodyline" inline create) |
| `Views/VocabularyManagementViewController.swift` | Settings-style list: atoms + bodylines, add/rename/delete/edit-tags |

### Tests

| File | Role |
|---|---|
| `CheerComCalculatorAppTests/VocabularyManifestTests.swift` | Encode/decode, add/remove/rename, manifest hash |
| `CheerComCalculatorAppTests/SkillAnimationTests.swift` | Animation serialize/deserialize |
| `CheerComCalculatorAppTests/OrbitalCameraSamplerTests.swift` | Verify 96 samples, correct grid coverage |
| `CheerComCalculatorAppTests/KeyframeInterpolatorTests.swift` | SLERP between two known rotations produces expected intermediate |
| `CheerComCalculatorAppTests/MixamoCOCOProjectorTests.swift` | T-pose projection → 17 keypoints in plausible positions |
| `CheerComCalculatorAppTests/SkillAnimationExporterTests.swift` | Integration: 2-keyframe animation → 96 valid JSON files written |

---

## Phase A — Data and export layer

## Task 1: VocabularyManifest + VocabularyManager

**Files:**
- Create: `CheerComCaluculatorApp/CheerComCaluculatorApp/Models/VocabularyManifest.swift`
- Create: `CheerComCaluculatorApp/CheerComCaluculatorApp/Managers/VocabularyManager.swift`
- Create: `CheerComCaluculatorApp/CheerComCalculatorAppTests/VocabularyManifestTests.swift`

**Rationale:** The vocabulary manifest is the root of the data-driven design. Every downstream stage (animation metadata, export JSON schema, TCN head sizing, composition rules) reads from it. Ship this first so everything else can reference it.

- [ ] **Step 1.1: Create `Models/VocabularyManifest.swift`**

```swift
import Foundation
import CryptoKit

/// Source of truth for the tumbling skill vocabulary. Edited by the user in CheerCOM,
/// consumed by the training pipeline and FlightFilter runtime.
public struct VocabularyManifest: Codable, Equatable {
    public let schemaVersion: Int
    public var atoms: [VocabularyAtom]
    public var bodylines: [VocabularyBodyline]

    public init(
        schemaVersion: Int = 1,
        atoms: [VocabularyAtom] = [],
        bodylines: [VocabularyBodyline] = []
    ) {
        self.schemaVersion = schemaVersion
        self.atoms = atoms
        self.bodylines = bodylines
    }

    /// Stable SHA-256 hash of the manifest's sorted, JSON-encoded content.
    /// Used to verify that a trained model and a manifest match at runtime.
    public func contentHash() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

public struct VocabularyAtom: Codable, Equatable, Identifiable {
    public let id: String                    // "back_handspring", "round_off", ...
    public var displayName: String           // "Back Handspring"
    public var category: String              // "tumbling", "stunts", ...
    public var tags: Set<String>             // ["entry", "hand_support", "back_facing"]
    public let createdAt: Date

    public init(
        id: String,
        displayName: String,
        category: String,
        tags: Set<String> = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.category = category
        self.tags = tags
        self.createdAt = createdAt
    }

    public func hasTag(_ tag: String) -> Bool { tags.contains(tag) }
}

public struct VocabularyBodyline: Codable, Equatable, Identifiable {
    public let id: String                    // "tuck_peak", "layout_peak", ...
    public var displayName: String           // "Tuck Peak"
    public let createdAt: Date

    public init(id: String, displayName: String, createdAt: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
    }
}

extension Set: @retroactive Encodable where Element: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in sorted(by: { String(describing: $0) < String(describing: $1) }) {
            try container.encode(element)
        }
    }
}

extension Set: @retroactive Decodable where Element: Decodable & Hashable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: Set<Element> = []
        while !container.isAtEnd {
            result.insert(try container.decode(Element.self))
        }
        self = result
    }
}
```

- [ ] **Step 1.2: Create `Managers/VocabularyManager.swift`**

```swift
import Foundation

/// Loads and saves VocabularyManifest to a JSON file in the app's Documents directory.
/// Singleton; use `VocabularyManager.shared`.
public final class VocabularyManager {
    public static let shared = VocabularyManager()

    private let manifestFilename = "vocabulary_manifest.json"
    private var cachedManifest: VocabularyManifest?

    private init() {}

    // MARK: - File URL

    private var manifestURL: URL {
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cheerDir = docsURL.appendingPathComponent("CheerCOMAnimations", isDirectory: true)
        if !fm.fileExists(atPath: cheerDir.path) {
            try? fm.createDirectory(at: cheerDir, withIntermediateDirectories: true)
        }
        return cheerDir.appendingPathComponent(manifestFilename)
    }

    // MARK: - Load / Save

    public func load() -> VocabularyManifest {
        if let cached = cachedManifest { return cached }

        let fm = FileManager.default
        guard fm.fileExists(atPath: manifestURL.path),
              let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(VocabularyManifest.self, from: data)
        else {
            let seed = VocabularyManifest()
            cachedManifest = seed
            return seed
        }

        cachedManifest = manifest
        return manifest
    }

    public func save(_ manifest: VocabularyManifest) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        try data.write(to: manifestURL, options: .atomic)
        cachedManifest = manifest
    }

    // MARK: - Mutations

    @discardableResult
    public func addAtom(
        id: String,
        displayName: String,
        category: String = "tumbling",
        tags: Set<String> = []
    ) throws -> VocabularyManifest {
        var manifest = load()
        guard !manifest.atoms.contains(where: { $0.id == id }) else {
            throw VocabularyError.atomAlreadyExists(id: id)
        }
        manifest.atoms.append(VocabularyAtom(
            id: id, displayName: displayName, category: category, tags: tags
        ))
        try save(manifest)
        return manifest
    }

    @discardableResult
    public func addBodyline(id: String, displayName: String) throws -> VocabularyManifest {
        var manifest = load()
        guard !manifest.bodylines.contains(where: { $0.id == id }) else {
            throw VocabularyError.bodylineAlreadyExists(id: id)
        }
        manifest.bodylines.append(VocabularyBodyline(id: id, displayName: displayName))
        try save(manifest)
        return manifest
    }

    @discardableResult
    public func removeAtom(id: String) throws -> VocabularyManifest {
        var manifest = load()
        manifest.atoms.removeAll { $0.id == id }
        try save(manifest)
        return manifest
    }

    @discardableResult
    public func removeBodyline(id: String) throws -> VocabularyManifest {
        var manifest = load()
        manifest.bodylines.removeAll { $0.id == id }
        try save(manifest)
        return manifest
    }

    // Test-only: reset the in-memory cache and delete the on-disk manifest.
    public func _resetForTesting() {
        cachedManifest = nil
        try? FileManager.default.removeItem(at: manifestURL)
    }
}

public enum VocabularyError: Error, Equatable {
    case atomAlreadyExists(id: String)
    case bodylineAlreadyExists(id: String)
}
```

- [ ] **Step 1.3: Create `CheerComCalculatorAppTests/VocabularyManifestTests.swift`**

```swift
import XCTest
@testable import CheerComCalculatorApp

final class VocabularyManifestTests: XCTestCase {

    override func setUp() {
        super.setUp()
        VocabularyManager.shared._resetForTesting()
    }

    override func tearDown() {
        VocabularyManager.shared._resetForTesting()
        super.tearDown()
    }

    func test_load_returns_empty_manifest_when_no_file_exists() {
        let manifest = VocabularyManager.shared.load()
        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertTrue(manifest.atoms.isEmpty)
        XCTAssertTrue(manifest.bodylines.isEmpty)
    }

    func test_addAtom_persists_atom_and_reload_returns_it() throws {
        try VocabularyManager.shared.addAtom(
            id: "back_handspring",
            displayName: "Back Handspring",
            category: "tumbling",
            tags: ["hand_support", "back_facing"]
        )
        let manifest = VocabularyManager.shared.load()
        XCTAssertEqual(manifest.atoms.count, 1)
        XCTAssertEqual(manifest.atoms[0].id, "back_handspring")
        XCTAssertEqual(manifest.atoms[0].displayName, "Back Handspring")
        XCTAssertTrue(manifest.atoms[0].hasTag("hand_support"))
        XCTAssertTrue(manifest.atoms[0].hasTag("back_facing"))
    }

    func test_addAtom_rejects_duplicates() throws {
        try VocabularyManager.shared.addAtom(id: "x", displayName: "X")
        XCTAssertThrowsError(try VocabularyManager.shared.addAtom(id: "x", displayName: "X"))
    }

    func test_removeAtom_deletes_matching_atom() throws {
        try VocabularyManager.shared.addAtom(id: "a", displayName: "A")
        try VocabularyManager.shared.addAtom(id: "b", displayName: "B")
        try VocabularyManager.shared.removeAtom(id: "a")
        let manifest = VocabularyManager.shared.load()
        XCTAssertEqual(manifest.atoms.map { $0.id }, ["b"])
    }

    func test_addBodyline_persists_and_loads() throws {
        try VocabularyManager.shared.addBodyline(id: "tuck_peak", displayName: "Tuck Peak")
        let manifest = VocabularyManager.shared.load()
        XCTAssertEqual(manifest.bodylines.count, 1)
        XCTAssertEqual(manifest.bodylines[0].id, "tuck_peak")
    }

    func test_contentHash_is_stable_for_identical_manifests() {
        let a = VocabularyManifest(atoms: [
            VocabularyAtom(id: "x", displayName: "X", category: "tumbling",
                          tags: ["a", "b"], createdAt: Date(timeIntervalSince1970: 0))
        ])
        let b = VocabularyManifest(atoms: [
            VocabularyAtom(id: "x", displayName: "X", category: "tumbling",
                          tags: ["b", "a"], createdAt: Date(timeIntervalSince1970: 0))
        ])
        XCTAssertEqual(a.contentHash(), b.contentHash(),
                       "Hash should be order-independent for tag sets")
    }

    func test_contentHash_changes_when_manifest_changes() {
        let a = VocabularyManifest(atoms: [
            VocabularyAtom(id: "x", displayName: "X", category: "tumbling",
                          createdAt: Date(timeIntervalSince1970: 0))
        ])
        let b = VocabularyManifest(atoms: [
            VocabularyAtom(id: "y", displayName: "Y", category: "tumbling",
                          createdAt: Date(timeIntervalSince1970: 0))
        ])
        XCTAssertNotEqual(a.contentHash(), b.contentHash())
    }
}
```

- [ ] **Step 1.4: Build and test**

Open the Xcode project (`CheerComCaluculatorApp.xcodeproj`), add the three new files to the `CheerComCalculatorApp` target (source files to main target, test file to test target). Then run:

```bash
cd /Users/ianrichardson/Projects/CheerCOM && xcodebuild test \
  -project CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj \
  -scheme CheerComCaluculatorApp \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  -only-testing:CheerComCalculatorAppTests/VocabularyManifestTests 2>&1 | tail -30
```

Expected: 6 tests passing. If no iPad simulator exists, create one via `xcrun simctl create "iPad test" "iPad (10th generation)"`.

- [ ] **Step 1.5: Commit**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && git add CheerComCaluculatorApp/CheerComCaluculatorApp/Models/VocabularyManifest.swift CheerComCaluculatorApp/CheerComCaluculatorApp/Managers/VocabularyManager.swift CheerComCaluculatorApp/CheerComCalculatorAppTests/VocabularyManifestTests.swift CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj/project.pbxproj && git commit -m "feat(vocab): add VocabularyManifest + VocabularyManager

User-editable source of truth for atoms, bodylines, and tags.
File-backed in Documents/CheerCOMAnimations/vocabulary_manifest.json.
Singleton manager with add/remove/load/save. Content hash is stable
and order-independent for tag sets — used at runtime to verify
trained model/manifest compatibility.

6 unit tests covering load, add, remove, duplicate rejection,
and hash stability.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Extend pose storage with bodyline field

**Files:**
- Modify: `CheerComCaluculatorApp/CheerComCaluculatorApp/Managers/PoseStorageManager.swift`
- Create: `CheerComCaluculatorApp/CheerComCaluculatorApp/Models/BodylineTaggedPose.swift`
- Create: `CheerComCalculatorAppTests/PoseStorageBodylineTests.swift`

**Rationale:** The Pose Library stores `SavedPose` in UserDefaults. To support bodyline tagging without breaking existing storage, wrap `SavedPose` with an associated bodyline ID that lives in a parallel UserDefaults key. This is simpler than schema-migrating the `SavedPose` itself (which lives in ModelRigKit and is shared with FlightFilter).

- [ ] **Step 2.1: Create `Models/BodylineTaggedPose.swift`**

```swift
import Foundation
import ModelRigKit

/// Pairs a SavedPose with an optional bodyline tag referencing an entry in
/// VocabularyManifest.bodylines. Bodyline tags are stored in a sidecar
/// UserDefaults dictionary so SavedPose itself (in ModelRigKit) stays unchanged.
public struct BodylineTaggedPose {
    public let pose: SavedPose
    public let bodylineId: String?

    public init(pose: SavedPose, bodylineId: String?) {
        self.pose = pose
        self.bodylineId = bodylineId
    }
}
```

- [ ] **Step 2.2: Modify `Managers/PoseStorageManager.swift` to add bodyline methods**

Add these methods to the existing `PoseStorageManager` class (leaving all existing methods intact):

```swift
    // MARK: - Bodyline Tagging

    private let bodylineTagsKey = "saved_pose_bodylines"

    /// Loads the pose-id → bodyline-id map from sidecar storage.
    private func loadBodylineTags() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: bodylineTagsKey),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return map
    }

    /// Persists the pose-id → bodyline-id map.
    private func persistBodylineTags(_ map: [String: String]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: bodylineTagsKey)
    }

    /// Tags a pose with a bodyline id. Nil id removes any existing tag.
    public func setBodyline(poseId: UUID, bodylineId: String?) {
        var map = loadBodylineTags()
        if let bodylineId = bodylineId {
            map[poseId.uuidString] = bodylineId
        } else {
            map.removeValue(forKey: poseId.uuidString)
        }
        persistBodylineTags(map)
    }

    public func bodyline(for poseId: UUID) -> String? {
        return loadBodylineTags()[poseId.uuidString]
    }

    /// Returns all saved poses paired with their bodyline tags.
    public func loadPosesWithBodylines() -> [BodylineTaggedPose] {
        let poses = loadPoses()
        let tags = loadBodylineTags()
        return poses.map { pose in
            BodylineTaggedPose(pose: pose, bodylineId: tags[pose.id.uuidString])
        }
    }

    /// Test-only: clear all bodyline tags.
    public func _resetBodylineTagsForTesting() {
        UserDefaults.standard.removeObject(forKey: bodylineTagsKey)
    }
```

- [ ] **Step 2.3: Create `CheerComCalculatorAppTests/PoseStorageBodylineTests.swift`**

```swift
import XCTest
import ModelRigKit
@testable import CheerComCalculatorApp

final class PoseStorageBodylineTests: XCTestCase {

    override func setUp() {
        super.setUp()
        PoseStorageManager.shared._resetBodylineTagsForTesting()
    }

    override func tearDown() {
        PoseStorageManager.shared._resetBodylineTagsForTesting()
        super.tearDown()
    }

    func test_bodyline_is_nil_by_default_for_untagged_pose() {
        let id = UUID()
        XCTAssertNil(PoseStorageManager.shared.bodyline(for: id))
    }

    func test_setBodyline_persists_and_retrieves_tag() {
        let id = UUID()
        PoseStorageManager.shared.setBodyline(poseId: id, bodylineId: "tuck_peak")
        XCTAssertEqual(PoseStorageManager.shared.bodyline(for: id), "tuck_peak")
    }

    func test_setBodyline_with_nil_removes_tag() {
        let id = UUID()
        PoseStorageManager.shared.setBodyline(poseId: id, bodylineId: "layout_peak")
        PoseStorageManager.shared.setBodyline(poseId: id, bodylineId: nil)
        XCTAssertNil(PoseStorageManager.shared.bodyline(for: id))
    }

    func test_loadPosesWithBodylines_returns_paired_data() {
        let id1 = UUID()
        let id2 = UUID()
        // Seed two poses using the existing API
        PoseStorageManager.shared.savePose(name: "P1", jointPositions: [:])
        PoseStorageManager.shared.savePose(name: "P2", jointPositions: [:])
        let poses = PoseStorageManager.shared.loadPoses()
        guard poses.count >= 2 else {
            XCTFail("Expected 2 poses")
            return
        }
        PoseStorageManager.shared.setBodyline(poseId: poses[0].id, bodylineId: "arch")
        // poses[1] gets no bodyline

        let tagged = PoseStorageManager.shared.loadPosesWithBodylines()
        let first = tagged.first { $0.pose.id == poses[0].id }
        let second = tagged.first { $0.pose.id == poses[1].id }
        XCTAssertEqual(first?.bodylineId, "arch")
        XCTAssertNil(second?.bodylineId)

        // Cleanup
        PoseStorageManager.shared.deletePose(id: poses[0].id)
        PoseStorageManager.shared.deletePose(id: poses[1].id)
    }
}
```

- [ ] **Step 2.4: Build and test**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && xcodebuild test \
  -project CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj \
  -scheme CheerComCaluculatorApp \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  -only-testing:CheerComCalculatorAppTests/PoseStorageBodylineTests 2>&1 | tail -20
```

Expected: 4 tests passing.

- [ ] **Step 2.5: Commit**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && git add CheerComCaluculatorApp/CheerComCaluculatorApp/Models/BodylineTaggedPose.swift CheerComCaluculatorApp/CheerComCaluculatorApp/Managers/PoseStorageManager.swift CheerComCaluculatorApp/CheerComCalculatorAppTests/PoseStorageBodylineTests.swift CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj/project.pbxproj && git commit -m "feat(vocab): tag saved poses with bodyline ids

Adds a sidecar UserDefaults dictionary (saved_pose_bodylines) keyed
by pose UUID that stores an optional bodyline id referencing
VocabularyManifest.bodylines. Keeps ModelRigKit's SavedPose struct
unchanged so FlightFilter's storage contract stays stable.

New public PoseStorageManager API: setBodyline/bodyline/
loadPosesWithBodylines. Backward compatible with existing saved
poses (they just return nil for bodyline).

4 unit tests covering default nil, set/get round trip, nil-to-clear,
and paired load.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: SkillAnimation data models + file storage

**Files:**
- Create: `CheerComCaluculatorApp/CheerComCaluculatorApp/Models/SkillKeyframe.swift`
- Create: `CheerComCaluculatorApp/CheerComCaluculatorApp/Models/SkillAnimation.swift`
- Create: `CheerComCaluculatorApp/CheerComCaluculatorApp/Managers/SkillAnimationStorage.swift`
- Create: `CheerComCalculatorAppTests/SkillAnimationTests.swift`

**Rationale:** Animations are stored as keyframe lists (not baked frame sequences) so they can be re-edited. Each keyframe references a `SavedPose` by UUID and holds a frame offset. The full animation metadata includes skill atom id, fps, num_frames, and character info.

- [ ] **Step 3.1: Create `Models/SkillKeyframe.swift`**

```swift
import Foundation

/// A single keyframe in a skill animation timeline: a reference to a saved pose
/// + the frame index at which that pose should appear.
public struct SkillKeyframe: Codable, Equatable, Identifiable {
    public var id: UUID
    public var poseId: UUID               // refers to a SavedPose in PoseStorageManager
    public var frameIndex: Int            // timeline position, 0-based
    public var bodylineId: String?        // optional override (usually propagated from pose)

    public init(
        id: UUID = UUID(),
        poseId: UUID,
        frameIndex: Int,
        bodylineId: String? = nil
    ) {
        self.id = id
        self.poseId = poseId
        self.frameIndex = frameIndex
        self.bodylineId = bodylineId
    }
}
```

- [ ] **Step 3.2: Create `Models/SkillAnimation.swift`**

```swift
import Foundation

/// A complete skill animation: atom id, fps, character metadata, and an ordered
/// list of keyframes. Exported from CheerCOM and consumed by the training pipeline.
public struct SkillAnimation: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String               // user-facing name, e.g. "BHS v1"
    public var atomId: String             // from VocabularyManifest.atoms
    public var category: String           // from the atom's category
    public var notes: String
    public var fps: Int
    public var numFrames: Int
    public var characterRig: String       // e.g. "mixamo"
    public var characterHeightM: Double
    public var characterProportionsPreset: String
    public var keyframes: [SkillKeyframe]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        atomId: String,
        category: String = "tumbling",
        notes: String = "",
        fps: Int = 30,
        numFrames: Int = 25,
        characterRig: String = "mixamo",
        characterHeightM: Double = 1.65,
        characterProportionsPreset: String = "average_adult_female",
        keyframes: [SkillKeyframe] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.atomId = atomId
        self.category = category
        self.notes = notes
        self.fps = fps
        self.numFrames = numFrames
        self.characterRig = characterRig
        self.characterHeightM = characterHeightM
        self.characterProportionsPreset = characterProportionsPreset
        self.keyframes = keyframes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var sortedKeyframes: [SkillKeyframe] {
        keyframes.sorted(by: { $0.frameIndex < $1.frameIndex })
    }
}
```

- [ ] **Step 3.3: Create `Managers/SkillAnimationStorage.swift`**

```swift
import Foundation

/// File-based storage for SkillAnimations. Stores one JSON file per animation
/// in Documents/CheerCOMAnimations/<animation_id>.anim.json. Separate from
/// UserDefaults-based SavedPose storage so animations can grow large and sync
/// via iCloud Drive.
public final class SkillAnimationStorage {
    public static let shared = SkillAnimationStorage()

    private init() {}

    // MARK: - Directory

    private var animationsDirectory: URL {
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cheerDir = docsURL.appendingPathComponent("CheerCOMAnimations", isDirectory: true)
        if !fm.fileExists(atPath: cheerDir.path) {
            try? fm.createDirectory(at: cheerDir, withIntermediateDirectories: true)
        }
        return cheerDir
    }

    private func fileURL(for id: UUID) -> URL {
        animationsDirectory.appendingPathComponent("\(id.uuidString).anim.json")
    }

    // MARK: - CRUD

    public func save(_ animation: SkillAnimation) throws {
        var updated = animation
        updated.updatedAt = Date()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(updated)
        try data.write(to: fileURL(for: updated.id), options: .atomic)
    }

    public func load(id: UUID) throws -> SkillAnimation {
        let data = try Data(contentsOf: fileURL(for: id))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SkillAnimation.self, from: data)
    }

    public func listAll() -> [SkillAnimation] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: animationsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        let animationFiles = files.filter { $0.lastPathComponent.hasSuffix(".anim.json") }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return animationFiles.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(SkillAnimation.self, from: data)
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func delete(id: UUID) throws {
        try FileManager.default.removeItem(at: fileURL(for: id))
    }

    // Test-only: wipe the animations directory.
    public func _resetForTesting() {
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(at: animationsDirectory, includingPropertiesForKeys: nil) {
            for url in files where url.lastPathComponent.hasSuffix(".anim.json") {
                try? fm.removeItem(at: url)
            }
        }
    }
}
```

- [ ] **Step 3.4: Create `CheerComCalculatorAppTests/SkillAnimationTests.swift`**

```swift
import XCTest
@testable import CheerComCalculatorApp

final class SkillAnimationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SkillAnimationStorage.shared._resetForTesting()
    }

    override func tearDown() {
        SkillAnimationStorage.shared._resetForTesting()
        super.tearDown()
    }

    func test_save_and_load_preserves_all_fields() throws {
        let k1 = SkillKeyframe(poseId: UUID(), frameIndex: 0, bodylineId: "stand_ready")
        let k2 = SkillKeyframe(poseId: UUID(), frameIndex: 10, bodylineId: "hands_plant_inverted")
        let k3 = SkillKeyframe(poseId: UUID(), frameIndex: 22, bodylineId: "landing_squat")

        let original = SkillAnimation(
            name: "BHS v1",
            atomId: "back_handspring",
            category: "tumbling",
            notes: "canonical form",
            fps: 30,
            numFrames: 25,
            keyframes: [k1, k2, k3]
        )

        try SkillAnimationStorage.shared.save(original)
        let loaded = try SkillAnimationStorage.shared.load(id: original.id)

        XCTAssertEqual(loaded.id, original.id)
        XCTAssertEqual(loaded.name, "BHS v1")
        XCTAssertEqual(loaded.atomId, "back_handspring")
        XCTAssertEqual(loaded.keyframes.count, 3)
        XCTAssertEqual(loaded.keyframes[0].frameIndex, 0)
        XCTAssertEqual(loaded.keyframes[2].frameIndex, 22)
        XCTAssertEqual(loaded.keyframes[1].bodylineId, "hands_plant_inverted")
    }

    func test_listAll_returns_sorted_by_updatedAt_descending() throws {
        let a = SkillAnimation(name: "A", atomId: "x")
        let b = SkillAnimation(name: "B", atomId: "x")

        try SkillAnimationStorage.shared.save(a)
        Thread.sleep(forTimeInterval: 0.05)
        try SkillAnimationStorage.shared.save(b)

        let all = SkillAnimationStorage.shared.listAll()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[0].name, "B", "Most recently updated should be first")
    }

    func test_delete_removes_animation() throws {
        let a = SkillAnimation(name: "A", atomId: "x")
        try SkillAnimationStorage.shared.save(a)
        try SkillAnimationStorage.shared.delete(id: a.id)
        let all = SkillAnimationStorage.shared.listAll()
        XCTAssertTrue(all.isEmpty)
    }

    func test_sortedKeyframes_orders_by_frameIndex() {
        let anim = SkillAnimation(
            name: "Out of order",
            atomId: "x",
            keyframes: [
                SkillKeyframe(poseId: UUID(), frameIndex: 10),
                SkillKeyframe(poseId: UUID(), frameIndex: 0),
                SkillKeyframe(poseId: UUID(), frameIndex: 5)
            ]
        )
        let sorted = anim.sortedKeyframes
        XCTAssertEqual(sorted.map { $0.frameIndex }, [0, 5, 10])
    }
}
```

- [ ] **Step 3.5: Build and test**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && xcodebuild test \
  -project CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj \
  -scheme CheerComCaluculatorApp \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  -only-testing:CheerComCalculatorAppTests/SkillAnimationTests 2>&1 | tail -20
```

Expected: 4 tests passing.

- [ ] **Step 3.6: Commit**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && git add CheerComCaluculatorApp/CheerComCaluculatorApp/Models/SkillKeyframe.swift CheerComCaluculatorApp/CheerComCaluculatorApp/Models/SkillAnimation.swift CheerComCaluculatorApp/CheerComCaluculatorApp/Managers/SkillAnimationStorage.swift CheerComCalculatorAppTests/SkillAnimationTests.swift CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj/project.pbxproj && git commit -m "feat(animator): add SkillAnimation data model and file storage

SkillAnimation bundles atom id, fps, character metadata, and a list
of SkillKeyframe entries (pose id + frame index + optional bodyline
override). Stored as JSON per animation in Documents/
CheerCOMAnimations/<id>.anim.json for iCloud Drive sync and large-
file tolerance.

SkillAnimationStorage provides save/load/listAll/delete with ISO8601
date handling. 4 unit tests cover round-trip serialization, sort
order, deletion, and keyframe ordering helper.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: OrbitalCameraSampler

**Files:**
- Create: `CheerComCaluculatorApp/CheerComCaluculatorApp/Export/OrbitalCameraSampler.swift`
- Create: `CheerComCalculatorAppTests/OrbitalCameraSamplerTests.swift`

**Rationale:** Pure data generation — computes the 24×4 = 96 (azimuth, elevation) virtual camera samples around the character. No SceneKit yet, just the coordinate grid. Stateless, testable, reusable.

- [ ] **Step 4.1: Create `Export/OrbitalCameraSampler.swift`**

```swift
import Foundation

/// A single virtual camera sample for exporting one animation from one viewpoint.
public struct CameraSample: Equatable {
    public let azimuthDeg: Double      // 0..<360
    public let elevationDeg: Double    // elevation angle from horizontal
    public let distanceM: Double       // distance from character origin
    public let focalLengthMm: Double   // virtual lens
    public let imageWidthPx: Int
    public let imageHeightPx: Int

    public init(
        azimuthDeg: Double,
        elevationDeg: Double,
        distanceM: Double,
        focalLengthMm: Double = 35.0,
        imageWidthPx: Int = 1920,
        imageHeightPx: Int = 1080
    ) {
        self.azimuthDeg = azimuthDeg
        self.elevationDeg = elevationDeg
        self.distanceM = distanceM
        self.focalLengthMm = focalLengthMm
        self.imageWidthPx = imageWidthPx
        self.imageHeightPx = imageHeightPx
    }
}

/// Generates the systematic 24×4 = 96 camera sample grid described in the
/// tumbling skill classification design spec (Section 3 / 6).
public enum OrbitalCameraSampler {

    public static let azimuthStepDeg: Double = 15.0           // 0, 15, 30, ..., 345 → 24 values
    public static let elevationAnglesDeg: [Double] = [-10.0, 0.0, 10.0, 20.0]  // 4 values
    public static let baseDistanceM: Double = 5.0
    public static let distanceJitterRatio: Double = 0.10      // ±10%

    /// Generate the full 96-sample grid. Deterministic given the seed.
    public static func standardGrid(seed: UInt64 = 0) -> [CameraSample] {
        var samples: [CameraSample] = []
        var rng = SeededRandom(seed: seed)

        var azimuth = 0.0
        while azimuth < 360.0 {
            for elevation in elevationAnglesDeg {
                let jitter = rng.nextDouble(in: -distanceJitterRatio...distanceJitterRatio)
                let distance = baseDistanceM * (1.0 + jitter)
                samples.append(CameraSample(
                    azimuthDeg: azimuth,
                    elevationDeg: elevation,
                    distanceM: distance
                ))
            }
            azimuth += azimuthStepDeg
        }

        return samples
    }
}

/// Minimal seeded PRNG (xorshift) for reproducible jitter.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEADBEEFCAFEBABE : seed
    }

    mutating func nextUInt64() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        let normalized = Double(nextUInt64() & 0xFFFFFFFF) / Double(UInt32.max)
        return range.lowerBound + normalized * (range.upperBound - range.lowerBound)
    }
}
```

- [ ] **Step 4.2: Create `CheerComCalculatorAppTests/OrbitalCameraSamplerTests.swift`**

```swift
import XCTest
@testable import CheerComCalculatorApp

final class OrbitalCameraSamplerTests: XCTestCase {

    func test_standardGrid_produces_exactly_96_samples() {
        let samples = OrbitalCameraSampler.standardGrid()
        XCTAssertEqual(samples.count, 96)
    }

    func test_standardGrid_covers_all_24_azimuths() {
        let samples = OrbitalCameraSampler.standardGrid()
        let azimuths = Set(samples.map { Int($0.azimuthDeg) })
        XCTAssertEqual(azimuths.count, 24)
        XCTAssertTrue(azimuths.contains(0))
        XCTAssertTrue(azimuths.contains(15))
        XCTAssertTrue(azimuths.contains(180))
        XCTAssertTrue(azimuths.contains(345))
        XCTAssertFalse(azimuths.contains(360))
    }

    func test_standardGrid_covers_all_4_elevations() {
        let samples = OrbitalCameraSampler.standardGrid()
        let elevations = Set(samples.map { $0.elevationDeg })
        XCTAssertEqual(elevations, Set([-10.0, 0.0, 10.0, 20.0]))
    }

    func test_standardGrid_is_deterministic_for_same_seed() {
        let a = OrbitalCameraSampler.standardGrid(seed: 42)
        let b = OrbitalCameraSampler.standardGrid(seed: 42)
        XCTAssertEqual(a, b, "Same seed should produce identical grid")
    }

    func test_standardGrid_distance_jitter_stays_within_10_percent() {
        let samples = OrbitalCameraSampler.standardGrid()
        for sample in samples {
            XCTAssertGreaterThanOrEqual(sample.distanceM, 5.0 * 0.90)
            XCTAssertLessThanOrEqual(sample.distanceM, 5.0 * 1.10)
        }
    }
}
```

- [ ] **Step 4.3: Build and test**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && xcodebuild test \
  -project CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj \
  -scheme CheerComCaluculatorApp \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  -only-testing:CheerComCalculatorAppTests/OrbitalCameraSamplerTests 2>&1 | tail -20
```

Expected: 5 tests passing.

- [ ] **Step 4.4: Commit**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && git add CheerComCaluculatorApp/CheerComCaluculatorApp/Export/OrbitalCameraSampler.swift CheerComCalculatorAppTests/OrbitalCameraSamplerTests.swift CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj/project.pbxproj && git commit -m "feat(export): add OrbitalCameraSampler for 96-sample grid

Generates a deterministic 24 azimuth x 4 elevation = 96 virtual
camera sample grid around a character, with +/-10% distance jitter
sourced from a seeded xorshift PRNG. Matches the camera strategy
in the tumbling skill classification design spec.

5 unit tests verify the 96-sample count, coverage of all 24
azimuths and all 4 elevations, seed determinism, and distance
jitter bounds.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: KeyframeInterpolator (SLERP)

**Files:**
- Create: `CheerComCaluculatorApp/CheerComCaluculatorApp/Export/KeyframeInterpolator.swift`
- Create: `CheerComCalculatorAppTests/KeyframeInterpolatorTests.swift`

**Rationale:** Given a list of pose keyframes at specific frame indices, produce a per-frame dictionary of joint euler angles by SLERP-interpolating between keyframe pairs. This is used at export time to render 25–45 dense frames from maybe 5 authored keyframes.

- [ ] **Step 5.1: Create `Export/KeyframeInterpolator.swift`**

```swift
import Foundation
import SceneKit
import ModelRigKit

/// Interpolates joint euler angles between skill keyframes using SLERP on quaternions.
///
/// Input: a list of (frameIndex, jointAngles dictionary) tuples from keyframes
///        with their resolved pose data.
/// Output: for any frame in [0, numFrames), a dictionary of interpolated joint angles.
public struct KeyframeInterpolator {

    /// A resolved keyframe: frame index + joint angles dictionary (bone name → euler SCNVector3 in radians).
    public struct ResolvedKeyframe {
        public let frameIndex: Int
        public let jointAngles: [String: SCNVector3]

        public init(frameIndex: Int, jointAngles: [String: SCNVector3]) {
            self.frameIndex = frameIndex
            self.jointAngles = jointAngles
        }
    }

    public let keyframes: [ResolvedKeyframe]     // sorted ascending by frameIndex
    public let numFrames: Int

    public init(keyframes: [ResolvedKeyframe], numFrames: Int) {
        self.keyframes = keyframes.sorted { $0.frameIndex < $1.frameIndex }
        self.numFrames = numFrames
    }

    /// Returns interpolated joint angles at a given frame index, clamped to the
    /// keyframe range at the edges and SLERPed between keyframe pairs in the middle.
    public func angles(atFrame frame: Int) -> [String: SCNVector3] {
        guard !keyframes.isEmpty else { return [:] }

        // Before the first keyframe: hold the first keyframe's angles
        if frame <= keyframes.first!.frameIndex {
            return keyframes.first!.jointAngles
        }
        // After the last keyframe: hold the last keyframe's angles
        if frame >= keyframes.last!.frameIndex {
            return keyframes.last!.jointAngles
        }

        // Find the keyframe pair bracketing this frame
        var prev = keyframes.first!
        var next = keyframes.last!
        for i in 0..<(keyframes.count - 1) {
            if keyframes[i].frameIndex <= frame && frame <= keyframes[i + 1].frameIndex {
                prev = keyframes[i]
                next = keyframes[i + 1]
                break
            }
        }

        let span = Double(next.frameIndex - prev.frameIndex)
        let t = span > 0 ? Double(frame - prev.frameIndex) / span : 0.0

        return interpolate(from: prev.jointAngles, to: next.jointAngles, t: t)
    }

    /// SLERP per joint between two angle dictionaries. Joints present in only one
    /// dictionary are held constant from the side that has them.
    private func interpolate(
        from: [String: SCNVector3],
        to: [String: SCNVector3],
        t: Double
    ) -> [String: SCNVector3] {
        var result: [String: SCNVector3] = [:]
        let allKeys = Set(from.keys).union(to.keys)
        for key in allKeys {
            if let a = from[key], let b = to[key] {
                result[key] = slerpEulerAngles(a, b, t: Float(t))
            } else if let a = from[key] {
                result[key] = a
            } else if let b = to[key] {
                result[key] = b
            }
        }
        return result
    }

    /// SLERPs between two sets of euler angles by converting to quaternions,
    /// spherically interpolating, and converting back.
    private func slerpEulerAngles(
        _ a: SCNVector3,
        _ b: SCNVector3,
        t: Float
    ) -> SCNVector3 {
        let qa = quaternionFromEuler(a)
        let qb = quaternionFromEuler(b)
        let qslerp = slerp(qa, qb, t: t)
        return eulerFromQuaternion(qslerp)
    }

    // MARK: - Quaternion helpers

    private func quaternionFromEuler(_ euler: SCNVector3) -> simd_quatf {
        let halfX = Float(euler.x) * 0.5
        let halfY = Float(euler.y) * 0.5
        let halfZ = Float(euler.z) * 0.5

        let qx = simd_quatf(angle: halfX * 2, axis: SIMD3<Float>(1, 0, 0))
        let qy = simd_quatf(angle: halfY * 2, axis: SIMD3<Float>(0, 1, 0))
        let qz = simd_quatf(angle: halfZ * 2, axis: SIMD3<Float>(0, 0, 1))
        return qy * qx * qz  // YXZ order, matches SceneKit's default euler convention
    }

    private func eulerFromQuaternion(_ q: simd_quatf) -> SCNVector3 {
        let ysqr = q.imag.y * q.imag.y
        let t0 = 2.0 * (q.real * q.imag.x + q.imag.y * q.imag.z)
        let t1 = 1.0 - 2.0 * (q.imag.x * q.imag.x + ysqr)
        let x = atan2(t0, t1)

        var t2 = 2.0 * (q.real * q.imag.y - q.imag.z * q.imag.x)
        t2 = max(-1.0, min(1.0, t2))
        let y = asin(t2)

        let t3 = 2.0 * (q.real * q.imag.z + q.imag.x * q.imag.y)
        let t4 = 1.0 - 2.0 * (ysqr + q.imag.z * q.imag.z)
        let z = atan2(t3, t4)

        #if os(macOS)
        return SCNVector3(CGFloat(x), CGFloat(y), CGFloat(z))
        #else
        return SCNVector3(x, y, z)
        #endif
    }

    private func slerp(_ a: simd_quatf, _ b: simd_quatf, t: Float) -> simd_quatf {
        return simd_slerp(a, b, t)
    }
}
```

- [ ] **Step 5.2: Create `CheerComCalculatorAppTests/KeyframeInterpolatorTests.swift`**

```swift
import XCTest
import SceneKit
import simd
@testable import CheerComCalculatorApp

final class KeyframeInterpolatorTests: XCTestCase {

    private func vec(_ x: Float, _ y: Float, _ z: Float) -> SCNVector3 {
        #if os(macOS)
        SCNVector3(CGFloat(x), CGFloat(y), CGFloat(z))
        #else
        SCNVector3(x, y, z)
        #endif
    }

    func test_holds_first_keyframe_before_its_frame() {
        let kfs = [
            KeyframeInterpolator.ResolvedKeyframe(
                frameIndex: 10,
                jointAngles: ["joint": vec(0.5, 0, 0)]
            )
        ]
        let interp = KeyframeInterpolator(keyframes: kfs, numFrames: 20)
        let result = interp.angles(atFrame: 0)
        XCTAssertEqual(Float(result["joint"]!.x), 0.5, accuracy: 1e-5)
    }

    func test_holds_last_keyframe_after_its_frame() {
        let kfs = [
            KeyframeInterpolator.ResolvedKeyframe(
                frameIndex: 5,
                jointAngles: ["joint": vec(1.0, 0, 0)]
            )
        ]
        let interp = KeyframeInterpolator(keyframes: kfs, numFrames: 20)
        let result = interp.angles(atFrame: 19)
        XCTAssertEqual(Float(result["joint"]!.x), 1.0, accuracy: 1e-5)
    }

    func test_interpolates_between_two_keyframes_at_midpoint() {
        let kfs = [
            KeyframeInterpolator.ResolvedKeyframe(
                frameIndex: 0,
                jointAngles: ["joint": vec(0, 0, 0)]
            ),
            KeyframeInterpolator.ResolvedKeyframe(
                frameIndex: 10,
                jointAngles: ["joint": vec(Float.pi / 2, 0, 0)]
            )
        ]
        let interp = KeyframeInterpolator(keyframes: kfs, numFrames: 20)
        let mid = interp.angles(atFrame: 5)
        // Midpoint of 0 and π/2 should be approximately π/4
        XCTAssertEqual(Float(mid["joint"]!.x), Float.pi / 4, accuracy: 0.05)
    }

    func test_returns_empty_when_no_keyframes() {
        let interp = KeyframeInterpolator(keyframes: [], numFrames: 10)
        XCTAssertTrue(interp.angles(atFrame: 0).isEmpty)
    }

    func test_joints_present_in_only_one_keyframe_hold_their_value() {
        let kfs = [
            KeyframeInterpolator.ResolvedKeyframe(
                frameIndex: 0,
                jointAngles: ["a": vec(1, 0, 0)]
            ),
            KeyframeInterpolator.ResolvedKeyframe(
                frameIndex: 10,
                jointAngles: ["b": vec(0, 1, 0)]
            )
        ]
        let interp = KeyframeInterpolator(keyframes: kfs, numFrames: 20)
        let mid = interp.angles(atFrame: 5)
        XCTAssertEqual(Float(mid["a"]!.x), 1.0, accuracy: 1e-5)
        XCTAssertEqual(Float(mid["b"]!.y), 1.0, accuracy: 1e-5)
    }
}
```

- [ ] **Step 5.3: Build and test**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && xcodebuild test \
  -project CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj \
  -scheme CheerComCaluculatorApp \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  -only-testing:CheerComCalculatorAppTests/KeyframeInterpolatorTests 2>&1 | tail -20
```

Expected: 5 tests passing.

- [ ] **Step 5.4: Commit**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && git add CheerComCaluculatorApp/CheerComCaluculatorApp/Export/KeyframeInterpolator.swift CheerComCalculatorAppTests/KeyframeInterpolatorTests.swift CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj/project.pbxproj && git commit -m "feat(export): add KeyframeInterpolator with SLERP

Given a list of resolved keyframes (frame index + joint angles)
and a target frame count, returns interpolated joint euler angles
at any frame. Uses SLERP on quaternions for smooth rotation
blending. Clamps at edges (holds first keyframe before its frame,
last keyframe after).

5 unit tests cover edge clamping, midpoint interpolation, empty
keyframe list, and joints present in only one keyframe.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: MixamoCOCOProjector

**Files:**
- Create: `CheerComCaluculatorApp/CheerComCaluculatorApp/Export/MixamoCOCOProjector.swift`
- Create: `CheerComCalculatorAppTests/MixamoCOCOProjectorTests.swift`

**Rationale:** Given the rigged SceneKit character at a specific pose, a virtual camera, and a render target size, produce a 17-element `[COCOKeypoint]` array in normalized [0, 1] image coordinates. This is the piece that converts 3D scene state into the 2D format the TCN consumes.

- [ ] **Step 6.1: Create `Export/MixamoCOCOProjector.swift`**

```swift
import Foundation
import SceneKit
import ModelRigKit

/// Projects a rigged Mixamo character's joint world positions to 2D COCO keypoint
/// coordinates from a virtual camera's viewpoint. Output: 17 COCOKeypoints in
/// normalized [0, 1] image coordinates, in COCO order.
///
/// Face keypoints (nose, eyes, ears) are all approximated from the head bone
/// position — the nose keypoint gets the head bone exactly, and eyes/ears are
/// fixed small pixel offsets. This is intentional: real YOLO face keypoints
/// cluster tightly, and face points don't drive tumbling classification.
public struct MixamoCOCOProjector {

    /// Mapping from each COCO keypoint slot to the Mixamo bone name that drives it.
    public static let boneMapping: [(COCOKeypointIndex, String)] = [
        (.nose,          "mixamorig_Head"),
        (.leftEye,       "mixamorig_Head"),  // fudged from head; see note
        (.rightEye,      "mixamorig_Head"),
        (.leftEar,       "mixamorig_Head"),
        (.rightEar,      "mixamorig_Head"),
        (.leftShoulder,  "mixamorig_LeftArm"),
        (.rightShoulder, "mixamorig_RightArm"),
        (.leftElbow,     "mixamorig_LeftForeArm"),
        (.rightElbow,    "mixamorig_RightForeArm"),
        (.leftWrist,     "mixamorig_LeftHand"),
        (.rightWrist,    "mixamorig_RightHand"),
        (.leftHip,       "mixamorig_LeftUpLeg"),
        (.rightHip,      "mixamorig_RightUpLeg"),
        (.leftKnee,      "mixamorig_LeftLeg"),
        (.rightKnee,     "mixamorig_RightLeg"),
        (.leftAnkle,     "mixamorig_LeftFoot"),
        (.rightAnkle,    "mixamorig_RightFoot")
    ]

    /// Extract 17 COCO keypoints from the rigged character using the given virtual camera.
    /// - Parameters:
    ///   - boneNodes: the character's bone nodes, keyed by bone name (as in
    ///     `CheerCOMSceneManager.cachedBoneNodes`).
    ///   - camera: the SCNCamera node positioned and oriented for this sample.
    ///   - sceneView: the SCNView used to run `projectPoint`.
    /// - Returns: 17 COCOKeypoints in COCO order, each in normalized [0, 1] image space.
    public static func project(
        boneNodes: [String: SCNNode],
        camera cameraNode: SCNNode,
        sceneView: SCNView
    ) -> [COCOKeypoint] {
        var result: [COCOKeypoint] = Array(
            repeating: COCOKeypoint(x: 0, y: 0, confidence: 0),
            count: 17
        )

        let originalPoint = sceneView.pointOfView
        sceneView.pointOfView = cameraNode
        defer { sceneView.pointOfView = originalPoint }

        // Image dimensions: use the sceneView bounds for projection, then normalize.
        let bounds = sceneView.bounds
        let width = Float(bounds.width == 0 ? 1920 : bounds.width)
        let height = Float(bounds.height == 0 ? 1080 : bounds.height)

        for (cocoIndex, boneName) in boneMapping {
            guard let boneNode = boneNodes[boneName] else {
                result[cocoIndex.rawValue] = COCOKeypoint(x: 0, y: 0, confidence: 0)
                continue
            }

            let worldPos = boneNode.presentation.worldPosition
            let projected = sceneView.projectPoint(worldPos)

            let normX = Float(projected.x) / width
            let normY = Float(projected.y) / height

            result[cocoIndex.rawValue] = COCOKeypoint(
                x: normX,
                y: normY,
                confidence: 1.0
            )
        }

        return result
    }

    /// Compute the normalized bounding box from a list of COCO keypoints.
    /// Returns (xMin, yMin, xMax, yMax) in [0, 1].
    public static func boundingBox(from keypoints: [COCOKeypoint]) -> (Double, Double, Double, Double) {
        let valid = keypoints.filter { $0.confidence > 0 }
        guard !valid.isEmpty else { return (0, 0, 0, 0) }

        let xs = valid.map { Double($0.x) }
        let ys = valid.map { Double($0.y) }
        return (xs.min()!, ys.min()!, xs.max()!, ys.max()!)
    }
}
```

- [ ] **Step 6.2: Create `CheerComCalculatorAppTests/MixamoCOCOProjectorTests.swift`**

```swift
import XCTest
import SceneKit
import ModelRigKit
@testable import CheerComCalculatorApp

final class MixamoCOCOProjectorTests: XCTestCase {

    func test_boneMapping_has_17_entries() {
        XCTAssertEqual(MixamoCOCOProjector.boneMapping.count, 17)
    }

    func test_boneMapping_covers_all_COCOKeypointIndex_values() {
        let mappedIndices = Set(MixamoCOCOProjector.boneMapping.map { $0.0 })
        let allIndices = Set(COCOKeypointIndex.allCases)
        XCTAssertEqual(mappedIndices, allIndices,
                       "All 17 COCO keypoints must be mapped to a bone")
    }

    func test_boundingBox_zero_for_empty_keypoints() {
        let empty = Array(repeating: COCOKeypoint(x: 0, y: 0, confidence: 0), count: 17)
        let (xmin, ymin, xmax, ymax) = MixamoCOCOProjector.boundingBox(from: empty)
        XCTAssertEqual(xmin, 0)
        XCTAssertEqual(ymin, 0)
        XCTAssertEqual(xmax, 0)
        XCTAssertEqual(ymax, 0)
    }

    func test_boundingBox_spans_min_and_max() {
        var kps: [COCOKeypoint] = Array(
            repeating: COCOKeypoint(x: 0.5, y: 0.5, confidence: 1.0),
            count: 17
        )
        kps[0] = COCOKeypoint(x: 0.1, y: 0.2, confidence: 1.0)
        kps[16] = COCOKeypoint(x: 0.9, y: 0.95, confidence: 1.0)
        let (xmin, ymin, xmax, ymax) = MixamoCOCOProjector.boundingBox(from: kps)
        XCTAssertEqual(xmin, 0.1, accuracy: 1e-6)
        XCTAssertEqual(ymin, 0.2, accuracy: 1e-6)
        XCTAssertEqual(xmax, 0.9, accuracy: 1e-6)
        XCTAssertEqual(ymax, 0.95, accuracy: 1e-6)
    }

    func test_boundingBox_ignores_zero_confidence_points() {
        var kps = Array(repeating: COCOKeypoint(x: 0.5, y: 0.5, confidence: 1.0), count: 17)
        kps[0] = COCOKeypoint(x: 0.01, y: 0.01, confidence: 0.0) // outlier, should be ignored
        let (xmin, ymin, _, _) = MixamoCOCOProjector.boundingBox(from: kps)
        XCTAssertGreaterThan(xmin, 0.01)
        XCTAssertGreaterThan(ymin, 0.01)
    }
}
```

Note: a full end-to-end projection test (scene → camera → keypoints in plausible positions) requires loading the character.dae asset and is done in Task 7 (exporter integration test). These unit tests cover the parts that don't need a loaded scene.

- [ ] **Step 6.3: Build and test**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && xcodebuild test \
  -project CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj \
  -scheme CheerComCaluculatorApp \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  -only-testing:CheerComCalculatorAppTests/MixamoCOCOProjectorTests 2>&1 | tail -20
```

Expected: 5 tests passing.

- [ ] **Step 6.4: Commit**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && git add CheerComCaluculatorApp/CheerComCaluculatorApp/Export/MixamoCOCOProjector.swift CheerComCalculatorAppTests/MixamoCOCOProjectorTests.swift CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj/project.pbxproj && git commit -m "feat(export): add MixamoCOCOProjector

Given a rigged SceneKit character's bone nodes + a virtual camera
SCNNode + a SCNView, projects each of the 17 COCO keypoints from
the mapped Mixamo bone's world position to 2D screen space and
normalizes to [0, 1] image coordinates.

Face keypoints (nose/eyes/ears) all share the head bone position —
intentional approximation since real YOLO face keypoints cluster
tightly and face points don't drive tumbling classification.

5 unit tests cover the bone mapping completeness (all 17 COCO
indices mapped), bounding box edge cases, and invalid-point filter.
Full scene-projection integration coverage comes in Task 7's
exporter tests.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: SkillAnimationExporter (end-to-end)

**Files:**
- Create: `CheerComCaluculatorApp/CheerComCaluculatorApp/Export/SkillAnimationExporter.swift`
- Create: `CheerComCaluculatorApp/CheerComCaluculatorApp/Export/ExportedKeypointFile.swift`
- Create: `CheerComCalculatorAppTests/SkillAnimationExporterTests.swift`

**Rationale:** Ties Tasks 3–6 together. Given a `SkillAnimation`, the exporter:
1. Resolves each keyframe's pose id → joint angles
2. For each camera sample (96):
   3. For each frame (0..<numFrames):
      - Interpolate joint angles at this frame
      - Apply to the scene's character
      - Run `MixamoCOCOProjector` to get 17 keypoints
      - Compute `KinematicFeatures`
      - Collect into a frame record
   4. Build the full JSON export struct
   5. Write to `training_data/raw/<animation_id>_<camera>_<timestamp>.json`

This is the terminal task of Phase A. After this ships, CheerCOM can author-via-test-fixture and produce real training data files.

- [ ] **Step 7.1: Create `Export/ExportedKeypointFile.swift`**

```swift
import Foundation

/// The exact JSON schema emitted per (animation, camera sample). Matches
/// Section 7 of the tumbling skill classification design spec.
public struct ExportedKeypointFile: Codable {
    public let schemaVersion: Int
    public let source: String
    public let createdAt: Date
    public let animationId: String
    public let fps: Int
    public let numFrames: Int
    public let skill: ExportedSkill
    public let camera: ExportedCamera
    public let character: ExportedCharacter
    public let frames: [ExportedFrame]

    public struct ExportedSkill: Codable {
        public let atom: String
        public let category: String
        public let notes: String
    }

    public struct ExportedCamera: Codable {
        public let azimuthDeg: Double
        public let elevationDeg: Double
        public let distanceM: Double
        public let focalLengthMm: Double
        public let imageWidthPx: Int
        public let imageHeightPx: Int
    }

    public struct ExportedCharacter: Codable {
        public let rig: String
        public let heightM: Double
        public let proportionsPreset: String
    }

    public struct ExportedFrame: Codable {
        public let frame: Int
        public let t: Double
        public let persons: [ExportedPerson]
    }

    public struct ExportedPerson: Codable {
        public let personId: Int
        public let role: String
        public let boundingBoxNorm: [Double]
        public let keypoints: [ExportedKeypoint]
        public let bodyline: String?
        public let derived: ExportedDerived
    }

    public struct ExportedKeypoint: Codable {
        public let name: String
        public let x: Double
        public let y: Double
        public let confidence: Double
    }

    public struct ExportedDerived: Codable {
        public let inversion: Bool
        public let bodyAngleDeg: Double
        public let hipAngleDeg: Double
        public let kneeAngleLeftDeg: Double
        public let kneeAngleRightDeg: Double
        public let comXNorm: Double
        public let comYNorm: Double
        public let comVxNorm: Double
        public let comVyNorm: Double
        public let hipAngularVelocityDps: Double
        public let shoulderHipTwistDeg: Double
        public let groundContact: Bool
    }
}

/// Canonical COCO keypoint names in the order produced by YOLOv8-pose.
public enum COCOKeypointNames {
    public static let ordered: [String] = [
        "nose", "left_eye", "right_eye", "left_ear", "right_ear",
        "left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
        "left_wrist", "right_wrist", "left_hip", "right_hip",
        "left_knee", "right_knee", "left_ankle", "right_ankle"
    ]
}
```

- [ ] **Step 7.2: Create `Export/SkillAnimationExporter.swift`**

```swift
import Foundation
import SceneKit
import ModelRigKit

/// Exports a SkillAnimation to JSON files — one per camera sample in the orbital grid.
///
/// Usage:
/// ```
/// let exporter = SkillAnimationExporter(
///     scene: cheerScene,
///     boneNodes: cheerScene.cachedBoneNodes
/// )
/// let urls = try await exporter.export(
///     animation: myAnimation,
///     posesById: { PoseStorageManager.shared.loadPoses().first { $0.id == $0 } },
///     bodylineForPoseId: { PoseStorageManager.shared.bodyline(for: $0) }
/// )
/// ```
@MainActor
public final class SkillAnimationExporter {

    public enum ExportError: Error {
        case missingPose(id: UUID)
        case noKeyframes
        case sceneSetupFailed
    }

    private let sceneView: SCNView
    private let characterNode: SCNNode
    private let boneNodes: [String: SCNNode]

    public init(sceneView: SCNView, characterNode: SCNNode, boneNodes: [String: SCNNode]) {
        self.sceneView = sceneView
        self.characterNode = characterNode
        self.boneNodes = boneNodes
    }

    // MARK: - Output directory

    public static var exportRootURL: URL {
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let rawDir = docsURL
            .appendingPathComponent("CheerCOMAnimations", isDirectory: true)
            .appendingPathComponent("training_data", isDirectory: true)
            .appendingPathComponent("raw", isDirectory: true)
        if !fm.fileExists(atPath: rawDir.path) {
            try? fm.createDirectory(at: rawDir, withIntermediateDirectories: true)
        }
        return rawDir
    }

    // MARK: - Export entry

    /// Run the export. Returns the URLs of the written JSON files.
    public func export(
        animation: SkillAnimation,
        poseResolver: (UUID) -> [String: SCNVector3]?,
        bodylineForPoseId: (UUID) -> String?
    ) throws -> [URL] {
        guard !animation.keyframes.isEmpty else { throw ExportError.noKeyframes }

        // 1. Resolve keyframes into interpolator input
        let resolved: [KeyframeInterpolator.ResolvedKeyframe] = try animation.sortedKeyframes.map { kf in
            guard let angles = poseResolver(kf.poseId) else {
                throw ExportError.missingPose(id: kf.poseId)
            }
            return KeyframeInterpolator.ResolvedKeyframe(
                frameIndex: kf.frameIndex,
                jointAngles: angles
            )
        }
        let interpolator = KeyframeInterpolator(
            keyframes: resolved,
            numFrames: animation.numFrames
        )

        // 2. Build a map from frame index to bodyline (propagated from nearest keyframe)
        let bodylineByFrame = buildBodylineByFrame(
            keyframes: animation.sortedKeyframes,
            numFrames: animation.numFrames,
            bodylineForPoseId: bodylineForPoseId
        )

        // 3. For each camera sample, render and write JSON
        let cameraSamples = OrbitalCameraSampler.standardGrid()
        var writtenUrls: [URL] = []
        let timestamp = ISO8601DateFormatter().string(from: Date())

        for cameraSample in cameraSamples {
            let frames = renderFrames(
                animation: animation,
                interpolator: interpolator,
                cameraSample: cameraSample,
                bodylineByFrame: bodylineByFrame
            )

            let file = ExportedKeypointFile(
                schemaVersion: 1,
                source: "cheercom_skill_animator",
                createdAt: Date(),
                animationId: "\(animation.atomId)_\(animation.id.uuidString.prefix(8))",
                fps: animation.fps,
                numFrames: animation.numFrames,
                skill: .init(
                    atom: animation.atomId,
                    category: animation.category,
                    notes: animation.notes
                ),
                camera: .init(
                    azimuthDeg: cameraSample.azimuthDeg,
                    elevationDeg: cameraSample.elevationDeg,
                    distanceM: cameraSample.distanceM,
                    focalLengthMm: cameraSample.focalLengthMm,
                    imageWidthPx: cameraSample.imageWidthPx,
                    imageHeightPx: cameraSample.imageHeightPx
                ),
                character: .init(
                    rig: animation.characterRig,
                    heightM: animation.characterHeightM,
                    proportionsPreset: animation.characterProportionsPreset
                ),
                frames: frames
            )

            let filename = String(
                format: "%@_az%03d_el%+03d_%@.json",
                animation.atomId,
                Int(cameraSample.azimuthDeg),
                Int(cameraSample.elevationDeg),
                timestamp
            )
            let url = Self.exportRootURL.appendingPathComponent(filename)
            try writeFile(file, to: url)
            writtenUrls.append(url)
        }

        return writtenUrls
    }

    // MARK: - Per-frame rendering

    private func renderFrames(
        animation: SkillAnimation,
        interpolator: KeyframeInterpolator,
        cameraSample: CameraSample,
        bodylineByFrame: [Int: String?]
    ) -> [ExportedKeypointFile.ExportedFrame] {
        var frames: [ExportedKeypointFile.ExportedFrame] = []
        var previousFeatures: KinematicFeatures? = nil

        // Temporary camera node for this sample
        let cameraNode = makeCameraNode(for: cameraSample)

        for frameIndex in 0..<animation.numFrames {
            // Apply interpolated angles to the character
            let angles = interpolator.angles(atFrame: frameIndex)
            applyAngles(angles, to: boneNodes)

            // Project to COCO keypoints
            let keypoints = MixamoCOCOProjector.project(
                boneNodes: boneNodes,
                camera: cameraNode,
                sceneView: sceneView
            )

            // Derived kinematic features
            let features = KinematicFeatures.compute(
                keypoints: keypoints,
                previous: previousFeatures,
                fps: Double(animation.fps)
            )
            previousFeatures = features

            // Bounding box
            let (xmin, ymin, xmax, ymax) = MixamoCOCOProjector.boundingBox(from: keypoints)

            // Build the frame record
            let person = ExportedKeypointFile.ExportedPerson(
                personId: 0,
                role: "tumbler",
                boundingBoxNorm: [xmin, ymin, xmax, ymax],
                keypoints: zip(keypoints, COCOKeypointNames.ordered).map { kp, name in
                    ExportedKeypointFile.ExportedKeypoint(
                        name: name,
                        x: Double(kp.x),
                        y: Double(kp.y),
                        confidence: Double(kp.confidence)
                    )
                },
                bodyline: bodylineByFrame[frameIndex] ?? nil,
                derived: .init(
                    inversion: features.inversion,
                    bodyAngleDeg: features.bodyAngleDeg,
                    hipAngleDeg: features.hipAngleDeg,
                    kneeAngleLeftDeg: features.kneeAngleLeftDeg,
                    kneeAngleRightDeg: features.kneeAngleRightDeg,
                    comXNorm: features.comXNorm,
                    comYNorm: features.comYNorm,
                    comVxNorm: features.comVxNorm,
                    comVyNorm: features.comVyNorm,
                    hipAngularVelocityDps: features.hipAngularVelocityDps,
                    shoulderHipTwistDeg: features.shoulderHipTwistDeg,
                    groundContact: features.groundContact
                )
            )

            frames.append(ExportedKeypointFile.ExportedFrame(
                frame: frameIndex,
                t: Double(frameIndex) / Double(animation.fps),
                persons: [person]
            ))
        }

        return frames
    }

    // MARK: - Helpers

    private func applyAngles(_ angles: [String: SCNVector3], to boneNodes: [String: SCNNode]) {
        for (boneName, eulerAngles) in angles {
            if let node = boneNodes[boneName] {
                node.eulerAngles = eulerAngles
            }
        }
    }

    private func makeCameraNode(for sample: CameraSample) -> SCNNode {
        // Position the camera at (azimuth, elevation, distance) around the origin,
        // looking at the character root.
        let azRad = sample.azimuthDeg * .pi / 180.0
        let elRad = sample.elevationDeg * .pi / 180.0

        let x = sample.distanceM * cos(elRad) * sin(azRad)
        let y = sample.distanceM * sin(elRad) + 1.0     // raise to head height ~1m
        let z = sample.distanceM * cos(elRad) * cos(azRad)

        let camera = SCNCamera()
        camera.fieldOfView = 60
        let node = SCNNode()
        node.camera = camera
        #if os(macOS)
        node.position = SCNVector3(CGFloat(x), CGFloat(y), CGFloat(z))
        #else
        node.position = SCNVector3(Float(x), Float(y), Float(z))
        #endif
        node.look(at: characterNode.presentation.worldPosition)
        return node
    }

    private func buildBodylineByFrame(
        keyframes: [SkillKeyframe],
        numFrames: Int,
        bodylineForPoseId: (UUID) -> String?
    ) -> [Int: String?] {
        var result: [Int: String?] = [:]
        guard !keyframes.isEmpty else { return result }

        // Build (frameIndex, bodyline) list from keyframes
        let pairs: [(Int, String?)] = keyframes.map { kf in
            (kf.frameIndex, kf.bodylineId ?? bodylineForPoseId(kf.poseId))
        }

        for frame in 0..<numFrames {
            // Find nearest keyframe by frame index
            let nearest = pairs.min { abs($0.0 - frame) < abs($1.0 - frame) }
            result[frame] = nearest?.1 ?? nil
        }
        return result
    }

    private func writeFile(_ file: ExportedKeypointFile, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(file)
        try data.write(to: url, options: .atomic)
    }
}
```

- [ ] **Step 7.3: Create `CheerComCalculatorAppTests/SkillAnimationExporterTests.swift`**

```swift
import XCTest
import SceneKit
import ModelRigKit
@testable import CheerComCalculatorApp

final class SkillAnimationExporterTests: XCTestCase {

    /// Build a minimal SCNScene with three bone nodes so the projector has something to read.
    /// For a full-fidelity scene test, Task 11 exercises the real character.dae asset via
    /// end-to-end manual testing.
    private func makeMinimalScene() -> (SCNView, SCNNode, [String: SCNNode]) {
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        let scene = SCNScene()
        view.scene = scene

        // Character root
        let character = SCNNode()
        character.name = "character"
        scene.rootNode.addChildNode(character)

        // A handful of bones at plausible positions
        let boneNames = [
            "mixamorig_Head", "mixamorig_LeftArm", "mixamorig_RightArm",
            "mixamorig_LeftForeArm", "mixamorig_RightForeArm",
            "mixamorig_LeftHand", "mixamorig_RightHand",
            "mixamorig_LeftUpLeg", "mixamorig_RightUpLeg",
            "mixamorig_LeftLeg", "mixamorig_RightLeg",
            "mixamorig_LeftFoot", "mixamorig_RightFoot"
        ]
        var boneNodes: [String: SCNNode] = [:]
        for (i, name) in boneNames.enumerated() {
            let node = SCNNode()
            node.name = name
            // Spread bones along Y axis to ensure non-zero projected coordinates
            #if os(macOS)
            node.position = SCNVector3(CGFloat(Double(i) * 0.05), CGFloat(1.5 - Double(i) * 0.1), 0)
            #else
            node.position = SCNVector3(Float(i) * 0.05, 1.5 - Float(i) * 0.1, 0)
            #endif
            character.addChildNode(node)
            boneNodes[name] = node
        }

        // Add a light so projection math works (not strictly required but sanity)
        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .ambient
        scene.rootNode.addChildNode(light)

        return (view, character, boneNodes)
    }

    @MainActor
    func test_export_with_empty_keyframes_throws() throws {
        let (view, character, boneNodes) = makeMinimalScene()
        let exporter = SkillAnimationExporter(
            sceneView: view, characterNode: character, boneNodes: boneNodes
        )
        let animation = SkillAnimation(name: "empty", atomId: "x", numFrames: 10, keyframes: [])
        XCTAssertThrowsError(try exporter.export(
            animation: animation,
            poseResolver: { _ in nil },
            bodylineForPoseId: { _ in nil }
        )) { error in
            XCTAssertTrue((error as? SkillAnimationExporter.ExportError) != nil)
        }
    }

    @MainActor
    func test_export_two_keyframe_animation_writes_96_files() throws {
        let (view, character, boneNodes) = makeMinimalScene()
        let exporter = SkillAnimationExporter(
            sceneView: view, characterNode: character, boneNodes: boneNodes
        )

        // Clean up any previous exports for this test
        let exportRoot = SkillAnimationExporter.exportRootURL
        try? FileManager.default.removeItem(at: exportRoot)

        let k1 = SkillKeyframe(poseId: UUID(), frameIndex: 0, bodylineId: "stand_ready")
        let k2 = SkillKeyframe(poseId: UUID(), frameIndex: 10, bodylineId: "landing_squat")
        let animation = SkillAnimation(
            name: "test_bhs",
            atomId: "back_handspring",
            numFrames: 11,
            keyframes: [k1, k2]
        )

        // Stub pose resolver: return empty dict (no bones move)
        let urls = try exporter.export(
            animation: animation,
            poseResolver: { _ in [:] },
            bodylineForPoseId: { _ in nil }
        )

        XCTAssertEqual(urls.count, 96, "Should write one JSON per camera sample")

        // Verify at least one file parses back into the expected schema
        guard let firstUrl = urls.first else {
            XCTFail("No URLs returned")
            return
        }
        let data = try Data(contentsOf: firstUrl)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let file = try decoder.decode(ExportedKeypointFile.self, from: data)
        XCTAssertEqual(file.schemaVersion, 1)
        XCTAssertEqual(file.skill.atom, "back_handspring")
        XCTAssertEqual(file.fps, 30)
        XCTAssertEqual(file.numFrames, 11)
        XCTAssertEqual(file.frames.count, 11)
        XCTAssertEqual(file.frames[0].persons.count, 1)
        XCTAssertEqual(file.frames[0].persons[0].keypoints.count, 17)
        XCTAssertEqual(file.frames[0].persons[0].keypoints[0].name, "nose")
        XCTAssertEqual(file.frames[0].persons[0].role, "tumbler")

        // Cleanup
        try? FileManager.default.removeItem(at: exportRoot)
    }

    @MainActor
    func test_export_missing_pose_throws() throws {
        let (view, character, boneNodes) = makeMinimalScene()
        let exporter = SkillAnimationExporter(
            sceneView: view, characterNode: character, boneNodes: boneNodes
        )
        let k1 = SkillKeyframe(poseId: UUID(), frameIndex: 0)
        let animation = SkillAnimation(
            name: "missing",
            atomId: "x",
            numFrames: 5,
            keyframes: [k1]
        )
        XCTAssertThrowsError(try exporter.export(
            animation: animation,
            poseResolver: { _ in nil },  // always returns nil → missing pose
            bodylineForPoseId: { _ in nil }
        ))
    }
}
```

- [ ] **Step 7.4: Build and test**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && xcodebuild test \
  -project CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj \
  -scheme CheerComCaluculatorApp \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  -only-testing:CheerComCalculatorAppTests/SkillAnimationExporterTests 2>&1 | tail -30
```

Expected: 3 tests passing. If the 96-file test reports fewer files, verify `exportRootURL` can be written to from the simulator sandbox (expand the `try? FileManager.default.createDirectory` paths if needed).

- [ ] **Step 7.5: Commit**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && git add CheerComCaluculatorApp/CheerComCaluculatorApp/Export/ExportedKeypointFile.swift CheerComCaluculatorApp/CheerComCaluculatorApp/Export/SkillAnimationExporter.swift CheerComCalculatorAppTests/SkillAnimationExporterTests.swift CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj/project.pbxproj && git commit -m "feat(export): add SkillAnimationExporter — 96 JSON files per animation

End-to-end exporter that ties together KeyframeInterpolator,
OrbitalCameraSampler, MixamoCOCOProjector, and
ModelRigKit.KinematicFeatures to produce the training data JSON
format consumed by the Python pipeline in Plan 3.

For each of the 96 camera samples (24 azimuths x 4 elevations),
renders every frame of the animation, extracts 17 COCO keypoints
via screen-space projection, computes kinematic features, and
writes a single JSON file per camera sample to
Documents/CheerCOMAnimations/training_data/raw/.

3 unit tests verify error handling for empty keyframes and
missing poses, plus the headline '96 files written, schema
round-trips' integration test using a minimal programmatic scene.

Phase A of P2 complete. A programmatic caller can now author
an animation via test fixtures and produce real training data
without touching the UI.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Phase B — iPad UI

## Task 8: ModeContainerViewController and SkillAnimatorViewController shell

**Files:**
- Create: `CheerComCaluculatorApp/CheerComCaluculatorApp/ModeContainerViewController.swift`
- Create: `CheerComCaluculatorApp/CheerComCaluculatorApp/Views/SkillAnimatorViewController.swift`
- Modify: `CheerComCaluculatorApp/CheerComCaluculatorApp/CheerCOMApp.swift` — swap the root view controller to the new container

**Rationale:** Introduce a parent container that hosts two child view controllers: the existing `SceneViewController` (Pose Mode) and a new `SkillAnimatorViewController` (Skill Animator Mode). A top segmented control toggles between them. The Skill Animator VC in this task is a shell — it owns a SceneKit viewport, a pose library reuse, and an Export button. The timeline comes in Task 9.

- [ ] **Step 8.1: Create `ModeContainerViewController.swift`**

```swift
import UIKit

final class ModeContainerViewController: UIViewController {

    enum Mode: Int {
        case pose = 0
        case skillAnimator = 1
    }

    private let modeSelector = UISegmentedControl(items: ["Pose", "Skill Animator"])
    private var poseVC: SceneViewController!
    private var animatorVC: SkillAnimatorViewController!
    private var currentChild: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupChildren()
        setupModeSelector()
        switchTo(.pose)
    }

    private func setupChildren() {
        poseVC = SceneViewController()
        animatorVC = SkillAnimatorViewController()
    }

    private func setupModeSelector() {
        modeSelector.translatesAutoresizingMaskIntoConstraints = false
        modeSelector.selectedSegmentIndex = 0
        modeSelector.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        view.addSubview(modeSelector)

        NSLayoutConstraint.activate([
            modeSelector.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            modeSelector.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeSelector.widthAnchor.constraint(equalToConstant: 280)
        ])
    }

    @objc private func modeChanged() {
        let newMode: Mode = modeSelector.selectedSegmentIndex == 0 ? .pose : .skillAnimator
        switchTo(newMode)
    }

    private func switchTo(_ mode: Mode) {
        if let current = currentChild {
            current.willMove(toParent: nil)
            current.view.removeFromSuperview()
            current.removeFromParent()
        }

        let child: UIViewController = (mode == .pose) ? poseVC : animatorVC
        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: modeSelector.bottomAnchor, constant: 8),
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        child.didMove(toParent: self)
        currentChild = child
    }
}
```

- [ ] **Step 8.2: Create `Views/SkillAnimatorViewController.swift`**

```swift
import UIKit
import SceneKit
import ModelRigKit

final class SkillAnimatorViewController: UIViewController {

    // Scene state — will be wired to an extracted scene manager in a future task
    private var sceneManager: CheerCOMSceneManager!
    private var viewportContainer: UIView!
    private var timelinePlaceholder: UIView!
    private var exportButton: UIButton!
    private var skillPickerButton: UIButton!
    private var cameraAngleLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        setupScene()
        setupControls()
    }

    private func setupLayout() {
        viewportContainer = UIView()
        viewportContainer.translatesAutoresizingMaskIntoConstraints = false
        viewportContainer.backgroundColor = .black
        view.addSubview(viewportContainer)

        timelinePlaceholder = UIView()
        timelinePlaceholder.translatesAutoresizingMaskIntoConstraints = false
        timelinePlaceholder.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        timelinePlaceholder.layer.cornerRadius = 12
        view.addSubview(timelinePlaceholder)

        NSLayoutConstraint.activate([
            viewportContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 60),
            viewportContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            viewportContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            viewportContainer.bottomAnchor.constraint(equalTo: timelinePlaceholder.topAnchor, constant: -16),

            timelinePlaceholder.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            timelinePlaceholder.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            timelinePlaceholder.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            timelinePlaceholder.heightAnchor.constraint(equalToConstant: 140)
        ])
    }

    private func setupScene() {
        sceneManager = CheerCOMSceneManager(view: viewportContainer)
    }

    private func setupControls() {
        skillPickerButton = UIButton(type: .system)
        skillPickerButton.translatesAutoresizingMaskIntoConstraints = false
        skillPickerButton.setTitle("Skill: (none)", for: .normal)
        skillPickerButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        skillPickerButton.addTarget(self, action: #selector(pickSkill), for: .touchUpInside)
        view.addSubview(skillPickerButton)

        cameraAngleLabel = UILabel()
        cameraAngleLabel.translatesAutoresizingMaskIntoConstraints = false
        cameraAngleLabel.text = "Camera: orbital (96)"
        cameraAngleLabel.textColor = .label
        cameraAngleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        view.addSubview(cameraAngleLabel)

        exportButton = UIButton(type: .system)
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        exportButton.setTitle("Export (96 angles)", for: .normal)
        exportButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        exportButton.backgroundColor = .systemBlue
        exportButton.setTitleColor(.white, for: .normal)
        exportButton.layer.cornerRadius = 10
        exportButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        exportButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        view.addSubview(exportButton)

        NSLayoutConstraint.activate([
            skillPickerButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            skillPickerButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            cameraAngleLabel.centerYAnchor.constraint(equalTo: skillPickerButton.centerYAnchor),
            cameraAngleLabel.leadingAnchor.constraint(equalTo: skillPickerButton.trailingAnchor, constant: 24),

            exportButton.centerYAnchor.constraint(equalTo: skillPickerButton.centerYAnchor),
            exportButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    @objc private func pickSkill() {
        // Placeholder — Task 10 will wire this to VocabularyManagementViewController
        print("skill picker tapped (placeholder)")
    }

    @objc private func exportTapped() {
        // Placeholder — real export flow in Task 11
        print("export tapped (placeholder)")
    }
}
```

- [ ] **Step 8.3: Modify `CheerCOMApp.swift` to use the container as root**

Find this block:
```swift
let viewController = SceneViewController()
print("✅ SceneViewController created")

window?.rootViewController = viewController
```

Replace with:
```swift
let viewController = ModeContainerViewController()
print("✅ ModeContainerViewController created")

window?.rootViewController = viewController
```

- [ ] **Step 8.4: Manual build and launch on iPad simulator**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && xcodebuild \
  -project CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj \
  -scheme CheerComCaluculatorApp \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

Launch on simulator and verify:
- The "Pose | Skill Animator" segmented control appears at the top.
- Tapping "Skill Animator" switches to a new view with a 3D viewport, a "Skill: (none)" button, a "Camera: orbital (96)" label, and an "Export (96 angles)" button.
- Tapping "Pose" switches back to the original Pose Mode view.
- The rigged character appears in the Skill Animator viewport (via `CheerCOMSceneManager`).

- [ ] **Step 8.5: Commit**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && git add CheerComCaluculatorApp/CheerComCaluculatorApp/ModeContainerViewController.swift CheerComCaluculatorApp/CheerComCaluculatorApp/Views/SkillAnimatorViewController.swift CheerComCaluculatorApp/CheerComCaluculatorApp/CheerCOMApp.swift CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj/project.pbxproj && git commit -m "feat(animator): add ModeContainerViewController + Skill Animator shell

New parent container hosts two child VCs with a top segmented
control to switch between Pose Mode (existing SceneViewController,
unchanged) and Skill Animator Mode (new).

Skill Animator shell contains a 3D viewport (reusing
CheerCOMSceneManager), a skill picker button placeholder, a
camera angle label, an Export button placeholder, and a timeline
placeholder panel. Timeline, vocabulary picker, and export flow
arrive in Tasks 9-11.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: SkillTimelineView (keyframe bar UI)

**Files:**
- Create: `CheerComCaluculatorApp/CheerComCaluculatorApp/Views/SkillTimelineView.swift`
- Modify: `CheerComCaluculatorApp/CheerComCaluculatorApp/Views/SkillAnimatorViewController.swift` — add the timeline view

**Rationale:** The authoring experience depends on a working timeline. This task adds a horizontal scrubbable track with keyframe diamonds that the user can tap, drag, or delete.

- [ ] **Step 9.1: Create `Views/SkillTimelineView.swift`**

```swift
import UIKit

protocol SkillTimelineViewDelegate: AnyObject {
    func timelineView(_ view: SkillTimelineView, didTapKeyframeAt index: Int)
    func timelineView(_ view: SkillTimelineView, didMoveKeyframeAt index: Int, toFrame frame: Int)
    func timelineView(_ view: SkillTimelineView, didScrubToFrame frame: Int)
}

final class SkillTimelineView: UIView {

    weak var delegate: SkillTimelineViewDelegate?

    var numFrames: Int = 25 { didSet { setNeedsLayout() } }
    var keyframes: [Int] = [] { didSet { setNeedsLayout() } }   // frame indices
    var currentFrame: Int = 0 { didSet { updatePlayhead() } }

    private let trackView = UIView()
    private let playheadView = UIView()
    private var keyframeMarkers: [UIView] = []
    private var draggingIndex: Int? = nil

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        layer.cornerRadius = 12

        trackView.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
        trackView.layer.cornerRadius = 4
        addSubview(trackView)

        playheadView.backgroundColor = .systemRed
        playheadView.layer.cornerRadius = 2
        addSubview(playheadView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        addGestureRecognizer(pan)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let pad: CGFloat = 16
        let trackHeight: CGFloat = 6
        let trackY = bounds.midY - trackHeight / 2
        trackView.frame = CGRect(x: pad, y: trackY, width: bounds.width - 2 * pad, height: trackHeight)

        layoutKeyframeMarkers()
        updatePlayhead()
    }

    private func layoutKeyframeMarkers() {
        // Recycle / create diamond markers
        while keyframeMarkers.count < keyframes.count {
            let marker = DiamondView()
            addSubview(marker)
            keyframeMarkers.append(marker)
        }
        while keyframeMarkers.count > keyframes.count {
            keyframeMarkers.removeLast().removeFromSuperview()
        }

        for (i, frame) in keyframes.enumerated() {
            let x = xForFrame(frame)
            let marker = keyframeMarkers[i]
            marker.frame = CGRect(x: x - 10, y: bounds.midY - 10, width: 20, height: 20)
        }
    }

    private func updatePlayhead() {
        let x = xForFrame(currentFrame)
        playheadView.frame = CGRect(x: x - 1, y: 12, width: 2, height: bounds.height - 24)
    }

    private func xForFrame(_ frame: Int) -> CGFloat {
        let pad: CGFloat = 16
        let usableWidth = bounds.width - 2 * pad
        let ratio = numFrames > 0 ? CGFloat(frame) / CGFloat(max(1, numFrames - 1)) : 0
        return pad + usableWidth * ratio
    }

    private func frameForX(_ x: CGFloat) -> Int {
        let pad: CGFloat = 16
        let usableWidth = bounds.width - 2 * pad
        let clamped = max(pad, min(bounds.width - pad, x))
        let ratio = (clamped - pad) / usableWidth
        return Int((ratio * CGFloat(max(1, numFrames - 1))).rounded())
    }

    // MARK: - Gestures

    @objc private func tapped(_ gr: UITapGestureRecognizer) {
        let location = gr.location(in: self)
        if let index = keyframeMarkers.firstIndex(where: { $0.frame.insetBy(dx: -8, dy: -8).contains(location) }) {
            delegate?.timelineView(self, didTapKeyframeAt: index)
        } else {
            let frame = frameForX(location.x)
            delegate?.timelineView(self, didScrubToFrame: frame)
        }
    }

    @objc private func panned(_ gr: UIPanGestureRecognizer) {
        let location = gr.location(in: self)
        switch gr.state {
        case .began:
            if let index = keyframeMarkers.firstIndex(where: { $0.frame.insetBy(dx: -8, dy: -8).contains(location) }) {
                draggingIndex = index
            }
        case .changed:
            guard let index = draggingIndex else { return }
            let frame = frameForX(location.x)
            delegate?.timelineView(self, didMoveKeyframeAt: index, toFrame: frame)
        case .ended, .cancelled:
            draggingIndex = nil
        default:
            break
        }
    }
}

/// Small diamond-shaped keyframe marker rendered with a path layer.
private final class DiamondView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.setFillColor(UIColor.systemYellow.cgColor)
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(1.5)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.close()

        ctx.addPath(path.cgPath)
        ctx.drawPath(using: .fillStroke)
    }
}
```

- [ ] **Step 9.2: Wire the timeline into `SkillAnimatorViewController`**

Modify `SkillAnimatorViewController.swift`. Replace the `timelinePlaceholder` UIView with a real `SkillTimelineView`, and add delegate conformance.

Change the property:
```swift
private var timelineView: SkillTimelineView!
```

Replace the `timelinePlaceholder = UIView()` block in `setupLayout()` with:
```swift
timelineView = SkillTimelineView()
timelineView.translatesAutoresizingMaskIntoConstraints = false
timelineView.numFrames = 25
timelineView.keyframes = [0, 6, 14, 22]  // stub keyframes for visual testing
timelineView.delegate = self
view.addSubview(timelineView)
```

Update constraints to reference `timelineView` instead of `timelinePlaceholder`.

Add delegate conformance at the bottom of the file:
```swift
extension SkillAnimatorViewController: SkillTimelineViewDelegate {
    func timelineView(_ view: SkillTimelineView, didTapKeyframeAt index: Int) {
        print("Tapped keyframe \(index)")
    }

    func timelineView(_ view: SkillTimelineView, didMoveKeyframeAt index: Int, toFrame frame: Int) {
        print("Moved keyframe \(index) to frame \(frame)")
        var kfs = view.keyframes
        kfs[index] = frame
        view.keyframes = kfs
    }

    func timelineView(_ view: SkillTimelineView, didScrubToFrame frame: Int) {
        view.currentFrame = frame
    }
}
```

- [ ] **Step 9.3: Manual build and iPad test**

Build and launch on iPad simulator. Verify:
- Switching to Skill Animator mode now shows a real horizontal track with 4 yellow diamond keyframes at frame indices 0, 6, 14, 22.
- Tapping a diamond prints "Tapped keyframe N" to the console.
- Tapping outside a diamond moves the playhead (red vertical line).
- Dragging a diamond moves it along the track and updates `keyframes` in real time.

```bash
cd /Users/ianrichardson/Projects/CheerCOM && xcodebuild \
  -project CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj \
  -scheme CheerComCaluculatorApp \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  build 2>&1 | tail -10
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 9.4: Commit**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && git add CheerComCaluculatorApp/CheerComCaluculatorApp/Views/SkillTimelineView.swift CheerComCaluculatorApp/CheerComCaluculatorApp/Views/SkillAnimatorViewController.swift CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj/project.pbxproj && git commit -m "feat(animator): add SkillTimelineView with draggable keyframe diamonds

Horizontal scrubber track with yellow diamond keyframe markers.
Tap a diamond to select it, tap elsewhere to scrub the playhead,
drag a diamond to reposition it along the frame axis. Delegate-
based callbacks hand off to the parent view controller.

Wired into SkillAnimatorViewController with 4 stub keyframes for
visual smoke testing. Real keyframe data flows in Task 11 when
authoring end-to-end lands.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: BodylineTagPickerViewController + VocabularyManagementViewController

**Files:**
- Create: `CheerComCaluculatorApp/CheerComCaluculatorApp/Views/BodylineTagPickerViewController.swift`
- Create: `CheerComCaluculatorApp/CheerComCaluculatorApp/Views/VocabularyManagementViewController.swift`
- Modify: `CheerComCaluculatorApp/CheerComCaluculatorApp/Views/PoseLibraryPanel.swift` — add a "Tag bodyline" button per saved pose

**Rationale:** Two UIKit view controllers that let the user edit the vocabulary manifest directly from the iPad. Bodyline picker is invoked from Pose Mode when tagging a saved pose; Vocabulary Management is the escape hatch for bulk edits.

- [ ] **Step 10.1: Create `Views/BodylineTagPickerViewController.swift`**

```swift
import UIKit

final class BodylineTagPickerViewController: UITableViewController {

    var onSelect: ((String?) -> Void)?    // nil means "no bodyline"

    private var bodylines: [VocabularyBodyline] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tag Bodyline"
        bodylines = VocabularyManager.shared.load().bodylines
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "+ New", style: .plain, target: self, action: #selector(addBodyline)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancel)
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : bodylines.count
    }

    override func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Clear" : "Existing"
    }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        if indexPath.section == 0 {
            cell.textLabel?.text = "(No bodyline)"
            cell.textLabel?.textColor = .secondaryLabel
        } else {
            let bl = bodylines[indexPath.row]
            cell.textLabel?.text = bl.displayName
            cell.textLabel?.textColor = .label
        }
        return cell
    }

    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            onSelect?(nil)
        } else {
            onSelect?(bodylines[indexPath.row].id)
        }
        dismiss(animated: true)
    }

    @objc private func addBodyline() {
        let alert = UIAlertController(title: "New Bodyline",
                                      message: "Enter a display name (e.g. 'Arabesque Peak').",
                                      preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Display name" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            let id = name.lowercased().replacingOccurrences(of: " ", with: "_")
            do {
                try VocabularyManager.shared.addBodyline(id: id, displayName: name)
                self.bodylines = VocabularyManager.shared.load().bodylines
                self.tableView.reloadData()
            } catch {
                self.showAlert("Could not add bodyline: \(error)")
            }
        })
        present(alert, animated: true)
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

- [ ] **Step 10.2: Create `Views/VocabularyManagementViewController.swift`**

```swift
import UIKit

final class VocabularyManagementViewController: UITableViewController {

    private enum Section: Int, CaseIterable {
        case atoms = 0
        case bodylines = 1
    }

    private var manifest: VocabularyManifest = VocabularyManifest()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Vocabulary"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(addTapped)
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    private func reload() {
        manifest = VocabularyManager.shared.load()
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .atoms: return "Atoms (\(manifest.atoms.count))"
        case .bodylines: return "Bodylines (\(manifest.bodylines.count))"
        default: return nil
        }
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .atoms: return manifest.atoms.count
        case .bodylines: return manifest.bodylines.count
        default: return 0
        }
    }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.accessoryType = .disclosureIndicator
        switch Section(rawValue: indexPath.section) {
        case .atoms:
            let atom = manifest.atoms[indexPath.row]
            cell.textLabel?.text = atom.displayName
            cell.detailTextLabel?.text = "\(atom.id)  [\(atom.tags.sorted().joined(separator: ", "))]"
        case .bodylines:
            let bl = manifest.bodylines[indexPath.row]
            cell.textLabel?.text = bl.displayName
            cell.detailTextLabel?.text = bl.id
        default: break
        }
        return cell
    }

    override func tableView(_ tv: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { true }

    override func tableView(_ tv: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        do {
            switch Section(rawValue: indexPath.section) {
            case .atoms:
                try VocabularyManager.shared.removeAtom(id: manifest.atoms[indexPath.row].id)
            case .bodylines:
                try VocabularyManager.shared.removeBodyline(id: manifest.bodylines[indexPath.row].id)
            default: break
            }
            reload()
        } catch {
            showAlert("Delete failed: \(error)")
        }
    }

    @objc private func addTapped() {
        let sheet = UIAlertController(title: "Add", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "New Atom", style: .default) { _ in
            self.promptAddAtom()
        })
        sheet.addAction(UIAlertAction(title: "New Bodyline", style: .default) { _ in
            self.promptAddBodyline()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

    private func promptAddAtom() {
        let alert = UIAlertController(title: "New Atom", message: "Enter a display name", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Display name (e.g., Back Handspring)" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            let id = name.lowercased().replacingOccurrences(of: " ", with: "_")
            do {
                try VocabularyManager.shared.addAtom(id: id, displayName: name)
                self.reload()
            } catch {
                self.showAlert("Add atom failed: \(error)")
            }
        })
        present(alert, animated: true)
    }

    private func promptAddBodyline() {
        let alert = UIAlertController(title: "New Bodyline", message: "Enter a display name", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Display name" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            let id = name.lowercased().replacingOccurrences(of: " ", with: "_")
            do {
                try VocabularyManager.shared.addBodyline(id: id, displayName: name)
                self.reload()
            } catch {
                self.showAlert("Add bodyline failed: \(error)")
            }
        })
        present(alert, animated: true)
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

- [ ] **Step 10.3: Add a Vocabulary button to SkillAnimatorViewController**

Update `setupControls()` in `SkillAnimatorViewController` to include a button that opens the vocabulary management screen:

```swift
        let vocabButton = UIButton(type: .system)
        vocabButton.translatesAutoresizingMaskIntoConstraints = false
        vocabButton.setTitle("Vocabulary", for: .normal)
        vocabButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        vocabButton.addTarget(self, action: #selector(openVocabulary), for: .touchUpInside)
        view.addSubview(vocabButton)

        NSLayoutConstraint.activate([
            vocabButton.centerYAnchor.constraint(equalTo: skillPickerButton.centerYAnchor),
            vocabButton.trailingAnchor.constraint(equalTo: exportButton.leadingAnchor, constant: -16)
        ])
```

Add the action:
```swift
    @objc private func openVocabulary() {
        let vc = VocabularyManagementViewController(style: .insetGrouped)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }
```

- [ ] **Step 10.4: Manual build and iPad test**

Build and launch. Verify:
- In Skill Animator mode, tapping "Vocabulary" opens a navigation modal with two sections (Atoms / Bodylines), both initially empty.
- Tapping "+" offers "New Atom" or "New Bodyline".
- Adding an atom with name "Back Handspring" creates an entry with id `back_handspring` in the Atoms section.
- Adding a bodyline with name "Tuck Peak" creates an entry with id `tuck_peak` in the Bodylines section.
- Swipe-to-delete removes an entry.
- Closing the modal, re-opening it — the entries persist (file-backed manifest worked).

- [ ] **Step 10.5: Commit**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && git add CheerComCaluculatorApp/CheerComCaluculatorApp/Views/BodylineTagPickerViewController.swift CheerComCaluculatorApp/CheerComCaluculatorApp/Views/VocabularyManagementViewController.swift CheerComCaluculatorApp/CheerComCaluculatorApp/Views/SkillAnimatorViewController.swift CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj/project.pbxproj && git commit -m "feat(vocab): add BodylineTagPicker + VocabularyManagement VCs

Two UIKit view controllers for editing the vocabulary manifest
from the iPad:

- BodylineTagPickerViewController: modal picker with 'Clear' and
  'Existing' sections plus a '+ New' button that prompts for a
  display name, slugs it to an id, and adds it to the manifest.
- VocabularyManagementViewController: grouped table with Atoms
  and Bodylines sections. Add via action sheet, delete via swipe.
  Reloads from disk on appear.

Wired a 'Vocabulary' button into Skill Animator mode's top bar
that opens the management VC modally.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: End-to-end manual test — author a real animation and export

**Files:** No new source files. Verifies the full Phase A + Phase B pipeline together.

**Rationale:** P2 isn't done until a human can open CheerCOM on an iPad, author a skill animation from scratch, and produce real JSON training data on disk. This task is a structured manual test plus any final wiring the earlier tasks left unfinished.

Before starting, write down what "success" looks like so you can recognize it:

- CheerCOM launches on iPad simulator
- Pose Mode still works unchanged
- Skill Animator mode shows the 3D character + timeline + controls
- The user can add 3+ saved poses (via Pose Mode) with bodyline tags
- The user can create a new animation (atom id, name, fps, numFrames)
- The user can add those saved poses as keyframes at specific frame indices
- Tapping Export produces ~96 JSON files in `Documents/CheerCOMAnimations/training_data/raw/`
- At least one of those files opens and parses into a valid `ExportedKeypointFile` struct

- [ ] **Step 11.1: Wire the Export button to the real exporter**

Update `SkillAnimatorViewController`'s `exportTapped()` action to invoke the real exporter using the scene's bone nodes and a test animation:

```swift
    @objc private func exportTapped() {
        guard let sceneManager = sceneManager else { return }
        // For the v1 end-to-end test, build an animation inline from the current
        // saved poses in the library. Use the most recent 3 saved poses as keyframes.
        let poses = PoseStorageManager.shared.loadPoses()
        guard poses.count >= 2 else {
            showSimpleAlert("Save at least 2 poses in Pose Mode before exporting")
            return
        }

        let keyframes: [SkillKeyframe] = [
            SkillKeyframe(poseId: poses[0].id, frameIndex: 0),
            SkillKeyframe(poseId: poses[1].id, frameIndex: 12),
            poses.count >= 3 ? SkillKeyframe(poseId: poses[2].id, frameIndex: 24) : nil
        ].compactMap { $0 }

        let animation = SkillAnimation(
            name: "manual_test",
            atomId: "back_handspring",
            category: "tumbling",
            numFrames: 25,
            keyframes: keyframes
        )

        let poseResolver: (UUID) -> [String: SCNVector3]? = { poseId in
            guard let saved = poses.first(where: { $0.id == poseId }) else { return nil }
            var result: [String: SCNVector3] = [:]
            for (boneName, components) in saved.jointAngles {
                guard components.count == 3 else { continue }
                #if os(macOS)
                result[boneName] = SCNVector3(
                    CGFloat(components[0]),
                    CGFloat(components[1]),
                    CGFloat(components[2])
                )
                #else
                result[boneName] = SCNVector3(components[0], components[1], components[2])
                #endif
            }
            return result
        }

        let bodylineResolver: (UUID) -> String? = { poseId in
            PoseStorageManager.shared.bodyline(for: poseId)
        }

        let exporter = SkillAnimationExporter(
            sceneView: sceneManager.sceneView,
            characterNode: sceneManager.characterNode,
            boneNodes: sceneManager.cachedBoneNodes
        )

        do {
            let urls = try exporter.export(
                animation: animation,
                poseResolver: poseResolver,
                bodylineForPoseId: bodylineResolver
            )
            showSimpleAlert("Exported \(urls.count) JSON files to CheerCOMAnimations/training_data/raw/")
            try? SkillAnimationStorage.shared.save(animation)
        } catch {
            showSimpleAlert("Export failed: \(error)")
        }
    }

    private func showSimpleAlert(_ message: String) {
        let alert = UIAlertController(title: "Export", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
```

- [ ] **Step 11.2: Run the manual end-to-end test on iPad simulator**

1. Build and launch:
```bash
cd /Users/ianrichardson/Projects/CheerCOM && xcodebuild \
  -project CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj \
  -scheme CheerComCaluculatorApp \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  build 2>&1 | tail -10
```

2. Open iPad simulator. Launch the app.
3. In Pose Mode:
   - Pose the character into three different shapes (e.g., T-pose, half-squat, arms overhead).
   - Save each one via the existing "Save" button in the Pose Library.
4. Switch to Skill Animator mode.
5. Tap "Vocabulary" → add an atom "Back Handspring" and a bodyline "Stand Ready". Close the modal.
6. Tap "Export (96 angles)".
7. Expected alert: "Exported 96 JSON files to CheerCOMAnimations/training_data/raw/".

- [ ] **Step 11.3: Verify output files exist**

Open Terminal and run (the exact path depends on the simulator's sandbox UUID):
```bash
find ~/Library/Developer/CoreSimulator/Devices -name "training_data" -type d 2>/dev/null | head -5
```

List the raw directory:
```bash
RAW_DIR=$(find ~/Library/Developer/CoreSimulator/Devices -name "raw" -type d -path "*CheerCOMAnimations*" 2>/dev/null | head -1)
ls "$RAW_DIR" | wc -l
ls "$RAW_DIR" | head -3
```

Expected: 96 files, names matching pattern `back_handspring_az<AAA>_el<+EE>_<timestamp>.json`.

- [ ] **Step 11.4: Parse one file to verify schema**

```bash
RAW_DIR=$(find ~/Library/Developer/CoreSimulator/Devices -name "raw" -type d -path "*CheerCOMAnimations*" 2>/dev/null | head -1)
python3 -c "
import json
import glob
files = sorted(glob.glob('$RAW_DIR/*.json'))
print(f'Found {len(files)} files')
with open(files[0]) as f:
    data = json.load(f)
print('schema_version:', data.get('schema_version'))
print('skill:', data.get('skill'))
print('fps:', data.get('fps'))
print('num_frames:', data.get('num_frames'))
print('camera:', data.get('camera'))
print('keypoints in first frame:', len(data['frames'][0]['persons'][0]['keypoints']))
print('first keypoint:', data['frames'][0]['persons'][0]['keypoints'][0])
print('derived inversion:', data['frames'][0]['persons'][0]['derived']['inversion'])
print('derived comXNorm:', data['frames'][0]['persons'][0]['derived']['comXNorm'])
"
```

Expected output:
- 96 files found
- schema_version: 1
- skill with atom/category/notes
- fps: 30
- num_frames: 25
- camera with azimuthDeg/elevationDeg/etc.
- 17 keypoints in first frame
- first keypoint is "nose"
- derived inversion is true or false
- derived comXNorm is some plausible float

- [ ] **Step 11.5: Commit**

```bash
cd /Users/ianrichardson/Projects/CheerCOM && git add CheerComCaluculatorApp/CheerComCaluculatorApp/Views/SkillAnimatorViewController.swift CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj/project.pbxproj && git commit -m "feat(animator): wire Export button to real SkillAnimationExporter

Final Phase B wiring. The Export button now builds a SkillAnimation
from the user's saved poses, resolves pose ids to joint angles
via PoseStorageManager, and invokes the real SkillAnimationExporter
to write 96 JSON files to Documents/CheerCOMAnimations/
training_data/raw/.

Manual end-to-end test on iPad simulator:
1. Save 3 poses in Pose Mode
2. Switch to Skill Animator mode
3. Tap Export — alert confirms 96 files written
4. Inspect raw/ directory: 96 back_handspring_az<N>_el<E>_*.json
5. python parse verifies schema_version 1, 17 COCO keypoints,
   kinematic features, 30 fps, 25 frames, correct skill metadata

P2 complete. CheerCOM is now a working training-data generator
for the tumbling skill classification pipeline. P3 (Python
training) can ingest these JSON files as its input dataset.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Completion checklist

Before declaring Plan 2 complete, verify:

- [ ] `xcodebuild build` succeeds with no warnings beyond existing CheerCOM warnings
- [ ] All new unit tests pass (VocabularyManifestTests, PoseStorageBodylineTests, SkillAnimationTests, OrbitalCameraSamplerTests, KeyframeInterpolatorTests, MixamoCOCOProjectorTests, SkillAnimationExporterTests)
- [ ] CheerCOM launches on iPad simulator
- [ ] Pose Mode still works unchanged (Pose Library, joint controls, diagnostics, CoM calc)
- [ ] Skill Animator mode shows viewport + timeline + controls
- [ ] Vocabulary Management panel can add/remove atoms and bodylines, persists across relaunch
- [ ] End-to-end manual export test produces 96 valid JSON files that parse correctly
- [ ] Eleven commits landed on the working branch, one per task
- [ ] No regressions in existing CheerCOM tests (`COMCalculatorTests`, etc.)

Once all these are green, Plan 2 is done. CheerCOM has transitioned from a single-pose visualization tool into a full training-data generator. Plan 3 (Python training pipeline) can begin immediately and will consume the JSON files this plan produces.

## Next up

Plans that become ready after P2:
- **Plan 3** — `p3-python-training-pipeline.md` — reads the JSON exports from `training_data/raw/`, applies procedural variation + noise augmentation, trains the multi-task TCN, exports Core ML
- **Plan 4** — `p4-flightfilter-skill-classification-integration.md` — loads the compiled Core ML model in FlightFilter, wires the inference service into `TumblingProcessingPipeline`, ships the composition state machine

P3 can start as soon as P2's Task 7 (SkillAnimationExporter) lands — you don't have to finish Phase B first. If you want to parallelize, write P3 after P2 Task 7 while iterating on P2 Tasks 8–11.
