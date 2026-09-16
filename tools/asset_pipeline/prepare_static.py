"""Prepare one static glTF asset in an isolated background Blender process.

This is a conversion recipe, not a model validation or benchmark tool.
Launch with --background --factory-startup --disable-autoexec --python-exit-code 1.
Only invoke with a trusted project-owned JSON recipe and a separate process.
"""

import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


def prepare(recipe_path):
    project = Path(__file__).resolve().parents[2]
    recipe = json.loads((project / recipe_path).read_text(encoding="utf-8"))
    source = (project / recipe["source"]).resolve()
    output = (project / recipe["output"]).resolve()
    work = (project / ".asset_work").resolve()
    production = (project / "assets" / "third_party").resolve()
    if not source.is_relative_to(work) or not output.is_relative_to(production):
        raise ValueError("Recipe input/output must stay in the designated project folders")

    # This script only owns its freshly created, isolated factory-startup scene.
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    # Remove factory materials too, so source names such as "Material" stay stable.
    for material in list(bpy.data.materials):
        bpy.data.materials.remove(material)
    bpy.ops.import_scene.gltf(filepath=str(source))
    objects = list(bpy.context.scene.objects)
    meshes = [obj for obj in objects if obj.type == "MESH"]
    selected_names = recipe.get("source_meshes")
    if selected_names:
        by_name = {obj.name: obj for obj in meshes}
        missing = set(selected_names) - by_name.keys()
        if missing:
            raise ValueError(f"Requested source parts are missing: {sorted(missing)}")
        meshes = [by_name[name] for name in selected_names]
    if not meshes or any(obj.type == "ARMATURE" for obj in objects) or any(obj.data.shape_keys for obj in meshes):
        raise ValueError("This recipe requires a static model with at least one mesh")

    # Explicit cosmetic remaps only; never infer that glass or gameplay cues match.
    material_remap = recipe.get("material_remap", {})
    for source_name, target_name in material_remap.items():
        if bpy.data.materials.get(source_name) is None or bpy.data.materials.get(target_name) is None:
            raise ValueError(f"Requested material remap is missing: {source_name} -> {target_name}")
    for obj in meshes:
        for slot in obj.material_slots:
            if slot.material and slot.material.name in material_remap:
                slot.material = bpy.data.materials[material_remap[slot.material.name]]

    # Bounds are used to perform the requested scale/pivot transformation,
    # not recorded as acceptance evidence or before/after measurements.
    corners = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    low = Vector(tuple(min(point[axis] for point in corners) for axis in range(3)))
    high = Vector(tuple(max(point[axis] for point in corners) for axis in range(3)))
    dimension = high.z - low.z if "target_height_m" in recipe else high.x - low.x
    if dimension <= 0:
        raise ValueError("Cannot normalize a zero-size object")
    target_size = recipe.get("target_height_m", recipe.get("target_width_m"))
    scale = float(target_size) / dimension
    pivot = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    target = int(recipe["target_triangles"])
    triangles = sum(max(0, len(face.vertices) - 2) for obj in meshes for face in obj.data.polygons)
    source_worlds = [obj.matrix_world.copy() for obj in meshes]

    # Keep individual source parts; detach while preserving their world transform.
    for index, obj in enumerate(meshes):
        world = source_worlds[index]
        obj.parent = None
        obj.matrix_world = world
        obj.data = obj.data.copy()
        for vertex in obj.data.vertices:
            vertex.co = (world @ vertex.co - pivot) * scale
        obj.matrix_world = Matrix.Identity(4)
        obj.name = recipe["mesh_name"] if len(meshes) == 1 else f'{recipe["mesh_name"]}{index + 1}'
        obj.data.name = obj.name
        obj.data.update()

        # Triangle count is an input to the reduction operation, not a QA report.
        if recipe.get("decimate_if_above_target") and triangles > target:
            modifier = obj.modifiers.new("WebReduction", "DECIMATE")
            modifier.ratio = target / triangles
            modifier.use_collapse_triangulate = True
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=modifier.name)

    for image in bpy.data.images:
        if image.source != "FILE" or image.size[0] == 0:
            continue
        width, height = image.size
        factor = min(1.0, int(recipe["max_texture_size"]) / max(width, height))
        if factor < 1.0:
            image.scale(max(1, round(width * factor)), max(1, round(height * factor)))

    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        use_selection=True,
        export_image_format=recipe["image_format"],
        export_jpeg_quality=int(recipe["jpeg_quality"]),
        export_keep_originals=False,
        export_animations=False,
        export_cameras=False,
        export_lights=False,
        export_apply=True,
    )
    print(f"Prepared asset: {recipe['output']}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--recipe", required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    prepare(args.recipe)
