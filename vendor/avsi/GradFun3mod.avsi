##################################################################################################################
#
#	High bitdepth tools for Avisynth - GradFun3mod r6 mod 3.1
#       based on Dither v1.27.1
#	Author: Firesledge, slightly modified by Gebbi
#
#  What?
#       - This is a slightly modified version of the original GradFun3.
#       - It combines the usual color banding removal stuff with resizers during the process
#         for sexier results (less detail loss, especially for downscales of cartoons).
#       - This is a starter script, not everything is covered through parameters. Modify it to your needs.
#
#	Requirements (in addition to the Dither requirements):
#       - AviSynth 2.6.x
#       - Debilinear, Debicubic, DebilinearM
#       - NNEDI3 + nnedi3_resize16
#
#  Changes from the original GradFun3:
#       - yuv444 = true
#         (4:2:0 -> 4:4:4 colorspace conversion, needs 1920x1080 input)
#       - resizer = [ "none", "Debilinear", "DebilinearMT", "DebilinearM", "DebilinearMTM", "Debicubic", "DebicubicMT", "DebicubicM", "DebicubicMTM", "Spline16",
#         "Spline36", "Spline64", "lineart_rpow2", "lineart_rpow2_bicubic", "lineart_rpow2MT", "lineart_rpow2_bicubicMT" ] 
#         (use it only for downscales)
#           NOTE: As of r2 Debicubic doesn't have 16-bit precision, so a Y (luma) plane fix by torch is used here,
#                 more info: https://mechaweaponsvidya.wordpress.com/2015/07/07/a-precise-debicubic/
#                 Without yuv444=true Dither_resize16 is used with an inverse bicubic kernel.
#       - w = 1280, h = 720
#         (output width & height for the resizers; or production resolution for resizer="lineart_rpow2")
#       - smode = 4
#         (the old GradFun3mod behaviour for legacy reasons; based on smode = 1 (dfttest);
#         not useful anymore in most cases, use smode = 2 instead (less detail loss))
#       - deb = true
#         (legacy parameter; same as resizer = "DebilinearM")
#
#  Usage examples:
#       - Source is bilinear 720p->1080p upscale (BD) with 1080p credits overlayed,
#         revert the upscale without fucking up the credits:
#               lwlibavvideosource("lol.m2ts")
#               GradFun3mod(smode=1, yuv444=true, resizer="DebilinearM")
#
#       - You just want to get rid off the banding without changing the resolution:
#               GradFun3(smode=2)
#
#       - Source is 1080p production (BD), downscale to 720p:
#               GradFun3mod(smode=2, yuv444=true, resizer="Spline36")
#
#       - Source is a HDTV transportstream (or CR or whatever), downscale to 720p:
#               GradFun3mod(smode=2, resizer="Spline36")
#
#       - Source is anime, 720p->1080p upscale, keep the resolution
#         but with smoother lineart instead of bilinear upscaled shit:
#               GradFun3mod(smode=2, resizer="lineart_rpow2")
#         This won't actually resize the video but instead mask the lineart and re-upscale it using
#         nnedi3_rpow2 which often results in much better looking lineart (script mostly by Daiz).
#
#       Note: Those examples don't include parameters like thr, radius, elast, mode, ampo, ampn, staticnoise.
#             You probably don't want to use the default values.
#             For 16-bit output use:
#              GradFun3mod(lsb=true).Dither_out()
#
#  What's the production resolution of my korean cartoon?
#       - Use your eyes combined with Debilinear(1280,720) - if it looks like oversharped shit,
#         it was probably produced in a higher resolution.
#       - Use Debilinear(1280,720).BilinearResize(1920,1080) for detail loss search.
#       - Alternatively you can lookup the (estimated) production resolution at
#         http://anibin.blogspot.com  (but don't blindly trust those results)
#
#	This program is free software. It comes without any warranty, to
#	the extent permitted by applicable law. You can redistribute it
#	and/or modify it under the terms of the Do What The Fuck You Want
#	To Public License, Version 2, as published by Sam Hocevar. See
#	http://sam.zoy.org/wtfpl/COPYING for more details.
#
##################################################################################################################


