#!/usr/bin/env python3
"""Draws the avatar set: app/assets/avatars/01.svg … 24.svg.

    python3 tool/make_avatars.py [--preview out.html]

Every avatar is drawn here, from shapes, in one shared style — a round
backdrop in the avatar's own colour, a front-facing head, and the same big
glossy eyes and blush on every face, animal or person. A set looks designed
when its parts agree with each other; generating them from common pieces is
how they agree.

Nothing is traced or taken from another platform, so there is nothing to
license. The characters are original: none is meant to be anyone from an
existing series.

Only features flutter_svg renders are used — shapes, paths, linear and
radial gradients, a circular clipPath. No filters, masks or CSS.

The ids are permanent and match app/lib/data/avatars.dart. Where a subject
survived the redesign it kept its id (a tiger was 2 and is still 2), so
nobody's avatar turns into a different animal.
"""

from __future__ import annotations

import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "app/assets/avatars"

INK = "#241a33"  # eyes and line work, everywhere
BLUSH = "#ff6f9c"


# --- shared parts ------------------------------------------------------------

def svg(n: int, bg: tuple[str, str], body: str, defs: str = "") -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
<defs>
<radialGradient id="bg{n}" cx="0.35" cy="0.3" r="0.85">
<stop offset="0" stop-color="{bg[0]}"/><stop offset="1" stop-color="{bg[1]}"/>
</radialGradient>
<clipPath id="c{n}"><circle cx="64" cy="64" r="64"/></clipPath>
{defs}
</defs>
<g clip-path="url(#c{n})">
<rect width="128" height="128" fill="url(#bg{n})"/>
<circle cx="40" cy="30" r="34" fill="#ffffff" fill-opacity="0.10"/>
{body}
</g>
</svg>
"""


def eyes(y: float = 74, dx: float = 13, rx: float = 5.4, ry: float = 6.8) -> str:
    """The animal eye: dark, round, two highlights."""
    out = []
    for s in (-1, 1):
        cx = 64 + s * dx
        out.append(
            f'<ellipse cx="{cx}" cy="{y}" rx="{rx}" ry="{ry}" fill="{INK}"/>'
            f'<circle cx="{cx - rx * 0.32}" cy="{y - ry * 0.36}" r="{rx * 0.42}" fill="#fff"/>'
            f'<circle cx="{cx + rx * 0.38}" cy="{y + ry * 0.36}" r="{rx * 0.17}" fill="#fff"/>'
        )
    return "".join(out)


def anime_eyes(n: int, iris: str, deep: str, y: float = 80, dx: float = 14,
               rx: float = 6.6, ry: float = 8.4, lash: str = INK) -> tuple[str, str]:
    """The person eye: coloured iris shading downward, lash line, highlights."""
    defs = (
        f'<linearGradient id="iris{n}" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{deep}"/><stop offset="1" stop-color="{iris}"/>'
        f"</linearGradient>"
    )
    out = []
    for s in (-1, 1):
        cx = 64 + s * dx
        out.append(
            f'<ellipse cx="{cx}" cy="{y}" rx="{rx}" ry="{ry}" fill="url(#iris{n})"/>'
            f'<ellipse cx="{cx}" cy="{y + 1}" rx="{rx * 0.5}" ry="{ry * 0.55}" fill="{deep}"/>'
            f'<circle cx="{cx - rx * 0.34}" cy="{y - ry * 0.38}" r="{rx * 0.4}" fill="#fff"/>'
            f'<circle cx="{cx + rx * 0.4}" cy="{y + ry * 0.4}" r="{rx * 0.17}" fill="#fff"/>'
            f'<path d="M{cx - rx - 2} {y - ry * 0.3} Q{cx} {y - ry - 4.5} {cx + rx + 2} {y - ry * 0.3}"'
            f' stroke="{lash}" stroke-width="2.8" fill="none" stroke-linecap="round"/>'
        )
    return "".join(out), defs


def blush(y: float = 86, dx: float = 22, rx: float = 5.5, op: float = 0.38) -> str:
    return "".join(
        f'<ellipse cx="{64 + s * dx}" cy="{y}" rx="{rx}" ry="{rx * 0.55}" fill="{BLUSH}" fill-opacity="{op}"/>'
        for s in (-1, 1)
    )


def smile(y: float = 88, w: float = 5, color: str = INK, width: float = 2.4) -> str:
    return (f'<path d="M{64 - w} {y} Q64 {y + w * 0.9} {64 + w} {y}" stroke="{color}"'
            f' stroke-width="{width}" fill="none" stroke-linecap="round"/>')


def cat_mouth(y: float = 90, color: str = INK) -> str:
    """The small 'w' under an animal nose."""
    return (f'<path d="M58 {y} Q61 {y + 4} 64 {y} Q67 {y + 4} 70 {y}" stroke="{color}"'
            f' stroke-width="2.2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')


def shoulders(color: str, shade: str, y: float = 112) -> str:
    return (f'<path d="M14 136 Q18 {y} 64 {y - 4} Q110 {y} 114 136 Z" fill="{color}"/>'
            f'<path d="M50 {y - 3} L64 {y + 12} L78 {y - 3}" stroke="{shade}" stroke-width="3" fill="none"/>')


# --- trading animals -----------------------------------------------------------

def owl(n):
    body = f"""
