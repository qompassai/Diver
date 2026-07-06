#!/usr/bin/env python3

# /qompassai/Diver/scripts/nerd.py
# Qompass AI Diver Nerd Icon Generator Script
# Copyright (C) 2026 Qompass AI, All rights reserved
# ----------------------------------------
import requests

target = open('./lua/config/ui/nerd.lua', 'w')
lua_str = '-- Generated with `python scripts/generator.py`\nreturn {\n'
target.write(lua_str)

nerd_font_src = 'ryanoasis/nerd-fonts/master'
url = 'https://raw.githubusercontent.com/' + nerd_font_src + '/glyphnames.json'
response = requests.get(url)
data = response.json()

indent = '    '
for i in data:
    if i != 'METADATA':
        code = str(data[i]['code'])
        char = str(data[i]['char'])
        target.write(f'{indent}{{ name = "{i}", code = "{code}", char = "{char}" }},\n')

target.write("}")
target.close()
