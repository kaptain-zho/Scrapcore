# Scrapcore Prototype Asset Standards

## Purpose and audited gameplay envelope

These standards keep prototype robots readable, interchangeable, and safe to attach to the existing movement controller. They apply to Asset Sprint 0 and should be revised only when a tested gameplay requirement changes.

The current playable robot uses a `5 x 1.5 x 7` stud chassis (`X x Y x Z`). Its camera offset is `(0, 34, 26)` studs and it looks toward a point `0.5` studs above the robot root, producing an approximately `52.2` degree downward angle below horizontal. Asset reviews must include this gameplay view, not only close-up editor views.

## Coordinate and facing convention

- Roblox `LookVector` (`-Z`) is always the robot's front.
- `+Y` is up and `+X` is the robot's right side.
- Front armor, weapon mounts, headlights, and directional details face `-Z`. Rear components, exhausts, batteries, and vulnerable details face `+Z`.
- Models must not rely on an unexplained 90- or 180-degree rotation at runtime. Correct facing in the source asset.

## Scale and bounding boxes

- The gameplay collision footprint remains exactly `5 x 1.5 x 7` studs unless a gameplay change explicitly updates `MovementConfig`.
- The visual chassis base should read as approximately `5` studs wide and `7` studs long from above.
- Decorative bodywork may extend at most `0.75` studs beyond each side of the collision footprint.
- Excluding removable weapons, the complete visual robot must fit inside a `6.5 x 4.5 x 8.5` stud box centered on the robot pivot.
- A mounted prototype weapon may extend the total length to `11` studs but must not silently enlarge gameplay collision.
- Avoid thin details below `0.15` studs; they disappear at the current camera distance and add unnecessary geometry.

## Pivot and PrimaryPart conventions

- Every robot asset is a `Model` with a transparent `RobotRoot` part as its `PrimaryPart`.
- `RobotRoot` uses the gameplay chassis size (`5 x 1.5 x 7` studs), identity rotation, and a pivot at the chassis center. Its local `LookVector` points toward the robot front (`-Z`).
- Visual and collision geometry is positioned relative to `RobotRoot`; scripts should move the model through its pivot rather than searching for arbitrary descendants.
- `RobotRoot` is non-rendered, `CanCollide=false`, and `Massless=true`. It is a placement and attachment reference, not extra collision.
- AssetLab models may be anchored for inspection. Runtime versions must be welded deliberately and unanchored as required by the gameplay rig.
- A removable prop is its own `Model` with a named root part and a meaningful pivot at its grip or attachment point.

## Hierarchy and naming

Use PascalCase for instances and this organization:

```text
Robot_<Variant> [Model]
|-- RobotRoot [Part, PrimaryPart]
|   `-- FrontWeaponMount [Attachment]
|-- Visuals [Folder]
|   |-- Chassis [Folder]
|   |-- Mobility [Folder]
|   |-- Armor [Folder]
|   `-- TeamPanels [Folder]
|-- Collision [Folder]
|   `-- BodyCollision [Part]
`-- Props [Folder]
    `-- Hammer_Prototype [Model]
        |-- HammerRoot [Part, PrimaryPart]
        `-- Visuals [Folder]
```

- Names describe function before decoration: `FrontBumper`, `LeftTrackHousing`, `RearBattery`, and `TeamPanelLeft` are preferred over generic names such as `Part1`.
- Use `Left` and `Right` from the robot's point of view while it faces `-Z`.
- Team-recolorable geometry belongs under `Visuals.TeamPanels` and uses the `TeamPanel` name prefix.
- Collision parts belong only under `Collision`; weapon previews and removable props belong only under `Props`.
- Do not put scripts, remotes, gameplay state, or imported Toolbox/free-model content inside art assets.

## Visual and collision geometry

- Visual geometry and collision geometry are separate.
- Every visual `BasePart` must use `Massless=true`, `CanCollide=false`, `CanTouch=false`, and `CanQuery=false` unless a documented gameplay system specifically needs queries.
- Visual geometry must never become an authoritative hitbox merely because it resembles armor or a wheel.
- Collision geometry should use the fewest simple primitives possible. The prototype robot uses one `BodyCollision` box matching the `5 x 1.5 x 7` gameplay envelope.
- Collision geometry is transparent in production, has no decorative children, and is the only geometry eligible for gameplay collision or overlap validation.
- Team panels change color independently of armor and chassis materials. Recoloring must not require renaming parts or changing collision.

## Universal front weapon attachment

- Every robot provides one `Attachment` named `FrontWeaponMount` directly under `RobotRoot`.
- Its local position is `(0, 0.35, -3.5)`, centered on the front plane of the gameplay chassis.
- Its rotation is identity: `LookVector=-Z` and `UpVector=+Y`.
- A compatible weapon uses a root named `WeaponRoot`, faces `-Z`, and places its pivot at the mounting interface.
- Weapon visuals may overlap a small standardized collar around the mount, but they must not assume a particular chassis decoration.
- Runtime attachment, hit detection, damage, cooldowns, and rewards remain server-authoritative. The attachment is only a spatial contract.

## Prototype budgets

- Hard maximum: fewer than `40` `BasePart` instances for the complete displayed robot, including collision and removable weapon props. Target `32` or fewer.
- Target body budget: `28` parts or fewer. Target removable weapon budget: `6` parts or fewer.
- Use no more than `4` Roblox materials per robot, including its weapon preview. Prefer `Metal`, `SmoothPlastic`, `DiamondPlate`, and sparing `Neon` accents.
- Use at most `2` Neon parts and keep them small enough that they do not overpower team-color readability.
- Asset Sprint 0 uses primitives only: no meshes, unions, textures, decals, surface appearances, Toolbox assets, or free models.
- Repeated wheels, track pads, bolts, and armor details must earn their part cost in the gameplay camera. Remove details that do not improve silhouette, facing, team recognition, or damage readability.

## Review checklist

- Front reads clearly as `-Z` from both top-down and three-quarter views.
- Body respects the collision footprint and visual bounding-box limits.
- `RobotRoot` is the `PrimaryPart`; pivots and named attachments are correct.
- Visual parts are massless and non-colliding; collision is simple and separate.
- Team panels can be recolored without touching other geometry.
- Front weapon mount accepts a standard prop without per-chassis offsets.
- Part and material budgets pass.
- The asset remains readable with the current gameplay camera.
- Existing movement and respawn behavior still pass in Studio with no console errors or warnings.
