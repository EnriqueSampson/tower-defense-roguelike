"""Shared helpers for placeholder model scripts.

Run a model script headless from the repo root, e.g.

    /Applications/Blender.app/Contents/MacOS/Blender -b \
        --python tools/blender/human_swordsman.py

Conventions (see docs/ROADMAP.md, asset spec):
- 1 Blender unit = 1 map tile. Towers fit a 2x2-unit square; pivot at the
  centre of the base, on the ground (z = 0).
- Models face -Y in Blender. glTF export (+Y up) turns that into +Z, which
  the game treats as the model's front.
- A tower's rotating part lives under an empty named "Turret".
- Animations are actions on one pivot object, named idle / walk / attack /
  death / build; the action name becomes the Godot animation name.
"""

import math
import os

import bpy

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODELS_DIR = os.path.join(REPO_ROOT, "assets", "models")


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def srgb_to_linear(channel):
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def linear_to_srgb(channel):
    if channel <= 0.0031308:
        return channel * 12.92
    return 1.055 * channel ** (1.0 / 2.4) - 0.055


def material(name, rgb, roughness=0.8, emission=0.0):
    """Principled material from an on-screen (sRGB) colour, e.g. a hex picker
    value / 255. Blender and glTF store linear colour, so it is converted.
    `emission` > 0 adds a glow in the same colour; keep it below ~1.
    """
    linear = tuple(srgb_to_linear(c) for c in rgb)
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*linear, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*linear, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = (*linear, 1.0)
    return mat


def empty(name, parent=None, location=(0.0, 0.0, 0.0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.parent = parent
    return obj


def part(kind, name, mat, parent, location, scale=(1.0, 1.0, 1.0), rotation=(0.0, 0.0, 0.0), **kwargs):
    """Adds a primitive ("cube", "cylinder", "sphere") parented to `parent`.

    `location` is relative to the parent.
    """
    ops = {
        "cube": bpy.ops.mesh.primitive_cube_add,
        "cylinder": bpy.ops.mesh.primitive_cylinder_add,
        "sphere": bpy.ops.mesh.primitive_uv_sphere_add,
    }
    ops[kind](location=(0.0, 0.0, 0.0), **kwargs)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    obj.data.materials.append(mat)
    obj.parent = parent
    obj.location = location
    obj.scale = scale
    obj.rotation_euler = rotation
    return obj


def keyframe_action(obj, action_name, data_path, keys, fps=24):
    """Creates an action on `obj` keyed at (seconds, value) pairs.

    `data_path` is e.g. "rotation_euler" or "location"; values are 3-tuples.
    The action is stashed on an NLA track so every action exports.
    """
    obj.animation_data_create()
    action = bpy.data.actions.new(action_name)
    action.use_fake_user = True
    obj.animation_data.action = action
    for seconds, value in keys:
        setattr(obj, data_path, value)
        obj.keyframe_insert(data_path=data_path, frame=1 + round(seconds * fps))
    track = obj.animation_data.nla_tracks.new()
    track.name = action_name
    track.strips.new(action_name, 1, action)
    obj.animation_data.action = None
    return action


def _vertex_color_material():
    mat = bpy.data.materials.get("VertexColor")
    if mat:
        return mat
    mat = bpy.data.materials.new("VertexColor")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.75
    attribute = nodes.new("ShaderNodeVertexColor")
    attribute.layer_name = "Col"
    mat.node_tree.links.new(attribute.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def optimize_for_game():
    """One draw call per moving part: bake each part's material colour into a
    vertex colour, give every non-glowing part one shared material, and merge
    the parts under each parent (root, Turret, pivots) into a single mesh.
    Glowing parts keep their own material so emission survives.
    """
    shared = _vertex_color_material()
    groups = {}
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH" or not obj.data.materials:
            continue
        source = obj.data.materials[0]
        bsdf = next((n for n in source.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if source.use_nodes else None
        if bsdf is not None and bsdf.inputs["Emission Strength"].default_value > 0.0:
            # Glowing parts keep their material; merge them per parent+material.
            groups.setdefault((obj.parent, source.name), []).append(obj)
            continue
        # Vertex colours reach Godot as display (sRGB) values, so convert the
        # linear base colour back; storing linear here renders far too dark.
        base = bsdf.inputs["Base Color"].default_value if bsdf else (1.0, 1.0, 1.0, 1.0)
        color = (linear_to_srgb(base[0]), linear_to_srgb(base[1]), linear_to_srgb(base[2]), 1.0)
        attribute = obj.data.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        for datum in attribute.data:
            datum.color = color
        obj.data.materials.clear()
        obj.data.materials.append(shared)
        groups.setdefault((obj.parent, shared.name), []).append(obj)
    for (parent, material_name), parts in groups.items():
        if len(parts) < 2:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for part in parts:
            part.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        parts[0].name = (parent.name if parent else "Model") + ("Mesh" if material_name == shared.name else "Glow")


def export_glb(relative_path):
    path = os.path.join(MODELS_DIR, relative_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    optimize_for_game()
    # Reset any pose left by keyframing so the rest pose exports cleanly.
    bpy.context.scene.frame_set(1)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_materials="EXPORT",
    )
    print("EXPORTED", path)
    return path


def radians(x, y, z):
    return (math.radians(x), math.radians(y), math.radians(z))
