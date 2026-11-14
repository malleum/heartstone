"""Assemble playable characters from Quaternius CC0 packs (see docs/ARCHITECTURE.md, Assets).

  blender -b --python tools/blender/build_heroes.py -- <outfits-pack> <base-pack> <out-dir>

Each hero = one outfit (which carries the skeleton and hands) + the head, eyes and
eyebrows cut from the matching base body + optional hair. Textures are shrunk because
the packs ship 4K maps and these characters are seen from four metres away.
"""
import bpy, bmesh, sys, os

OUTFITS, BASE, OUT = sys.argv[sys.argv.index("--") + 1:]
OG = os.path.join(OUTFITS, "Exports/glTF (Godot-Unreal)/Outfits")
BG = os.path.join(BASE, "Base Characters/Godot - UE")
HG = os.path.join(BASE, "Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)")
HEROES = {  # name: (outfit, body, [hair...])
    # Every hairstyle is included; the game shows one and hides the rest.
    "male_peasant": ("Male_Peasant", "Superhero_Male_FullBody", ["Hair_SimpleParted", "Hair_Buzzed", "Hair_Beard"]),
    "female_peasant": ("Female_Peasant", "Superhero_Female_FullBody", ["Hair_Long", "Hair_Buns"]),
    "male_ranger": ("Male_Ranger", "Superhero_Male_FullBody", ["Hair_SimpleParted", "Hair_Buzzed", "Hair_Beard"]),
    "female_ranger": ("Female_Ranger", "Superhero_Female_FullBody", ["Hair_Long", "Hair_Buns"]),
}
KEEP = {"Head", "neck_01"}

def load(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for o in [o for o in new if o.name.startswith("Icosphere")]:
        new.remove(o); bpy.data.objects.remove(o)
    return new

def adopt(meshes, arm):
    for m in meshes:
        m.parent = arm
        m.matrix_parent_inverse.identity()
        for mod in m.modifiers:
            if mod.type == "ARMATURE":
                mod.object = arm

def head_only(obj):
    idx = {g.index for g in obj.vertex_groups if g.name in KEEP}
    bm = bmesh.new(); bm.from_mesh(obj.data)
    dl = bm.verts.layers.deform.verify()
    drop = [v for v in bm.verts if sum(w for g, w in v[dl].items() if g in idx) < 0.5]
    bmesh.ops.delete(bm, geom=drop, context="VERTS")
    bm.to_mesh(obj.data); bm.free()

# --- generated garments ---------------------------------------------------------------
# The free packs have no dresses, cloaks or shawls, and the Wheel of Time needs all
# three. Each garment is a lofted sheet built in the rest pose with hand-written skin
# weights: transferring weights from the body makes a skirt behave like trousers,
# while these blend toward the hips so cloth swings instead of wrapping each leg.
# UV: u runs around the garment, v from 0 at the top edge to 1 at the hem.
import math
from mathutils import Vector

def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)

def sheet(name, arm, rows, closed):
    """rows: list of rings, each a list of (position, {bone: weight}). Returns the object."""
    n = len(rows[0]); verts = []; faces = []; uvs = []
    for j, ring in enumerate(rows):
        for i, (p, _w) in enumerate(ring):
            verts.append(p); uvs.append((i / (n if closed else n - 1), 1.0 - j / (len(rows) - 1)))
    for j in range(len(rows) - 1):
        for i in range(n if closed else n - 1):
            a = j * n + i; b = j * n + (i + 1) % n
            faces.append((a, b, b + n, a + n))
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces)
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            u, v = uvs[vi]
            # The seam column of a closed ring needs u = 1 on its far side.
            if closed and vi % n == 0 and any(me.loops[l].vertex_index % n == n - 1 for l in poly.loop_indices):
                u = 1.0
            uv.data[li].uv = (u, v)
    for poly in me.polygons:
        poly.use_smooth = True
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    k = 0
    for ring in rows:
        for _p, w in ring:
            tot = sum(w.values())
            for bone, val in w.items():
                if val > 0.001:
                    g = ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
                    g.add([k], val / tot, "REPLACE")
            k += 1
    mat = bpy.data.materials.get("Garment") or bpy.data.materials.new("Garment")
    me.materials.append(mat)
    ob.parent = arm; ob.matrix_parent_inverse = arm.matrix_world.inverted()
    mod = ob.modifiers.new("Armature", "ARMATURE"); mod.object = arm
    return ob

