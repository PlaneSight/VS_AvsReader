############################################################################
/*
 MatchFrames v1.15, by StainlessS:

 Find And return frames in c clip that are best matched to frames in f clip.
 Planar, YUY2, RGB24/32. Previously YV12 only.
 Null Audio returned.
 ##################################
 Based on FindFrame() (c) Gavino.         http://forum.doom9.org/showthread.php?p=1569622#post1569622
 Required: GScript    (c) Gavino:         http://forum.doom9.org/showthread.php?t=147846
 Required: RT_Stats v2.0 (c) StainlessS:  http://forum.doom9.org/showthread.php?p=1584313
 Recommended FrameSel (c) StainlessS:     http://forum.doom9.org/showthread.php?t=167971
 Recommended DebugView utility to view and capture output: http://technet.microsoft.com/en-gb/sysinternals/bb545027
 MatchFrames  THREAD:                     http://forum.doom9.org/showthread.php?t=164766
 LocateFrames POST:                       http://forum.doom9.org/showthread.php?p=1600961#post1600961
 ##################################

 MatchFrames(clip c,clip f,bool "Show"=true,float "Thresh"=0.0,float "Thresh2"=0.0,
               \ string "FileName"="MatchframesCmd.txt",string "LogFile"=="Matchframes.Log",
               \ int "Start"=0,int "Stop"=0,bool "XP"=true,Bool "Chroma"=false,Float "ChromaWeight"=1/3.0,string "Title"="",bool "debug"=true,
               \ int "X"=0,int "Y"=0,int "W"=0,int "H"=0,Int "Matrix"=2,Bool "PD"=True)

 Args:

 c       = clip, Source clip.
 f       = clip, Consisting of frames that you wish to find in the c clip.
 Show    = bool[true], True returns both find and found frames using StackHorizontal. NOTE, hires clips, may cause problems in eg VDUB
                if StackHorizontal width goes over some VD imposed limit.
 Thresh  = float[0.0 == Search for 1st exact match or best possible if no exact match found]. Threshold for declaring match (diff <= Thresh).
           Range 0.0 -> 255.0.
 Thresh2 = float[0.0 == NOT time ordered]. Both a 'time ordered' indicator and a threshold.
           If (Thresh < Thresh2) Then clip f is taken as time ordered (in c), ie frames in both f and c clips are temporally ordered.
           If f clip is known to be time ordered (in c), this arg can significantly cut down on the time taken to search for frames.

           Assuming time ordered f clip (Thresh < Thresh2),

               If a match found where diff of find to found frame <= Thresh,
                    Next frame search will start from found frame + 1.
               Else if diff of find to Full Scan BEST found frame < Thresh2
                    Next frame search will start from BEST found frame + 1.
               Else
                    Next frame search will start from current start position.
               End if
               *** Where above 'Full Scan' means scan from current start postion to the last valid search frame.

 FileName= string["MatchFramesCmd.txt"], Output Frames command file.
             Can use FrameSel() Plugin to select frames using MatchFramesCmd.txt Command file.
             FrameSel() Plugin can be found here:- http://forum.doom9.org/showthread.php?t=167971
             Can monitor the MatchFramesCmd.txt file during scanning to view progress (ie view in notepad, [Read-Only viewer maybe safer]).

 LogFile = string["MatchFrames.Log"], Output Log file. Can monitor as for command file.
             The Logfile might produce an output line like that below:

             "0]=[1100] Diff=0.239 (T1:XP) S=1000 E =1101 XPCNT=5"

             Where eg 0] is find frame number, [1100] is found frame,
             Diff is the Difference (Luma + optional Chroma) between find and found frames.
             S and E are the search start and end positions that were searched for that frame.
             The "(T1:XP)" stuff presents just a little info about the search:
              "(BM:  )" Best Match, where no frame was found with a Diff <= Thresh, the returned frame was best match found in search area.
              "(BM:T2)" Same as "(BM:  )" but was an Ordered search & because Diff<Thresh2, then next frame search will start at Best Match+1.
              "(T1:  )" Means that the found frame had a Diff <= Thresh.
              "(T1:XP)" Same as "(T1:  )" but Xtra Paranoia (XP) successfully found a better matching frame following the one that
              initially broke thresh. If this flag is shown, you will also see "XPCNT" which will tell how many successive better frames
              were found after the initial frame that broke Thresh.
              See Debug arg below to view real time output in DebugView window without slight risk involved reading open log file.

 Start   = int[0, == First frame of clip], Start frame to search from (eg Skip introduction).
 Stop    = int[0, == Last frame of clip + 1], Frame prior to which, c clip is searched (Exclusive). (eg Skip end credits).
 XP      = bool[true == Extra Paranoid] Main purpose of XP is so that you can use Thresh > 0.0 even if you dont fully trust a non best search.
               If diff of find to found frame <= Thresh, then search would normally stop at that frame, but when
               XP is true (Default), it will continue to search so long as subsequent frames provide a better match. Will usually result
               in 1 extra frame being compared (providing that your Thresh is not too high).
               If Thresh is set to 0.0 (default) then will only stop search on EXACT match, and so is likely to do a full search
               (unless exact frame exists). XP allows you to settle for a close match by setting thresh a little above 0.0, and when a close
               match is found, it will continue to edge forward 1 frame at a time until matches cease to be better.
               If exact match was found, ie diff == 0.0 then will not scan extra frames (no better match possible).

 Chroma   = bool[false==Luma diff Only], If true then also uses chroma difference as per ChromaWeight.
               THIS IS NO LONGER FUNCTIONAL, totally switched now via the ChromaWeight arg.

 ChromaWeight=float[1.0/3.0 ie 0.33333]. If Chroma==true then LumaWeight = 1.0-ChromaWeight.
               If Chroma==false then ChromaWeight is ignored and only luma difference is used.
               Chroma and ChromaWeight are for YUV only, not used for Y8 or RGB, no real advantage to using Luma only.
 Title    = string[""== none], Allows you to place a string of text in the Log and Command file headers, eg "Hires Test#2" or whatever.
 Debug    = bool[True == Debug info sent to debugview], True, send logging info to DebugView window (google DebugView),
            allows monitoring of progress without the slightly risky method of reading the open LogFile.
            Default True as cannot change your mind in middle of long search, does not have significant overhead in producing debug log.
            False, switch real time debug logging off.
            This setting has nothing whatever to do with below pre v1.10 DEBUG MODE, see below.

 X        = int[0], X coord, allow avoid some edge artefact or logo.
 Y        = int[0], Y coord, allow avoid some edge artefact or logo.
 W        = int[0], W coord, allow avoid some edge artefact or logo.
 H        = int[0], H coord, allow avoid some edge artefact or logo.

Matrix    = int[2,PC601]. #  Matrix: Default=2(PC601), 3=PC709. Used in conversion of RGB to YUV-Y. (Best not use 0 or 1, TV levels)

 PD       = True. New in v1.13, uses Pearsons Distance measure instead of RT_FrameDifference (well actually a limited variation of it).
            To make the function work with both RT_FrameDifference and the PD=True methods, it is necessary for them  both to return similar-ish
            value, ie 0.0 being identical and 255.0 being totally different. RT__FrameDifference returns the average pixel difference across the
            whole frame (in X,Y,W,H area). For RT_FrameDifference can also weight in the U&V compnent differences by specifying ChromaWeight.
            For RGB, a little new functionality has been added (RT_Stats v2.0). If ChromaWeight is specified as 0.0, then RT_FrameDifference
            returns Exactly the same as LumaDifference, but if ChromaWeight is non 0.0, then for RGB, it will return the average channgel difference,
            ie (RDif + GDif + BDif) / 3. [For LumaDifference mode, RGB converted to Luma-Y, uses Matrix arg].
            Our limited version of Pearsons Distance goes like this
                PD = Min(1.0 - LumaCorrelation, 1.0) * 255.0, result in range 0.0 -> 255.0 where 0.0 means identical.
            when PD=True, ChromaWeight has no function.
            Pearsons distance, based on Correlation, is not so perturbed by small changes in frame bightness, and may be better for matching
            than the standard Average Pixel Difference mode.
            Correlation      limited PD
                1.00             00.00
                0.95             12.75
                0.90             25.50
                0.85             38.25
                0.80             51.00
                0.75             63.75
                0.70             76.50
                0.65             89.25
                0.60            102.00
                0.55            114.75
                0.50            127.50

 ##################################
 DEBUG MODE: If the f FrameCount and c[START,STOP] FrameCount (ie STOP-START) are same AND Thresh < Thresh2 (ie Ordered), then the script is put
 into DEBUG MODE. This would be easiest achieved when START and STOP are at their default 0 values meaning 'All of c clip' and lengths of
 f and c are same.
 In Debug Mode, there is no searching for best match, log is produced with difference between all corresponding frames
 and in the footer of the log, it will show Average Diff, Min Diff, and Max Diff for the entire frame set.
 In DEBUG MODE, the command file is cleared, prints header only.
 ##################################

 Will take some time to show results, it is not a bug if it seems to hang, it is WORKING HARD.

*/

