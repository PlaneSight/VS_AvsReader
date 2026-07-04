# ===============================================================================
# ===============================================================================
#            FrostyBorders 2025-04-14
# ===============================================================================
# ===============================================================================

function FrostyBorders(clip Source, \
int "OutWidth", int "OutHeight", float "CL", float "CT", float "CR", float "CB", \
val "CropDAR", float "TCRatio", val "InDAR", val "InSAR", int "Mod", \
bool "Frosty", bool "Frosty2", int "FrostyStatic", \
int "Clone", bool "FrostyGradient", bool "FrostyPlain", bool "Plain", \
val "BColor", int "BDivider", val "BDColor", int "Feather", \
float "Bright", float "Cont", float "Sat", float "Gamma", \
float "Blend", float "Blur", float "VBlur", int "Iterations", float "Threads", \
int "GPlugin", float "Texture", float "TextureC", bool "StaticT", \
int "TSoft", bool "TSoftx2", string "Resizer", string "RStr", bool "Info") {

# ===============================================================================

AvsStr = LCase(VersionString())
IsAvsPlus = (FindStr(AvsStr, "avisynth+") > 0)
IsAvsNeo = (FindStr(AvsStr, "avisynth neo") > 0)
NumA = IsAvsPlus || IsAvsNeo ? FindStr(AvsStr, "(r") + 2 : 0
NumB = IsAvsPlus || IsAvsNeo ? FindStr(AvsStr, ",") : 0
NumC = (NumB > NumA) ? NumB - NumA : undefined()
AvsBuildNum = (NumA > 2) ? int(value(MidStr(AvsStr, NumA, NumC))) : 0
IsAvsHBD = (AvsBuildNum > 2294)
IsAvsProps = (AvsBuildNum >= 3593)

Source_Width = width(Source)
F_Source_Width = float(Source_Width)
Source_Height = height(Source)
F_Source_Height = float(Source_Height)

FB = " FrostyBorders " + chr(10)
Assert(HasVideo(Source) && (Source_Width > 48) && (Source_Height > 48), \
FB + " No video found or the source width or height is too small " + chr(10))

IsYUY2Source = IsYUY2(Source)
Source = IsYUY2Source ? ConvertToYV16(Source) : Source

PropRange = IsAvsProps ? propGetAny(Source, "_ColorRange") : undefined()
PropRange = defined(PropRange) && IsInt(PropRange) && (0 <= PropRange <= 1) ? PropRange : -1
Total_Frames = FrameCount(Source)
Last_Frame = Total_Frames - 1
Source_Bits = IsAvsHBD ? BitsPerComponent(Source) : 8
Scale = (Source_Bits == 8) ? 1 : (Source_Bits != 32) ? pow(2, Source_Bits - 8) : 1.0 / 256.0
Source_Audio = !HasAudio(Source) ? Source : Source.KillVideo()
Source = Source.KillAudio()
Color_Format = PixelType(Source)
WidthMod = IsYV411(Source) ? 4 : \
(IsAvsHBD && (Is420(Source) || Is422(Source))) || IsYV12(Source) || IsYV16(Source) ? 2 : 1
HeightMod = (IsAvsHBD && Is420(Source)) || IsYV12(Source) ? 2 : 1
F_WidthMod = float(WidthMod)
F_HeightMod = float(HeightMod)

OutWidth = default(OutWidth, 0)
OutHeight = default(OutHeight, 0)
F_OutWidth = float(OutWidth)
F_OutHeight = float(OutHeight)
CL = default(CL, 0.0)
CT = default(CT, 0.0)
CR = default(CR, 0.0)
CB = default(CB, 0.0)
CR = (CR == 0) ? 0.0 : (CR < 0) ? -CR : Source_Width - CL - CR
CB = (CB == 0) ? 0.0 : (CB < 0) ? -CB : Source_Height - CT - CB
CRTest = ((CL + CR) < Source_Width)
CBTest = ((CT + CB) < Source_Height)
CropDAR = default(CropDAR, 0.0)
TCRatio = default(TCRatio, 0.5)
IsInDAR = defined(InDAR)
IsInSAR = defined(InSAR)
InDAR = default(InDAR, 0.0)
InSAR = default(InSAR, 0.0)
IsMod = defined(Mod)
Mod = default(Mod, 2 * WidthMod)
HMod = IsMod ? Mod : 2 * HeightMod
F_Mod = float(Mod)
F_HMod = float(HMod)
Info = default(Info, false)

# ===============================================================================
#            Insist
# ===============================================================================

Assert(!IsRGB(Source), FB + " RGB video is not supported " + chr(10))
Assert((OutWidth == 0) || (WidthMod != 2) || ((OutWidth % 2) == 0), \
FB + " " + Color_Format + " requires a Mod2 OutWidth " + chr(10))
Assert((OutWidth == 0) || (WidthMod != 4) || ((OutWidth % 4) == 0), \
FB + " " + Color_Format + " requires a Mod4 OutWidth " + chr(10))
Assert((OutHeight == 0) || (HeightMod != 2) || ((OutHeight % 2) == 0), \
FB + " " + Color_Format + " requires a Mod4 OutHeight " + chr(10))
Assert(CRTest, FB + " Left plus right cropping must be less than the source width " + chr(10))
Assert(CBTest, FB + " Top plus bottom cropping must be less than the source height " + chr(10))
Assert((CL >= 0) && (CT >= 0), FB + " CL & CT must be greater than, or equal to zero " + chr(10))
Assert(IsFloat(CropDAR) && !IsInt(CropDAR) && (CropDAR >= 0), \
FB + " CropDAR must be a floating point number greater than or equal to zero " + chr(10) + \
" (16.0/9.0 or 1.7778 etc)" + chr(10))
Assert((0.0 <= TCRatio <= 1.0), FB + " The valid range for TCRatio is 0 to 1.0 " + chr(10))
Assert(IsFloat(InDAR) && !IsInt(InDAR) && (InDAR >= 0), \
FB + " InDAR must be a floating point number greater than or equal to zero " + chr(10) + \
" (16.0/9.0 or 1.7778 etc)" + chr(10))
Assert(IsFloat(InSAR) && !IsInt(InSAR) && (InSAR >= 0), \
FB + " InSAR must be a floating point number greater than or equal to zero " + chr(10) + \
" (64.0/45.0 or 1.4222 etc)" + chr(10))
Assert((InDAR == 0) || (InSAR == 0), FB + " InDAR & InSAR can't be specified together " + chr(10))
Assert((Mod == 1) || (Mod == 2) || (Mod == 4) || (Mod == 8) || (Mod == 16), \
FB + " Mod must be 1, 2, 4, 8 or 16 " + chr(10))
Assert(((Mod % 2) == 0) || (WidthMod != 2), \
FB + " " + Color_Format + " requires a minimum width Mod of 2 " + chr(10))
Assert(((Mod % 4) == 0) || (WidthMod != 4), FB + \
FB + " " + Color_Format + " requires a minimum width Mod of 4 " + chr(10))
Assert(((HMod % 2) == 0) || (HeightMod != 2), FB + \
FB + " " + Color_Format + " requires a minimum height Mod of 2 " + chr(10))

# ===============================================================================
#            Configure Resizer
# ===============================================================================

IsResizer = defined(Resizer)
Resizer = default(Resizer, FB_Default_Resizer())
Resizer = (Resizer != "") ? Resizer : "Spline36"

IsResizeMTAppended = (RightStr(Resizer, 8) == "ResizeMT") || (RightStr(Resizer, 8) == "MTResize")
IsMTAppended = (RightStr(Resizer, 2) == "MT")
IsResizeMT = IsResizeMTAppended || IsMTAppended
IsResizeAppended = (RightStr(Resizer, 6) == "Resize")

Kernel = IsResizeMTAppended ? LeftStr(Resizer, StrLen(Resizer) - 8) : \
IsMTAppended ? LeftStr(Resizer, StrLen(Resizer) - 2) : \
IsResizeAppended ? LeftStr(Resizer, StrLen(Resizer) - 6) : Resizer

IsAVSKernel = \
(Kernel == "Bicubic") || (Kernel == "Bilinear") || (Kernel == "Blackman") || (Kernel == "Gauss") || \
(Kernel == "Lanczos") || (Kernel == "Lanczos3") || (Kernel == "Lanczos4") || (Kernel == "Point") || \
(Kernel == "Spline16") || (Kernel == "Spline36") || (Kernel == "Spline64") || (Kernel == "Sinc")

Resizer = !IsAVSKernel ? Resizer : (Kernel == "Lanczos3") ? "Lanczos" : Kernel
Resizer = !IsAVSKernel ? Resizer : Resizer + (IsResizeMT ? "ResizeMT" : "Resize")

RTaps = (Kernel == "Lanczos3") ? ", taps=3" : ""
RStr = default(RStr, IsResizer ? "" : FB_Default_RStr())
ResStr = (RStr == "") ? "" : ", " + RStr

# ===============================================================================
#            Aspect & Dimensions
# ===============================================================================

PropsNum = IsAvsProps ? Source.propGetAny("_SARNum") : undefined()
PropsDen = IsAvsProps ? Source.propGetAny("_SARDen") : undefined()
PropsNum = defined(PropsNum) && IsInt(PropsNum) ? PropsNum : 0
PropsDen = defined(PropsDen) && IsInt(PropsDen) ? PropsDen : 0
PropsSAR = (PropsNum > 0 < PropsDen) && !IsInDAR && !IsInSAR ? float(PropsNum) / float(PropsDen) : 0
IsAnamorphicInput = ((InDAR > 0) && (InDAR != F_Source_Width / F_Source_Height)) || \
((InSAR > 0) && (InSAR != 1)) || ((PropsSAR > 0) && (PropsSAR != 1))
IsBorders = (OutWidth > 0) && (OutHeight > 0)

Cropped_Source_Width = Source_Width - CL - CR
Cropped_Source_Height = Source_Height - CT - CB
F_Cropped_Source_Width = float(Cropped_Source_Width)
F_Cropped_Source_Height = float(Cropped_Source_Height)

Cropped_Source_DAR = !IsAnamorphicInput ? F_Cropped_Source_Width / F_Cropped_Source_Height : \
(InDAR > 0) ? F_Cropped_Source_Width * F_Source_Height * InDAR / F_Cropped_Source_Height / F_Source_Width : \
F_Cropped_Source_Width * ((InSAR > 0) ? InSAR : PropsSAR) / F_Cropped_Source_Height

F_Resized_Cropped_Width = !IsAnamorphicInput ? F_Cropped_Source_Width : \
(InDAR > 0) ? F_Cropped_Source_Width * F_Source_Height * InDAR / F_Source_Width : \
F_Cropped_Source_Width * ((InSAR > 0) ? InSAR : PropsSAR)

Mod_Cropped_Resized_Width = ((round(F_Resized_Cropped_Width) % WidthMod) == 0) && \
FB_IsEqual(F_Resized_Cropped_Width, round(F_Resized_Cropped_Width)) ? \
round(F_Resized_Cropped_Width) : floor(F_Resized_Cropped_Width / F_Mod) * Mod
F_Mod_Cropped_Resized_Width = float(Mod_Cropped_Resized_Width)

Mod_Cropped_Height = floor(F_Cropped_Source_Height / F_HMod) * HMod

Resizing_Width = (OutWidth > 0) ? OutWidth : Mod_Cropped_Resized_Width
Resizing_Height = (OutHeight > 0) ? OutHeight : Mod_Cropped_Height
F_Resizing_Width = float(Resizing_Width)
F_Resizing_Height = float(Resizing_Height)

Resizing_DAR = (CropDAR > 0) ? CropDAR : Cropped_Source_DAR

Height_From_Width = IsBorders ? (Resizing_DAR >= (F_Resizing_Width / F_Resizing_Height)) : \
(OutWidth > 0) ? true : (OutHeight > 0) ? false : true

# ===============================================================================
#            Height Calculated From Width
# ===============================================================================

Height_From_Width ? Eval("""

F_Aspect_Height = F_Resizing_Width / Resizing_DAR
F_Aspect_Height = FB_IsEqual(F_Aspect_Height, round(F_Aspect_Height)) && \
((round(F_Aspect_Height) % HeightMod) == 0) ? float(round(F_Aspect_Height)) : F_Aspect_Height

F_Resizing_Height = (fmod(F_Aspect_Height, F_HMod) > (F_HMod / 2.0)) ? \
F_Aspect_Height + F_HMod - fmod(F_Aspect_Height, F_HMod) : F_Aspect_Height - fmod(F_Aspect_Height, F_HMod)
Resizing_Height = round(F_Resizing_Height)

""", "Height From Width Resizing Eval") : Eval("""

# ===============================================================================
#            Width Calculated From Height
# ===============================================================================

F_Aspect_Width = F_Resizing_Height * Resizing_DAR
F_Aspect_Width = FB_IsEqual(F_Aspect_Width, round(F_Aspect_Width)) && \
((round(F_Aspect_Width) % WidthMod) == 0) ? float(round(F_Aspect_Width)) : F_Aspect_Width

F_Resizing_Width = (fmod(F_Aspect_Width, F_Mod) > (F_Mod / 2.0)) ? \
F_Aspect_Width + F_Mod - fmod(F_Aspect_Width, F_Mod) : F_Aspect_Width - fmod(F_Aspect_Width, F_Mod)
Resizing_Width = round(F_Resizing_Width)

""", "Width From Height Resizing Eval")

# ===============================================================================
#            Cropping & Resizing
# ===============================================================================

TCRatio = (CropDAR == 0) || (CropDAR <= Cropped_Source_DAR) ? 0.5 : TCRatio
Cropping_DAR = F_Resizing_Width / F_Resizing_Height

F_Extra_Width_Crop = \
FB_IsEqual(Cropping_DAR, Cropped_Source_DAR) || (Cropping_DAR > Cropped_Source_DAR) ? 0.0 : \
max(0.0, !IsAnamorphicInput ? \
F_Cropped_Source_Width - (F_Cropped_Source_Height * F_Resizing_Width / F_Resizing_Height) : \
(InDAR > 0) ? F_Cropped_Source_Width - \
(F_Cropped_Source_Height * F_Resizing_Width * F_Source_Width / InDAR / F_Resizing_Height / F_Source_Height) : \
F_Cropped_Source_Width - \
(F_Cropped_Source_Height * F_Resizing_Width / F_Resizing_Height / ((InSAR > 0) ? InSAR : PropsSAR)))

F_Extra_Height_Crop = \
FB_IsEqual(Cropping_DAR, Cropped_Source_DAR) || (Cropping_DAR < Cropped_Source_DAR) ? 0.0 : \
max(0.0, !IsAnamorphicInput ? \
F_Cropped_Source_Height - (F_Cropped_Source_Width * F_Resizing_Height / F_Resizing_Width) : \
(InDAR > 0) ? F_Cropped_Source_Height - \
(F_Cropped_Source_Width * F_Resizing_Height * F_Source_Height * InDAR / F_Resizing_Width / F_Source_Width) : \
F_Cropped_Source_Height - \
(F_Cropped_Source_Width * F_Resizing_Height * ((InSAR > 0) ? InSAR : PropsSAR) / F_Resizing_Width))

F_Extra_Crop_LR = max(0.0, F_Extra_Width_Crop / 2.0)
F_Extra_Crop_LR = \
FB_IsEqual(F_Extra_Crop_LR, round(F_Extra_Crop_LR)) ? float(round(F_Extra_Crop_LR)) : F_Extra_Crop_LR

F_Extra_Crop_T = max(0.0, (TCRatio == 0.5) ? F_Extra_Height_Crop / 2.0 : F_Extra_Height_Crop * TCRatio)
F_Extra_Crop_T = \
FB_IsEqual(F_Extra_Crop_T, round(F_Extra_Crop_T)) ? float(round(F_Extra_Crop_T)) : F_Extra_Crop_T

F_Extra_Crop_B = max(0.0, (TCRatio == 0.5) ? F_Extra_Height_Crop / 2.0 : F_Extra_Height_Crop - F_Extra_Crop_T)
F_Extra_Crop_B = \
FB_IsEqual(F_Extra_Crop_B, round(F_Extra_Crop_B)) ? float(round(F_Extra_Crop_B)) : F_Extra_Crop_B

CCL = round(max(0, CL + F_Extra_Crop_LR - fmod((CL + F_Extra_Crop_LR), F_WidthMod)))
CCR = round(max(0, CR + F_Extra_Crop_LR - fmod((CR + F_Extra_Crop_LR), F_WidthMod)))
CCT = round(max(0, CT + F_Extra_Crop_T - fmod((CT + F_Extra_Crop_T), F_HeightMod)))
CCB = round(max(0, CB + F_Extra_Crop_B - fmod((CB + F_Extra_Crop_B), F_HeightMod)))
RCL = max(0.0, CL + F_Extra_Crop_LR - CCL)
RCR = max(0.0, CR + F_Extra_Crop_LR - CCR)
RCT = max(0.0, CT + F_Extra_Crop_T - CCT)
RCB = max(0.0, CB + F_Extra_Crop_B - CCB)

F_Cropped_Width = F_Source_Width - CCL - CCR - RCL - RCR
F_Cropped_Height = F_Source_Height - CCT - CCB - RCT - RCB

Cropped = (0 == CCL == CCT == CCR == CCB) ? Source : Source.crop(CCL, CCT, -CCR, -CCB)

Resized = Cropped.Eval(Resizer + "(Resizing_Width, Resizing_Height, \
src_left=RCL, src_top=RCT, src_width=F_Cropped_Width, src_height=F_Cropped_Height" + RTaps + ResStr + ")")

# ===============================================================================
#            Border Size
# ===============================================================================

Additional_Width = OutWidth - Resizing_Width
F_WidthSplit = float(Additional_Width) / 2.0

BL = round(max(0, ((Additional_Width % (WidthMod * 2)) == 0) ? Additional_Width / 2 : \
(CL > CR) ? min(Additional_Width, F_WidthSplit + F_WidthMod - fmod(F_WidthSplit, F_WidthMod)) : \
F_WidthSplit - fmod(F_WidthSplit, F_WidthMod)))

BR = Additional_Width - BL

Additional_Height = OutHeight - Resizing_Height
F_HeightSplit = float(Additional_Height) / 2.0

BT = round(max(0, ((Additional_Height % (HeightMod * 2)) == 0) ? Additional_Height / 2 : \
(CT > CB) ? min(Additional_Height, F_HeightSplit + F_HeightMod - fmod(F_HeightSplit, F_HeightMod)) : \
F_HeightSplit - fmod(F_HeightSplit, F_HeightMod)))

BB = Additional_Height - BT

# ===============================================================================
#            Defaults
# ===============================================================================

IsPillarBox = ((BL > 0) || (BR > 0)) && IsBorders
IsLetterBox = ((BT > 0) || (BB > 0)) && IsBorders
IsBorders = IsPillarBox || IsLetterBox

Frosty = default(Frosty, true)
Frosty2 = default(Frosty2, false)
IsFrostyStatic = defined(FrostyStatic)
FrostyStatic = default(FrostyStatic, 0)
Clone = default(Clone, 0)
Clone1 = (Clone == 1)
Clone2 = (Clone == 2)
Clone3 = (Clone == 3)
FrostyGradient = default(FrostyGradient, false)
FrostyPlain = default(FrostyPlain, false)
Plain = default(Plain, false)
BDivider = default(BDivider, 0)
BDColor = default(BDColor, $000000)
Feather = default(Feather, 0)
IsBlur = defined(Blur)
IsVBlur = defined(VBlur)
Iterations = default(Iterations, 3)
GPlugin = default(GPlugin, 1)
StaticT = default(StaticT, true)
DynamicT = !StaticT

BorderMin = Frosty || (Frosty && Frosty2) || IsFrostyStatic || FrostyGradient ? \
(IsPillarBox && (WidthMod == 4) ? 32 : 16) : \
Clone1 || Clone2 || Clone3 ? (IsPillarBox && (WidthMod == 4) ? 8 : 4) : IsPillarBox ? WidthMod : HeightMod

SizeTest = (IsPillarBox && (BL >= BorderMin <= BR)) || (IsLetterBox && (BT >= BorderMin <= BB))

IsBDivider = \
(BDivider > 0) && ((IsPillarBox && (BL > BorderMin < BR)) || (IsLetterBox && (BT > BorderMin < BB)))
IsFeather = \
(Feather > 0) && ((IsPillarBox && (BL >= WidthMod <= BR)) || (IsLetterBox && (BT >= HeightMod <= BB)))

FrostyPlain = FrostyPlain && !Plain
FrostyGradient = FrostyGradient && !FrostyPlain && !Plain && SizeTest
Clone1 = Clone1 || (Clone2 && !IsFeather) && !FrostyGradient && !FrostyPlain && !Plain && SizeTest
Clone2 = Clone2 && IsFeather && !FrostyGradient && !FrostyPlain && !Plain && SizeTest
Clone3 = Clone3 && !FrostyGradient && !FrostyPlain && !Plain && SizeTest
IsClone = Clone1 || Clone2 || Clone3
IsFrosty = (Frosty || Frosty2 || IsFrostyStatic) && \
!FrostyGradient && !FrostyPlain && !Plain && !IsClone && SizeTest
Plain = Plain || (!FrostyGradient && !FrostyPlain && !IsClone && !IsFrosty)
IsPlain = Plain || FrostyPlain

Ratio = !IsBorders ? 1.0 : (IsPillarBox ? F_Resizing_Width : F_OutWidth) * \
(IsPillarBox ? F_OutHeight : F_Resizing_Height) / F_Source_Width / F_Source_Height

BordVid = IsClone || IsAnamorphicInput || (Ratio < 1) ? Resized : Cropped
BordVid_Width = width(BordVid)
BordVid_Height = height(BordVid)
F_BordVid_Width = float(BordVid_Width)
F_BordVid_Height = float(BordVid_Height)
F_VidSize = IsPillarBox ? F_BordVid_Height : F_BordVid_Width

Feather = !IsFeather ? 0 : IsPillarBox ? \
min((Feather < WidthMod) ? WidthMod : Feather, floor(F_Resizing_Width / 6.0 / F_WidthMod) * WidthMod) : \
min((Feather < HeightMod) ? HeightMod : Feather, floor(F_Resizing_Height / 6.0 / F_HeightMod) * HeightMod)

BColor = default(BColor, FrostyGradient || FrostyPlain ? $008080 : $000000)

Bright = default(Bright, IsPillarBox || IsFrosty || FrostyGradient || Plain ? 0.0 : -20.0)
Cont = default(Cont, IsPillarBox || IsFrosty || FrostyGradient || Plain ? 1.0 : 0.66)
Sat = default(Sat, FrostyGradient || Plain ? 1.0 : IsPillarBox ? 0.85 : 0.66)
Gamma = default(Gamma, IsFrosty && IsLetterBox ? 0.5 : 1.0)

Blend = default(Blend, IsFrostyStatic ? 0.5 : IsFrosty ? (IsPillarBox ? 0.2 : 0.1) : 0.0)

Blur = IsBlur ? ((Blur >= 0) ? Blur : -Blur * F_VidSize / 720.0) : \
Clone1 || Clone2 ? F_VidSize / 75.0 : Clone3 ? F_VidSize / 25.0 : 0
VBlur = IsVBlur ? ((VBlur >= 0) ? VBlur : -VBlur * F_VidSize / 720.0) : IsBlur || IsClone ? Blur : 0

Texture = default(Texture, IsClone ? 2.5 : !Plain ? 5.0 : 0.0)
Texture = (Texture == 0) || (GPlugin == 0) ? 0 : (GPlugin == 1) ? Texture : round(Texture * 64.0)
TextureC = default(TextureC, 0.0)
TextureC = (TextureC == 0) || (GPlugin == 0) ? 0 : (GPlugin == 1) ? TextureC : round(TextureC * 64.0)

TSoft = default(TSoft, IsFrostyStatic ? 0 : IsFrosty ? 5 : Clone3 ? 1 : 0)
IsTSoft = (TSoft > 0) && (IsFrosty || IsClone)
TSoftx2 = IsTSoft && default(TSoftx2, false)

# ===============================================================================
#            Insist
# ===============================================================================

Assert((0 <= FrostyStatic <= Last_Frame), \
FB + " The valid range for FrostyStatic is from zero to the final frame number " + \
string(Last_Frame, "(0 to %.0f) ") + chr(10))
Assert(!IsPillarBox || (BDivider <= 0) || (WidthMod != 2) || ((BDivider % 2) == 0), \
FB + " " + Color_Format + " requires a Mod2 BDivider for pillarbox borders " + chr(10))
Assert(!IsPillarBox || (BDivider <= 0) || (WidthMod != 4) || ((BDivider % 4) == 0), \
FB + " " + Color_Format + " requires a Mod4 BDivider for pillarbox borders " + chr(10))
Assert(!IsLetterBox || (BDivider <= 0) || (HeightMod != 2) || ((BDivider % 2) == 0), \
FB + " " + Color_Format + " requires a Mod2 BDivider for letterbox borders " + chr(10))
Assert((Feather == 0) || (BDivider == 0), \
FB + " Feather and BDivider can't be used together (one must equal zero) " + chr(10))
Assert((Feather == 0) || !FrostyGradient, \
FB + " Feather can't be greater than zero when FrostyGradient=true " + chr(10))
Assert((0 <= GPlugin <= 2), FB + " The valid choices for GPlugin are " + chr(10) + \
" 0 (no added grain), 1 (AddGrainC) or 2 (neo_f3kdb) " + chr(10))
Assert((0 <= Clone <= 3), FB + " Clone can only be 0 (disabled), 1, 2 or 3 " + chr(10))
Assert((-255 <= Bright <= 255), FB + " The valid range for Bright is -255 thru 255 " + chr(10))
Assert((0 <= Cont <= 10), FB + " The valid range for Cont is 0.0 thru 10.0 " + chr(10))
Assert((0 <= Sat <= 10), FB + " The valid range for Sat is 0.0 thru 10.0 " + chr(10))
Assert((0 <= Blend <= 1), FB + " The valid range for Blend is 0.0 to 1.0 " + chr(10))
Assert((Texture >= 0 <= TextureC), FB + " Texture and TextureC cannot be negative " + chr(10))
Assert((0 <= TSoft <= 7), FB + " The valid range for TSoft is 0 to 7 " + chr(10))

# ===============================================================================
#            PillarBox & LetterBox Strings
# ===============================================================================

IsBorders ? Eval("""

FastBlurStr = (IsPlain && !IsFeather) || FrostyGradient || (Iterations <= 0) ? "" : \
".FastBlur(Blur, y_blur=VBlur, iterations=Iterations, dither=true, threads=Threads)"

GammaStr = (Gamma == 1) ? "" : \
(PropRange != 0) ? ".Levels(16*Scale, Gamma, 235*Scale, 16*Scale, 235*Scale, coring=false)" : \
".Levels(0, Gamma, 255*Scale, 0, 255*Scale, coring=false)"

GrainStr = (Texture == 0 == TextureC) || (GPlugin == 0) ? "" : \
(GPlugin == 1) ? ".AddGrainC(var=Texture, uvar=TextureC, constant=StaticT)" : \
".neo_f3kdb(grainY=Texture, grainC=TextureC, dither_algo=1, " + \
"dynamic_grain=DynamicT, output_depth=Source_Bits)"

LoopStr = ".Trim(1, 1).Loop(Total_Frames)"
SLoopStr = IsFrostyStatic ? ".Trim(FrostyStatic, end=FrostyStatic).Loop(Total_Frames)" : ""
TSoftStr = IsTSoft ? ".TemporalSoften(TSoft, 255, 255, 20, 2)" + \
(TSoftx2 ? ".TemporalSoften(TSoft, 255, 255, 20, 2)" : "") : ""
TweakStr = (Bright != 0) || (Cont != 1) || (Sat != 1) ? \
".Tweak(bright=Bright, cont=Cont, sat=Sat, realcalc=true, dither=true)" : ""

""", "PillarBox & LetterBox Strings Eval") : nop()

# ===============================================================================
#            PillarBox Borders
# ===============================================================================

IsPillarBox ? Eval("""

BL = IsBDivider ? BL - BDivider : BL
BR = IsBDivider ? BR - BDivider : BR
FL = IsFeather ? max(BL, floor((BL + (Feather * 3)) / F_WidthMod) * WidthMod) : 0
FR = IsFeather ? max(BR, floor((BR + (Feather * 3)) / F_WidthMod) * WidthMod) : 0

# -------------------------------------------------------------------------------
#            PillarBox Strings
# -------------------------------------------------------------------------------

ResizedStr = !IsBDivider ? ",Resized," : ",Resized.AddBorders(BDivider, 0, BDivider, 0, color=BDColor),"
BordStr = ".AddBorders(0, 0, Resizing_Width-FL+BL-FR+BR, 0),"

GaussResizeLStr = !IsPlain ? ".GaussResize" + (!IsResizeMT ? "" : "MT") + "(BL, OutHeight)" : ""
GaussResizeRStr = !IsPlain ? ".GaussResize" + (!IsResizeMT ? "" : "MT") + "(BR, OutHeight)" : ""
FGaussResizeLStr = IsFeather ? ".GaussResize" + (!IsResizeMT ? "" : "MT") + "(FL, OutHeight)" : ""
FGaussResizeRStr = IsFeather ? ".GaussResize" + (!IsResizeMT ? "" : "MT") + "(FR, OutHeight)" : ""

GaussResize3LStr = Clone3 ? ".GaussResize" + (!IsResizeMT ? "" : "MT") + \
"(max(BL, floor(WidthCloneBL * RatioL / F_WidthMod) * WidthMod), \
max(OutHeight, floor(OutHeight * RatioL / F_HeightMod) * HeightMod))" : ""
GaussResize3RStr = Clone3 ? ".GaussResize" + (!IsResizeMT ? "" : "MT") + \
"(max(BR, floor(WidthCloneBR * RatioR / F_WidthMod) * WidthMod), \
max(OutHeight, floor(OutHeight * RatioR / F_HeightMod) * HeightMod))" : ""

""", "PillarBox Strings Eval") : nop()

# -------------------------------------------------------------------------------
#            PillarBox Frosty Borders
# -------------------------------------------------------------------------------

IsPillarBox && IsFrosty ? Eval("""

MaxFrostyC = IsFeather ? floor(F_BordVid_Width / 2.0 / F_WidthMod) * WidthMod : nop()
FrostyCropL = IsFeather ? max(MaxFrostyC, BordVid_Width - BL) : nop()
FrostyCropR = IsFeather ? max(MaxFrostyC, BordVid_Width - BR) : nop()
FrostyBL = IsFeather ? Resized.crop(0, 0, -FrostyCropL, 0) : nop()
FrostyBR = IsFeather ? Resized.crop(FrostyCropR, 0, 0, 0) : nop()
WidthFrostyBL = IsFeather ? width(FrostyBL) : nop()
WidthFrostyBR = IsFeather ? width(FrostyBR) : nop()

FlipFrostyL = \
IsFeather ? FlipHorizontal((WidthFrostyBL == BL) ? FrostyBL : Eval("FrostyBL" + GaussResizeLStr)) : nop()
FlipFrostyR = \
IsFeather ? FlipHorizontal((WidthFrostyBR == BR) ? FrostyBR : Eval("FrostyBR" + GaussResizeRStr)) : nop()

FrostyCrop = BordVid_Width - max(BorderMin, floor(F_BordVid_Width / 4.0 / F_WidthMod) * WidthMod)

Blur = IsBlur ? Blur : float(FrostyCrop) / (!Frosty2 ? 16.0 : 4.0)
VBlur = IsVBlur ? VBlur : F_BordVid_Height / 10.0
FastBlurStr = (Blur == 0 == VBlur) ? "" : FastBlurStr

FrostyLR = Eval("StackHorizontal(BordVid.crop(0, 0, -FrostyCrop, 0), " + \
"BordVid.crop(FrostyCrop, 0, 0, 0))" + TSoftStr + FastBlurStr)

FrostyCrop = width(FrostyLR) - max(BorderMin, floor(width(FrostyLR) / 20.0 / F_WidthMod) * WidthMod)

FrostyL = FrostyLR.crop(0, 0, -FrostyCrop, 0)
FrostyR = FrostyLR.crop(FrostyCrop, 0, 0, 0)

FrostyBlendL = (Blend == 0) ? FrostyL : (Blend == 1) ? FrostyR : \
Overlay(FrostyL, FlipHorizontal(FrostyR), Opacity=Blend)
FrostyBlendR = (Blend == 0) ? FrostyR : (Blend == 1) ? FrostyL : \
Overlay(FrostyR, FlipHorizontal(FrostyL), Opacity=Blend)

FrostyL = \
!IsFeather ? Eval("FrostyBlendL" + GaussResizeLStr + GammaStr + TweakStr + GrainStr + SLoopStr) : nop()
FrostyR = \
!IsFeather ? Eval("FrostyBlendR" + GaussResizeRStr + GammaStr + TweakStr + GrainStr + SLoopStr) : nop()

FFrostyL = \
IsFeather ? Eval("FrostyBlendL" + FGaussResizeLStr + GammaStr + TweakStr + GrainStr + SLoopStr) : nop()
FFrostyR = \
IsFeather ? Eval("FrostyBlendR" + FGaussResizeRStr + GammaStr + TweakStr + GrainStr + SLoopStr) : nop()

""", "PillarBox Frosty Eval") : IsPillarBox ? Eval("""

FastBlurStr = (Blur == 0 == VBlur) ? "" : FastBlurStr

""") : nop()

# -------------------------------------------------------------------------------
#            PillarBox Clone Borders
# -------------------------------------------------------------------------------

IsPillarBox && IsClone ? Eval("""

MaxCloneC = floor(F_BordVid_Width / 2.0 / F_WidthMod) * WidthMod
CloneCropL = max(MaxCloneC, BordVid_Width - BL)
CloneCropR = max(MaxCloneC, BordVid_Width - BR)
CloneBL = BordVid.crop(0, 0, -CloneCropL, 0)
CloneBR = BordVid.crop(CloneCropR, 0, 0, 0)
WidthCloneBL = width(CloneBL)
WidthCloneBR = width(CloneBR)

FlipCloneL = FlipHorizontal((WidthCloneBL == BL) ? CloneBL : Eval("CloneBL" + GaussResizeLStr))
FlipCloneR = FlipHorizontal((WidthCloneBR == BR) ? CloneBR : Eval("CloneBR" + GaussResizeRStr))

CloneLR = (Clone1 || Clone3) && IsTSoft ? Eval("StackHorizontal(CloneBL, CloneBR)" + TSoftStr) : nop()

CloneL = Clone1 || Clone3 ? (IsTSoft ? CloneLR.crop(0, 0, -width(CloneLR)+WidthCloneBL, 0) : CloneBL) : nop()
CloneR = Clone1 || Clone3 ? (IsTSoft ? CloneLR.crop(width(CloneLR)-WidthCloneBR, 0, 0, 0) : CloneBR) : nop()

CloneBlendL = Clone1 || Clone3 ? ((Blend == 0) ? CloneL : (Blend == 1) ? CloneR : \
Overlay(CloneL, FlipHorizontal(CloneR), Opacity=Blend)) : nop()
CloneBlendR = Clone1 || Clone3 ? ((Blend == 0) ? CloneR : (Blend == 1) ? CloneL : \
Overlay(CloneR, FlipHorizontal(CloneL), Opacity=Blend)) : nop()

CloneL = Clone1 && !IsFeather ? Eval("CloneBlendL" + FastBlurStr + \
((WidthCloneBL == BL) ? "" : GaussResizeLStr) + GammaStr + TweakStr + GrainStr) : nop()
CloneR = Clone1 && !IsFeather ? Eval("CloneBlendR" + FastBlurStr + \
((WidthCloneBR == BR) ? "" : GaussResizeRStr) + GammaStr + TweakStr + GrainStr) : nop()

FCloneL = Clone1 && IsFeather ? \
Eval("CloneBlendL" + ((WidthCloneBL == BL) ? "" : GaussResizeLStr) + GammaStr + TweakStr) : nop()
FCloneR = Clone1 && IsFeather ? \
Eval("CloneBlendR" + ((WidthCloneBR == BR) ? "" : GaussResizeRStr) + GammaStr + TweakStr) : nop()

""", "PillarBox Clone Eval") : nop()

# -------------------------------------------------------------------------------
#            PillarBox Clone2 Borders
# -------------------------------------------------------------------------------

IsPillarBox && Clone2 ? Eval("""

Clone2CropL = max(MaxCloneC, BordVid_Width - FL)
Clone2CropR = max(MaxCloneC, BordVid_Width - FR)
Clone2BL = BordVid.crop(0, 0, -Clone2CropL, 0)
Clone2BR = BordVid.crop(Clone2CropR, 0, 0, 0)
WidthClone2BL = width(Clone2BL)
WidthClone2BR = width(Clone2BR)

Clone2LR = IsTSoft ? Eval("StackHorizontal(Clone2BL, Clone2BR)" + TSoftStr) : nop()

Clone2L = IsTSoft ? Clone2LR.crop(0, 0, -width(Clone2LR)+WidthClone2BL, 0) : Clone2BL
Clone2R = IsTSoft ? Clone2LR.crop(width(Clone2LR)-WidthClone2BR, 0, 0, 0) : Clone2BR

Clone2BlendL = (Blend == 0) ? Clone2L : (Blend == 1) ? Clone2R : \
Overlay(Clone2L, FlipHorizontal(Clone2R), Opacity=Blend)
Clone2BlendR = (Blend == 0) ? Clone2R : (Blend == 1) ? Clone2L : \
Overlay(Clone2R, FlipHorizontal(Clone2L), Opacity=Blend)

FClone2L = Eval("Clone2BlendL" + FastBlurStr + \
((WidthClone2BL == FL) ? "" : FGaussResizeLStr) + GammaStr + TweakStr + GrainStr)
FClone2R = Eval("Clone2BlendR" + FastBlurStr + \
((WidthClone2BR == FR) ? "" : FGaussResizeLStr) + GammaStr + TweakStr + GrainStr)

""", "PillarBox Clone2 Eval") : nop()

# -------------------------------------------------------------------------------
#            PillarBox Clone3 Borders
# -------------------------------------------------------------------------------

IsPillarBox && Clone3 ? Eval("""

RatioL = ((WidthCloneBL - BL) >= 0) ? 1.618 : float(BL) / float(WidthCloneBL)
RatioR = ((WidthCloneBR - BR) >= 0) ? 1.618 : float(BR) / float(WidthCloneBR)

Clone3L = Eval("CloneBlendL" + GaussResize3LStr)
Clone3R = Eval("CloneBlendR" + GaussResize3RStr)
WidthClone3L = width(Clone3L)
HeightClone3L = height(Clone3L)
WidthClone3R = width(Clone3R)
HeightClone3R = height(Clone3R)

Clone3L_CL = max(0, floor((WidthClone3L - BL) / F_WidthMod / 2.0) * WidthMod)
Clone3L_CR = max(0, WidthClone3L - BL - Clone3L_CL)
Clone3L_CT = max(0, floor((HeightClone3L - BordVid_Height) / F_HeightMod / 2.0) * HeightMod)
Clone3L_CB = max(0, HeightClone3L - BordVid_Height - Clone3L_CT)
Clone3R_CL = max(0, floor((WidthClone3R - BR) / F_WidthMod / 2.0) * WidthMod)
Clone3R_CR = max(0, WidthClone3R - BR - Clone3R_CL)
Clone3R_CT = max(0, floor((HeightClone3R - BordVid_Height) / F_HeightMod / 2.0) * HeightMod)
Clone3R_CB = max(0, HeightClone3R - BordVid_Height - Clone3R_CT)

FClone3L = Eval("Clone3L.crop(Clone3L_CL, Clone3L_CT, -Clone3L_CR, -Clone3L_CB)" + GammaStr + TweakStr)
FClone3R = Eval("Clone3R.crop(Clone3R_CL, Clone3R_CT, -Clone3R_CR, -Clone3R_CB)" + GammaStr + TweakStr)

Clone3L = !IsFeather ? Eval("FClone3L" + FastBlurStr + GrainStr) : nop()
Clone3R = !IsFeather ? Eval("FClone3R" + FastBlurStr + GrainStr) : nop()

""", "PillarBox Clone3 Eval") : nop()

# -------------------------------------------------------------------------------
#            PillarBox FrostyGradient Borders
# -------------------------------------------------------------------------------

IsPillarBox && FrostyGradient ? Eval("""

GradientLR = Eval("BlankClip(BordVid, width=72, height=OutHeight).AddBorders(24, 0, 0, 0, color=BColor)" + \
".FastBlur(30, y_blur=0, iterations=3, dither=true, threads=Threads, gamma=false)")

GradientL = Eval("FlipHorizontal(GradientLR)" + GaussResizeLStr + GammaStr + TweakStr + GrainStr + LoopStr)
GradientR = Eval("GradientLR" + GaussResizeRStr + GammaStr + TweakStr + GrainStr + LoopStr)

""", "PillarBox FrostyGradient Eval") : nop()

# -------------------------------------------------------------------------------
#            PillarBox Plain Borders
# -------------------------------------------------------------------------------

IsPillarBox && IsPlain ? Eval("""

TweakPL = (BL >= WidthMod) ? Eval("BlankClip(Resized, width=BL, color=BColor)" + GammaStr + TweakStr) : nop()
TweakPR = (BR >= WidthMod) ? Eval("BlankClip(Resized, width=BR, color=BColor)" + GammaStr + TweakStr) : nop()

PlainL = (BL >= WidthMod) && !IsFeather ? Eval("TweakPL" + GrainStr + LoopStr) : nop()
PlainR = (BR >= WidthMod) && !IsFeather ? Eval("TweakPR" + GrainStr + LoopStr) : nop()

FPlainL = (BL >= WidthMod) && IsFeather ? Eval("TweakPL" + LoopStr) : nop()
FPlainR = (BR >= WidthMod) && IsFeather ? Eval("TweakPR" + LoopStr) : nop()

""", "PillarBox Plain Eval") : nop()

# -------------------------------------------------------------------------------
#            PillarBox Frosty Clip
# -------------------------------------------------------------------------------

IsPillarBox ? Eval("""

FrostyBL = !IsFeather ? (IsFrosty ? FrostyL : Clone1 ? CloneL : Clone3 ? Clone3L : \
FrostyGradient ? GradientL : IsPlain && (BL >= WidthMod) ? PlainL : nop()) : \
IsFrosty ? FlipFrostyL : IsClone ? FlipCloneL : IsPlain && (BL >= WidthMod) ? FPlainL : nop()

FrostyBR = !IsFeather ? (IsFrosty ? FrostyR : Clone1 ? CloneR : Clone3 ? Clone3R : \
FrostyGradient ? GradientR :IsPlain && (BR >= WidthMod) ? PlainR : nop()) : \
IsFrosty ? FlipFrostyR : IsClone ? FlipCloneR : IsPlain && (BR >= WidthMod) ? FPlainR : nop()

FrostyClip = IsFrosty || IsClone || FrostyGradient || (IsPlain && (BL >= WidthMod <= BR)) ? \
Eval("StackHorizontal(FrostyBL" + ResizedStr + "FrostyBR)") : \
IsPlain && (BL >= WidthMod) ? StackHorizontal(FrostyBL, Resized) : \
IsPlain && (BR >= WidthMod) ? StackHorizontal(Resized, FrostyBR) : Resized

""", "PillarBox Frosty Clip Eval") : nop()

# -------------------------------------------------------------------------------
#            PillarBox Feather Mask
# -------------------------------------------------------------------------------

IsPillarBox && IsFeather ? Eval("""

MBlur = round(max(0, Feather / 2.25))

MFastBlurStr = (MBlur == 0) ? "" : \
".FastBlur(MBlur, y_blur=0, iterations=Iterations, dither=true, threads=Threads, gamma=false)"

FeatherMask = BlankClip(Resized, width=Resizing_Width-(Feather*2))\
.AddBorders(BL+Feather, 0, BR+Feather, 0, color=$FFFFFF).ColorYUV(Levels="TV->PC")

FeatherMask = Eval("FeatherMask" + MFastBlurStr + LoopStr)

# -------------------------------------------------------------------------------
#            PillarBox Feather Clip
# -------------------------------------------------------------------------------

FeatherClip = IsFrosty ? Eval("StackHorizontal(FFrostyL" + BordStr + "FFrostyR)")  : \
Clone1 ? Eval("StackHorizontal(" + \
"StackHorizontal(FCloneL, Resized.crop(0, 0, -Resizing_Width+FL-BL, 0))" + FastBlurStr + GrainStr + BordStr + \
"StackHorizontal(Resized.crop(Resizing_Width-FR+BR, 0, 0, 0), FCloneR)" + FastBlurStr + GrainStr + ")")  : \
Clone2 ? Eval("StackHorizontal(FClone2L" + BordStr + "FClone2R)") : \
Clone3 ? Eval("StackHorizontal(" + \
"StackHorizontal(FClone3L, Resized.crop(0, 0, -Resizing_Width+FL-BL, 0))" + FastBlurStr + GrainStr + BordStr + \
"StackHorizontal(Resized.crop(Resizing_Width-FR+BR, 0, 0, 0), FClone3R)" + FastBlurStr + GrainStr + ")") : \
Eval("StackHorizontal(BlankClip(Resized, width=FL, color=BColor)" + \
GammaStr + TweakStr + GrainStr + LoopStr + BordStr + \
"BlankClip(Resized, width=FR, color=BColor)" + GammaStr + TweakStr + GrainStr + LoopStr + ")")

""", "PillarBox Feather Clip Eval") : nop()

# -------------------------------------------------------------------------------
#            PillarBox Output
# -------------------------------------------------------------------------------

IsPillarBox ? Eval("""

FrostyOut = IsFeather ? Overlay(FrostyClip, FeatherClip, mask=FeatherMask) : FrostyClip

""", "PillarBox Output Eval") : nop()

# ===============================================================================
#            LetterBox Borders
# ===============================================================================

IsLetterBox ? Eval("""

BT = IsBDivider ? BT - BDivider : BT
BB = IsBDivider ? BB - BDivider : BB
FT = IsFeather ? max(BT, floor((BT + (Feather * 3)) / F_HeightMod) * HeightMod) : 0
FB = IsFeather ? max(BB, floor((BB + (Feather * 3)) / F_HeightMod) * HeightMod) : 0

# -------------------------------------------------------------------------------
#            LetterBox Strings
# -------------------------------------------------------------------------------

ResizedStr = !IsBDivider ? ",Resized," : ",Resized.AddBorders(0, BDivider, 0, BDivider, color=BDColor),"
BordStr = ".AddBorders(0, 0, 0, Resizing_Height-FT+BT-FB+BB),"

GaussResizeTStr = !IsPlain ? ".GaussResize" + (!IsResizeMT ? "" : "MT") + "(OutWidth, BT)" : ""
GaussResizeBStr = !IsPlain ? ".GaussResize" + (!IsResizeMT ? "" : "MT") + "(OutWidth, BB)" : ""
FGaussResizeTStr = IsFeather ? ".GaussResize" + (!IsResizeMT ? "" : "MT") + "(OutWidth, FT)" : ""
FGaussResizeBStr = IsFeather ? ".GaussResize" + (!IsResizeMT ? "" : "MT") + "(OutWidth, FB)" : ""

GaussResize3TStr = Clone3 ? ".GaussResize" + (!IsResizeMT ? "" : "MT") + \
"(max(OutWidth, floor(OutWidth * RatioT / F_WidthMod) * WidthMod), \
max(BT, floor(HeightCloneBT * RatioT / F_HeightMod) * HeightMod))" : ""
GaussResize3BStr = Clone3 ? ".GaussResize" + (!IsResizeMT ? "" : "MT") + \
"(max(OutWidth, floor(OutWidth * RatioB / F_WidthMod) * WidthMod), \
max(BB, floor(HeightCloneBB * RatioB / F_HeightMod) * HeightMod))" : ""

""", "LetterBox Strings Eval") : nop()

# -------------------------------------------------------------------------------
#            LetterBox Frosty Borders
# -------------------------------------------------------------------------------

IsLetterBox && IsFrosty ? Eval("""

MaxFrostyC = IsFeather ? floor(F_BordVid_Height / 2.0 / F_HeightMod) * HeightMod : nop()
FrostyCropT = IsFeather ? max(MaxFrostyC, BordVid_Height - BT) : nop()
FrostyCropB = IsFeather ? max(MaxFrostyC, BordVid_Height - BB) : nop()
FrostyBT = IsFeather ? Resized.crop(0, 0, 0, -FrostyCropT) : nop()
FrostyBB = IsFeather ? Resized.crop(0, FrostyCropB, 0, 0) : nop()
HeightFrostyBT = IsFeather ? height(FrostyBT) : nop()
HeightFrostyBB = IsFeather ? height(FrostyBB) : nop()

FlipFrostyT = \
IsFeather ? FlipVertical((HeightFrostyBT == BT) ? FrostyBT : Eval("FrostyBT" + GaussResizeTStr)) : nop()
FlipFrostyB = \
IsFeather ? FlipVertical((HeightFrostyBB == BB) ? FrostyBB : Eval("FrostyBB" + GaussResizeBStr)) : nop()

FrostyCrop = BordVid_Height - max(BorderMin, floor(F_BordVid_Height / 4.0 / F_HeightMod) * HeightMod)

Blur = IsBlur ? Blur : F_BordVid_Width / 10.0
VBlur = IsVBlur ? VBlur : float(FrostyCrop) / (!Frosty2 ? 16.0 : 4.0)
FastBlurStr = (Blur == 0 == VBlur) ? "" : FastBlurStr

FrostyTB = Eval("StackVertical(BordVid.crop(0, 0, 0, -FrostyCrop), " + \
"BordVid.crop(0, FrostyCrop, 0, 0))" + TSoftStr + FastBlurStr)

FrostyCrop = height(FrostyTB) - max(BorderMin, floor(height(FrostyTB) / 20.0 / F_HeightMod) * HeightMod)

FrostyT = FrostyTB.crop(0, 0, 0, -FrostyCrop)
FrostyB = FrostyTB.crop(0, FrostyCrop, 0, 0)

FrostyBlendT = (Blend == 0) ? FrostyT : (Blend == 1) ? FrostyB : \
Overlay(FrostyT, FlipVertical(FrostyB), Opacity=Blend)
FrostyBlendB = (Blend == 0) ? FrostyB : (Blend == 1) ? FrostyT : \
Overlay(FrostyB, FlipVertical(FrostyT), Opacity=Blend)

FrostyT = \
!IsFeather ? Eval("FrostyBlendT" + GaussResizeTStr + GammaStr + TweakStr + GrainStr + SLoopStr) : nop()
FrostyB = \
!IsFeather ? Eval("FrostyBlendB" + GaussResizeBStr + GammaStr + TweakStr + GrainStr + SLoopStr) : nop()

FFrostyT = \
IsFeather ? Eval("FrostyBlendT" + FGaussResizeTStr + GammaStr + TweakStr + GrainStr + SLoopStr) : nop()
FFrostyB = \
IsFeather ? Eval("FrostyBlendB" + FGaussResizeBStr + GammaStr + TweakStr + GrainStr + SLoopStr) : nop()

""", "LetterBox Frosty Eval") : IsLetterBox ? Eval("""

FastBlurStr = (Blur == 0 == VBlur) ? "" : FastBlurStr

""") : nop()

# -------------------------------------------------------------------------------
#            LetterBox Clone Borders
# -------------------------------------------------------------------------------

IsLetterBox && IsClone ? Eval("""

MaxCloneC = floor(F_BordVid_Height / 2.0 / F_HeightMod) * HeightMod
CloneCropT = max(MaxCloneC, BordVid_Height - BT)
CloneCropB = max(MaxCloneC, BordVid_Height - BB)
CloneBT = BordVid.crop(0, 0, 0, -CloneCropT)
CloneBB = BordVid.crop(0, CloneCropB, 0, 0)
HeightCloneBT = height(CloneBT)
HeightCloneBB = height(CloneBB)

FlipCloneT = FlipVertical((HeightCloneBT == BT) ? CloneBT : Eval("CloneBT" + GaussResizeTStr))
FlipCloneB = FlipVertical((HeightCloneBB == BB) ? CloneBB : Eval("CloneBB" + GaussResizeBStr))

CloneTB = (Clone1 || Clone3) && IsTSoft ? Eval("StackVertical(CloneBT, CloneBB)" + TSoftStr) : nop()

CloneT = Clone1 || Clone3 ? (IsTSoft ? CloneTB.crop(0, 0, 0, -height(CloneTB)+HeightCloneBT) : CloneBT) : nop()
CloneB = Clone1 || Clone3 ? (IsTSoft ? CloneTB.crop(0, height(CloneTB)-HeightCloneBB, 0, 0) : CloneBB) : nop()

CloneBlendT = Clone1 || Clone3 ? ((Blend == 0) ? CloneT : (Blend == 1) ? CloneB : \
Overlay(CloneT, FlipVertical(CloneB), Opacity=Blend)) : nop()
CloneBlendB = Clone1 || Clone3 ? ((Blend == 0) ? CloneB : (Blend == 1) ? CloneT : \
Overlay(CloneB, FlipVertical(CloneT), Opacity=Blend)) : nop()

CloneT = Clone1 && !IsFeather ? Eval("CloneBlendT" + FastBlurStr + \
((HeightCloneBT == BT) ? "" : GaussResizeTStr) + GammaStr + TweakStr + GrainStr) : nop()
CloneB = Clone1 && !IsFeather ? Eval("CloneBlendB" + FastBlurStr + \
((HeightCloneBB == BB) ? "" : GaussResizeBStr) + GammaStr + TweakStr + GrainStr) : nop()

FCloneT = Clone1 && IsFeather ? \
Eval("CloneBlendT" + ((HeightCloneBT == BT) ? "" : GaussResizeTStr) + GammaStr + TweakStr) : nop()
FCloneB = Clone1 && IsFeather ? \
Eval("CloneBlendB" + ((HeightCloneBB == BB) ? "" : GaussResizeBStr) + GammaStr + TweakStr) : nop()

""", "LetterBox Clone Eval") : nop()

# -------------------------------------------------------------------------------
#            LetterBox Clone2 Borders
# -------------------------------------------------------------------------------

IsLetterBox && Clone2 ? Eval("""

Clone2CropT = max(MaxCloneC, BordVid_Height - FT)
Clone2CropB = max(MaxCloneC, BordVid_Height - FB)
Clone2BT = BordVid.crop(0, 0, 0, -Clone2CropT)
Clone2BB = BordVid.crop(0, Clone2CropB, 0, 0)
HeightClone2BT = height(Clone2BT)
HeightClone2BB = height(Clone2BB)

Clone2TB = IsTSoft ? Eval("StackVertical(Clone2BT, Clone2BB)" + TSoftStr) : nop()

Clone2T = IsTSoft ? Clone2TB.crop(0, 0, 0, -height(Clone2TB)+HeightClone2BT) : Clone2BT
Clone2B = IsTSoft ? Clone2TB.crop(0, height(Clone2TB)-HeightClone2BB, 0, 0) : Clone2BB

Clone2BlendT = (Blend == 0) ? Clone2T : (Blend == 1) ? Clone2B : \
Overlay(Clone2T, FlipVertical(Clone2B), Opacity=Blend)
Clone2BlendB = (Blend == 0) ? Clone2B : (Blend == 1) ? Clone2T : \
Overlay(Clone2B, FlipVertical(Clone2T), Opacity=Blend)

FClone2T = Eval("Clone2BlendT" + FastBlurStr + \
((HeightClone2BT == FT) ? "" : FGaussResizeTStr) + GammaStr + TweakStr + GrainStr)
FClone2B = Eval("Clone2BlendB" + FastBlurStr + \
((HeightClone2BB == FB) ? "" : FGaussResizeBStr) + GammaStr + TweakStr + GrainStr)

""", "LetterBox Clone2 Eval") : nop()

# -------------------------------------------------------------------------------
#            LetterBox Clone3 Borders
# -------------------------------------------------------------------------------

IsLetterBox && Clone3 ? Eval("""

RatioT = ((HeightCloneBT - BT) >= 0) ? 1.618 : float(BT) / float(HeightCloneBT)
RatioB = ((HeightCloneBB - BB) >= 0) ? 1.618 : float(BB) / float(HeightCloneBB)

Clone3T = Eval("CloneBlendT" + GaussResize3TStr)
Clone3B = Eval("CloneBlendB" + GaussResize3BStr)
WidthClone3T = width(Clone3T)
HeightClone3T = height(Clone3T)
WidthClone3B = width(Clone3B)
HeightClone3B = height(Clone3B)

Clone3T_CL = max(0, floor((WidthClone3T - BordVid_Width) / F_WidthMod / 2.0) * WidthMod)
Clone3T_CR = max(0, WidthClone3T - BordVid_Width - Clone3T_CL)
Clone3T_CT = max(0, floor((HeightClone3T - BT) / F_HeightMod / 2.0) * HeightMod)
Clone3T_CB = max(0, HeightClone3T - BT - Clone3T_CT)
Clone3B_CL = max(0, floor((WidthClone3B - BordVid_Width) / F_WidthMod / 2.0) * WidthMod)
Clone3B_CR = max(0, WidthClone3B - BordVid_Width - Clone3B_CL)
Clone3B_CT = max(0, floor((HeightClone3B - BB) / F_HeightMod / 2.0) * HeightMod)
Clone3B_CB = max(0, HeightClone3B - BB - Clone3B_CT)

FClone3T = Eval("Clone3T.crop(Clone3T_CL, Clone3T_CT, -Clone3T_CR, -Clone3T_CB)" + GammaStr + TweakStr)
FClone3B = Eval("Clone3B.crop(Clone3B_CL, Clone3B_CT, -Clone3B_CR, -Clone3B_CB)" + GammaStr + TweakStr)

Clone3T = !IsFeather ? Eval("FClone3T" + FastBlurStr + GrainStr) : nop()
Clone3B = !IsFeather ? Eval("FClone3B" + FastBlurStr + GrainStr) : nop()

""", "LetterBox Clone3 Eval") : nop()

# -------------------------------------------------------------------------------
#            LetterBox FrostyGradient Borders
# -------------------------------------------------------------------------------

IsLetterBox && FrostyGradient ? Eval("""

GradientTB = Eval("BlankClip(BordVid, width=OutWidth, height=72).AddBorders(0, 24, 0, 0, color=BColor)" + \
".FastBlur(0, y_blur=30, iterations=3, dither=true, threads=Threads, gamma=false)")

GradientT = Eval("FlipVertical(GradientTB)" + GaussResizeTStr + GammaStr + TweakStr + GrainStr + LoopStr)
GradientB = Eval("GradientTB" + GaussResizeBStr + GammaStr + TweakStr + GrainStr + LoopStr)

""", "LetterBox FrostyGradient Eval") : nop()

# -------------------------------------------------------------------------------
#            LetterBox Plain Borders
# -------------------------------------------------------------------------------

IsLetterBox && IsPlain ? Eval("""

TweakPT = (BT >= HeightMod) ? Eval("BlankClip(Resized, height=BT, color=BColor)" + GammaStr + TweakStr) : nop()
TweakPB = (BB >= HeightMod) ? Eval("BlankClip(Resized, height=BB, color=BColor)" + GammaStr + TweakStr) : nop()

PlainT = (BT >= HeightMod) && !IsFeather ? Eval("TweakPT" + GrainStr + LoopStr) : nop()
PlainB = (BB >= HeightMod) && !IsFeather ? Eval("TweakPB" + GrainStr + LoopStr) : nop()

FPlainT = (BT >= HeightMod) && IsFeather ? Eval("TweakPT" + LoopStr) : nop()
FPlainB = (BB >= HeightMod) && IsFeather ? Eval("TweakPB" + LoopStr) : nop()

""", "LetterBox Plain Eval") : nop()

# -------------------------------------------------------------------------------
#            LetterBox Frosty Clip
# -------------------------------------------------------------------------------

IsLetterBox ? Eval("""

FrostyBT = !IsFeather ? (IsFrosty ? FrostyT : Clone1 ? CloneT : Clone3 ? Clone3T : \
FrostyGradient ? GradientT : IsPlain && (BT >= HeightMod) ? PlainT : nop()) : \
IsFrosty ? FlipFrostyT : IsClone ? FlipCloneT : IsPlain && (BT >= HeightMod) ? FPlainT : nop()

FrostyBB = !IsFeather ? (IsFrosty ? FrostyB : Clone1 ? CloneB : Clone3 ? Clone3B : \
FrostyGradient ? GradientB : IsPlain && (BB >= HeightMod) ? PlainB : nop()) : \
IsFrosty ? FlipFrostyB : IsClone ? FlipCloneB : IsPlain && (BB >= HeightMod) ? FPlainB : nop()

FrostyClip = IsFrosty || IsClone || FrostyGradient || (IsPlain && (BT >= HeightMod <= BB)) ? \
Eval("StackVertical(FrostyBT" + ResizedStr + "FrostyBB)") : \
IsPlain && (BT >= HeightMod) ? StackVertical(FrostyBT, Resized) : \
IsPlain && (BB >= HeightMod) ? StackVertical(Resized, FrostyBB) : Resized

""", "LetterBox Frosty Clip Eval") : nop()

# -------------------------------------------------------------------------------
#            LetterBox Feather Mask
# -------------------------------------------------------------------------------

IsLetterBox && IsFeather ? Eval("""

MVBlur = round(max(0, Feather / 2.25))

MFastBlurStr = (MVBlur == 0) ? "" : \
".FastBlur(0, y_blur=MVBlur, iterations=Iterations, dither=true, threads=Threads, gamma=false)"

FeatherMask = BlankClip(Resized, height=Resizing_Height-(Feather*2))\
.AddBorders(0, BT+Feather, 0, BB+Feather, color=$FFFFFF).ColorYUV(Levels="TV->PC")

FeatherMask = Eval("FeatherMask" + MFastBlurStr + LoopStr)

# -------------------------------------------------------------------------------
#            LetterBox Feather Clip
# -------------------------------------------------------------------------------

FeatherClip = IsFrosty ? Eval("StackVertical(FFrostyT" + BordStr + "FFrostyB)") : \
Clone1 ? Eval("StackVertical(" + \
"StackVertical(FCloneT, Resized.crop(0, 0, 0, -Resizing_Height+FT-BT))" + FastBlurStr + GrainStr + BordStr + \
"StackVertical(Resized.crop(0, Resizing_Height-FB+BB, 0, 0), FCloneB)" + FastBlurStr + GrainStr + ")")  : \
Clone2 ? Eval("StackVertical(FClone2T" + BordStr + "FClone2B)") : \
Clone3 ? Eval("StackVertical(" + \
"StackVertical(FClone3T, Resized.crop(0, 0, 0, -Resizing_Height+FT-BT))" + FastBlurStr + GrainStr + BordStr + \
"StackVertical(Resized.crop(0, Resizing_Height-FB+BB, 0, 0), FClone3B)" + FastBlurStr + GrainStr + ")") : \
Eval("StackVertical(BlankClip(Resized, height=FT, color=BColor)" + \
GammaStr + TweakStr + GrainStr + LoopStr + BordStr + \
"BlankClip(Resized, height=FB, color=BColor)" + GammaStr + TweakStr + GrainStr + LoopStr + ")")

""", "LetterBox Feather Clip Eval") : nop()

# -------------------------------------------------------------------------------
#            LetterBox Output
# -------------------------------------------------------------------------------

IsLetterBox ? Eval("""

FrostyOut = IsFeather ? Overlay(FrostyClip, FeatherClip, mask=FeatherMask) : FrostyClip

""", "LetterBox Output Eval") : nop()

# ===============================================================================
#            No Borders
# ===============================================================================

!IsBorders ? Eval(" FrostyOut = Resized ") : nop()

# ===============================================================================
#            Info
# ===============================================================================

Info ? Eval("""

InfoDAR = (InDAR > 0) ? InDAR : \
F_Source_Width * ((InSAR > 0) ? InSAR : (PropsSAR > 0) ? PropsSAR : 1.0) / F_Source_Height
InfoSAR = (InDAR > 0) ? F_Source_Height * InDAR / F_Source_Width : \
(InSAR > 0) ? InSAR : (PropsSAR > 0) ? PropsSAR : 1.0

AspectInfo = "Input Aspect   " + \
((InDAR > 0) ? "InDAR" : (InSAR > 0) ? "InSAR" : (PropsSAR > 0) ? "Frame Props SAR" : "None")

SourceInfo = string(Source_Width, "\n\nSource   %.0f x ") + string(Source_Height, "%.0f") + \
"\nDAR   " + FB_FS(InfoDAR, 5, True) + FB_FTF(InfoDAR) + \
"\nSAR   " + FB_FS(InfoSAR, 5, True) + FB_FTF(InfoSAR)

CroppingInfo = "\n\nTotal Cropping\n(" + \
FB_FS(CCL+RCL) + ",  " + FB_FS(CCT+RCT) + ",  " + FB_FS(-CCR-RCR) + ",  " + FB_FS(-CCB-RCB) + ")"

PicDAR = F_Resizing_Width / F_Resizing_Height

PicWH = string(Resizing_Width, "\n\nResized Picture   %.0f x ") + string(Resizing_Height, "%.0f") + \
"\nDAR   " + FB_FS(PicDAR, 5, True) + FB_FTF(PicDAR) + FB_PicMod(Resizing_Width, Resizing_Height)

InfoBL = IsBorders ? (!IsPillarBox || !IsBDivider ? BL : BL + BDivider) : 0
InfoBT = IsBorders ? (!IsLetterBox || !IsBDivider ? BT : BT + BDivider) : 0
InfoBR = IsBorders ? (!IsPillarBox || !IsBDivider ? BR : BR + BDivider) : 0
InfoBB = IsBorders ? (!IsLetterBox || !IsBDivider ? BB : BB + BDivider) : 0

BType = !IsBorders ? "" : "  (" + (FrostyPlain ? "FrostyPlain" : FrostyGradient ? "FrostyGradient" : \
Clone3 ? "Clone=3" : (Clone == 2) && (Clone2 || Clone1) ? "Clone=2" : Clone1 ? "Clone=1": \
IsFrostyStatic ? "FrostyStatic" : Frosty2 ? "Frosty2" : Frosty ? "Frosty" : "Plain") + ")"

Borders = "\n\nBorders" + (!IsBorders ? "\nNone" : \
BType + string(InfoBL, "\n(%.0f") + string(InfoBT, ",  %.0f") + \
string(InfoBR, ",  %.0f") + string(InfoBB, ",  %.0f)"))

OutWidth = (OutWidth > 0) ? OutWidth : Resizing_Width
OutHeight = (OutHeight > 0) ? OutHeight : Resizing_Height
F_OutWidth = (OutWidth > 0) ? float(OutWidth) : F_Resizing_Width
F_OutHeight = (OutHeight > 0) ? float(OutHeight) : F_Resizing_Height

OutDAR = F_OutWidth / F_OutHeight

OutWH = string(OutWidth, "\n\nOutput   %.0f x ") + string(OutHeight, "%.0f") + \
"\nDAR   " + FB_FS(OutDAR, 5, True) + FB_FTF(OutDAR) + FB_PicMod(OutWidth, OutHeight)

InfoResizer = "\n\nResizer   " + Resizer + ((RTaps == "") ? "" : "  (3 taps)") + \
((RStr == "") ? "" : "\nRStr   " + RStr)

SSize = min(F_OutWidth * 0.0215, \
F_OutHeight * ((OutHeight < 300) ? 0.0345 : (OutHeight < 400) ? 0.036 : (OutHeight < 500) ? 0.0335 : \
(OutHeight < 600) ? 0.0342 : (OutHeight < 1100) ? 0.0335 : (OutHeight < 1600) ? 0.033 : \
(OutHeight < 1800) ? 0.032 : (OutHeight < 2180) ? 0.031 : 0.03))

SY = (F_OutHeight * 0.51)

SLSP = (OutHeight < 400) ? 8 : (OutHeight < 600) ? 16 : 24

FrostyOut = FrostyOut.subtitle(AspectInfo + SourceInfo + CroppingInfo + PicWH + \
Borders + OutWH + InfoResizer, y=SY, size=SSize, text_color=$FFFFE0, align=5, lsp=SLSP)

""", "Info Eval") : nop()

# ===============================================================================
#            Frosty Output
# ===============================================================================

FrostyOut = IsYUY2Source ? ConvertToYUY2(FrostyOut) : FrostyOut
FrostyOut = IsAvsProps ? FrostyOut.propSet("_SARNum", 1).propSet("_SARDen", 1) : FrostyOut

return !HasAudio(Source_Audio) ? FrostyOut : AudioDub(FrostyOut, Source_Audio) }

