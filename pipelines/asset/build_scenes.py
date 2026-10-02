#!/usr/bin/env python3
"""Builds the script-free Godot scenes and resources for each theme from the extracted SVGs.

    python3 pipelines/asset/build_scenes.py

Run after extract_bible.py. Writes, per theme under client/themes/<theme_id>/:
  - one visual scene per archetype / prop / god / guide / fx: a Sprite2D at 1/DENSITY scale,
    anchored at the feet, with the bible's loop animations (AnimationPlayer, autoplay "idle")
    and an "Emissive" node holding additive glows at the eyes, hearts and flames, which rooms
    lift above the darkness layer
  - rigs/hunter.tscn: Skeleton2D with the 14 bones from rig.json and idle/run/shoot/hurt/down/revive
  - tiles/tiles.tres: a TileSet (96 px textures, drawn by a TileMapLayer scaled to 1/3)
  - fonts/*.tres and ui_theme.tres built from the palette and the Screens board's UI kit
Theme folders stay script-free (App Store 2.5.2); all logic lives in client code.
"""
from __future__ import annotations

import json
import math
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
THEMES = ROOT / "client" / "themes"
DENSITY = 3
NS = "{http://www.w3.org/2000/svg}"
EASE = -2.0  # Godot transition: ease in-out

PALETTES = {
    "grove_default": {
        "night_ink": "#1C1016", "deep_grove": "#16241F", "canopy": "#2F5A44", "trail_clay": "#6B4430",
        "geru_earth": "#9B3B1F", "rice_white": "#F3EAD6", "skin_umber": "#7A4A2F", "spirit_jade": "#6FF2B0",
        "meat_amber": "#E0913F", "torch_gold": "#FFC54A", "blight_violet": "#4A1F5E", "blight_glow": "#E56BFF",
        "storm_sky": "#8FD3FF", "kumkum_red": "#C8372D",
        # UI roles (Screens board)
        "panel": "#1E2F28", "panel_edge": "#2F5A44", "text": "#F3EAD6", "text_muted": "#B7C4B8",
        "primary": "#6FF2B0", "primary_text": "#0F2A1C", "reward": "#E0913F", "reward_text": "#2A1606",
        "secondary": "#2A3F36", "locked": "#3A3A3A", "darkness": "#1C1016", "friend_glow": "#6FF2B0",
        "foe_glow": "#E56BFF", "light": "#FFC54A", "health": "#C8372D",
    },
    "deep_reef": {
        "night_ink": "#101826", "deep_grove": "#0A1C2A", "canopy": "#2F6B4F", "trail_clay": "#C9A76B",
        "geru_earth": "#E0644A", "rice_white": "#F4EFE4", "skin_umber": "#7A4A2F", "spirit_jade": "#7FE8FF",
        "meat_amber": "#F4EFE4", "torch_gold": "#FFC54A", "blight_violet": "#5A1F48", "blight_glow": "#FF4FA0",
        "storm_sky": "#8FD3FF", "kumkum_red": "#E0644A",
        "panel": "#12283A", "panel_edge": "#2F6B4F", "text": "#F4EFE4", "text_muted": "#A9C2CF",
        "primary": "#7FE8FF", "primary_text": "#08202C", "reward": "#F4EFE4", "reward_text": "#101826",
        "secondary": "#1B3A4E", "locked": "#36404A", "darkness": "#0A1C2A", "friend_glow": "#7FE8FF",
        "foe_glow": "#FF4FA0", "light": "#FFC54A", "health": "#E0644A",
    },
}
GLOW_PAINTS = {"eyeGlow": "foe", "kEye": "foe", "rEye": "foe", "wEye": "foe", "kHeart": "foe",
               "uJade": "friend", "gSpirit": "friend", "wTorch": "light", "rLamp": "light"}


def color(hex_str: str, alpha: float | None = None) -> str:
    h = hex_str.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    a = 1.0 if alpha is None else alpha
    return f"Color({r:.4g}, {g:.4g}, {b:.4g}, {a:.4g})"


def num(v: float) -> str:
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def vec(x: float, y: float) -> str:
    return f"Vector2({num(x)}, {num(y)})"


# --------------------------------------------------------------------------- tscn writer


class Scene:
    def __init__(self, uid_hint: str) -> None:
        self.ext: list[tuple[str, str, str]] = []
        self.sub: list[tuple[str, str, list[str]]] = []
        self.nodes: list[str] = []
        self.hint = uid_hint

    def ext_res(self, type_: str, path: str) -> str:
        for t, p, rid in self.ext:
            if p == path:
                return rid
        rid = f"{len(self.ext) + 1}_{self.hint}"
        self.ext.append((type_, path, rid))
        return rid

    def sub_res(self, type_: str, props: list[str], rid: str | None = None) -> str:
        rid = rid or f"{type_}_{len(self.sub) + 1}"
        self.sub.append((type_, rid, props))
        return rid

    def node(self, name: str, type_: str, parent: str | None, props: list[str] | None = None, instance: str | None = None) -> None:
        head = f'[node name="{name}"'
        if type_:
            head += f' type="{type_}"'
        if parent is not None:
            head += f' parent="{parent}"'
        if instance:
            head += f' instance=ExtResource("{instance}")'
        head += "]"
        self.nodes.append("\n".join([head, *(props or [])]))

    def text(self) -> str:
        out = ["[gd_scene format=3]", ""]
        for t, p, rid in self.ext:
            out += [f'[ext_resource type="{t}" path="{p}" id="{rid}"]']
        if self.ext:
            out.append("")
        for t, rid, props in self.sub:
            out += [f'[sub_resource type="{t}" id="{rid}"]', *props, ""]
        for n in self.nodes:
            out += [n, ""]
        return "\n".join(out).rstrip() + "\n"


