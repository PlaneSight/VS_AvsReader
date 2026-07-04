[*===============================================================================
=================================================================================
             ReplaceFrameX 2022-12-17
=================================================================================
=================================================================================

ReplaceFrameX(Source, int Frame, int "Replace", string "Mode", string "Preset", int "BlkSize", bool "Position")

Usage Example:  ReplaceFrameX(1463, 2, "Dup")

---------------------------------------------------------------------------------
             Requirements
---------------------------------------------------------------------------------

For interpolating frames with FrameRateConverter or MVTools2.
http://avisynth.nl/index.php/MVTools
FrameRateConverter also requires MaskTools2.
http://avisynth.nl/index.php/Masktools2

FrameRateConverter.
Original version. 8 bit video only. Without the "Rife", "RifeHQ" and "RifeAnime" presets.
http://avisynth.nl/index.php/FrameRateConverter
HBD versions. See the top of each script for additional dependancies.
https://github.com/Dogway/Avisynth-Scripts/blob/master/EX mods/FrameRateConverterEX.avsi
https://github.com/Dogway/Avisynth-Scripts/blob/master/MIX mods/FrameRateConverterMIX.avsi

Position=true requires GRunT.
http://avisynth.nl/index.php/GRunT

---------------------------------------------------------------------------------
             Frame (compulsory un-named argument)
---------------------------------------------------------------------------------

Specify the number of the frame to be replaced.
When Replace is greater than 2, Frame specifies the first frame to be replaced.

---------------------------------------------------------------------------------
             Replace (default 1)
---------------------------------------------------------------------------------

Replace=1 Replaces a single frame.
          Cannot replace the first frame unless Mode="DupN".
          Cannot replace the last frame unless Mode="DupP" (or "Dup").
Replace>1 Replaces two or more frames. The specified frame and the following frame.
          Frame cannot equal zero.
          Frame + Replace can't exceed the 2nd last frame number.
          The dup modes can't be used when Replace is greater than 3.

---------------------------------------------------------------------------------
             Mode (default "Dup")
---------------------------------------------------------------------------------

Mode = "Dup", "DupP", "DupN", "Blend", "FRC", "FRCEX", "FRCMIX", "MFlow", "MBlock".

"Dup" is an alias for "DupP"
"DupP" (duplicate previous)
"DupN" (duplicate next)
The dup modes can't be used when Replace is greater than 3.
See below for how the Dup modes work.

"Blend"
Replaces frames with blended versions of the previous frame and the next good frame.

"FRC"
Replaces frames with interpolated frames using FrameRateConverter.

"FRCEX"
Replaces frames with interpolated frames using FrameRateConverterEX.

"FRCMIX"
Replaces frames with interpolated frames using FrameRateConverterMIX.

"MFlow"
Replaces frames with interpolated frames using the MFlowFPS function from MVTools2.

"MBlock"
Replaces frames with interpolated frames using the MBlockFPS function from MVTools2.

---------------------------------------------------------------------------------

Dup examples.
The following are frame numbers, with the numbers in square brackets representing the replaced frames.

ReplaceFrameX(15, 1, "DupP")  -  Replaces frame 15
11, 12, 13, 14, [14], 16, 17, 18, 19, 20

ReplaceFrameX(15, 1, "DupN")  -  Replaces frame 15
11, 12, 13, 14, [16], 16, 17, 18, 19, 20

When Replace=2, "DupP" and "DupN" produce identical results.
ReplaceFrameX(15, 2, "DupP")  -  Replaces frames 15 & 16
ReplaceFrameX(15, 2, "DupN")  -  Replaces frames 15 & 16
11, 12, 13, 14, [14], [17], 17, 18, 19, 20

ReplaceFrameX(15, 3, "DupP")  -  Replaces frames 15, 16 & 17
11, 12, 13, 14, [14], [14], [18], 18, 19, 20

ReplaceFrameX(15, 3, "DupN")  -  Replaces frames 15, 16 & 17
11, 12, 13, 14, [14], [18], [18], 18, 19, 20

---------------------------------------------------------------------------------
             Preset (default "Slower")
---------------------------------------------------------------------------------

Preset = "Slowest", "Slower", "Slow", "Normal", "Fast", "Faster", "Anime", "Rife", "RifeHQ", "RifeAnime".

Presets for FrameRateConverter. Does nothing unless Mode equals "FRC", "FRCEX" or "FRCMIX".

---------------------------------------------------------------------------------
             BlkSize (default undefined)
---------------------------------------------------------------------------------

Block size for FrameRateConverter and MVTools2.
Allowed vales 6, 8, 12, 16, 24, 32, 48 and 64 (although it depends on the MVTools2 version).
When FrameRateConverter is interpolating frames, the FrameRateConverter defaults are
used (based on resolution) unless a value is specified.
For MVTools2 the default is BlkSize 8 when the video height is less than 720, otherwise it's 16.

---------------------------------------------------------------------------------
             Position (default false)
---------------------------------------------------------------------------------

Display the current frame number at the top of the video, excluding the frames being replaced.

-------------------------------------------------------------------------------*]

