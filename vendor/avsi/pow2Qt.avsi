##################################
### Antialiasing (AA) for game footage
### (blending nnedi3_rpow2 & QTGMC) 
##
## @ sharpen - post-process Sharpen to mitigate QTGMC smoothing
##             (on double-size image, so apparent effect is 1/2)
##             (0.2-0.3 best in initial tests; default 0.3)
## @ cpoint  - upscale pass2 chroma with PointResize (sharper)
## @ doublesize - 2x enlargement, but AA less effective
##
## v0.42.02 - support RGB32, RGB24, Y8 (and YV12 as before)
##
function pow2Qt(clip C, float "sharpen", bool "doublesize", bool "cpoint")
{
    Assert(C.IsRGB || C.IsYV12 || C.IsY8, 
    \   "pow2Qt: source must be RGB, YV12 or Y8")

    shp = Default(sharpen, 0.0)
    dbl = Default(doublesize, false)
    cpt = Default(cpoint, false)

    return 
    \   (C.IsYV12) ? C._pow2QtYV12(sharpen, doublesize, cpoint)
    \ : (C.IsY8)   ? C._pow2QtY8  (sharpen, doublesize)
    \ :              C._pow2QtRGB (sharpen, doublesize)
    ## Y8   : 25 fps
    ## YV12 : 13 fps
    ## RGB24:  8 fps
    ## RGB32:  7 fps
}
##################################
function _pow2QtYV12(clip C, float "sharpen", bool "doublesize", bool "cpoint")
{
    Assert(C.IsYV12, "_pow2QtYV12: source must be YV12")

    shp = Default(sharpen, 0.3)
    cpt = Default(cpoint, false)
    dbl = Default(doublesize, false)

    C
    wid = Width
    hgt = Height

    ## pass 1: nnedi3 double size, scale back

    Y  = nnedi3_rpow2(rfactor=2, nsize=0, nns=3, qual=2, 
    \                 cshift="Spline64Resize")    
    UV = (cpt) 
    \  ? PointResize(2*wid, 2*hgt, src_top=0.25)
    \  : Spline64Resize(2*wid, 2*hgt, src_left=+0.5, src_top=+0.5)
    YToUV(UV.UToY, UV.VToY, Y.ConvertToY8)

    BicubicResize(wid, hgt, b=-1, c=0, src_left=-0.5, src_top=+0.5)

    ## pass 2: nnedi3 double size, QTGMC de-shimmer, sharpen, scale back

    Y = nnedi3_rpow2(rfactor=2, nsize=0, nns=3, qual=2, 
    \                 cshift="Spline64Resize") 
    UV = (cpt) 
    \  ? PointResize(2*wid, 2*hgt, src_top=0.25)
    \  : Spline64Resize(2*wid, 2*hgt, src_left=-0.5, src_top=-0.5)
    YToUV(UV.UToY, UV.VToY, Y.ConvertToY8)
    
    QTGMC(preset="Medium", InputType=1)
    Sharpen(shp)

    return (dbl) 
    \  ? Last 
    \  : BicubicResize(wid, hgt, b=-1, c=0, src_left=0.5, src_top=-0.5)
}
##################################
function _pow2QtY8(clip C, float "sharpen", bool "doublesize")
{
    Assert(C.IsY8, "_pow2QtY8: source must be Y8")

    shp = Default(sharpen, 0.3)
    dbl = Default(doublesize, false)

    C
    wid = Width
    hgt = Height

    ## pass 1: nnedi3 double size, scale back 

    ConvertToYV12
    ### {
        nnedi3_rpow2(rfactor=2, nsize=0, nns=3, qual=2, 
        \            cshift="Spline64Resize")    

        BicubicResize(wid, hgt, b=-1, c=0) #, src_left=-0.5, src_top=+0.5)

        ## pass 2: nnedi3 double size, QTGMC de-shimmer, sharpen, scale back

        nnedi3_rpow2(rfactor=2, nsize=0, nns=3, qual=2, 
        \             cshift="Spline64Resize") 

        QTGMC(preset="Medium", InputType=1, RepChroma=false)
    ### }
    ConvertToY8
    Sharpen(shp)

    return (dbl) 
    \ ? Last 
    \ : BicubicResize(wid, hgt, b=-1, c=0) #, src_left=0.5, src_top=-0.5)
}
##################################
function _pow2QtRGB(clip C, float "sharpen", bool "doublesize")
{
    Assert(C.IsRGB, "_pow2QtRGB: source must be RGB")

    shp = Default(sharpen, 0.3)
    dbl = Default(doublesize, false)

    return (C.IsRGB32) 
    \ ? MergeARGB(
    \       C.ShowAlpha("Y8")._pow2QtY8(sharpen, doublesize),
    \       C.ShowRed  ("Y8")._pow2QtY8(sharpen, doublesize),
    \       C.ShowGreen("Y8")._pow2QtY8(sharpen, doublesize),
    \       C.ShowBlue ("Y8")._pow2QtY8(sharpen, doublesize)
    \   )
    \ : MergeRGB(
    \       C.ShowRed  ("Y8")._pow2QtY8(sharpen, doublesize),
    \       C.ShowGreen("Y8")._pow2QtY8(sharpen, doublesize),
    \       C.ShowBlue ("Y8")._pow2QtY8(sharpen, doublesize),
    \       pixel_type="RGB24"
    \   )
}