@dataclass
class Track:
    path: str
    times: list[float]
    values: list[str]
    interp: int = 1
    transitions: list[float] | None = None
    discrete: bool = False


@dataclass
class Anim:
    name: str
    length: float
    loop: bool
    tracks: list[Track] = field(default_factory=list)


def add_animations(scene: Scene, anims: list[Anim], autoplay: str = "idle") -> None:
    refs = []
    for a in anims:
        props = [f'resource_name = "{a.name}"', f"length = {num(a.length)}"]
        if a.loop:
            props.append("loop_mode = 1")
        for i, t in enumerate(a.tracks):
            trans = t.transitions or [EASE] * len(t.times)
            props += [
                f'tracks/{i}/type = "value"', f"tracks/{i}/imported = false", f"tracks/{i}/enabled = true",
                f'tracks/{i}/path = NodePath("{t.path}")', f"tracks/{i}/interp = {t.interp}",
                f"tracks/{i}/loop_wrap = true",
                f"tracks/{i}/keys = {{",
                f'"times": PackedFloat32Array({", ".join(num(x) for x in t.times)}),',
                f'"transitions": PackedFloat32Array({", ".join(num(x) for x in trans)}),',
                f'"update": {1 if t.discrete else 0},',
                f'"values": [{", ".join(t.values)}]',
                "}",
            ]
        refs.append((a.name, scene.sub_res("Animation", props, f"Animation_{a.name}")))
    lib = scene.sub_res("AnimationLibrary", ["_data = {", ",\n".join(f'&"{n}": SubResource("{r}")' for n, r in refs), "}"], "AnimationLibrary_main")
    scene.node("AnimationPlayer", "AnimationPlayer", ".", ["libraries = {", f'&"": SubResource("{lib}")', "}",
                                                         f'autoplay = &"{autoplay}"'])


# --------------------------------------------------------------------------- svg helpers


@dataclass
class SvgInfo:
    vb: tuple[float, float, float, float]
    tex: tuple[float, float]
    glows: list[tuple[float, float, float, str]]  # x, y, radius (master units), kind

    @property
    def scale(self) -> float:  # game px per master px
        return self.tex[0] / self.vb[2] / DENSITY

    @property
    def game_size(self) -> tuple[float, float]:
        return self.tex[0] / DENSITY, self.tex[1] / DENSITY


def svg_info(path: Path) -> SvgInfo:
    root = ET.parse(path).getroot()
    vb = tuple(float(v) for v in root.attrib["viewBox"].split())
    tex = (float(root.attrib["width"]), float(root.attrib["height"]))
    glows = []
    for el in root.iter():
        tag = el.tag.replace(NS, "")
        m = re.match(r"url\(#([^)]+)\)", el.attrib.get("fill", ""))
        if not m or m.group(1) not in GLOW_PAINTS:
            continue
        kind = GLOW_PAINTS[m.group(1)]
        if tag == "circle":
            glows.append((float(el.attrib["cx"]), float(el.attrib["cy"]), float(el.attrib["r"]), kind))
        elif tag == "ellipse":
            glows.append((float(el.attrib["cx"]), float(el.attrib["cy"]),
                          max(float(el.attrib["rx"]), float(el.attrib["ry"])), kind))
        elif tag == "path" and m.group(1) == "kHeart":
            glows.append((340.0, 190.0, 40.0, kind))  # Rotheart / Angler heart centre
    # Only glows inside the cropped view and not duplicated (transforms are ignored: master space).
    seen, out = set(), []
    for g in glows:
        key = (round(g[0]), round(g[1]))
        if key in seen or not (vb[0] <= g[0] <= vb[0] + vb[2] and vb[1] <= g[1] <= vb[1] + vb[3]):
            continue
        seen.add(key)
        out.append(g)
    return SvgInfo(vb, tex, out)  # type: ignore[arg-type]


def res_path(path: Path) -> str:
    return "res://" + path.relative_to(ROOT / "client").as_posix()


# --------------------------------------------------------------------------- visual scenes

LOOPS: dict[str, Anim] = {}


def _loop(name: str, length: float, path: str, a: str, b: str, extra: list[Track] | None = None) -> Anim:
    tracks = [Track(path, [0, length / 2, length], [a, b, a])] + (extra or [])
    return Anim(name, length, True, tracks)


