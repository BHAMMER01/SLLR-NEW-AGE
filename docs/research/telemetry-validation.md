# Runtime telemetry validation

`capture_runtime_telemetry.ps1` runs the Vulkan city benchmark in a private
copy of the game root and samples the host process every 250 ms. It records
process CPU time, working-set RAM and thread count alongside the engine's
frametime/GPU CSV. It does not modify the production game or executable.

The collector is intentionally external: Windows process counters are reliable
for attribution, while the engine CSV remains authoritative for subsystem
timings. GPU adapter utilization is not synthesized when Windows does not
expose a stable per-process counter.

Example:

```powershell
.\scripts\capture_runtime_telemetry.ps1 -DriveSeconds 20
```

Outputs are written under `build/verification/telemetry/` and include a process
CSV, the engine perf CSV, stdout/stderr and a JSON summary.

The captured 15.73-second run consumed 50.91 CPU-seconds, equivalent to about
323.7% average logical-CPU utilization, and reached 59 host threads. This is
evidence that the host is not restricted to a single CPU core; the remaining
problem is per-frame scheduling/render/physics cost, not a one-core-only limit.
