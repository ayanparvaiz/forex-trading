#!/usr/bin/env python3
"""Draws the community pictures: app/assets/community_avatars/01.svg … 28.svg.

    python3 tool/make_community_avatars.py

A community's picture is a badge, not a face: a rounded square rather than
the circle every person has, so a community never looks like someone in a
list of people. Every badge is the same few parts — a diagonal gradient in
its own colours, a soft light from the top left, one emblem in light and an
accent colour, and a shadow under the emblem — so the set reads as one set.

Four shelves of seven, by topic: the market, discipline, nature (with the
shapla, Bangladesh's water lily) and emblems. Drawn here from shapes, so
there is nothing to license.

Only features flutter_svg renders are used — shapes, paths, linear and
radial gradients, transforms, group opacity and a clipPath. No filters,
masks, text or CSS.

The ids are permanent and match app/lib/data/community_avatars.dart: a
community stores its number, so a number never changes what it shows.
"""

from __future__ import annotations

import math
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "app/assets/community_avatars"

SHADOW = "#000000"


def badge(n: int, bg: tuple[str, str], emblem, colors: dict[str, str], extra_defs: str = "") -> str:
    """The shared frame, with [emblem] drawn twice: once as its shadow."""
    shadow_colors = {k: SHADOW for k in colors}
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
<defs>
<linearGradient id="g{n}" x1="0" y1="0" x2="128" y2="128" gradientUnits="userSpaceOnUse">
<stop offset="0" stop-color="{bg[0]}"/><stop offset="1" stop-color="{bg[1]}"/>
</linearGradient>
<radialGradient id="l{n}" cx="0.2" cy="0.1" r="0.9">
<stop offset="0" stop-color="#ffffff" stop-opacity="0.28"/><stop offset="0.6" stop-color="#ffffff" stop-opacity="0"/>
</radialGradient>
<clipPath id="k{n}"><rect width="128" height="128" rx="34" ry="34"/></clipPath>
{extra_defs}
</defs>
<g clip-path="url(#k{n})">
<rect width="128" height="128" fill="url(#g{n})"/>
<rect width="128" height="128" fill="url(#l{n})"/>
<g opacity="0.22" transform="translate(0 4)">
{emblem(n, **shadow_colors)}
</g>
{emblem(n, **colors)}
</g>
</svg>
"""


def star_points(cx: float, cy: float, points: int, outer: float, inner: float, rot: float = -90) -> str:
    out = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = math.radians(rot + i * 180 / points)
        out.append(f"{cx + r * math.cos(a):.1f} {cy + r * math.sin(a):.1f}")
    return "M" + " L".join(out) + " Z"


def crescent(x1: float, y1: float, r1: float, x2: float, y2: float, r2: float) -> str:
    """Circle one, less circle two: the outline of what is left, as a path."""
    dx, dy = x2 - x1, y2 - y1
    d = math.hypot(dx, dy)
    a = (r1 * r1 - r2 * r2 + d * d) / (2 * d)
    h = math.sqrt(r1 * r1 - a * a)
    mx, my = x1 + a * dx / d, y1 + a * dy / d
    ax, ay = mx - h * dy / d, my + h * dx / d
    bx, by = mx + h * dy / d, my - h * dx / d
    return (f"M{bx:.1f} {by:.1f} A{r1} {r1} 0 1 0 {ax:.1f} {ay:.1f} "
            f"A{r2} {r2} 0 0 1 {bx:.1f} {by:.1f} Z")


def sparkle(x: float, y: float, r: float, color: str) -> str:
    return f'<path d="{star_points(x, y, 4, r, r * 0.3, -90)}" fill="{color}"/>'


# --- the market ----------------------------------------------------------------

def bull(n, fg, accent, ink):
    return f"""