<path d="M26 60 L34 24 L54 44 Z" fill="#7a4e33"/><path d="M102 60 L94 24 L74 44 Z" fill="#7a4e33"/>
<circle cx="64" cy="78" r="42" fill="#8d5b3b"/>
<path d="M30 108 Q64 90 98 108 L98 136 L30 136 Z" fill="#b07a52"/>
<path d="M50 116 l4 5 l4 -5 M62 118 l4 5 l4 -5 M74 116 l4 5 l4 -5" stroke="#8d5b3b" stroke-width="2" fill="none" stroke-linecap="round"/>
<circle cx="49" cy="72" r="18" fill="#f1dcbc"/><circle cx="79" cy="72" r="18" fill="#f1dcbc"/>
<circle cx="49" cy="72" r="11.5" fill="#f6b93b"/><circle cx="79" cy="72" r="11.5" fill="#f6b93b"/>
{eyes(72, 15, 6.4, 7.4)}
<path d="M59 84 L69 84 L64 94 Z" fill="#f0832b"/>
"""
    return svg(n, ("#5b4aa8", "#231a4f"), body)


def tiger(n):
    body = f"""
<circle cx="34" cy="44" r="13" fill="#f28c28"/><circle cx="94" cy="44" r="13" fill="#f28c28"/>
<circle cx="34" cy="44" r="6.5" fill="#ffd9b3"/><circle cx="94" cy="44" r="6.5" fill="#ffd9b3"/>
<ellipse cx="64" cy="76" rx="40" ry="37" fill="#f7931e"/>
<path d="M56 40 L60 54 L64 40 Z M66 40 L68 52 L72 41 Z M48 44 L54 55 L56 42 Z" fill="#3a2418"/>
<path d="M24 70 L40 74 L24 78 Z M26 86 L40 84 L28 92 Z M104 70 L88 74 L104 78 Z M102 86 L88 84 L100 92 Z" fill="#3a2418"/>
<ellipse cx="54" cy="92" rx="13" ry="11" fill="#fff6ea"/><ellipse cx="74" cy="92" rx="13" ry="11" fill="#fff6ea"/>
<ellipse cx="64" cy="102" rx="10" ry="6" fill="#fff6ea"/>
{eyes(72, 15)}
<path d="M59 85 Q64 82 69 85 Q66 90 64 90 Q62 90 59 85 Z" fill="#6b3a2a"/>
{cat_mouth(92, "#6b3a2a")}
{blush(88, 27, 4.5, 0.3)}
"""
    return svg(n, ("#27b37f", "#0b5a45"), body)


def fox(n):
    body = f"""
<path d="M30 66 L28 16 L60 46 Z" fill="#ff8a3d"/><path d="M98 66 L100 16 L68 46 Z" fill="#ff8a3d"/>
<path d="M34 56 L33 26 L52 44 Z" fill="#ffe3cc"/><path d="M94 56 L95 26 L76 44 Z" fill="#ffe3cc"/>
<path d="M28 16 L34 26 L37 20 Z M100 16 L94 26 L91 20 Z" fill="#3b2a2a"/>
<path d="M22 64 Q64 30 106 64 Q100 98 64 112 Q28 98 22 64 Z" fill="#ff8a3d"/>
<path d="M64 76 L30 76 Q38 104 64 112 Q90 104 98 76 Z" fill="#fff4ea"/>
{eyes(72, 17, 5.2, 6.6)}
<ellipse cx="64" cy="94" rx="6" ry="4.5" fill="{INK}"/>
<circle cx="62.3" cy="92.8" r="1.4" fill="#fff" fill-opacity="0.7"/>
{smile(101, 4)}
{blush(86, 27, 4.5, 0.35)}
"""
    return svg(n, ("#7c6cf0", "#33298f"), body)


def wolf(n):
    body = f"""
