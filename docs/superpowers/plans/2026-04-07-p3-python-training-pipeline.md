# P3 — Python Training Pipeline Plan (compressed)

> **For agentic workers:** Use superpowers:executing-plans. Checkbox (`- [ ]`) steps.

**Goal:** Python pipeline that ingests CheerCOM JSON exports → augments (procedural variation + noise) → trains a multi-task TCN → fine-tunes on real Tumble set clips → exports Core ML.

**Architecture:** Eight scripts under `training_pipeline/` in the CheerCOM monorepo, driven by `configs/v1_training.yaml`, chained by `run_all.sh`. PyTorch 2.x + coremltools 7+. Runs on Apple Silicon MPS.

**Working dir:** `/Users/ianrichardson/Projects/CheerCOM/training_pipeline`

---

## File map

```
training_pipeline/
├── configs/v1_training.yaml    # all hyperparameters
├── kinematic_features.py       # Python port of ModelRigKit.KinematicFeatures
├── ingest_cheercom_exports.py  # JSON → IngestedAnimation dataclass
├── procedural_variation.py     # mirror, scale, speed, translate, trim
├── noise_augment.py            # jitter, dropout, L/R swap, confidence noise
├── build_dataset.py            # ingest → augment → NPZ shards
├── model.py                    # SkillTCN class (5-block dilated TCN, 2 heads)
├── train_tcn.py                # Stage 1 synthetic pretrain
├── fine_tune_real.py           # Stage 2 real fine-tune with frozen early blocks
├── evaluate.py                 # macro F1 + per-class + confusion matrix
├── export_coreml.py            # torch.jit.trace → coremltools.convert → .mlmodel
├── requirements.txt
├── run_all.sh
└── tests/
    ├── fixtures/kinematic_features_golden.json
    └── test_kinematic_features_parity.py
```

---

## Task 1: Scaffold

- [ ] Create directory, `requirements.txt` (torch, coremltools, numpy, pyyaml, tqdm, scikit-learn)
- [ ] Create `configs/v1_training.yaml` with all hyperparameters from the design spec Section 8 + 9 (seed, fps, paths, dataset.{variants_per_animation, background_fraction, val_split_fraction, train_val_stratify_by="animation_id"}, variation.{body_presets, speed_range, mirror_probability, scale_jitter, translation_jitter, form_imperfection_probability, start_end_trim_max}, noise.{keypoint_jitter_sigma: 0.006, temporal_smoothness_alpha: 0.7, brief_dropout_probability: 0.03, run_dropout_probability: 0.01, lr_swap_probability_inverted: 0.05, confidence_multiplier_range: [0.6, 1.0], confidence_noise_sigma: 0.1, orientation_wobble_sigma_deg: 2.0, per_clip_scale_sigma: 0.08, frame_drop_probability: 0.02}, model.{channels: 128, num_blocks: 5, kernel_size: 3, dropout: 0.2}, training.stage1.{epochs: 60, batch_size: 32, learning_rate: 0.001, weight_decay: 0.0001, scheduler: "cosine", early_stopping_patience: 8}, training.stage2.{epochs: 10, batch_size: 16, learning_rate: 0.0001, freeze_blocks: [0, 1]}, loss.{atom_weight: 1.0, bodyline_weight: 0.3, focal_gamma: 2.0}, export.{coreml_filename: "CheerSkillTCN_v1.mlmodel", input_name: "pose_features", minimum_deployment_target: "iOS15"})
- [ ] Create `run_all.sh` (chmod +x): `build_dataset.py` → `train_tcn.py` → `fine_tune_real.py` (if real labels dir exists) → `evaluate.py` → `export_coreml.py`
- [ ] `.gitignore`: `training_runs/ augmented/ tumble_set_labels/ __pycache__/ *.pyc .venv/`
- [ ] Commit

## Task 2: KinematicFeatures Python port + parity test

**Port contract:** Python `kinematic_features.compute(keypoints, previous, fps)` must match Swift `ModelRigKit.KinematicFeatures.compute()` to 1.0° for angles, 0.15 for CoM, 5 dps for angular velocity.