def loop_for(kind: str) -> Anim:
    """The bible's CSS loops, converted to game px (transform-origin at the feet)."""
    if kind == "trot":    # Blight beasts .trot .36s: translateY(-5) rotate(-1.5deg)
        return _loop("idle", 0.36, "Body:position", vec(0, 0), vec(0, -2),
                     [Track("Body:rotation", [0, 0.18, 0.36], ["0.0", num(math.radians(-1.5)), "0.0"])])
    if kind == "heavy":   # .heavy .9s: translateY(-3) scaleX(1.01)
        return _loop("idle", 0.9, "Body:position", vec(0, 0), vec(0, -1.5),
                     [Track("Body:scale", [0, 0.45, 0.9], [vec(1, 1), vec(1.01, 1), vec(1, 1)])])
    if kind == "float":   # .float 2s: translateY(-10)
        return _loop("idle", 2.0, "Body:position", vec(0, 0), vec(0, -6))
    if kind == "stomp":   # Rotheart .stomp 1.4s: translateY(-4) rotate(-.6deg)
        return _loop("idle", 1.4, "Body:position", vec(0, 0), vec(0, -3),
                     [Track("Body:rotation", [0, 0.7, 1.4], ["0.0", num(math.radians(-0.6)), "0.0"])])
    if kind == "hover":   # Gods .hover 3s: translateY(-8)
        return _loop("idle", 3.0, "Body:position", vec(0, 0), vec(0, -5))
    if kind == "sway":    # .sway 3.2s rotate(4deg), origin top
        return _loop("idle", 3.2, "Body:rotation", "0.0", num(math.radians(4)))
    if kind == "glide":   # Guides .glide 2.6s translate(6,-8)
        return _loop("idle", 2.6, "Body:position", vec(0, 0), vec(3, -4))
    if kind == "twinkle":  # .twinkle 1.3s opacity .25
        return _loop("idle", 1.3, "Body:modulate", "Color(1, 1, 1, 1)", "Color(1, 1, 1, 0.25)")
    if kind == "flicker":  # Grove .flicker .18s steps(2) opacity .75 (flame glow only)
        return Anim("idle", 0.18, True, [Track("Emissive:modulate", [0, 0.09], ["Color(1, 1, 1, 1)", "Color(1, 1, 1, 0.75)"], discrete=True)])
    if kind == "pulse":   # .pulse 1.2s opacity .35 scale 1.25
        return _loop("idle", 1.2, "Body:scale", vec(1, 1), vec(1.12, 1.12),
                     [Track("Body:modulate", [0, 0.6, 1.2], ["Color(1, 1, 1, 1)", "Color(1, 1, 1, 0.6)", "Color(1, 1, 1, 1)"])])
    if kind == "spin":    # .spin 6s linear rotate 360
        return Anim("idle", 6.0, True, [Track("Body:rotation", [0, 6.0], ["0.0", num(math.tau)], transitions=[1, 1])])
    return Anim("idle", 1.0, True, [Track("Body:position", [0, 1.0], [vec(0, 0), vec(0, 0)])])


def glow_texture(scene: Scene, kind: str, palette: dict[str, str]) -> tuple[str, str]:
    """Additive radial glow (texture, material) for an emissive; shared per scene and kind."""
    tex_id, mat_id = f"GradientTexture2D_{kind}", "CanvasItemMaterial_add"
    existing = {rid for _, rid, _ in scene.sub}
    if tex_id not in existing:
        h = {"foe": palette["foe_glow"], "friend": palette["friend_glow"], "light": palette["light"]}[kind]
        stops = ", ".join(color(h, a)[6:-1] for a in (0.95, 0.45, 0.0))
        grad = scene.sub_res("Gradient", ["offsets = PackedFloat32Array(0, 0.35, 1)", f"colors = PackedColorArray({stops})"],
                             f"Gradient_{kind}")
        scene.sub_res("GradientTexture2D", [f'gradient = SubResource("{grad}")', "width = 64", "height = 64",
                                            "fill = 1", "fill_from = Vector2(0.5, 0.5)", "fill_to = Vector2(1, 0.5)"], tex_id)
    if mat_id not in existing:
        scene.sub_res("CanvasItemMaterial", ["blend_mode = 1"], mat_id)
    return tex_id, mat_id


@dataclass
class Visual:
    out: str            # scene path under themes/
    svg: str            # svg path under themes/
    loop: str = ""
    anchor: str = "feet"  # feet | center
    glow_scale: float = 1.0
    extra_glows: list[tuple[float, float, float, str]] = field(default_factory=list)


def build_visual(theme: str, v: Visual) -> None:
    palette = PALETTES[theme]
    svg_path = THEMES / v.svg
    info = svg_info(svg_path)
    gw, gh = info.game_size
    ox, oy = (-gw / 2, -gh) if v.anchor == "feet" else (-gw / 2, -gh / 2)
    name = "".join(p.capitalize() for p in Path(v.out).stem.split("_"))
    scene = Scene(Path(v.out).stem)
    tex = scene.ext_res("Texture2D", res_path(svg_path))
    scene.node(name, "Node2D", None)
    scene.node("Body", "Node2D", ".")
    scene.node("Sprite", "Sprite2D", "Body", [f'texture = ExtResource("{tex}")', "centered = false",
                                              f"position = {vec(ox, oy)}", f"scale = {vec(1 / DENSITY, 1 / DENSITY)}"])
    glows = info.glows + v.extra_glows
    if glows:
        scene.node("Emissive", "Node2D", "Body")
        for i, (gx, gy, r, kind) in enumerate(glows):
            tex_id, mat = glow_texture(scene, kind, palette)
            px = (gx - info.vb[0]) * info.scale + ox
            py = (gy - info.vb[1]) * info.scale + oy
            size = max(6.0, r * info.scale * 2.6 * v.glow_scale)
            scene.node(f"Glow{i}", "Sprite2D", "Body/Emissive", [
                f'material = SubResource("{mat}")', f'texture = SubResource("{tex_id}")',
                f"position = {vec(px, py)}", f"scale = {vec(size / 64, size / 64)}"])
    add_animations(scene, [loop_for(v.loop)])
    out = THEMES / v.out
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(scene.text(), encoding="utf-8")


# --------------------------------------------------------------------------- hunter rig