<circle cx="98" cy="28" r="10" fill="#f5f3dc" fill-opacity="0.9"/>
<path d="M28 64 L30 18 L58 44 Z" fill="#7d879a"/><path d="M100 64 L98 18 L70 44 Z" fill="#7d879a"/>
<path d="M34 56 L35 28 L51 44 Z" fill="#c9d0dc"/><path d="M94 56 L93 28 L77 44 Z" fill="#c9d0dc"/>
<path d="M20 66 Q64 30 108 66 L100 96 Q64 118 28 96 Z" fill="#8c96a8"/>
<path d="M64 56 L40 70 Q44 108 64 112 Q84 108 88 70 Z" fill="#e4e8ef"/>
<path d="M64 40 L56 56 L64 62 L72 56 Z" fill="#6f7a8d"/>
{eyes(73, 16, 5.2, 6.4)}
<ellipse cx="64" cy="94" rx="7" ry="5" fill="{INK}"/>
{smile(102, 4)}
"""
    return svg(n, ("#34467e", "#111834"), body)


def lion(n):
    mane = "".join(
        f'<circle cx="{64 + 44 * c:.1f}" cy="{74 + 44 * s:.1f}" r="15" fill="#d9772b"/>'
        for c, s in [(1, 0), (0.87, 0.5), (0.5, 0.87), (0, 1), (-0.5, 0.87), (-0.87, 0.5),
                     (-1, 0), (-0.87, -0.5), (-0.5, -0.87), (0, -1), (0.5, -0.87), (0.87, -0.5)]
    )
    body = f"""
{mane}
<circle cx="64" cy="74" r="44" fill="#e08a36"/>
<circle cx="40" cy="48" r="9" fill="#f5c16c"/><circle cx="88" cy="48" r="9" fill="#f5c16c"/>
<circle cx="64" cy="76" r="31" fill="#f5c16c"/>
<ellipse cx="57" cy="90" rx="10" ry="8" fill="#fff0d2"/><ellipse cx="71" cy="90" rx="10" ry="8" fill="#fff0d2"/>
{eyes(72, 13, 4.8, 6.2)}
<path d="M59 83 Q64 80 69 83 Q66 88 64 88 Q62 88 59 83 Z" fill="#7a3e1d"/>
{cat_mouth(90, "#7a3e1d")}
"""
    return svg(n, ("#5bb8ff", "#1b62b0"), body)


def panda(n):
    body = f"""
<circle cx="34" cy="42" r="14" fill="#2a2a2e"/><circle cx="94" cy="42" r="14" fill="#2a2a2e"/>
<ellipse cx="64" cy="76" rx="42" ry="39" fill="#fbfbfb"/>
<ellipse cx="48" cy="74" rx="11" ry="14" fill="#2a2a2e" transform="rotate(25 48 74)"/>
<ellipse cx="80" cy="74" rx="11" ry="14" fill="#2a2a2e" transform="rotate(-25 80 74)"/>
{eyes(74, 16, 4.6, 5.8)}
<ellipse cx="64" cy="90" rx="6" ry="4" fill="#2a2a2e"/>
{cat_mouth(95, "#2a2a2e")}
{blush(92, 26, 5, 0.4)}
<path d="M18 136 Q22 112 64 110 Q106 112 110 136 Z" fill="#2a2a2e"/>
"""
    return svg(n, ("#7fdc93", "#238a4c"), body)


def bull(n):
    # The market bull: green backdrop, a faint rising candle chart behind.
    body = f"""
<g fill="#ffffff" fill-opacity="0.13">
<rect x="14" y="80" width="7" height="22" rx="1.5"/><rect x="26" y="70" width="7" height="26" rx="1.5"/>
<rect x="95" y="46" width="7" height="24" rx="1.5"/><rect x="107" y="34" width="7" height="28" rx="1.5"/>
</g>
<path d="M36 50 Q14 46 12 22 Q24 38 42 40 Z" fill="#f4e1b8"/>
<path d="M92 50 Q114 46 116 22 Q104 38 86 40 Z" fill="#f4e1b8"/>
<ellipse cx="24" cy="64" rx="13" ry="7" fill="#7a4a30" transform="rotate(-20 24 64)"/>
<ellipse cx="104" cy="64" rx="13" ry="7" fill="#7a4a30" transform="rotate(20 104 64)"/>
<path d="M30 58 Q64 26 98 58 L94 94 Q64 110 34 94 Z" fill="#8d5a3b"/>
<path d="M54 40 Q60 30 64 40 Q68 30 74 40 Q64 48 54 40 Z" fill="#6b4029"/>
<ellipse cx="64" cy="96" rx="25" ry="17" fill="#e9b894"/>
<ellipse cx="55" cy="96" rx="3.6" ry="5" fill="#8d5a3b"/><ellipse cx="73" cy="96" rx="3.6" ry="5" fill="#8d5a3b"/>
<path d="M56 110 Q64 118 72 110" stroke="#f7c948" stroke-width="3.4" fill="none" stroke-linecap="round"/>
{eyes(70, 15, 5.2, 6.6)}
<path d="M44 58 L56 62 M84 58 L72 62" stroke="{INK}" stroke-width="3" stroke-linecap="round"/>
"""
    return svg(n, ("#2ed68f", "#0a7a52"), body)


def bear(n):
    # The market bear: red backdrop, a faint falling candle chart behind.
    body = f"""
<g fill="#ffffff" fill-opacity="0.13">
<rect x="14" y="34" width="7" height="26" rx="1.5"/><rect x="26" y="46" width="7" height="24" rx="1.5"/>
<rect x="95" y="72" width="7" height="24" rx="1.5"/><rect x="107" y="84" width="7" height="22" rx="1.5"/>
</g>
<circle cx="34" cy="44" r="14" fill="#6e4128"/><circle cx="94" cy="44" r="14" fill="#6e4128"/>
<circle cx="34" cy="44" r="7" fill="#c98f63"/><circle cx="94" cy="44" r="7" fill="#c98f63"/>
<ellipse cx="64" cy="78" rx="41" ry="38" fill="#7b4a2e"/>
<ellipse cx="64" cy="94" rx="19" ry="15" fill="#d9a877"/>
<ellipse cx="64" cy="87" rx="7" ry="5" fill="{INK}"/>
<path d="M58 101 Q64 97 70 101" stroke="{INK}" stroke-width="2.4" fill="none" stroke-linecap="round"/>
{eyes(74, 16, 5, 6.4)}
<path d="M40 62 L54 66 M88 62 L74 66" stroke="{INK}" stroke-width="3.2" stroke-linecap="round"/>
"""
    return svg(n, ("#ff6b6b", "#a8201a"), body)


def whale(n):
    body = f"""
