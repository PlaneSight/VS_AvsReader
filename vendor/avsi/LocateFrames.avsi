Function LocateFrames(clip c,clip f,float "Thresh",float "Thresh2",int "Start",int "Stop",bool "XP", Bool "Chroma", \
      Float "ChromaWeight",String "Prefix",bool "Debug",String "DB",int "X",int "Y",int "W",int "H",Int "Matrix",Bool "PD") {

/*
 LocateFrames() v1.15 by StainlessS:
 Find frames in c clip that are best matched to frames in f clip.
 Planar, YUY2, RGB24/32.

 Returns either a result string (old method) or if given a string DB arg, creates RT_Stats DB DataBase file, and returns number of records, Int.

 ##################################
 Based on FindFrame() (c) Gavino.         http://forum.doom9.org/showthread.php?p=1569622#post1569622
 Required: GScript    (c) Gavino:         http://forum.doom9.org/showthread.php?t=147846
 Required: RT_Stats v2.0 (c) StainlessS:  http://forum.doom9.org/showthread.php?p=1584313
 Recommended FrameSel (c) StainlessS:     http://forum.doom9.org/showthread.php?t=167971
 Recommended DebugView utility to view and capture output: http://technet.microsoft.com/en-gb/sysinternals/bb545027
 MatchFrames  THREAD:                     http://forum.doom9.org/showthread.php?t=164766
 LocateFrames POST:                       http://forum.doom9.org/showthread.php?p=1600961#post1600961
  ##################################

Function LocateFrames(clip c,clip f,float "Thresh"=0.0,float "Thresh2"0.0,int "Start"=0,int "Stop"=0,bool "XP"=True, Bool "Chroma"=false, \
      Float "ChromaWeight"=1/3.0,String "Prefix"="LF_",bool "Debug"=True,String "DB"="",int "X"=0,int "Y"=0,int "W"=0,int "H"=0,Int "Matrix"=2,Bool "PD"=True) {

 Args:

 c       = clip, Source clip.
 f       = clip, Consisting of frames that you wish to find in the c clip.
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
               Now Planar, YUY2, RGB (was YV12 only), Chroma and ChromaWeight are for YUV only, not used for Y8 or RGB,
               no real advantage to using Luma only.
 Prefix   = string("LF_"). Prefix prepended to variable names in returned string. (NOT USED if DBase mode, see below DB arg)
 Debug    = bool[True == Debug info sent to debugview], True, send logging info to DebugView window (google DebugView),
            allows monitoring of progress.
            v1.10, Default True as cannot change your mind in middle of long search, does not have significant overhead in producing debug log.
            False, switch real time debug logging off.

 DB       = string["" == Do Not Use DataBase]. Default "" as old version, where results returned in String as described below.
            v1.10, Otherwise, if DB != "" eg "LocateFrames.DB", then will create an RT_Stats DBase file using supplied DB as the filename,
            where results are stored in the Dbase and will return an Int, ie the number of frames in find f clip, which is also the
            number of records stored in the DB File. DB file created with typestring "iifiiii", in other words 7 fields per record.
            First two fields are Type Int, next 1 field of Type Float, then 4 fields of Type Int.
              Field 0 : Type Int   : LF_FOUND      Index of found clip frame
              Field 1 : Type Int   : LF_FIND       Index of find clip frame
              Field 2 : Type Float : LF_DIFF       FrameDifference() between find and found
              Field 3 : Type Int   : LF_START      Start frame searched
              Field 4 : Type Int   : LF_END        End frame searched
              Field 5 : Type Int   : LF_XPCNT      Count of extra frames advanced due to eXtra Paranoia setting, See above XP.
              Field 6 : Type Int   : LF_MATCH      Kind of match found.  # As for MatchFrames(), 0="BM", 1="(BM:T2)", 2="(T1:  )", 3="(T1:XP)"
              See below for explanation of field contents, and RT_Stats for usage of RT_DBaseGetField(String Filename,Int Record,Int Field).

 X        = int[0], X coord, allow avoid some edge artefact or logo.
 Y        = int[0], Y coord, allow avoid some edge artefact or logo.
 W        = int[0], W coord, allow avoid some edge artefact or logo.
 H        = int[0], H coord, allow avoid some edge artefact or logo.

 Matrix   = int[2,PC601]. #  Matrix: Default=2(PC601), 3=PC709. Used in conversion of RGB to YUV-Y. (Best not use 0 or 1, TV levels)

 PD       = True. New in v1.13, v1.14 made Default True.
            True=Uses Pearsons Distance measure instead of RT_FrameDifference (well actually a limited variation of it).
            To make the function work with both RT_FrameDifference and the PD=True methods, it is necessary for them  both to return similar-ish
            value, ie 0.0 being identical and 255.0 being totally different. RT__FrameDifference returns the average pixel difference across the
            whole frame (in X,Y,W,H area). For RT_FrameDifference can also weight in the U&V compnent differences by specifying ChromaWeight.
            For RGB, a little new functionality has been added (RT_Stats v2.0). If ChromaWeight is specified as 0.0, then RT_FrameDifference
            returns Exactly the same as LumaDifference, but if ChromaWeight is non 0.0, then for RGB, it will return the average channgel difference,
            ie (RDif + GDif + BDif) / 3. [For LumaDifference mode, RGB converted to Luma-Y, uses Matrix arg].
            Our limited version of Pearsons Distance goes like this
                PD = Min(1.0 - LumaCorrelation, 1.0) * 255.0, result in range 0.0 -> 255.0 where 0.0 means identical.
            when PD=True, ChromaWeight has no function.
            Pearsons distance, based on Correlation, is not so perturbed by small changes in frame brightness, and may be better for matching
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

 Returns newline [Chr(10)] separated list of results as a multiline String, OR results stored in DB Database File, where it returns
  the number of records in the DB file (ie frames in Findclip f).

  STRING RESULT:-
   Results string for a single frame find clip using default "LF_" prefix, as in format:-

     "LF_FOUND=1100   LF_FIND=0   LF_DIFF=0.006134 LF_START=1000   LF_END=1599   LF_XPCNT=0   LF_MATCH=0"

     LF_FOUND= Index of found clip frame
     LF_FIND = Index of find clip frame
     LF_DIFF = FrameDifference() between find and found (range 0.0 -> 255.0)
     LF_START= Start frame searched
     LF_END  = End frame searched
     LF_XPCNT= Count of extra frames advanced due to eXtra Paranoia setting, See above XP.
     LF_MATCH= Kind of match found.  # As for MatchFrames(), 0="BM", 1="(BM:T2)", 2="(T1:  )", 3="(T1:XP)"

           0= Best Match, where no frame was found with a Diff <= Thresh, the returned frame was best match found in search area.
           1= Same as 0 but was an Ordered search & because Diff<Thresh2, then next frame search will start at Best Match+1.
           2= Means that the found frame had a Diff <= Thresh.
           3= Same as 2 but Xtra Paranoia (XP) successfully found a better matching frame following the one that
              initially broke thresh. "XPCNT" will tell how many successive better frames were found after the initial
              frame that broke Thresh.

   Can use RT_Stats functions eg
     RT_TxtQueryLines() to inquire lines of text in result string (same as frames in find f clip).
     RT_TxtGetLine() to extract a single result (if multiple find frames) from the combined results string.
   Can use eg "Eval(s)" to set variables where s is a single line result string.

   The innards of LocateFrames are much like MatchFrames, but could be more useful as implemented to use results
   programatically in other scripts.

   Use DebugView utility to view and capture output.

   Brief example usage:

    GScript("""
       myName="StringResultScript:"
       SearchClip=avisource("D:\avs\xmen2.avi").trim(4000,-1000)                                   # 1000 frame SearchClip
       FindClip=SearchClip.SelectEvery(100,0).Blur(1.58)                                           # 10 frame FindClip, Make a bit Different
       Results=LocateFrames(searchclip,findclip)
       n = RT_TxtQueryLines(Results)                                                               # Same as number of frames in findclip.
       Result = 0                                                                                  # Will become clip
       for(i=0,n-1) {
           s=RT_TxtGetLine(Results,Line=i)                                                         # Get individual result string
           Eval(s)                                                                                 # Set variables for this find frame
           RT_DebugF("Found frame %d for find frame %d Had a diff of %f",LF_FOUND,LF_FIND,LF_DIFF,name=myName)
           Lft=FindClip.Trim(LF_FIND,-1).RT_SubTitle("%d DIFF=%f",LF_FIND,LF_DIFF)                 # Find Frame
           Rgt=SearchClip.Trim(LF_FOUND,-1).RT_SubTitle("%d",LF_FOUND)                             # Found Frame
           Stak = StackHorizontal(Lft,Rgt)
           Result = (Result.IsClip) ? Result ++ Stak : Stak                                        # Append to clip so far
       }
       Return Result.AssumeFPS(1.0)
    """)
    Return Last
 ##################################

 DBASE RESULT:- (actual result is Int, number of records in created DB, ie frames in FindClip)

    SearchClip=avisource("D:\avs\xmen2.avi").trim(4000,-1000)                                      # 1000 frame SearchClip
    FindClip=SearchClip.SelectEvery(100,0).Blur(1.58)                                              # 10 frame FindClip, Make a bit Different
    DEBUG=True
    myName="DB_Script: "
    DB="~MyDbase_" + RT_LocalTimeString(File=True)+".DB"                                           # Unique Temporary DBase filename
    Records = LocateFrames(SearchClip,FindClip,debug=DEBUG,db=DB)                                  # Same as number of frames in FindClip.
    RT_DebugF("I got %d Records",Records,name=myName)                                              # Send to DebugView
    Result = 0                                                                                     # Will later be a clip
    GScript("""
        for(i=0,Records-1) {
            FoundIx = RT_DBaseGetField(DB,i,0)                                                      # Frame we found (Int)
            FindIx  = RT_DBaseGetField(DB,i,1)                                                      # Frame that we had to find (Int)
            Diff    = RT_DBaseGetField(DB,i,2)                                                      # FrameDifference (Float)
            RT_DebugF("%d ] Found frame %d with Difference of %f",FindIx,FoundIx,Diff,name=myName)
            Lft=FindClip.Trim(FindIx,-1).RT_SubTitle("%d DIFF=%f",FindIx,Diff)                      # Find Frame
            Rgt=SearchClip.Trim(FoundIx,-1).RT_SubTitle("%d",FoundIx)                               # Found Frame
            Stak = StackHorizontal(Lft,Rgt)
            Result = (Result.IsClip) ? Result ++ Stak : Stak                                        # Append to clip so far
        }
        RT_FileDelete(DB)                                                                           # Delete temp DB file
    """)
    Return Result.AssumeFPS(1.0)
*/

 ##################################
    myName		= "LocateFrames: "
	IsAvsPlus=(FindStr(UCase(versionString),"AVISYNTH+")!=0)    HasGScript=RT_FunctionExist("GScript")
	Assert(IsAvsPlus || HasGScript,RT_String("%sNeed either GScript or AVS+",myName))

    ver         = "v1.15 - 02 Aug 2018"                 # Version Number
    c = c.Killaudio()   f = f.Killaudio()               # Audio not needed.
    Thresh      = Default(Thresh, 0.0)                  # Threshold for declaring match, Default==0.0 to search for best possible match.
    Thresh2     = Default(Thresh2,0.0)                  # Threshold2 Default==0.0, find clip f, not time ordered.
    Start       = Default(Start,0)                      # Frame to start search from.
    Stop        = Default(Stop,0)                       # Frame to stop search (0 == last frame + 1).
    XP          = Default(XP,true)                      # Extra Paranoid, dont fully trust Thresh.
    Chroma      = Default(Chroma,False)                 # Default Luma Only.
    ChromaWeight= Default(ChromaWeight,1.0/3.0)         # Default, 33% of Total Difference (Combined U and V).
    Prefix      = Default(Prefix,"LF_")
    Debug       = Default(Debug,True)                   # v1.10, changed True
    DB          = Default(DB,"")                        # DBase not default
    X           = Default(X,0)
    Y           = Default(Y,0)
    W           = Default(W,0)
    H           = Default(H,0)
    Matrix      = Default(Matrix,2)						# PC601
    PD          = Default(PD,True)                      # Made default True in v1.14.
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
    MODE = (DB!="")
    Ordered  = Thresh < Thresh2                         # If true then: Find frames are in time order (match(f[n]) searches from match(f[n-1])+1
    FMT="%sFOUND=%-6d %sFIND=%-6d %sDIFF=%f %sSTART=%d %sEND=%-6d %sXPCNT=%-3d %sMATCH=%d"
    Result = ""
    GS="""
		(DEBUG) ? RT_DebugF("\n%s %s (%s Mode)\n",myName, Ver,(!MODE)? "STRING" : "DBASE",name=myName) : NOP
        if(MODE) {RT_DBaseAlloc(DB,0,"iifiiii")}
        for (ix = 0, f.Framecount-1) {                  # Iterate through find frames clip.
            s = Start                                   # Init Start search position
            BestSoFar       = s                         # Search start position
            BestSoFarDiff   = 255.0 + 1.0               # Maximum Possible + 1
            sS =s                                       # Start offset this time
            mS= 0                                       # " (BM:  )", Init to 'scanned all the way' message (Flag Best Match).
            eterm=(Ordered)?Stop-f.Framecount+ix:Stop-1 # Init last frame to compare for this iteration.
            e=eterm                                     # Init to 'scanned all the way'
            Assert(s<=e,myName+"- Internal Error, s > e")  # Oops.
            xpCnt=0                                     # Prep XP skip Count string
            for(n=s, eterm) {               # Search c clip(s to eterm) or until satisfactory match found. (eterm evaluated on entry only)
                # Difference to current find frame.
                CurrDiff=(PD)
                    \ ? Min(1.0-RT_LumaCorrelation(c,f,n=n,x=X,y=Y,w=W,h=H,n2=ix,Matrix=Matrix),1.0)*255.0
                    \ : RT_FrameDifference(c,f,n=n,n2=ix,ChromaWeight=ChromaWeight,Matrix=Matrix,x=X,y=Y,w=W,h=H)
                if(CurrDiff < BestSoFarDiff) {          # Better match than found so far ?
                    BestSoFar       = n                 # Remember frame number
                    BestSoFarDiff   = CurrDiff          # Remember difference
                    if(BestSoFarDiff <= thresh) {       # Good enough to satisfy user requirement ?
                        e=BestSoFar                     # Where we've scanned to so far
                        mS=2                            # " (T1:  )", Found satisfactory frame, (Flag Thresh)
                        if(XP && BestSoFar < eterm && BestSoFarDiff > 0.0) { # DBug will NOT enter here!, eterm condition will fail.
                            tmp = BestSoFar             # Remember
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
                                    n = eterm+1                         # Force Exit with current_frame == eterm + 2 (normally exit @ eterm+1)
                                }
                            }
                            if(BestSoFar != tmp) {
                                mS=3                   # " (T1:XP)", Found satisfactory frame, (Flag Thresh, and Xtra Paranoid found better frame)
                                XpCnt=BestSoFar-tmp    # How many frames Xtra Paranoid skipped to find better match than Thresh.
                            }
                        }
                        Start=(Ordered)?BestSoFar+1:Start   # If required, Next time search from BestSoFar + 1
                        n = eterm + 1                       # Force Exit with current_frame == eterm + 2 (normally exit @ eterm + 1)
                    }
                }
            }
            if(Ordered && n == eterm+1 && BestSoFarDiff < Thresh2) {
                mS = 1                                      # " (BM:T2)", For Log, Time ordered, (Flag, Best Match and Thresh2)
                Start = BestSoFar + 1                       # Next time start from BEST MATCH found + 1.
            }
            if(MODE) {
                (DEBUG) ? RT_DebugF(FMT,Prefix,BestSoFar,Prefix,ix,Prefix,BestSoFarDiff,Prefix,sS,Prefix,e,Prefix,XpCnt,Prefix,mS,name=myName) : NOP
                RT_DBaseAppend(DB,BestSoFar,ix,BestSoFarDiff,sS,e,XpCnt,mS)
            } Else {
                Text = RT_String(FMT, Prefix,BestSoFar,Prefix,ix,Prefix,BestSoFarDiff,Prefix,sS,Prefix,e,Prefix,XpCnt,Prefix,mS)
                Result = RT_TxtAddStr(Result,Text)              # Avoid string concatenation bug in v2.58 and v2.6a3.
                (DEBUG) ? RT_DebugF("%s",Text,name=myName) : NOP
            }
        }
    """ # End Of GScript

	HasGScript ? GScript(GS) : Eval(GS) # Use GSCript if installed (loaded plugs override builtin)

    return (MODE) ? f.FrameCount : Result           # Int return for Dbase and String if not DBase
}