def build_hunter(theme: str = "grove_default") -> None:
    rig = json.loads((THEMES / theme / "rigs/hunter/rig.json").read_text(encoding="utf-8"))
    s = rig["game_scale"]
    bones = {b["part"]: b for b in rig["bones"]}
    master_h = rig["master_size"][1]
    feet_y = 236.0  # ankle line in hFront master space; the rig origin sits at the feet
    centre_x = 100.0

    def game(p: list[float]) -> tuple[float, float]:
        return (p[0] - centre_x) * s, (p[1] - feet_y) * s

    scene = Scene("hunter")
    scene.node("Hunter", "Node2D", None)
    scene.node("Body", "Node2D", ".")
    scene.node("Skeleton", "Skeleton2D", "Body")

    def path_of(part: str) -> str:
        chain = []
        while part:
            chain.append(part)
            part = bones[part]["parent"]
        return "Body/Skeleton/" + "/".join(reversed(chain))

    order = ["torso_lower", "leg_l", "leg_r", "torso_upper", "head", "feather", "arm_upper_l", "arm_lower_l",
             "hand_l", "bow", "string", "arm_upper_r", "arm_lower_r", "hand_r"]
    for part in order:
        b = bones[part]
        px, py = game(b["pivot"])
        if b["parent"]:
            qx, qy = game(bones[b["parent"]]["pivot"])
            px, py = px - qx, py - qy
        parent = path_of(b["parent"]) if b["parent"] else "Body/Skeleton"
        rel_parent = parent
        scene.node(part, "Bone2D", rel_parent, [f"position = {vec(px, py)}",
                                                f"rest = Transform2D(1, 0, 0, 1, {num(px)}, {num(py)})",
                                                "auto_calculate_length_and_angle = false", "length = 8.0"])
        svg_path = THEMES / theme / "rigs/hunter" / f"{part}.svg"
        info = svg_info(svg_path)
        tex = scene.ext_res("Texture2D", res_path(svg_path))
        sx = (info.vb[0] - b["pivot"][0]) * s
        sy = (info.vb[1] - b["pivot"][1]) * s
        scene.node("Sprite", "Sprite2D", path_of(part), [f"z_index = {b['z']}", f'texture = ExtResource("{tex}")',
                                                          "centered = false", f"position = {vec(sx, sy)}",
                                                          f"scale = {vec(1 / DENSITY, 1 / DENSITY)}"])
    # Spirit necklace glow (rule 4: spirit glows) on the upper torso.
    tex_id, mat = glow_texture(scene, "friend", PALETTES[theme])
    nx, ny = (100 - bones["torso_upper"]["pivot"][0]) * s, (95 - bones["torso_upper"]["pivot"][1]) * s
    scene.node("Emissive", "Node2D", path_of("torso_upper"), ["z_index = 9"])
    scene.node("Necklace", "Sprite2D", path_of("torso_upper") + "/Emissive",
               [f'material = SubResource("{mat}")', f'texture = SubResource("{tex_id}")',
                f"position = {vec(nx, ny)}", f"scale = {vec(0.22, 0.22)}"])

    rad = math.radians
    P = path_of
    run_len, fps = 8 / 14, 14
    anims = [
        Anim("idle", 2.4, True, [Track("Body:scale", [0, 1.2, 2.4], [vec(1, 1), vec(1, 1.03), vec(1, 1)])]),
        Anim("run", run_len, True, [
            Track("Body:position", [0, run_len / 4, run_len / 2, 3 * run_len / 4, run_len],
                  [vec(0, 0), vec(0, -4), vec(0, 0), vec(0, -4), vec(0, 0)]),
            Track(f"{P('leg_l')}:rotation", [0, run_len / 2, run_len], [num(rad(22)), num(rad(-22)), num(rad(22))]),
            Track(f"{P('leg_r')}:rotation", [0, run_len / 2, run_len], [num(rad(-22)), num(rad(22)), num(rad(-22))]),
            Track(f"{P('arm_upper_r')}:rotation", [0, run_len / 2, run_len], [num(rad(-18)), num(rad(18)), num(rad(-18))]),
            Track(f"{P('feather')}:rotation", [0, run_len / 2, run_len], [num(rad(-10)), num(rad(10)), num(rad(-10))]),
        ]),
        # draw 3 · release 2 · recover 1 at 14 fps
        Anim("shoot", 6 / fps, False, [
            Track(f"{P('string')}:position", [0, 3 / fps, 3.5 / fps, 6 / fps],
                  [_bone_pos(bones, "string", s), _bone_pos(bones, "string", s, 7), _bone_pos(bones, "string", s),
                   _bone_pos(bones, "string", s)]),
            Track(f"{P('arm_upper_l')}:rotation", [0, 3 / fps, 5 / fps, 6 / fps],
                  ["0.0", num(rad(-35)), num(rad(-30)), "0.0"]),
            Track(f"{P('arm_upper_r')}:rotation", [0, 3 / fps, 5 / fps, 6 / fps],
                  ["0.0", num(rad(30)), num(rad(10)), "0.0"]),
        ]),
        Anim("hurt", 3 / fps, False, [
            Track("Body:rotation", [0, 1 / fps, 3 / fps], ["0.0", num(rad(-12)), "0.0"]),
            Track("Body:modulate", [0, 1 / fps, 3 / fps], ["Color(1, 1, 1, 1)", "Color(1, 0.45, 0.45, 1)", "Color(1, 1, 1, 1)"]),
        ]),
        Anim("down", 10 / fps, False, [
            Track("Body:rotation", [0, 10 / fps], ["0.0", num(rad(-84))]),
            Track("Body:position", [0, 10 / fps], [vec(0, 0), vec(-6, -6)]),
            Track("Body:modulate", [0, 10 / fps], ["Color(1, 1, 1, 1)", "Color(0.8, 0.8, 0.85, 1)"]),
        ]),
        Anim("revive", 8 / fps, False, [
            Track("Body:rotation", [0, 8 / fps], [num(rad(-84)), "0.0"]),
            Track("Body:position", [0, 8 / fps], [vec(-6, -6), vec(0, 0)]),
            Track("Body:modulate", [0, 4 / fps, 8 / fps], ["Color(0.8, 0.8, 0.85, 1)", "Color(1.6, 2, 1.8, 1)", "Color(1, 1, 1, 1)"]),
        ]),
    ]
    add_animations(scene, anims)
    (THEMES / theme / "rigs/hunter.tscn").write_text(scene.text(), encoding="utf-8")


