# Runtime Body-Dependent Radial Grid Refactor

The simulation code has been fully refactored from a fixed Sun-centered radial
grid to a runtime, body-dependent radial grid. The same trajectory, bincount,
Kepler exterior arc, snapshot, heartbeat, merge, MPI, final output, and
diagnostic pipeline now works for both Sun and Earth without hard-coded solar
constants. All major numerical stability issues, including the RK45 timeout
pathology, have been resolved.

## Runtime Radial Grid

The fixed constants `R_SUN_KM`, `NUM_BINS`, `TOTAL_BINS`, and `BIN_WIDTH_KM`
were replaced by a runtime `Bincount_Radial_Grid` that builds body-specific
inner and exterior bins from the target body radius, with Earth runs using a
`0.001 R_body` inner bin width, while the legacy Sun API is preserved for
backward compatibility.

## Trajectory and Bincount

Trajectory histograms changed from fixed arrays to runtime-sized vectors, and
Hermite bincount deposition as well as Kepler exterior arc accumulation now use
the passed-in runtime grid instead of fixed Sun constants. `Trajectory_Simulator`
now holds a runtime radial grid and provides an explicit-grid constructor, with
the same grid shared across bincount deposition, Kepler exterior arcs, and
trajectory histogram allocation.

## Snapshot, Heartbeat, Merge

Snapshot binary checkpoints, shared state, report state, merge, and heartbeat
all support runtime histogram lengths and runtime radial grids, and snapshot
reports now output body-neutral metadata using `r_lower_Rbody` and
`r_upper_Rbody`.

## Simulation Data, MPI, Final Output

Aggregate histograms, jackknife storage and indexing, MPI reductions,
`bincount.txt`, `residence_jackknife_blocks.tsv`, and `run_metadata.json` all use
runtime bin counts and Rbody-normalized schema.

## Diagnostic Output

All diagnostic outputs migrated from Rsun to Rbody normalization, including
evaporation output, snapshot evaporation output, trajectory summary, trajectory
events, and invalid trajectory ledger, with output versions and binary
checkpoint versions incremented to avoid misreading old Rsun-normalized data.

## Numerical Stability Fixes

Several numerical stability issues were fixed: the radial free-flight center
crossing now correctly flips `r`, `v_radial`, and `axis_x` instead of clamping
to zero; the Kepler exterior radial-grid edge classification near `1.1 R_body`
was corrected; an unbound outward-escape fallback ensures unbound, outward,
scatter-free trajectories terminate correctly; and free-propagation timeout
diagnostics were added for state inspection at timeout. The high-cross-section
RK45 timeout pathology has also been resolved, with the root causes being the
radial center-crossing clamp and the missing unbound outward-escape termination,
so large timeout warning counts no longer appear in high-cross-section scans.
Dense-position tolerance metadata was corrected with a runtime overload
returning `2.0e-3 * radial_grid.Inner_Bin_Width_Km()`, so Earth output now
reports the Earth-scaled tolerance.

## Final Status

The simulation code refactor is complete: the pipeline is fully runtime
body-dependent, numerically stable, and validated by the full test suite.
