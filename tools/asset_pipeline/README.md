# Asset preparation

Read `docs/asset_pipeline_plan.md` first. State and next work are in `batch.json` and `tasks/`. The initial eight-model package has one authored placement; this is not visual/performance acceptance.

The existing Blender 5.1.1 installation is `D:/Soft/Blender 5.1/blender.exe`. Blender MCP is not callable in the setup session; the background route was used. Godot MCP bridge was offline. Do not edit the user's live Blender scene. No tests, builds, QA or performance measurements have been authorized.

## Reproduce the pilot

Download the 1K glTF at `https://api.polyhaven.com/files/painted_wooden_bench`, property `gltf.1k.gltf`, into `.asset_work/poolrooms_painted_bench/painted_wooden_bench_1k.gltf`. Download each declared `include` dependency into its relative path under that folder. Do not download the entire pack or alternate resolutions. The `.asset_work/.gdignore` marker must be present before downloading; temporary files are excluded from Git and all export presets.

From the project root, prepare the model (this is asset conversion, not a build or QA):

```powershell
& 'D:/Soft/Blender 5.1/blender.exe' --background --factory-startup --disable-autoexec --python-exit-code 1 --python 'tools/asset_pipeline/prepare_static.py' -- --recipe 'tools/asset_pipeline/recipes/poolrooms_painted_bench.json'
```

The JSON recipe defines source/output, whole-asset geometry target, width, texture limit and export options. The script keeps separate mesh parts, normalizes the ground pivot, reduces geometry only when above target and embeds textures in a GLB. This first recipe does not bake high-poly detail or support armatures/morph targets; use a separate recipe for those. Do not generalize this pilot to arbitrary animated models. Geometry counts/bounds needed for the transformation are internal processing inputs, not benchmark or acceptance evidence.

The pilot source is already low-poly (the source page lists 630 triangles). Geometry reduction was skipped; textures were resized from the 1K source to a 512px cap. The Blender exporter reported a sampler-selection warning while packing metallic/roughness textures. Export completed successfully; visual acceptance remains unperformed. Record the warning rather than claiming it was visually assessed.

The wrapper `scenes/props/poolrooms_painted_bench.tscn` owns the visual and a separate simple collision body. Its instance is in `scenes/branches/poolrooms/poolrooms_gallery.tscn` under `Environment/Props/PoolroomsPaintedBench`, beside the entry. Collision and silhouette QA remain unperformed.

## Temporary data

Keep managed downloads and intermediates inside `.asset_work/`. After successful processing and authored placement, remove only enumerated task-owned temporary files; retain the prepared GLB, recipe, wrapper and source record. Do not remove an unresolved input or unique unrecoverable original. Cleanup does not claim game QA or a reduction in the Web build size.