<path d="M40 44 Q20 36 20 14 Q30 32 50 36 Z" fill="{accent}"/>
<path d="M88 44 Q108 36 108 14 Q98 32 78 36 Z" fill="{accent}"/>
<path d="M42 50 Q28 46 22 56 Q32 62 44 58 Z" fill="{fg}"/>
<path d="M86 50 Q100 46 106 56 Q96 62 84 58 Z" fill="{fg}"/>
<path d="M40 38 Q64 28 88 38 Q96 58 86 80 Q78 104 64 106 Q50 104 42 80 Q32 58 40 38 Z" fill="{fg}"/>
<ellipse cx="64" cy="88" rx="18" ry="13" fill="{accent}"/>
<ellipse cx="57" cy="88" rx="3.2" ry="4.2" fill="{ink}"/><ellipse cx="71" cy="88" rx="3.2" ry="4.2" fill="{ink}"/>
<circle cx="52" cy="62" r="4.6" fill="{ink}"/><circle cx="76" cy="62" r="4.6" fill="{ink}"/>
<path d="M56 46 Q64 42 72 46" stroke="{accent}" stroke-width="3" fill="none" stroke-linecap="round"/>
"""


def bear(n, fg, accent, ink):
    return f"""
<circle cx="38" cy="38" r="14" fill="{fg}"/><circle cx="90" cy="38" r="14" fill="{fg}"/>
<circle cx="38" cy="38" r="7" fill="{accent}"/><circle cx="90" cy="38" r="7" fill="{accent}"/>
<circle cx="64" cy="68" r="36" fill="{fg}"/>
<ellipse cx="64" cy="82" rx="18" ry="14" fill="{accent}"/>
<ellipse cx="64" cy="75" rx="7" ry="5" fill="{ink}"/>
<path d="M64 80 L64 86 M58 90 Q64 94 70 90" stroke="{ink}" stroke-width="2.6" fill="none" stroke-linecap="round"/>
<circle cx="50" cy="60" r="4.4" fill="{ink}"/><circle cx="78" cy="60" r="4.4" fill="{ink}"/>
"""


def candles(n, fg, accent, ink):
    return f"""
<path d="M18 104 L110 104" stroke="{fg}" stroke-width="3" stroke-linecap="round" opacity="0.5"/>
<path d="M36 34 L36 96 M64 20 L64 88 M92 30 L92 98" stroke="{fg}" stroke-width="4" stroke-linecap="round"/>
<rect x="26" y="52" width="20" height="32" rx="4" fill="{ink}"/>
<rect x="54" y="32" width="20" height="44" rx="4" fill="{accent}"/>
<rect x="82" y="42" width="20" height="40" rx="4" fill="{accent}"/>
"""


def chart(n, fg, accent, ink):
    return f"""
<path d="M20 96 L46 70 L64 82 L98 44 L98 108 L20 108 Z" fill="{fg}" opacity="0.18"/>
<path d="M20 96 L46 70 L64 82 L96 46" stroke="{fg}" stroke-width="9" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M80 38 L106 30 L100 56 Z" fill="{fg}" stroke="{fg}" stroke-width="3" stroke-linejoin="round"/>
<circle cx="46" cy="70" r="6" fill="{accent}"/><circle cx="64" cy="82" r="6" fill="{accent}"/>
"""


def coins(n, fg, accent, ink):
    stack = []
    for i in range(4):
        y = 96 - i * 11
        stack.append(
            f'<path d="M22 {y} L22 {y + 7} Q44 {y + 17} 66 {y + 7} L66 {y} Z" fill="{ink}"/>'
            f'<ellipse cx="44" cy="{y}" rx="22" ry="8" fill="{accent}"/>'
        )
    return "".join(stack) + f"""
<circle cx="82" cy="56" r="28" fill="{ink}"/>
<circle cx="82" cy="53" r="28" fill="{accent}"/>
<circle cx="82" cy="53" r="20" fill="none" stroke="{fg}" stroke-width="3" opacity="0.8"/>
<path d="M82 66 L82 42 M72 51 L82 40 L92 51" stroke="{fg}" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
"""


def globe(n, fg, accent, ink):
    return f"""