# ===============================================================================
# ===============================================================================
#            Float To Fraction
# ===============================================================================
# ===============================================================================

function FB_FTF(float Decimal, int "Out") {
Out = default(Out, 1)
Num = (Decimal == 0) ? "0" : string(ContinuedNumerator(Decimal, Limit=10000))
Den = (Decimal == 0) ? "1" : string(ContinuedDenominator(Decimal, Limit=10000))
return "  (" + Num + ((Out == 1) ? ":" : " / ") + Den + ")" }

# ===============================================================================
# ===============================================================================
#            Format String
# ===============================================================================
# ===============================================================================

function FB_FS(float F, int "Limit", bool "Keep") {

Limit = abs(default(Limit, 3))
Keep = default(Keep, false)
S = Eval("""string(F, "%.""" + string(Limit) + """f")""")
S = (Limit == 0) ? S : FB_RemoveTrailingZeros(S)
SLength = StrLen(S)
NewStr = (Limit == 0) || (FindStr(S, ".") < SLength) ? S : !Keep ? LeftStr(S, SLength - 1) : S + "0"

return (value(NewStr) == 0) && (FindStr(NewStr, "-") > 0) ? MidStr(NewStr, 2) : NewStr }

# ---------------------------------------

function FB_RemoveTrailingZeros(string S) {
ZeroPos = FindStr(S + "x", "0x")
return (ZeroPos == 0) ? S : FB_RemoveTrailingZeros(LeftStr(S, ZeroPos - 1)) }