Function GradFun3mod (clip src, float "thr", int "radius", float "elast",
\	int "mask", int "mode", float "ampo", float "ampn", int "pat",
\	bool "dyn", float "dthr", int "smode", float "wmin", float "thr_det",
\	float "thr_edg", int "debug", int "subspl", bool "lsb", bool "lsb_in",
\	bool "staticnoise", float "thrc", int "radiusc", float "elastc",
\	int "y", int "u", int "v", clip "ref", bool "slice", bool "yuv444", int "w", int "h", string "resizer", bool "deb")
{
	thr     = Default (thr,       0.35)
	thrc    = Default (thrc,       thr)
	radius  = Default (radius,      12)
	radiusc = Default (radiusc, radius)
	elast   = Default (elast,      3.0)
	elastc  = Default (elastc,   elast)
	mask    = Default (mask,         2)
	smode   = Default (smode,        2)
	wmin    = Default (wmin,       1.0)
	thr_det = Default (thr_det, 2 + Round (Dither_max (thr - 0.35, 0) / 0.3))
	debug   = Default (debug,        0)
	subspl  = Default (subspl,       0)
	lsb     = Default (lsb,      false)
	lsb_in  = Default (lsb_in,   false)
	ref     = Default (ref,        src)
	yuv444 = Default (yuv444, false)
	w = Default (w, 1280)
	h = Default (h, 720)
	resizer = Default (resizer, "none")
	deb = Default (deb, false)
	
	
	# Do lineart smoothing first for sharper results
	
	ow = src.Width()
	oh = src.Height()
	
	src = (resizer == "lineart_rpow2") ? lineart_rpow2(src, w, h, ow, oh, false, false)
\           : (resizer == "lineart_rpow2MT") ? lineart_rpow2(src, w, h, ow, oh, false, true)
\           : (resizer == "lineart_rpow2_bicubic") ? lineart_rpow2(src, w, h, ow, oh, true, false)
\           : (resizer == "lineart_rpow2_bicubicMT") ? lineart_rpow2(src, w, h, ow, oh, true, true)
\           : src

	# Input range check. The other parameters are checked by the plugins.
	Assert (radius  > 0, "GradFun3: "+chr(34)+"radius" +chr(34)+" must be strictly positive.")
	Assert (radiusc > 0, "GradFun3: "+chr(34)+"radiusc"+chr(34)+" must be strictly positive.")
	Assert (thr     > 0, "GradFun3: "+chr(34)+"thr"    +chr(34)+" must be strictly positive.")
	Assert (thrc    > 0, "GradFun3: "+chr(34)+"thrc"   +chr(34)+" must be strictly positive.")
	Assert (thr_det > 0, "GradFun3: "+chr(34)+"thr_det"+chr(34)+" must be strictly positive.")
	Assert (elast  >= 1, "GradFun3: "+chr(34)+"elast"  +chr(34)+" must be greater or equal to 1.")
	Assert (elastc >= 1, "GradFun3: "+chr(34)+"elastc" +chr(34)+" must be greater or equal to 1.")
	(yuv444 && resizer != "lineart_rpow2" && resizer != "lineart_rpow2_bicubic" && resizer != "lineart_rpow2MT" && resizer != "lineart_rpow2_bicubicMT") ? Assert (w == 1280, "GradFun3mod: Output resolution must be 1280x720 when using 4:4:4 colorspace.") : true
	(yuv444 && resizer != "lineart_rpow2" && resizer != "lineart_rpow2_bicubic" && resizer != "lineart_rpow2MT" && resizer != "lineart_rpow2_bicubicMT") ? Assert (h == 720, "GradFun3mod: Output resolution must be 1280x720 when using 4:4:4 colorspace.") : true

	src_8  = (lsb_in) ? src.DitherPost (mode=-1) : src
	src_16 = (lsb_in) ? src : src.Dither_convert_8_to_16 ()
	ref_16 = (lsb_in) ? ref : ref.Dither_convert_8_to_16 ()
	yv411_flag = src.Dither_isyv411 ()

	# Main debanding

	yp     = (! Defined (y) || (y == 3)) ? 3 : 1
	up     = (! Defined (u) || (u == 3)) ? 3 : 1
	vp     = (! Defined (v) || (v == 3)) ? 3 : 1

	chroma_flag = (  (thrc != thr || radiusc != radius || elastc != elast)
\	               && yp == 3 && (up == 3 || vp == 3))
	up2    = (chroma_flag) ? 1 : up
	vp2    = (chroma_flag) ? 1 : vp

	src_16
	flt_y  =                 Dither_gf3_smooth_mod (last, src_8, ref_16, smode, radius,  thr,  elast,  lsb_in, wmin, subspl, yp, up2, vp2)
	flt_c  = (chroma_flag) ? Dither_gf3_smooth_mod (last, src_8, ref_16, smode, radiusc, thrc, elastc, lsb_in, wmin, subspl, 1,  up,  vp) : flt_y
	flt    = (chroma_flag) ? flt_y.MergeChroma (flt_c) : flt_y

	# Edge/detail mask

	td_lo  = Dither_max (thr_det * 0.75, 1)
	td_hi  = Dither_max (thr_det,        1)
	mexpr  = Dither_make_expr_gate (td_lo, td_hi)

	dmask  = (mask > 0 && yv411_flag) ? src_8.ConvertToY8 ()       : src_8
	dmask  = (mask > 0) ? dmask.Dither_build_gf3_range_mask (mask) : dmask
	dmask  = (mask > 0) ? dmask.mt_lut (expr=mexpr)                : dmask
	dmask  = (mask > 0) ? dmask.Dither_removegrain_emul (22, -1)   : dmask
	dmask  = (mask > 1) ? dmask.Dither_removegrain_emul (11, -1)   : dmask
	dmask  = (mask > 2) ? dmask.Dither_removegrain_emul (20, -1)   : dmask
	dmask  = (mask > 0 && yv411_flag) ? dmask.ConvertToYV411 ()    : dmask

	res_16 = (mask > 0) ? Dither_merge16_8 (flt, src_16, dmask, luma=true, y=yp, u=up, v=vp) : flt

	# Resizing / colorspace conversion (GradFun3mod)
	
	resizer = (deb) ? "DebilinearM" : resizer
	resizer = (yuv444 && resizer == "none") ? "Spline36" : resizer
	
	rkernel = (resizer == "Debilinear" && yuv444) ? res_16.DebilinearY(w,h,lsb_inout=true)
\           : (resizer == "Debilinear") ? res_16.Debilinear(w,h,lsb_inout=true)
\           : (resizer == "DebilinearMT" && yuv444) ? res_16.ResizeX(w, h, desampling=true, kernel="Bilinear",lsb_in=true,lsb_out=true)
\           : (resizer == "DebilinearMT") ? res_16.ResizeX(w, h, desampling=true, kernel="Bilinear",lsb_in=true,lsb_out=true)
\           : (resizer == "DebilinearM" && yuv444) ? res_16.DebilinearM(w,h,lsb_inout=true,chroma=false)
\           : (resizer == "DebilinearM") ? res_16.DebilinearM(w,h,lsb_inout=true)
\           : (resizer == "DebilinearMTM" && yuv444) ? res_16.DebilinearM(w,h,lsb_inout=true,chroma=false, DeResizeMT=true)
\           : (resizer == "DebilinearMTM") ? res_16.DebilinearM(w,h,lsb_inout=true, DeResizeMT=true)
\           : (resizer == "Debicubic" && yuv444) ? res_16.debicubicy_precise(w,h)
\           : (resizer == "Debicubic") ? res_16.Dither_resize16(w,h,kernel="bicubic",invksh=true,fh=1.3,fv=1.3,invkstaps=7)
\           : (resizer == "DebicubicMT" && yuv444) ? res_16.debicubicy_precise(w,h, DeResizeMT=true)
\           : (resizer == "DebicubicMT") ? res_16.Dither_resize16(w,h,kernel="bicubic",invksh=true,fh=1.3,fv=1.3,invkstaps=7)
\           : (resizer == "DebicubicM" && yuv444) ? res_16.DebicubicM_precise16(w,h,chroma=false)
\           : (resizer == "DebicubicM") ? res_16.DebicubicM_precise16(w,h)
\           : (resizer == "DebicubicMMT" && yuv444) ? res_16.DebicubicM_precise16(w,h,chroma=false, DeResizeMT=true)
\           : (resizer == "DebicubicMMT") ? res_16.DebicubicM_precise16(w,h, DeResizeMT=true)
\           : (resizer == "Spline16" && yuv444) ? res_16.Dither_resize16(w,h,kernel="spline16",fh=1.2,fv=1.2).ConvertToY8()
\           : (resizer == "Spline16") ? res_16.Dither_resize16(w,h,kernel="spline16",fh=1.2,fv=1.2)
\           : (resizer == "Spline36" && yuv444) ? res_16.Dither_resize16(w,h,kernel="spline36",fh=1.2,fv=1.2).ConvertToY8()
\           : (resizer == "Spline36") ? res_16.Dither_resize16(w,h,kernel="spline36",fh=1.2,fv=1.2)
\           : (resizer == "Spline64" && yuv444) ? res_16.Dither_resize16(w,h,kernel="spline64",fh=1.2,fv=1.2).ConvertToY8()
\           : (resizer == "Spline64") ? res_16.Dither_resize16(w,h,kernel="spline64",fh=1.2,fv=1.2)
\           : ((resizer == "lineart_rpow2" || resizer == "lineart_rpow2_bicubic") && yuv444) ? res_16.Dither_resize16(1280,720,kernel="spline36",fh=1.2,fv=1.2).ConvertToY8()
\           : (resizer == "lineart_rpow2" || resizer == "lineart_rpow2_bicubic") ? res_16
\           : ((resizer == "lineart_rpow2MT" || resizer == "lineart_rpow2_bicubicMT") && yuv444) ? res_16.Dither_resize16(1280,720,kernel="spline36",fh=1.2,fv=1.2).ConvertToY8()
\           : (resizer == "lineart_rpow2MT" || resizer == "lineart_rpow2_bicubicMT") ? res_16
\           : (resizer == "none") ? res_16
\	         : Assert (false, "GradFun3mod: wrong resizer value.") 

    ly = rkernel
    lu = res_16.utoy8().Dither_resize16(1280, 720, src_left=0.25, kernel="blackman")
    lv = res_16.vtoy8().Dither_resize16(1280, 720, src_left=0.25, kernel="blackman")
    (yuv444) ? ytouv(lu,lv,ly) : rkernel  
	
	# Dithering

	result = (lsb) ? last : last.DitherPost (
\		mode=mode, ampo=ampo, ampn=ampn, pat=pat, dyn=dyn,
\		prot=false, thr=dthr, staticnoise=staticnoise,
\		y=yp, u=up, v=vp, slice=slice
\	)
	result = (lsb)
\		? Dither_switch_planes16 (src_16, result, y=y, u=u, v=v)
\		: Dither_switch_planes8  (src_8,  result, y=y, u=u, v=v)

	(debug == 1       ) ? dmask.GreyScale ()        : result
	(debug == 1 && lsb) ? Dither_convert_8_to_16 () : last
}