def garments(arm, female):
    B = {b.name: arm.matrix_world @ b.head_local for b in arm.data.bones}
    hip = B["pelvis"]; neck = B["neck_01"]; chest = B["spine_03"]; sh = B["upperarm_l"].x
    cy = hip.y            # front is -Y in Blender
    tw = sh + 0.035       # torso half-width
    td = 0.15 if female else 0.165

    def legs(x, t):
        """Lower-body weights at lateral position x and depth t (0 hips .. 1 ankle)."""
        l = smooth(-0.09, 0.09, x)
        low = smooth(0.42, 0.66, t)
        follow = 0.78 * smooth(0.06, 0.35, t)     # the rest stays with the hips: swing
        return {"pelvis": 1.0 - follow, "thigh_l": follow * l * (1 - low), "thigh_r": follow * (1 - l) * (1 - low),
                "calf_l": follow * l * low, "calf_r": follow * (1 - l) * low}

    # Skirt: waist to ankle, A-line with soft folds.
    if female:
        rows = []; top = hip.z + 0.09; hem = 0.09; N = 32
        for j in range(12):
            t = j / 11.0; z = top + (hem - top) * t; ring = []
            for i in range(N):
                a = i / N * math.tau
                fold = 1.0 + 0.045 * math.sin(a * 7.0) * smooth(0.15, 1.0, t)
                rx = ((tw + 0.03) + (0.33 - tw) * t ** 0.75) * fold
                ry = ((td + 0.035) + (0.31 - td) * t ** 0.75) * fold
                x = math.sin(a) * rx
                ring.append((Vector((x, cy + math.cos(a) * ry, z)), legs(x, t)))
            rows.append(ring)
        sheet("Skirt", arm, rows, True)

    # Coat: the skirts of a long coat, belted at the waist, open down the front and
    # falling to the knee. With the tunic above recoloured it reads as one garment;
    # the Asha'man black coat is this.
    if not female:
        rows = []; top = hip.z + 0.11; hem = 0.50; N = 29
        for j in range(9):
            t = j / 8.0; z = top + (hem - top) * t; ring = []
            for i in range(N):
                u = i / (N - 1) * 2.0 - 1.0; a = u * math.radians(168)     # 0 = back, +-168 = front edges
                fold = 1.0 + 0.03 * math.sin(u * 9.0) * smooth(0.2, 1.0, t)
                rx = ((tw + 0.035) + 0.07 * t) * fold
                ry = ((td + 0.04) + 0.08 * t) * fold
                x = math.sin(a) * rx
                ring.append((Vector((x, cy + math.cos(a) * ry, z)), legs(x, t * 0.5)))
            rows.append(ring)
        sheet("Coat", arm, rows, False)

    # Cloak: clasped at the throat, thrown back behind the arms, down to the calves.
    rows = []; top = neck.z + 0.01; hem = 0.24; N = 21
    for j in range(13):
        t = j / 12.0; z = top + (hem - top) * t; ring = []
        over = smooth(0.0, 0.12, t)                 # how far past the neck we are
        half = math.radians(150 - 62 * smooth(0.0, 0.25, t))
        for i in range(N):
            u = i / (N - 1) * 2.0 - 1.0; a = u * half
            fold = 1.0 + 0.05 * math.sin(u * 11.0) * smooth(0.2, 1.0, t)
            rx = (0.10 + (tw + 0.05 - 0.10) * over + 0.20 * t) * fold
            ry = (0.10 + (td + 0.07 - 0.10) * over + 0.22 * t) * fold
            x = math.sin(a) * rx
            y = cy + 0.02 + math.cos(a) * ry        # +Y is behind the character
            zb = z                                    # bone heights as weight centres
            w = {"neck_01": max(0.0, 1 - abs(zb - neck.z) / 0.12), "spine_03": max(0.0, 1 - abs(zb - chest.z) / 0.22),
                 "spine_01": max(0.0, 1 - abs(zb - (hip.z + 0.12)) / 0.25)}
            below = smooth(hip.z + 0.05, hip.z - 0.25, z)
            for k, v in legs(x, 0.35 + 0.5 * below).items():
                w[k] = w.get(k, 0.0) + v * below * 1.2
            ring.append((Vector((x, y, z)), w))
        rows.append(ring)
    sheet("Cloak", arm, rows, False)

    # Shawl: draped over the shoulders and upper arms, dipping to a point at the back,
    # open at the front. Rounded over the shoulder like cloth, not a flat yoke.
    if female:
        rows = []; N = 37; R = 8
        for j in range(R):
            t = j / (R - 1.0); ring = []
            out = math.sin(t * math.pi * 0.5)             # fast outward, then hanging down
            for i in range(N):
                u = i / (N - 1) * 2.0 - 1.0; a = u * math.radians(172)     # 0 = back, +-172 = front edges
                side = abs(math.sin(a)); back = smooth(math.radians(75), 0.0, abs(a))
                bottom = chest.z - 0.05 - 0.24 * back - 0.03 * side
                z = (neck.z - 0.005) + (bottom - (neck.z - 0.005)) * (t ** 1.5)
                rx = 0.085 + (sh + 0.085 - 0.085) * out
                ry = 0.085 + (td + 0.055 - 0.085) * out
                x = math.sin(a) * rx
                arm_side = "l" if x > 0 else "r"
                w = {"spine_03": 0.55 + 0.35 * (1 - side), "neck_01": 0.35 * (1 - t),
                     "clavicle_" + arm_side: 0.3 * side, "upperarm_" + arm_side: 0.45 * side * t, "spine_02": 0.5 * t * back}
                ring.append((Vector((x, cy + 0.012 + math.cos(a) * ry, z)), w))
            rows.append(ring)
        sheet("Shawl", arm, rows, False)

for name, (outfit, body, hairs) in HEROES.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = load(os.path.join(OG, outfit + ".gltf"))
    arm = next(o for o in objs if o.type == "ARMATURE")
    for extra in [body] + hairs:
        folder = BG if extra == body else HG
        new = load(os.path.join(folder, extra + ".gltf"))
        meshes = [o for o in new if o.type == "MESH"]
        for m in meshes:
            if extra == body and m.name.lower().startswith("superhero"):
                head_only(m)
        adopt(meshes, arm)
        for o in new:
            if o.type != "MESH":
                bpy.data.objects.remove(o)
    garments(arm, name.startswith("female"))
    for img in bpy.data.images:
        cap = 512 if ("Hair" in img.name or "Eye" in img.name or "Normal" in img.name or "Rough" in img.name) else 1024
        if img.size[0] > cap:
            img.scale(cap, cap)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
        export_image_format="JPEG", export_image_quality=85, export_animations=False, export_yup=True)
    print("HERO", name, [o.name for o in bpy.data.objects])
