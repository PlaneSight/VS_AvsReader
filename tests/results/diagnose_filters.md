# diagnose_filters.py

## Source

- AviSynth ColorBars 64x48 YUV420P8
- Frames: 1

## Bit-Exact Filters

**Count:** 6

- `Limiter(16,235,16,240)`
- `GreyScale`
- `Crop(8,8,-8,-8)`
- `PointResize(128,96)`
- `SwapUV`
- `ex_invert`

## Non-Bit-Exact Filters

**Count:** 17

| Filter | Max Diff |
|--------|----------|
| `Invert` | 169.000000 |
| `Tweak bright=5` | 5.000000 |
| `Tweak sat=0` | 9.000000 |
| `Tweak cont=1.1` | 20.000000 |
| `Levels(16,1.0,235,16,235)` | 17.000000 |
| `FlipHorizontal` | 228.000000 |
| `FlipVertical` | 164.000000 |
| `TurnLeft` | 219.000000 |
| `TurnRight` | 219.000000 |
| `Turn180` | 170.000000 |
| `AddBorders(4,4,4,4)` | 16.000000 |
| `BilinearResize(128,96)` | 17.000000 |
| `BicubicResize(128,96)` | 30.000000 |
| `ex_lut 'x 2 /'` | 1.000000 |
| `ex_boxblur` | 73.000000 |
| `ex_expand` | 196.000000 |
| `ex_inpand` | 219.000000 |

## Dimension Mismatch

**Count:** 1

- `UToY`