# ===============================================================================
# ===============================================================================
#            ReplaceFrameX
# ===============================================================================
# ===============================================================================

function ReplaceFrameX(clip Source, \
int Frame, int "Replace", string "Mode", string "Preset", int "BlkSize", bool "Position")  {

RFX = " ReplaceFrameX " + chr(10)
Assert(HasVideo(Source), RFX + " No video found " + chr(10))

Video = KillAudio(Source)
Audio = HasAudio(Source) ? KillVideo(Source) : nop()
SourceHeight = height(Source)
Num = FrameRateNumerator(Source)
Den = FrameRateDenominator(Source)
EndFrame = FrameCount(Source) - 1
PrevFrame = max(0, Frame - 1)
NextFrame = min(Frame + Replace, EndFrame)
Replace = default(Replace, 1)
Mode = default(Mode, "Dup")
Preset = default(Preset, "Slower")
DupP = (Mode == "Dup") || (Mode == "DupP")
DupN = (Mode == "DupN")
FRC = (Mode == "FRC") || (Mode == "FRCEX") || (Mode == "FRCMIX")
BlkSize = default(BlkSize, FRC ? undefined() : (SourceHeight >= 720) ? 16 : 8)
BlkSize2 = !defined(BlkSize) ? undefined() : min(2, floor(float(BlkSize) / 4.0) * 2)
BlkSize3 = !defined(BlkSize) ? undefined() : min(2, floor(float(BlkSize) / 8.0) * 2)
Position = default(Position, false)

# -------------------------------------------------------------------------------

Assert((0 <= Frame <= EndFrame), \
RFX + string(EndFrame, " The range for Frame is from 0 to %.0f (the final frame) ") + chr(10))
Assert(DupP || DupN || (Mode == "Blend") || (Mode == "MFlow") || (Mode == "MBlock") || FRC, \
RFX + """ Mode="""" + Mode + """" is an invalid mode """ + chr(10) + " Valid modes are" + chr(10) + \
""" "Dup", "DupP", "DupN", "Blend", "FRC", "FRCEX", "FRCMIX", "MFlow" & "MBlock" """ + chr(10))
Assert((Replace > 0), RFX + " Replace must be greater than zero " + chr(10))
Assert((!DupP && !DupN) || (0 < Replace < 4), \
RFX + """ Replace can only equal 1, 2 or 3 when using the "Dup" DupP" or DupN" modes """ + chr(10))
Assert((Preset == "Slowest") || (Preset == "Slower") || (Preset == "Slow") || \
(Preset == "Normal") || (Preset == "Fast") || (Preset == "Faster") || (Preset == "Anime") || \
(Preset == "Rife") || (Preset == "RifeHQ") || (Preset == "RifeAnime"), \
RFX + """ Preset="""" + Preset + """" is an invalid preset """ + chr(10) + " Valid presets are " + chr(10) + \
""" "Slowest", "Slower", "Slow", "Normal", "Fast", "Faster", "Anime", "Rife", "RifeHQ" & "RifeAnime" """ + chr(10))
Assert((Mode != "FRC") || ((Preset != "Rife") && (Preset != "RifeHQ") && (Preset != "RifeAnime")), \
RFX + " The Rife presets can only be used with the EX and MIX versions of FrameRateConverter " + chr(10))
Assert((Frame > 0) || ((Replace == 1) && DupN), \
RFX + """ Can't replace the first frame unless Replace=1 & Mode="DupN" """ + chr(10))
Assert((Frame < EndFrame) || ((Replace == 1) && DupP), \
RFX + """ Can't replace the final frame unless Replace=1 & Mode="DupP" (or "Dup") """ + chr(10))
Assert((Frame == EndFrame) || ((Frame + Replace) < EndFrame), \
RFX + string(EndFrame - 1, " Frame + Replace can't exceed the 2nd last frame number (%.0f) ") + chr(10) + \
""" although the last frame can be replaced when Mode="Dup" and Replace=1 """ + chr(10))

# -------------------------------------------------------------------------------

Size = !Position ? nop() : min(width(Source) * 0.045, SourceHeight * ((SourceHeight < 300) ? 0.045 : \
(SourceHeight < 400) ? 0.044 : (SourceHeight < 500) ? 0.042 : (SourceHeight < 600) ? 0.0435 : 0.0345))

PositionVideo = !Position ? Video : GScriptClip(Video, """
subtitle(string(current_frame, "%.0f"), y=Size, size=Size, text_color=$F0FFFF, align=8)  """, args="Size")

Start = PositionVideo.Trim(0, end=PrevFrame)
End = PositionVideo.Trim(NextFrame, 0)
PrevDup = Video.Trim(PrevFrame, -1)
NextDup = Video.Trim(NextFrame, -1)
Trimmed = (PrevDup + NextDup).AssumeScaledFPS(divisor=Replace + 1)

# -------------------------------------------------------------------------------

(Mode == "MFlow") || (Mode == "MBlock") ?  Eval("""

S = Trimmed.MSuper(pel=2, hpad=0, vpad=0, rfilter=4)
Bvec1 = MAnalyse(S, chroma=false, isb=true, blksize=BlkSize, search=3, searchparam=3, plevel=0, badrange=-24)
Fvec1 = MAnalyse(S, chroma=false, isb=false, blksize=BlkSize, search=3, searchparam=3, plevel=0, badrange=-24)
Bvec2 = MRecalculate(S, chroma=false, Bvec1, blksize=BlkSize2, search=3, searchparam=1)
Fvec2 = MRecalculate(S, chroma=false, Fvec1, blksize=BlkSize2, search=3, searchparam=1)
Bvec3 = MRecalculate(S, chroma=false, Bvec2, blksize=BlkSize3, search=3, searchparam=0)
Fvec3 = MRecalculate(S, chroma=false, Fvec2, blksize=BlkSize3, search=3, searchparam=0)

""", "MVToolsFPS Eval") : nop()

# -------------------------------------------------------------------------------

RepairedFrames = DupP || DupN ? \
((Replace == 1) ? (DupP ? PrevDup : NextDup) : (Replace == 2) ? PrevDup + NextDup : \
DupP ? PrevDup + PrevDup + NextDup : PrevDup + NextDup + NextDup) : \
(Mode == "Blend") ? Trimmed.ConvertFPS(Num, Den) : \
(Mode == "FRC") ? ((Replace > 1) ? \
Trimmed.FrameRateConverter(NewNum=Num, NewDen=Den, preset=Preset, BlkSize=BlkSize) : \
Trimmed.FrameRateConverter(FrameDouble=true, preset=Preset, BlkSize=BlkSize)) : \
(Mode == "FRCEX") ? ((Replace > 1) ? \
Trimmed.FrameRateConverterEX(NewNum=Num, NewDen=Den, preset=Preset, BlkSize=BlkSize) : \
Trimmed.FrameRateConverterEX(FrameDouble=true, preset=Preset, BlkSize=BlkSize)) : \
(Mode == "FRCMIX") ? ((Replace > 1) ? \
Trimmed.FrameRateConverterMIX(NewNum=Num, NewDen=Den, preset=Preset, BlkSize=BlkSize) : \
Trimmed.FrameRateConverterMIX(FrameDouble=true, preset=Preset, BlkSize=BlkSize)) : \
(Mode == "MFlow") ?  \
Trimmed.MFlowFPS(S, Bvec3, Fvec3, blend=false, num=Num, den=Den) : \
Trimmed.MBlockFPS(S, Bvec3, Fvec3, blend=false, num=Num, den=Den, mode=0)

RepairedFrames = DupP || DupN ? RepairedFrames : RepairedFrames.AssumeFPS(Num, Den).Trim(1, Replace)

Replaced = (0 < Frame < EndFrame) ? Start + RepairedFrames + End : \
(Frame == 0) ? RepairedFrames + End : Start + RepairedFrames

return !HasAudio(Source) ? Replaced : AudioDub(Replaced, Audio)  }

# ===============================================================================
# ===============================================================================