# ===============================================================================
# ===============================================================================
#            Picture Mod
# ===============================================================================
# ===============================================================================

function FB_PicMod(W, H) {

WMod = ((W % 16) == 0) ? 16 : ((W % 8) == 0) ? 8 : ((W % 4) == 0) ? 4 : ((W % 2) == 0) ? 2 : 1
HMod = ((H % 16) == 0) ? 16 : ((H % 8) == 0) ? 8 : ((H % 4) == 0) ? 4 : ((H % 2) == 0) ? 2 : 1

return string(WMod, "  (Mod %.0fx") + string(HMod, "%.0f)") }

# ===============================================================================
# ===============================================================================
#            IsEqual
# ===============================================================================
# ===============================================================================

function FB_IsEqual(Val1, Val2) { return (abs(Val1 - Val2) < 0.00005) }

# ===============================================================================
# ===============================================================================
#            Wrapper Functions
# ===============================================================================
# ===============================================================================

function iFrostyBorders(clip Source, \
int "OutWidth", int "OutHeight", float "CL", float "CT", float "CR", float "CB", \
val "CropDAR", float "TCRatio", val "InDAR", val "InSAR", int "Mod", \
bool "Frosty", bool "Frosty2", int "FrostyStatic", \
int "Clone", bool "FrostyGradient", bool "FrostyPlain", bool "Plain", \
val "BColor", int "BDivider", val "BDColor", int "Feather", \
float "Bright", float "Cont", float "Sat", float "Gamma", \
float "Blend", float "Blur", float "VBlur", int "Iterations", float "Threads", \
int "GPlugin", float "Texture", float "TextureC", bool "StaticT", \
int "TSoft", bool "TSoftx2", string "Resizer", string "RStr", bool "Info") {

Info = default(Info, true)

FrostyBorders(Source, OutWidth, OutHeight, CL, CT, CR, CB, CropDAR, TCRatio, InDAR, InSAR, Mod, \
Frosty, Frosty2, FrostyStatic, Clone, FrostyGradient, FrostyPlain, Plain, BColor, BDivider, BDColor, \
Feather, Bright, Cont, Sat, Gamma, Blend, Blur, VBlur, Iterations, Threads, \
GPlugin, Texture, TextureC, StaticT, TSoft, TSoftx2, Resizer, RStr, Info) }

