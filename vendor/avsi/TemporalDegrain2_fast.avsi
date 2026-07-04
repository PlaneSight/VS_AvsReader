#                    Temporal Degrain 2 fast
#
# Based on TemporalDegrainV2
# https://forum.doom9.org/showthread.php?t=175798
#
# Needed plugins:
#   neo_FFT3D        https://github.com/HomeOfAviSynthPlusEvolution/neo_FFT3D
#   MaskTools2       https://github.com/pinterf/masktools
#   MVTools2         https://github.com/pinterf/mvtools
#   RgTools          https://github.com/pinterf/RgTools
#   vsDeGrainMedian  https://github.com/Asd-g/AviSynth-vsDeGrainMedian
#
# Usage Default:
#   TemporalDegrain2_fast(Strength=3, Y=3, U=3, V=3, RadT=1, Sharp=0.6, postMix=0)


function TemporalDegrain2_fast (clip input, int "Strength", int "Y", int "U", int "V", int "RadT", float "Sharp", float "PostMix") {
Strength = Default(Strength, 3) # Noise/grain suppression strength. Depth noise (< 2), low (3 ... 5), medium (6 ... 9), high (10 ... 14), veryhigh (> 15)
Y        = Default(Y, 3)        # Luma plane to process. Value: 2 - copy from input, 3 - process
U        = Default(U, Y)        # Chroma plane to process. Value: 2 - copy from input, 3 - process
V        = Default(V, U)        # Chroma plane to process. Value: 2 - copy from input, 3 - process
RadT     = Default(RadT, 1)     # Temporal Radius of frame analysis. Value 1 or 2
Sharp    = Default(Sharp, 0.6)  # Sharpening strength. Range: 0 ... 1
PostMix  = Default(PostMix, 0)  # How much noise/grain will be returned. Range: 0 ... 1

func_name = "TemporalDegrain2_fast: "
Assert(Y == 2 || Y == 3, func_name+"Luma Y plane must be 2 or 3")
Assert(U == 2 || U == 3, func_name+"Chroma U plane must be 2 or 3")
Assert(V == 2 || V == 3, func_name+"Chroma V plane must be 2 or 3")
Assert(Y == 3 || U == 3 || V == 3, func_name+"One of the planes Y, U, V must be 3")
Assert(RadT == 1 || RadT == 2, func_name+"Temporal Radius of frame analysis must be 1 or 2")
Assert(Sharp >= 0 && Sharp <= 1, func_name+"Sharpening strength must be between 0 and 1.0")
Assert(PostMix >= 0 && PostMix <= 1, func_name+"The noise return value must be between 0 and 1.0")

dPlane = Y==3 && (U==3 || V==3) ? 4
     \ : Y==3 && U==2 && V==2   ? 0
     \ : Y==2 && U==3 && V==2   ? 1
     \ : Y==2 && U==2 && V==3   ? 2
     \ : Y==2 && U==3 && V==3   ? 3 : 4
Blksz = 16
OLap = Blksz/2
pad = Max(Blksz, 8)
pel = 1

# denoising 1st way
dgLimit = input.neo_fft3d(sigma=Strength, bt=RadT==1?3:5, Y=Y, U=U, V=V) #, ncpu=4, mt=true)
dgSpatD = mt_makediff(input, dgLimit, Y=Y, U=U, V=V)

# denoising 2nd way
dgNR1  = dgLimit.vsDeGrainMedian(modeY=0, limitY=Strength, limitU=U==3?Strength+2:0, limitV=V==3?Strength+2:0)
dgNR1D = mt_makediff(input, dgNR1, Y=Y, U=U, V=V)

# combine 1st and 2nd ways
dgDD   = mt_lutxy(dgSpatD, dgNR1D, "x range_half - abs y range_half - abs < x y ?", Y=Y, U=U, V=V, use_expr=2)
dgNR1x = mt_makediff(input, dgDD, Y=Y, U=U, V=V)

# sharpen the edges only
dgNR1x = Sharp > 0 ? mt_merge(dgNR1x, \
                              dgNR1x.RemoveGrain(17).Sharpen(Sharp), \
                              dgNR1x.RemoveGrain(11).mt_edge("prewitt", Y=3, U=2, V=2).mt_inpand(chroma="-128").Blur(1.58), \
                              Y=3, U=2, V=2)
                 \ : dgNR1x

# denoising 3rd way
sup      = dgNR1x.Blur(1.58).Blur(1.58).MSuper(hpad=pad, vpad=pad, pel=pel, chroma=U==3||V==3?true:false)
MultiVec = MAnalyse(sup, multi=true, delta=RadT, blksize=Blksz, overlap=OLap, search=5, dct=7, chroma=U==3||V==3?true:false, truemotion=true, global=true)
dgNR1xS  = MSuper(dgNR1x, hpad=pad, vpad=pad, pel=pel, levels=1, chroma=U==3||V==3?true:false)
dgNR2    = MDegrainN(dgNR1x, dgNR1xS, MultiVec, RadT, plane=dPlane)

# combine 1st, 2nd and 3rd ways
dgDD2 = mt_lutxy(dgNR1x, dgNR2, "x range_half - abs y range_half - abs < x y ?", Y=Y, U=U, V=V, use_expr=2)

# post denoising
# dgNR3 = dgDD2.RemoveGrain(17)
# dgDD2 = mt_lutxy(dgNR3, dgDD2, "x range_half - abs y range_half - abs < x y ?", Y=Y, U=U, V=V, use_expr=2)

# sharpening
allD = Sharp > 0 ? mt_makediff(input.Sharpen(1), dgDD2.Blur(1.58).Blur(1.58)) : NOP()
ssD  = Sharp > 0 ? mt_makediff(dgDD2, dgDD2.RemoveGrain(20,-1)) : NOP()
ssDD = Sharp > 0 ? mt_lutxy(ssD.Repair(allD, 12), ssD, "x range_half - abs y range_half - abs < x y ?", Y=Y, U=U, V=V, use_expr=2) : NOP()
# out  = mt_adddiff(dgDD2, ssDD, Y=3, U=2, V=2)
out  = Sharp > 0 ? mt_lutxy(dgDD2, ssDD, "x range_half y - "+String(Sharp)+" * -", Y=3, U=2, V=2, use_expr=2) : dgDD2

PostMix > 0 ? mt_lutxy(out, input, "x x y - "+String(PostMix)+" * -", Y=Y, U=U, V=V, use_expr=2) : out
}
