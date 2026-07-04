#------------------------------------------------------------------------
#                s_ExLogo() v1.1, De-logo Function, With Clipping
#                                by StainlessS
#
# http://forum.doom9.org/showthread.php?t=154559
#------------------------------------------------------------------------
# History:
#
# v1.0 Initial release, featuring Lousy coordinate calculations. 
# v1.1 15 Sept 2010: Fixed haphazard coord calcs + lots of other alterations.
#      More like what v1.0 should have been, with more rigorous error checking and reporting.
#      SPow now 2.2 by default as in pre-release v0.0
#------------------------------------------------------------------------
#
# ("s_" Just Means Script Function)
#
# Filter requirements:- NONE (Tested only on Avisynth v2.5.8 and v2.6)
#
# Based on Dekafka (YUY2 Only)
#
#  HHHHHH         s_Exlogo, samples above and below (shown left as 'H')
# VLLLLLLV        and combines them into a horizontal bar.
# VLLLLLLV        Samples left and right and combines them into a vertical bar (shown as 'V').
# VLLLLLLV        Logo area shown as 'L'.
# VLLLLLLV        These bars may or may not be blurred, and are then resized to fit
#  HHHHHH         the logo area. The resized bars are then mixed together based
#                 on arg "Spow" and the ratio of length of Vertical bars to length
#                 of horizontal bars. Finally, the resultant de-logo'd area is
#                 Layer'ed onto the clip using the Amount arg.
#                   Clipping can be set so as to avoid eg sampling letterboxing when
#                 blurring out the logo (would normally result in nasty black
#                 block instead of a nasty logo). 
#
#  Basic usage:-
#   s_ExLogo(clip, int LogoX, int LogoY, int LogoW, Int LogoH)
#
#     LogoX,LogoY,LogoW,LogoH, position of logo, width and height (Compulsory args)
#         LogoX, LogoY, Sets upper left position of logo rectangle.
#         LogoW, LogoH, Width and height of Logo rectangle,
#            Zero and -ve, values can be used, relative to the width and height,
#            (as used in crop)
#            s_ExLogo(Last,680,520,-4,-4) would set logo area to (680,520,36,52)
#              on a 720x576 clip.
#         LogoX and LogoW should be in even numbers only (YUY2).
#
#  Optional args
#     int LogoMode, 0-4, Default 2.
#         0 = Show LOGO position by dimmed rectangle. (initial logo setup)
#         1 = Show PATCH (CLIPPED logo) position & Clipping. NON CLIPPED area shown in GREEN.
#             Clipping setup, Used AFTER LogoMode=0 (Initial Logo Setup).
#         2 = Normal, Default.
#         3 = Keep Chroma (delogo Luma only)
#         4 = Keep Luma (delogo Chroma only)
#
#     int BlurMode, 0-6, Default 4, Sets Both HBlur and VBlur as below.
#         0 = 0.0,  Off, No Blurring, BilinearResize only. (maybe subtitles)
#         1 = 0.2
#         2 = 0.33
#         3 = 0.5
#         4 = 1.0  Default
#         5 = 1.58 Maximum possible
#         6=  1.0  User Defined. (defaults to 1.0 here, as HBlur & VBlur, default 1.0)
#
#     int HBlur, Int VBlur, Default 1.0
#         Set by BlurMode or user defined if BlurMode = 6.
#         HBlur controls amount of Horizontal blurring in Vertical bars.
#         VBlur controls amount of Vertical blurring in Horizontal bars.
#
#     int ClipX, ClipY,ClipW,ClipH, Clipping rectangle, All default 0
#         As used in crop.
#         ClipX, ClipY, Sets upper left position of clipping rectangle.
#         ClipW, ClipH, Width and height of clipping rectangle,
#            Zero and -ve, values can be used, relative to the clip width and height.
#            The defaults (0) sets ClipW to Width and ClipH to Height.
#         In Normal usage, (no borders/letterboxing), not used at all.
#         Sometimes (black borders) rarely more than 1 of these Clip? args
#         and never more than 2 will be set.
#         ClipX and ClipW should be in even numbers only (YUY2).
#
#     float spow, 1.0 to 150.0, Default 2.2
#         When mixing blurred horizontal and vertical bars either side, top and bottom,
#         of a logo, this arg controls the mix. When spow==1.0, the bars with the
#         longest sides are given precedence weighted by how long they are compared
#         to the other bars. If the vertical bars either side of the logo are eg
#         100 pixels tall and the horizontal bars are 50, then the vertical bars
#         are mixed with 2:1 the strength of the horizontal bars, ie 66%, (about
#         170 for argument to Layer(), 256*0.66). Dekafka would have given this
#         example a strength of 255, close to 100% (255/256). Strangely, if lengths
#         were swapped about, it would have gotten a strength of 64, = 25%. s_ExLogo
#         is symetrical, whereas Dekafka is not.
#
#         Based on the above example where vertical bars are twice as long as the
#         horizontal bars:-
#         spow        V_Strength%     Layer_arg          ratio
#         1.0            66%            170               2:1      (Linear)
#         1.6            75%            191               3:1
#         2.2            80%            205               4:1      (Default)
#         2.8            83%            213               5:1
#         3.3            86%            219               6:1
#         4.0            88%            224               7:1
#         4.6            89%            228               8:1
#         5.0            90%            230               9:1
#         5.7            91%            233               10:1
#         143.0          99.6           255               255:1
#
#
#         As you can see, the above spow Default is 2.2, with a ratio of 4:1
#         meaning that if the vertical bars are twice as long as the horizontal ones,
#         they acquire a strength of 80%, 4:1 as opposed to 2:1 when linear spow of 1.0
#         is used.
#         Using spow=143.0 (or anywhere close) pretty much switches OFF the shortest side
#         which may have application. Anything else above about 5.7 is unlikely to be of
#         any great use. The spow arg does NOT produce miracles, but is something else
#         to play with if you get bored.
#           In this version, the default spow has reverted back to the original test value
#         of 2.2 (was 1.6 in first release). spow really is just an externally adjustable
#         default value, meant for testing and not really intended to be changed, suggest
#         that if you dont like the default setting, that you manually change it in the
#         source instead of submitting an spow arg every time its used.
#
#     int Mix, -1 to 256, default -1 (Use SPow)
#         Overrides Spow calculations for controlling mixing of vertical and horizontal
#         bars based on vertical : horizontal ratio.
#         Sets the argument passed to 'Layer()" directly, eg 256 uses ALL of the vertical
#         bars and NONE of the horizontal, 128 does a 50/50 mix and 0 uses only
#         horizontal bars. For one-off adjustments, may be best to use Mix instead
#         of using the spow arg.
#
#     int Amount, 0-256, Default 252, How much of blurred de-logo is used.
#         This controls  how much of the blurred de-logo put together by spow (or Mix, above)
#         is finally combined with the original clip to replace the logo area.
#
#------------------------------------------------------------------------ 
#  X-Coords should be in even numbers only (YUY2).
# -------
#  IN-USE:
#    Position logo using LogoMode=0 (Ignores clipping in this mode).
#      Displays Logo area as a "dimmed" rectangle. MUST SET LOGO IN THIS MODE 1st.
#    If borders/letterboxing, then:
#      Switch to LogoMode=1,
#         Shows Patch (CLIPPED logo) position & Clipping. NON CLIPPED area shown in GREEN.
#         NOTE, the Logo rectangle (patch) will have been clipped in this mode and any
#         that has been clipped out will NOT be hi-lited. Changed NON Clipped color
#         in v1.1 from Pink to GREEN. I'm sure that a better (more intuitive) method for
#         clipped hi-liting could be found, but this is the easy way, and I'm basically lazy.
#    When coords of Logo and optional clipping set then:
#      Switch to LogoMode=2, Normal usage. (LogoMode 3 and 4, may also have application)
# -------
#  CLIPPING:
#    If you have a standard set of LOGO coords for a particular station logo then
#    you would use these LOGO coords whether or not there are any borders/letterboxing.
#    You would only use the CLIP coords if borders/letterboxing, LOGO coords are NOT
#    changed. The only Clipping coords that need be set, are the ones where the
#    borders are, so if eg:
#      Video clip has eg letter boxing top and bottom, and logo is in top left, then:
#        Use LogoMode=1, to set only "ClipY", in this case ClipY should be the coord
#        of the topmost logo pixel that does NOT contain any border.
#        When set correctly, switch to LogoMode=2 (default use).
#        Blurred de-logo data is (in this case) taken only from left, right and bottom
#        of logo patch area. (Patch area = clipped LOGO area). 
# -------
#  SOME USAGE EXAMPLES, TO SHOW YOU WHAT TO EXPECT with LogoModes 0 and 1.
#
#  s_ExLogo(20,20,100,100,LogoMode=0)			# Logo Top LHS, No clipping, Show Logo 
#  s_ExLogo(20,20,100,100,ClipY=70,LogoMode=1)  # Logo Top LHS, Top HALF LOGO Clipped, Show Logo/Clipping 
#
#  s_ExLogo(0,12,-0,40,LogoMode=0)			    # Full width scrolling logo, No clipping, Show Logo 
#  s_ExLogo(0,12,-0,40,ClipY=32,logomode=1)	    # Full width scrolling logo, Top HALF LOGO Clipped, Show Logo/Clipping
# -------
#  LASTLY, Have had pretty impressive results using this as a post processor to AvsInpaint with low setting
#  for amount and FF3DFilter doing a further little bit of smoothing on a cropped area slightly larger
#  than the patch area. (AvsInpaint using InPaintFunc.avs by Reuf Toc). AvsInpaint, can be a little on the slow
#  side, but whilst you are waiting, you could always spend your time wisely, perhaps; write a good book.
#------------------------------------------------------------------------ 