def _bone_pos(bones: dict, part: str, s: float, pull: float = 0.0) -> str:
    b, p = bones[part], bones[bones[part]["parent"]]
    return vec((b["pivot"][0] - p["pivot"][0]) * s + pull * s, (b["pivot"][1] - p["pivot"][1]) * s)


# --------------------------------------------------------------------------- tiles


def build_tileset(theme: str = "grove_default") -> None:
    tiles = ["floor", "grass", "canopy_wall", "canopy_edge"]
    lines = ["[gd_resource type=\"TileSet\" format=3]", ""]
    for i, t in enumerate(tiles):
        lines.append(f'[ext_resource type="Texture2D" path="res://themes/{theme}/tiles/{t}.svg" id="{i + 1}_{t}"]')
    lines.append("")
    for i, t in enumerate(tiles):
        props = [f'[sub_resource type="TileSetAtlasSource" id="src_{t}"]', f'texture = ExtResource("{i + 1}_{t}")',
                 "texture_region_size = Vector2i(96, 96)", "0:0/0 = 0"]
        if t == "canopy_wall":
            props += ["0:0/0/physics_layer_0/polygon_0/points = PackedVector2Array(-48, -48, 48, -48, 48, 48, -48, 48)"]
        lines += props + [""]
    lines += ["[resource]", "tile_size = Vector2i(96, 96)", "physics_layer_0/collision_layer = 64",
              "physics_layer_0/collision_mask = 0"]
    for i, t in enumerate(tiles):
        lines.append(f'sources/{i} = SubResource("src_{t}")')
    (THEMES / theme / "tiles/tiles.tres").write_text("\n".join(lines) + "\n", encoding="utf-8")


# --------------------------------------------------------------------------- fonts and UI theme


def build_fonts() -> None:
    d = THEMES / "grove_default/fonts"
    wght = 2003265652  # OpenType tag 'wght'
    for name, weight in [("baloo_extrabold", 800), ("baloo_bold", 700)]:
        (d / f"{name}.tres").write_text("\n".join([
            '[gd_resource type="FontVariation" format=3]', "",
            '[ext_resource type="FontFile" path="res://themes/grove_default/fonts/baloo2_variable.ttf" id="1_baloo"]', "",
            "[resource]", 'base_font = ExtResource("1_baloo")', f"variation_opentype = {{{wght}: {weight}}}", ""]),
            encoding="utf-8")


def stylebox(id_: str, bg: str, border: str | None = None, bw: int = 0, radius: int = 18,
             margin: tuple[int, int] = (20, 12), shadow: str | None = None) -> list[str]:
    props = [f'[sub_resource type="StyleBoxFlat" id="{id_}"]',
             f"content_margin_left = {margin[0]}.0", f"content_margin_top = {margin[1]}.0",
             f"content_margin_right = {margin[0]}.0", f"content_margin_bottom = {margin[1]}.0",
             f"bg_color = {bg}"]
    if border:
        props += [f"border_width_left = {bw}", f"border_width_top = {bw}", f"border_width_right = {bw}",
                  f"border_width_bottom = {bw + 2}", f"border_color = {border}"]
    props += [f"corner_radius_top_left = {radius}", f"corner_radius_top_right = {radius}",
              f"corner_radius_bottom_right = {radius}", f"corner_radius_bottom_left = {radius}",
              "anti_aliasing_size = 1.0"]
    if shadow:
        props += [f"shadow_color = {shadow}", "shadow_size = 10"]
    return props + [""]


