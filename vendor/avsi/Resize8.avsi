# ===============================================================================
# ===============================================================================
#            Resize8 2025-03-25
# ===============================================================================
# ===============================================================================
#
#   https://forum.videohelp.com/threads/403005-Resize8-An-updated-version-of-the-original-resizing-function
#   https://forum.doom9.org/showthread.php?t=183057
#
#   Based on Resize8 1.2 2015.02.23 by mawen1250
#   http://avisynth.nl/index.php/Resize8
#
# ===============================================================================
#            Requirements
# ===============================================================================
#
#   RgTools for ringing repair http://avisynth.nl/index.php/RgTools
#
#   AviSynth 2.60 or 2.61 without HBD, YUVA or _ChromaLocation frame property support.
#   AviSynth+ >= 3.4.0 (r2295) for HBD and YUVA support.
#   AviSynth+ >= 3.7.1 (r3593) for _ChromaLocation frame property support.
#   AviSynth+ >= 3.7.3 (r4003) for SinPowerResize SincLin2Resize & UserDefined2Resize support.
#   AviSynth+ >= 3.7.3 Test 10 (r4035) for UserDefined2Resize "s" argument support.
#
# ===============================================================================
#
#   Supports all Avisynth+ colorspaces, bit depths & native resizing kernels.
#   Supports any resizer with the same named arguments for cropping as AviSynth's native resizers.
#   The following are also "known" resizers. Therefore the a1, a2 and a3 arguments can be used to
#   specify resizer options when applicable.
#
#   JincResize (multi-threaded): http://avisynth.nl/index.php/JincResize
#   ResampleMT (multi-threaded): https://github.com/jpsdr/ResampleMT
#
# ===============================================================================
# ===============================================================================

