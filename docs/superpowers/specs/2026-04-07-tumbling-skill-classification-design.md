# Tumbling Skill Classification — Design Spec

**Date:** 2026-04-07
**Status:** Draft — awaiting final review
**Repo:** CheerCOM (monorepo hosting authoring tool, training pipeline, and Core ML artifacts)
**Owner:** Ian Richardson

## Problem

Coaches and athletes need automatic identification of tumbling skills in video — both individual atoms (round-off, back handspring, back tuck, layout, full) and composed passes ("round-off back handspring layout full"). Two specific use cases drive the requirement:

1. **Coach feedback / form grading.** Given a practice video, identify each skill and its execution quality, with precise start/end timing per skill so individual phases can be scored.
2. **Difficulty scoring for routines.** Given a full competition routine video, output a difficulty score based on the skills thrown, following rubrics like NCA/USASF.

Both use cases require **segmentation with timing**, not just whole-clip labels.

### Prior attempt and why it failed

An earlier effort (CheerSkillTagger + CreateML Action Classifier, 32 skill classes) produced a trained `CheerSkillClassifier.mlmodel` that does not generalize. Root causes:

- **Severe class imbalance** in the training corpus: 324 back handsprings vs 1 layout, 1 front tuck, 1 front handspring. CreateML Action Classifier needs roughly 50+ samples per class to train usable heads; most classes had fewer than 5.
- **Domain mixing.** Competition wide-shot footage (rage_tags, Ferocity, Blackout, Wrath — athletes 50–200 pixels tall) was mixed with single-athlete practice clips (400–1000 pixels tall). Pose estimator output on the two sources looks statistically different after keypoint extraction, and mixing them during training produced a classifier that generalized to neither.
- **Black-box architecture.** CreateML Action Classifier is a fixed wrapper. It cannot do dense per-frame segmentation (only whole-window classification), cannot accept custom derived features, and cannot have its loss weighted to handle imbalance. Iterating on it would hit the same walls repeatedly.
- **Fixed-size window.** The 17-frame window (~3.4s at 5 fps) is not built for variable-length multi-skill passes.

The underlying approach — keypoint-based temporal classification — is correct. The execution was blocked by data distribution, labeling bandwidth, and architectural rigidity. This spec addresses all three.

## Solution summary

A **two-layer classifier** with a **synthetic-first training strategy**:

- **Layer 1 (ML):** a small custom Temporal Convolutional Network (TCN) trained on pose keypoint sequences + derived kinematic features. Multi-task heads output per-frame atom labels and per-frame bodyline labels. Emits dense per-frame predictions → segmentable into atom segments with precise timing.
- **Layer 2 (rules):** a Swift state machine that consumes atom segments and emits structured pass labels ("running back handspring full") using deterministic composition rules.

Training data is generated primarily by **authoring skill animations in CheerCOM on iPad**, exported as keypoint sequences from ~96 virtual camera angles per animation, then procedurally varied and noise-augmented in Python to simulate real YOLO output. A small real-data fine-tune on the existing Tumble set closes the sim-to-real gap.

**Core principle — vocabulary is user-defined, not hardcoded.** Atoms, bodylines, and per-atom tags (e.g. "entry skill", "back-facing", "airborne") are authored in CheerCOM and propagate through the pipeline as data. Adding a new atom is a CheerCOM authoring action, not a Swift enum change or a Python config edit. The spec's illustrative vocabulary is a starting point, not a fixed contract. The user's CheerCOM library is canon.

