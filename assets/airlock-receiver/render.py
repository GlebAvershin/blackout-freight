"""Render the Depot 07 receiver from the geometry used by Roblox. Run inside Blender."""
import json
from pathlib import Path

import bpy
from mathutils import Vector

folder = Path(__file__).resolve().parent
spec = json.loads((folder.parents[1] / "src/server/ReceiverGeometry.json").read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 28
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1120, 560
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new("Depot night")
scene.world.color = (.14, .16, .20)


def linear(byte):
    value = byte / 255
    return value / 12.92 if value < .04045 else ((value + .055) / 1.055) ** 2.4


def material(name, rgb, glow=False):
    paint = bpy.data.materials.new(name)
    paint.use_nodes = True
    shader = paint.node_tree.nodes.get("Principled BSDF")
    color = tuple(linear(byte) for byte in rgb) + (1,)
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Metallic"].default_value = .38
    shader.inputs["Roughness"].default_value = .32
    if glow:
        shader.inputs["Emission Color"].default_value = color
        shader.inputs["Emission Strength"].default_value = 1.8
    return paint


paints = {name: material(name, rgb, name in ("charged", "amber"))
          for name, rgb in spec["palette"].items()}
for shape in spec["parts"]:
    x, y, z = shape["center"]
    width, height, depth = shape["size"]
    paint = shape["paint"]
    if shape["name"] in ("Slot1", "Slot2", "Slot3"):
        paint = "charged"
        y += spec["travel"]
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, z, y))
    obj = bpy.context.object
    obj.name = shape["name"]
    obj.dimensions = (width, depth, height)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(paints[paint])
    bevel = obj.modifiers.new("Edge highlight", "BEVEL")
    bevel.width, bevel.segments = .036, 3
    obj.modifiers.new("Flat face normals", "WEIGHTED_NORMAL")

bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.009))
bpy.context.object.data.materials.append(material("Floor", [35, 46, 58]))


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


for pos, watts, size, color in [
    ((-3, -5, 7), 850, 6, (.8, .92, 1)),
    ((4, 3, 6), 1200, 5, (1, .76, .49)),
    ((1, -6, 3), 350, 4, (.53, .79, 1)),
]:
    bpy.ops.object.light_add(type="AREA", location=pos)
    lamp = bpy.context.object
    lamp.data.energy, lamp.data.shape, lamp.data.size, lamp.data.color = watts, "DISK", size, color
    aim(lamp, (0, 0, 1))
bpy.ops.object.camera_add(location=(5.8, -13, 5.7))
scene.camera = bpy.context.object
scene.camera.data.type = "ORTHO"
scene.camera.data.ortho_scale = 9.9
aim(scene.camera, (0, .25, 1.05))
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(folder / "receiver.png")
bpy.ops.render.render(write_still=True)