function Resize8(clip source, int "target_width", int "target_height", \
                 float "src_left", float "src_top", float "src_width", float "src_height", \
                 string "kernel", string "kernel_c", string "rstr", string "rstr_c", \
                 float "a1", float "a2", float "a3", float "a1_c", float "a2_c", float "a3_c", \
                 val "noring", val "noring_c", val "cplace", val "cplaced", \
                 bool "Y", bool "U", bool "V", bool "alpha", bool "chroma", \
                 val "DAR", val "SAR", bool "keep", bool "fullc", \
                 bool "separate", bool "show", bool "info") {

# ===============================================================================

    AvsStr = LCase(VersionString())
    IsAvsPlus = (FindStr(AvsStr, "avisynth+") > 0)
    IsAvsNeo = (FindStr(AvsStr, "avisynth neo") > 0)
    NumA = IsAvsPlus || IsAvsNeo ? FindStr(AvsStr, "(r") + 2 : 0
    NumB = IsAvsPlus || IsAvsNeo ? FindStr(AvsStr, ",") : 0
    NumC = (NumB > NumA) ? NumB - NumA : undefined()
    AvsBuildNum = (NumA > 2) ? int(value(MidStr(AvsStr, NumA, NumC))) : 0
    IsAvsHBD = (AvsBuildNum >= 2295)
    IsAvsProps = (AvsBuildNum >= 3593)

    R8A = " Resize8 " + chr(10) + " "
    R8B = " " + chr(10)
    assert(HasVideo(source) && (width(source) > 48) && (height(source) > 48), \
           R8A + "No video found or the source width or height is too small" + R8B)

# ===============================================================================
#            source properties
# ===============================================================================

    audio       = HasAudio(source) ? source.KillVideo() : source
    source      = source.KillAudio()
    IsRGBSource = IsRGB(source)
    pixtype     = PixelType(source)
    source_bits = IsAvsHBD ? BitsPerComponent(source) : 8

    sCSP = IsYUY2(source)  ? "YUY2" : \
           IsYV411(source) ? "411"  : \
           (IsAvsHBD && IsY(source))   || IsY8(source)   ? "000" : \
           (IsAvsHBD && Is420(source)) || IsYV12(source) ? "420" : \
           (IsAvsHBD && Is422(source)) || IsYV16(source) ? "422" : \
           (IsAvsHBD && Is444(source)) || IsYV24(source) ? "444" : \
           IsRGB24(source) ? "RGB24" : \
           IsRGB32(source) ? "RGB32" : \
           IsAvsHBD && IsRGB48(source) ? "RGB48" : \
           IsAvsHBD && IsRGB64(source) ? "RGB64" : \
           IsAvsHBD && IsPlanarRGB(source)  ? "RGBP"  : \
           IsAvsHBD && IsPlanarRGBA(source) ? "RGBAP" : \
           assert(false, R8A + chr(34) + pixtype + chr(34) + " is an unsupported color format" + R8B)

    Sub444 = (sCSP == "444") || IsRGBSource
    Sub422 = (sCSP == "422") || (sCSP == "YUY2")
    Sub420 = (sCSP == "420")
    Sub411 = (sCSP == "411")
    Sub000 = (sCSP == "000")

    IsAlpha  = (IsAvsHBD && HasAlpha(source)) || (sCSP == "RGB32")
    alpha    = default(alpha, IsAlpha ? true : false)
    AddAlpha = alpha && !IsAlpha

    Source_Width         = width(source)
    Source_Height        = height(source)
    F_Source_Width       = float(Source_Width)
    F_Source_Height      = float(Source_Height)
    Source_Chroma_Width  = Sub444 || Sub000 ? Source_Width : Source_Width / (Sub422 || Sub420 ? 2 : 4)
    Source_Chroma_Height = Sub420 ? Source_Height / 2 : Source_Height

    src_left   = default(src_left, 0.0)
    src_top    = default(src_top,  0.0)
    src_width  = default(src_width,  F_Source_Width)
    src_height = default(src_height, F_Source_Height)
    src_width  = (src_width  <= 0) ? F_Source_Width  - src_left + src_width  : src_width
    src_height = (src_height <= 0) ? F_Source_Height - src_top  + src_height : src_height

# ===============================================================================
#            Parameters for resizing
# ===============================================================================

    separate = default(separate, false)
    fullc    = default(fullc, false) && !Sub444 && !Sub000 && !separate

    target_width           = default(target_width, Source_Width)
    target_height          = default(target_height, Source_Height)
    F_target_width         = float(target_width)
    F_target_height        = float(target_height)
    target_chroma_width    = fullc || Sub444 || Sub000 ? target_width : target_width / (Sub422 || Sub420 ? 2 : 4)
    target_chroma_height   = fullc || !Sub420 ? target_height : target_height / 2
    F_target_chroma_width  = float(target_chroma_width)
    F_target_chroma_height = float(target_chroma_height)

    assert(!Sub411 || (target_width % 4 == 0), R8A + pixtype + " output width must be Mod4" + R8B)
    assert((!Sub422 && !Sub420) || (target_width % 2 == 0), R8A + pixtype + " output width must be Mod2" + R8B)
    assert(!Sub420 || (target_height % 2 == 0), R8A + pixtype + " output height must be Mod2" + R8B)

    !separate ? Eval("""

    src_chroma_left   = Sub444 || Sub000 ? src_left : src_left / (Sub422 || Sub420 ? 2.0 : 4.0)
    src_chroma_top    = Sub420 ? src_top / 2.0 : src_top
    src_chroma_width  = Sub444 || Sub000 ? src_width : src_width / (Sub422 || Sub420 ? 2.0 : 4.0)
    src_chroma_height = Sub420 ? src_height / 2.0 : src_height

    """) : Eval("""

    src_right         = F_Source_Width  - src_width  - src_left
    src_bottom        = F_Source_Height - src_height - src_top
    src_chroma_left   = src_left
    src_chroma_top    = src_top
    src_chroma_width  = float(Source_Chroma_Width)  - src_left - src_right
    src_chroma_height = float(Source_Chroma_Height) - src_top  - src_bottom

    """)

    IsLumaU = ((F_target_width * F_target_height / src_width / src_height) >= 1)
    IsChroU = ((F_target_chroma_width * F_target_chroma_height / src_chroma_width / src_chroma_height) >= 1)

# ===============================================================================
#            Input & Output Aspect Ratios
# ===============================================================================

    DAR  = default(DAR, 0.0)
    SAR  = default(SAR, 0.0)
    keep = default(keep, false)

    assert(IsFloat(DAR) && !IsInt(DAR) && (DAR >= 0), \
           R8A + "DAR must be a floating point number greater than or equal to zero" + \
           R8B + " (16.0/9 or 1.7778 etc)" + R8B)
    assert(IsFloat(SAR) && !IsInt(SAR) && (SAR >= 0), \
           R8A + "SAR must be a floating point number greater than or equal to zero" + \
           R8B + " (64.0/45 or 1.4222 etc)" + R8B)
    assert((DAR == 0) || (SAR == 0), \
           R8A + "A DAR and SAR can't be specified together (both cannot be greater than zero)" + R8B)

    PropNum    = IsAvsProps ? source.propGetAny("_SARNum") : undefined()
    PropDen    = IsAvsProps ? source.propGetAny("_SARDen") : undefined()
    PropNum    = defined(PropNum) && IsInt(PropNum) ? PropNum : 0
    PropDen    = defined(PropDen) && IsInt(PropDen) ? PropDen : 0
    F_PropNum  = float(PropNum)
    F_PropDen  = float(PropDen)
    IsPropSAR  = (PropNum > 0 < PropDen)
    PropSAR    = IsPropSAR ? F_PropNum / F_PropDen : 0
    IsDAR      = (DAR > 0)
    IsSAR      = (SAR > 0)
    IsAspect   = (IsDAR || IsSAR || IsPropSAR) && !separate

    cropping_L = max(0, src_left)
    cropping_T = max(0, src_top)
    cropping_R = max(0, F_Source_Width  - cropping_L - src_width)
    cropping_B = max(0, F_Source_Height - cropping_T - src_height)

    F_Cropped_Width  = F_Source_Width  - cropping_L - cropping_R
    F_Cropped_Height = F_Source_Height - cropping_T - cropping_B

    InSAR  = IsDAR     ? F_Source_Height * DAR / F_Source_Width : \
             IsSAR     ? SAR : \
             IsPropSAR ? F_PropNum / F_PropDen : 1.0

    InDAR  = IsDAR     ? DAR : \
             IsSAR     ? F_Source_Width * SAR / F_Source_Height : \
             IsPropSAR ? F_Source_Width * F_PropNum / F_PropDen / F_Source_Height : \
                         F_Source_Width / F_Source_Height

    OutSAR = keep      ? (IsDAR ? F_target_height * DAR / F_target_width : InSAR) : \
             IsDAR     ? F_target_height * F_Cropped_Width * F_Source_Height * \
                         DAR / F_Source_Width / F_Cropped_Height / F_target_width : \
             IsSAR     ? F_target_height * F_Cropped_Width * SAR / F_target_width / F_Cropped_Height : \
             IsPropSAR ? F_target_height * F_Cropped_Width * \
                         F_PropNum / F_PropDen / F_target_width / F_Cropped_Height : \
                         F_target_height * F_Cropped_Width / F_target_width / F_Cropped_Height

    OutDAR = keep && IsDAR ? DAR : F_target_width * OutSAR / F_target_height

    IsEqual = !keep && !IsDAR && !IsSAR && IsPropSAR && (abs(InSAR - OutSAR) < 0.00005)

    assert((OutSAR >= 0.000051), R8A + "The output sample aspect ratio must be greater than zero" + R8B)

    OutNum  = (OutSAR <= 0) ? 0 : \
              keep      ? (IsDAR || IsSAR ? ContinuedNumerator(OutSAR, limit=10000) : \
              IsPropSAR ? PropNum : 1) : \
              IsEqual   ? PropNum : ContinuedNumerator(OutSAR, limit=10000)
    OutDen  = (OutSAR <= 0) ? 0 : \
              keep      ? (IsDAR || IsSAR ? ContinuedDenominator(OutSAR, limit=10000) : \
              IsPropSAR ? PropDen : 1) : \
              IsEqual   ? PropDen : ContinuedDenominator(OutSAR, limit=10000)

# ===============================================================================
#            Determine the resizing kernel
# ===============================================================================

    LumaU = (R8_Luma_UpScale() != "")     ? R8_Luma_UpScale()     : "Lanczos4Resize"
    LumaD = (R8_Luma_DownScale() != "")   ? R8_Luma_DownScale()   : "Spline36Resize"
    ChroU = (R8_Chroma_UpScale() != "")   ? R8_Chroma_UpScale()   : "LanczosResize"
    ChroD = (R8_Chroma_DownScale() != "") ? R8_Chroma_DownScale() : "Spline36Resize"

    IsKl = defined(kernel)
    IsKc = defined(kernel_c)
    Kl   = default(kernel,  IsLumaU ? LumaU  : LumaD)
    Kc   = default(kernel_c, IsKl ? kernel : IsChroU ? ChroU : ChroD)

    original_Kl = Kl
    original_Kc = Kc

    IsResizeMTAppended_Kl = (RightStr(Kl, 8) == "ResizeMT") || (RightStr(Kl, 8) == "MTResize")
    IsResizeMTAppended_Kc = (RightStr(Kc, 8) == "ResizeMT") || (RightStr(Kc, 8) == "MTResize")
    IsMTAppended_Kl       = (RightStr(Kl, 2) == "MT")
    IsMTAppended_Kc       = (RightStr(Kc, 2) == "MT")
    IsResampleMT_Kl       = IsResizeMTAppended_Kl || IsMTAppended_Kl
    IsResampleMT_Kc       = IsResizeMTAppended_Kc || IsMTAppended_Kc

    Kl = IsResizeMTAppended_Kl ? LeftStr(Kl, StrLen(Kl) - 8) : \
         (RightStr(Kl, 6) == "Resize") ? LeftStr(Kl, StrLen(Kl) - 6) : \
         IsMTAppended_Kl ? LeftStr(Kl, StrLen(Kl) - 2) : Kl
    Kc = IsResizeMTAppended_Kc ? LeftStr(Kc, StrLen(Kc) - 8) : \
         (RightStr(Kc, 6) == "Resize") ? LeftStr(Kc, StrLen(Kc) - 6) : \
         IsMTAppended_Kc ? LeftStr(Kc, StrLen(Kc) - 2) : Kc

    assert((((LeftStr(Kl, 9) != "SoftCubic") || (StrLen(Kl) < 10) || (Kl == "SoftCubicXX") || \
           (Kl == "SoftCubic100") || (Kl == "SoftCubicMT")) || \
           (0 <= value(RightStr(Kl, StrLen(Kl) - 9)) <= 100)) && \
           (((LeftStr(Kc, 9) != "SoftCubic") || (StrLen(Kc) < 10) || (Kc == "SoftCubicXX") || \
           (Kc == "SoftCubic100") || (Kc == "SoftCubicMT")) || \
           (0 <= value(RightStr(Kc, StrLen(Kc) - 9)) <= 100)), \
           R8A + """When replacing "XX" in SoftCubicXX with an integer """ + chr(10) + \
           """ "XX" must be greater than or equal to zero, and less than or equal to 100""" + R8B)

# ===============================================================================
#            Add the appropriate resizer arguments
# ===============================================================================

    IsA1  = defined(a1)
    IsA2  = defined(a2)
    IsA3  = defined(a3)
    IsA1c = defined(a1_c)
    IsA2c = defined(a2_c)
    IsA3c = defined(a3_c)

    arg1_Kl = (Kl == "Catmull-Rom")         ? ", b=0, c=0.5" : \
              (Kl == "Hermite")             ? ", b=0, c=0" : \
              (Kl == "Mitchell-Netravali")  ? ", b=1.0/3.0, c=1.0/3.0" : \
              (Kl == "Robidoux")            ? ", b=0.3782, c=0.3109" : \
              (Kl == "SoftCubic")           ? ", b=" + R8_FS(default(a1,75)/100.0) + \
                                              ", c=" + R8_FS(1.0-(default(a1,75)/100.0)) : \
              (Kl == "SoftCubic100")        ? ", b=1.0, c=0" : \
              (Kl == "SoftCubicXX")         ? ", b=0.75, c=0.25" : \
              (LeftStr(Kl,9)=="SoftCubic")  ? ", b=" + R8_FS(Value(RightStr(Kl,StrLen(Kl)-9))/100.0) + \
                                              ", c=" + R8_FS(1.0-(Value(RightStr(Kl,StrLen(Kl)-9))/100.0)) : \
              (Kl == "Bicubic")             ? (IsA1 ? ", b=" + R8_FS(a1) : "") : \
              (Kl == "Bilinear")            ? "" : \
              (Kl == "Blackman")            ? (IsA1 ? ", taps=" + R8_FS(a1) : "") : \
              (Kl == "Blackman2")           ? ", taps=2" : \
              (Kl == "Blackman3")           ? ", taps=3" : \
              (Kl == "Blackman4")           ? ", taps=4" : \
              (Kl == "Gauss")               ? (IsA1 ? ", p="    + R8_FS(a1) : "") : \
              (Kl == "Jinc")                ? (IsA1 ? ", tap="  + R8_FS(a1) : "") : \
              (Kl == "Jinc36")              ? "" : \
              (Kl == "Jinc64")              ? "" : \
              (Kl == "Jinc144")             ? "" : \
              (Kl == "Jinc256")             ? "" : \
              (Kl == "Lanczos")             ? (IsA1 ? ", taps=" + R8_FS(a1) : "") : \
              (Kl == "Lanczos2")            ? ", taps=2" : \
              (Kl == "Lanczos3")            ? ", taps=3" : \
              (Kl == "Lanczos4")            ? "" : \
              (Kl == "Point")               ? "" : \
              (Kl == "Sinc")                ? (IsA1 ? ", taps=" + R8_FS(a1) : "") : \
              (Kl == "SinPow")              ? (IsA1 ? ", p="    + R8_FS(a1) : "") : \
              (Kl == "SincLin2")            ? (IsA1 ? ", taps=" + R8_FS(a1) : "") : \
              (Kl == "Spline16")            ? "" : \
              (Kl == "Spline36")            ? "" : \
              (Kl == "Spline64")            ? "" : \
              (Kl == "UserDefined2")        ? (IsA1 ? ", b="    + R8_FS(a1) : "") : "unKnown"

    arg2_Kl = (Kl == "Bicubic")             ? (IsA2 ? ", c="    + R8_FS(a2) : "") : \
              (Kl == "Gauss")               ? (IsA2 ? ", b="    + R8_FS(a2) : "") : \
              (Kl == "Jinc")                ? (IsA2 ? ", blur=" + R8_FS(a2) : "") : \
              (Kl == "UserDefined2")        ? (IsA2 ? ", c="    + R8_FS(a2) : "") : ""

    arg3_Kl = (Kl == "Gauss")               ? (IsA3 ? ", s="    + R8_FS(a3) : "") : \
              (Kl == "UserDefined2")        ? (IsA3 ? ", s="    + R8_FS(a3) : "") : ""

# -------------------------------------------------------------------------------

    arg1_Kc = !IsA1c && IsA1 && (Kl == Kc)  ? arg1_Kl : \
              (Kc == "Catmull-Rom")         ? ", b=0, c=0.5" : \
              (Kc == "Hermite")             ? ", b=0, c=0" : \
              (Kc == "Mitchell-Netravali")  ? ", b=1.0/3.0, c=1.0/3.0" : \
              (Kc == "Robidoux")            ? ", b=0.3782, c=0.3109" : \
              (Kc == "SoftCubic")           ? ", b=" + R8_FS(default(a1_c,75)/100.0) + \
                                              ", c=" + R8_FS(1.0-(default(a1_c,75)/100.0)) : \
              (Kc == "SoftCubic100")        ? ", b=1.0, c=0" : \
              (Kc == "SoftCubicXX")         ? ", b=0.75, c=0.25" : \
              (LeftStr(Kc,9)=="SoftCubic")  ? ", b=" + R8_FS(Value(RightStr(Kc,StrLen(Kc)-9))/100.0) + \
                                              ", c=" + R8_FS(1.0-(Value(RightStr(Kc,StrLen(Kc)-9))/100.0)) : \
              (Kc == "Bicubic")             ? (IsA1c ? ", b=" + R8_FS(a1_c) : "") : \
              (Kc == "Bilinear")            ? "" : \
              (Kc == "Blackman")            ? (IsA1c ? ", taps=" + R8_FS(a1_c) : "") : \
              (Kc == "Blackman2")           ? ", taps=2" : \
              (Kc == "Blackman3")           ? ", taps=3" : \
              (Kc == "Blackman4")           ? ", taps=4" : \
              (Kc == "Gauss")               ? (IsA1c ? ", p="    + R8_FS(a1_c) : "") : \
              (Kc == "Jinc")                ? (IsA1c ? ", tap="  + R8_FS(a1_c) : "") : \
              (Kc == "Jinc36")              ? "" : \
              (Kc == "Jinc64")              ? "" : \
              (Kc == "Jinc144")             ? "" : \
              (Kc == "Jinc256")             ? "" : \
              (Kc == "Lanczos")             ? (IsA1c ? ", taps=" + R8_FS(a1_c) : "") : \
              (Kc == "Lanczos2")            ? ", taps=2" : \
              (Kc == "Lanczos3")            ? ", taps=3" : \
              (Kc == "Lanczos4")            ? "" : \
              (Kc == "Point")               ? "" : \
              (Kc == "Sinc")                ? (IsA1c ? ", taps=" + R8_FS(a1_c) : "") : \
              (Kc == "SinPow")              ? (IsA1c ? ", p="    + R8_FS(a1_c) : "") : \
              (Kc == "SincLin2")            ? (IsA1c ? ", taps=" + R8_FS(a1_c) : "") : \
              (Kc == "Spline16")            ? "" : \
              (Kc == "Spline36")            ? "" : \
              (Kc == "Spline64")            ? "" : \
              (Kc == "UserDefined2")        ? (IsA1c ? ", b="    + R8_FS(a1_c) : "") : "unKnown"

    arg2_Kc = !IsA2c && IsA2 && (Kl == Kc)  ? arg2_Kl : \
              (Kc == "Bicubic")             ? (IsA2c ? ", c="    + R8_FS(a2_c) : "") : \
              (Kc == "Gauss")               ? (IsA2c ? ", b="    + R8_FS(a2_c) : "") : \
              (Kc == "Jinc")                ? (IsA2c ? ", blur=" + R8_FS(a2_c) : "") : \
              (Kc == "UserDefined2")        ? (IsA2c ? ", c="    + R8_FS(a2_c) : "") : ""

    arg3_Kc = !IsA3c && IsA3 && (Kl == Kc)  ? arg3_Kl : \
              (Kc == "Gauss")               ? (IsA3c ? ", s="    + R8_FS(a3_c) : "") : \
              (Kc == "UserDefined2")        ? (IsA3c ? ", s="    + R8_FS(a3_c) : "") : ""

    unKnown_Kl = (arg1_Kl == "unKnown")
    unKnown_Kc = (arg1_Kc == "unKnown")
    arg1_Kl    = unKnown_Kl ? "" : arg1_Kl
    arg1_Kc    = unKnown_Kc ? "" : arg1_Kc

# ===============================================================================
#            Restore full resizer names
# ===============================================================================

    Kl = (Kl == "Catmull-Rom") || (Kl == "Hermite") || (Kl == "Mitchell-Netravali") || \
         (Kl == "Robidoux") || (LeftStr(Kl, 9) == "SoftCubic") ? "Bicubic" : \
         (LeftStr(Kl, 8) == "Blackman") ? "Blackman" : \
         (Kl == "Lanczos2") || (Kl == "Lanczos3") ? "Lanczos" : Kl

    Kc = (Kc == "Catmull-Rom") || (Kc == "Hermite") || (Kc == "Mitchell-Netravali") || \
         (Kc == "Robidoux") || (LeftStr(Kc, 9) == "SoftCubic") ? "Bicubic" : \
         (LeftStr(Kc, 8) == "Blackman") ? "Blackman" : \
         (Kc == "Lanczos2") || (Kc == "Lanczos3") ? "Lanczos" : Kc

    resizer_Kl = unKnown_Kl ? original_Kl : IsResampleMT_Kl ? Kl + "ResizeMT" : Kl + "Resize"
    resizer_Kc = unKnown_Kc ? original_Kc : IsResampleMT_Kc ? Kc + "ResizeMT" : Kc + "Resize"

# ===============================================================================
#            Configure rstr & rstr_c
# ===============================================================================

    strLumaU = IsKl ? "" : R8_Luma_UpScale_rstr()
    strLumaD = IsKl ? "" : R8_Luma_DownScale_rstr()
    strChroU = IsKl || IsKc ? "" : R8_Chroma_UpScale_rstr()
    strChroD = IsKl || IsKc ? "" : R8_Chroma_DownScale_rstr()

    IsRstr = defined(rstr)
    rstr   = default(rstr, IsLumaU ? strLumaU : strLumaD)
    rstr_c = default(rstr_c, IsRstr && (resizer_Kl == resizer_Kc) ? rstr : IsChroU ? strChroU : strChroD)
    rstr   = (rstr   != "") ? ", " + rstr   : ""
    rstr_c = (rstr_c != "") ? ", " + rstr_c : ""

# ===============================================================================
#            Chroma crop before scaling to prevent chroma shift
# ===============================================================================
#
#   YUY2 & YUV411:
#   The chroma placement is always 0 (left/mpeg2) and any other value in frame properties is ignored.
#
#   YUV422 (but not YUY2):
#   The chroma placement is usually 0 (left/mpeg2), but Avisynth+ also permits 2 (top_left) and
#   4 (bottom_left) in frame properties, while treating them as 0 (left/mpeg2).
#   Therefore 1 (center/mpeg1/jpeg) is treated as center, while 0, 2 & 4 are treated as 0 (left/mpeg2),
#   and any other value in frame properties will result in an error message.
#
#   YUV420:
#   The chroma placement for YUV420 can be 0 (left/mpeg2), 1 (center/mpeg1/jpeg), 2 (top_left),
#   3 (top), 4 (bottom_left) or 5 (bottom). Any other value will result in an error message.
#
#   Avisynth's resizers cause a slight chroma shift when scaling YUV with sub-sampled chroma that isn't
#   center aligned.
#   For a 2x upscale of left aligned YUV420 it's a shift of 0.25, or one quarter of a luma pixel to the right.
#   For a 2x downscale of left aligned YUV420 it's a shift of -0.5, or half a luma pixel to the left.
#
# ===============================================================================

    PropChroma = IsAvsProps ? source.propGetAny("_ChromaLocation") : undefined()
    PropChroma = defined(PropChroma) && IsInt(PropChroma) ? PropChroma : -1

    cplace  = default(cplace, "")
    cplaced = default(cplaced, fullc ? "" : cplace)

    assert(IsInt(cplace)  || IsString(cplace),  R8A + "cplace must be an integer or a string"  + R8B)
    assert(IsInt(cplaced) || IsString(cplaced), R8A + "cplaced must be an integer or a string" + R8B)

    cplace_s = cplace
    cplace_d = cplaced
    cplace   = !IsInt(cplace) ? cplace : string(cplace)
    cplaced  = !IsInt(cplaced) ? cplaced : string(cplaced)

    cplace  = (cplace == "") ? "" : \
              (cplace == "0") || (cplace == "mpeg2") || (cplace == "left") ? "0" : \
              (cplace == "1") || (cplace == "mpeg1") || (cplace == "center") || (cplace == "jpeg") ? "1" : \
              (cplace == "2") || (cplace == "top_left") ? "2" : \
              (cplace == "3") || (cplace == "top") ? "3" : \
              (cplace == "4") || (cplace == "bottom_left") ? "4" : \
              (cplace == "5") || (cplace == "bottom") ? "5" : "unsupported"
    cplaced = (cplaced == "") ? "" : \
              (cplaced == "0") || (cplaced == "mpeg2") || (cplaced == "left") ? "0" : \
              (cplaced == "1") || (cplaced == "mpeg1") || (cplaced == "center") || (cplaced == "jpeg") ? "1" : \
              (cplaced == "2") || (cplaced == "top_left") ? "2" : \
              (cplaced == "3") || (cplaced == "top") ? "3" : \
              (cplaced == "4") || (cplaced == "bottom_left") ? "4" : \
              (cplaced == "5") || (cplaced == "bottom") ? "5" : "unsupported"

# -------------------------------------------------------------------------------

    assert((cplace == "")  || (cplace != "unsupported"), \
           R8A + "cplace=" + (IsInt(cplace_s) ? string(cplace_s) : """"""" + cplace_s + """"""") + \
           " is not a supported chroma placement" + R8B)
    assert((cplaced == "") || (cplaced != "unsupported"), \
           R8A + "cplaced=" + (IsInt(cplace_d) ? string(cplace_d) : """"""" + cplace_d + """"""") + \
           " is not a supported chroma placement" + R8B)
    assert((cplace != "") || separate || (Kc == "Point") || (sCSP == "YUY2") || \
           (!Sub422 || (-1 <= PropChroma <= 2) || (PropChroma == 4)), \
           R8A + "The value for ChromaLocation in frame properties is " + string(PropChroma) + " but only" + \
           R8B + " 0 (left), 1 (center), 2 (top_left) & 4 (bottom_left) are supported for YUV422" + \
           R8B + " (however if the cplace argument is used to specify a supported chroma" + \
           R8B + " placement the chroma location in frame properties will be ignored)" + R8B)
    assert((cplace != "") || separate || (Kc == "Point") || \
           (((sCSP != "YUY2") && !Sub411) || (-1 <= PropChroma <= 0)), \
           R8A + "The value for ChromaLocation in frame properties is " + string(PropChroma) + \
           R8B + " but only 0 (left) is supported for YUY2 & YUV411" + \
           R8B + " (however if the cplace argument is used to specify a left chroma" + \
           R8B + " placement the chroma location in frame properties will be ignored)" + R8B)
    assert((!Sub444 && !Sub000) || \
           (((cplace == "") || (cplace == "1")) && ((cplaced == "") || (cplaced == "1"))), \
           R8A + "cplace & cplaced must be unspecified or 1 (center/mpeg1/jpeg)" + \
           R8B + " unless the source has subsampled chroma" + R8B) \
    assert((Kc != "Point") || (cplace == "" == cplaced), \
           R8A + """When kernel_c="Point" cplace & cplaced cannot be used""" + R8B)
    assert(!separate || (cplace == "" == cplaced), \
           R8A + "When separate=true cplace & cplaced cannot be used" + R8B)
    assert(!fullc || (cplaced == "") || (cplaced == "1"), \
           R8A + "When fullc=true cplaced must be unspecified or 1 (center/mpeg1/jpeg)" + R8B)
    assert(((sCSP != "YUY2") && !Sub411) || \
           (((cplace == "") || (cplace == "0")) && ((cplaced == "") || (cplaced == "0"))), \
           R8A + "cplace and cplacd can only be uspecified or 0 (left/mpeg2) for YUY2 & YUV411" + R8B)

# -------------------------------------------------------------------------------

    cplace  = (cplace != "") ? cplace  : (PropChroma != -1) ? string(PropChroma) : ""
    cplaced = fullc ? "" : (cplaced != "") ? cplaced : cplace

    cps = Sub000 || Sub444 || separate || (Kc == "Point") ? "1" : \
          (sCSP == "YUY2") || Sub411 || (Sub422 && (cplace != "1")) ? "0" : (cplace != "") ? cplace : "0"
    cpd = fullc || Sub000 || Sub444 || separate || (Kc == "Point") ? "1" : \
          (sCSP == "YUY2") || Sub411 || (Sub422 && (cplaced != "1")) ? "0" : (cplaced != "") ? cplaced : "0"

    multi_l = Sub411 ? 0.375 : 0.25
    crop_l  = !fullc ? src_chroma_width  * multi_l / F_target_chroma_width : 0
    crop_t  = !fullc ? src_chroma_height * 0.25    / F_target_chroma_height : 0

    fix_cl = Sub444 || Sub000 ? 0.0 : \
             ((cps == "0") || (cps == "2") || (cps == "4")) && \
             ((cpd == "0") || (cpd == "2") || (cpd == "4")) ? multi_l - crop_l : \
             ((cps == "0") || (cps == "2") || (cps == "4")) && \
             ((cpd == "1") || (cpd == "3") || (cpd == "5")) ? multi_l : \
             ((cps == "1") || (cps == "3") || (cps == "5")) && \
             ((cpd == "0") || (cpd == "2") || (cpd == "4")) ? -crop_l : 0.0

    fix_ct = Sub444 || Sub000 ? 0.0 : \
             ((cps == "0") || (cps == "1")) && ((cpd == "2") || (cpd == "3")) ? -crop_t : \
             ((cps == "0") || (cps == "1")) && ((cpd == "4") || (cpd == "5")) ? crop_t : \
             ((cps == "2") || (cps == "3")) && ((cpd == "0") || (cpd == "1")) ? 0.25 : \
             ((cps == "4") || (cps == "5")) && ((cpd == "0") || (cpd == "1")) ? -0.25 : \
             ((cps == "2") || (cps == "3")) && ((cpd == "2") || (cpd == "3")) ? 0.25 - crop_t : \
             ((cps == "4") || (cps == "5")) && ((cpd == "4") || (cpd == "5")) ? -0.25 + crop_t : \
             ((cps == "2") || (cps == "3")) && ((cpd == "4") || (cpd == "5")) ? 0.25 + crop_t : \
             ((cps == "4") || (cps == "5")) && ((cpd == "2") || (cpd == "3")) ? -0.25 - crop_t : 0.0

    src_chroma_left = src_chroma_left + fix_cl
    src_chroma_top = src_chroma_top + fix_ct

# ===============================================================================
#            Create strings for resizing
# ===============================================================================

    whstr    = "(target_width, target_height"
    whstr_c  = "(target_chroma_width, target_chroma_height"

    srcstr   = ", src_left=src_left, src_top=src_top,  src_width=src_width, src_height=src_height"
    srcstr_c = ", src_left=src_chroma_left, src_top=src_chroma_top, " + \
               "src_width=src_chroma_width, src_height=src_chroma_height"

    resizeA  = resizer_Kc + whstr   + srcstr   + arg1_Kc + arg2_Kc + arg3_Kc + rstr_c + ")"
    resizeY  = resizer_Kl + whstr   + srcstr   + arg1_Kl + arg2_Kl + arg3_Kl + rstr   + ")"
    resizeC  = resizer_Kc + whstr_c + srcstr_c + arg1_Kc + arg2_Kc + arg3_Kc + rstr_c + ")"

    gaussY   = "GaussResize" + (IsResampleMT_Kl ? "MT" : "") + whstr   + srcstr   + ", p=100)"
    gaussC   = "GaussResize" + (IsResampleMT_Kc ? "MT" : "") + whstr_c + srcstr_c + ", p=100)"

    BlankY   = "BlankClip(width=target_width,  height=target_height,  color=$808080).KillAudio()"
    BlankC   = "BlankClip(width=target_chroma_width, height=target_chroma_height, color=$828282).KillAudio()"
    BlankRGB = "BlankClip(width=target_width,  height=target_height,  color=$000000).KillAudio()"

# ===============================================================================
#            Ringing repair
# ===============================================================================

    # Disable ringing repair for these kernels by default

    norepair_kl = (Kl == "Point") || (Kl == "Bilinear") || (Kl == "Gauss") || \
                  (Kl == "Hermite") || (Kl == "SinPow") || (Kl == "SincLin2") || \
                  (Kl == "UserDefined2") || (LeftStr(Kl, 9) == "SoftCubic") || unKnown_Kl

    norepair_kc = (Kc == "Point") || (Kc == "Bilinear") || (Kc == "Gauss") || \
                  (Kc == "Hermite") || (Kc == "SinPow") || (Kc == "SincLin2") || \
                  (Kc == "UserDefined2") || (LeftStr(Kc, 9) == "SoftCubic") || unKnown_Kc

    IsNoring   = defined(noring)
    IsNoring_c = defined(noring_c)
    noring     = default(noring, !norepair_kl && IsLumaU)
    noring_c   = default(noring_c, IsNoring && (resizer_Kl == resizer_Kc) ? noring : !norepair_kc && IsChroU)

    assert((IsBool(noring) || IsFloat(noring)) && (IsBool(noring_c) || IsFloat(noring_c)), \
          R8A + "noring must be bool, integer or float" + R8B)
    assert((IsBool(noring) || (0 <= noring <= 1)) && (IsBool(noring_c) || (0 <= noring_c <= 1)), \
          R8A + "When noring is float the allowed range is 0 to 1" + R8B)

# -------------------------------------------------------------------------------
#            Weight calculation of adaptive anti-ringing algorithm
# -------------------------------------------------------------------------------

    res_mul   = IsLumaU ? F_target_width * F_target_height / src_height / src_width : \
                src_width * src_height / F_target_height / F_target_width
    res_mul   = min(max(res_mul, 1), 2.25)
    nr_wght   = IsFloat(noring) ? noring : noring ? Spline(res_mul, 1, 0, 2.25, 1, 3.5, 0, true) : 0
    nr_wght   = min(max(nr_wght, 0), 1)

    res_mul_c = IsChroU ? F_target_chroma_width * target_chroma_height / src_chroma_height / src_chroma_width : \
                src_chroma_width * src_chroma_height / F_target_chroma_height / F_target_chroma_width
    res_mul_c = IsRGBSource && IsAlpha && alpha ? res_mul : min(max(res_mul_c, 1), 2.25)
    nr_wght_c = IsFloat(noring_c) ? noring_c : noring_c ? Spline(res_mul_c, 1, 0, 2.25, 1, 3.5, 0, true) : 0
    nr_wght_c = min(max(nr_wght_c, 0), 1)

# ===============================================================================
#            Control whether to process Y/U/V/A or R/G/B/A planes
# ===============================================================================

    chroma = default(chroma, true)
    At = alpha && IsAlpha && (IsRGBSource || (IsAvsHBD && !IsRGBSource))
    Yt = default(Y, true)
    Ut = default(U, chroma) && !Sub000
    Vt = default(V, chroma) && !Sub000
    Rt = default(Y, true)
    Gt = default(U, true)
    Bt = default(V, true)

    assert(IsAvsHBD || (!alpha || IsRGBSource), R8A + "AviSynth+ is required for YUV alpha support" + R8B)
    assert(chroma || !IsRGBSource, R8A + "chroma=false only applies to YUV sources" + R8B)
    assert(!alpha || ((sCSP != "YUY2") && !Sub411 && !Sub000), \
          R8A + "An alpha plane can't be added to " + pixtype + R8B)

# ===============================================================================
#            YUV Resize
# ===============================================================================

    show = default(show, false)
    info = show ? false : default(info, false)

    !IsRGBSource && (!show || info) ? Eval("""

    As = At ? ExtractA(source) : nop()
    Ys = !Sub000 ? (IsAvsHBD ? ExtractY(source) : ConvertToY8(source)) : source
    Us = !Sub000 ? (IsAvsHBD ? ExtractU(source) : UtoY8(source)) : nop()
    Vs = !Sub000 ? (IsAvsHBD ? ExtractV(source) : VtoY8(source)) : nop()

    Ao = At ? As.Eval(resizeY) : nop()
    Yo = Yt ? Ys.Eval(resizeY) : nop()
    Uo = Ut ? Us.Eval(resizeC) : nop()
    Vo = Vt ? Vs.Eval(resizeC) : nop()

    Ag = At && (nr_wght > 0) ? As.Eval(gaussY) : nop()
    Yg = Yt && (nr_wght > 0) ? Ys.Eval(gaussY) : nop()
    Ug = Ut && (nr_wght_c>0) ? Us.Eval(gaussC) : nop()
    Vg = Vt && (nr_wght_c>0) ? Vs.Eval(gaussC) : nop()

    Ar = At && (nr_wght > 0) ? Ao.Repair(Ag, 1, -1) : nop()
    Yr = Yt && (nr_wght > 0) ? Yo.Repair(Yg, 1, -1) : nop()
    Ur = Ut && (nr_wght_c>0) ? Uo.Repair(Ug, 1, -1) : nop()
    Vr = Vt && (nr_wght_c>0) ? Vo.Repair(Vg, 1, -1) : nop()

    Am = At ? ((nr_wght == 1) ? Ar : (nr_wght > 0) ? Ao.Merge(Ar,  nr_wght) : Ao) : nop()
    Ym = Yt ? ((nr_wght == 1) ? Yr : (nr_wght > 0) ? Yo.Merge(Yr,  nr_wght) : Yo) : Eval("Ys."+BlankY)
    Um = Ut ? ((nr_wght_c==1) ? Ur : (nr_wght_c>0) ? Uo.Merge(Ur, nr_wght_c): Uo) : Eval("Us."+BlankC)
    Vm = Vt ? ((nr_wght_c==1) ? Vr : (nr_wght_c>0) ? Vo.Merge(Vr, nr_wght_c): Vo) : Eval("Vs."+BlankC)

    cspace = fullc || Sub444 ? 444 : Sub422 ? 422 : 420

    ptype = !IsAvsHBD ? "" : At ? BuildPixelType(family="YUVA", bits=source_bits, chroma=cspace) : \
            BuildPixelType(family="YUV", bits=source_bits, chroma=cspace)

    output = Sub000 ? Ym : \
             !fullc && (sCSP == "YUY2") ? YtoUV(Um, Vm, Ym).ConvertToYUY2() : \
             !fullc && (sCSP == "YV16") ? YtoUV(Um, Vm, Ym).ConvertToYV16() : \
             !IsAvsHBD || Sub411 ? YtoUV(Um, Vm, Ym) : \
             At ? CombinePlanes(Ym, Um, Vm, Am, planes="YUVA", source_planes="YYYY", pixel_type=ptype) : \
             CombinePlanes(Ym, Um, Vm, planes="YUV", source_planes="YYY", pixel_type=ptype)

    output = !IsAvsHBD || !AddAlpha ? output : output.AddAlphaPlane()

    """, "Resize YUV Eval") : !show || info ? Eval("""

# ===============================================================================
#            RGB Resize
# ===============================================================================

    As = At ? (IsAvsHBD ? ExtractA(source) : ShowAlpha(source, "Y8")) : nop()
    Rs = IsAvsHBD ? ExtractR(source) : ShowRed(source,   "Y8")
    Gs = IsAvsHBD ? ExtractG(source) : ShowGreen(source, "Y8")
    Bs = IsAvsHBD ? ExtractB(source) : ShowBlue(source,  "Y8")

    Ao = At ? As.Eval(resizeA) : nop()
    Ro = Rt ? Rs.Eval(resizeY) : nop()
    Go = Gt ? Gs.Eval(resizeY) : nop()
    Bo = Bt ? Bs.Eval(resizeY) : nop()

    Ag = At && (nr_wght_c>0) ? As.Eval(gaussY) : nop()
    Rg = Rt && (nr_wght > 0) ? Rs.Eval(gaussY) : nop()
    Gg = Gt && (nr_wght > 0) ? Gs.Eval(gaussY) : nop()
    Bg = Bt && (nr_wght > 0) ? Bs.Eval(gaussY) : nop()

    Ar = At && (nr_wght_c>0) ? Ao.Repair(Ag, 1, -1) : nop()
    Rr = Rt && (nr_wght > 0) ? Ro.Repair(Rg, 1, -1) : nop()
    Gr = Gt && (nr_wght > 0) ? Go.Repair(Gg, 1, -1) : nop()
    Br = Bt && (nr_wght > 0) ? Bo.Repair(Bg, 1, -1) : nop()

    Am = At ? ((nr_wght_c==1) ? Ar : (nr_wght_c>0) ? Ao.Merge(Ar,nr_wght_c): Ao) : nop()
    Rm = Rt ? ((nr_wght == 1) ? Rr : (nr_wght > 0) ? Ro.Merge(Rr, nr_wght) : Ro) : Eval("Rs."+BlankRGB)
    Gm = Gt ? ((nr_wght == 1) ? Gr : (nr_wght > 0) ? Go.Merge(Gr, nr_wght) : Go) : Eval("Gs."+BlankRGB)
    Bm = Bt ? ((nr_wght == 1) ? Br : (nr_wght > 0) ? Bo.Merge(Br, nr_wght) : Bo) : Eval("Bs."+BlankRGB)

    cspace = AddAlpha && (sCSP == "RGB24") ? "RGB32" : !At && (sCSP == "RGB32") ? "RGB24" : \
             AddAlpha && (sCSP == "RGB48") ? "RGB64" : !At && (sCSP == "RGB64") ? "RGB48" : sCSP

    ptype = !IsAvsHBD || IsPackedRGB(source) ? "" : \
            IsAlpha ? BuildPixelType(family="RGB", bits=source_bits) : pixtype

    output = IsAvsHBD && !IsPackedRGB(source) ? (At ? \
             CombinePlanes(Rm, Gm, Bm, Am, planes="RGBA", source_planes="YYYY", pixel_type=pixtype) : \
             CombinePlanes(Rm, Gm, Bm, planes="RGB", source_planes="YYY", pixel_type=ptype)) : \
             At ? MergeARGB(Am, Rm, Gm, Bm) : MergeRGB(Rm, Gm, Bm, cspace)

    output = !IsAvsHBD || !AddAlpha || IsPackedRGB(source) ? output : output.AddAlphaPlane()

    """, "Resize RGB Eval") : nop()

# ===============================================================================
#            Display info
# ===============================================================================

    info || show ? Eval("""

    FRateNum = FrameRateNumerator(source)
    FRateDen = FrameRateDenominator(source)
    FRate    = float(FRateNum) / float(FRateDen)

    owstr  = R8_FS(target_width,  "(", ", ")
    ohstr  = R8_FS(target_height)
    owstrc = R8_FS(target_chroma_width, "(", ", ")
    ohstrc = R8_FS(target_chroma_height)
    srcl   = R8_FS(src_left,  ", src_left=",  ", src_top=")
    srct   = R8_FS(src_top)
    srcw   = R8_FS(src_width,  ", src_width=", ", src_height=")
    srch   = R8_FS(src_height)
    srclc  = R8_FS(src_chroma_left, ", src_left=",  ", src_top=")
    srctc  = R8_FS(src_chroma_top)
    srcwc  = R8_FS(src_chroma_width, ", src_width=", ", src_height=")
    srchc  = R8_FS(src_chroma_height)
    fix_cl = R8_FS(fix_cl,    keep=true)
    fix_ct = R8_FS(fix_ct,    keep=true)
    nwKl   = R8_FS(nr_wght,   keep=true)
    nwKc   = R8_FS(nr_wght_c, keep=true)

    owhstr   = owstr  + ohstr
    owhstrc  = owstrc + ohstrc
    src_str  = srcl   + srct  + srcw  + srch
    src_strc = srclc  + srctc + srcwc + srchc

    resizestrA = resizer_Kc + owhstr  + src_str  + arg1_Kc + arg2_Kc + arg3_Kc + rstr_c + ")"
    resizestrY = resizer_Kl + owhstr  + src_str  + arg1_Kl + arg2_Kl + arg3_Kl + rstr   + ")"
    resizestrC = resizer_Kc + owhstrc + src_strc + arg1_Kc + arg2_Kc + arg3_Kc + rstr_c + ")"

    No_nwKl = (!IsRGBSource && !Yt && (!IsAlpha || !alpha)) || (IsRGBSource && !Rt && !Gt && !Bt)
    No_nwKc = (!IsRGBSource && (Sub000 || (!Ut && !Vt))) || (IsRGBSource && (!alpha || !IsAlpha))

    LB1 = "\n\n\n\n\n\n\n\n"
    LB2 = "\n\n\n\n\n\n"
    LB3 = LB1 + LB2 + (IsRGBSource || Sub000 ? "\n\n\n" : LB2)
    LB4 = LB3 + "\n\n\n"

    PropDAR = IsPropSAR ? F_Source_Width * F_PropNum / F_PropDen / F_Source_Height : \
              F_Source_Width / F_Source_Height

    txtS1 = "\nSource Resolution    " + R8_FS(Source_Width) + R8_FS(Source_Height, " x ") + \
            "        Frame Props SAR    " + \
            (!IsPropSAR ? "None" : R8_FS(F_PropNum / F_PropDen, limit=5, keep=true) + \
            string(PropNum, "   (%.f:") + string(PropDen, "%.f)")) + \
            "\nSource Display Aspect Ratio    " + (!IsPropSAR || (PropSAR == 1) ? "" : \
            R8_FS(F_Source_Width * PropNum / PropDen, limit=2) + R8_FS(Source_Height, " x ", "    ")) + \
            R8_FS(PropDAR, limit=5) + R8_FTF(PropDAR) + \
            R8_FS(source_bits, "\n", " bit    ") + pixtype + R8_FS(FRate, "    ", " fps") + \
            ((abs(round(FRate) - FRate) < 0.00005) ? R8_FTF(round(FRate), 2) : \
            string(FRateNum, "  (%.0f / ") + string(FRateDen, "%.0f)"))

    C0 = "0  left"
    C1 = "1  center"
    C2 = "2  top_left"
    C3 = "3  top"
    C4 = "4  bottom_left"
    C5 = "5  bottom"

    txtS2 = "\n\n\n\n\n" + (Sub444 || Sub000 || separate || (Kc == "Point") ? \
            "No CPlace    " + (Sub000 ? "no chroma" : Sub444 ? "chroma not sub-sampled" : \
            separate ? "separate=true" : "kernel_c=" + chr(34) + resizer_kc + chr(34)) : \
            "Using CPlace       " + \
            (Sub422 && (sCSP != "YUY2") && (cplace == "2") ? "0  top_left as left" : \
            Sub422 && (sCSP != "YUY2") && (cplace == "4") ? "0  bottom_left as left" : \
            ((cplace != "") || (PropChroma != -1)) && (cps == "0") ? C0 : \
            (cps == "1") ? C1 : (cps == "2") ? C2 : (cps == "3") ? C3 : (cps == "4") ? C4 : \
            (cps == "5") ? C5 : "0  Assumed left") + \
            "           Source Frame Prop Chroma    " + \
            ((PropChroma == -1) ? "None" : (PropChroma == 0) ? C0 : (PropChroma == 1) ? C1 : \
            (PropChroma == 2) ? C2 : (PropChroma == 3) ? C3 : (PropChroma == 4) ? C4 : \
            (PropChroma == 5) ? C5 : (PropChroma == 6) ? "6  dv" : string(PropChroma)) + \
            "\nUsing CPlaceD    " + \
            (Sub422 && (sCSP != "YUY2") && (cplaced == "2") ? "0  top_left as left" : \
            Sub422 && (sCSP != "YUY2") && (cplaced == "4") ? "0  bottom_left as left" : \
            (cpd == "0") ? C0 : (cpd == "1") ? C1 : (cpd == "2") ? C2 : \
            (cpd == "3") ? C3 : (cpd == "4") ? C4 : (cpd == "5") ? C5 : C0) + \
            "           Writing Frame Prop Chroma    " + \
            (fullc ? "None  (output full chroma)" : \
            Sub411 ? "None  (output YUV411)" : (sCSP == "YUY2") ? "None  (output YUY2)" : \
            Sub422 && (cplaced == "2") ? C2 : Sub422 && (cplaced == "4") ? C4 : \
            (cpd == "0") ? C0 : (cpd == "1") ? C1 : (cpd == "2") ? C2 : (cpd == "3") ? C3 : \
            (cpd == "4") ? C4 : (cpd == "5") ? C5 : C0))

    textY = LB1 + (IsRGBSource && !Rt && !Gt && !Bt ? "RGB Planes Disabled" : \
            !IsRGBSource && !Yt ? "Y Plane Disabled" : \
            ((!IsRGBSource ? "Y Plane" : "RGB Planes") + "   (kernel)\n") + resizestrY)

    textA = LB1 + "\n\n\n" + (Sub000 ? "No Alpha Plane" : AddAlpha ? "Alpha Plane Added" : \
            !IsAlpha ? "No Alpha Plane" : !At ? "Alpha Plane Removed" : \
            "Alpha Plane   " + (!IsRGBSource ? "(kernel)\n" : "(kernel_c)\n") + \
            (!IsRGBSource ? resizestrY : resizestrA))

    textC = LB1 + LB2 + (IsRGBSource ? "No chroma shift correction required" : \
            Sub000 ? "No UV Planes" : !IsRGBSource && !Ut && !Vt ? "UV Planes Disabled" : \
            "UV Planes   (kernel_c)\n" + resizestrC + (IsRGBSource || Sub000 ? "" : \
            Sub444 || separate || (Kc == "Point") ? "\n\nNo chroma shift correction required" : \
            "\n\nExtra left UV crop to prevent chroma shift    " + fix_cl + \
            (Sub420 || (Sub422 && (sCSP != "YUY2")) ? \
            "\nExtra top UV crop to prevent chroma shift    " + fix_ct : "")))

    NoNR1   = IsNoring && ((IsBool(noring) && !noring) || (IsFloat(noring) && (noring == 0)))
    NoNR2   = !IsNoring && IsBool(noring) && !noring
    NoNR1_c = ((IsNoring && (resizer_Kl == resizer_Kc)) || IsNoring_c) && \
              ((IsBool(noring_c) && !noring_c) || (IsFloat(noring_c) && (noring_c == 0)))
    NoNR2_c = !IsNoring_c && IsBool(noring_c) && !noring_c && \
              (!IsNoring || (IsNoring && (resizer_Kl != resizer_Kc)))

    nr_Kl = No_nwKl ? "" : LB3 + (NoNR1 ? "Ringing repair disabled" : \
            NoNR2 ? "Ringing repair disabled by default " + \
            ((!norepair_kl && !IsLumaU ? "unless upscaling " : "") + "for " + resizer_Kl) : \
            "Weight of " + resizer_Kl + " ringing repair    " + nwKl) + \
            ("   " + (IsRGBSource ? "(RGB planes)" : \
            IsAlpha && alpha && Yt ? "(Alpha & Y planes)" : \
            IsAlpha && alpha ? "(Alpha plane)" : "(Y plane)"))

    nr_Kc = No_nwKc ? "" : LB3 + "\n" + \
            (NoNR1_c ? "Ringing repair disabled" : \
            NoNR2_c ? "Ringing repair disabled by default " + \
            ((!norepair_kc && !IsChroU ? "unless upscaling " : "") + "for " + resizer_Kc) : \
            "Weight of " + resizer_Kc + " ringing repair    " + nwKc) + \
            ("   " + (!IsRGBSource ? "(UV planes)" : "(alpha plane)"))

    aspect_s = LB4 + "Input Aspect    " + \
               (!IsAspect ? "\nNone" + (!separate ? "" : "    separate=true") : \
               (IsDAR ? "Using DAR" : IsSAR ? "Using SAR" : "Frame Props SAR") + \
               (keep ? "    keep=true" : "")) + (!IsAspect ? "" : \
               R8_FS(InDAR, "\nDAR    ", limit=5, keep=true) + R8_FTF(InDAR) + \
               R8_FS(InSAR, "\nSAR    ", limit=5, keep=true) + R8_FTF(InSAR))

    aspect_d = "\n\nOutput Aspect" + (!IsAspect ? "\nNone" : \
               R8_FS(OutDAR, "\nDAR    ", limit=5, keep=true) + R8_FTF(OutDAR) + \
               R8_FS(OutSAR, "\nSAR    ", limit=5, keep=true) + R8_FTF(OutSAR))

    sar_d = "\n\nWriting Frame Props SAR" + \
            (!IsAspect ? "\nNone" : R8_FS(OutNum, "\nSARNum    ") + R8_FS(OutDen, "\nSARNum    "))

    textR = "Resize8  2025-03-25"
    textX = aspect_s + aspect_d + sar_d
    scolor1 = !IsRGBSource ? $FFDAB9 : $F0FFFF
    scolor2 = !IsRGBSource ? $F0FFFF : $FFDAB9
    rsrlen = max(StrLen(resizestrY), max(StrLen(resizestrA), StrLen(resizestrC)))

    txtsize = min(show ? 16.55 : F_target_width * ((rsrlen < 100) ? 0.025 : (rsrlen < 160) ? 0.014 : 0.009), \
              show ? 16.55 : F_target_height * ((target_height < 300) ? 0.023 : (target_height < 800) ? 0.02375 : \
              (target_height < 1000) ? 0.023 : 0.021))

    posx = txtsize * 2
    posy = txtsize

    output = (!show ? output : BlankClip(width=1280, height=640, pixel_type=pixtype).KillAudio())\
             .subtitle(textR, size=txtsize, text_color=$F0FFFF, x=posx, y=posy, lsp=10)\
             .subtitle(txtS1, size=txtsize, text_color=$FFFFE0, x=posx, y=posy, lsp=10)\
             .subtitle(txtS2, size=txtsize, text_color=scolor1, x=posx, y=posy, lsp=10)\
             .subtitle(textY, size=txtsize, text_color=$F0FFFF, x=posx, y=posy, lsp=10)\
             .subtitle(textA, size=txtsize, text_color=scolor2, x=posx, y=posy, lsp=10)\
             .subtitle(textC, size=txtsize, text_color=$FFDAB9, x=posx, y=posy, lsp=10)\
             .subtitle(nr_Kl, size=txtsize, text_color=$F0FFFF, x=posx, y=posy, lsp=10)\
             .subtitle(nr_Kc, size=txtsize, text_color=$FFDAB9, x=posx, y=posy, lsp=10)\
             .subtitle(textX, size=txtsize, text_color=$FFFFE0, x=posx, y=posy, lsp=10)

    """, "Info Eval") : nop()

# ===============================================================================
#            Resize8 Output
# ===============================================================================

    IsAvsProps && !show ? Eval("""

    output = fullc || Sub444 || Sub411 || Sub000 || (sCSP == "YUY2") || (Kc == "Point") || separate ? \
             ((PropChroma != -1) ? output.propDelete("_ChromaLocation") : output) : \
             Sub422 && (cplaced == "2") ? output.propSet("_ChromaLocation", 2) : \
             Sub422 && (cplaced == "4") ? output.propSet("_ChromaLocation", 4) : \
             (cpd == "0") ? output.propSet("_ChromaLocation", 0) : \
             (cpd == "1") ? output.propSet("_ChromaLocation", 1) : \
             (cpd == "2") ? output.propSet("_ChromaLocation", 2) : \
             (cpd == "3") ? output.propSet("_ChromaLocation", 3) : \
             (cpd == "4") ? output.propSet("_ChromaLocation", 4) : \
             (cpd == "5") ? output.propSet("_ChromaLocation", 5) : output

    output = !IsAspect ? output : output.propSet("_SARNum", OutNum).propSet("_SARDen", OutDen)

    """, "Write Frame Props Eval") : nop()

# -------------------------------------------------------------------------------

    return !HasAudio(audio) ? output : AudioDub(output, audio) }