Function Dither_gf3_smooth_mod (clip src_16, clip src_8, clip ref_16, int smode, int radius, float thr, float elast, bool lsb_in, float wmin, int subspl, int yp, int up, int vp)
{
	src_16
	  (smode == 0) ? Dither_gf3_smoothgrad_multistage (ref_16, radius, thr, elast, yp, up, vp)
\	: (smode == 1) ? Dither_gf3_dfttest (src_8, ref_16, radius, thr, elast, lsb_in, yp, up, vp)
\	: (smode == 2) ? Dither_gf3_bilateral_multistage (ref_16, radius, thr, elast, wmin, subspl, yp, up, vp)
\	: (smode == 3) ? Dither_gf3_smoothgrad_multistage_3 (radius, thr, elast, yp, up, vp)
\  : (smode == 4) ? Dither_gf3_dfttest_mod (src_8, ref_16, radius, thr, elast, lsb_in, yp, up, vp)
\	:                Assert (false, "GradFun3mod: wrong smode value.") 
}



# Valid values for y, u and v: 1 and 3
Function Dither_gf3_dfttest_mod (clip src, clip src_8, clip ref,
\	int radius, float thr, float elast, bool lsb_in,
\	int y, int u, int v)
{
	Assert (radius <= 128, "GradFun3: max "+chr(34)+"radius" +chr(34)+" value is 128 when smode = 1.")

	hrad = Dither_max (radius * 3 / 4, 1)

	(lsb_in) ? src : src_8

	dfttest (
\		sigma=thr*12, tbsize=1,
\		sbsize=hrad*4, sosize=hrad*3,
\		lsb=true, lsb_in=lsb_in,
\		Y=(y==3), U=(u==3), V=(v==3)
\	)

	Dither_limit_dif16 (last, ref, thr=thr, elast=elast, y=y, u=u, v=v)
}

