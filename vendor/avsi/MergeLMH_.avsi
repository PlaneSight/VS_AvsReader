# Changelog:
# High bit depth support


# A script that allows you to Tweak (or anything else) the midrange tones only, leaving highlights and lowlights alone.

## Last = YUV

## DEMO - FRAME STEP ONLY
#return Interleave(
#\   Subtitle("org"),
#\   Tweak(sat=1.5) /* exaggerated for testing */
#\     .Subtitle("Tweak"),
#\   MergeLMH(C_mid=Tweak(sat=1.7)) /* same apparent sat (+/-) */
#\     .Subtitle("MergeLMH"),
#\   Subtitle("org")
#\ ).Loop(3).Histogram("color2")

#######################################
### merge Lo, Mid, Hi clips based on clip "C" luma
### requires MaskTools v2
##
## @ xover_x   - aproximate 50% luma blend between ranges 
##                  default 102 (40%), 191 (75%)
## @ showmasks - if true, show original + 3 masks in quad split
##
function MergeLMH(clip C, clip "C_lo", clip "C_mid", clip "C_hi",
\           float "xover_lomid", float "xover_midhi",
\           bool "showmasks", bool "full_range")
{
    xlo        = Min(Max(  0, Default(xover_lomid, 102)), 127) * 3.0 / 256
    xhi        = Min(Max(128, Default(xover_midhi, 191)), 255) * 3.0 / 256
    showmasks  = Default(showmasks, false)
    full_range = Default(full_range, false)
    
    range = full_range ? "allf" : "all"

    ## (mt_lutxyz too slow; use mt_lut x3)

    mask_lo  = C.mt_lut(
    \   yexpr="x -0.01 * "+String(xlo)+" + 256 * ",
    \   u=-128, v=-128, scale_inputs=range, clamp_float=true)
    
    mask_hi  = C.mt_lut(
    \   yexpr="1 x -0.01 * "+String(xhi)+" + - 256 * ",
    \   u=-128, v=-128, scale_inputs=range, clamp_float=true)
    
    mask_mid = mt_lutxy(mask_lo, mask_hi, 
    \   "x  y + -1 * 256 + ", 
    \   u=-128, v=-128, scale_inputs=range, clamp_float=true)

    R = C
    R = (!IsClip(C_lo))  ? R : R.Overlay(C_lo,  mask=mask_lo)
    R = (!IsClip(C_mid)) ? R : R.Overlay(C_mid, mask=mask_mid)
    R = (!IsClip(C_hi))  ? R : R.Overlay(C_hi,  mask=mask_hi)
    
    return (showmasks==false) ? R
    \  : StackVertical(
    \       StackHorizontal(C, mask_lo),
    \       StackHorizontal(mask_mid, mask_hi)
    \    ).BilinearResize(C.Width, C.height)
    \     .Subtitle("Low",    align=9)
    \     .Subtitle("\nMid",  align=4, lsp=0)
    \     .Subtitle("\nHigh", align=6, lsp=0)
}
