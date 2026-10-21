<<<<<<< HEAD
# Satellite Orbit Simulator — Godot 4 Edition

A real-time, physically-grounded satellite orbit visualizer built in
Godot 4 / GDScript, styled after mission-analysis software (the kind
of tool an ops room or an aerospace engineering course would use), rather
than a game. This is a ground-up rebuild of an earlier Pygame prototype —
no Pygame code was ported. Rendering, UI, camera, and physics were all
redesigned around Godot's own systems (Node3D scene graph, spatial
shaders, `WorldEnvironment` HDR pipeline, `Control` UI).

---

 1. Installation

Requirements: Godot 4.3 or later (Forward+ renderer). No plugins, no
external assets, no internet connection needed — everything, including
Earth's surface, the starfield, and the atmosphere, is generated
procedurally by shaders and code at runtime.

1. Open Godot 4.
2. Import → select this project's `project.godot`.
3. Press F5 (or the ▶ Play button). `Main.tscn` is the entry scene.

No build step, no missing-texture errors, no setup beyond opening the
project.

---

 2. Controls

| Input | Action |
|---|---|
| Left-click + drag | Orbit the camera around the current focus point |
| Right-click + drag | Pan the focus point |
| Scroll wheel | Zoom in / out |
| **LAUNCH** button | Start propagating the loaded mission |
| **PAUSE / RESUME** button | Halt or continue the simulation clock |
| **RESET** button | Reload the current mission from its initial elements |
| **CAMERA** button | Cycle Free Orbit → Focus Earth → Focus Satellite → Cinematic |
| **SCREENSHOT** button | Save a PNG of the current view to `user://screenshots/` |
| **EXPORT DATA** button | Save a CSV telemetry snapshot to `user://exports/` |
| Simulation speed slider | Scale simulated seconds per real second (1×–2000×) |
| Mission preset dropdown | Load a different orbit regime |

`user://` resolves to Godot's per-project user data directory (on
desktop this is typically under your OS's app-data folder for the
project).

---

 3. Features

- Procedural Earth — no texture files. A single spatial shader
  (`shaders/earth.gdshader`) layers value-noise continents, oceans,
  polar ice, animated clouds, a day/night terminator, and emissive city
  lights on the dark side.
- Atmosphere glow — a front-face-culled, slightly oversized sphere
  with a Fresnel-driven additive shader (`shaders/atmosphere.gdshader`)
  produces the limb-glow "atmospheric scattering" look.
- Procedural starfield + nebula sky — `shaders/starfield_sky.gdshader`
  drives the `WorldEnvironment`'s sky, generating stars and soft nebula
  bands from hashed noise (no skybox image).
- HDR lighting / bloom — configured in `scenes/default_env.tres`:
  ACES tonemapping, glow/bloom, and a subtle contrast/saturation grade.
- Original satellite model — assembled from primitives in
  `scripts/satellite.gd`: a hex-profile metallic bus, MLI thermal wrap,
  two solar-panel wings with emissive cell-grid striping, a parabolic
  dish + whip antennas, and four attitude-control thruster nozzles plus
  a main engine bell. Not a copy of any real spacecraft.
- Orbit trail + predicted path — the satellite leaves a fading
  cyan trail of where it's been; `OrbitRenderer` separately draws the
  full analytic ellipse of where it's *going*.
- Newtonian orbital mechanics — see §4.
- Seven mission presets — LEO (ISS-class), MEO (GPS-class), GEO,
  Polar, Sun-Synchronous, Molniya (highly elliptical), and an Escape
  Trajectory, each with physically representative altitude,
  inclination, and eccentricity.
- Professional dark UI — glass-panel styling, mission-control color
  language (electric cyan / mission green / warning amber / critical
  red), live telemetry, and an escape-trajectory warning banner.
- Screenshot & CSV telemetry export, driven straight from the UI.

---

 4. Physics

Two propagation modes are used, matching how real mission tools
distinguish stable orbits from escape trajectories:

