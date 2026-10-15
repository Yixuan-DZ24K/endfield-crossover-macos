# Preserved Wine patches

These patches were recovered unchanged from the maintenance archive of the tested installation. They modify LGPL Wine source and retain upstream terms and contributor attribution.

| File | Role |
| --- | --- |
| `CrossOver-26.3-current-compatibility.patch` | Experimental kernel/process/session/module compatibility follow-up; includes `csrss`, `lsass`, Wine server protocol additions and Wine boot changes. It also already contains the `wine_info.plist.in` safe-area metadata hunk. |
| `Endfield-winemac-coordinate-v4.patch` | Adds the optional native/logical coordinate bridge to absolute input, scroll position, relative deltas, cursor polling/warps/clipping, queued warp positions and native frame queries. |
| `Endfield-notch-safe-area-source.patch` | Historical copy of the metadata hunk already in the first patch. Kept for completeness. **Do not apply it again after the first patch.** The metadata flag alone did not solve the notch overlap. |

The archived compatibility diff was generated in a Wine source checkout already carrying the FineWine compatibility base. FineWine 1.2.2 is an upstream input, not an alternative name for this final custom runtime. The exact old source-tree commit/configure invocation was not preserved in the maintenance archive. See [BUILDING.md](../docs/BUILDING.md) for the known provenance and reconstruction limits.

Before applying to a candidate checkout, inspect its base and run `git apply --check` for each selected patch. Stop on mismatches rather than forcing hunks or replacing unrelated build files. Rebuild the matched server and client-side modules together: protocol additions are appended after the CrossOver base request IDs, and mixing old and new binaries can be incompatible.

Suggested logical order after the required FineWine baseline is present:

1. `CrossOver-26.3-current-compatibility.patch`
2. `Endfield-winemac-coordinate-v4.patch`

The public snapshot does not assert that this sequence is a verified clean build recipe against unmodified CrossOver or current upstream Wine.