<path d="M64 38 Q60 22 50 16 M64 38 Q64 20 64 12 M64 38 Q68 22 78 16" stroke="#bfe6ff" stroke-width="4" fill="none" stroke-linecap="round"/>
<circle cx="50" cy="15" r="4" fill="#bfe6ff"/><circle cx="78" cy="15" r="4" fill="#bfe6ff"/><circle cx="64" cy="11" r="4" fill="#bfe6ff"/>
<path d="M12 96 Q10 42 64 40 Q118 42 116 96 Q116 128 64 128 Q12 128 12 96 Z" fill="#4a8fe0"/>
<path d="M24 100 Q64 84 104 100 Q98 126 64 128 Q30 126 24 100 Z" fill="#dfeefe"/>
<path d="M44 106 L44 122 M54 102 L54 124 M64 101 L64 125 M74 102 L74 124 M84 106 L84 122" stroke="#b6d5f5" stroke-width="2" stroke-linecap="round"/>
{eyes(76, 22, 5.6, 7)}
{smile(90, 8, INK, 2.8)}
{blush(88, 34, 5, 0.35)}
"""
    return svg(n, ("#5b72ff", "#16207a"), body)


def turtle(n):
    body = f"""
<rect x="50" y="78" width="28" height="18" rx="8" fill="#6aae5a"/>
<ellipse cx="64" cy="62" rx="32" ry="28" fill="#7cc26b"/>
<ellipse cx="54" cy="44" rx="12" ry="7" fill="#a6dc8f" fill-opacity="0.7"/>
<circle cx="84" cy="50" r="3.2" fill="#5f9e4f"/><circle cx="90" cy="58" r="2.2" fill="#5f9e4f"/><circle cx="40" cy="52" r="2.6" fill="#5f9e4f"/>
<path d="M4 136 Q6 88 64 86 Q122 88 124 136 Z" fill="#2f7d3a"/>
<path d="M40 102 L52 94 L64 100 L76 94 L88 102 L82 116 L64 122 L46 116 Z" fill="#3f9b4b"/>
<path d="M16 120 L28 104 L40 102 M112 120 L100 104 L88 102 M64 122 L64 136" stroke="#256a30" stroke-width="3" fill="none"/>
<path d="M4 136 Q6 88 64 86 Q122 88 124 136" stroke="#dcb35c" stroke-width="4" fill="none"/>
{eyes(60, 13, 5.2, 6.6)}
{smile(72, 6)}
{blush(69, 20, 4.5, 0.4)}
"""
    return svg(n, ("#ffd86b", "#e0902a"), body)


def elephant(n):
    body = f"""
<ellipse cx="24" cy="72" rx="22" ry="28" fill="#9aa5b8"/><ellipse cx="104" cy="72" rx="22" ry="28" fill="#9aa5b8"/>
<ellipse cx="26" cy="72" rx="14" ry="19" fill="#f2b8c8"/><ellipse cx="102" cy="72" rx="14" ry="19" fill="#f2b8c8"/>
<ellipse cx="64" cy="70" rx="32" ry="34" fill="#aeb8c9"/>
<path d="M56 86 Q54 110 62 118 Q70 124 76 116" stroke="#aeb8c9" stroke-width="14" fill="none" stroke-linecap="round"/>
<path d="M54 98 L60 98 M55 106 L61 105" stroke="#8f9aad" stroke-width="2" stroke-linecap="round"/>
{eyes(68, 13, 4.8, 6.2)}
{blush(80, 22, 5, 0.4)}
"""
    return svg(n, ("#a99cff", "#5a45d6"), body)


def rabbit(n):
    body = f"""
<ellipse cx="46" cy="30" rx="11" ry="30" fill="#fff5ee" transform="rotate(-10 46 30)"/>
<ellipse cx="82" cy="30" rx="11" ry="30" fill="#fff5ee" transform="rotate(10 82 30)"/>
<ellipse cx="46" cy="32" rx="5.5" ry="22" fill="#ffb3c7" transform="rotate(-10 46 32)"/>
<ellipse cx="82" cy="32" rx="5.5" ry="22" fill="#ffb3c7" transform="rotate(10 82 32)"/>
<ellipse cx="64" cy="82" rx="38" ry="34" fill="#fff5ee"/>
{eyes(78, 15, 5.2, 6.6)}
<path d="M60 90 Q64 87 68 90 Q66 94 64 94 Q62 94 60 90 Z" fill="#ff7aa0"/>
<path d="M64 94 L64 98 M58 98 Q64 103 70 98" stroke="{INK}" stroke-width="2" fill="none" stroke-linecap="round"/>
<rect x="60.5" y="99" width="7" height="6" rx="1.5" fill="#ffffff" stroke="#e6d6cc" stroke-width="1"/>
{blush(92, 24, 5, 0.45)}
"""
    return svg(n, ("#5ef0c9", "#0a9f7c"), body)


def lucky_cat(n):
    # Maneki-neko: the beckoning cat of shops and good fortune.
    body = f"""