# -------------------------------------------------------------------------------

function PlainBorders(clip Source, \
int "OutWidth", int "OutHeight", float "CL", float "CT", float "CR", float "CB", \
val "CropDAR", float "TCRatio", val "InDAR", val "InSAR", int "Mod", \
bool "Frosty", bool "Frosty2", int "FrostyStatic", \
int "Clone", bool "FrostyGradient", bool "FrostyPlain", bool "Plain", \
val "BColor", int "BDivider", val "BDColor", int "Feather", \
float "Bright", float "Cont", float "Sat", float "Gamma", \
float "Blend", float "Blur", float "VBlur", int "Iterations", float "Threads", \
int "GPlugin", float "Texture", float "TextureC", bool "StaticT", \
int "TSoft", bool "TSoftx2", string "Resizer", string "RStr", bool "Info") {

Plain = default(Plain, true)

FrostyBorders(Source, OutWidth, OutHeight, CL, CT, CR, CB, CropDAR, TCRatio, InDAR, InSAR, Mod, \
Frosty, Frosty2, FrostyStatic, Clone, FrostyGradient, FrostyPlain, Plain, BColor, BDivider, BDColor, \
Feather, Bright, Cont, Sat, Gamma, Blend, Blur, VBlur, Iterations, Threads, \
GPlugin, Texture, TextureC, StaticT, TSoft, TSoftx2, Resizer, RStr, Info) }

