#!/usr/bin/env python3
"""Extracts engine-ready SVGs from the Vanya Asset Bible design boards.

The bible is a design canvas whose boards (`*.dc.html`) draw every asset as inline SVG:
named <symbol>s, or <svg> elements with a descriptive aria-label. This script turns them
into standalone SVG files under client/themes/<theme_id>/ that Godot rasterizes at import.

    python3 pipelines/asset/extract_bible.py <boards_dir> [--godot <godot binary>]

Every asset is listed in ASSETS below with its in-game scale (game px per master px, taken
from the Grove board's mid-fight phone mock and its scale notes). Output SVGs get
width/height = cropped viewBox × scale × DENSITY, so Godot's default import gives a
texture at DENSITY× the in-game size and scenes draw it at 1/DENSITY.

Pass --godot to crop each asset to its painted bounds (rendered headlessly through
tools/svg_bounds.gd). Without it, assets keep their source viewBox.
The output is deterministic, so re-running after the bible changes gives a reviewable diff.
"""
from __future__ import annotations

import argparse
import copy
import json
import math
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CLIENT = ROOT / "client"
DENSITY = 3
SVG_NS = "http://www.w3.org/2000/svg"
VOID = {"meta", "link", "br", "img", "input", "hr", "source", "area", "base", "col", "embed", "param", "track", "wbr"}
# Presentation-only attributes from the boards that the engine must not see.
DROP_ATTRS = {"class", "style", "aria-hidden", "aria-label", "role", "overflow", "filter"}
UNSUPPORTED = {"foreignObject", "filter", "mask", "image", "animate", "animateTransform"}


# --------------------------------------------------------------------------- parsing


def _camel(name: str) -> str:
    if name.startswith("sc-camel-"):
        head, *rest = name[len("sc-camel-"):].split("-")
        return head + "".join(p.capitalize() for p in rest)
    return name


class _TreeBuilder(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.root = ET.Element("root")
        self.stack = [self.root]

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag = {"radialgradient": "radialGradient", "lineargradient": "linearGradient",
               "clippath": "clipPath", "foreignobject": "foreignObject"}.get(tag, tag)
        el = ET.SubElement(self.stack[-1], tag, {_camel(k): (v or "") for k, v in attrs})
        if tag not in VOID:
            self.stack.append(el)

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.handle_starttag(tag, attrs)
        if tag not in VOID:
            self.stack.pop()

    def handle_endtag(self, tag: str) -> None:
        if tag in VOID:
            return
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i].tag.lower() == tag.lower():
                del self.stack[i:]
                return

    def handle_data(self, data: str) -> None:
        el = self.stack[-1]
        if len(el):
            el[-1].tail = (el[-1].tail or "") + data
        else:
            el.text = (el.text or "") + data


class Board:
    def __init__(self, path: Path) -> None:
        text = path.read_text(encoding="utf-8")
        body = text[text.index("<x-dc>"):text.index("</x-dc>")]
        builder = _TreeBuilder()
        builder.feed(body)
        self.name = path.stem.replace(".dc", "")
        self.root = builder.root
        self.ids: dict[str, ET.Element] = {}
        for el in self.root.iter():
            if "id" in el.attrib:
                self.ids.setdefault(el.attrib["id"], el)

    def symbol(self, sym_id: str) -> ET.Element:
        el = self.ids.get(sym_id)
        if el is None or el.tag != "symbol":
            raise KeyError(f"{self.name}: no <symbol id='{sym_id}'>")
        return el

    def after(self, marker: str, index: int) -> ET.Element:
        """The index-th <svg> that follows the first element whose text is `marker` (unlabelled art)."""
        seen = False
        count = 0
        for el in self.root.iter():
            if not seen and (el.text or "").strip() == marker:
                seen = True
            elif seen and el.tag == "svg":
                if count == index:
                    return el
                count += 1
        raise KeyError(f"{self.name}: no <svg> #{index} after '{marker}'")

    def labelled(self, label: str) -> ET.Element:
        for el in self.root.iter("svg"):
            if el.attrib.get("aria-label") == label:
                return el
        raise KeyError(f"{self.name}: no <svg aria-label='{label}'>")


# --------------------------------------------------------------------------- svg building