Function lineart_rpow2 (clip src, int w, int h, int ow, int oh, bool bicubic, bool DeResizeMT)
{
    w = default(w, 1280)
    h = default(h, 720)
    ow = default(ow, 1920)
    oh = default(oh, 1080)
    bicubic = default(bicubic, false)
    DeResizeMT = default(DeResizeMT, false)

    orig = src
    DeResizeMT ? ResizeX(src, w, h, desampling=true, kernel=bicubic ? "Bicubic" : "Bilinear") : (bicubic) ? DebicubicM(src, w, h) : DebilinearM(src, w, h)
    nnedi3_rpow2(2, cshift="Spline36Resize", fwidth=ow, fheight=oh)
    edges = last.mt_edge("prewitt", 4, 24, 4, 24, chroma="true").removegrain(20, 1)
    sharp = last
    mt_merge(orig, sharp, edges)
}

Function debicubicy_precise(clip src, int dst_width, int dst_height, float "src_left", float "src_top", float "src_width", float "src_height", bool "DeResizeMT")
{
    # script by torch
    
	sw = src.width()
	sh = src.height()/2
	src_left = default(src_left,   0.0)
	src_top = default(src_top,    0.0)
	src_width = default(src_width,  sw)
	src_height = default(src_height, sh)
	DeResizeMT = default(DeResizeMT, false)
	
	inv_left = -src_left * dst_width/src_width
	inv_top = -src_top * dst_height/src_height
	inv_width = (sw-src_left) * dst_width/src_width
	inv_height = (sh-src_top) * dst_height/src_height
	
	seed = DeResizeMT ? ResizeX(src, dst_width, dst_height, src_left, src_top, src_width+src_left, src_height+src_top, chroma=false, desampling=true, kernel="Bicubic", lsb_in=true, lsb_out=true) : debicubicy(src, dst_width, dst_height, src_left, src_top, src_width+src_left, src_height+src_top, lsb_inout=true)
	up = seed.dither_resize16(sw, sh, inv_left, inv_top, inv_width, inv_height, kernel="bicubic", fh=-1.0, fv=-1.0)
	diff = dither_sub16(src, up, dif=true).dither_lut16("x 32768 - 99 * 32768 +")
	down = DeResizeMT ? diff.ResizeX(dst_width, dst_height, src_left, src_top, src_width+src_left, src_height+src_top, chroma=false, desampling=true, kernel="Bicubic", lsb_in=true, lsb_out=true) : diff.debicubicy(dst_width, dst_height, src_left, src_top, src_width+src_left, src_height+src_top, lsb_inout=true)
	down = down.dither_lut16("x 32768 - 99 / 32768 + round")
	
	return seed.dither_add16(down, dif=true)
}

