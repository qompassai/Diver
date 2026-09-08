# Terminal audio workflow

## Files

- `audio/source_voice.wav` — raw spoken track
- `audio/source_bed.wav` — music/noise/ambience bed
- `fx/presets/voice_clean.sh` — SoX voice cleanup chain
- `fx/presets/mix_preview.sh` — fast preview mix
- `fx/presets/mix_final.sh` — shaped final mix
- `Makefile` — build targets
- `nvim/audio.lua` — optional Neovim commands/keymaps

## Build targets

```bash
make preview
make final
make play
make play-voice
make clean
```

## Tuning

### Voice cleanup

Edit `fx/presets/voice_clean.sh` to change:
- `highpass 80` — removes rumble
- `lowpass 9000` — trims harsh top end
- `compand ...` — speech consistency
- `equalizer 3200 ... 3` — presence boost

### Mix level

Edit the `-v` values in the mix scripts:
- preview bed level: `0.22`
- final bed level: `0.18`

Increase the bed if you want more atmosphere. Reduce it if intelligibility drops.

## Neovim loop

Open the project in Neovim, source or integrate `nvim/audio.lua`, then:
- `<leader>ap` build preview
- `<leader>aa` play preview mix
- `<leader>av` play cleaned voice
- `<leader>af` build final

Suggested split layout:
- left: `README.md` or notes
- right: `fx/presets/*.sh`
- bottom terminal: `make preview`