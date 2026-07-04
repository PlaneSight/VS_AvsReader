# Diagnose Pixels — Pixel-Level Diagnostic Results

## Summary: Expected vs Actual Pixel Values

| test | plane | expected | actual_mean | actual_min | actual_max | all_match |
| --- | --- | --- | --- | --- | --- | --- |
| AviSynth BlankClip $808080 plane 0 | 0 | 128 | 126.0 | 126 | 126 | False |
| VS BlankClip [128,128,128] plane 0 | 0 | 128 | 128.0 | 128 | 128 | True |
| AviSynth BlankClip $FFFFFF plane 0 | 0 | 255 | 235.0 | 235 | 235 | False |
| AviSynth BlankClip $000000 plane 0 | 0 | 0 | 16.0 | 16 | 16 | False |
|   Y plane plane 0 | 0 | 128 | 102.0 | 102 | 102 | False |
|   plane 1 (AviSynth V=128, VS expects U) plane 1 | 1 | 128 | 142.0 | 142 | 142 | False |
|   plane 2 (AviSynth U=80, VS expects V) plane 2 | 2 | 80 | 145.0 | 145 | 145 | False |

## Per-Test Details

### AviSynth BlankClip $808080 plane 0
- **Dimensions:** 16×16
- **Stride:** 32
- **Expected:** 128

col|R0|R1|R2|R3
0|126|126|126|126
1|126|126|126|126


### VS BlankClip [128,128,128] plane 0
- **Dimensions:** 16×16
- **Stride:** 32
- **Expected:** 128

col|R0|R1|R2|R3
0|128|128|128|128
1|128|128|128|128


### AviSynth BlankClip $FFFFFF plane 0
- **Dimensions:** 16×16
- **Stride:** 32
- **Expected:** 255

col|R0|R1|R2|R3
0|235|235|235|235
1|235|235|235|235


### AviSynth BlankClip $000000 plane 0
- **Dimensions:** 16×16
- **Stride:** 32
- **Expected:** 0

col|R0|R1|R2|R3
0|16|16|16|16
1|16|16|16|16


###   Y plane plane 0
- **Dimensions:** 16×16
- **Stride:** 32
- **Expected:** 128

col|R0|R1|R2|R3
0|102|102|102|102
1|102|102|102|102


###   plane 1 (AviSynth V=128, VS expects U) plane 1
- **Dimensions:** 8×8
- **Stride:** 32
- **Expected:** 128

col|R0|R1|R2|R3
0|142|142|142|142
1|142|142|142|142


###   plane 2 (AviSynth U=80, VS expects V) plane 2
- **Dimensions:** 8×8
- **Stride:** 32
- **Expected:** 80

col|R0|R1|R2|R3
0|145|145|145|145
1|145|145|145|145

