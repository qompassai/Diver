#!/usr/bin/env python3

# nerd2.py
# Qompass AI - [ ]
# Copyright (C) 2026 Qompass AI, All rights reserved
# ----------------------------------------
import requests
import os
from pathlib import Path

script_dir = Path(__file__).parent
config_root = script_dir.parent  # Go up one level from scripts/ to nvim/
target_path = config_root / "lua" / "config" / "ui" / "nerd.lua"

with open(target_path, "w") as target:
    lua_str = "-- Generated with `python scripts/generator.py`\nreturn {\n"
    target.write(lua_str)

    nerd_font_src = "ryanoasis/nerd-fonts/master"
    url = "https://raw.githubusercontent.com/" + nerd_font_src + "/glyphnames.json"
    response = requests.get(url)
    data = response.json()

    indent = "    "
    for i in data:
        if i != "METADATA":
            code = str(data[i]["code"])
            char = str(data[i]["char"])
            target.write(f'{indent}{{ name = "{i}", code = "{code}", char = "{char}" }},\n')

    target.write("}")