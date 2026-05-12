# CheerCOM Learnings

## 2026-04-07 — CheerCOMSceneManager requires explicit loadCharacter()/frameCharacter() after init

- **Category:** best_practice
- **What happened:** SkillAnimatorViewController showed a black/blank screen because `setupScene()` only called `CheerCOMSceneManager(view:)` without following up with `loadCharacter()` and `frameCharacter()`. The scene manager's init only sets up lighting + ground plane — the character must be loaded separately. SceneViewController.viewDidLoad does both calls correctly (lines 82-98).
- **Rule:** Any new view controller that hosts a `CheerCOMSceneManager` must call `loadCharacter()` and `frameCharacter()` after init, or the viewport will render black. Init alone does not load the character model.

## 2026-04-07 — xcodebuild -exportArchive fails with "Copy failed" when MacPorts rsync shadows Apple's

- **Category:** correction
- **What happened:** `xcodebuild -exportArchive` failed at `IDEDistributionCreateIPAStep` with `Error Domain=IDEFoundationErrorDomain Code=1 "Copy failed"`. Pipeline log showed `rsync: on remote machine: --extended-attributes: unknown option` and `server=3.4.1`. Root cause: `/opt/local/bin/rsync` (MacPorts GNU rsync 3.4.1) was ahead of `/usr/bin/rsync` (Apple openrsync 2.6.9) in PATH. openrsync uses `-E`/`--extended-attributes`, which GNU rsync doesn't recognize, so when openrsync spawned the "server" side via PATH it picked up GNU rsync and rejected the flag.
- **Rule:** When building/uploading to TestFlight, always run `xcodebuild -exportArchive` with `PATH=/usr/bin:$PATH` prepended so both sides of any rsync invocation use Apple's openrsync. Applies to any Mac with MacPorts or Homebrew rsync installed.