def build_ui_theme(theme: str) -> None:
    p = PALETTES[theme]
    ink = color(p["night_ink"])
    fonts = "res://themes/grove_default/fonts"
    lines = ['[gd_resource type="Theme" format=3]', "",
             f'[ext_resource type="FontVariation" path="{fonts}/baloo_extrabold.tres" id="1_display"]',
             f'[ext_resource type="FontVariation" path="{fonts}/baloo_bold.tres" id="2_bold"]',
             f'[ext_resource type="FontFile" path="{fonts}/hind_medium.ttf" id="3_body"]', ""]
    lines += stylebox("primary", color(p["primary"]), ink, 3, shadow=color(p["primary"], 0.35))
    lines += stylebox("primary_hover", color(p["primary"], 0.9), ink, 3)
    lines += stylebox("primary_pressed", color(p["primary"], 0.75), ink, 3)
    lines += stylebox("reward", color(p["reward"]), ink, 3)
    lines += stylebox("reward_pressed", color(p["reward"], 0.8), ink, 3)
    lines += stylebox("secondary", color(p["secondary"]), color(p["panel_edge"]), 2)
    lines += stylebox("secondary_pressed", color(p["panel_edge"]), color(p["panel_edge"]), 2)
    lines += stylebox("locked", color(p["locked"]), color(p["locked"]), 2)
    lines += stylebox("focus", "Color(0, 0, 0, 0)", color(p["torch_gold"]), 3)
    lines += stylebox("panel", color(p["panel"], 0.94), color(p["panel_edge"]), 2, radius=22, margin=(18, 16))
    lines += stylebox("card", color(p["secondary"], 0.9), None, 0, radius=16, margin=(14, 12))
    lines += stylebox("hud_pill", color(p["night_ink"], 0.72), None, 0, radius=999, margin=(12, 4))
    lines += stylebox("bar_bg", color(p["night_ink"], 0.8), ink, 2, radius=8, margin=(0, 0))
    lines += stylebox("bar_fill", color(p["health"]), None, 0, radius=6, margin=(0, 0))
    lines += ["[resource]", 'default_font = ExtResource("3_body")', "default_font_size = 17",
              # Buttons: Baloo bold, primary spirit jade
              'Button/fonts/font = ExtResource("2_bold")', "Button/font_sizes/font_size = 22",
              f"Button/colors/font_color = {color(p['primary_text'])}",
              f"Button/colors/font_hover_color = {color(p['primary_text'])}",
              f"Button/colors/font_pressed_color = {color(p['primary_text'])}",
              f"Button/colors/font_focus_color = {color(p['primary_text'])}",
              f"Button/colors/font_disabled_color = {color(p['text_muted'])}",
              'Button/styles/normal = SubResource("primary")', 'Button/styles/hover = SubResource("primary_hover")',
              'Button/styles/pressed = SubResource("primary_pressed")', 'Button/styles/disabled = SubResource("locked")',
              'Button/styles/focus = SubResource("focus")',
              # Variations
              'RewardButton/base_type = &"Button"', f"RewardButton/colors/font_color = {color(p['reward_text'])}",
              f"RewardButton/colors/font_pressed_color = {color(p['reward_text'])}",
              f"RewardButton/colors/font_hover_color = {color(p['reward_text'])}",
              'RewardButton/styles/normal = SubResource("reward")', 'RewardButton/styles/hover = SubResource("reward")',
              'RewardButton/styles/pressed = SubResource("reward_pressed")',
              'SecondaryButton/base_type = &"Button"', f"SecondaryButton/colors/font_color = {color(p['text'])}",
              f"SecondaryButton/colors/font_hover_color = {color(p['text'])}",
              f"SecondaryButton/colors/font_pressed_color = {color(p['text'])}",
              'SecondaryButton/font_sizes/font_size = 18',
              'SecondaryButton/styles/normal = SubResource("secondary")', 'SecondaryButton/styles/hover = SubResource("secondary")',
              'SecondaryButton/styles/pressed = SubResource("secondary_pressed")',
              # Labels
              f"Label/colors/font_color = {color(p['text'])}", f"Label/colors/font_outline_color = {ink}",
              'TitleLabel/base_type = &"Label"', 'TitleLabel/fonts/font = ExtResource("1_display")',
              "TitleLabel/font_sizes/font_size = 34",
              'DisplayLabel/base_type = &"Label"', 'DisplayLabel/fonts/font = ExtResource("1_display")',
              "DisplayLabel/font_sizes/font_size = 72",
              'NumberLabel/base_type = &"Label"', 'NumberLabel/fonts/font = ExtResource("1_display")',
              "NumberLabel/font_sizes/font_size = 22", "NumberLabel/constants/outline_size = 6",
              'MutedLabel/base_type = &"Label"', f"MutedLabel/colors/font_color = {color(p['text_muted'])}",
              "MutedLabel/font_sizes/font_size = 14",
              # Panels
              'PanelContainer/styles/panel = SubResource("panel")', 'Panel/styles/panel = SubResource("panel")',
              'CardPanel/base_type = &"PanelContainer"', 'CardPanel/styles/panel = SubResource("card")',
              'HudPill/base_type = &"PanelContainer"', 'HudPill/styles/panel = SubResource("hud_pill")',
              'ProgressBar/styles/background = SubResource("bar_bg")', 'ProgressBar/styles/fill = SubResource("bar_fill")',
              "ProgressBar/font_sizes/font_size = 1", ""]
    (THEMES / theme / "ui_theme.tres").write_text("\n".join(lines), encoding="utf-8")


# --------------------------------------------------------------------------- catalogue

