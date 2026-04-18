# asset-pipeline

Rough scripts that generated the grassland biome props (reference PNG + 3D mesh).
First end-to-end run on 2026-04-17 (Group 3 minerals, 15 meshes).

Not official yet — we want to revisit and formalize later (CLI ergonomics,
config, retries, probably wrap into a single `./generate <prop_id>` entry point).

## Scripts

### `gen_image.py`
Generates a reference PNG via Gemini image model.

```bash
export GEMINI_API_KEY=...
export GEMINI_IMAGE_MODEL=gemini-3.1-flash-image-preview  # optional, default gemini-2.5-flash-image
python3 gen_image.py prompt.txt out.png
```

### `meshy_pipeline.py`
Runs the full Meshy chain on reference PNGs: image-to-3d → remesh (3K tris)
→ retexture → download `.glb`. Batches in parallel (5 workers by default).

```bash
export MESHY_API_KEY=...
export MESHY_PARALLEL=5         # optional (default 5 workers)
export FARHAVEN_PROPS_DIR=...   # optional override — default resolves to ../../assets/props from this script

# default: all P01001–P01005, all 3 variants
python3 meshy_pipeline.py

# one full prop (3 variants)
python3 meshy_pipeline.py P01001

# specific variants
python3 meshy_pipeline.py P01001:1 P01003:2
```

Input:  `assets/props/<prop_id>/reference_v<N>.png`
Output: `assets/props/<prop_id>/mesh_v<N>.glb`

## Cost note

Via API = 30 credits per image-to-3d job (higher than the 20 credits the
web UI shows for equivalent work). Worth it for batch automation; not worth
it for one-offs.

## Known rough edges

- Default target list is hardcoded to P01001–P01005 (minerals batch)
- No retry on failed Meshy tasks
- No resume support — re-running reprocesses successful items
- Both scripts stdlib-only (urllib) which works but is ugly for error paths