<circle cx="64" cy="64" r="32" fill="{fg}" opacity="0.14"/>
<circle cx="64" cy="64" r="32" fill="none" stroke="{fg}" stroke-width="5"/>
<ellipse cx="64" cy="64" rx="13" ry="32" fill="none" stroke="{fg}" stroke-width="4"/>
<path d="M32 64 L96 64 M37 48 Q64 54 91 48 M37 80 Q64 74 91 80" stroke="{fg}" stroke-width="4" fill="none"/>
<path d="M18 58 Q22 22 60 16" stroke="{accent}" stroke-width="6" fill="none" stroke-linecap="round"/>
<path d="M54 8 L66 16 L55 26 Z" fill="{accent}"/>
<path d="M110 70 Q106 106 68 112" stroke="{accent}" stroke-width="6" fill="none" stroke-linecap="round"/>
<path d="M74 120 L62 112 L73 102 Z" fill="{accent}"/>
"""


def bell(n, fg, accent, ink):
    return f"""
<circle cx="64" cy="24" r="6" fill="{fg}"/>
<path d="M64 28 Q40 30 40 60 L40 80 L30 92 L98 92 L88 80 L88 60 Q88 30 64 28 Z" fill="{fg}"/>
<path d="M36 88 L92 88" stroke="{accent}" stroke-width="5" stroke-linecap="round"/>
<circle cx="64" cy="100" r="8" fill="{accent}"/>
<path d="M50 44 Q48 56 48 70" stroke="{accent}" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.7"/>
<path d="M22 44 Q16 56 22 68 M106 44 Q112 56 106 68" stroke="{fg}" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.6"/>
"""


# --- discipline ----------------------------------------------------------------

def target(n, fg, accent, ink):
    return f"""
<circle cx="58" cy="70" r="38" fill="{fg}"/>
<circle cx="58" cy="70" r="29" fill="{accent}"/>
<circle cx="58" cy="70" r="20" fill="{fg}"/>
<circle cx="58" cy="70" r="11" fill="{accent}"/>
<path d="M58 70 L100 28" stroke="{ink}" stroke-width="5" stroke-linecap="round"/>
<path d="M96 20 L104 28 L112 18 L106 14 Z M100 32 L108 24 L114 32 L106 36 Z" fill="{fg}"/>
<path d="M92 26 L110 20 L104 38 Z" fill="{fg}"/>
"""


def shield(n, fg, accent, ink):
    return f"""
<path d="M64 16 L102 30 Q102 80 64 110 Q26 80 26 30 Z" fill="{fg}"/>
<path d="M64 26 L92 36 Q92 76 64 100 Q36 76 36 36 Z" fill="{accent}"/>
<path d="M46 62 L59 75 L84 48" stroke="{fg}" stroke-width="10" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
"""


def knight(n, fg, accent, ink):
    return f"""
<rect x="34" y="96" width="60" height="12" rx="4" fill="{fg}"/>
<path d="M42 96 L86 96 L82 88 L46 88 Z" fill="{fg}"/>
<path d="M50 88 Q44 76 52 66 Q58 60 60 54 L46 60 Q36 62 34 54 Q34 46 44 36 Q52 28 58 24 L58 14 L66 22 Q88 24 92 50 Q96 70 84 88 Z" fill="{fg}"/>
<path d="M64 24 Q84 30 86 52 Q88 68 80 82" stroke="{accent}" stroke-width="6" fill="none" stroke-linecap="round"/>
<circle cx="58" cy="38" r="3.6" fill="{ink}"/>
<circle cx="41" cy="52" r="2" fill="{ink}"/>
"""


def compass(n, fg, accent, ink):
    return f"""
<circle cx="64" cy="64" r="44" fill="none" stroke="{fg}" stroke-width="4" opacity="0.55"/>
<path d="{star_points(64, 64, 4, 40, 9, -45)}" fill="{fg}" opacity="0.55"/>
<path d="{star_points(64, 64, 4, 50, 11, -90)}" fill="{fg}"/>
<path d="M64 14 L75 53 L64 64 L53 53 Z" fill="{accent}"/>
<circle cx="64" cy="64" r="7" fill="{ink}"/>
<circle cx="64" cy="64" r="3" fill="{fg}"/>
"""


def hourglass(n, fg, accent, ink):
    return f"""
