#!/usr/bin/env python3
"""Render the bug-bounty dashboard PNG.

Reads a JSON snapshot from stdin (see lua/security/bounty/dashboard.lua),
writes a dark-themed dashboard PNG to the path given as argv[1].

Usage: dashboard_render.py <output.png> < snapshot.json
Stdin carries the snapshot so nothing sensitive lands on the command line.
"""
import json
import sys

from PIL import Image, ImageDraw, ImageFont

WIDTH, HEIGHT = 1400, 900
MARGIN = 48

BG = (13, 17, 23)
PANEL = (22, 27, 34)
TEXT = (230, 237, 243)
DIM = (139, 148, 158)
ACCENT = (88, 166, 255)
GREEN = (63, 185, 80)
RED = (248, 81, 73)
AMBER = (210, 153, 34)
LINE = (48, 54, 61)

FONT_CANDIDATES = [
    "/usr/share/fonts/TTF/JetBrainsMono-Regular.ttf",
    "/usr/share/fonts/TTF/JetBrainsMonoNerdFontMono-Regular.ttf",
    "/home/phaedrus/.local/share/fonts/TTF/JetBrainsMonoNerdFontMono-Regular.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
]


def load_font(size):
    for path in FONT_CANDIDATES:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


F_TITLE = load_font(44)
F_HEAD = load_font(28)
F_BODY = load_font(22)
F_SMALL = load_font(18)


def gate_dot(draw, x, y, is_open, label):
    r = 11
    color = GREEN if is_open else RED
    draw.ellipse([x - r, y - r, x + r, y + r], outline=color, width=3)
    if is_open:
        draw.ellipse([x - r + 5, y - r + 5, x + r - 5, y + r - 5], fill=color)
    draw.text((x + r + 10, y - 13), label, font=F_SMALL, fill=DIM)


def draw_program(draw, prog, y):
    card_h = 132
    draw.rounded_rectangle(
        [MARGIN, y, WIDTH - MARGIN, y + card_h], radius=14, fill=PANEL
    )
    x = MARGIN + 28
    draw.text((x, y + 16), prog["name"], font=F_HEAD, fill=TEXT)
    meta = "%d scope target(s)  ·  %d report(s)" % (
        prog["scope_targets"],
        prog["reports"],
    )
    draw.text((x, y + 56), meta, font=F_BODY, fill=DIM)

    gates = prog["gates"]
    gx = x
    gy = y + card_h - 30
    for key, label in (("scope", "scope"), ("finding", "finding"), ("submission", "submission")):
        gate_dot(draw, gx, gy, bool(gates.get(key)), label)
        gx += 150

    run = prog.get("last_run")
    if run:
        run_line = "run %s · %s @ %s · %d new finding(s)" % (
            run["id"],
            run["state"],
            run["stage"],
            run["new_findings"],
        )
        color = AMBER if run["state"] == "running" else DIM
    else:
        run_line = "no recon runs yet"
        color = DIM
    draw.text((WIDTH - MARGIN - 28 - draw.textlength(run_line, font=F_SMALL), y + 24),
              run_line, font=F_SMALL, fill=color)
    return y + card_h + 20


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: dashboard_render.py <output.png>")
    snapshot = json.load(sys.stdin)

    img = Image.new("RGB", (WIDTH, HEIGHT), BG)
    draw = ImageDraw.Draw(img)

    draw.text((MARGIN, 36), "BUG BOUNTY", font=F_TITLE, fill=TEXT)
    draw.text(
        (MARGIN, 92),
        "dashboard · generated %s" % snapshot.get("generated_at", "?"),
        font=F_SMALL,
        fill=DIM,
    )
    profile = snapshot.get("active_profile") or "none"
    plabel = "profile: %s" % profile
    draw.text(
        (WIDTH - MARGIN - draw.textlength(plabel, font=F_SMALL), 92),
        plabel,
        font=F_SMALL,
        fill=ACCENT,
    )
    draw.line([MARGIN, 132, WIDTH - MARGIN, 132], fill=LINE, width=2)

    y = 160
    programs = snapshot.get("programs", [])
    if not programs:
        msg = "No programs filed yet — run :BountyScope"
        draw.text(
            ((WIDTH - draw.textlength(msg, font=F_HEAD)) / 2, HEIGHT / 2),
            msg,
            font=F_HEAD,
            fill=DIM,
        )
    else:
        for prog in programs:
            if y + 160 > HEIGHT - 90:
                break
            y = draw_program(draw, prog, y)

    totals = snapshot.get("totals", {})
    footer = "%d program(s)  ·  %d scope target(s)  ·  %d report(s)  ·  %d new finding(s)" % (
        totals.get("programs", 0),
        totals.get("scope_targets", 0),
        totals.get("reports", 0),
        totals.get("new_findings", 0),
    )
    draw.line([MARGIN, HEIGHT - 64, WIDTH - MARGIN, HEIGHT - 64], fill=LINE, width=2)
    draw.text((MARGIN, HEIGHT - 48), footer, font=F_SMALL, fill=DIM)

    img.save(sys.argv[1], "PNG")


if __name__ == "__main__":
    main()