def _viewbox(el: ET.Element) -> tuple[float, float, float, float]:
    x, y, w, h = (float(v) for v in el.attrib["viewBox"].replace(",", " ").split())
    return x, y, w, h


def _f(v: float) -> str:
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def _ref_id(value: str) -> str | None:
    m = re.match(r"url\(#([^)]+)\)", value.strip())
    return m.group(1) if m else None


class SvgBuilder:
    """Resolves <use>, patterns and paint servers of one board into a standalone SVG."""

    def __init__(self, board: Board) -> None:
        self.board = board
        self.paint_ids: set[str] = set()

    def inline(self, el: ET.Element) -> ET.Element:
        out = ET.Element(el.tag)
        for k, v in el.attrib.items():
            if k in DROP_ATTRS or k.startswith("data-") or k.startswith("aria-"):
                continue
            out.set(k, v)
        out.text = el.text if el.tag == "text" else None
        for child in el:
            tag = child.tag
            if tag in ("defs", "title", "desc", "text", "symbol"):
                continue
            if tag in UNSUPPORTED:
                raise ValueError(f"{self.board.name}: unsupported <{tag}> in asset")
            if tag == "use":
                out.append(self._resolve_use(child))
            elif tag == "rect" and _ref_id(child.attrib.get("fill", "")) in self._patterns():
                out.append(self._expand_pattern(child))
            else:
                out.append(self.inline(child))
            out[-1].tail = None
        for k in ("fill", "stroke"):
            ref = _ref_id(out.attrib.get(k, ""))
            if ref:
                self.paint_ids.add(ref)
        return out

    def _patterns(self) -> set[str]:
        return {k for k, v in self.board.ids.items() if v.tag == "pattern"}

    def _resolve_use(self, use: ET.Element) -> ET.Element:
        ref = use.attrib.get("href", use.attrib.get("xlink:href", "")).lstrip("#")
        target = self.board.ids.get(ref)
        if target is None:
            raise KeyError(f"{self.board.name}: <use> of unknown #{ref}")
        g = ET.Element("g")
        transforms = []
        x, y = float(use.attrib.get("x", 0)), float(use.attrib.get("y", 0))
        if x or y:
            transforms.append(f"translate({_f(x)} {_f(y)})")
        if target.tag == "symbol" and "viewBox" in target.attrib:
            vx, vy, vw, vh = _viewbox(target)
            w = float(use.attrib.get("width", vw))
            h = float(use.attrib.get("height", vh))
            s = min(w / vw, h / vh)  # preserveAspectRatio xMidYMid meet
            dx, dy = (w - vw * s) / 2, (h - vh * s) / 2
            transforms.append(f"translate({_f(dx)} {_f(dy)}) scale({_f(s)}) translate({_f(-vx)} {_f(-vy)})")
            inner = self.inline(target)
            inner.tag = "g"
            inner.attrib.pop("viewBox", None)
            inner.attrib.pop("id", None)
        else:
            inner = self.inline(target)
            inner.attrib.pop("id", None)
        for k in ("opacity", "transform"):
            if k in use.attrib:
                g.set(k, use.attrib[k]) if k == "opacity" else transforms.insert(0, use.attrib[k])
        if transforms:
            g.set("transform", " ".join(transforms))
        g.append(inner)
        return g

    def _expand_pattern(self, rect: ET.Element) -> ET.Element:
        pattern = self.board.ids[_ref_id(rect.attrib["fill"]) or ""]
        pw, ph = float(pattern.attrib["width"]), float(pattern.attrib["height"])
        rx, ry = float(rect.attrib.get("x", 0)), float(rect.attrib.get("y", 0))
        rw, rh = float(rect.attrib["width"]), float(rect.attrib["height"])
        clip_id = f"clip_{pattern.attrib['id']}_{len(self.paint_ids)}"
        clip = ET.Element("clipPath", {"id": clip_id})
        ET.SubElement(clip, "rect", {"x": _f(rx), "y": _f(ry), "width": _f(rw), "height": _f(rh)})
        self.extra_defs.append(clip)
        g = ET.Element("g", {"clip-path": f"url(#{clip_id})"})
        for ty in range(int(ry // ph), math.ceil((ry + rh) / ph)):
            for tx in range(int(rx // pw), math.ceil((rx + rw) / pw)):
                tile = ET.SubElement(g, "g", {"transform": f"translate({_f(tx * pw)} {_f(ty * ph)})"})
                for child in pattern:
                    tile.append(self.inline(child))
        return g

    def document(self, content: ET.Element, viewbox: tuple[float, float, float, float], scale: float) -> ET.Element:
        x, y, w, h = viewbox
        svg = ET.Element("svg", {
            "xmlns": SVG_NS,
            "viewBox": f"{_f(x)} {_f(y)} {_f(w)} {_f(h)}",
            "width": _f(round(w * scale * DENSITY, 2)),
            "height": _f(round(h * scale * DENSITY, 2)),
        })
        defs = ET.SubElement(svg, "defs")
        resolved: set[str] = set()
        pending = sorted(self.paint_ids)
        while pending:
            pid = pending.pop()
            if pid in resolved:
                continue
            resolved.add(pid)
            src = self.board.ids.get(pid)
            if src is None:
                raise KeyError(f"{self.board.name}: missing paint server #{pid}")
            paint = copy.deepcopy(src)
            for el in paint.iter():
                for k in list(el.attrib):
                    if k in ("class", "style"):
                        del el.attrib[k]
            href = paint.attrib.get("href", "").lstrip("#")
            if href:
                pending.append(href)
            defs.append(paint)
        for d in self.extra_defs:
            defs.append(d)
        if not len(defs):
            svg.remove(defs)
        for child in content:
            svg.append(child)
        return svg

    extra_defs: list[ET.Element]

    def build(self, source: ET.Element, scale: float, viewbox: tuple[float, float, float, float] | None = None) -> ET.Element:
        self.paint_ids = set()
        self.extra_defs = []
        content = self.inline(source)
        return self.document(content, viewbox or _viewbox(source), scale)


# --------------------------------------------------------------------------- asset specs


@dataclass
class Asset:
    out: str                       # path under client/themes/
    board: str                     # board file stem
    symbol: str = ""               # <symbol id>
    label: str = ""                # <svg aria-label>
    after: str = ""                # or: the index-th <svg> after this heading text
    index: int = 0
    scale: float = 1.0             # game px per master px
    crop: bool = True
    strip_floor: bool = False      # drop the board's floor-tile backdrop behind a prop
    meta: dict = field(default_factory=dict)


S_HUNTER = 78 / 260          # Grove: "Hunter 78 px tall on a 390-wide screen"
S_ROTLING = 54 / 220         # phone mock: rotlings 52-58 px wide
S_THORN = 88 / 260           # phone mock: 88 x 68
S_WISP = 46 / 160            # phone mock: 46 x 52
S_BOSS = 190 / 560           # Rotheart: in-game width 190 px
S_TILE = 32 / 64             # tile 64 px master, 32 px in game
S_ICON = 1.0
S_GOD = 0.45
S_TOTEM = 0.5
S_CAGE = 64 / 150            # a cage is two tiles wide

ASSETS: list[Asset] = [
    # --- beasts and boss
    Asset("grove_default/rigs/rotling.svg", "BlightBeasts", symbol="rotling", scale=S_ROTLING),
    Asset("grove_default/rigs/thornback.svg", "BlightBeasts", symbol="thornback", scale=S_THORN),
    Asset("grove_default/rigs/wisp.svg", "BlightBeasts", symbol="wisp", scale=S_WISP),
    Asset("grove_default/fx/wisp_orb.svg", "BlightBeasts", label="Wisp spit projectile", scale=0.4),
    Asset("grove_default/rigs/rotheart.svg", "Rotheart", symbol="rotheart", scale=S_BOSS),
    # --- hunter (whole figure for UI; parts come from the rig spec below)
    Asset("grove_default/rigs/hunter_front.svg", "Hunter", symbol="hFront", scale=S_HUNTER),
    Asset("grove_default/rigs/hunter_aim.svg", "Store", symbol="hunterAim", scale=S_HUNTER),
    *[Asset(f"grove_default/fx/arrow_{tier}.svg", "Hunter", after="Arrow tiers", index=i, scale=0.26)
      for i, tier in enumerate(("stone", "flint", "bone", "rapid"))],
    # --- gods, totems, guides, cages
    Asset("grove_default/gods/meghra.svg", "Gods", label="Meghra, the Storm Mother", scale=S_GOD),
    Asset("grove_default/gods/dhoru.svg", "Gods", label="Dhoru, the Stone Bull", scale=S_GOD),
    Asset("grove_default/gods/vayli.svg", "Gods", label="Vayli, the Vine Keeper", scale=S_GOD),
    Asset("grove_default/gods/totem_suryak.svg", "Gods", label="Suryak totem, the Sun Eye", scale=S_TOTEM),
    Asset("grove_default/gods/totem_tamba.svg", "Gods", label="Tamba totem, the Earth Drum", scale=S_TOTEM),
    Asset("grove_default/gods/totem_kaja.svg", "Gods", label="Kaja totem, the Swift Wind", scale=S_TOTEM),
    Asset("grove_default/gods/totem_anjor.svg", "Gods", label="Anjor totem, the First Flame", scale=S_TOTEM),
    Asset("grove_default/guides/pira.svg", "Guides", symbol="pira", scale=40 / 220),
    Asset("grove_default/guides/hare.svg", "Guides", symbol="hare", scale=0.4),
    Asset("grove_default/guides/jugnu_fly.svg", "Guides", symbol="fly", scale=0.5),
    Asset("grove_default/props/cage_back.svg", "Guides", symbol="cageBack", scale=S_CAGE),
    Asset("grove_default/props/cage_front.svg", "Guides", symbol="cageFront", scale=S_CAGE),
    Asset("grove_default/props/cage_bird.svg", "Guides", label="Caged bird", scale=S_CAGE),
    Asset("grove_default/props/cage_hare.svg", "Guides", label="Caged hare", scale=S_CAGE),
    Asset("grove_default/props/cage_jar.svg", "Guides", label="Firefly jar", scale=S_CAGE),
    # --- grove props and tiles
    Asset("grove_default/props/bush.svg", "Grove", symbol="bush", scale=1.25),
    Asset("grove_default/props/idol.svg", "Grove", symbol="idol", scale=34 / 40),
    Asset("grove_default/props/torch.svg", "Grove", symbol="torch", scale=1.0),
    Asset("grove_default/tiles/floor.svg", "Grove", label="Earth floor tile", scale=S_TILE, crop=False),
    Asset("grove_default/tiles/grass.svg", "Grove", label="Grass floor tile", scale=S_TILE, crop=False),
    Asset("grove_default/tiles/canopy_wall.svg", "Grove", label="Canopy wall tile", scale=S_TILE, crop=False),
    Asset("grove_default/tiles/canopy_edge.svg", "Grove", label="Canopy edge tile", scale=S_TILE, crop=False),
    Asset("grove_default/props/gate_sealed.svg", "Grove", label="Exit gate, sealed", scale=1.0),
    Asset("grove_default/props/gate_open.svg", "Grove", label="Exit gate, open", scale=1.0),
    Asset("grove_default/props/log.svg", "Grove", label="Fallen log obstacle", scale=S_TILE * 2, strip_floor=True),
    Asset("grove_default/props/roots.svg", "Grove", label="Blight roots", scale=S_TILE * 2, strip_floor=True),
    Asset("grove_default/props/dance_ring.svg", "Grove", label="Warli dance ring decal", scale=2.5, strip_floor=True),
    Asset("grove_default/props/portal.svg", "Grove", label="Spawn portal", scale=1.0, strip_floor=True),
    # --- fx
    Asset("grove_default/fx/spawn_portal.svg", "BlightBeasts", label="Spawn portal", scale=0.5),
    Asset("grove_default/fx/ash_burst.svg", "BlightBeasts", label="Death ash burst", scale=0.5),
    Asset("grove_default/fx/hit_spark.svg", "BlightBeasts", label="Hit spark", scale=0.4),
    Asset("grove_default/fx/meat_drop.svg", "BlightBeasts", label="Meat drop", scale=0.4),
    Asset("grove_default/fx/rot_stain.svg", "BlightBeasts", label="Rot stain decal", scale=0.6),
    # --- icons (48 px in UI)
    *[Asset(f"grove_default/icons/{name}.svg", "Screens", label=label, scale=48 / size)
      for name, label, size in [
          ("meat", "Meat", 24), ("spirit", "Spirit", 40), ("health", "Health", 24),
          ("meghra", "Meghra", 40), ("dhoru", "Dhoru", 40), ("vayli", "Vayli", 40),
          ("suryak", "Suryak", 40), ("tamba", "Tamba", 40), ("kaja", "Kaja", 40),
          ("anjor", "Anjor", 40), ("pira", "Pira", 220), ("jugnu", "Jugnu", 40)]],
    # --- screen art
    Asset("grove_default/ui/camp_scene.svg", "Screens", label="Hunters' camp at night: fire, hut and shrine totems", scale=1.0, crop=False),
    Asset("grove_default/ui/defeat_scene.svg", "Screens", label="The hunter lies fallen in the dark grove while spirit motes rise", scale=1.0, crop=False),
    # --- deep reef test theme (ThemeMap board)
    Asset("deep_reef/rigs/piranha.svg", "ThemeMap", symbol="rPiranha", scale=S_ROTLING),
    Asset("deep_reef/rigs/crab.svg", "ThemeMap", symbol="rCrab", scale=S_THORN),
    Asset("deep_reef/rigs/jelly.svg", "ThemeMap", symbol="rJelly", scale=S_WISP),
    Asset("deep_reef/rigs/angler.svg", "ThemeMap", symbol="rAngler", scale=S_BOSS),
    Asset("deep_reef/props/net.svg", "ThemeMap", symbol="rNet", scale=S_CAGE),
    Asset("deep_reef/props/coral.svg", "ThemeMap", symbol="rCoral", scale=1.0),
    Asset("deep_reef/icons/pearl.svg", "ThemeMap", symbol="rPearl", scale=2.0),
    Asset("deep_reef/icons/bubble.svg", "ThemeMap", symbol="rBubble", scale=1.2),
]

# Hunter cut-out rig: RigSpec's exploded figure, in document order, with each layer's
# number from the rig table. Undoing each group's translate puts the part back in hFront space.
HUNTER_PARTS = ["string", "bow", "leg_l", "leg_r", "arm_upper_l", "arm_lower_l", "arm_upper_r",
                "arm_lower_r", "torso_lower", "torso_upper", "hand_l", "hand_r", "head", "feather"]
HUNTER_TABLE = [  # layer number order: (part, pivot name, parent bone)
    ("head", "neck", "torso_upper"), ("feather", "knot", "head"), ("torso_upper", "waist", ""),
    ("torso_lower", "waist", ""), ("arm_upper_l", "shoulder", "torso_upper"),
    ("arm_lower_l", "elbow", "arm_upper_l"), ("hand_l", "wrist", "arm_lower_l"),
    ("arm_upper_r", "shoulder", "torso_upper"), ("arm_lower_r", "elbow", "arm_upper_r"),
    ("hand_r", "wrist", "arm_lower_r"), ("leg_l", "hip socket", "torso_lower"),
    ("leg_r", "hip socket", "torso_lower"), ("bow", "grip", "hand_l"), ("string", "centre", "bow"),
]
# Draw order front to back in hFront: feather behind head; bow over arm, under hand.
HUNTER_Z = {"leg_l": 0, "leg_r": 0, "arm_upper_l": 1, "arm_lower_l": 1, "arm_upper_r": 1,
            "arm_lower_r": 1, "bow": 2, "string": 3, "hand_l": 4, "hand_r": 4,
            "torso_upper": 5, "torso_lower": 6, "feather": 7, "head": 8}

FLIPBOOK_CLIPS = [("run", 6, True), ("lunge", 3, False), ("death", 5, False)]


# --------------------------------------------------------------------------- writers


def _write(svg: ET.Element, path: Path) -> None:
    ET.register_namespace("", SVG_NS)
    ET.indent(svg, space=" ")
    text = ET.tostring(svg, encoding="unicode").replace(' xmlns:ns0="http://www.w3.org/2000/svg"', "")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text + "\n", encoding="utf-8")


def _parse_translate(transform: str) -> tuple[float, float]:
    m = re.fullmatch(r"\s*translate\(\s*(-?[\d.]+)[\s,]+(-?[\d.]+)\s*\)\s*", transform)
    if not m:
        raise ValueError(f"expected a plain translate(), got {transform!r}")
    return float(m.group(1)), float(m.group(2))


def extract_hunter_rig(board: Board, out_dir: Path) -> list[Asset]:
    exploded = board.labelled("Hunter rig exploded into 14 parts with numbered pivot points")
    wrapper = [c for c in exploded if c.tag == "g"]
    groups = wrapper[:14]
    if len(groups) != 14:
        raise ValueError(f"expected 14 rig groups, found {len(groups)}")
    pivots = [c for c in exploded if c.tag == "circle" and c.attrib.get("fill") == "#6ff2b0"]
    if len(pivots) != 14:
        raise ValueError(f"expected 14 pivots, found {len(pivots)}")
    offsets = {name: _parse_translate(g.attrib["transform"]) for name, g in zip(HUNTER_PARTS, groups)}
    builder = SvgBuilder(board)
    hfront_vb = _viewbox(board.symbol("hFront"))
    bones = []
    assets = []
    for number, (part, pivot_name, parent) in enumerate(HUNTER_TABLE, start=1):
        g = groups[HUNTER_PARTS.index(part)]
        dx, dy = offsets[part]
        px = float(pivots[number - 1].attrib["cx"]) - dx
        py = float(pivots[number - 1].attrib["cy"]) - dy
        part_el = copy.deepcopy(g)
        part_el.attrib.pop("transform")
        holder = ET.Element("g")
        holder.append(part_el)
        svg = builder.build(holder, S_HUNTER, hfront_vb)
        rel = f"grove_default/rigs/hunter/{part}.svg"
        _write(svg, out_dir / rel)
        assets.append(Asset(rel, "RigSpec", scale=S_HUNTER))
        bones.append({"layer": number, "part": part, "svg_layer": f"hunter/{part}", "pivot_name": pivot_name,
                      "pivot": [round(px, 2), round(py, 2)], "parent": parent, "z": HUNTER_Z[part]})
    rig = {"source": "Asset Bible v1.1 · 11 Rigs and export", "master_size": [hfront_vb[2], hfront_vb[3]],
           "game_scale": round(S_HUNTER, 6), "density": DENSITY, "bones": bones}
    (out_dir / "grove_default/rigs/hunter").mkdir(parents=True, exist_ok=True)
    (out_dir / "grove_default/rigs/hunter/rig.json").write_text(json.dumps(rig, indent=2) + "\n", encoding="utf-8")
    return assets


def extract_flipbook(board: Board, out_dir: Path) -> None:
    """Bakes RigSpec's rotling clips into one horizontal sheet: run 6, lunge 3, death 5."""
    frames = [el for el in board.root.iter("svg")
              if el.attrib.get("viewBox") == "0 0 220 160" and any(u.tag == "use" for u in el.iter())
              and el.attrib.get("width") == "84"]
    expected = sum(n for _, n, _ in FLIPBOOK_CLIPS)
    if len(frames) != expected:
        raise ValueError(f"expected {expected} flipbook frames, found {len(frames)}")
    builder = SvgBuilder(board)
    vx, vy, vw, vh = 0.0, 0.0, 220.0, 160.0
    pad = 2 / (S_ROTLING * DENSITY)  # 2 texture px between cells
    cell_w = vw + pad
    sheet = ET.Element("g")
    paint: set[str] = set()
    for i, frame in enumerate(frames):
        builder.paint_ids = set()
        builder.extra_defs = []
        content = builder.inline(frame)
        paint |= builder.paint_ids
        clip_id = f"cell{i}"
        cell = ET.SubElement(sheet, "g", {"transform": f"translate({_f(i * cell_w)} 0)"})
        clip = ET.SubElement(cell, "clipPath", {"id": clip_id})
        ET.SubElement(clip, "rect", {"width": _f(vw), "height": _f(vh)})
        inner = ET.SubElement(cell, "g", {"clip-path": f"url(#{clip_id})"})
        for child in content:
            inner.append(child)
    builder.paint_ids = paint
    builder.extra_defs = []
    total_w = cell_w * len(frames) - pad
    svg = builder.document(sheet, (vx, vy, total_w, vh), S_ROTLING)
    _write(svg, out_dir / "grove_default/rigs/rotling_sheet.svg")
    clips, start = {}, 0
    for name, count, loop in FLIPBOOK_CLIPS:
        clips[name] = {"start": start, "count": count, "loop": loop}
        start += count
    meta = {"source": "Asset Bible v1.1 · 11 Rigs and export", "frames": len(frames),
            "cell_size_px": [round(vw * S_ROTLING * DENSITY, 2), round(vh * S_ROTLING * DENSITY, 2)],
            "cell_stride_px": round(cell_w * S_ROTLING * DENSITY, 4), "density": DENSITY, "clips": clips}
    (out_dir / "grove_default/rigs/rotling_sheet.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")


def extract_icon(board: Board) -> None:
    builder = SvgBuilder(board)
    svg = builder.build(board.labelled("App icon: Warli-style archer drawing a bow with a jade arrow"), 1.0 / DENSITY)
    _write(svg, CLIENT / "icon.svg")


def crop_assets(godot: str, out_dir: Path, assets: list[Asset]) -> None:
    """Renders each asset at 1 texture px per viewBox unit and tightens its viewBox to the painted area."""
    targets = [a for a in assets if a.crop]
    with tempfile.TemporaryDirectory() as tmp:
        listing = Path(tmp) / "list.txt"
        listing.write_text("\n".join(str(out_dir / a.out) for a in targets) + "\n", encoding="utf-8")
        result = Path(tmp) / "bounds.json"
        subprocess.run([godot, "--headless", "--path", str(CLIENT), "-s", str(ROOT / "tools/svg_bounds.gd"),
                        "--", str(listing), str(result)], check=True, capture_output=True)
        bounds = json.loads(result.read_text(encoding="utf-8"))
    for a in targets:
        path = out_dir / a.out
        b = bounds.get(str(path))
        if not b:
            continue
        svg = ET.parse(path).getroot()
        x, y, w, h = _viewbox(svg)
        sx, sy = float(svg.attrib["width"]) / w, float(svg.attrib["height"]) / h
        margin = 2.0
        nx = x + max(0.0, b[0] - margin) / sx
        ny = y + max(0.0, b[1] - margin) / sy
        nw = min(w - (nx - x), (b[2] + 2 * margin) / sx)
        nh = min(h - (ny - y), (b[3] + 2 * margin) / sy)
        svg.set("viewBox", f"{_f(nx)} {_f(ny)} {_f(nw)} {_f(nh)}")
        svg.set("width", _f(round(nw * sx, 2)))
        svg.set("height", _f(round(nh * sy, 2)))
        for el in svg.iter():
            el.tag = el.tag.replace("{" + SVG_NS + "}", "")
        svg.set("xmlns", SVG_NS)
        _write(svg, path)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("boards", type=Path, help="folder with the bible's *.dc.html boards")
    ap.add_argument("--godot", help="Godot binary, used to crop assets to their painted bounds")
    args = ap.parse_args()

    boards = {p.stem.replace(".dc", ""): Board(p) for p in sorted(args.boards.glob("*.dc.html"))}
    out_dir = CLIENT / "themes"
    written: list[Asset] = []
    for a in ASSETS:
        board = boards[a.board]
        if a.symbol:
            source = board.symbol(a.symbol)
        elif a.after:
            source = board.after(a.after, a.index)
        else:
            source = board.labelled(a.label)
        if a.strip_floor:
            source = copy.deepcopy(source)
            for child in list(source):
                if child.tag == "rect" and _ref_id(child.attrib.get("fill", "")) == "floor":
                    source.remove(child)
        svg = SvgBuilder(board).build(source, a.scale)
        _write(svg, out_dir / a.out)
        written.append(a)
    written += extract_hunter_rig(boards["RigSpec"], out_dir)
    extract_flipbook(boards["RigSpec"], out_dir)
    extract_icon(boards["Store"])
    if args.godot:
        crop_assets(args.godot, out_dir, written)
    print(f"extract_bible: wrote {len(written) + 2} SVGs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