<path d="M44 28 L84 28 Q84 50 67 64 Q84 78 84 100 L44 100 Q44 78 61 64 Q44 50 44 28 Z" fill="{fg}" opacity="0.35"/>
<path d="M44 28 L84 28 Q84 50 67 64 Q84 78 84 100 L44 100 Q44 78 61 64 Q44 50 44 28 Z" fill="none" stroke="{fg}" stroke-width="4" stroke-linejoin="round"/>
<path d="M51 40 L77 40 Q75 50 64 58 Q53 50 51 40 Z" fill="{accent}"/>
<path d="M64 60 L64 88" stroke="{accent}" stroke-width="3" stroke-linecap="round"/>
<path d="M48 98 Q64 76 80 98 Z" fill="{accent}"/>
<rect x="34" y="18" width="60" height="11" rx="5" fill="{fg}"/>
<rect x="34" y="99" width="60" height="11" rx="5" fill="{fg}"/>
"""


def scale(n, fg, accent, ink):
    return f"""
<path d="M64 30 L64 96" stroke="{fg}" stroke-width="7" stroke-linecap="round"/>
<path d="M42 104 L86 104 L78 92 L50 92 Z" fill="{fg}"/>
<path d="M24 40 L104 40" stroke="{fg}" stroke-width="7" stroke-linecap="round"/>
<circle cx="64" cy="28" r="8" fill="{accent}"/>
<path d="M28 42 L16 74 M28 42 L40 74 M100 42 L88 74 M100 42 L112 74" stroke="{fg}" stroke-width="3" opacity="0.8"/>
<path d="M12 74 L44 74 Q40 88 28 88 Q16 88 12 74 Z" fill="{accent}"/>
<path d="M84 74 L116 74 Q112 88 100 88 Q88 88 84 74 Z" fill="{accent}"/>
"""


def key(n, fg, accent, ink):
    return f"""
<circle cx="42" cy="54" r="22" fill="none" stroke="{fg}" stroke-width="12"/>
<circle cx="42" cy="54" r="7" fill="{accent}"/>
<path d="M60 64 L106 92" stroke="{fg}" stroke-width="12" stroke-linecap="round"/>
<path d="M92 84 L84 98 M102 90 L96 102" stroke="{fg}" stroke-width="9" stroke-linecap="round"/>
"""


# --- nature ----------------------------------------------------------------------

def sunrise(n, fg, accent, ink):
    rays = "".join(
        f'<path d="M{64 + 36 * math.cos(math.radians(a)):.1f} {80 + 36 * math.sin(math.radians(a)):.1f} '
        f'L{64 + 48 * math.cos(math.radians(a)):.1f} {80 + 48 * math.sin(math.radians(a)):.1f}" '
        f'stroke="{accent}" stroke-width="6" stroke-linecap="round"/>'
        for a in (-160, -125, -90, -55, -20)
    )
    return rays + f"""
<path d="M36 82 A28 28 0 0 1 92 82 Z" fill="{accent}"/>
<path d="M14 86 L114 86" stroke="{fg}" stroke-width="6" stroke-linecap="round"/>
<path d="M28 98 L100 98" stroke="{fg}" stroke-width="5" stroke-linecap="round" opacity="0.7"/>
<path d="M44 109 L84 109" stroke="{fg}" stroke-width="4" stroke-linecap="round" opacity="0.45"/>
"""


def moon(n, fg, accent, ink):
    return f"""
<path d="{crescent(58, 66, 36, 78, 52, 31)}" fill="{fg}"/>
<circle cx="40" cy="80" r="5" fill="{ink}" opacity="0.15"/><circle cx="52" cy="92" r="3.5" fill="{ink}" opacity="0.15"/>
{sparkle(92, 86, 11, accent)}{sparkle(104, 30, 7, accent)}{sparkle(80, 104, 5, fg)}
"""


def mountain(n, fg, accent, ink):
    return f"""
<circle cx="32" cy="36" r="11" fill="{accent}"/>
<path d="M8 108 L46 50 L84 108 Z" fill="{fg}" opacity="0.55"/>
<path d="M36 108 L80 32 L124 108 Z" fill="{fg}"/>
<path d="M80 32 L69 51 L76 47 L81 54 L87 47 L92 52 Z" fill="{ink}" opacity="0.35"/>
<path d="M80 32 L80 14" stroke="{fg}" stroke-width="3" stroke-linecap="round"/>
<path d="M80 14 L96 19 L80 25 Z" fill="{accent}"/>
"""


def wave(n, fg, accent, ink):
    return f"""
