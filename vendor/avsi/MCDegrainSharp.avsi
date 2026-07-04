/*
  McDegrainSharp(), by StainlessS.
  Original post:-                                   https://forum.doom9.org/showthread.php?p=1508635#post1508635
  Earlier mods:-                                    https://forum.doom9.org/showthread.php?p=1737045#post1737045
  Based on MCDegrain By Didee,                      https://forum.doom9.org/showthread.php?p=1508289#post1508289
  Also based on DiDee observations in this thread:  http://forum.doom9.org/showthread.php?t=161580
    "Denoise with MDegrainX, do slight sharpening where motionmatch is good, do slight blurring where motionmatch is bad"
    In areas where MAnalyse cannot find good matches, the blur() will be dominant.
    In areas where good matches are found, the sharpen()'ed pixels will overweight the blur()'ed pixels
    when the pixel averaging is performed.

  McDegrainSharp(clip c, int "frames"=2, float "bblur", float "csharp"=0.6, bool "bsrch"=True, bool "Precise"=False, Float "Limit"=255, Float "LimitC"=Limit,
    \ int "Pel"=2,  bool "Chroma"=True,Int "BlkSz",Int "Olap"=BlkSz/2, Int "Plane"=4,bool "Tm"=True,Bool "glob"=tm, Int "ThSAD"=400,Int "ThSAD2"=ThSAD)

  v1.02, 17 Feb 2020. Default bblur mod for HD. BlkSz (blocksize) mod for HD. Added Limit, LimitC. 17 Feb 2020.
  v1.04, 21 Oct 2020. Add args Pel, Chroma, BlkSz, OLap, Plane, Tm, Glob, ThSAD and ThSAD2.
  v1.05, 01 Nov 2020, If Colorspace 8 bit, force Limit/LimitC args to type Int.

    Frames,   Default 2 (1 or more, was 3 max). Temporal radius of frames processed, default as per MDegrain2.
    bblur,    Blur arg used for both MSuper pre-filter clip (bsrch==true) and blurring used where motion match is bad.
              Range 0.0 <= bblur <= 1.58.
              Default depends upon source clip width. (c.width>1920) ? 0.75 : (c.width>1280) ? 0.7 : (c.width>960 ) ? 0.65 : 0.6)
    csharp,   Default 0.6, (0.0 <= csharp <= 1.0) Sharpening used where motion match is good.
    bsrch,    Default True. If true, then prefilter clip is blurred source clip, c.blur(bblur).
    Precise,  Default false. If true, then uses MRecalculate to refine vectors.
    Limit,    Default 255 [no limit]. Limits amount of change to pixel luma.
    LimitC,   Default Limit. Limits amount of change to pixel Chroma.
              Default Limit/LimitC is 255 (int), but allows input eg 255.0 (Float)
                Pinterf MvTools v2.7.42 (20200522) changed MDegrainN Limit/LimitC types to Float.
                If Colorspace is 8 bit, then will force any user supplied float value to eg Int(Limit) or Int(LimitC).
                Will still be a problem (throw error in mvtools) if High Bit Depth, Float Limit/LimitC, and pre-Printerf v2.7.42 MvTools.
    Pel,      Default 2. 1 may be better and faster for HD content.
    Chroma,   Default true. Set to true, it allows to take chroma into account when doing the motion estimation (false: luma only).
    BlkSz,    Block size used for MAnalyse. 8 <= BlkSz, ideally power of 2, at least multiple of 4.
              Default depends upon source clip width. (c.width>1920) ? 32 : (c.width>1280) ? 24 : (c.width>960 ) ? 16 : 8
    OLap,     Default half BlkSz, Block overlap.
    Plane,    Used by MDegrainN, color planes processed. 0=Luma, 1=Chroma U, 2=Chroma V, 3=Both chromas, 4=All Planes.
    Tm,       (truemotion) Default true. Arg to MAnalyse. Number of users believe false is better especially for larger blocksize and HD.
    Glob,     Global, Default tm. Allow set MAnalyse(global) independently of TrueMotion. Suggest always true.
    ThSAD     Default 400.
              Defines the soft threshold of block sum absolute differences.
              Block with SAD above threshold thSAD have a zero weight for averaging (denoising).
              Block with low SAD has highest weight.
              Rest of weight is taken from pixels of source clip.
              The provided thSAD value is scaled to a 8x8 blocksize.
              Low values can result in staggered denoising, large values can result in ghosting and artifacts.
    ThSAD2    Default ThSAD.
              Parameter is for MDegrainN, defines the SAD soft threshold for the furthest frames.
              The actual SAD threshold for each reference frame is a smooth interpolation between the original thSAD (close to the current frame) and thSAD2.
              Setting thSAD2 lower than thSAD allows large temporal radii and good efficiency for low SAD blocks while reducing the risk of bluring.

*/