- [ ] Emit golden JSON from ModelRigKit: `swift test --filter KinematicFeaturesGoldenTests.test_emit_golden_json`, extract the block between `BEGIN/END` markers into `training_pipeline/tests/fixtures/kinematic_features_golden.json`
- [ ] Create `kinematic_features.py` with:
  - `KinematicFeatures` dataclass (11 fields matching Swift: inversion, body_angle_deg, hip_angle_deg, knee_angle_left_deg, knee_angle_right_deg, com_x_norm, com_y_norm, com_vx_norm, com_vy_norm, hip_angular_velocity_dps, shoulder_hip_twist_deg, ground_contact)
  - Helper functions: `_angle_from_vertical(dx, dy)` using `math.atan2(dx, -dy)`, `_angle_between(a, b, c)` via dot/mag, `_signed_angle_between(a, b)` via cross/dot, `_compute_com(keypoints)` using simplified 2-segment trunk (hip_mid → shoulder_mid at 0.55 blend) plus limb segments with de-Leva mass ratios from the spec
  - `compute(keypoints, previous=None, fps=30.0)` main entry
  - `to_feature_vector(features) -> List[float]` for TCN input concatenation
- [ ] Create `tests/test_kinematic_features_parity.py`: load golden JSON, assert each field within tolerance for all 3 cases (canonical T-pose, rightward shift, inverted T-pose)
- [ ] Run parity test, iterate until it passes
- [ ] Commit

## Task 3: Ingest