Function s_ExLogo(clip Last, int LogoX, int LogoY, int LogoW, int LogoH, \
    int "LogoMode",int "BlurMode",int "ClipX",Int "ClipY",int "ClipW",int "ClipH", \
    Float "HBlur", Float "VBlur", Float "spow", int "Amount",int "Mix")
{
	# Might wish to change below spow default value directly in source, depending pref.
	spow=Default(Spow,2.2)					# changed back to original v0.0, ie 2.2
	Assert(spow>=1.0 && spow<=150.0,"s_Exlogo:- Spow range 1.0 to 150.0 ("+string(spow,"%.2f")+")")
	Assert(IsYUY2(),"s_ExLogo:- Requires YUY2")
	LogoMode=Default(LogoMode,2)
	Assert(LogoMode>=0 && LogoMode<=4,"s_ExLogo:- LogoMode Must be in Range 0 - 4 ("+string(LogoMode)+")")
	# Turn OFF clip rect if LogoMode = 0 (ShowLogoArea, ie set to full screen area)
	ClipX=(LogoMode==0)?0:Default(ClipX,0)
	ClipY=(LogoMode==0)?0:Default(ClipY,0)
	ClipW=(LogoMode==0)?0:Default(ClipW,-0)		# -0 is just a visual hint, ie Width
	ClipH=(LogoMode==0)?0:Default(ClipH,-0)		# -0 is just a visual hint, ie Height
	Assert(LogoX>=0 && LogoY >=0,"LogoX and LogoY Cannot be -ve ("+String(LogoX)+","+String(LogoY)+")")
	Assert(ClipX>=0 && ClipY >=0,"ClipX and ClipY Cannot be -ve ("+String(ClipX)+","+String(ClipY)+")")
	Assert(LogoX % 2==0 && LogoW % 2==0,"LogoX and LogoW must be even numbers [YUY2] ("+string(LogoX)+","+string(LogoW)+")")
	Assert(ClipX % 2==0 && ClipW % 2==0,"ClipX and ClipW must be even numbers [YUY2] ("+string(ClipX)+","+string(ClipW)+")")
	Amount=Default(Amount,252)
	Assert(Amount>=0 && Amount <=256, "s_ExLogo:- Amount Must be in Range 0 - 256 ("+String(Amount)+")")
	BlurMode=Default(BlurMode,4)				# default to 1.0
	Assert(BlurMode>=0 && BlurMode<=6,"s_ExLogo:- BlurMode Must be in Range 0 - 6 ("+String(BlurMode)+")")
	HBlur=Select(BlurMode,0.0,0.2,0.33,0.5,1.0,1.58,Default(HBlur,1.0))
	VBlur=Select(BlurMode,0.0,0.2,0.33,0.5,1.0,1.58,Default(VBlur,1.0))
	Mix=Default(Mix,-1)						# defaults to 'use spow'
	Assert(Mix>=-1 && Mix<=256,"s_Exlogo:- Mix range -1 to 256 ("+String(Mix)+")") 

	# Check logo coords
	LogoX2=(LogoW<=0) ? Width + LogoW : LogoX+LogoW
	LogoY2=(LogoH<=0) ? Height + LogoH : LogoY+LogoH
	LogoX2=(LogoX2<=Width)?LogoX2:Width 	# Silently correct
	LogoY2=(LogoY2<=Height)?LogoY2:Height	# Silently correct
	LogoW=LogoX2 - LogoX
	LogoH=LogoY2 - LogoY
	# The below can be fired when large -ve LogoW or LogoH
	Assert(LogoW>0 && LogoH>0,"s_ExLogo:- Check LogoW and LogoH ("+String(LogoW)+","+String(LogoH)+")")
			
	# Check Clipping coords
	ClipX2=(ClipW<=0) ? Width + ClipW : ClipX+ClipW
	ClipY2=(ClipH<=0) ? Height+ ClipH : ClipY+ClipH
	ClipX2=(ClipX2<=Width)?ClipX2:Width 	# Silently correct
	ClipY2=(ClipY2<=Height)?ClipY2:Height	# Silently correct
	ClipW=ClipX2 - ClipX
	ClipH=ClipY2 - ClipY
	# The below can be fired when large -ve ClipW or ClipH
	Assert(ClipW>0 && ClipH > 0,"s_ExLogo:- Check ClipW and ClipH ("+String(ClipW)+","+String(ClipH)+")")

	# Ascertain Patch, intersection of logo and clipping rectangles
	# (Patch, area to be de-logo'ed after clipping applied)	
	PX = (LogoX >ClipX )? LogoX: ClipX
	PY = (LogoY >ClipY )? LogoY: ClipY
	PX2 =(LogoX2<ClipX2)? LogoX2:ClipX2
	PY2 =(LogoY2<ClipY2)? LogoY2:ClipY2
	PW=PX2 - PX
	PH=PY2 - PY
	Assert(PW>0 && PH > 0,"s_ExLogo:- Check, Clip coords, Logo completely clipped OUT("+String(PW)+","+String(PH)+")")
	Assert(PW>=2 && PH >=2,"s_ExLogo:- Logo area (after clipping) MUST be at least 2x2("+String(PW)+","+String(PH)+")")

	# Which vertical bars can we do ?
	# If we can do both left and right vertical bars then we need to sample 2 pixels outside of patch
	# area, for both bars. If we can only do soley left OR right bar then we need to be able to sample
	# 4 pixels outside of patch area. The reason for this is the resize function will fail with error
	# trying to resize less than 4 pixel width. If doing both left and right, both bars are stacked
	# horizontal and so 2 pixel samples are enough for a resize sample source width of 4 pixels.
	ok_v = (PX-2 >= ClipX) ? 1 : 0						# Can we do Left  vertical bar, (assuming both L & R)? 1 = yes
	ok_v = ok_v + ((PX2+2 <= ClipX2)   ?2:0)			# Can we do Right vertical bar, (assuming both L & R)? 2 = yes
	# Here we know what we can do IF BOTH L & R are Possible, BUT what about if ONE only.
	# If only 1 bar possible and 4 pixels NOT available, then we switch OFF vertical bars completely.
	ok_v = ((ok_v==1)&&(PX-4 < ClipX)) ?0:ok_v			# If Soley Left vertical bar & less than 4pix, then CANT DO
	ok_v = ((ok_v==2)&&(PX2+4> ClipX2))?0:ok_v			# If Soley Right vertical bar & less than 4pix, then CANT DO
	# ok_v, 0=none, 1=Left only, 2=Right only, 3=Left and Right
	
	# Which horizontal bars can we do ?
	# If we can do both top and bottom horizontal bars then we need to sample 2 pixels outside of patch
	# area, for both bars. If we can only do soley top OR bottom bar then we need to be able to sample
	# 4 pixels outside of patch area. The reason for this is the resize function will fail with error
	# trying to resize less than 4 pixel height. If doing both top and bottom, both bars are stacked
	# vertical and so 2 pixel samples are enough for a resize sample source height of 4 pixels.
	ok_h = (PY-2 >= ClipY) ? 1 : 0						# Can we do Top horizontal bar, (assuming both T & B)? 1 = yes
	ok_h = ok_h + ((PY2+2 <=  ClipY2) ?2:0)				# Can we do Bot horizontal bar, (assuming both T & B)? 2 = yes
	# Here we know what we can do IF BOTH T & B are Possible, BUT what about if ONE only.
	# If only 1 bar possible and 4 pixels NOT available, then we switch OFF horizontal bars completely.
	ok_h = ((ok_h==1)&&(PY-4 <ClipY)) ?0:ok_h			# If Soley Top horizontal bar, & less than 4pix then CANT DO
	ok_h = ((ok_h==2)&&(PY2+4>ClipY2))?0:ok_h			# If Soley Bot horizontal bar, & less than 4pix then CANT DO
	# ok_h, 0=none, 1=Top only, 2=Bot only, 3=Top and Bot

	# Check we have something to do 
	ok_both=(ok_h==0) ? 0: 1
	ok_both=ok_both+((ok_v==0) ? 0: 2)
	# Ok_both, 0=none, 1=horizontal only, 2=vertical only, 3=both
	Assert(ok_both!=0,"s_ExLogo:- Nothing to do, No vertical or horizontal bars ("+String(ok_h)+","+string(ok_v)+","+string(ok_both)+")")
	
	A_H = PH * ((ok_v == 3) ? 2 : 1)	# Double thick height if doing both Lft & Rgt vertical bars.
	A_W = PW * ((ok_h == 3) ? 2 : 1)	# Double thick width if doing both Top & Bot horizontal bars.
	# Weighted A_W and A_H taking account of clipped sides

	Amount2 = (256 * A_H / (A_H + A_W)) - 128
	Amount2=(int(pow(abs(Amount2/128.0),1.0/spow) * 128.0) * sign(amount2)) + 128
	# Mixing for Horizontal & Vertical bars. Higher, more vertical bars dominance.

	Amount2=(Mix>=0) ? Mix : Amount2					# if MIX, Forget spow, user set arg to Layer, directly.

	# This selects the script string to create the vertical Patch from 1 or both vertical bars.
	# Also does optional horizontal blurring based on HBlur (whether set using BlurMode or user defined HBlur).
	# If patch created using both vertical bars, then two pixels are sampled either side, stacked horizontally,
	#   optionally horizontally blurred, resized to 3 * patch width and a center cut cropped out which should
	#   more or less be equivalent to a single pixel sample from either side.
	# If patch created using a single vertical bar, then 4 pixels are sampled from that side, optionally horizontally
	#   blurred, resized to 4 * patch width and cropped to represent a single pixel sampled from that side. 
	# DeKafa samples 2 pixels either side (rather than what we try here, a single pixel), probably the only
	# reason it does so is because of the resize requirment of 4 source pixels minimum, else resize throws error.
	# It does not really make sense (at least not to me) to have 2 pixels either side resized into the patch area,
	# and would probably result in more streaking. If your research shows good reason to use 2 pixels then do
	# let me know.
	#
	# ok_v, 0=none, 1=Left only, 2=Right only, 3=Left and Right
	pat_v= ( \
		Select(ok_v, \
			("NoneDummy" ) , \
			( (HBlur==0.0) ? "Crop(PX-4,PY,4,PH).BilinearResize(PW*4,PH).Crop(PW*3,0,PW,PH)" \
					       : "Crop(PX-4,PY,4,PH).Blur(HBlur,0.0).BilinearResize(PW*4,PH).Crop(PW*3,0,PW,PH)" ) , \
			( (HBlur==0.0) ? "Crop(PX2, PY,4,PH).BilinearResize(PW*4,PH).Crop(0,0,PW,PH)" \
					       : "Crop(PX2, PY,4,PH).Blur(HBlur,0.0).BilinearResize(PW*4,PH).Crop(0,0,PW,PH)" ) , \
			( (HBlur==0.0) ? "StackHorizontal(Crop(PX-2,PY,2,PH),Crop(PX2,PY,2,PH)).BilinearResize(PW*3,PH).Crop(PW,0,PW,PH)" \
					       : "StackHorizontal(Crop(PX-2,PY,2,PH),Crop(PX2,PY,2,PH)).Blur(HBlur,0.0)" + \
						     ".BilinearResize(PW*3,PH).Crop(PW,0,PW,PH)" ) \
		) \
	)

	# This selects the script string to create the horizontal Patch from 1 or both horizontal bars.
	# Works exactly the same sort of way as pat_v selection except using VBlur. See Above.
	# ok_h, 0=none, 1=Top only, 2=Bot only, 3=Top and Bot
	pat_h= ( \
		Select(ok_h, \
			("NoneDummy") , \
			( (VBlur==0.0) ? "Crop(PX,PY-4,PW,4).BilinearResize(PW,PH*4).Crop(0,PH*3,PW,PH)" \
					       : "Crop(PX,PY-4,PW,4).Blur(0.0,VBlur).BilinearResize(PW,PH*4).Crop(0,PH*3,PW,PH)" ) , \
			( (VBlur==0.0) ? "Crop(PX,PY2, PW,4).BilinearResize(PW,PH*4).Crop(0,0,PW,PH)" \
					       : "Crop(PX,PY2, PW,4).Blur(0.0,VBlur).BilinearResize(PW,PH*4).Crop(0,0,PW,PH)" ) , \
			( (VBlur==0.0) ? "StackVertical(Crop(PX,PY-2,PW,2),Crop(PX,PY2,PW,2)).BilinearResize(PW,PH*3).Crop(0,PH,PW,PH)" \
					       : "StackVertical(Crop(PX,PY-2,PW,2),Crop(PX,PY2,PW,2)).Blur(0.0,VBlur)" + \
						     ".BilinearResize(PW,PH*3).Crop(0,PH,PW,PH)" ) \
		) \
	)
	# Merge Horiz & Vert, blurred Logo patches
	# Ok_both, 1=horizontal only, 2=vertical only, 3=both
	Logo_s=( \
		(ok_both==1) ? Eval(pat_h) : \
		(ok_both==2) ? Eval(pat_v) : \		
		Layer(Eval(pat_h),Eval(pat_v), "add", Amount2) \
	)
	# LogoMode, 0=ShowLogo,1=ShowLogo&Clip, 2=Normal, 3=KeepChroma, 4=KeepLuma
	Last=Select(LogoMode, \
		Layer(logo_s.Levels(0,1.0,255,64,128), "add", 100, PX,PY), \
		Layer(BlankClip(Last,Width=ClipW,Height=ClipH,Length=1,color=$00FF00),"add", 75, ClipX,ClipY), \
		Layer(logo_s, "add", Amount, PX,PY), \
		Layer(MergeChroma(logo_s,Crop(PX,PY,PW,PH),1.0),"add",Amount,PX,PY), \
		Layer(MergeLuma(logo_s,Crop(PX,PY,PW,PH),1.0),"add",Amount,PX,PY) \
	)
	# Show Logo Area Over Cliprect ?
	Last=(LogoMode==1) ? Layer(logo_s.Levels(0,1.0,255,64,128), "add", 128, PX,PY) : Last
	Return Last
}