Function MatchFrames(clip c,clip f,bool "Show",float "Thresh",float "Thresh2",string "FileName",string "LogFile",
        \ int "Start",int "Stop",bool "XP", Bool "Chroma",Float "ChromaWeight",string "Title",bool "Debug",
        \ int "X",int "Y",int "W",int "H",Int "Matrix",Bool "PD"
        \ ) {
    ver         = "v1.15 - 02 Aug 2018"                 # Version Number
    myName		="MatchFrames: "
	IsAvsPlus=(FindStr(UCase(versionString),"AVISYNTH+")!=0)    HasGScript=RT_FunctionExist("GScript")
	Assert(IsAvsPlus || HasGScript,RT_String("%sNeed either GScript or AVS+",myName))

    c = c.Killaudio()   f = f.Killaudio()               # Audio return not sensible.
    Show        = Default(Show,true)                    # Defaults true = show StackHorizontal find & found frames
    Thresh      = Float(Default(Thresh, 0.0))           # Threshold for declaring match, Default==0.0 to search for best possible match.
    Thresh2     = Float(Default(Thresh2,0.0))           # Threshold2 Default==0.0, find clip f, not time ordered.
    FileName    = Default(FileName,"MatchFramesCmd.txt")# "" to switch OFF Frames output command file.
    LogFile     = Default(LogFile,"MatchFrames.Log")    # "" to switch OFF Logfile.
    Start       = Default(Start,0)                      # Frame to start search from.
    Stop        = Default(Stop,0)                       # Frame to stop search (0 == last frame + 1).
    XP          = Default(XP,true)                      # Extra Paranoid, dont fully trust Thresh.
    Chroma      = Default(Chroma,True)                  # Default Luma + Chroma.
    ChromaWeight= Float(Default(ChromaWeight,1.0/3.0))  # Default, 33% of Total Difference (Combined U and V).
    Title       = Default(Title,"")                     # Shown in log and command file, Default "".
    Debug       = Default(Debug,True)                   # Default no debug logging to DebugView
    X           = Default(X,0)
    Y           = Default(Y,0)
    W           = Default(W,0)
    H           = Default(H,0)
    Matrix      = Default(Matrix,2)						# PC601
    PD          = Default(PD,True)                      # v 1.14, changed default to True
    Start       = (Start<0)?0:Start                     # Silent check
    Stop=(Stop<=0||Stop>c.FrameCount)?c.FrameCount:Stop # Silent check
    cfrms       = Stop-Start                            # Number of frames to scan in c
    ChromaWeight=(Chroma)?ChromaWeight:0.0              # If Not Needed, ignore default weight.
    Assert(c.Width==f.Width,myName+"- Clip Width mismatch")
    Assert(c.Height==f.Height,myName+"- Clip Height mismatch")
    Assert(RT_VarIsSame(c,f),myName+"- ColorSpace Mismatch")    # Same colorspace ?
    Assert(cfrms>0,myName+"- Invalid Start>=Stop")
    Assert(Thresh>=0.0,myName+"- Invalid Thresh")
    Assert(f.Framecount<=cfrms,myName+"- f Frames > c[START,STOP] Frames")
    Assert(ChromaWeight>=0.0&&ChromaWeight<=1.0,myName+"- ChromaWeight Range 0.0->1.0")
    DBug = (cfrms==f.FrameCount && Thresh < Thresh2)    # Debugging Mode ?
    Thresh  = (DBug) ? 255.0 : Thresh                   # If DBug, Ensure everything breaks Thresh.
    Thresh2 = (DBug) ? 255.1 : Thresh2                  # If DBug, Maintain Ordered.
    TDHi =0.0                                           # DEBUG: TotalDifference Hi  (Extra precision)
    TDLo =0.0                                           # DEBUG: TotalDifference Lo
    MinDiff  = 255.0 + 1.0                              # DEBUG: Output, max + 1
    MaxDiff  = 0.0 - 1.0                                # DEBUG: Output, min - 1
    Ordered  = Thresh < Thresh2                         # If true then: Find frames are in time order (match(f[n]) searches from match(f[n-1])+1
    Result = 0                                          # Dummy, Will become a Clip, Dont use 'c.BlankClip(length=0)' (Maybe StackHorizontal)
    Scanned = 0                                         # Init Total Frames scanned
    EOL = Chr(10)                                       # End Of Line. (Do NOT use Carriage Return, Line Feed, Will auto add the CR)
    TLINE = "##########################################################################" + EOL
    TGEN  = "# MatchFrames " + Ver
    TCMD  = "Command File for FrameSel() Plugin." + EOL + "#" + EOL
    TLOG  = " (c) StainlessS : LogFile." + EOL + "#" + EOL
    TNAM  = (Title=="") ? "" : "# Title='" + Title + "'" + EOL + "#" + EOL
    TSET  = "# Width=" + String(c.Width) + " : Height=" + String(c.Height) + " : Start=" + String(Start) + " : Stop=" + String(Stop)
            \ + ((ORDERED && !DBug) ? " : ORDERED" : "") + EOL+"#"+EOL
    TSET2 = "# Thresh="+String(Thresh,"%.3f")+" : Thresh2="+String(Thresh2,"%.3f")+" : XP="+String(XP)
    TSET3 = ((Chroma)?" : ChromaWeight="+String(ChromaWeight,"%.3f"):"") + EOL + "#" + EOL
    TSET4 = ((DBug) ? "# DEBUG MODE" + EOL:"") + "#" + EOL
    LogT = RT_String("%s#\n%s%s%s%s%s%s%s%s",TLINE,TGEN,TLOG,TNAM,TSET,TSET2,TSET3,TSET4,TLINE)
    (Debug) ? RT_DebugF("%s",LogT,name=myName)  : NOP           # DebugView
    (LogFile !="") ? RT_WriteFile(LogFile, "%s",LogT)   : NOP
    (FileName!="") ? RT_WriteFile(FileName,"%s#\n%s : %s%s%s%s%s%s%s",TLINE,TGEN,TCMD,TNAM,TSET,TSET2,TSET3,TSET4,TLINE) : NOP
    FileName= (DBug) ? "" : FileName                # No Command file frame numbers if DBug Mode, HEADER ONLY (ie Wipe command file).
    TimeStart = RT_LocalTimeString(file=false)      # Format "YYYY-MM-DD HH:MM:SS.mmm"
    Start_Secs = RT_TimerHP()
    GS="""
    for(ix = 0, f.Framecount-1) {                   # Iterate through find frames clip.
        s = Start                                   # Init Start search position
        BestSoFar       = s                         # Search start position
        BestSoFarDiff   = 255.0 + 1.0               # Maximum Possible + 1
        sS =" S=" + String(s,"%-4.0f")              # Start offset this time, as string (at least 4 digits)
        mS=" (BM:  )"                               # Init to 'scanned all the way' message (Flag Best Match).
        eterm=(Ordered)?Stop-f.Framecount+ix:Stop-1 # Init last frame to compare for this iteration.
        e=eterm                                     # Init to 'scanned all the way'
        Assert(s<=e,myName+"- Internal Error, s > e")  # Oops.
        xS=""                                       # Prep XP skip Count string
        for(n=s, eterm) {                           # Search c clip(s to eterm) or until satisfactory match found. (eterm evaluated on entry only)
            # Difference to current find frame.
            CurrDiff=(PD)
                \ ? Min(1.0-RT_LumaCorrelation(c,f,n=n,x=X,y=Y,w=W,h=H,n2=ix,Matrix=Matrix),1.0)*255.0
                \ : RT_FrameDifference(c,f,n=n,n2=ix,ChromaWeight=ChromaWeight,Matrix=Matrix,x=X,y=Y,w=W,h=H)
            if(CurrDiff < BestSoFarDiff) {                      # Better match than found so far ?
                BestSoFar       = n                             # Remember frame number
                BestSoFarDiff   = CurrDiff                      # Remember difference
                if(BestSoFarDiff <= thresh) {                   # Good enough to satisfy user requirement ?
                    if(DBug) {                                  # DEBUG
                        MinDiff = Min(CurrDiff,MinDiff)
                        MaxDiff = Max(CurrDiff,MaxDiff)
                        TDLo = TDLo + CurrDiff
                        TDHi = TDHi + floor(TDLo / 256.0)       # Hi part, Extra Precision
                        TDLo = frac(TDLo / 256.0) * 256.0       # Lo part, Extra Precision
                    }
                    e=BestSoFar                                 # Where we've scanned to so far
                    mS=" (T1:  )"                               # Found satisfactory frame, (Flag Thresh)
                    if(XP && BestSoFar < eterm && BestSoFarDiff > 0.0) { # DBug will NOT enter here!, eterm condition will fail.
                        tmp = BestSoFar                         # Remember
                        for(n=BestSoFar+1,eterm) {
                            CurrDiff=(PD)
                                \ ? Min(1.0-RT_LumaCorrelation(c,f,n=n,x=X,y=Y,w=W,h=H,n2=ix,Matrix=Matrix),1.0)*255.0
                                \ : RT_FrameDifference(c,f,n=n,n2=ix,ChromaWeight=ChromaWeight,Matrix=Matrix,x=X,y=Y,w=W,h=H)
                            e=n                                 # We scanned more frames past original BestSoFar
                            if(CurrDiff < BestSoFarDiff) {      # Better match ?
                                if(ix < f.Framecount-1) {
                                    # Check if XP advance makes problem for next ix find
                                    ChkDiff=(PD)
                                        \ ? Min(1.0-RT_LumaCorrelation(c,f,n=n,x=X,y=Y,w=W,h=H,n2=ix+1,Matrix=Matrix),1.0)*255.0
                                        \ : RT_FrameDifference(c,f,n=n,n2=ix+1,ChromaWeight=ChromaWeight,Matrix=Matrix,x=X,y=Y,w=W,h=H)
                                    if(ChkDiff>CurrDiff) {              # OK, no problem for next ix iteration
                                        BestSoFar    = n                # Remember frame number
                                        BestSoFarDiff= CurrDiff         # Remember                                        
                                    } Else {            # Override XP advance
                                        n = eterm+1     # Force Exit with current_frame == eterm + 2 (normally exit @ eterm+1)
                                    }                                        
                                } Else {                                    
                                    BestSoFar    = n                # Remember frame number
                                    BestSoFarDiff= CurrDiff         # Remember
                                }
                            } else {
                                n = eterm+1                     # Force Exit with n == eterm + 2 (normally exit @ eterm+1)
                            }
                        }
                        if(BestSoFar != tmp) {
                            mS=" (T1:XP)"                       # Found satisfactory frame, (Flag Thresh, and Xtra Paranoid found better frame)
                            xS=" XPCNT=" + String(BestSoFar-tmp)# How many frames Xtra Paranoid skipped to find better match than Thresh.
                        }
                    }
                    Start=(Ordered)?BestSoFar+1:Start           # If required, Next time search from BestSoFar + 1
                    n = eterm + 1                               # Force Exit with current_frame == eterm + 2 (normally exit @ eterm + 1)
                }
            }
        }
        if(Ordered && n == eterm+1 && BestSoFarDiff < Thresh2) {
            mS = " (BM:T2)"                                     # For Log, Time ordered, (Flag, Best Match and Thresh2)
            Start = BestSoFar + 1                               # Next time start from BEST MATCH found + 1.
        }
        Scanned = Scanned + e - s + 1
        Text = RT_String("%4d]=[%6d] Diff=%7.3f%s%s E =%-4.0f%s",ix,BestSoFar,BestSoFarDiff,ms,sS,e,xS)
        (Debug) ? RT_DebugF("%s",Text,name=myName) : NOP                                            # DebugView
        (LogFile!="")  ? RT_WriteFile(LogFile,"%s",Text,Append=true) : NOP              # Log file
        (FileName!="") ? RT_WriteFile(FileName,"%d",BestSoFar,Append=true) : NOP        # Command file
        FindFrame =f.Trim(ix,-1).SubTitle(Text)
        wrClip    =c.Trim(BestSoFar,-1)
        GotFrame=(Show) ? StackHorizontal(FindFrame,wrClip) : wrClip
        Result = (IsClip(Result)) ? Result ++ GotFrame : GotFrame                       # Append to 'result clip so far'.
    }
    """ # End Of GScript

  	HasGScript ? GScript(GS) : Eval(GS) # Use GSCript if installed (loaded plugs override builtin)

    TimeEnd = RT_LocalTimeString(file=false)
    Tim = RT_TimerHP - Start_Secs
    Text = RT_String("\n%s\nStart Time = %s\nEnd   Time = %s\nTotal Time = %.3f Secs (%.3f Mins)\n",TLINE,TimeStart,TimeEnd,Tim,Tim/60.0)
    Text2 = RT_String("Total Frames Searched =%6d (%7.3f FPS : %10.6f SPF)",Scanned,Scanned/Tim,Tim/Scanned)
    Text3 = RT_String("Find Frames Located   =%6d (%7.3f FPS : %10.6f SPF)",f.FrameCount,f.FrameCount/Tim,Tim/f.FrameCount)
    (Debug) ? RT_DebugF("%s\n%s\n%s",Text,Text2,Text3,name=myName) : NOP
    (LogFile!="") ? RT_WriteFile(LogFile,"%s\n%s\n%s",Text,Text2,Text3,Append=True) : NOP
    Text4 = RT_String("DEBUG: AveDiff=%.3f : MinDiff=%.3f : MaxDiff=%.3f : [L=%.3f : (U+V)=%.3f]\n",
        \ (TDHi / cfrms * 256.0) + (TDLo / cfrms),MinDiff,MaxDiff,1.0-ChromaWeight,ChromaWeight)
    (DBug&&Debug)       ? RT_DebugF("%s",Text4,name=myName)             : NOP
    (DBug&&LogFile!="") ? RT_WriteFile(LogFile,"%s",Text4,Append=True)  : NOP
    Return Result.AssumeFPS(1.0)
}
