"""Author the Depot inspection drone and export its native Roblox rig.

blender -b --python assets/sentinel/build.py
blender -b assets/sentinel/Sentinel.blend --python assets/sentinel/build.py -- --export
"""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

FOLDER = Path(__file__).resolve().parent
RIG = FOLDER.parents[1] / 'src/client/SentinelRig.json'
COLORS = {
    'Enamel': ('D7A254', 'SmoothPlastic'), 'Graphite': ('34484B', 'SmoothPlastic'),
    'Rail': ('6F8784', 'Metal'), 'Recess': ('16282D', 'Metal'),
    'Bone': ('E6DCC0', 'SmoothPlastic'), 'Rotor': ('71837C', 'Metal'),
    'Optical glass': ('E34332', 'Neon'), 'Sight': ('FFD1A7', 'Neon'),
}


def linear(n):
    n /= 255
    return n / 12.92 if n <= .04045 else ((n + .055) / 1.055) ** 2.4


def add(name, primitive, pos, dims, material, angles=(0, 0, 0), group='Hull'):
    if primitive == 'Cylinder':
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=.5, depth=1)
    elif primitive == 'Ball':
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=.5)
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object
    obj.name = name
    obj.location = pos
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler = tuple(math.radians(a) for a in angles)
    obj['primitive'] = primitive
    obj['group'] = group
    obj.data.materials.append(bpy.data.materials[material])
    if primitive == 'Ball':
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    elif min(dims) > .045:
        modifier = obj.modifiers.new('Milled edges', 'BEVEL')
        modifier.width = min(.055, min(dims) * .13)
        modifier.segments = 3
        obj.modifiers.new('Panel normals', 'WEIGHTED_NORMAL')
    return obj


