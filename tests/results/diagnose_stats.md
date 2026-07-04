# Diagnose Stats

Per-plane min, max, and average pixel values for each processing stage.
Resolution: 320x240, frames: 1.

| label | min_Y | min_U | min_V | max_Y | max_U | max_V | avg_Y | avg_U | avg_V |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| AviSynth ColorBars (src) | 7.00 | 44.00 | 44.00 | 235.00 | 212.00 | 212.00 | 0.36 | 0.52 | 0.50 |
| VS BlankClip gray | 128.00 | 128.00 | 128.00 | 128.00 | 128.00 | 128.00 | 0.50 | 0.50 | 0.50 |
| AviSynth BlankClip gray | 126.00 | 128.00 | 128.00 | 126.00 | 128.00 | 128.00 | 0.49 | 0.50 | 0.50 |
| |avs_blank - vs_blank| | 2.00 | 128.00 | 128.00 | 2.00 | 128.00 | 128.00 | 0.01 | 0.50 | 0.50 |
| VS Expr invert (port) | 20.00 | 44.00 | 44.00 | 248.00 | 212.00 | 212.00 | 0.64 | 0.52 | 0.50 |
| AviSynth ex_invert (ref) | 20.00 | 44.00 | 44.00 | 248.00 | 212.00 | 212.00 | 0.64 | 0.52 | 0.50 |
| |port_invert - ref_invert| | 0.00 | 44.00 | 44.00 | 0.00 | 212.00 | 212.00 | 0.00 | 0.52 | 0.50 |
| AviSynth raw Expr 255 x - | 20.00 | 44.00 | 44.00 | 248.00 | 212.00 | 212.00 | 0.64 | 0.52 | 0.50 |
| |port_invert - avs_raw_invert| | 0.00 | 44.00 | 44.00 | 0.00 | 212.00 | 212.00 | 0.00 | 0.52 | 0.50 |