Function DebicubicM_precise16(clip input, int target_width, int target_height, bool "chroma", bool "DeResizeMT")
{
    # based on DebilinearM v1.3.1
    
    Assert(target_width  > 0, "GradFun3mod: target width must be greater than 0")
    Assert(target_height > 0, "GradFun3mod: target height must be greater than 0")
    
    thr = 10
    expand = 1
    inflate = 2
    kernel = "Spline36"
    chroma = Default(chroma, true)
	DeResizeMT = default(DeResizeMT, false)
    
    w = input.Width()
    h = input.Height()/2
    uvint = chroma ? 3 : 1
    
    # Resizing
    input_8bit = input.DitherPost(mode=-1)
        dbi = chroma ? input.Dither_resize16(target_width,target_height,kernel="bicubic",invksh=true,fh=1.3,fv=1.3,invkstaps=7)
         \                 : input.debicubicy_precise(target_width,target_height,DeResizeMT=DeResizeMT)
    dbi_8bit = DeResizeMT ? input_8bit.ResizeX(target_width,target_height, chroma=chroma, desampling=true, kernel="Bicubic") : chroma ? input_8bit.Debicubic(target_width,target_height)
         \                 : input_8bit.DebicubicY(target_width,target_height)
    dbi2     = dbi_8bit.ResizeX(w,h, kernel="Bicubic", chroma=chroma)   
    rs = input.ResizeX(target_width,target_height, kernel=kernel, chroma=chroma, lsb_in=true, lsb_out=true)
    
    # Masking
    diffmask = mt_lutxy(input_8bit,dbi2, "x y - abs", U=uvint, V=uvint).mt_binarize(threshold=thr, U=uvint, V=uvint)
    diffmask = diffmask.ResizeX(target_width,target_height, kernel="Bilinear", chroma=chroma)
    \                                  .mt_binarize(threshold=3, U=uvint, V=uvint)
    \                                  .DebilinearM_expand(expand=expand, U=uvint, V=uvint)
    \                                  .DebilinearM_inflate(inflate=inflate, U=uvint, V=uvint)
    merged = Dither_merge16_8(dbi,rs,diffmask, u=uvint, v=uvint)

    return merged
}

