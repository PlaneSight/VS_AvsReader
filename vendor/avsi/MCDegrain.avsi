/*
  McDegrain(), by Didee.            https://forum.doom9.org/showthread.php?p=1508289#post1508289

  Mods by StainlessS.
  v1.02, 17 Feb 2020. Added Limit, LimitC. BlkSz based on frame size.
  v1.04, 21 Oct 2020, Add args bblur, Pel, Chroma, BlkSz, OLap, Plane, Tm, Glob, ThSAD and ThSAD2.
  v1.05, 01 Nov 2020, If Colorspace 8 bit, force Limit/LimitC args to type Int.

  McDegrain(clip c, int "frames"=2, Float "Limit"=255, Float "LimitC"=Limit,
    \ float "bblur"=0.0,int "Pel"=2,  bool "Chroma"=True,Int "BlkSz",Int "Olap"=BlkSz/2, Int "Plane"=4,
    \ bool "Tm"=True,Bool "glob"=tm, Int "ThSAD"=400,Int "ThSAD2"=ThSAD)

    Frames,   Default 2 (1 or more, was 3 max). Temporal radius of frames processed, default as per MDegrain2.
    Limit,    Default 255 [no limit]. Limits amount of change to pixel luma.
    LimitC,   Default Limit. Limits amount of change to pixel Chroma.
              Default Limit/LimitC is 255 (int), but allows input eg 255.0 (Float)
                Pinterf MvTools v2.7.42 (20200522) changed MDegrainN Limit/LimitC types to Float.
                If Colorspace is 8 bit, then will force any user supplied float value to eg Int(Limit) or Int(LimitC).
                Will still be a problem (throw error in mvtools) if High Bit Depth, Float Limit/LimitC, and pre-Printerf v2.7.42 MvTools.
    bblur,    Default 0.0[OFF], Range 0.0 <= bblur <= 1.58. Blur prefilter for Super clip. Suggest about 0.6
              If bblur < 0.0, then will set bblur based on frame size, (c.width>1920) ? 0.75 : (c.width>1280) ? 0.7 : (c.width>960 ) ? 0.65 : 0.6)
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

Function McDegrain(clip c, int "frames",
    \ Float "Limit",Float "LimitC",
    \ float "bblur", int "Pel",bool "Chroma", Int "BlkSz",Int "OLap",Int "Plane",bool "Tm",Bool "glob", Int "ThSAD",Int "ThSAD2") {
    Function __McDegrain_bpc(clip c) {try {bpc=c.bpc} catch(mes) {bpc=8} return bpc}
    myName = "McDegrain: "
    frames = Default(frames, 2)
    Limit  = Default(Limit,255)
    LimitC = Default(LimitC,Limit) # Default Limit/LimitC is 255 (int)
             Limit =(c.__McDegrain_bpc==8)?Limit.Int :Limit    # Force Limit/LimitC to type int if Colorspace is 8 bit
             LimitC=(c.__McDegrain_bpc==8)?LimitC.Int:LimitC
    bblur  = Default(bblur,0.0)    # Denoising for Super Clip.
    bblur  = (bblur>=0.0) ? bblur : (c.width>1920) ? 0.75 : (c.width>1280) ? 0.7 : (c.width>960 ) ? 0.65 : 0.6
    pel    = Default(pel,2)
    chroma = Default(chroma,true)  # Use chroma in MAnalyse for vectors
    BlkSz  = Default(BlkSz,(c.width>1920) ? 32 : (c.width>1280) ? 24 : (c.width>960 ) ? 16 : 8)
    OLap   = Default(OLap,BlkSz/2)
    Plane  = Default(Plane,4)
    tm     = Default(tm,true)       # TrueMotion
    Glob   = Default(glob,Tm)       # Default Tm, Allow set MAnalyse(global) independently of TrueMotion.
    ThSAD  = Default(ThSAD,400)
    ThSAD2 = Default(ThSAD2,ThSAD)
    Assert(0.0 <= bblur <= 1.58, myName + "0.0 <= bblur <= 1.58")
    Assert(pel==1 || pel==2 || pel==4, myName + "pel==1 || pel==2 || pel==4")
    Assert(0 <= Plane <= 4, myName + "0 <= Plane <= 4")
    super      = (bblur==0.0  ? c : c.blur(bblur)).MSuper(pel=pel, sharp=1)
    super_rend = (bblur==0.0) ? super : c.MSuper(pel=pel, sharp=1,Levels=1) # Only 1 Level required for rendering Super (not MAnalyse-ing)
    MultiVec = super.MAnalyse(multi=true,delta=frames,blksize=BlkSz,overlap=OLap,chroma=Chroma,truemotion=Tm,global=Glob)
    (frames<=0)
        \ ? c
        \ : c.MDegrainN(super_rend, MultiVec, Frames, thSAD=ThSAD, plane=Plane, Limit=Limit, LimitC=LimitC, thsad2=ThSAD2)
    return Last
}
