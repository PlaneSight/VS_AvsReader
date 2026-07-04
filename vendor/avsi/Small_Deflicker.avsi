# Small Deflicker 2.4
# Based in idea by Didée, kurish (http://forum.doom9.org/showthread.ph...35#post1601335)
# Adapted by GMJCZP
# Requirements: Masktools2, RGTools, vsCnr2, vsMSmooth.

# USAGE:
# Small_Deflicker(clip, width_clip=width(clip)/4, height_clip=height(clip)/4, preset=2, cnr=false, rep=false) (default values)

# PRESETS:
# preset = 1 Soft deflickering (GMJCZP values)
# preset = 2 Medium deflickering (kurish values, preset by default)
# preset = 3 Hard deflickering (Didée values)

# REPAIR MODE:
# - Chroma noise reduction it is an experimental attempt to mitigate the side effects of the script
# By default it is disabled (only for presets 2 and 3)
# - Repair is an option for certain sources or anime/cartoon content, where ghosting may be evident
# By default it is disabled (maybe for preset = 1 it is not necessary to activate it)


function Small_Deflicker(clip o, int "width_clip", int "height_clip", int "preset", bool "cnr", bool "rep")
{

width_clip  = default(width_clip,AdjustMOD(width(o)/4,16)) # Width of small clip
height_clip = default(height_clip,AdjustMOD(height(o)/4,16)) # Height of small clip
preset      = default(preset,2) # Medium Deflickering
cnr         = default(cnr,false) # Chroma noise reduction (experimental)
rep         = default(rep,false) # Repair mode

Assert(((width_clip % 16) == 0), "width_clip must be mod 16")
Assert(((height_clip % 16) == 0), "height_clip must be mod 16")

	sm=o.bicubicresize(width_clip,height_clip,0,0) # can be altered, but ~25% of original resolution seems reasonable
        smm = (preset==1) ? sm.Preset1() : (preset==2) ? sm.Preset2(cnr) : (preset==3) ? sm.Preset3(cnr) : Assert(false, "Preset not valid (1, 2 or 3)")
	o2=o.mt_makediff(mt_makediff(sm,smm,u=3,v=3).bicubicresize(width(o),height(o),0,0),u=3,v=3)
	o2 = rep ? Repair(o2, o, mode=10, modeU=10, modeV=10) : o2


return o2
}

# Function that adjusts parameters to mod 16

Function AdjustMOD(int value, int "factor")
{
factor = default(factor,16)
adjust = value - (value % factor)
return adjust
}

# Presets

Function Preset1(clip sm)
{
smm=sm.temporalsoften(1,6,9,10,2).vsMSmooth(threshold=0.8,strength=25.0,chroma=true,luma=false).merge (sm,0.25).merge (sm,0.25)
smm=smm.temporalsoften(2,3,5,6,2).vsMSmooth(threshold=2.0,strength=1.0,chroma=true,luma=false)
Return smm
}

Function Preset2(clip sm, bool cnr)
{
smm=sm.temporalsoften(1,12,255,24,2).vsMSmooth(threshold=0.8,strength=25.0,chroma=true,luma=false).merge (sm,0.25).merge (sm,0.25)
smm=smm.temporalsoften(2,7,255,20,2).vsMSmooth(threshold=2.0,strength=1.0,chroma=true,luma=false)
smm = cnr ? smm.vsCnr2(mode="ooo",ln=5,un=40,vn=40, scdthr=2.0) : smm
Return smm
}

Function Preset3(clip sm, bool cnr)
{
smm=sm.temporalsoften(1,32,255,24,2).vsMSmooth(threshold=0.8,strength=25.0,chroma=true,luma=false).merge (sm,0.25).merge (sm,0.25)
smm=smm.temporalsoften(2,12,255,20,2).vsMSmooth(threshold=2.0,strength=1.0,chroma=true,luma=false)
smm = cnr ? smm.vsCnr2(mode="ooo",ln=10,lm=255,un=35,vn=35, scdthr=2.0) : smm
Return smm
}