<path d="M-4 112 L-4 86 Q10 58 42 50 Q76 44 92 66 Q82 58 72 62 Q58 70 66 84 Q76 96 96 90 Q114 84 132 70 L132 112 Z" fill="{fg}"/>
<path d="M-4 128 L-4 100 Q30 92 64 104 Q98 116 132 98 L132 128 Z" fill="{accent}"/>
<circle cx="98" cy="46" r="4" fill="{fg}"/><circle cx="108" cy="58" r="3" fill="{fg}"/><circle cx="88" cy="36" r="2.5" fill="{fg}"/>
"""


def bolt(n, fg, accent, ink):
    return f"""
<path d="M74 12 L32 70 L60 70 L50 116 L96 52 L68 52 L82 12 Z" fill="{accent}" stroke="{fg}" stroke-width="5" stroke-linejoin="round"/>
{sparkle(28, 34, 9, fg)}{sparkle(102, 94, 8, fg)}
"""


def flame(n, fg, accent, ink):
    return f"""
<path d="M64 14 Q86 40 86 60 Q98 52 96 40 Q112 62 108 82 Q100 110 64 112 Q28 110 20 82 Q16 60 36 42 Q36 58 44 62 Q42 36 64 14 Z" fill="{accent}"/>
<path d="M64 52 Q82 70 80 88 Q78 104 64 104 Q50 104 48 88 Q46 70 64 52 Z" fill="{fg}"/>
<path d="M64 76 Q72 86 70 94 Q68 100 64 100 Q60 100 58 94 Q56 86 64 76 Z" fill="{ink}" opacity="0.25"/>
"""


def shapla(n, fg, accent, ink):
    back = "".join(
        f'<path d="M64 76 Q52 50 64 24 Q76 50 64 76 Z" fill="{accent}" transform="rotate({a} 64 76)"/>'
        for a in (-72, -36, 36, 72)
    )
    front = "".join(
        f'<path d="M64 78 Q54 56 64 34 Q74 56 64 78 Z" fill="{fg}" transform="rotate({a} 64 78)"/>'
        for a in (-50, -18, 18, 50)
    )
    return f"""
<ellipse cx="64" cy="98" rx="50" ry="13" fill="{ink}" opacity="0.55"/>
<path d="M64 98 L64 86" stroke="{ink}" stroke-width="3"/>
{back}{front}
<path d="M64 80 Q54 58 64 30 Q74 58 64 80 Z" fill="{fg}"/>
<circle cx="64" cy="76" r="8" fill="#ffd54a"/>
"""


# --- emblems ---------------------------------------------------------------------

def crown(n, fg, accent, ink):
    return f"""
<path d="M24 90 L28 42 L48 62 L64 30 L80 62 L100 42 L104 90 Z" fill="{fg}"/>
<rect x="22" y="86" width="84" height="16" rx="5" fill="{fg}"/>
<circle cx="28" cy="40" r="6" fill="{accent}"/><circle cx="64" cy="28" r="6" fill="{accent}"/><circle cx="100" cy="40" r="6" fill="{accent}"/>
<circle cx="44" cy="94" r="4.5" fill="{accent}"/><circle cx="64" cy="94" r="5.5" fill="{ink}"/><circle cx="84" cy="94" r="4.5" fill="{accent}"/>
<path d="M48 76 L64 56 L80 76" stroke="{ink}" stroke-width="3" fill="none" opacity="0.25" stroke-linejoin="round"/>
"""


def trophy(n, fg, accent, ink):
    return f"""
<path d="M40 34 Q20 34 22 50 Q24 66 44 68" stroke="{fg}" stroke-width="7" fill="none" stroke-linecap="round"/>
<path d="M88 34 Q108 34 106 50 Q104 66 84 68" stroke="{fg}" stroke-width="7" fill="none" stroke-linecap="round"/>
<path d="M38 24 L90 24 L88 54 Q86 80 64 82 Q42 80 40 54 Z" fill="{fg}"/>
<rect x="57" y="80" width="14" height="14" fill="{fg}"/>
<rect x="42" y="92" width="44" height="10" rx="3" fill="{fg}"/>
<rect x="36" y="100" width="56" height="10" rx="3" fill="{accent}"/>
<path d="{star_points(64, 50, 5, 14, 6)}" fill="{accent}"/>
"""


def diamond(n, fg, accent, ink):
    return f"""