Closed orbits (e < 1):** propagated analytically via classical
orbital elements. Each simulated step advances the mean anomaly
linearly (`M = M₀ + n·t`, where `n` is the mean motion,
`n = √(μ / a³)`), then recovers the *eccentric anomaly* by solving
Kepler's equation `M = E − e·sin(E)` with Newton–Raphson iteration, and
finally the true anomaly from `E`. The true anomaly plus the six
classical elements (`a, e, i, Ω, ω, ν`) are converted to a Cartesian
state vector via the standard perifocal-to-inertial rotation. This is
exact for the unperturbed two-body problem — no drift, no integration
error, at any simulation speed.

Escape trajectories (e ≥ 1): once a mission crosses escape
velocity, the analytic ellipse no longer applies, so the simulator
switches to direct numerical integration — 4th-order Runge–Kutta
(RK4) on Newton's law of gravitation, `a = −μ·r / |r|³` — which
remains valid for parabolic/hyperbolic paths.

All physics runs in SI units (meters, seconds, kilograms) against
Earth's real mass, radius, and gravitational parameter
(`μ = G·M_Earth ≈ 3.986 × 10¹⁴ m³/s²`); only the render layer scales
the resulting positions down for the viewport
(`scripts/constants.gd → RENDER_UNITS_PER_METER`). Telemetry —
altitude, speed, orbital period, apogee/perigee, eccentricity,
inclination, and ground-track latitude/longitude — is derived from
that same physical state each frame (`sim_state.gd → get_telemetry()`),
so displayed numbers are never separately approximated for the UI.

---

 5. Folder structure

```
project.godot
scenes/
    Main.tscn              # top-level orchestrator
    Earth.tscn              # procedurally shaded planet + atmosphere shell
    Satellite.tscn           # procedural spacecraft model + trail
    OrbitRenderer.tscn        # analytic orbit ellipse line
    CameraController.tscn      # orbit / pan / zoom rig
    UI.tscn                   # header + panel layout (CanvasLayer)
    MissionControl.tscn        # mission select + run controls
    TelemetryPanel.tscn         # live telemetry readout
    default_env.tres           # WorldEnvironment: sky, glow, tonemap
scripts/
    constants.gd     (autoload) physical constants, palette, mission presets
    sim_state.gd      (autoload) simulation state machine & physics step
    orbit_math.gd                 pure Kepler / two-body math library
    earth.gd, satellite.gd, orbit_renderer.gd, camera_controller.gd,
    ui.gd, mission_control.gd, telemetry_panel.gd, ui_theme.gd, main.gd
shaders/
    earth.gdshader            procedural surface (land/ocean/clouds/night)
    atmosphere.gdshader        Fresnel rim-glow shell
    starfield_sky.gdshader     procedural stars + nebula sky
assets/
    icons/icon.svg
```

Architecture notes: each `.tscn` is a thin root node carrying a
single script that builds and owns its own children in code
(`_ready()`), rather than hand-authored node trees — this keeps every
visual component self-contained, reusable, and diff-friendly, and
avoids brittle scene files full of magic sub-resource references.
Simulation state and physics live entirely in the `SimState` autoload;
every visual script *reads* from it and never computes orbital
mechanics itself, so physics stays correct regardless of which visuals
are enabled. `Constants` and `OrbitMath` are stateless and
independently testable.

---

 6. Known limitations / next steps

- Only two-body Newtonian gravity is modeled; J2 oblateness and drag
  constants are defined (`Constants.EARTH_J2`,
  `Constants.ATMOSPHERE_DRAG_ALTITUDE` equivalents) but not yet applied
  to propagation — a natural next step for a more advanced perturbation
  model.
- The Earth surface is procedural, not photographic — swapping in a real
  albedo/night-lights texture pair is a drop-in change to
  `earth.gdshader` (replace the noise-based `surface`/`night_lights`
  terms with texture samples) if real imagery is available.
- Multi-satellite / constellation support is not implemented; the
  architecture (SimState driving stateless visual scenes) supports it
  by instancing additional Satellite/OrbitRenderer pairs against
  per-satellite state.
=======
 satellite-orbit-simulator
>>>>>>> 7ce04968b779db39267df6c1cda781a286b18d52