# -------------------------------------------------------------------------------

function iPlainBorders(clip Source, \
int "OutWidth", int "OutHeight", float "CL", float "CT", float "CR", float "CB", \
val "CropDAR", float "TCRatio", val "InDAR", val "InSAR", int "Mod", \
bool "Frosty", bool "Frosty2", int "FrostyStatic", \
int "Clone", bool "FrostyGradient", bool "FrostyPlain", bool "Plain", \
val "BColor", int "BDivider", val "BDColor", int "Feather", \
float "Bright", float "Cont", float "Sat", float "Gamma", \
float "Blend", float "Blur", float "VBlur", int "Iterations", float "Threads", \
int "GPlugin", float "Texture", float "TextureC", bool "StaticT", \
int "TSoft", bool "TSoftx2", string "Resizer", string "RStr", bool "Info") {

Plain = default(Plain, true)
Info = default(Info, true)

FrostyBorders(Source, OutWidth, OutHeight, CL, CT, CR, CB, CropDAR, TCRatio, InDAR, InSAR, Mod, \
Frosty, Frosty2, FrostyStatic, Clone, FrostyGradient, FrostyPlain, Plain, BColor, BDivider, BDColor, \
Feather, Bright, Cont, Sat, Gamma, Blend, Blur, VBlur, Iterations, Threads, \
GPlugin, Texture, TextureC, StaticT, TSoft, TSoftx2, Resizer, RStr, Info) }

# ===============================================================================
# ===============================================================================
#            Resizing Defaults
# ===============================================================================
# ===============================================================================

# When a resizing method is specified via the Resizer argument, both functions below are ignored.
# When the RStr argument is used, the RStr function below is ignored.

function FB_Default_Resizer() { "" }
function FB_Default_RStr() { "" }

# ===============================================================================
# ===============================================================================