# ===============================================================================
# ===============================================================================
#            Float To Fraction
# ===============================================================================
# ===============================================================================

function R8_FTF(float Decimal, int "Out") {
    Out = default(Out, 1)
    Num = (Decimal == 0) ? "0" : string(ContinuedNumerator(Decimal, Limit=10000))
    Den = (Decimal == 0) ? "1" : string(ContinuedDenominator(Decimal, Limit=10000))
    return ((Out == 1) ? " " : "") + "  (" + Num + ((Out == 1) ? ":" : " / ") + Den + ")" }

# ===============================================================================
# ===============================================================================
#            Format String
# ===============================================================================
# ===============================================================================

function R8_FS(float f, string "text1", string "text2", int "limit", bool "keep") {

    text1 = default(text1, "")
    text2 = default(text2, "")
    limit = abs(default(limit, 4))
    keep  = default(keep, false)

    s = Eval("""string(f, "%.""" + string(limit) + """f")""")
    s = (limit == 0) ? s : R8_RemoveTrailingZeros(s)
    slength = StrLen(s)
    NewStr = (limit == 0) || (FindStr(s, ".") < slength) ? s : !Keep ? LeftStr(s, slength - 1) : s + "0"
    NewStr = (value(NewStr) == 0) && (FindStr(NewStr, "-") > 0) ? MidStr(NewStr, 2) : NewStr

    return (text1 == "" == text2) ? NewStr : text1 + NewStr + text2 }