<path d="M38 34 L90 34 L108 56 L64 110 L20 56 Z" fill="{fg}"/>
<path d="M38 34 L52 56 L20 56 Z" fill="{accent}" opacity="0.55"/>
<path d="M90 34 L76 56 L108 56 Z" fill="{accent}" opacity="0.35"/>
<path d="M52 56 L64 110 L20 56 Z" fill="{accent}" opacity="0.25"/>
<path d="M76 56 L64 110 L108 56 Z" fill="{accent}" opacity="0.6"/>
<path d="M52 56 L64 34 L76 56 Z" fill="{accent}" opacity="0.15"/>
<path d="M20 56 L108 56 M38 34 L52 56 L64 34 L76 56 L90 34 M52 56 L64 110 L76 56" stroke="{ink}" stroke-width="2" fill="none" opacity="0.35" stroke-linejoin="round"/>
{sparkle(104, 24, 9, fg)}{sparkle(22, 96, 6, fg)}
"""


def anchor(n, fg, accent, ink):
    return f"""
<circle cx="64" cy="26" r="9" fill="none" stroke="{fg}" stroke-width="6"/>
<path d="M64 35 L64 104" stroke="{fg}" stroke-width="9" stroke-linecap="round"/>
<path d="M44 48 L84 48" stroke="{accent}" stroke-width="8" stroke-linecap="round"/>
<path d="M26 76 Q30 104 64 106 Q98 104 102 76" stroke="{fg}" stroke-width="9" fill="none" stroke-linecap="round"/>
<path d="M16 82 L28 66 L36 84 Z M112 82 L100 66 L92 84 Z" fill="{fg}"/>
"""


def rocket(n, fg, accent, ink):
    return f"""
<g transform="rotate(40 64 64)">
<path d="M52 92 Q64 124 76 92 Z" fill="#ffb02e"/>
<path d="M57 92 Q64 112 71 92 Z" fill="#fff2b3"/>
<path d="M44 70 L30 92 L46 88 Z M84 70 L98 92 L82 88 Z" fill="{accent}"/>
<path d="M64 12 Q86 32 86 64 L84 92 L44 92 L42 64 Q42 32 64 12 Z" fill="{fg}"/>
<circle cx="64" cy="52" r="11" fill="{accent}"/>
<circle cx="64" cy="52" r="6" fill="{ink}"/>
<path d="M54 92 L74 92 L70 98 L58 98 Z" fill="{accent}"/>
</g>
{sparkle(24, 30, 7, fg)}{sparkle(30, 100, 5, fg)}{sparkle(104, 104, 6, fg)}
"""


def star(n, fg, accent, ink):
    return f"""
<path d="{star_points(64, 68, 5, 48, 21)}" fill="{fg}" stroke="{fg}" stroke-width="6" stroke-linejoin="round"/>
<path d="{star_points(64, 68, 5, 24, 11)}" fill="{accent}"/>
{sparkle(106, 22, 8, fg)}{sparkle(20, 24, 5, fg)}
"""


def flag(n, fg, accent, ink):
    return f"""
