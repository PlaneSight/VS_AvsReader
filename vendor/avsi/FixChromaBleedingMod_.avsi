# FixChromaBleedingMod v1.351

### Changelog ###
# Removed SmoothLevels dependency.
# Fixed high bit-depth output.
###
# Require SmoothLevels, ChromaShiftSP2.
###
# High bit-depth support.


Function FixChromaBleedingMod(clip input, int "cxShift", int "cyShift", float "thr", float "strength", float "opacity", bool "n")
{
	xShift = default ( cxShift,       -4 )
	yShift = default ( cyShift,       -4 )
	thr	 = default ( thr,         4.0 )
	stre = default ( strength,      0.8 )
	n =  default ( n,       false )
	opacity = default ( opacity,       1 )
	
	bits = BitsPerComponent(input)
	m = BitLShift(1, bits) - 1
	v = BitLShift(1, bits - 8)
	
	# prepare to work on the V channel
	vch  = input.Tweak(sat = thr, dither = true).PlaneToY("V")
	area = n ? vch.Blur(1) : vch
	
	# select and normalize both extremes of the scale
	red = area.Levels(m,1.0,m,m,0, dither = true)
	blue = area.Levels(0,1.0,0,0,m, dither = true)
	
	# merge both masks
	maskc = n ? MergeLuma(red, blue, 0.5).Blur(1).Levels(250*v,1.0,250*v,m,0) : MergeLuma(red, blue, 0.5).Levels(250*v,1.0,250*v,m,0)
	
	# expand to cover beyond the bleeding areas and shift to compensate the resizing
	maskc = maskc.mt_edge("0 0 0 1 0 0 0 0 0", 0,255,0,255).mt_edge("1 1 1 1 1 1 0 0 0", 0,255,0,255)
	
	# binarize (also a trick to expand)
	maskc = maskc.Levels(10*v,1.0,10*v,0,m).mt_inflate()
	
	# prepare a version of the image that has its chroma shifted and less saturated
	input_c = input.ChromaShiftSP2(ux = xShift, vx = xShift, uy = yShift, vy = yShift).Tweak(sat = stre)
	
	# combine both images using the mask
	fu = input.PlaneToY("U").overlay(input_c.PlaneToY("U"),mask=maskc,mode="blend",opacity=opacity)
	fv = input.PlaneToY("V").overlay(input_c.PlaneToY("V"),mask=maskc,mode="blend",opacity=opacity)
	return CombinePlanes(ExtractY(input), fu, fv, planes = "YUV", sample_clip = input)
}