GROVE = [
    Visual("grove_default/rigs/rotling.tscn", "grove_default/rigs/rotling.svg", "trot"),
    Visual("grove_default/rigs/thornback.tscn", "grove_default/rigs/thornback.svg", "heavy"),
    Visual("grove_default/rigs/wisp.tscn", "grove_default/rigs/wisp.svg", "float"),
    Visual("grove_default/rigs/rotheart.tscn", "grove_default/rigs/rotheart.svg", "stomp", glow_scale=0.8),
    Visual("grove_default/rigs/hunter_front.tscn", "grove_default/rigs/hunter_front.svg", "idle"),
    Visual("grove_default/fx/wisp_orb.tscn", "grove_default/fx/wisp_orb.svg", "pulse", anchor="center"),
    Visual("grove_default/gods/meghra.tscn", "grove_default/gods/meghra.svg", "hover"),
    Visual("grove_default/gods/dhoru.tscn", "grove_default/gods/dhoru.svg", "hover"),
    Visual("grove_default/gods/vayli.tscn", "grove_default/gods/vayli.svg", "hover"),
    *[Visual(f"grove_default/gods/totem_{g}.tscn", f"grove_default/gods/totem_{g}.svg", "")
      for g in ("suryak", "tamba", "kaja", "anjor")],
    Visual("grove_default/guides/pira.tscn", "grove_default/guides/pira.svg", "glide", anchor="center"),
    Visual("grove_default/guides/hare.tscn", "grove_default/guides/hare.svg", ""),
    Visual("grove_default/guides/jugnu_fly.tscn", "grove_default/guides/jugnu_fly.svg", "twinkle", anchor="center",
           extra_glows=[(15, 15, 10, "light")]),
    Visual("grove_default/props/cage_bird.tscn", "grove_default/props/cage_bird.svg", ""),
    Visual("grove_default/props/cage_hare.tscn", "grove_default/props/cage_hare.svg", ""),
    Visual("grove_default/props/cage_jar.tscn", "grove_default/props/cage_jar.svg", ""),
    Visual("grove_default/props/bush.tscn", "grove_default/props/bush.svg", ""),
    Visual("grove_default/props/idol.tscn", "grove_default/props/idol.svg", ""),
    Visual("grove_default/props/torch.tscn", "grove_default/props/torch.svg", "flicker",
           extra_glows=[(15, 14, 13, "light")]),
    Visual("grove_default/props/gate_sealed.tscn", "grove_default/props/gate_sealed.svg", ""),
    Visual("grove_default/props/gate_open.tscn", "grove_default/props/gate_open.svg", ""),
    Visual("grove_default/props/log.tscn", "grove_default/props/log.svg", ""),
    Visual("grove_default/props/roots.tscn", "grove_default/props/roots.svg", "", anchor="center"),
    Visual("grove_default/props/dance_ring.tscn", "grove_default/props/dance_ring.svg", "", anchor="center"),
    Visual("grove_default/props/portal.tscn", "grove_default/props/portal.svg", "spin", anchor="center"),
    Visual("grove_default/fx/ash_burst.tscn", "grove_default/fx/ash_burst.svg", "", anchor="center"),
    Visual("grove_default/fx/hit_spark.tscn", "grove_default/fx/hit_spark.svg", "", anchor="center"),
    Visual("grove_default/fx/meat_drop.tscn", "grove_default/fx/meat_drop.svg", "", anchor="center"),
    Visual("grove_default/fx/spirit_drop.tscn", "grove_default/icons/spirit.svg", "pulse", anchor="center",
           extra_glows=[(20, 22, 14, "friend")]),
    Visual("grove_default/fx/rot_stain.tscn", "grove_default/fx/rot_stain.svg", "", anchor="center"),
]
REEF = [
    Visual("deep_reef/rigs/piranha.tscn", "deep_reef/rigs/piranha.svg", "trot"),
    Visual("deep_reef/rigs/crab.tscn", "deep_reef/rigs/crab.svg", "heavy"),
    Visual("deep_reef/rigs/jelly.tscn", "deep_reef/rigs/jelly.svg", "float"),
    Visual("deep_reef/rigs/angler.tscn", "deep_reef/rigs/angler.svg", "stomp", glow_scale=0.8),
    Visual("deep_reef/props/net.tscn", "deep_reef/props/net.svg", ""),
    Visual("deep_reef/props/coral.tscn", "deep_reef/props/coral.svg", "flicker", extra_glows=[(15, 14, 13, "light")]),
    Visual("deep_reef/fx/pearl_drop.tscn", "deep_reef/icons/pearl.svg", "", anchor="center"),
    Visual("deep_reef/fx/bubble_drop.tscn", "deep_reef/icons/bubble.svg", "pulse", anchor="center",
           extra_glows=[(20, 20, 14, "friend")]),
]


# --------------------------------------------------------------------------- manifests


def _r(theme: str, p: str) -> str:
    return f"res://themes/{theme}/{p}"


