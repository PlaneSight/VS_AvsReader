# Vendored AviSynth+ Plugins

Binary plugins from the AviSynth+ distribution loaded at runtime
via `IScriptEnvironment::LoadPlugin()` when referenced by `.avsi` scripts.

## Source

Homebrew `avisynthplus` 3.7.5 — `/opt/homebrew/lib/avisynth/`

| Plugin                  | Description                          |
|-------------------------|--------------------------------------|
| `libconvertstacked.dylib` | Stacked ↔ native high bitdepth    |
| `libimageseq.dylib`       | Image sequence source (`ImageReader`) |
| `libshibatch.dylib`       | Shibatch audio resampler             |
| `libtimestretch.dylib`    | Audio time stretching                |

## Additional plugin dependencies

The vendored `.avsi` scripts in `vendor/avsi/` may reference
additional AviSynth+ plugins not included here:

- **MVTools2** — motion estimation (SMDegrain)
- **AddGrainC** — grain generation (FilmGrain)
- **masktools2** — pixel operations (SMDegrain, ExTools fallback)
- **vsTCanny** — edge detection (FilmGrain)
- **nnedi3 / eedi3** — interpolation (ResizersPack)
- **Dither tools** — high bitdepth dithering (GradFun3, Dither interop)

These must be installed separately via the AviSynth+ plugin directory
or loaded explicitly with `LoadPlugin()` in the `.avs` script.

## License

Each plugin's license follows the AviSynth+ distribution (GPL).
See [AviSynth+](https://github.com/AviSynth/AviSynthPlus) for details.