<path d="M36 22 L36 110" stroke="{fg}" stroke-width="7" stroke-linecap="round"/>
<circle cx="36" cy="18" r="6" fill="{accent}"/>
<path d="M40 26 Q58 16 76 26 Q94 36 108 26 L108 70 Q94 80 76 70 Q58 60 40 70 Z" fill="{accent}"/>
<path d="{star_points(72, 48, 5, 12, 5)}" fill="{fg}"/>
<path d="M24 112 L48 112" stroke="{fg}" stroke-width="6" stroke-linecap="round"/>
"""


# id: (slug, drawing, (bg from, bg to), light, accent, ink)
SET = {
    # The market.
    1: ("bull", bull, ("#12b886", "#0b4f3c"), "#f4fff9", "#ffd166", "#0b3d2e"),
    2: ("bear", bear, ("#ff6b6b", "#7a1f2b"), "#fff4f2", "#c9824f", "#3b0f16"),
    3: ("candles", candles, ("#2f3e8f", "#11163d"), "#e8ecff", "#2fe39a", "#ff5a6e"),
    4: ("chart", chart, ("#00b4d8", "#03346b"), "#f2fbff", "#ffd166", "#03233f"),
    5: ("coins", coins, ("#6c4ce0", "#241356"), "#fffaf0", "#ffc83d", "#c98a0c"),
    6: ("globe", globe, ("#1098f7", "#0b2e6f"), "#eef7ff", "#7cf29a", "#0b2e6f"),
    7: ("bell", bell, ("#f76707", "#7a2308"), "#fff6ec", "#ffe066", "#5c1a05"),
    # Discipline.
    8: ("target", target, ("#364fc7", "#141f5c"), "#f5f7ff", "#ff4d6d", "#2b2d42"),
    9: ("shield", shield, ("#0ca678", "#063d31"), "#f1fff9", "#1c7ed6", "#063d31"),
    10: ("knight", knight, ("#495057", "#16191c"), "#f8f9fa", "#fcc419", "#16191c"),
    11: ("compass", compass, ("#1c7ed6", "#0a2a52"), "#f1f7ff", "#ff6b6b", "#0a2a52"),
    12: ("hourglass", hourglass, ("#ae3ec9", "#3d0e4f"), "#fdf2ff", "#ffd43b", "#3d0e4f"),
    13: ("scale", scale, ("#0b7285", "#06303a"), "#effcff", "#ffc078", "#06303a"),
    14: ("key", key, ("#e8590c", "#6b1f00"), "#fff4e6", "#74c0fc", "#6b1f00"),
    # Nature.
    15: ("sunrise", sunrise, ("#ff8a5c", "#5f2c82"), "#fff1e6", "#ffd43b", "#5f2c82"),
    16: ("moon", moon, ("#3b3b98", "#0c0c2e"), "#fff6d6", "#ffd43b", "#0c0c2e"),
    17: ("mountain", mountain, ("#4dabf7", "#1b3a6b"), "#f1f8ff", "#ffa94d", "#1b3a6b"),
    18: ("wave", wave, ("#15aabf", "#073b4c"), "#f0fcff", "#0b7285", "#073b4c"),
    19: ("bolt", bolt, ("#7048e8", "#23104f"), "#ffffff", "#ffd43b", "#23104f"),
    20: ("flame", flame, ("#c92a2a", "#3d0808"), "#ffe8a3", "#ff922b", "#3d0808"),
    21: ("shapla", shapla, ("#0ca678", "#0b3d5c"), "#fff0f6", "#f783ac", "#087f5b"),
    # Emblems.
    22: ("crown", crown, ("#7950f2", "#2a1466"), "#ffd43b", "#ff6b9d", "#7a4a00"),
    23: ("trophy", trophy, ("#0b7285", "#082f3a"), "#ffd43b", "#e8590c", "#7a4a00"),
    24: ("diamond", diamond, ("#d6336c", "#4a0d25"), "#e7f5ff", "#4dabf7", "#0b3a66"),
    25: ("anchor", anchor, ("#1864ab", "#081f3a"), "#f1f7ff", "#ff6b6b", "#081f3a"),
    26: ("rocket", rocket, ("#212e5c", "#070b1f"), "#f1f3ff", "#ff4d6d", "#070b1f"),
    27: ("star", star, ("#f59f00", "#8a3c00"), "#fff9db", "#e8590c", "#8a3c00"),
    28: ("flag", flag, ("#2b8a3e", "#0b3317"), "#ffffff", "#f03e3e", "#0b3317"),
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for n, (_, draw, bg, light, accent, ink) in SET.items():
        colors = {"fg": light, "accent": accent, "ink": ink}
        (OUT / f"{n:02d}.svg").write_text(badge(n, bg, draw, colors))
    print(f"wrote {len(SET)} pictures to {OUT}")


if __name__ == "__main__":
    main()