<path d="M30 58 L32 24 L56 44 Z" fill="#fffaf2"/><path d="M98 58 L96 24 L72 44 Z" fill="#fffaf2"/>
<path d="M35 50 L36 32 L50 44 Z" fill="#ffb3c0"/><path d="M93 50 L92 32 L78 44 Z" fill="#f28f3b"/>
<ellipse cx="64" cy="72" rx="40" ry="34" fill="#fffaf2"/>
<ellipse cx="90" cy="54" rx="10" ry="8" fill="#f28f3b" fill-opacity="0.9"/>
<path d="M44 70 Q50 64 56 70 M72 70 Q78 64 84 70" stroke="{INK}" stroke-width="3" fill="none" stroke-linecap="round"/>
<path d="M61 80 L67 80 L64 84 Z" fill="#ff7aa0"/>
{cat_mouth(86)}
<path d="M24 76 L40 78 M24 84 L40 82 M104 76 L88 78 M104 84 L88 82" stroke="#c9bcae" stroke-width="1.6" stroke-linecap="round"/>
{blush(80, 25, 5, 0.45)}
<path d="M26 104 Q64 96 102 104 L106 112 Q64 104 22 112 Z" fill="#e0342f"/>
<circle cx="64" cy="112" r="9" fill="#f9c823"/><path d="M58 112 L70 112" stroke="#c99a10" stroke-width="2"/>
<circle cx="64" cy="115" r="1.6" fill="#8a6a08"/>
<ellipse cx="22" cy="92" rx="11" ry="14" fill="#fffaf2"/>
<ellipse cx="22" cy="96" rx="4" ry="3.4" fill="#ffb3c0"/><circle cx="17" cy="88" r="2" fill="#ffb3c0"/><circle cx="22" cy="86" r="2" fill="#ffb3c0"/><circle cx="27" cy="88" r="2" fill="#ffb3c0"/>
<path d="M4 136 Q8 114 64 116 Q120 114 124 136 Z" fill="#fffaf2"/>
"""
    return svg(n, ("#ff5a5a", "#8e1616"), body)


def eagle(n):
    body = f"""
<path d="M8 136 Q16 102 64 98 Q112 102 120 136 Z" fill="#6d4c41"/>
<path d="M28 70 Q26 36 64 32 Q102 36 100 70 Q98 104 64 108 Q30 104 28 70 Z" fill="#fafafa"/>
<path d="M28 70 Q34 58 44 60 L40 50 Q32 56 28 70 Z M100 70 Q94 58 84 60 L88 50 Q96 56 100 70 Z" fill="#e2e2e2"/>
{eyes(68, 16, 5, 6.4)}
<path d="M44 58 L58 63 M84 58 L70 63" stroke="{INK}" stroke-width="3.2" stroke-linecap="round"/>
<path d="M50 80 Q64 72 78 80 Q76 94 64 104 Q60 96 56 94 Q50 88 50 80 Z" fill="#ffc21a"/>
<path d="M56 86 Q64 82 72 86" stroke="#e0a100" stroke-width="2" fill="none" stroke-linecap="round"/>
"""
    return svg(n, ("#7cc4ff", "#1667c8"), body)


def shark(n):
    body = f"""
<path d="M64 12 L78 42 L50 42 Z" fill="#5b7c99"/>
<path d="M14 90 Q12 40 64 38 Q116 40 114 90 Q112 128 64 130 Q16 128 14 90 Z" fill="#5b7c99"/>
<path d="M18 92 Q64 70 110 92 Q106 126 64 128 Q22 126 18 92 Z" fill="#eef4f8"/>
<path d="M30 96 Q64 120 98 96 Q90 104 64 106 Q38 104 30 96 Z" fill="#3b2230"/>
<path d="M36 98 L41 104 L46 100 L51 106 L56 101 L61 107 L66 101 L71 107 L76 101 L81 106 L86 100 L91 104 L94 99" fill="#ffffff"/>
<path d="M24 74 L28 72 M24 80 L29 78 M104 74 L100 72 M104 80 L99 78" stroke="#46647e" stroke-width="2.2" stroke-linecap="round"/>
{eyes(70, 20, 5, 6.2)}
"""
    return svg(n, ("#27d7d2", "#0a5f7d"), body)


def dragon(n):
    body = f"""
