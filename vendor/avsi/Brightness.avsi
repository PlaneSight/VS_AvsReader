#                        Brightness v1.2
#
# v1.0 - First release.
# v1.1 - Adapted for use in all versions of AviSynth.
# v1.2 - Changed the function for CurveL.
#        Now if 'light' > 0 bright areas will be brighter.
#        Changed the default value of 'light' to -20.

/*
Needed plugins: MaskTools2 v2.2.16 or greater.
    https://github.com/pinterf/masktools/releases
    http://avisynth.nl/index.php/MaskTools2/mt_lut

Brightness(mode, dark, light, bit, chroma, DarkLightZonesOnly, SaveMinMaxLuma)

mode:
-----
    "Line" - linear brightness variation.
    "Cos"  - changes brightness by Cosine function.
    "Cube" - changes brightness by a cubic power function.
    Default: "Cube"

dark:
-----
    The strength of changing dark zones.
    The recommended range is -30 ... 30. The range is not limited, in theory.
    Default: 20

light:
------
    The strength of changing light zones.
    The recommended range is -30...30.
    Default: -20

bit:
----
    Bit depth per channel in input clip.
    -1 - for autoscale in MaskTools2 (slower).
     0 - for autodetection (faster).
    8, 10, 12, 14, 16.
    Default: 0

chroma:
-------
    true  - it means "process"; set u = v = 3 in mt_lut() MaskTools2.
    false - it means "copy" or "copy first"; set u = v = 2.
    Default: false

DarkLightZonesOnly:
-------------------
    Changes only dark and light zones.
    true  or  false.
    If true, then "SaveMinMaxLuma" is ignored.
    Default: false

SaveMinMaxLuma:
---------------
    Smooth brightness change for dark and bright zones. Keep minimum (0) and maximum (255) value of luma range.
    true  or  false.
    Default: true

Usage Default:
Brightness(mode="Cube", dark=20, light=-20, bit=0, chroma=false, DarkLightZonesOnly=false, SaveMinMaxLuma=true)
or
Brightness("Cube", 20, -20, 0, false, false, true)
*/

function Brightness(clip input, string "mode", float "dark", float "light", int "bit", bool "chroma", bool "DarkLightZonesOnly", bool "SaveMinMaxLuma") {
mode   = Default(mode, "Cube")
dark   = Default(dark, 20)
light  = Default(light, -20)
bit    = Default(bit, 0)
chroma = Default(chroma, false)
DLZO   = Default(DarkLightZonesOnly, false)
SMML   = Default(SaveMinMaxLuma, true)

Assert(mode == "Line" || mode == "Cos" || mode == "Cube", "Brightness: Mode must be: Line, Cos, Cube")
Assert(bit == -1 || bit == 0 || bit == 8 || bit == 10 || bit == 12 || bit == 14 || bit == 16, \
       "Brightness: Bit depth per channel must be only: 8, 10, 12, 14, 16 or -1, 0 for autodetection")

Try { bpc = bit == 0 || bit == -1 ? input.BitsPerComponent : bit } Catch (msg) { bpc=8 }      #BitsPerComponent only in AVS+
scale_inputs = bit >= 0 ? "none" : bpc == 8 ? "none" : "allf"   #"all" range in 8 bits Y=16...235; "allf" range in 8 bits Y=0...255
use_expr = bit >= 0 ? 0 : bpc == 8 ? 0 : 2
chrom = chroma ? "process" : "copy"

LUMA = bit >= 0 ? Pow(2.0, bpc) - 1 : 255.0
maxY = String(LUMA)
midY = String(LUMA/2.0)

stD = bit >= 0 ? String(dark * Pow(2.0, bpc - 8)) : String(dark)
stL = bit >= 0 ? String(light * Pow(2.0, bpc - 8)) : String(light)

k = String(mode == "Line" || mode == "Cube" ? 0 : 1)
n = String(mode == "Cube" ? 3 : 1) # odd numbers only
j = String(30) # even numbers only
l = string(21) # odd numbers only
m = String(SMML == true ? 1 : 0)
f = String(mode == "Line" ? 1.25 : mode == "Cos" ? 1.15 : 1.05)

curveD = dark == 0 ? "x" : !DLZO ? "x "+stD+" "+k+" 1 + 1 x "+midY+" / - "+n+" ^ * pi x * "+maxY+" / cos "+k+" * - * 1 1 x "+midY+" / - "+j+" ^ "+m+" * - * +"
                               \ : "x "+stD+" 1 x "+midY+" / - "+l+" ^ pi x * "+maxY+" / cos "+l+" ^ - * "+f+" * -"
curveL = light == 0 ? "x" : !DLZO ? "x "+stL+" "+k+" 1 + 1 x "+midY+" / - "+n+" ^ * pi x * "+maxY+" / cos "+k+" * - * 1 1 x "+midY+" / - "+j+" ^ "+m+" * - * -"
                                \ : "x "+stL+" 1 x "+midY+" / - "+l+" ^ pi x * "+maxY+" / cos "+l+" ^ - * "+f+" * +"

# function 1:  x + 'st'*((1+'k')*(1 - x/127.5)^'n' - 'k'*cos(x*pi/255))*(1 - 'm'*(1 - x/127.5)^'j')
# function 2:  x - 'f'*'st'*((1 - x/127.5)^'l' - cos(x*pi/255)^'l')

out = "x "+midY+" > "+curveL+" "+curveD+" ?"

mt_lut(input, expr=out, Y=3, chroma=chrom, scale_inputs=scale_inputs, use_expr=use_expr)
# mt_lut(input, expr=out, Y=3, chroma=chrom) # for MaskTools v2.0a48
}