def build_manifests() -> None:
    """Theme manifest v2: archetypes (role, name key, visual), props, icons, tiles, strings, inheritance."""
    g, r = "grove_default", "deep_reef"
    base = {"pack_version": "1.0.0", "schema_version": 2, "min_client": "0.2.0", "max_client": "", "signature": "",
            "title_key": "THEME_TITLE"}

    def arche(theme: str, role: str, key: str, visual: str, **extra: object) -> dict:
        return {"role": role, "name_key": key, "visual": _r(theme, visual), **extra}

    grove = base | {
        "theme_id": g, "inherits": "", "ui_theme": _r(g, "ui_theme.tres"),
        "translations": [_r(g, f"strings/strings.{loc}.translation") for loc in ("en", "hi", "mr")],
        "palette": {k: v for k, v in PALETTES[g].items()},
        "lighting": {"darkness": PALETTES[g]["darkness"], "darkness_strength": 0.74, "light": PALETTES[g]["light"]},
        "archetypes": {
            "hunter": arche(g, "PLAYER", "HUNTER_NAME", "rigs/hunter.tscn"),
            "rotling": arche(g, "SWARM", "ENEMY_SWARM_NAME", "rigs/rotling.tscn",
                             flipbook={"texture": _r(g, "rigs/rotling_sheet.svg"), "meta": _r(g, "rigs/rotling_sheet.json")}),
            "thornback": arche(g, "TANK", "ENEMY_TANK_NAME", "rigs/thornback.tscn"),
            "wisp": arche(g, "RANGED", "ENEMY_RANGED_NAME", "rigs/wisp.tscn"),
            "rotheart": arche(g, "BOSS", "ENEMY_BOSS_NAME", "rigs/rotheart.tscn"),
            "cage_bird": arche(g, "CAGE_TARGET", "CAGE_NAME", "props/cage_bird.tscn"),
            "cage_hare": arche(g, "CAGE_TARGET", "CAGE_NAME", "props/cage_hare.tscn"),
            "cage_jar": arche(g, "CAGE_TARGET", "JAR_NAME", "props/cage_jar.tscn"),
            "meat": arche(g, "CURRENCY_A", "CURRENCY_A_NAME", "fx/meat_drop.tscn"),
            "spirit": arche(g, "CURRENCY_B", "CURRENCY_B_NAME", "fx/spirit_drop.tscn"),
            "torch": arche(g, "LIGHT_SOURCE", "LIGHT_NAME", "props/torch.tscn"),
            "meghra": arche(g, "BUFF_GOD", "GOD_MEGHRA_NAME", "gods/meghra.tscn"),
            "dhoru": arche(g, "BUFF_GOD", "GOD_DHORU_NAME", "gods/dhoru.tscn"),
            "vayli": arche(g, "BUFF_GOD", "GOD_VAYLI_NAME", "gods/vayli.tscn"),
            "suryak": arche(g, "META_GOD", "GOD_SURYAK_NAME", "gods/totem_suryak.tscn"),
            "tamba": arche(g, "META_GOD", "GOD_TAMBA_NAME", "gods/totem_tamba.tscn"),
            "kaja": arche(g, "META_GOD", "GOD_KAJA_NAME", "gods/totem_kaja.tscn"),
            "anjor": arche(g, "META_GOD", "GOD_ANJOR_NAME", "gods/totem_anjor.tscn"),
            "pira": arche(g, "GUIDE", "GUIDE_PIRA_NAME", "guides/pira.tscn"),
            "jugnu": arche(g, "GUIDE", "GUIDE_JUGNU_NAME", "guides/jugnu_fly.tscn"),
            "hare": arche(g, "RESCUE", "HARE_NAME", "guides/hare.tscn"),
        },
        "props": {p: _r(g, f"props/{p}.tscn") for p in
                  ("bush", "idol", "gate_sealed", "gate_open", "log", "roots", "dance_ring", "portal")}
        | {p: _r(g, f"fx/{p}.tscn") for p in ("ash_burst", "hit_spark", "rot_stain", "wisp_orb")},
        "icons": {i: _r(g, f"icons/{i}.svg") for i in
                  ("meat", "spirit", "health", "meghra", "dhoru", "vayli", "suryak", "tamba", "kaja", "anjor", "pira", "jugnu")},
        "textures": {f"arrow_{t}": _r(g, f"fx/arrow_{t}.svg") for t in ("stone", "flint", "bone", "rapid")}
        | {"wisp_orb": _r(g, "fx/wisp_orb.svg"), "hit_spark": _r(g, "fx/hit_spark.svg")},
        "tiles": _r(g, "tiles/tiles.tres"),
        "screens": {"camp": _r(g, "ui/camp_scene.svg"), "defeat": _r(g, "ui/defeat_scene.svg")},
        "files": [],
    }
    reef = base | {
        "theme_id": r, "pack_version": "0.1.0", "inherits": g, "ui_theme": _r(r, "ui_theme.tres"),
        "translations": [_r(r, f"strings/strings.{loc}.translation") for loc in ("en", "hi", "mr")],
        "palette": {k: v for k, v in PALETTES[r].items()},
        "lighting": {"darkness": PALETTES[r]["darkness"], "darkness_strength": 0.7, "light": PALETTES[r]["light"]},
        "archetypes": {
            "rotling": arche(r, "SWARM", "ENEMY_SWARM_NAME", "rigs/piranha.tscn"),
            "thornback": arche(r, "TANK", "ENEMY_TANK_NAME", "rigs/crab.tscn"),
            "wisp": arche(r, "RANGED", "ENEMY_RANGED_NAME", "rigs/jelly.tscn"),
            "rotheart": arche(r, "BOSS", "ENEMY_BOSS_NAME", "rigs/angler.tscn"),
            "cage_bird": arche(r, "CAGE_TARGET", "CAGE_NAME", "props/net.tscn"),
            "cage_hare": arche(r, "CAGE_TARGET", "CAGE_NAME", "props/net.tscn"),
            "meat": arche(r, "CURRENCY_A", "CURRENCY_A_NAME", "fx/pearl_drop.tscn"),
            "spirit": arche(r, "CURRENCY_B", "CURRENCY_B_NAME", "fx/bubble_drop.tscn"),
            "torch": arche(r, "LIGHT_SOURCE", "LIGHT_NAME", "props/coral.tscn"),
        },
        "props": {},
        "icons": {"meat": _r(r, "icons/pearl.svg"), "spirit": _r(r, "icons/bubble.svg")},
        "files": [],
    }
    for theme, manifest in ((g, grove), (r, reef)):
        (THEMES / theme / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> int:
    for v in GROVE:
        build_visual("grove_default", v)
    for v in REEF:
        build_visual("deep_reef", v)
    build_hunter()
    build_tileset()
    build_fonts()
    build_ui_theme("grove_default")
    build_ui_theme("deep_reef")
    build_manifests()
    print(f"build_scenes: {len(GROVE) + len(REEF) + 1} scenes, 1 tileset, 2 UI themes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