<path d="M42 44 L32 12 L54 36 Z" fill="#f4e1b8"/><path d="M86 44 L96 12 L74 36 Z" fill="#f4e1b8"/>
<path d="M22 70 L6 58 L14 80 Z M106 70 L122 58 L114 80 Z" fill="#0e8f6e"/>
<ellipse cx="64" cy="70" rx="40" ry="34" fill="#10ac84"/>
<ellipse cx="64" cy="98" rx="28" ry="18" fill="#1dd1a1"/>
<ellipse cx="56" cy="92" rx="2.6" ry="3.6" fill="#0a6b52"/><ellipse cx="72" cy="92" rx="2.6" ry="3.6" fill="#0a6b52"/>
<path d="M52 104 Q64 112 76 104" stroke="{INK}" stroke-width="2.4" fill="none" stroke-linecap="round"/>
<path d="M55 105 L57 110 L59 106 Z M69 106 L71 110 L73 105 Z" fill="#fff"/>
<path d="M56 40 Q64 34 72 40 Q64 46 56 40 Z" fill="#0a8e6b"/>
{eyes(68, 16, 5.4, 6.8)}
{blush(84, 26, 5, 0.35)}
"""
    return svg(n, ("#ffd43b", "#e8590c"), body)


# --- original anime-style characters ------------------------------------------

FACE = "#ffe0c9"
FACE_SHADE = "#f7c7a9"


def face(y: float = 76) -> str:
    return (f'<ellipse cx="34" cy="{y + 2}" rx="5" ry="7" fill="{FACE_SHADE}"/>'
            f'<ellipse cx="94" cy="{y + 2}" rx="5" ry="7" fill="{FACE_SHADE}"/>'
            f'<path d="M34 {y - 8} Q34 {y + 30} 64 {y + 36} Q94 {y + 30} 94 {y - 8} Q94 {y - 36} 64 {y - 36} Q34 {y - 36} 34 {y - 8} Z" fill="{FACE}"/>')


def kira(n):
    e, d = anime_eyes(n, "#b56cff", "#5b2a9e")
    body = f"""
<ellipse cx="18" cy="96" rx="14" ry="30" fill="#ff5fa2"/><ellipse cx="110" cy="96" rx="14" ry="30" fill="#ff5fa2"/>
<circle cx="22" cy="62" r="7" fill="#ffd43b"/><circle cx="106" cy="62" r="7" fill="#ffd43b"/>
<path d="M24 80 Q20 26 64 24 Q108 26 104 80 L98 60 Q64 44 30 60 Z" fill="#ff4f96"/>
{shoulders("#2d2b55", "#ffd43b")}
{face()}
<path d="M32 62 Q40 34 64 32 Q90 34 96 62 Q86 50 76 54 L72 44 Q66 56 54 52 Q46 58 32 62 Z" fill="#ff5fa2"/>
<path d="M26 72 Q24 30 64 26 Q104 30 102 72" stroke="#2b2d42" stroke-width="5" fill="none"/>
<rect x="18" y="66" width="12" height="20" rx="5" fill="#2b2d42"/><rect x="98" y="66" width="12" height="20" rx="5" fill="#2b2d42"/>
<path d="M24 86 Q30 104 50 104" stroke="#2b2d42" stroke-width="3" fill="none" stroke-linecap="round"/>
<circle cx="52" cy="104" r="3.4" fill="#2ed68f"/>
{e}
{blush(92, 20, 5, 0.45)}
{smile(98, 4)}
"""
    return svg(n, ("#ff8ec4", "#6c3fd6"), body, d)


def ren(n):
    # A samurai: topknot, headband, calm determined eyes.
    e, d = anime_eyes(n, "#4c6ef5", "#1b2a6b", y=82, rx=6.2, ry=7.4)
    body = f"""
<circle cx="96" cy="34" r="18" fill="#ff6b6b" fill-opacity="0.85"/>
<ellipse cx="64" cy="22" rx="9" ry="8" fill="#1f1f2e"/><rect x="60" y="26" width="8" height="10" fill="#1f1f2e"/>
<path d="M28 84 Q24 34 64 32 Q104 34 100 84 Z" fill="#1f1f2e"/>
<path d="M16 136 Q20 112 64 110 Q108 112 112 136 Z" fill="#2c3e8f"/>
<path d="M44 110 L64 136 L84 110" fill="#f1f3f5"/><path d="M50 110 L64 128 L78 110" fill="#2c3e8f"/>
{face()}
<path d="M34 60 Q40 38 64 38 Q88 38 94 60 Q80 48 64 52 Q48 48 34 60 Z" fill="#1f1f2e"/>
<path d="M32 58 Q64 46 96 58 L96 64 Q64 52 32 64 Z" fill="#f1f3f5"/>
<circle cx="64" cy="55" r="3.2" fill="#e03131"/>
<path d="M96 60 L108 70 L104 58 Z" fill="#f1f3f5"/>
<path d="M46 70 L58 72 M82 70 L70 72" stroke="{INK}" stroke-width="3.2" stroke-linecap="round"/>
{e}
<path d="M59 100 L69 100" stroke="{INK}" stroke-width="2.4" stroke-linecap="round"/>
{blush(94, 20, 4.5, 0.3)}
"""
    return svg(n, ("#3d4fb8", "#121a45"), body, d)


def kage(n):
    # A ninja: hood and mask, only the eyes showing.
    e, d = anime_eyes(n, "#2ed68f", "#0b6b44", y=74, rx=6.4, ry=7.2)
    body = f"""