**What's new:**
- `CheerCOM.SkillAnimator` — iPad mode for authoring tumbling animations on a rigged 3D skeleton
- `CheerCOM.VocabularyManifest` — user-editable source of truth for atoms, bodylines, and tags
- `training_pipeline/` — Python pipeline for ingest, augmentation, training, and Core ML export (reads vocab from manifest, dynamically sizes model heads)
- `FlightFilter.SkillClassificationService` — Core ML wrapper that runs the TCN on FlightFilter pose output
- `FlightFilter.CompositionStateMachine` — Swift rules engine for atom → pass composition (reads atom tags from the compiled model's metadata, not hardcoded)

**What's recycled:**
- CheerCOM's existing rigged character, joint controls, pose library, CoM validation, SceneKit scene
- ModelRigKit's `PoseAdapter`, `COCOKeypoint`, and `JointLimits`
- FlightFilter's entire pose extraction pipeline (`PoseEstimationService` + `TumblingProcessingPipeline`)
- The Tumble set real clips (Stage 2 fine-tune corpus)
- CheerSkillTagger (used to label real clips for Stage 2)

**What's archived:**
- Existing `CheerSkillClassifier.mlmodel` (kept as baseline reference only)
- Competition tag corpus (`rage_tags`, `Ferocity`, `Blackout`, `Wrath`, `Frenzy`, `Navy`, `SSX`) — distribution mismatch with inference-time footage
- The flat 32-class fixed vocabulary (replaced by a user-editable manifest-driven vocabulary + composition rules)

## Scope

### In scope for v1

- Single-person tumbling classification only.
- Tumbling atom vocabulary + 1 background class (size determined by `vocabulary_manifest.json`; seed manifest suggests ~12 atoms, but this is user-editable and not part of the contract).
- Composition rules covering the standard cheer tumbling pass vocabulary (running/standing, multi-skill connections, doubles/triples of repeated atoms).
- CheerCOM gets a new Skill Animator mode for authoring animations; Pose Mode is unchanged.
- Python training pipeline with synthetic + fine-tune stages.
- FlightFilter integration with the existing `TumblingProcessingPipeline`.

### Out of scope for v1 (explicit deferrals)

- **Multi-person stunt classification** (v2+). The keypoint data schema is designed to be multi-person-ready (`persons` is always an array) and the `SkillClassificationService` uses a model registry so stunts can ship as a second trained model, but no stunt code or model is built in v1.
- **Whip, X-out, Arabian, back handspring step-out, and other variant atoms.** Added to v2 by authoring additional CheerCOM animations.
- **Twist execution scoring** (under-rotated full detection, etc.) beyond basic atom classification. The `derived.shoulder_hip_twist_deg` feature is recorded per frame and exposed at inference time, so a scoring layer can be built on top later.
- **Live/real-time inference.** FlightFilter is a post-processing tool; the TCN runs on full pose sequences after recording, not during.
- **Automatic CheerCOM→iCloud→Mac sync orchestration.** iCloud Drive handles file sync; the training pipeline reads from a local directory.

## Architecture

Five components across three execution environments.

### On iPad (CheerCOM, Swift)

- **`CheerCOM.PoseMode`** — existing single-frame pose authoring. Extended only by adding an optional `bodyline: String?` tag on saved poses.
- **`CheerCOM.SkillAnimator`** — new mode for authoring timed skill animations from keyframed poses, with batch orbital camera export.

### On Mac (Python, offline, batch)

- **`training_pipeline/`** — parses CheerCOM JSON exports, applies procedural variation and noise augmentation, builds training shards, trains the multi-task TCN, evaluates, and exports to Core ML.

### On iPhone/iPad (FlightFilter, Swift, runtime)

- **`FlightFilter.SkillClassificationService`** — wraps the Core ML `CheerSkillTCN_v1.mlmodel`. Consumes pose sequences from `TumblingProcessingPipeline`, emits atom segments + bodyline labels.
- **`FlightFilter.CompositionStateMachine`** — pure Swift rules engine. Consumes atom segments, emits pass-level structured labels.

### Data boundaries

| Boundary | Format | Direction |
|---|---|---|
| CheerCOM → `training_pipeline` | JSON keypoint sequences (transfer via iCloud Drive) | One-way |
| `training_pipeline` → FlightFilter | Compiled `.mlmodel` in `CoreMLModels/CheerSkillTCN_v1.mlmodel` | One-way |
| FlightFilter internal | `FrameAnalysis[]` → `[AtomSegment]` → `[ClassifiedPass]` | In-process |

### Repository layout

```
CheerCOM/
├── CheerComCaluculatorApp/              # existing iOS app, extended with SkillAnimator
│   └── CheerComCaluculatorApp/
│       ├── Views/
│       │   ├── SkillAnimatorView.swift          (NEW)
│       │   ├── SkillTimelineView.swift          (NEW)
│       │   ├── KeyframeBarView.swift            (NEW)
│       │   └── VirtualCameraPanel.swift         (NEW)
│       ├── Managers/
│       │   ├── SkillAnimationStorage.swift      (NEW)
│       │   ├── SkillAnimationExporter.swift     (NEW)
│       │   └── OrbitalCameraSampler.swift       (NEW)
│       └── Models/
│           ├── SkillAnimation.swift             (NEW)
│           ├── SkillKeyframe.swift              (NEW)
│           ├── VocabularyManifest.swift         (NEW)
│           └── BodylineLabel.swift              (NEW — dynamic struct, not enum)
├── training_pipeline/                   # NEW — Python
│   ├── ingest_cheercom_exports.py
│   ├── kinematic_features.py
│   ├── procedural_variation.py
│   ├── noise_augment.py
│   ├── background_mining.py
│   ├── build_dataset.py
│   ├── train_tcn.py
│   ├── fine_tune_real.py
│   ├── evaluate.py
│   ├── export_coreml.py
│   ├── configs/
│   │   └── v1_training.yaml
│   ├── requirements.txt
│   └── run_all.sh
├── CoreMLModels/                        # NEW — compiled models, checked in
│   └── CheerSkillTCN_v1.mlmodel
├── training_data/                       # NEW — data directory
│   ├── raw/                             # CheerCOM exports (via iCloud)
│   ├── augmented/                       # gitignored generated shards
│   └── tumble_set_labels/               # Stage 2 real labels
└── docs/superpowers/specs/
    └── 2026-04-07-tumbling-skill-classification-design.md
```

FlightFilter consumes the compiled model by copying `CoreMLModels/CheerSkillTCN_v1.mlmodel` into its own `Resources/` bundle at build time (either via an Xcode build phase script or a manual copy; decided during implementation).

## Atom vocabulary and composition rules

### Vocabulary is data, not code

Atoms and bodylines are defined in **`CheerCOM/training_data/raw/vocabulary_manifest.json`**. That file is the single source of truth. Nothing downstream hardcodes the atom or bodyline list:

- **CheerCOM Skill Animator** reads the manifest to populate the skill picker, the bodyline tag dropdown, and the atom filter in the animation library.
- **`training_pipeline/build_dataset.py`** reads the manifest at dataset build time and dynamically sizes the TCN output heads (`num_atoms + 1` for atom head including background; `num_bodylines` for bodyline head).
- **The exported Core ML model** embeds the vocabulary as metadata (`CheerSkillTCN_v1.mlmodel.modelDescription.metadata`) — atom class names, bodyline class names, and per-atom tags.
- **FlightFilter's `SkillClassificationService`** reads class names and tags from the Core ML metadata at load time. No Swift enum needs to be touched when the vocabulary grows.
- **`CompositionStateMachine`** references atoms by string ID and reads per-atom tags from the loaded model. Rules like "R2 running pass" operate on the `entry` tag, not on a hardcoded set of atom names.

Adding a new skill is a data operation: author in CheerCOM → manifest updates → retrain → new Core ML model ships with the new class and its tags. No code changes in any of the three apps.

### The manifest schema

```json
{
  "schema_version": 1,
  "atoms": [
    {
      "id": "back_handspring",
      "display_name": "Back Handspring",
      "category": "tumbling",
      "tags": ["hand_support", "back_facing", "airborne_brief"],
      "created_at": "2026-04-07T21:03:47Z"
    },
    {
      "id": "round_off",
      "display_name": "Round Off",
      "category": "tumbling",
      "tags": ["entry", "hand_support", "running"],
      "created_at": "2026-04-07T21:05:12Z"
    }
  ],
  "bodylines": [
    {
      "id": "tuck_peak",
      "display_name": "Tuck Peak",
      "created_at": "2026-04-07T21:06:00Z"
    },
    {
      "id": "layout_peak",
      "display_name": "Layout Peak",
      "created_at": "2026-04-07T21:06:15Z"
    }
  ]
}
```

Atom `tags` are a loose, extensible set. V1 recognizes these tag values for composition rules:

| Tag | Meaning to the composition state machine |
|---|---|
| `entry` | This atom is an entry skill → a pass starting with this atom is a "running" pass |
| `airborne` | Fully airborne skill (no ground contact during the skill) |
| `hand_support` | Skill uses hands on the ground (BHS, round-off, cartwheel, walkovers, etc.) |
| `back_facing` | Rotation is in the backward direction |
| `front_facing` | Rotation is in the forward direction |
| `twisting` | Skill includes longitudinal rotation (full, double full, arabian, whip) |

Adding a new tag is as simple as adding it in CheerCOM; composition rules that don't know the tag ignore it. Future composition rules can read new tags as they become useful.

### Starter vocabulary (illustrative only — replace with whatever CheerCOM actually contains)

The actual vocabulary used by v1 is whatever you author in CheerCOM. The list below is a *suggestion* of atoms to seed the manifest with before the first training run. Replace, rename, or extend freely — this table is not part of the contract.

| Atom id (suggestion) | Suggested tags |
|---|---|
| `background` | (implicit — always present, no tags) |
| `cartwheel` | `entry`, `hand_support` |
| `round_off` | `entry`, `hand_support`, `running` |
| `back_handspring` | `hand_support`, `back_facing` |
| `back_tuck` | `airborne`, `back_facing` |
| `back_layout` | `airborne`, `back_facing` |
| `back_full` | `airborne`, `back_facing`, `twisting` |
| `back_double_full` | `airborne`, `back_facing`, `twisting` |
| `front_handspring` | `entry`, `hand_support`, `front_facing` |
| `front_tuck` | `airborne`, `front_facing` |
| `aerial` | `airborne`, `front_facing` |
| `back_walkover` | `entry`, `hand_support`, `back_facing` |
| `front_walkover` | `entry`, `hand_support`, `front_facing` |

**Design note on layout/full/double full (if you choose to keep them as separate atoms):** they share the same body shape and differ only by twist count. The model learns twist count from the `shoulder_hip_twist_deg` derived feature and from hip-shoulder relative angular velocity over the airborne phase. You could alternatively collapse them to a single `back_layout` atom and derive "full/double full" from twist count as a separate output — a preference decision made during CheerCOM authoring.

### Composition rules (Swift state machine)

Input: a list of `AtomSegment` tuples `(atom, start_frame, end_frame, confidence)` after model inference, smoothing, and thresholding.

**R1 — Pass boundaries.** Two consecutive atoms belong to the same pass if the gap between them is less than `MAX_SKILL_GAP_FRAMES` (default 30 frames = 1s at 30fps). Otherwise a new pass starts.

**R2 — Running vs standing.** A pass is "running" if its first atom has the `entry` tag in the vocabulary manifest. Otherwise "standing". The state machine queries the loaded model's embedded metadata for tag membership — it does not hold a hardcoded entry-skill list.

**R3 — Skill repetition collapse.** Two or more consecutive identical atoms collapse to a count multiplier.
- `[BHS, BHS]` → "double back handspring"
- `[BHS, BHS, BHS]` → "triple back handspring"

**R4 — Standard pass naming.** The pass label is the concatenation of atom names (with R3 collapse applied) prefixed by the running/standing qualifier.

**R5 — Confidence gate.** Any atom with mean confidence below `MIN_ATOM_CONFIDENCE` (default 0.5) is dropped before composition.

**R6 — Minimum duration.** Any atom segment shorter than `MIN_ATOM_DURATION_FRAMES` (default 8 frames ≈ 0.27s) is dropped as noise.

**R7 — Overlap resolution.** If two atom predictions overlap in time, keep the one with higher mean confidence.

Thresholds live in a `CompositionConfig` struct so they can be tuned without code changes.

### Composition examples

| Atom sequence | Composed pass label |
|---|---|
| `[back_handspring]` | "standing back handspring" |
| `[back_tuck]` | "standing back tuck" |
| `[back_handspring, back_handspring]` | "standing double back handspring" |
| `[round_off, back_handspring]` | "running back handspring" |
| `[round_off, back_handspring, back_handspring]` | "running double back handspring" |
| `[round_off, back_handspring, back_tuck]` | "round-off back handspring tuck" |
| `[round_off, back_handspring, back_handspring, back_layout]` | "round-off double back handspring layout" |
| `[round_off, back_handspring, back_full]` | "round-off back handspring full" |
| `[round_off, back_handspring, back_handspring, back_double_full]` | "round-off double back handspring double full" |
| `[cartwheel, back_handspring]` | "cartwheel back handspring" |
| `[aerial, back_handspring]` | "aerial back handspring" |

### Output types

Atoms and bodylines are **dynamic string-identified values**, not enums. This lets vocabulary grow in CheerCOM without Swift code changes.

```swift
struct Atom: Hashable, Codable {
    let id: String                      // "back_handspring", "round_off", ...
    let displayName: String             // "Back Handspring"
    let category: String                // "tumbling", "stunts", ...
    let tags: Set<String>               // ["entry", "hand_support", "back_facing"]

    func hasTag(_ tag: String) -> Bool { tags.contains(tag) }
}

struct Bodyline: Hashable, Codable {
    let id: String                      // "tuck_peak", "layout_peak", ...
    let displayName: String
}

struct AtomSegment {
    let atom: Atom
    let startFrame: Int
    let endFrame: Int
    let confidence: Double
    let bodylineAtPeak: Bodyline?
}

struct ClassifiedPass {
    let startFrame: Int
    let endFrame: Int
    let atoms: [AtomSegment]
    let label: String                   // "round-off back handspring layout"
    let isRunning: Bool
    let totalTwistDegrees: Double
    let peakInversionFrame: Int?
}
```

**Vocabulary provider:** a shared `VocabularyRegistry` loads atoms and bodylines from the Core ML model's embedded metadata at `SkillClassificationService` init time. All code that needs to resolve an atom ID or a bodyline ID goes through the registry. The registry is the only place where the vocabulary lives at runtime.

```swift
final class VocabularyRegistry {
    let atoms: [String: Atom]           // keyed by id
    let bodylines: [String: Bodyline]

    init(from model: MLModel) throws {
        let metadata = model.modelDescription.metadata
        self.atoms = try Self.parseAtoms(from: metadata)
        self.bodylines = try Self.parseBodylines(from: metadata)
    }

    func atom(id: String) -> Atom? { atoms[id] }
    func atomsWithTag(_ tag: String) -> [Atom] {
        atoms.values.filter { $0.hasTag(tag) }
    }
}
```

## CheerCOM Skill Animator mode

### User flow

1. Open CheerCOM on iPad → pick "Skill Animator" from the top-level mode switcher.
2. Pick a skill to author from a list (`back_handspring`, `cartwheel`, ...) or create "New Animation".
3. Drag poses from the Pose Library onto the timeline. Each pose becomes a keyframe at a chosen frame.
4. Drag keyframes left/right to set timing. The 3D viewport renders interpolated in-between poses in real time.
5. Set the virtual camera angle (or leave at default "side"); this only affects the authoring preview, not export.
6. Scrub the timeline or hit Play to preview.
7. Tag the animation with skill atom label + category (auto-populated from the skill type picked in step 2).
8. Tap Export → writes ~96 JSON files, one per camera sample, to the app's documents directory.

### Layout (iPad landscape)

```
┌─────────────────────────────────────────────────────────────┐
│  [Skill: back_handspring ▾]  [Camera: side ▾]  [Export]     │
├─────────────────────────────────────────────────────────────┤
│          ┌───────────────┐         ┌────────────────┐       │
│          │   3D viewport │         │ Pose Library   │       │
│          │   (SceneKit)  │         │  • stand_ready │       │
│          │    character  │         │  • arms_reach  │       │
│          │    + CoM dot  │         │  • hands_plant │       │
│          │    + gravity  │         │  • snap_down   │       │
│          │      line     │         │  • land_squat  │       │
│          │               │         │  • tuck_peak   │       │
│          │               │         │  • layout_peak │       │
│          │               │         │  [+ New Pose]  │       │
│          └───────────────┘         └────────────────┘       │
├─────────────────────────────────────────────────────────────┤
│  Timeline  [◀ ▶ ⏸]  0 ──────────────────────── 25 frames    │
│            ◆──────◆───────◆──────────◆────────◆             │
│         stand_ready  arms_reach hands_plant snap  land      │
│         frame 0      frame 4     frame 9    15    22        │
└─────────────────────────────────────────────────────────────┘
```

### Keyframe interpolation

- **SLERP** (spherical linear interpolation) between bone rotations.
- **Linear time, linear ease** for v1. No bezier curves.
- **Internal frame rate: 30 fps.** All exports are resampled to 30 fps regardless of authoring cadence. This matches FlightFilter runtime pose rate.

### Batch orbital camera export

Export does not emit one file per preset. It emits ~96 JSON files drawn from a systematic grid:

- **Azimuth:** `{0, 15, 30, ..., 345}` → 24 samples
- **Elevation:** `{-10°, 0°, +10°, +20°}` → 4 samples
- **Distance:** fixed at ~5× character height, per-sample jitter ±10%
- **Roll:** 0° ± 3° jitter
- **Framing offset:** aim point jitter ±0.1 m
- **Character world position:** jitter ±0.3 m horizontally

= **24 × 4 = 96 camera samples per animation.**

File naming: `<skill>_<version>_az<NNN>_el<NN>_<timestamp>.json`, e.g. `back_handspring_v1_az045_el10_20260407T2103.json`.

**Sampling bias (applied at training-time data loader, not export):** side-ish angles (azimuth 90° ± 30°) get 2× weight. Near-front/near-back angles (azimuth near 0° or 180°) get 0.5× weight. All 96 files are still exported.

### Pose Library extension + bodyline vocabulary

Each saved pose gains an optional `bodyline: String?` field referencing a bodyline ID from the current vocabulary manifest. When the user saves a new pose in Pose Mode, they either pick an existing bodyline from a dropdown or **create a new one inline** with a name — the new bodyline is immediately added to `vocabulary_manifest.json` and becomes available everywhere.

Creating a new bodyline is a one-tap flow:
1. User taps "Tag bodyline" on a saved pose
2. Dropdown shows current bodylines + "➕ New bodyline..."
3. User picks new, types a name ("arabesque_peak"), taps Save
4. Manifest updates, pose is tagged, dropdown now contains the new bodyline for future poses

The same flow applies when authoring a new skill animation: if the user wants to create a new atom (e.g., "punch_front"), they tap "New skill..." in Skill Animator's skill picker, enter a display name and category, optionally pick tags from a checkbox list, and the atom is added to the manifest.

### Vocabulary Management panel

A simple settings-style panel accessed from either Pose Mode or Skill Animator mode. Lists all atoms and bodylines from the current manifest with their metadata. Actions:

- **Rename** an atom or bodyline (updates manifest + all existing animations that reference the old ID)
- **Delete** an atom or bodyline (warns if animations reference it; offers to re-tag or delete those animations)
- **Edit tags** on an atom (checkboxes for `entry`, `airborne`, `hand_support`, `back_facing`, `front_facing`, `twisting`, plus a free-text field for custom tags)
- **Add new atom** directly (outside of the Skill Animator flow)
- **Add new bodyline** directly (outside of the Pose Mode flow)
- **Export manifest** to JSON for backup or sharing
- **Import manifest** from JSON (merge or replace)

The panel is the escape hatch for bulk vocabulary edits. Most day-to-day additions happen inline during authoring.

### Storage format in CheerCOM

Animations save locally as JSON in `Documents/CheerCOMAnimations/<skill_name>_<timestamp>.anim.json`. The on-disk format is a keyframe list (not a baked frame sequence) so animations can be re-edited without loss. At Export time the keyframe list is rendered into dense per-frame JSON files (one per camera sample) using the schema defined in the next section.

Authored animations sync via iCloud Drive to the Mac, landing in `CheerCOM/training_data/raw/` on the training workstation.

## Keypoint data representation (JSON schema)

One schema is used in three places: CheerCOM export, Python training ingest, FlightFilter inference input. Schema drift is prevented by keeping `schema_version` and refusing unknown versions at ingest.

```json
{
  "schema_version": 1,
  "source": "cheercom_skill_animator",
  "created_at": "2026-04-07T21:03:47Z",
  "animation_id": "back_handspring_v1_az045_el10",
  "fps": 30,
  "num_frames": 25,

  "skill": {
    "atom": "back_handspring",
    "category": "tumbling",
    "notes": "canonical form"
  },

  "camera": {
    "azimuth_deg": 45,
    "elevation_deg": 10,
    "distance_m": 5.0,
    "focal_length_mm": 35,
    "image_width_px": 1920,
    "image_height_px": 1080
  },

  "character": {
    "rig": "mixamo",
    "height_m": 1.65,
    "proportions_preset": "average_adult_female"
  },

  "frames": [
    {
      "frame": 0,
      "t": 0.0,
      "persons": [
        {
          "person_id": 0,
          "role": "tumbler",
          "bounding_box_norm": [0.42, 0.20, 0.58, 0.95],
          "keypoints": [
            { "name": "nose",           "x": 0.50, "y": 0.22, "confidence": 1.0 },
            { "name": "left_eye",       "x": 0.49, "y": 0.21, "confidence": 1.0 },
            { "name": "right_eye",      "x": 0.51, "y": 0.21, "confidence": 1.0 },
            { "name": "left_ear",       "x": 0.48, "y": 0.22, "confidence": 1.0 },
            { "name": "right_ear",      "x": 0.52, "y": 0.22, "confidence": 1.0 },
            { "name": "left_shoulder",  "x": 0.47, "y": 0.30, "confidence": 1.0 },
            { "name": "right_shoulder", "x": 0.53, "y": 0.30, "confidence": 1.0 },
            { "name": "left_elbow",     "x": 0.44, "y": 0.40, "confidence": 1.0 },
            { "name": "right_elbow",    "x": 0.56, "y": 0.40, "confidence": 1.0 },
            { "name": "left_wrist",     "x": 0.42, "y": 0.50, "confidence": 1.0 },
            { "name": "right_wrist",    "x": 0.58, "y": 0.50, "confidence": 1.0 },
            { "name": "left_hip",       "x": 0.48, "y": 0.55, "confidence": 1.0 },
            { "name": "right_hip",      "x": 0.52, "y": 0.55, "confidence": 1.0 },
            { "name": "left_knee",      "x": 0.47, "y": 0.75, "confidence": 1.0 },
            { "name": "right_knee",     "x": 0.53, "y": 0.75, "confidence": 1.0 },
            { "name": "left_ankle",     "x": 0.47, "y": 0.92, "confidence": 1.0 },
            { "name": "right_ankle",    "x": 0.53, "y": 0.92, "confidence": 1.0 }
          ],
          "bodyline": "stand_ready",
          "derived": {
            "inversion": false,
            "body_angle_deg": 2.1,
            "hip_angle_deg": 178.0,
            "knee_angle_left_deg": 176.0,
            "knee_angle_right_deg": 176.0,
            "com_x_norm": 0.50,
            "com_y_norm": 0.60,
            "com_vx_norm": 0.0,
            "com_vy_norm": 0.0,
            "hip_angular_velocity_dps": 0.0,
            "shoulder_hip_twist_deg": 0.0,
            "ground_contact": true
          }
        }
      ]
    }
  ]
}
```

### Schema invariants

1. **`persons` is always an array.** For v1, length == 1. For v2 stunts, length == 4–5. No code anywhere assumes a single person.
2. **Coordinates are normalized `[0.0, 1.0]`** relative to image dimensions. Resolution-agnostic by construction.
3. **Keypoint order matches COCO 17-point convention** exactly, matching `ModelRigKit.COCOKeypoint` and YOLO output. No remapping.
4. **`confidence` is always `1.0` in authored CheerCOM exports.** Noise augmentation in the Python pipeline introduces varying confidences.
5. **`bodyline` is nullable.** Frames without an explicit bodyline propagate from the nearest keyframe or hold `null`.
6. **`derived` is computed at export time** from the same shared code path used at inference. See Derived Features Contract below.
7. **`animation_id`** is the deduplication key. All camera variants of the same animation share a prefix. Used at training time to prevent leakage across train/val.

### Derived features contract (shared utility)

Computed identically in three places:
- CheerCOM export (Swift, at export time)
- Python training pipeline (Python, for sanity check and noise-recompute)
- FlightFilter inference (Swift, per frame at runtime)

The Swift implementation lives in a new shared module `ModelRigKit.KinematicFeatures`. A parallel Python implementation `training_pipeline/kinematic_features.py` is tested for numerical equivalence against golden Swift outputs.

| Feature | Computation |
|---|---|
| `inversion` | `head_y > hip_y` (image Y increases downward) |
| `body_angle_deg` | Angle of `hip_midpoint → shoulder_midpoint` vector from vertical, signed |
| `hip_angle_deg` | Angle `shoulder_midpoint → hip_midpoint → knee_midpoint` |
| `knee_angle_{left,right}_deg` | Angle at knee, 180° = straight |
| `com_{x,y}_norm` | Weighted segment average using `CheerCOM.COMCalculator` body weights |
| `com_v{x,y}_norm` | Frame-to-frame CoM velocity; first frame = 0.0 |
| `hip_angular_velocity_dps` | Change in `body_angle_deg` per second |
| `shoulder_hip_twist_deg` | Angle between shoulder line and hip line in image plane |
| `ground_contact` | `min(left_ankle_y, right_ankle_y) > GROUND_Y_THRESHOLD` |

### TCN input tensor shape

Per frame, per person:

```
[ 17 keypoints × (x, y, confidence) ] + [ 11 derived features ]
= [51] + [11]
= 62 floats per frame
```

V1 single person: **62-channel input.** Sequence length is variable (32–512 frames at train/inference time).

## Procedural variation and noise augmentation

### Stage 1 — Procedural variation (on clean authored exports)

Purpose: teach the model to generalize across bodies, speeds, and handedness.

| Axis | Range | Applied by |
|---|---|---|
| Body proportions | 3 presets (`short` ×0.85, `average` ×1.0, `tall` ×1.15), independent limb ratios ±15% | Scale keypoints around hip midpoint |
| Speed | Uniform `[0.75, 1.25]` | Resample frame sequence (linear) |
| Horizontal mirror | 50% probability | Flip X around 0.5, swap L/R joints |
| Scale jitter | Uniform `[0.85, 1.15]` | Scale around hip midpoint |
| Translation jitter | Uniform `[-0.1, +0.1]` per axis | Shift keypoints |
| Slight form imperfection | 30% probability, 5° rotation on one random limb per frame | Per-limb rotation around joint |
| Frame rate jitter | 50% probability resample to 25 or 60 fps before standardizing to 30 fps | Temporal resample |
| Start/end trim | Uniform 0–3 frame trim | Crop sequence |

Sample **20 variants per authored animation × 96 camera angles** at dataset build time.

### Stage 2 — Noise augmentation (the sim-to-real bridge)

Purpose: make clean synthetic keypoints look like real YOLO output. The single most critical step for real-world performance.

| Noise type | Default |
|---|---|
| Gaussian keypoint jitter | σ = 0.006 per coordinate, per frame |
| Temporal smoothness | Low-pass correlation α=0.7 with previous frame |
| Brief joint dropout | 3% per-frame probability conf drops below 0.3 |
| Run joint dropout | 1% per-frame probability of starting a 3–10 frame run |
| L/R swap | 5% probability per frame during `inversion==true`, swaps L/R shoulders, hips, knees, ankles |
| Confidence noise | Multiply by `Uniform[0.6, 1.0]` per frame + per-joint `N(0, 0.1)` clamped |
| Orientation wobble | Rotate skeleton `N(0°, 2°)` per frame, smoothed over 5 |
| Per-clip scale jitter | `N(1.0, 0.08)` once per clip |
| Frame duplicate/drop | 2% per-frame probability |

**Critical invariant: derived features are recomputed AFTER noise is applied**, so the model always sees derived features consistent with the noisy keypoints it will see at inference.

### Stage 3 — Hard negatives (background class)

Background frames prevent false-positive skill firing. Sources:
1. Author 5–10 CheerCOM background animations: `walking_across_mat`, `standing_waiting`, `stretching`, `arms_overhead_stretch`, `lunge_walk`.
2. Mine real FlightFilter tumbling recordings for frames between passes (`background_mining.py`).

Target training distribution: **60% background / 40% skill** (with the 40% roughly balanced across whatever skill atoms the current manifest contains).

### Stage 4 — Real Tumble set fine-tune

After synthetic-only training converges:
1. Run YOLOv8-pose (same model as FlightFilter) on each Tumble set clip.
2. Manually label each clip's atom + start/end frames in CheerSkillTagger.
3. Fine-tune the pretrained model with freeze on the first two TCN blocks, low learning rate, small batch size, few epochs.

Approximate real labeling effort: ~155 clips × ~30s per clip = ~1.5 hours one-time.

### Dataset size estimates

| Stage | Sequences | Approx per-frame examples |
|---|---|---|
| Authored animations | 30–90 (skill) + 5–10 (background) | 750–2,500 |
| × 96 camera angles | 2,880–9,600 | 72,000–240,000 |
| × 20 procedural variants | 57,600–192,000 | 1.4M–4.8M |
| + Stage 4 real fine-tune | +155 | +3,875 |

Plenty for a ~250k-parameter model.

## TCN model architecture and training

### Why TCN

Temporal Convolutional Network with dilated 1D convolutions. Chosen over LSTM (serial, slow) and Transformer (data-hungry, overkill for ≤500-frame sequences):
- Parallelizable at both train and inference time
- Receptive field scales exponentially with depth via dilation
- Exports cleanly to Core ML and runs on the Apple Neural Engine with no special handling

### Architecture

```
Input:  [batch, features=62, time=T]
          T = 32..512 (variable, padded per batch)

Stem:   Conv1D(k=1, 62 → 128) + BN + ReLU

Block 1 (dilation=1):
  DilatedConv1D(k=3) + BN + ReLU + Dropout(0.2)
  DilatedConv1D(k=3) + BN + ReLU + Dropout(0.2)
  + residual from input
Block 2 (dilation=2):  same
Block 3 (dilation=4):  same
Block 4 (dilation=8):  same
Block 5 (dilation=16): same

Shared backbone:    [batch, 128, T]

Atom head:
  Conv1D(1×1, 128 → 64) + ReLU
  Conv1D(1×1, 64 → N_atoms + 1)       # +1 for background
  → [batch, N_atoms + 1, T]   atom logits

Bodyline head:
  Conv1D(1×1, 128 → 64) + ReLU
  Conv1D(1×1, 64 → N_bodylines)
  → [batch, N_bodylines, T]   bodyline logits
```

**Dynamic head sizing:** `N_atoms` and `N_bodylines` are read from `vocabulary_manifest.json` at `build_dataset.py` invocation time and baked into the model. Each trained model is **versioned together with the vocabulary manifest that produced it** (manifest hash stored in model metadata). If vocabulary changes, the next training run produces a new model with matched vocabulary. Mismatched manifest/model pairs are rejected at FlightFilter load time with a clear error.

**Receptive field:** kernel 3, dilations {1, 2, 4, 8, 16}, 2 convs/block:
`RF = 1 + 2 × (3-1) × (1+2+4+8+16) = 125 frames ≈ 4.16 seconds at 30 fps`.

**Parameter count:** ~230k–280k. Core ML size: ~1–2 MB.

**Padding:** symmetric (non-causal). FlightFilter is post-processing, so future-frame context is available and improves segmentation at skill boundaries.

**Loss:**
```
total_loss = 1.0 * atom_loss + 0.3 * bodyline_loss

atom_loss:     Focal Loss (γ=2.0) + class-balanced weighting by inverse-sqrt frequency
bodyline_loss: Cross-entropy, masked where bodyline label is null
```

Class weights normalized so skill atoms receive ~4× the gradient signal of background. Weights are computed dynamically from the manifest's atom count, not hardcoded.

### Training stages

**Stage 1 — Synthetic pretrain**
```
Input:        training_data/augmented/*.npz
Optimizer:    AdamW, lr=1e-3, weight_decay=1e-4
Scheduler:    CosineAnnealingLR
Batch size:   32 sequences
Max seq len:  256 (random crop for longer)
Min seq len:  32
Epochs:       60 with early stopping (patience=8 on val macro-F1)
Val split:    10% of animation_ids held out, stratified by atom
Runtime est.: 30 minutes – 2 hours on Apple Silicon Mac, no GPU rental
```

**Stage 2 — Real Tumble set fine-tune**
```
Input:        training_data/tumble_set_labels/*.json
Starting pt:  Stage 1 best.pt
Frozen:       TCN Blocks 1 and 2 (early pose motion features)
Optimizer:    AdamW, lr=1e-4 (10× smaller than Stage 1)
Scheduler:    None (constant)
Batch size:   16
Epochs:       10
Val split:    ~20% of clips, stratified by atom
```

**Stage 3 — Core ML export** via `coremltools.convert` with `RangeDim(32, 512)` on the time axis. Supports any input length between 32 and 512 frames (~1 to 17 seconds of video at 30 fps) at inference.

### Validation strategy

**Split by `animation_id`, never by frame or sequence.** All 96 camera angles and all 20 procedural variants of a single authored animation go to the same split. Otherwise near-identical variants leak across train/val and metrics become meaningless.

### Tracked metrics

Per-epoch on train and val:
- Atom macro-F1 (primary)
- Atom per-class F1 (diagnostic)
- Atom confusion matrix (diagnostic gold)
- Bodyline macro-F1 (auxiliary)
- Atom frame-level accuracy
- Atom segment-level IoU (after smoothing + segmentation)

### Target metrics for v1 ship

| Stage | Metric | Target |
|---|---|---|
| Stage 1 synthetic | Atom macro-F1 | ≥ 0.90 |
| Stage 2 real fine-tune | Atom macro-F1 | ≥ 0.70 |
| Stage 2 real fine-tune | Segment IoU | ≥ 0.60 |

If metrics fall below targets, the tuning playbook (in order of preference):
1. Increase noise augmentation aggressiveness
2. Add more real fine-tune data (more CheerSkillTagger labeling sessions)
3. Author more CheerCOM animations for underperforming classes
4. Tune temporal smoothing / thresholding at the segmentation stage

Model architecture changes are the last resort.

### Reproducibility

- All randomness seeded (`--seed`, default 42)
- Dataset generation is deterministic given seed + input files + config
- Config is YAML at `training_pipeline/configs/v1_training.yaml`
- Every trained model records config + input file hashes in its metadata

### One-command training

```bash
cd training_pipeline
./run_all.sh --config configs/v1_training.yaml
```

Invokes in order: `build_dataset.py → train_tcn.py → fine_tune_real.py → evaluate.py → export_coreml.py`.

## Core ML export and FlightFilter integration

The training pipeline's final step writes `CoreMLModels/CheerSkillTCN_v1.mlmodel`. This is the handoff point to FlightFilter.

### FlightFilter integration architecture

```
existing:
 Video → TumblingProcessingPipeline
             ↓
             AnalysisResult (frames: [FrameAnalysis])
             ↓ (existing: used for playback overlays)

new:
             ↓
             SkillClassificationService
             ├── TCNFeatureBuilder
             │     (FrameAnalysis → [62]-channel tensor per frame)
             ├── KinematicFeatures  (shared with ModelRigKit)
             ├── Core ML inference  (CheerSkillTCN_v1.mlmodel)
             ├── Per-frame → segment extraction
             │     (smoothing, thresholding, min-duration)
             └── [AtomSegment]
                     ↓
             CompositionStateMachine
                     ↓
             [ClassifiedPass]
                     ↓
             Integrated back into AnalysisResult as new field:
                   analysisResult.classifiedPasses: [ClassifiedPass]
```

### `SkillClassificationService` (new)

```swift
final class SkillClassificationService {
    private let model: CheerSkillTCN_v1
    private let featureBuilder = TCNFeatureBuilder()

    init() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        self.model = try CheerSkillTCN_v1(configuration: config)
    }

    func classify(frames: [FrameAnalysis], mode: AnalysisMode) async throws -> [AtomSegment] {
        guard mode == .tumbling else { return [] }  // v1 tumbling only
        guard frames.count >= 32 else { return [] } // below min input size

        // Build feature tensor [1, 62, T]
        let tensor = try featureBuilder.buildTensor(from: frames)

        // Run Core ML
        let output = try await model.prediction(pose_features: tensor)
        let atomLogits = output.atom_logits           // [1, 13, T]
        let bodylineLogits = output.bodyline_logits   // [1, N_bodylines, T]

        // Per-frame softmax → atom probabilities
        let atomProbs = softmax(atomLogits, axis: 1)
        let bodylineProbs = softmax(bodylineLogits, axis: 1)

        // Segment extraction: smooth → threshold → min-duration filter
        return extractSegments(
            atomProbs: atomProbs,
            bodylineProbs: bodylineProbs,
            smoothingWindow: 5,
            minConfidence: 0.5,
            minDurationFrames: 8
        )
    }
}
```

### `TCNFeatureBuilder` (new)

Converts a `[FrameAnalysis]` sequence into the exact 62-channel tensor the TCN expects.

```swift
struct TCNFeatureBuilder {
    func buildTensor(from frames: [FrameAnalysis]) throws -> MLMultiArray {
        let T = frames.count
        let tensor = try MLMultiArray(shape: [1, 62, T as NSNumber],
                                       dataType: .float32)
        for (t, frame) in frames.enumerated() {
            guard let skeleton = frame.flyerSkeleton else {
                // zero-fill for frames with no detection
                zero(tensor, time: t)
                continue
            }
            // 17 keypoints × (x, y, confidence)
            writeKeypoints(tensor, time: t, keypoints: skeleton.keypoints)
            // 11 derived features from shared KinematicFeatures module
            let derived = KinematicFeatures.compute(from: skeleton, prev: prev(t), fps: 30)
            writeDerived(tensor, time: t, derived: derived)
        }
        return tensor
    }
}
```

### `extractSegments` post-processing

```swift
func extractSegments(
    atomProbs: [[Double]],       // [13][T]
    bodylineProbs: [[Double]],
    smoothingWindow: Int,
    minConfidence: Double,
    minDurationFrames: Int
) -> [AtomSegment] {
    // 1. Temporal median filter on per-frame argmax
    let smoothedLabels = medianSmooth(atomProbs: atomProbs, window: smoothingWindow)

    // 2. Group consecutive frames with same label into spans
    let spans = groupConsecutive(smoothedLabels)

    // 3. Filter spans by min duration
    let filteredSpans = spans.filter { $0.length >= minDurationFrames }

    // 4. Filter spans by min mean confidence
    let confidentSpans = filteredSpans.filter {
        meanConfidence(atomProbs, atom: $0.label, range: $0.range) >= minConfidence
    }

    // 5. Drop background-labeled spans (they're not skills)
    let skillSpans = confidentSpans.filter { $0.label != .background }

    // 6. Attach bodyline-at-peak for each span
    return skillSpans.map { span in
        AtomSegment(
            atom: span.label,
            startFrame: span.startFrame,
            endFrame: span.endFrame,
            confidence: meanConfidence(atomProbs, atom: span.label, range: span.range),
            bodylineAtPeak: peakBodyline(bodylineProbs, in: span.range)
        )
    }
}
```

### `CompositionStateMachine` (new)

A pure Swift rules engine. No ML, no hardcoded vocabulary. Reads atom tags from a `VocabularyRegistry` (loaded from Core ML model metadata at init). Implements R1–R7 from the Composition Rules section above.

```swift
struct CompositionStateMachine {
    let config: CompositionConfig
    let vocabulary: VocabularyRegistry

    func compose(segments: [AtomSegment]) -> [ClassifiedPass] {
        // R5, R6: pre-filter (done in extractSegments, but defensive here)
        let valid = segments
            .filter { $0.confidence >= config.minAtomConfidence }
            .filter { $0.endFrame - $0.startFrame >= config.minAtomDurationFrames }

        // R1: split into passes on gaps > maxSkillGapFrames
        let passSegments = splitByGaps(valid, maxGap: config.maxSkillGapFrames)

        // R2, R3, R4: per-pass composition
        return passSegments.map { composePass($0) }
    }

    private func composePass(_ segments: [AtomSegment]) -> ClassifiedPass {
        // R2: running if first atom carries the `entry` tag in the manifest
        let firstAtom = segments.first!.atom
        let isRunning = firstAtom.hasTag("entry")

        // R3: collapse repetitions by atom id
        let runs = runLengthEncode(segments.map { $0.atom.id })

        // R4: build label string from display names
        let label = buildLabel(runs: runs, isRunning: isRunning, vocabulary: vocabulary)

        // Summary derived values
        let totalTwist = sumTwistDegrees(segments)
        let peakInversionFrame = findPeakInversionFrame(segments)

        return ClassifiedPass(
            startFrame: segments.first!.startFrame,
            endFrame: segments.last!.endFrame,
            atoms: segments,
            label: label,
            isRunning: isRunning,
            totalTwistDegrees: totalTwist,
            peakInversionFrame: peakInversionFrame
        )
    }
}

struct CompositionConfig {
    var maxSkillGapFrames: Int = 30
    var minAtomConfidence: Double = 0.5
    var minAtomDurationFrames: Int = 8
}
```

### Integration point in `TumblingProcessingPipeline`

The existing `TumblingProcessingPipeline.process(videoURL:)` currently returns `AnalysisResult`. It gets a new final stage:

```swift
func process(videoURL: URL) async throws -> AnalysisResult {
    // ... existing stages (pose extraction, interpolation, COM, etc.) ...
    var result = // existing result construction

    // NEW: skill classification
    if result.mode == .tumbling {
        let classifier = try SkillClassificationService()
        let segments = try await classifier.classify(frames: result.frames, mode: .tumbling)
        let composer = CompositionStateMachine(config: .default)
        result.classifiedPasses = composer.compose(segments: segments)
    }

    return result
}
```

New field on `AnalysisResult`:
```swift
struct AnalysisResult: Codable {
    // ... existing fields ...
    var classifiedPasses: [ClassifiedPass] = []
}
```

### UI exposure in FlightFilter

Out of scope for this spec — the design doc covers the classification engine only. A follow-up UI design will cover:
- Pass labels shown on the playback timeline as markers
- Tap a marker to scrub to that pass
- Pass label overlay during playback
- Per-atom form feedback (uses bodyline labels at peak)

## Testing and evaluation

### Unit tests

**Python (`training_pipeline/`):**
- `kinematic_features.py` — golden-value tests against known pose inputs (e.g., T-pose → inversion=false, body_angle=0°; upside-down → inversion=true, body_angle=180°)
- `procedural_variation.py` — each transformation is invertible where applicable (mirror twice = identity); body-proportion scaling preserves relative proportions
- `noise_augment.py` — noise statistics match configured distributions over large samples; no NaNs or infs introduced
- Schema parser — rejects unknown `schema_version`, rejects malformed keypoints, accepts valid v1

**Swift (`CheerCOM.SkillAnimator`):**
- Keyframe interpolation — SLERP between two known rotations produces expected intermediate
- Timeline operations — add/move/delete keyframes, timeline invariants preserved
- Orbital camera sampler — emits exactly 96 samples, azimuths and elevations match the grid
- JSON export — round-trips through encode/decode preserving all fields
- Bodyline label propagation from nearest keyframe

**Swift (`FlightFilter`):**
- `TCNFeatureBuilder` — produces 62-channel tensor of expected shape from a sample `[FrameAnalysis]`
- `KinematicFeatures` Swift implementation — matches Python golden values numerically (tolerance 1e-4)
- `extractSegments` — known per-frame probability sequences produce expected segment lists, minimum-duration filter works
- `CompositionStateMachine` — each rule R1 through R7 has dedicated tests with synthetic `AtomSegment` inputs and expected `ClassifiedPass` outputs
- Composition examples table (Section "Composition rules") is a parameterized test suite

### Integration tests

- **Synthetic end-to-end:** a known CheerCOM JSON export is piped through the Python pipeline → training happens (tiny subset) → Core ML export → loaded in a Swift XCTest → inference produces expected atoms
- **Real end-to-end:** a handful of curated FlightFilter recordings with hand-labeled passes serve as a regression set. Every v1+ trained model is evaluated against this set before being considered a candidate for shipping.

### Golden regression set

A directory `training_pipeline/tests/golden/` holds:
- 10–20 short real FlightFilter recordings with hand-labeled atom sequences
- Expected `[ClassifiedPass]` output for each
- An `evaluate.py --golden` mode that runs the full pipeline and diffs against expected

Any change to the model or composition rules must not regress this set without conscious acknowledgment.

### Model evaluation metrics

Already listed under TCN training section. Summary:
- Atom macro-F1 (primary)
- Atom per-class F1
- Confusion matrix
- Segment-level IoU
- Bodyline auxiliary macro-F1

### Success criteria for v1 ship

| Criterion | Target |
|---|---|
| Stage 1 (synthetic) atom macro-F1 | ≥ 0.90 |
| Stage 2 (real fine-tune) atom macro-F1 | ≥ 0.70 |
| Stage 2 segment IoU | ≥ 0.60 |
| Golden regression set passes | 100% (any regression must be investigated before merge) |
| Inference latency on iPhone 15 Pro | < 50ms per 5-second clip |
| Core ML model size | < 5 MB |
| CheerCOM authoring usable on iPad during a sitting | Author 1 complete animation in ≤ 15 minutes |

## Risks and open questions

### Risks

1. **Sim-to-real gap is larger than noise augmentation can close.** Mitigation: Stage 2 real fine-tune. Fallback: increase noise aggressiveness iteratively using the golden set as feedback.
2. **Authored animations are not physically plausible enough** (e.g., CoM trajectory wrong during airborne phase → model learns impossible motion). Mitigation: CheerCOM's existing CoM validation harness runs on each authored animation during preview; warning shown if CoM trajectory during inverted phases is implausible.
3. **Core ML variable-length input failures** on older iOS versions or specific tensor shapes. Mitigation: test export on device early (during TCN development, not at the end).
4. **SceneKit 3D → 2D projection doesn't match YOLO's coordinate conventions** (Y-axis direction, origin placement). Mitigation: build a Swift test that projects a known pose through both paths and compares.
5. **Authoring burden exceeds patience.** If 60 animations feels like too much, the model is still trainable on fewer but accuracy drops. Mitigation: prioritize the most common tumbling atoms first and ship a reduced v1, expanding later. Because vocabulary is data-driven, "shipping v1 with fewer atoms" is zero code effort — just train on whatever the manifest currently contains.
6. **Vocabulary drift between manifest and deployed model.** If the manifest is edited after training but before the new model ships, runtime inference references IDs the deployed model doesn't produce. Mitigation: every trained Core ML model embeds the hash of the manifest that produced it; `SkillClassificationService` rejects model/manifest pairs with mismatched hashes and falls back to the previous model version.
7. **Atom rename or delete breaks historical animations.** If the user renames `back_handspring` → `bhs`, any exported JSON files referencing the old ID become orphaned. Mitigation: CheerCOM's Vocabulary Management panel performs rename operations as a migration (updates manifest + rewrites all JSON files in `training_data/raw/` that reference the old ID). Delete operations warn and offer to re-tag orphaned animations before removing the atom.
8. **Tag taxonomy bloat.** If the user creates many ad-hoc tags, composition rules become unpredictable. Mitigation: CheerCOM UI surfaces the core v1 tag vocabulary as checkboxes and treats custom tags as a power-user free-text field. Custom tags are ignored by composition rules that don't know them.

### Open questions

1. **Should bodyline labels be per-keyframe or per-frame-dense at authoring time?** Spec assumes per-keyframe (propagated to adjacent frames). Alternative: per-frame-dense during authoring would require a new UI.
2. **Exact TCN hidden channel count.** Spec says 128; 64 or 96 might be enough for this data volume. Tune during implementation.
3. **Should the training pipeline also accept raw video input** (run YOLO internally, then train) to simplify the Stage 4 real fine-tune workflow? Probably yes as a convenience script, but not in the core pipeline.
4. **iCloud Drive vs manual file transfer** for CheerCOM → Mac handoff. iCloud is simpler but has sync latency. Decided at implementation time based on whether iCloud reliability is acceptable.
5. **Model versioning in FlightFilter.** Should the app support multiple model versions simultaneously (A/B compare) or just the latest? Probably just latest for v1, with a flag to roll back.

## Future extensions (v2+, not designed here)

### Stunt group classification

The v1 architecture is designed to support multi-person stunt classification without rework:
- Keypoint schema `persons` array accepts multiple people per frame
- `SkillClassificationService` uses a model registry: load `CheerSkillTCN_stunts_v1.mlmodel` when `mode == .stuntGroup`
- `CompositionStateMachine` has a separate stunt rule set, same interface
- `CheerCOM.SkillAnimator` extends to multi-character scenes (drop multiple rigs into the SceneKit scene, pose them together)

Stunt atom vocabulary sketch: `extension_press, prep, tick_tock, full_up, half_up, cradle_dismount, rewind, full_down, ...` (~15–20 atoms sourced from existing rage_tags/SSX/Navy vocabulary).

Stunt-specific features beyond the single-person feature vector:
- Inter-person distances (base hands ↔ flyer feet)
- Triangle/polygon of base positions
- Flyer CoM level relative to base hand level (ground / prep / extended)
- Connection quality score (a new auxiliary head — "hands connected" vs "loose grip" — huge for coach feedback)

### Additional tumbling variants

`whip`, `x_out`, `arabian`, `back_handspring_stepout`, `punch_front`, etc. — add to v2 by authoring CheerCOM animations and extending the atom vocabulary. No architecture changes.

### Twist execution scoring

A follow-up spec can build a regression head on top of the TCN backbone that predicts continuous twist degrees and compares to the target (360° for full, 720° for double full). Enables coach feedback like "your full was under-rotated by 40°."

### Live / streaming inference

Currently v1 is post-processing. A future iteration could run the TCN on sliding windows of incoming pose data during recording, with causal padding, to enable real-time feedback during practice. Requires retraining with causal convolutions.

## Appendix A — Glossary

- **Atom:** a single tumbling skill (back handspring, round-off, etc.); the classifier's output vocabulary
- **Bodyline:** cheer-specific term for aesthetic body shape (tuck, layout, pike, inverted-straight, etc.)
- **Composition:** the rule-based derivation of pass-level labels from an atom sequence
- **Pass:** a contiguous sequence of tumbling atoms performed without significant pause
- **TCN:** Temporal Convolutional Network
- **COCO 17:** the 17-point keypoint convention used by YOLO pose models and Apple Vision
- **SLERP:** Spherical Linear Interpolation of rotation quaternions
- **Running pass:** a tumbling pass initiated with a running entry skill (round-off, cartwheel, etc.)
- **Standing pass:** a tumbling pass initiated from stationary position

## Appendix B — File creation / modification summary

### New Swift files (CheerCOM)

- `Views/SkillAnimatorView.swift`
- `Views/SkillTimelineView.swift`
- `Views/KeyframeBarView.swift`
- `Views/VirtualCameraPanel.swift`
- `Managers/SkillAnimationStorage.swift`
- `Managers/SkillAnimationExporter.swift`
- `Managers/OrbitalCameraSampler.swift`
- `Models/SkillAnimation.swift`
- `Models/SkillKeyframe.swift`
- `Models/BodylineLabel.swift`
- `Models/VocabularyManifest.swift`
- `Managers/VocabularyManager.swift` — load/save manifest, add/rename/delete atoms and bodylines, propagate changes to existing animations
- `Views/VocabularyManagementView.swift` — UI panel listing atoms and bodylines with add/rename/delete/edit-tags actions

### Modified Swift files (CheerCOM)

- `CheerCOMApp.swift` — add mode switcher for Pose/Animator
- `Views/PoseLibraryPanel.swift` — support bodyline label tagging
- `Managers/PoseStorageManager.swift` — persist bodyline field
- `Managers/PosePresets.swift` — seed library with common tumbling keyframes

### New Swift files (ModelRigKit)

- `Sources/ModelRigKit/KinematicFeatures.swift` — shared feature computation
- `Tests/ModelRigKitTests/KinematicFeaturesTests.swift`

### New Swift files (FlightFilter)

- `Services/SkillClassificationService.swift`
- `Services/TCNFeatureBuilder.swift`
- `Services/CompositionStateMachine.swift`
- `Services/VocabularyRegistry.swift` — loads atoms, bodylines, tags from Core ML model metadata
- `Models/AtomSegment.swift`
- `Models/ClassifiedPass.swift`
- `Models/Atom.swift` — dynamic struct, not an enum
- `Models/Bodyline.swift` — dynamic struct, not an enum

### Modified Swift files (FlightFilter)

- `Services/TumblingProcessingPipeline.swift` — add classification stage
- `Models/FrameAnalysis.swift` — add `classifiedPasses` to `AnalysisResult`
- `Resources/` — add `CheerSkillTCN_v1.mlmodel` via build phase

### New Python files (`training_pipeline/`)

- `ingest_cheercom_exports.py`
- `kinematic_features.py`
- `procedural_variation.py`
- `noise_augment.py`
- `background_mining.py`
- `build_dataset.py`
- `train_tcn.py`
- `fine_tune_real.py`
- `evaluate.py`
- `export_coreml.py`
- `configs/v1_training.yaml`
- `requirements.txt`
- `run_all.sh`
- `tests/test_kinematic_features.py`
- `tests/test_variation.py`
- `tests/test_noise.py`
- `tests/test_schema.py`
- `tests/golden/` — regression set

### Build artifacts (checked in)

- `CoreMLModels/CheerSkillTCN_v1.mlmodel`

### Gitignored

- `training_data/raw/*.json` (large, generated offline)
- `training_data/augmented/*.npz`
- `training_pipeline/training_runs/`
