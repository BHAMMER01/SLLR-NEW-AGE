# Physics validation against external references

Date: 2026-11-25

## Scope

This pass compares the New Age native physics surface with the local
`sl-remastered` and `street-legal` checkouts. It is an audit and validation
plan; no production physics was changed.

## Findings

New Age already has native modules for vehicle dynamics, contacts, suspension
geometry, tyres, Pacejka, wheel mounting, mass properties, deformation and
dyno modelling (`src/physics/`). It also has focused tests for dynamics,
contacts, mass, tick rate, recovery, wheel mounting and suspension-related
behavior under `tests/`.

`sl-remastered` provides the strongest reusable testing ideas: independent
wheel geometry/runtime tests, suspension probes, friction and solver tests,
mesh-mass tests, and evidence JSON files. It is a macOS ARM64 port and is not
a drop-in implementation for the Windows/bgfx host.

`street-legal` provides a separate Rust physics implementation plus oracle
probes and configuration decoders for vehicle, wheel, tyre and part data. It is
valuable for fixture design and cross-checking decoded values, but its solver
and units must not be assumed equivalent to New Age.

## Checks performed

- Static inventory confirmed New Age physics modules and the existing focused
  test suite.
- Static inventory confirmed external suspension, wheel, tyre, friction,
  vehicle and oracle test sources.
- Release host build was previously verified successfully during this review
  (`build/Release/slrr_host.exe`).
- The C++ toolchain was used to build the existing deterministic vehicle
  fixture manually. The command compiled `tests/test_vehicle_dynamics.cpp`
  with `src/physics/vehicle_dynamics.cpp`, `tire_model.cpp` and
  `suspension_geometry.cpp` into `build/verification/test_vehicle_dynamics.exe`.
  The executable passed **35 tests, 0 failures**. Its deterministic diagnostics
  reported Nitro dry/wet/unavailable speeds of 16.765/23.479/16.765 m/s,
  aero side-force slope 0.0396 per degree, wind mean 6.036 m/s, and only
  0.0045 m displacement for a braked car in a 15 m/s crosswind.

  This validates the current standalone dynamics fixture; it is not yet a
  complete city-runtime benchmark.

## Recommended next validation

1. Add a headless physics-test target that runs the existing `tests/test_*`
   fixtures without launching the game.
2. Export one deterministic vehicle fixture (mass, centre of mass, wheel
   positions, spring/damper, tyre inputs and timestep).
3. Run that fixture through New Age and compare only observable outputs:
   position, velocity, wheel load, suspension travel and yaw/pitch/roll.
4. Use the `sl-remastered` and `street-legal` probes as independent references,
   recording unit conversions and tolerances in the fixture metadata.
5. After numerical parity is understood, profile the real city run to separate
   physics cost from rendering, scripts and streaming cost.

## Decision

The external projects add valuable test methodology and reference data, not a
safe drop-in replacement. The next actionable deliverable is a deterministic,
headless New Age physics harness and one cross-project fixture.