<path d="M8 136 Q12 108 64 104 Q116 108 120 136 Z" fill="#23283a"/>
<path d="M22 84 Q18 22 64 20 Q110 22 106 84 Q104 118 64 120 Q24 118 22 84 Z" fill="#2b3147"/>
<path d="M36 62 Q64 54 92 62 L92 86 Q64 80 36 86 Z" fill="{FACE}"/>
<path d="M26 56 Q64 44 102 56 L102 64 Q64 52 26 64 Z" fill="#c92a2a"/>
<path d="M100 58 Q114 60 120 74 Q110 66 102 64 Z M102 62 Q112 70 112 84 Q106 74 100 66 Z" fill="#c92a2a"/>
<path d="M44 66 L58 69 M84 66 L70 69" stroke="{INK}" stroke-width="3" stroke-linecap="round"/>
{e}
<path d="M36 86 Q64 80 92 86 L94 108 Q64 116 34 108 Z" fill="#23283a"/>
"""
    return svg(n, ("#1f5d6e", "#0b1f2a"), body, d)


def yuki(n):
    # An analyst: short bob, round glasses.
    e, d = anime_eyes(n, "#3aa0ff", "#0b3f8a", y=80, rx=6, ry=7.6)
    body = f"""
<path d="M24 96 Q18 30 64 28 Q110 30 104 96 L92 98 L92 70 L36 70 L36 98 Z" fill="#2d3561"/>
{shoulders("#f1c1d2", "#d98fa9")}
{face()}
<path d="M30 70 Q30 36 64 34 Q98 36 98 70 Q92 54 80 50 Q66 58 50 52 Q38 56 30 70 Z" fill="#2d3561"/>
{e}
<circle cx="50" cy="80" r="11.5" fill="#ffffff" fill-opacity="0.12" stroke="#3a3a4a" stroke-width="2.6"/>
<circle cx="78" cy="80" r="11.5" fill="#ffffff" fill-opacity="0.12" stroke="#3a3a4a" stroke-width="2.6"/>
<path d="M61.5 79 Q64 76 66.5 79" stroke="#3a3a4a" stroke-width="2.4" fill="none"/>
<path d="M43 74 L48 70 M71 74 L76 70" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-opacity="0.8"/>
{blush(94, 20, 4.5, 0.4)}
{smile(99, 4)}
"""
    return svg(n, ("#80c8ff", "#1c64c7"), body, d)


def nova(n):
    # An astronaut kid, face behind a visor.
    stars = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#fff" fill-opacity="0.8"/>'
                    for x, y, r in [(16, 22, 1.4), (30, 48, 1), (108, 20, 1.6), (116, 50, 1.1), (98, 40, 0.9), (20, 76, 1)])
    e, d = anime_eyes(n, "#ff9f43", "#9c4a07", y=80, dx=13, rx=5.8, ry=7.2)
    body = f"""
{stars}
<path d="M10 136 Q12 108 64 106 Q116 108 118 136 Z" fill="#eef1f5"/>
<rect x="50" y="112" width="28" height="10" rx="3" fill="#ff6b3d"/>
<circle cx="64" cy="70" r="46" fill="#eef1f5"/>
<circle cx="64" cy="70" r="46" fill="none" stroke="#c7ced9" stroke-width="3"/>
<ellipse cx="64" cy="76" rx="34" ry="30" fill="#1e2a5a"/>
<path d="M40 70 Q40 50 64 48 Q88 50 88 70 Q88 100 64 104 Q40 100 40 70 Z" fill="{FACE}"/>
<path d="M40 70 Q42 50 64 48 Q86 50 88 70 Q80 60 70 62 Q60 56 48 62 Z" fill="#8b5a3c"/>
{e}
{smile(94, 4)}
{blush(90, 17, 4, 0.4)}
<path d="M36 58 Q44 46 58 44" stroke="#ffffff" stroke-width="4" fill="none" stroke-linecap="round" stroke-opacity="0.55"/>
<circle cx="104" cy="44" r="5" fill="#ff6b3d"/>
"""
    return svg(n, ("#3b3a8f", "#0d0b2e"), body, d)


def rin(n):
    # A fox spirit girl: fox ears in her hair, amber eyes.
    e, d = anime_eyes(n, "#ffb020", "#8a4b00")
    body = f"""