def author():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name, (hexcode, finish) in COLORS.items():
        rgb = tuple(linear(v) for v in bytes.fromhex(hexcode)) + (1,)
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = rgb
        mat.use_nodes = True
        shader = mat.node_tree.nodes['Principled BSDF']
        shader.inputs['Base Color'].default_value = rgb
        shader.inputs['Metallic'].default_value = .47 if finish == 'Metal' else .08
        shader.inputs['Roughness'].default_value = .33
        if finish == 'Neon':
            shader.inputs['Emission Color'].default_value = rgb
            shader.inputs['Emission Strength'].default_value = 1.55

    add('Keel', 'Ball', (0, 0, -.1), (3.22, 3.38, 1.74), 'Graphite')
    add('Hull seam', 'Ball', (0, -.18, .17), (3.43, 3.56, 1.18), 'Recess')
    add('Crown', 'Ball', (0, -.21, .38), (3.36, 3.48, 1.06), 'Enamel')
    add('Backbone', 'Block', (0, -.6, .72), (1.34, 1.85, .39), 'Graphite', (4, 0, 0))
    for index in range(5):
        add('Cooling rib %d' % index, 'Block', (0, -1.21 + index * .22, .91 + index * .013),
            (1.1, .09, .13), 'Rail', (12, 0, 0))
    add('Jaw', 'Ball', (0, .93, -.48), (2.19, 1.36, .72), 'Rail')
    for side, x in (('Port', -2.52), ('Starboard', 2.52)):
        sign = -1 if x < 0 else 1
        add(side + ' spar', 'Block', (x * .7, 0, -.05), (1.37, 1.35, .37), 'Rail', (0, 8 * sign, 0))
        add(side + ' duct', 'Cylinder', (x, -.10, .02), (2.94, 3.14, .76), 'Graphite')
        add(side + ' shroud', 'Cylinder', (x, -.10, .25), (2.90, 3.10, .41), 'Enamel')
        add(side + ' lip', 'Cylinder', (x, -.10, .465), (2.81, 3.0, .075), 'Rail')
        add(side + ' intake', 'Cylinder', (x, -.10, .505), (2.48, 2.64, .06), 'Recess')
        add(side + ' exhaust', 'Cylinder', (x, -.10, -.39), (2.52, 2.74, .22), 'Rail')
        add(side + ' exhaust well', 'Cylinder', (x, -.10, -.515), (2.19, 2.37, .06), 'Recess')
        add(side + ' bearing', 'Cylinder', (x, -.10, .63), (.48, .48, .22), 'Bone', group=side)
        for index in range(6):
            phi = index * math.tau / 6
            add(side + ' impeller %d' % index, 'Block',
                (x + .64 * math.cos(phi), -.1 + .64 * math.sin(phi), .565),
                (1.02, .34, .075), 'Rotor', (18, 0, math.degrees(phi) - 18), side)
        # Protective struts cross the opening above the freely turning fan.
        for rail in (-1, 1):
            add(side + ' guard %d' % rail, 'Block', (x + rail * .56, -.1, .75),
                (.075, 2.54, .095), 'Graphite', (0, 0, 11 * sign))
        for index in (-1, 1):
            add(side + ' cowl lug ' + str(index), 'Block', (x + .75 * index, .99, .435),
                (.29, .54, .11), 'Bone', (0, 0, -30 * index))
        add(side + ' shoe', 'Block', (x + .8 * sign, -.62, -.37),
            (.28, 1.58, .34), 'Graphite', (0, 0, 10 * sign))
        add(side + ' nav light', 'Block', (x + .99 * sign, .85, -.025),
            (.18, .62, .15), 'Optical glass', (0, 0, 37 * sign))
        add(side + ' shoulder', 'Ball', (sign * 1.13, .69, .58), (.47, 1.5, .31), 'Bone', (0, 0, 11 * sign))
        add(side + ' yoke', 'Block', (sign * .95, 1.21, -.11), (.28, .88, .66), 'Graphite',
            (0, 12 * sign, 0))
    add('Service plate', 'Block', (0, .82, .715), (1.11, .56, .09), 'Recess', (-17, 0, 0))
    add('Cabinet stripe', 'Block', (-.43, .83, .774), (.095, .40, .035), 'Enamel', (-17, 0, 0))
    for i in range(3):
        add('Cabinet hatch ' + str(i), 'Block', (.04 + .17 * i, .83, .774),
            (.065, .33, .035), 'Bone', (-17, 0, -9))
    add('Tail antenna base', 'Block', (-.92, -1.23, .52), (.27, .42, .18), 'Rail')
    add('Tail aerial', 'Cylinder', (-.92, -1.47, .95), (.085, .085, 1.03), 'Graphite', (24, 0, 0))
    # Machined concentric rings surround the articulated front camera.
    for name, front, diameter, depth, paint in (
        ('Gimbal', 1.31, 1.86, .55, 'Graphite'), ('Brass bezel', 1.61, 1.70, .16, 'Enamel'),
        ('Mount ring', 1.735, 1.44, .12, 'Rail'), ('Recessed seat', 1.82, 1.20, .09, 'Recess'),
        ('Iris', 1.876, .92, .06, 'Optical glass'), ('Pupil', 1.92, .53, .05, 'Recess'),
        ('Pilot lens', 1.955, .32, .045, 'Optical glass'),
    ):
        add(name, 'Cylinder', (0, front, -.03), (diameter, diameter, depth), paint,
            (90, 0, 0), 'Optic')
    add('Lens glint', 'Ball', (-.095, 1.991, .062), (.095, .029, .068), 'Sight', group='Optic')
    for angle in (45, 135, 225, 315):
        a = math.radians(angle)
        add('Lens retainer %d' % angle, 'Cylinder', (.737 * math.cos(a), 1.709, -.03 + .737 * math.sin(a)),
            (.085, .085, .05), 'Recess', (90, 0, 0), 'Optic')

    # Scene staging stays out of the Roblox export.
    scene = bpy.context.scene
    scene.world = bpy.data.worlds.new('Depot night')
    scene.world.color = (.17, .21, .22)
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1440, 810
    scene.render.resolution_percentage = 100
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -1.58))
    bpy.context.object.name = 'Studio floor'
    bpy.context.object.data.materials.append(bpy.data.materials['Recess'])
    for pos, watts, size, color in [
        ((-4, 4, 7), 860, 6, (.83, .95, 1)), ((4, -4, 5), 1360, 4, (1, .73, .46)),
        ((2, 6, 2), 380, 4, (.88, .94, 1)),
    ]:
        bpy.ops.object.light_add(type='AREA', location=pos)
        lamp = bpy.context.object
        lamp.data.energy, lamp.data.shape, lamp.data.size, lamp.data.color = watts, 'DISK', size, color
        lamp.rotation_euler = (-lamp.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.ops.object.camera_add(location=(5.8, 11.9, 6.8))
    cam = bpy.context.object
    cam.rotation_euler = (-cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.type, cam.data.ortho_scale = 'ORTHO', 10.65
    scene.camera = cam
    bpy.context.preferences.filepaths.save_version = 0
    scene.render.filepath = str(FOLDER / 'Sentinel.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(FOLDER / 'Sentinel.blend'), compress=True)


def export():
    # Roblox Y is up and -Z is forward. Its native cylinder axis is X.
    basis = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
    cylinder = Matrix(((0, 1, 0), (0, 0, 1), (1, 0, 0)))
    parts = []
    for obj in sorted((o for o in bpy.context.scene.objects if 'primitive' in o), key=lambda o: o.name):
        p, q, scale = obj.matrix_world.decompose()
        bounds = [Vector(b) for b in obj.bound_box]
        dims = [(max(v[i] for v in bounds) - min(v[i] for v in bounds)) * abs(scale[i]) for i in range(3)]
        is_cylinder = obj['primitive'] == 'Cylinder'
        orient = basis @ q.to_matrix() @ (cylinder if is_cylinder else basis.transposed())
        size = [dims[2], dims[0], dims[1]] if is_cylinder else [dims[0], dims[2], dims[1]]
        pose = list(basis @ p) + [a for row in orient for a in row]
        parts.append(dict(name=obj.name, shape=obj['primitive'], group=obj['group'],
                          size=[round(n, 5) for n in size], pose=[round(n, 6) for n in pose],
                          paint=obj.active_material.name))
    config = dict(palette=COLORS, parts=parts)
    RIG.write_text(json.dumps(config, separators=(',', ':'), ensure_ascii=False).replace('},{', '},\n{') + '\n')
    print('Exported %d native pieces' % len(parts))


if '--export' not in sys.argv:
    author()
export()
if '--export' not in sys.argv:
    bpy.ops.render.render(write_still=True)
