################################################################################
# DO NOT OPEN THIS DOCUMENT IN ANY MACHINE TRANSLATE OR BAD THINGS WILL HAPPEN #
################################################################################
# Latest version of this script can always be found here: http://avisynth.nl/index.php/AviSynth+#Help_filling_MT_modes
###########################################################################
# General info:
#    1. Do not include core filters in the list
#    2. Specify the lowest mode that produces correct output with any settings. 
#        For example if something works with MT_MULTI_INSTANCE on some parameters and MT_SERIALIZED with other, MT_SERIALIZED should be used
#        You can of course specify this in comments so people who do want to get MAXIMUM PERFORMANCE can modify the script themselves.
#    3. Do not specify MT modes for runtime filters. Behaviour of runtime filtering with mt is not very well known yet.
#    4. In case it isn't obvious, NICE_FILTER - mt mode 1, MULTI_INSTANCE - mt mode 2, SERIALIZED - mt mode 3. Variables are defined by avs+ core.
#    5. Starting from AviSynth+ r2069, AviSynth+ will now automatically recognize source filters. If it sees a source filter which has no MT-mode specified at all, it will automatically use mode 3 instead of the default MT mode. This is great  for source filters as in their case it rarely hurts performance and they often need mode 3 anyway, and it will help yet unclassified source filters perform correctly without any user action. One step closer to  the "it just works" target.
##################################################################################
#Another Lists
#https://gist.github.com/tp7/8899021
##################################################################################
# Official avs+ filters. Newer versions will register themself so you should never force any of these modes
############################################
SetFilterMTMode("TMaskCleaner",        MT_MULTI_INSTANCE)
SetFilterMTMode("checkmate",           MT_NICE_FILTER) 
#########################################
# Core filters (because putting it here is easier than modifying the source and firing a PR)
##################################
 
 
#########################################
# External filters (guessed, might not be very stable)
##################################
SetFilterMTMode("InterFrame",         MT_MULTI_INSTANCE)
#############################################
# External Filters (tested by Reel.Deal)
#############################################
# Testing info:
#    1. All processing plugins have been tested with ColorBars(pixel_type="YV12") as the source. Plugins that do not support YV12 have been tested accordingly.
#    2. AVSMeter is used to check optimal performance and VDub/MPC-HC is used to check correct output.
#############################################
# Source plugins

 
# Processing plugins
SetFilterMTMode("StaticNoiseC",        MT_NICE_FILTER)    #StaticNoiseC      --->    2011/01/08 - Mode 1/2 performance is almost identical. 
SetFilterMTMode("SVSuper",             MT_NICE_FILTER)    #SVPflow       4.0.0.128   2016/02/12 - Documentation states "all filters now compatible with MT mode 1"
SetFilterMTMode("SVAnalyse",           MT_NICE_FILTER)    #SVPflow       4.0.0.128   2016/02/12 - Documentation states "all filters now compatible with MT mode 1"
SetFilterMTMode("SVSmoothFps",         MT_MULTI_INSTANCE)    #SVPflow       4.0.0.128   2016/02/12 - Documentation states "all filters now compatible with MT mode 1" #2018/02/03
SetFilterMTMode("tdtrans",             MT_MULTI_INSTANCE) #tcanny            v1.0    2009/06/03 - Same as tcanny
SetFilterMTMode("VideoScope",          MT_NICE_FILTER)    #VideoScope        v1.2    2004/05/01 - Mode 1/2 performance is almost identical.
# flash3kyuu_deband 2.0pre2 2012/12/03 - Crashes with mode 1 even with mt=False

#Follow are for HDRCore, HDRNoise, HDRMatrix, HDRColor and HDRSharp.

#########################################
# Filters from Dither 1.25.0. Tested by Firesledge (not extensively though)
SetFilterMTMode("DitherPost",          MT_NICE_FILTER)
SetFilterMTMode("SmoothGrad",          MT_NICE_FILTER)
SetFilterMTMode("Dither_box_filter16", MT_NICE_FILTER)
SetFilterMTMode("Dither_bilateral16",  MT_NICE_FILTER)
SetFilterMTMode("Dither_limit_dif16",  MT_NICE_FILTER)
SetFilterMTMode("Dither_resize16",     MT_NICE_FILTER)
SetFilterMTMode("Dither_out",          MT_NICE_FILTER)
SetFilterMTMode("Dither_removegrain16",MT_NICE_FILTER)
SetFilterMTMode("Dither_repair16",     MT_NICE_FILTER)
SetFilterMTMode("Dither_median16",     MT_NICE_FILTER)
SetFilterMTMode("Dither_add16",        MT_NICE_FILTER)
SetFilterMTMode("Dither_sub16",        MT_NICE_FILTER)
SetFilterMTMode("Dither_max_dif16",    MT_NICE_FILTER)
SetFilterMTMode("Dither_merge16",      MT_NICE_FILTER)
#########################################

#note1: Can't use mode 1 or 2 on any filters if encoding 1080i files(480i works perfectly fine).
#FFVideoSource runs a few seconds, however, it always crashes.
#As far as I know, the only workaround seems to be running a deinterlacer right after the video source and running it as "MT_SERIALIZED",
#than running any desired filters after. Filters after the deinterlacer, seem to be able use any mode.
#note2: tried multiple files, seems to corrupt video even when it is the only filter in a script.
#tried mode 1, 2, and 3, none worked. however it works fine if MT isn't enabled.
#should ColorMatrix still be in the list? as a notice? or should it be removed?
#########################################
SetFilterMTMode("FRFun3d",             MT_NICE_FILTER)
SetFilterMTMode("ContinuityFixer",     MT_NICE_FILTER)
SetFilterMTMode("ReferenceFixer",      MT_NICE_FILTER)
SetFilterMTMode("SmoothLevels",        MT_NICE_FILTER)
SetFilterMTMode("SmoothTweak",         MT_NICE_FILTER)
SetFilterMTMode("SmoothCurve",         MT_NICE_FILTER)
SetFilterMTMode("SmoothCustom",        MT_NICE_FILTER)
SetFilterMTMode("SmoothTools",         MT_NICE_FILTER)
SetFilterMTMode("SmoothLevels16",      MT_NICE_FILTER)
SetFilterMTMode("SmoothTweak16",       MT_NICE_FILTER)
SetFilterMTMode("SmoothCurve16",       MT_NICE_FILTER)
SetFilterMTMode("SmoothCustom16",      MT_NICE_FILTER)
SetFilterMTMode("SmoothTools16",       MT_NICE_FILTER)

# SetFilterMTMode("yadifmod2",           MT_NICE_FILTER) # Starting from v0.0.4 this plugin will self-register the apropriate MT mode
 
#########################################
# Filters from MVTools v2.6.0.5 (from http://forum.doom9.org/showthread.php?p=1386559#post1386559 ) Tested On 2016/03/06

#########################################
#Filters from EEDI2 v0.9.2 (from http://forum.doom9.org/showthread.php?t=173238 ) Tested On 2016/03/06
 
########################################

 
########################################
 
#########################################
#keep it the last line please
# this isn't actually optimal, because it will also disable avstp threads if running 
# on a single-threaded filter chain
#avstp_set_threads(0, 1)   #disable threading in dither and mvtools2
