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
    "male_peasant": ("Male_Peasant", "Superhero_Male_FullBody", ["Hair_SimpleParted"]),
    "female_peasant": ("Female_Peasant", "Superhero_Female_FullBody", ["Hair_Long"]),
    "male_ranger": ("Male_Ranger", "Superhero_Male_FullBody", ["Hair_Beard"]),
    "female_ranger": ("Female_Ranger", "Superhero_Female_FullBody", []),
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
    for img in bpy.data.images:
        cap = 512 if ("Hair" in img.name or "Eye" in img.name or "Normal" in img.name or "Rough" in img.name) else 1024
        if img.size[0] > cap:
            img.scale(cap, cap)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
        export_image_format="JPEG", export_image_quality=85, export_animations=False, export_yup=True)
    print("HERO", name, [o.name for o in bpy.data.objects])
