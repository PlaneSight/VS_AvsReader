# https://forum.doom9.org/showthread.php?t=186015

function portalscope (clip clp, int "mode")
{
# Emulgator's PortalScope (Version 2023 12 05)
# "VideoTek and beyond", thanks FranceBB !
# Well known Avisynth scopes are arranged as tiled portal around the source video.
# Tidyness was a goal, so this approach avoids resizing wherever possible.
# A status bar on top shows lots of information from the source clip.
# All Scopes got scales now which match the source's colourspace and resolution.
# Small source video gets padded up with black bars, not resized, some 256x256 Scopes have been tidied 
# (histogram(levels) has been cut in stripes and rearranged,
# the 512x512 stereo goniometer is cropped to 256x256 around the center area...)
# Bargraph can show 10 channels, waveform I tested with 50 channels.
# Portalscope takes just one parameter for now : mode (integer) default = 0
# This decides about the center stack.
# Set it to 0 or not at all: the center stack will show the usual unsqueezed source planes' overlay.
# Set it to 1 and instead of all source planes the center stack will show only unsqueezed luma plane with exaggerated detail.
# This may be useful for spotting of MPEG blocking and other artifacts.
# Set it to 2 and the center stack will show the squeezed source plane's overlay squeezed a bit plus half-height U plane.
# Set it to 3 and the center stack will show the squeezed source plane's overlay plus half-height V plane.
# Set it to 4 and the center stack will show the squeezed source plane's overlay plus quarter-height U+V planes,.
# The PortalScope will hopefully make video assessment and adjustment more eye-friendly...
## Requirements: AviSynth (tested with pinterf 3.7.3 test8 64bit on Win10Pro64 i9-11900K 128GB)
## wonkey_monkey's waveform (tested with 2.0.2)
## Font LcdD if you want to have the SMPTE TC display in that style.
## The other functions are AviSynth internal functions.
## Sourcefilters suggested as of 2023: LWLibavVideoSource(), LWLibavAudioSource(), DGSource(), MPEG2Source().
## (It seems as if  NicAC3Source() can not handle modern Audio Cache requirements anymore...)
##
mode=default(mode, 0)
bpc=clp.bitspercomponent()
isSMPTE=\
round(framerate(clp)*1000)==23976 || round(framerate(clp)*1000)==24000 || round(framerate(clp)*1000)==25000\
|| round(framerate(clp)*1000)==29970 || round(framerate(clp)*1000)==30000 || round(framerate(clp)*1000)==47952\
|| round(framerate(clp)*1000)==48000 || round(framerate(clp)*1000)==50000 || round(framerate(clp)*1000)==59940\
|| round(framerate(clp)*1000)==60000 ? true : false
src=clp.ConvertToYUV444()
#-----------------------------  histogram(levels)  tidied ----------
topbarfontsize=6+ceil(width(clp)/480.0)*6
histfontsize=6+ceil(width(clp)/1920.0)*6
wavefontsize=6+ceil(width(clp)/960.0)*6
level=Histogram(clp, mode="levels", keepsource=false)\
# 256x256, had uneven spacing. 3 bars each 80 pix height were stacked, bottom adds a 16pix black bar
# To be able to add labeling I will slice that into 3 pieces, net 3x66 pix height = 198 pix height,
# then restack fitting the new labeling.
# Each bar has height 65pix color bar +15pix black, any peak adds 1 pix white into black.
# 2 mid bars shall take 2 text lines each, 2 top/bottombars take 1 line
# Total height = 256, blackbar sum = 256-198 = 58 / 6 = 9 2/3 per line -> 9+10+10+10+10+9.
# upward shift because of  audio bargraph clipping range below
barTc=crop(level,0,0,0,66)
barMc=crop(level,0,80,0,66)
barBc=crop(level,0,160,0,66)
barTp=AddBorders(barTc,0,4,0,10)
barMp=AddBorders(barMc,0,10,0,10)
barBp=AddBorders(barBc,0,10,0,14)
histoYUV_RGB=IsRGB(level)\
? StackVertical(barTp,barMp,barBp)\
.Subtitle("R",size=histfontsize, align=4,x=0, y=3+wavefontsize*3/8, text_color=$770000)\
.Subtitle("R",size=histfontsize, align=5,x=128, y=3+histfontsize*3/8, text_color=$AA0000)\
.Subtitle("R",size=histfontsize, align=6,x=255, y=3+histfontsize*3/8, text_color=$FFAA00)\
.Subtitle("0",size=histfontsize, align=7,x=0, y=70-histfontsize*1/8, text_color=$770000)\
.Subtitle("127",size=histfontsize, align=8,x=128, y=70-histfontsize*1/8, text_color=$AA0000)\
.Subtitle("255",size=histfontsize, align=9,x=255, y=70-histfontsize*1/8, text_color=$FFAA00)\
.Subtitle("G",size=histfontsize, align=4,x=0, y=88+histfontsize*3/8, text_color=$007700)\
.Subtitle("G",size=histfontsize, align=5,x=128, y=88+histfontsize*3/8, text_color=$00AA00)\
.Subtitle("G",size=histfontsize, align=6,x=255, y=88+histfontsize*3/8, text_color=$66FF66)\
.Subtitle("0",size=histfontsize, align=7,x=0, y=155-histfontsize*1/8, text_color=$007700)\
.Subtitle("127",size=histfontsize, align=8,x=128, y=155-histfontsize*1/8, text_color=$00AA00)\
.Subtitle("255",size=histfontsize, align=9,x=255, y=155-histfontsize*1/8, text_color=$66FF66)\
.Subtitle("B",size=histfontsize, align=4,x=0, y=174+histfontsize*3/8, text_color=$0000FF)\
.Subtitle("B",size=histfontsize, align=5,x=128, y=174+histfontsize*3/8, text_color=$0088FF)\
.Subtitle("B",size=histfontsize, align=6,x=255, y=174+histfontsize*3/8, text_color=$AABBFF)\
.Subtitle("0",size=histfontsize, align=7,x=0, y=241-histfontsize*1/8, text_color=$0000FF)\
.Subtitle("127",size=histfontsize, align=8,x=128, y=241-histfontsize*1/8, text_color=$0088FF)\
.Subtitle("255",size=histfontsize, align=9,x=255, y=241-histfontsize*1/8, text_color=$AABBFF)\
.ConvertBits(8).ConvertToYV24().ConvertBits(bpc)\
: StackVertical(barTp,barMp,barBp)\
.Subtitle("B",size=histfontsize, align=5,x=16, y=3+histfontsize*3/8, text_color=$999999)\
.Subtitle("Y",size=histfontsize, align=5,x=128, y=3+histfontsize*3/8, text_color=$AAAAAA)\
.Subtitle("W",size=histfontsize, align=5,x=235, y=3+histfontsize*3/8, text_color=$FFFFFF)\
.Subtitle("16",size=histfontsize, align=8,x=16, y=70-histfontsize*1/8, text_color=$999999)\
.Subtitle("127",size=histfontsize, align=8,x=128, y=70-histfontsize*1/8, text_color=$AAAAAA)\
.Subtitle("235",size=histfontsize, align=8,x=235, y=70-histfontsize*1/8, text_color=$FFFFFF)\
.Subtitle("-Y",size=histfontsize, align=5,x=16, y=88+histfontsize*3/8, text_color=$FFAA00)\
.Subtitle("U",size=histfontsize, align=5,x=128, y=88+histfontsize*3/8, text_color=$6688FF)\
.Subtitle("+B",size=histfontsize, align=5,x=240, y=88+histfontsize*3/8, text_color=$6688FF)\
.Subtitle("16",size=histfontsize, align=8,x=16, y=155-histfontsize*1/8, text_color=$FFAA00)\
.Subtitle("127",size=histfontsize, align=8,x=128, y=155-histfontsize*1/8, text_color=$6688FF)\
.Subtitle("240",size=histfontsize, align=8,x=240, y=155-histfontsize*1/8, text_color=$6688FF)\
.Subtitle("-C",size=histfontsize, align=5,x=16, y=174+histfontsize*3/8, text_color=$00FFFF)\
.Subtitle("V",size=histfontsize, align=5,x=128, y=174+histfontsize*3/8, text_color=$AA8000)\
.Subtitle("+R",size=histfontsize, align=5,x=240, y=174+histfontsize*3/8, text_color=$FF0000)\
.Subtitle("16",size=histfontsize, align=8,x=16, y=241-histfontsize*1/8, text_color=$00FFFF)\
.Subtitle("127",size=histfontsize, align=8,x=128, y=241-histfontsize*1/8, text_color=$AA8000)\
.Subtitle("240",size=histfontsize, align=8,x=240, y=241-histfontsize*1/8, text_color=$FF0000)\
.ConvertBits(8).ConvertToYV24().ConvertBits(bpc)
# --------------  Chroma flower with added chroma locations -----------
colorfontsize=6+ceil(width(clp)/960.0)*6
color=Histogram(src, mode="color2", keepsource=false)\
.Subtitle("G",size=colorfontsize, align=5,x=72.5, y=57.5+colorfontsize*3/8, text_color=$00FF00)\
.Subtitle("C",size=colorfontsize, align=5,x=156.5, y=43.5+colorfontsize*3/8, text_color=$00FFFF)\
.Subtitle("Y",size=colorfontsize, align=5,x=44.5, y=141.5+colorfontsize*3/8, text_color=$FFFF00)\
.Subtitle("W",size=colorfontsize, align=5,x=127, y=127+colorfontsize*3/8, text_color=$FFFFFF)\
.Subtitle("B",size=colorfontsize, align=5,x=213, y=114+colorfontsize*3/8, text_color=$6688FF)\
.Subtitle("R",size=colorfontsize, align=5,x=100.5, y=211.5+colorfontsize*3/8, text_color=$FF0000)\
.Subtitle("M",size=colorfontsize, align=5,x=184.5, y=197.5+colorfontsize*3/8, text_color=$FF00FF)
#------------------------------line-waveform along y-axis
Ywavey=Histogram(src, mode="classic", keepsource=false).ColorYUV(gamma_Y=200)\
.Subtitle("0",x=0,y=(height(clp)*3/8),align=5,size=wavefontsize,font_angle=-90.0)\
.Subtitle("0",x=0,y=(height(clp)*5/8),align=5,size=wavefontsize,font_angle=-90.0)\
.Subtitle(String(round(pow(2,bpc)/16)),x=width(histoYUV_RGB)/16,y=(height(clp)/2+wavefontsize*3/8),align=5,size=wavefontsize)\
.Subtitle(String(round(pow(2,bpc)/2)-1),x=(width(histoYUV_RGB)/2)-1,y=(height(clp)/2+wavefontsize*3/8),align=5,size=wavefontsize)\
.Subtitle(String(round(pow(2,bpc))*235/256),x=(width(histoYUV_RGB)-1)*47/51,y=(height(clp)/2+wavefontsize*3/8),align=5,size=wavefontsize)\
.Subtitle(String(round(pow(2,bpc)-1)),x=width(histoYUV_RGB)+wavefontsize/4,y=(height(clp)*3/8),align=8,size=wavefontsize,font_angle=-90.0)\
.Subtitle(String(round(pow(2,bpc)-1)),x=width(histoYUV_RGB)+wavefontsize/4,y=(height(clp)*5/8),align=8,size=wavefontsize,font_angle=-90.0)
#------------------------------Y column-waveform along x-axis
srcturn=turnright(src)
Ywavex=srcturn.Histogram(mode="classic", keepsource=false).ColorYUV(gamma_Y=200)\
.Subtitle("0",x=0,y=(height(srcturn)*3/8),align=5,size=wavefontsize,font_angle=-90.0)\
.Subtitle("0",x=0,y=(height(srcturn)*5/8),align=5,size=wavefontsize,font_angle=-90.0)\
.Subtitle(String(round(pow(2,bpc)/16)),x=width(histoYUV_RGB)/16-wavefontsize*3/8,y=(height(srcturn)/2),align=5,size=wavefontsize,font_angle=-90)\
.Subtitle(String(round(pow(2,bpc)/2)-1),x=(width(histoYUV_RGB)/2)-1-wavefontsize*3/8,y=(height(srcturn)/2),align=5,size=wavefontsize,font_angle=-90)\
.Subtitle(String(round(pow(2,bpc))*235/256),x=(width(histoYUV_RGB)-1)*47/51-wavefontsize*3/8,y=(height(srcturn)/2),align=5,size=wavefontsize,font_angle=-90)\
.Subtitle(String(round(pow(2,bpc)-1)),x=width(histoYUV_RGB)+wavefontsize/4,y=(height(srcturn)*3/8),align=8,size=wavefontsize,font_angle=-90.0)\
.Subtitle(String(round(pow(2,bpc)-1)),x=width(histoYUV_RGB)+wavefontsize/4,y=(height(srcturn)*5/8),align=8,size=wavefontsize,font_angle=-90.0)\
.turnleft()
#------------------------------U column-waveform along x-axis
Uwavex=srcturn.UtoY.Histogram(mode="classic", keepsource=false).ColorYUV(gamma_Y=0,gamma_U=100,gamma_V=-100)\
.Subtitle("0",x=0,y=(height(srcturn)*3/8),align=5,size=wavefontsize,font_angle=-90.0)\
.Subtitle("0",x=0,y=(height(srcturn)*5/8),align=5,size=wavefontsize,font_angle=-90.0)\
.Subtitle(String(round(pow(2,bpc)/16)),x=width(histoYUV_RGB)/16-wavefontsize*3/8,y=(height(srcturn)/2),align=5,size=wavefontsize,font_angle=-90)\
.Subtitle(String(round(pow(2,bpc)/2)-1),x=(width(histoYUV_RGB)/2)-1-wavefontsize*3/8,y=(height(srcturn)/2),align=5,size=wavefontsize,font_angle=-90)\
.Subtitle(String(round(pow(2,bpc))*235/256),x=(width(histoYUV_RGB)-1)*47/51-wavefontsize*3/8,y=(height(srcturn)/2),align=5,size=wavefontsize,font_angle=-90)\
.Subtitle(String(round(pow(2,bpc)-1)),x=width(histoYUV_RGB)+wavefontsize/4,y=(height(srcturn)*3/8),align=8,size=wavefontsize,font_angle=-90.0)\
.Subtitle(String(round(pow(2,bpc)-1)),x=width(histoYUV_RGB)+wavefontsize/4,y=(height(srcturn)*5/8),align=8,size=wavefontsize,font_angle=-90.0)\
.turnleft()
#------------------------------V column-waveform along x-axis
Vwavex=srcturn.VtoY.Histogram(mode="classic", keepsource=false).ColorYUV(gamma_Y=0,gamma_U=-100,gamma_V=100)\
.Subtitle("0",x=0,y=(height(srcturn)*3/8),align=5,size=wavefontsize,font_angle=-90.0)\
.Subtitle("0",x=0,y=(height(srcturn)*5/8),align=5,size=wavefontsize,font_angle=-90.0)\
.Subtitle(String(round(pow(2,bpc)/16)),x=width(histoYUV_RGB)/16-wavefontsize*3/8,y=(height(srcturn)/2),align=5,size=wavefontsize,font_angle=-90)\
.Subtitle(String(round(pow(2,bpc)/2)-1),x=(width(histoYUV_RGB)/2)-1-wavefontsize*3/8,y=(height(srcturn)/2),align=5,size=wavefontsize,font_angle=-90)\
.Subtitle(String(round(pow(2,bpc))*235/256),x=(width(histoYUV_RGB)-1)*47/51-wavefontsize*3/8,y=(height(srcturn)/2),align=5,size=wavefontsize,font_angle=-90)\
.Subtitle(String(round(pow(2,bpc)-1)),x=width(histoYUV_RGB)+wavefontsize/4,y=(height(srcturn)*3/8),align=8,size=wavefontsize,font_angle=-90.0)\
.Subtitle(String(round(pow(2,bpc)-1)),x=width(histoYUV_RGB)+wavefontsize/4,y=(height(srcturn)*5/8),align=8,size=wavefontsize,font_angle=-90.0)\
.turnleft()
#----- Because of forum 16.000 character limit, please append code block 2 here ---------
# ----  Code Block 2, please append to code Block 1 ------
#---------- Goniometer tile, cropped and populated with parameters -----------
goniofontsize=histfontsize
gonio=clp.audiochannels==2 ? src.ConvertBits(8).Histogram(mode="stereoY8", keepsource=false)\
.ConvertToYV24().ColorYUV(gamma_Y=0,gamma_U=-250,gamma_V=90).ConvertBits(bpc).crop(128,128,-128,-128)\
.Subtitle("+L",size=goniofontsize, align=7,x=0, y=0, text_color=$00FF00)\
.Subtitle("L+R",size=goniofontsize, align=8,x=127, y=0, text_color=$FFFF00)\
.Subtitle("+R",size=goniofontsize, align=9,x=255, y=0, text_color=$FF0000)\
.Subtitle("L-R",size=goniofontsize, align=4,x=0, y=127+goniofontsize*3/8, text_color=$80BBFF)\
.Subtitle("R-L",size=goniofontsize, align=6,x=255, y=127+goniofontsize*3/8, text_color=$8000FF)\
.Subtitle("-R",size=goniofontsize, align=1,x=0, y=255, text_color=$00FFFF)\
.Subtitle("-L-R",size=goniofontsize, align=2,x=127, y=255, text_color=$AA8000)\
.Subtitle("-L",size=goniofontsize, align=3,x=255, y=255, text_color=$FFFF00)\
: Blankclip(histoYUV_RGB)
#-------------- Audio bargraph rendered on a variable Blankclip tile ---------
minbargraphheight=64
bargraph=hasaudio(clp) ?\
histogram(ConvertBits(Blankclip(src,width=width(gonio),height=max(height(src)-height(gonio),minbargraphheight))\
.AudioDub(src),8), mode="audiolevels").ConvertToYV24().ConvertBits(bpc)\
: ConvertBits(Blankclip(src,width=width(gonio),height=max(height(src)-height(gonio),minbargraphheight))\
.Subtitle("No Audio",align=5,size=topbarfontsize),8).ConvertToYV24().ConvertBits(bpc)
#----------------------------
stackCheight=height(Ywavex)+height(clp)
stackRheightmin=height(level)+minbargraphheight+height(gonio)
padupLC=stackRheightmin-stackCheight
#--------------- Center stack mode dependent-----------------------------------------------------------------------
luma=src.Histogram(mode="luma", keepsource=false)
preC=mode==1?StackVertical(Ywavex,luma)\
: mode==2?StackVertical(Ywavex,BilinearResize(Uwavex,width(Ywavex),height(Ywavex)/2),BilinearResize(src,width(clp),(height(clp)-height(Ywavex)/2)))\
: mode==3?StackVertical(Ywavex,BilinearResize(Vwavex,width(Ywavex),height(Ywavex)/2),BilinearResize(src,width(clp),(height(clp)-height(Ywavex)/2)))\
: mode==4?StackVertical(Ywavex,BilinearResize(Uwavex,width(Uwavex),height(Uwavex)/4),BilinearResize(Vwavex,width(Vwavex),height(Vwavex)/4)\
,BilinearResize(src,width(clp),(height(clp)-height(Ywavex)/4-height(Uwavex)/4)))\
: StackVertical(Ywavex,isSMPTE==true ? src[*.ShowSMPTE(size=48, x=200, y=100, text_color=$A0FFFF, font="LcdD")*]:src)
#----------------
stackL=padupLC>0 ? StackVertical(color,Ywavey,Blankclip(Ywavey,height=padupLC)) : StackVertical(color,Ywavey)
stackC=padupLC>0 ? StackVertical(preC, Blankclip(src,height=padupLC)) : preC
stackC=waveform(stackC,height=0.2, window=2)
#----------------------------------------------------------------
stackR=StackVertical(histoYUV_RGB,bargraph,gonio)
unprop=StackHorizontal(stackL,stackC,stackR)
#------------- Building and populating the topbar ----------
topbarwidth=unprop.width
topbarheight=topbarfontsize*4/3
statussplit=float(13)/32 # optimal graphic status bar property splitpoint between yellow and green parameters
countershift=topbarfontsize*4 # optimal graphic status bar counter splitpoint "/" , left from statussplit, between white and orange parameters
isSMPTE==true ? Eval("""
topbar=src.BlankClip(width=topbarwidth,height=topbarheight)\
.Subtitle("TC",size=topbarfontsize, align=6,x=width(unprop)*statussplit-(topbarfontsize*84/4), y=topbarheight*3/4-1, text_color=$A0FFFF)\
.ShowSMPTE(size=topbarfontsize, x=width(unprop)*statussplit-(topbarfontsize*74/4), y=topbarheight*3/4-1, text_color=$A0FFFF, font="LcdD")\
.Subtitle("f",size=topbarfontsize, align=6,x=width(unprop)*statussplit-(topbarfontsize*63/4), y=topbarheight*3/4-1, text_color=$FF0000)\
.ShowTime(size=topbarfontsize, x=width(unprop)*statussplit-(topbarfontsize*49/4), y=topbarheight*3/4-1)\
.Subtitle("ms",size=topbarfontsize, align=6,x=width(unprop)*statussplit-(topbarfontsize*33/4),y=topbarheight*3/4-1)\
.ShowFrameNumber(scroll=false, size=topbarfontsize*6/5, x=(width(unprop)*statussplit)-(countershift+topbarfontsize*15/4), y=topbarheight*3/4,text_color=$FFFFFF)\
.Subtitle("/"+String(src.framecount),size=topbarfontsize, align=4,x=(width(unprop)*statussplit)-countershift,y=topbarheight*3/4-1,text_color=$EE8800)\
.Subtitle("f",size=topbarfontsize, align=6,x=(width(unprop)*statussplit)-(countershift-topbarfontsize*7/2),y=topbarheight*3/4-1,text_color=$FF0000)\
.Subtitle(String(clp.width)+"x"+String(clp.height)+"@"+String(clp.framerate)+"fps"+"  "+String(isfieldbased(clp)?"i":"p")\
+"  "+String(GetParity(clp)?"TFF":"BFF")+"  "+String(clp.pixeltype)\
+"  "+String(clp.bitspercomponent)+"bpc"+"  |  "+String(clp.audiochannels)+"-CH "+"@"+String(clp.audiorate)+"Hz"\
+"  "+String(clp.audiobits)+"bit"+" " +String(clp.IsAudioFloat ? "float" : "int")\
,size=topbarfontsize, align=4, x=width(unprop)*statussplit, y=topbarheight*3/4-1,text_color=$00FF00)  """)\
: Eval("""
topbar=src.BlankClip(width=topbarwidth,height=topbarheight)\
.Subtitle("(no SMPTE-TC)",size=topbarfontsize, align=6,x=(width(unprop)*statussplit)-topbarfontsize*61/4, y=topbarheight*3/4-1,text_color=$808080, font="LcdD")\
.ShowTime(size=topbarfontsize, x=width(unprop)*statussplit-(topbarfontsize*49/4), y=topbarheight*3/4-1)\
.Subtitle("ms",size=topbarfontsize, align=6,x=width(unprop)*statussplit-(topbarfontsize*33/4),y=topbarheight*3/4-1)\
.ShowFrameNumber(scroll=false, size=topbarfontsize*6/5, x=(width(unprop)*statussplit)-(countershift+topbarfontsize*15/4), y=topbarheight*3/4,text_color=$FFFFFF)\
.Subtitle("/"+String(src.framecount),size=topbarfontsize, align=4,x=(width(unprop)*statussplit)-countershift,y=topbarheight*3/4-1,text_color=$EE8800)\
.Subtitle("f",size=topbarfontsize, align=6,x=(width(unprop)*statussplit)-(countershift-topbarfontsize*7/2),y=topbarheight*3/4-1,text_color=$FF0000)\
.Subtitle(String(clp.width)+"x"+String(clp.height)+"@"+String(clp.framerate)+"fps"+"  "+String(isfieldbased(clp)?"i":"p")\
+"  "+String(GetParity(clp)?"TFF":"BFF")+"  "+String(clp.pixeltype)\
+"  "+String(clp.bitspercomponent)+"bpc"+"  |  "+String(clp.audiochannels)+"-CH "+"@"+String(clp.audiorate)+"Hz"\
+"  "+String(clp.audiobits)+"bit"+" " +String(clp.IsAudioFloat ? "float" : "int")\
,size=topbarfontsize, align=4, x=width(unprop)*statussplit, y=topbarheight*3/4-1,text_color=$00FF00)  """)
#------------------------------------------------------------------------
StackVertical(topbar,unprop)
try {AudioDub(last,clp)}
catch (err) {last}
return(last)
}