# -------------------------------------------------------------------------------

function R8_RemoveTrailingZeros(string s) {
    zeropos = FindStr(s + "x", "0x")
    return (zeropos == 0) ? s : R8_RemoveTrailingZeros(LeftStr(s, zeropos - 1)) }

# ===============================================================================
# ===============================================================================
#            Resize8 Defaults
# ===============================================================================
# ===============================================================================
#
#   The functions below cannot be commented out.
#
# -------------------------------------------------------------------------------
#
#   To change the default resizers, modify the strings in the appropriate function. For example:
#
#   function R8_Luma_UpScale() { return "BicubicResize" }
#
#   None of the resizers below will be applied when a resizer is specified via the Resize8 kernel
#   argument as it's used for upscaling and downscaling both luma and chroma, unless kernel_c is
#   used to specify a chroma resizer.
#
#   If a chroma resizer is specified via the kernel_c argument, it's used for chroma upscaling and
#   downscaling and the chroma resizers below will be ignored.
#
# -------------------------------------------------------------------------------

function R8_Luma_UpScale()     { return "" }
function R8_Luma_DownScale()   { return "" }
function R8_Chroma_UpScale()   { return "" }
function R8_Chroma_DownScale() { return "" }

# -------------------------------------------------------------------------------
#
#   Default strings for the resizing kernels can be added to the following functions. For example:
#
#   function R8_Luma_UpScale_rstr() { return "b=0.5, c=0.25" }
#
#   The four strings below are ignored when a kernel is specified via the Resize8 kernel argument.
#   When kernel_c is used to specify a chroma resizer, the two chroma strings are ignored.
#
#   The four strings below are also ignored when a string is specified via the "rstr" argument,
#   and rstr="" will clear them (change all four to an empty string).
#
#   The "rstr_c" argument replaces the two chroma strings below, and rstr_c="" will clear them.
#
# -------------------------------------------------------------------------------

function R8_Luma_UpScale_rstr()     { return "" }
function R8_Luma_DownScale_rstr()   { return "" }
function R8_Chroma_UpScale_rstr()   { return "" }
function R8_Chroma_DownScale_rstr() { return "" }

# ===============================================================================
# ===============================================================================