<path d="M30 46 L22 10 L52 34 Z" fill="#ff8a3d"/><path d="M98 46 L106 10 L76 34 Z" fill="#ff8a3d"/>
<path d="M33 40 L28 18 L47 34 Z" fill="#fff4ea"/><path d="M95 40 L100 18 L81 34 Z" fill="#fff4ea"/>
<path d="M22 110 Q14 40 64 30 Q114 40 106 110 L94 112 L94 70 L34 70 L34 112 Z" fill="#f1f3f5"/>
{shoulders("#e03131", "#ffd43b")}
{face()}
<path d="M32 66 Q34 36 64 34 Q94 36 96 66 Q88 54 80 58 L76 46 Q70 58 60 54 Q52 62 44 56 Q40 64 32 66 Z" fill="#f1f3f5"/>
{e}
{blush(92, 20, 5, 0.45)}
<path d="M58 97 Q64 102 70 97" stroke="{INK}" stroke-width="2.4" fill="none" stroke-linecap="round"/>
<path d="M66 98 L67.5 102 L69 98.5 Z" fill="#fff"/>
"""
    return svg(n, ("#ffc36b", "#d9480f"), body, d)


def zed(n):
    # A robot with a screen face.
    body = f"""
<path d="M64 22 L64 10" stroke="#9aa5b1" stroke-width="3" stroke-linecap="round"/>
<circle cx="64" cy="9" r="5" fill="#ff4d4f"/>
<rect x="16" y="54" width="12" height="30" rx="5" fill="#7a8591"/><rect x="100" y="54" width="12" height="30" rx="5" fill="#7a8591"/>
<rect x="24" y="22" width="80" height="84" rx="26" fill="#c9d1d9"/>
<rect x="24" y="22" width="80" height="30" rx="26" fill="#dde3e9"/>
<rect x="34" y="44" width="60" height="44" rx="14" fill="#10223d"/>
<rect x="44" y="58" width="12" height="16" rx="6" fill="#40e0ff"/><rect x="72" y="58" width="12" height="16" rx="6" fill="#40e0ff"/>
<rect x="46" y="60" width="4" height="5" rx="2" fill="#ffffff"/><rect x="74" y="60" width="4" height="5" rx="2" fill="#ffffff"/>
<path d="M54 80 Q64 86 74 80" stroke="#40e0ff" stroke-width="2.6" fill="none" stroke-linecap="round"/>
<path d="M14 136 Q18 110 64 108 Q110 110 114 136 Z" fill="#8a96a3"/>
<circle cx="64" cy="122" r="6" fill="#40e0ff" fill-opacity="0.9"/>
"""
    return svg(n, ("#6f7e8c", "#1f2a33"), body)


def taro(n):
    # A hoodie kid: teal spiky hair, earbuds, a confident grin.
    e, d = anime_eyes(n, "#20c997", "#0b5d45", y=82)
    body = f"""
<path d="M6 136 Q8 96 64 94 Q120 96 122 136 Z" fill="#343a40"/>
<path d="M18 110 Q8 30 64 22 Q120 30 110 110 Q100 70 64 66 Q28 70 18 110 Z" fill="#495057"/>
{face(80)}
<path d="M32 70 L30 44 L42 56 L44 34 L54 50 L62 28 L68 48 L78 32 L80 52 L94 40 L96 70 Q86 60 76 62 Q64 56 52 62 Q42 60 32 70 Z" fill="#12b886"/>
{e}
<path d="M46 72 L58 70 M82 72 L70 70" stroke="{INK}" stroke-width="3" stroke-linecap="round"/>
<path d="M56 100 Q64 106 72 98" stroke="{INK}" stroke-width="2.6" fill="none" stroke-linecap="round"/>
{blush(96, 20, 4.5, 0.35)}
<circle cx="31" cy="92" r="4" fill="#f8f9fa"/><path d="M31 96 Q30 110 40 118" stroke="#f8f9fa" stroke-width="2" fill="none"/>
<path d="M50 120 L50 136 M78 120 L78 136" stroke="#adb5bd" stroke-width="2.4"/>
"""
    return svg(n, ("#c3ec52", "#4f9a1f"), body, d)


# --- the set, by permanent id ----------------------------------------------------

SET = {
    1: owl, 2: tiger, 3: fox, 4: wolf, 5: lion, 6: panda, 7: bull, 8: eagle,
    9: shark, 10: dragon, 11: whale, 12: turtle, 13: elephant, 14: rabbit,
    15: lucky_cat, 16: kira, 17: ren, 18: kage, 19: yuki, 20: nova,
    21: rin, 22: zed, 23: taro, 24: bear,
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for n, draw in SET.items():
        (OUT / f"{n:02d}.svg").write_text(draw(n))
    print(f"wrote {len(SET)} avatars to {OUT}")

    if "--preview" in sys.argv:
        path = Path(sys.argv[sys.argv.index("--preview") + 1])
        tiles = "".join(
            f'<figure><img src="{OUT}/{n:02d}.svg"><figcaption>{n} · {f.__name__}</figcaption></figure>'
            for n, f in SET.items()
        )
        path.write_text(
            "<html><body style='margin:0;background:#0b141a;font:13px -apple-system;color:#8696a0'>"
            "<div style='display:grid;grid-template-columns:repeat(6,150px);gap:18px;padding:24px'>"
            f"{tiles}</div><style>img{{width:128px;height:128px}}figure{{margin:0;text-align:center}}"
            "figcaption{margin-top:6px}</style></body></html>"
        )
        print(f"preview: {path}")


if __name__ == "__main__":
    main()