- [ ] Create `ingest_cheercom_exports.py` with `load_file(path)` and `load_directory(dir)`
- [ ] `IngestedAnimation` dataclass carrying: schema_version, source_file, animation_id, atom_id, category, fps, num_frames, camera_azimuth_deg, camera_elevation_deg, frames (list of `IngestedFrame` each with frame, t, keypoints=17x IngestedKeypoint, bodyline: Optional[str])
- [ ] Reject schema_version != 1; warn-and-skip on per-file parse errors (don't abort the directory load)
- [ ] v1 single-person: always read `persons[0]`
- [ ] Smoke test: `python3 ingest_cheercom_exports.py <raw_dir>` against whatever CheerCOM has produced
- [ ] Commit

## Task 4: Procedural variation + noise augmentation

- [ ] Create `procedural_variation.py`:
  - `_LR_SWAP_PAIRS` constant listing the 8 COCO left/right joint index pairs
  - `mirror_horizontal(anim)` flips X around 0.5 and swaps L/R joints
  - `scale(anim, factor)` around hip midpoint
  - `translate(anim, dx, dy)`
  - `resample_speed(anim, speed)` via `np.linspace` nearest-neighbor lookup on source frames
  - `trim_ends(anim, rng, max_trim)` drops random leading/trailing frames
  - `apply_variant(anim, rng, config)` composes one random draw using the config's `variation` section
- [ ] Create `noise_augment.py`:
  - `apply_noise(anim, rng, config)` mutates each frame's keypoints using the config's `noise` section — gaussian jitter with temporal correlation alpha=0.7, brief per-frame dropouts (low confidence), L/R joint swap on inverted frames (head y > hip mid y), confidence multiplier + per-joint noise, per-clip scale jitter around (0.5, 0.5)
- [ ] **Critical invariant:** derived features are computed AFTER noise is applied in `build_dataset.py` (Task 5), never before
- [ ] Commit

## Task 5: Dataset builder

- [ ] Create `build_dataset.py`:
  - `load_vocab(manifest_path)` reads CheerCOM's `vocabulary_manifest.json`, returns `(atom_ids, bodyline_ids)` with "background" always at atom index 0
  - `sequence_to_feature_tensor(anim)` produces (62, T) float32: 17×3 keypoints + 11 derived features computed via `kinematic_features.compute`
  - `bodyline_sequence(anim, vocab)` produces (T,) int64 with -1 for null/unknown bodylines
  - `pad_to(tensor, target_t)` pads with zeros if shorter, truncates if longer
  - Main: for each animation, produce `variants_per_animation` variants by chaining `apply_variant → apply_noise → sequence_to_feature_tensor → pad_to`
  - Write single NPZ shard `training_runs/augmented/shard_0000.npz` with keys: features (N, 62, T_max), atom_labels (N,), bodyline_labels (N, T_max), lengths (N,), animation_ids (N,)
  - Also emit `training_runs/vocabulary.json` with the final atom and bodyline lists (dynamically extended if data contains atoms not in manifest)
- [ ] Commit

## Task 6: Model + Stage 1 training

- [ ] Create `model.py` with `SkillTCN` class:
  - Stem: `Conv1d(62, 128, kernel=1)` + BN + ReLU
  - 5 residual `TCNBlock`s with dilations {1, 2, 4, 8, 16}, each = 2x (DilatedConv1d + BN + ReLU + Dropout) + residual
  - Atom head: `Conv1d(128, head_hidden, 1) + ReLU + Conv1d(head_hidden, num_atoms, 1)` → (B, C_a, T)
  - Bodyline head: same shape with num_bodylines
  - Forward returns `(atom_logits, bodyline_logits)`
- [ ] Create `train_tcn.py`:
  - `ShardDataset` wraps the NPZ by index
  - `stratified_split_by_animation(animation_ids, atom_labels, val_fraction, seed)` — split by unique animation_id, not by sample — PREVENTS VARIANT LEAKAGE
  - `focal_loss(logits, targets, weights, gamma)` for the atom head
  - `compute_class_weights(labels, num_classes)` = `1/sqrt(counts)`, normalized to mean 1
  - `train_one_epoch` does: compute atom_logits + bodyline_logits, mean-pool atom logits over valid frames via mask, compute focal loss on pooled atoms, mask-and-gather bodyline loss (ignoring -1 labels), combined loss = `1.0*atom + 0.3*bodyline`
  - Main: load shard, split, DataLoader, model, AdamW(lr=1e-3, wd=1e-4), CosineAnnealingLR, train up to 60 epochs with early stopping on val macro F1 (patience 8), save best.pt to `training_runs/stage1_synthetic_<ts>/`, symlink `stage1_latest`
  - Use MPS device on Apple Silicon
- [ ] Commit

## Task 7: Stage 2 fine-tune + evaluation

- [ ] Create `fine_tune_real.py`:
  - Exits cleanly if `tumble_set_labels/` is missing or empty (synthetic-only model still valid for v0)
  - `RealClipDataset` loads JSON clip files with shape `{clip_path, atom_id, keypoints: [[[x,y,c]x17]xT]}`, converts to (62, T_max) tensors using the same feature extractor
  - Load stage1_latest checkpoint, freeze TCN blocks 0 and 1 (`requires_grad = False`), AdamW lr=1e-4, 10 epochs
  - Save to `training_runs/stage2_finetuned_<ts>/best.pt`, symlink `stage2_latest`
- [ ] Create `evaluate.py`:
  - Loads stage2_latest (fallback stage1_latest) and the same val split used in training
  - Reports: macro F1, accuracy, sklearn `classification_report`, printed confusion matrix with atom names as headers
- [ ] Commit

## Task 8: Core ML export

- [ ] Create `export_coreml.py`:
  - Load latest checkpoint (stage2 preferred)
  - Wrap model in a small `TracedSkillTCN(nn.Module)` that returns a tuple
  - `torch.jit.trace` with shape `(1, 62, 128)` sample
  - `ct.convert(traced, inputs=[ct.TensorType(name="pose_features", shape=(1, 62, ct.RangeDim(32, 512)))], convert_to="mlprogram", compute_units=ct.ComputeUnit.ALL, minimum_deployment_target=ct.target.iOS15)`
  - Set `mlmodel.user_defined_metadata`: `atoms` = JSON-encoded atom list, `bodylines` = JSON-encoded bodyline list, `vocabulary_hash` = SHA-256 of the manifest JSON file (FlightFilter uses this to reject mismatched model/manifest pairs)
  - Save to `/Users/ianrichardson/Projects/CheerCOM/CoreMLModels/CheerSkillTCN_v1.mlmodel`
- [ ] Commit

---

## Completion checklist

- [ ] Parity test passes: `python3 tests/test_kinematic_features_parity.py`
- [ ] `pip install -r requirements.txt` succeeds
- [ ] `./run_all.sh` runs end-to-end without errors (given at least one CheerCOM export in raw_dir)
- [ ] `CoreMLModels/CheerSkillTCN_v1.mlmodel` exists and is loadable in Python via `ct.models.MLModel(path)`
- [ ] Eight commits, one per task

## Open decisions flagged to revisit in execution

- **CoM implementation fidelity:** Python port uses a simplified 2-segment trunk. If parity tolerance is too loose to catch bugs, port `PoseAdapter` + `COMCalculator` from ModelRigKit to Python in a dedicated follow-up.
- **Bodyline feature vector dimension:** spec says 11 derived features but `to_feature_vector` may emit 12 depending on whether `ground_contact` is encoded; adjust input_channels in model.py accordingly (62 → 63 if needed).
- **Real clip JSON schema:** Task 7 assumes a specific format. If CheerSkillTagger's existing format differs, add an adapter in `fine_tune_real.py` rather than changing the tagger.

## Handoff

After P3 ships, P4 (FlightFilter integration) consumes `CoreMLModels/CheerSkillTCN_v1.mlmodel` and reads its user_defined_metadata for atoms + bodylines + vocabulary_hash.