Function McDegrainSharp(clip c, int "frames", float "bblur", float "csharp", bool "bsrch",bool "Precise",Float "Limit",Float "LimitC",
    \ int "Pel",bool "Chroma", Int "BlkSz",Int "OLap",Int "Plane",bool "Tm",Bool "glob", Int "ThSAD",Int "ThSAD2") {
    Function __McDegrainSharp_bpc(clip c) {try {bpc=c.bpc} catch(mes) {bpc=8} return bpc}
    myName = "McDegrainSharp: "
    frames = Default(frames, 2)
    bblur  = Default(bblur, (c.width>1920) ? 0.75 : (c.width>1280) ? 0.7 : (c.width>960 ) ? 0.65 : 0.6)
    csharp = Default(csharp, 0.6)
    bsrch  = Default(bsrch, true)
    Precise= Default(Precise,False)  # Use MRecalculate
    Limit  = Default(Limit,255)      # Max allowed Y change, Arg to MDegrainN. Default Limit/LimitC is 255 (int)
    LimitC = Default(LimitC,Limit)   # Max allowed U,V change
             Limit =(c.__McDegrainSharp_bpc==8)?Limit.Int :Limit    # Force Limit/LimitC to type int if Colorspace is 8 bit
             LimitC=(c.__McDegrainSharp_bpc==8)?LimitC.Int:LimitC
    pel    = Default(pel,2)
    chroma = Default(chroma,true)    # Use chroma in MAnalyse for vectors
    BlkSz  = Default(BlkSz,(c.width>1920) ? 32 : (c.width>1280) ? 24 : (c.width>960 ) ? 16 : 8)
    OLap   = Default(OLap,BlkSz/2)
    Plane  = Default(Plane,4)
    tm     = Default(tm,true)        # TrueMotion
    Glob   = Default(glob,Tm)        # Default Tm, Allow set MAnalyse(global) independently of TrueMotion.
    ThSAD  = Default(ThSAD,400)
    ThSAD2 = Default(ThSAD2,ThSAD)
    Assert(0.0 <= bblur <= 1.58, myName + "0.0 <= bblur <= 1.58")
    Assert(0.0 <= csharp <= 1.0, myName + "0.0 <= csharp <= 1.0")
    Assert(pel==1 || pel==2 || pel==4, myName + "pel==1 || pel==2 || pel==4")
    Assert(0 <= Plane <= 4, myName + "0 <= Plane <= 4")
    c2          = c.blur(bblur)
    super       = bsrch ? c2.MSuper(pel=pel, sharp=1) : c.MSuper(pel=pel, sharp=1)
    super_rend  = c.sharpen(csharp).MSuper(pel=pel, sharp=1,levels=1)   # Only 1 Level required for sharpened Super (not MAnalyse-ing)
    MultiVec    = super.MAnalyse(multi=true,delta=frames,blksize=BlkSz,overlap=OLap,chroma=Chroma,truemotion=Tm,global=Glob)
    # If Precise, then recalculate on Prefiltered (blurred) Super (NOT the sharpened render super)
    MultiVec = (Precise)
        \ ? super.MRecalculate(MultiVec,blksize=BlkSz/2,overlap=OLap/2,thSAD=100,chroma=chroma,truemotion=tm,global=Glob, tr=frames)
        \ : MultiVec
    (frames<=0)
        \ ? c
        \ : c2.MDegrainN(super_rend, MultiVec, Frames, thSAD=ThSAD, plane=Plane, Limit=Limit, LimitC=LimitC, thsad2=ThSAD2)
    return Last
}
