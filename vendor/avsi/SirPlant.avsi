# SirPlant.avs

/*

Function SirPlant(clip src,clip rep,
            \ string srcARR,string srcNxtARR, string repARR,string repNxtARR,
            \ Float "Th"=0.90,Float "Th2"=0.75,Float "LumaTol"=8.0,Int "MatchLen"=60,Int "SearchStep"=MatchLen/4,
            \ Float "CW"=1.0/3.0,Int "BlkW"=64,Int "BlkH"=BlkW,Int "OLapX"=BlkW/2,int "OLapY"=BlkH/2,
            \ Bool "Strict"=True,Int "InsMode"=0,String "Project"="Default",Bool "Debug"=True,Int "Verbosity"=1)

     Req:-
        RT_Stats v2.0 Beta 10,  http://forum.doom9.org/showthread.php?p=1787898#post1787898     (c) StainlessS
        Prune,                  http://forum.doom9.org/showthread.php?t=162446                  (c) StainlessS
        GScript,                http://forum.doom9.org/showthread.php?t=147846                  (c) Gavino
        DebugView,              https://technet.microsoft.com/en-us/sysinternals/debugview.aspx (c) SysInternals (M$).

     Function to generate a Prune() Command file to substitute/supplant sequences in src source clip with similar sequences from rep replacement clip.
     Both clips must have scenes similarly ordered (same size, Framerate, Colorspace etc). Can Also insert unique ranges in rep clip, into
     the src source clip at approximately the correct position (or both replace and insert, with all unique ranges in the single result clip,
     perhaps easier to hand edit into correct ordering).

     NOTE, RT_QwikScanCreate() which is used to create the srcARR, srcNxtARR, and repARR, and repNxtARR Arrays, sets the Matrix (RGB to Luma-Y)
     and X, Y, W, and H args used for RT_LumaCorrelation differencing. This function acquires those values from the ARR array ID's.
     The X, Y, W, and H args provided to RT_QwikScanCreate() will be used to avoid eg Logos on one clip that do not exist on other (as for Crop).

     For every rep replacement frame, it searches the entire src source clip (from current src clip position) for a frame that best matches (initially
     via RT_QwikScan FM mode to locate BEST MATCH, and then via RT_LumaCorrelation Th arg to see if match is good enough), this is Sync1 frame, if
     Sync1+1 ie Sync2 frames (also via Th) also match, then tries to match remainder of frames (both forwards and backwards using Th2) and the
     resulting range length is compared to MatchLen. If sufficiently long, then that range will be replaced. That is basically it. The function creates
     a Prune() Command file which is used to splice the sequences together. Note, Prune will Trim/Splice BOTH video and Audio.
     (It also alternately does a reverse scan to find current position src frame in rep clip, in between above rep scan failures, doing about same as above).

     Args:-
        src,        source clip.

        rep,        replacement/substitute clip (probably better quality clip of similar dimensions/colorspace and spatially in sync with src).

        srcArr,     RT_Stats Array filename, for array as created by RT_QwikScanCreate(), eg
                        RT_QwikScanCreate(src,"MySrc.ARR","","MySrcNxt.ARR",Matrix=Matrix,x=X,y=Y,w=W,h=H)
                            where
                                Matrix defaults (src.Width>1100||src.Height>600)?3:2) # 3=PC709, 2=PC601
                                X,Y,W,H are crop style coords (ignore eg logo).

        srcNxtARR,  RT_Stats Array filename, for array as created by RT_QwikScanCreate() as in above example.
                        Used for fast forward searching and locating of frames using RT_QwikScan().

        repArr,     RT_Stats Array filename, for array as created by RT_QwikScanCreate(), eg
                        RT_QwikScanCreate(rep,"MySrc.ARR","","MySrcNxt.ARR",Matrix=Matrix,x=X,y=Y,w=W,h=H)
                            where
                                Matrix defaults (src.Width>1100||src.Height>600)?3:2) # 3=PC709, 2=PC601
                                X,Y,W,H are crop style coords (ignore eg logo).

        repNxtARR,  RT_Stats Array filename, for array as created by RT_QwikScanCreate() as in above example.
                        Used for fast forward searching and locating of frames using RT_QwikScan().

        Th,         Default 0.90. LumaCorrelation threshold, greater or equal to this are considered similar frames. Th is used to find 'Sync' frames, and
                        Th should be greater than Th2. Range 0.0 < Th <= 1.0.
                        0.0 = not correlated, 1.0 = full correlation.

        Th2,        Default 0.75. LumaCorrelation threshold, greater or equal to this are considered similar frames, used for all remaining frames that are not
                        'Sync' frames. Range 0.0 < Th2 <= Th.

        LumaTol,    Default 8.0. Range 0.0->16.0. See RT_Stats RT_QwikScan docs. Suggest 16.0 if significant differences in brightness/contrast between clips,
                    lower is faster but may not find some frames if significant difference in brightness between src and rep clips.
                    Small increase in LumaTol results in significant speed decrease.
                    If you end up with duplicate ranges in result clip, then LumaTol is likely set too low, it cannot find the frames via RT_QwikScan fingerprint,
                    and so sees the frames as not matching.
                    When Verbosity=2, and Sync1 and Sync2 are shown high (In DebugView), but below Th, then Th is set too high to match frames.

        MatchLen,   Default = 60. Minimum number of frames (of source clip, when Strict=False) that must match, otherwise not replaced. Range 16 or more.

        SearchStep, Default MatchLen/4 (1 -> MatchLen). When frame search fails, the search frame number is incremented by this, and search retried. When matching frame
                    is found, will scan both forwards and backwards, re-doing frames that were stepped over. Higher faster, but possibility of missing some
                    matches.

        CW          Default 1.0/3.0 (0.0 -> 1.0),
                      ChromaWeight, 0.0 = Luma differencing only, else weighting for pair of chroma channels.
                      If RGB, 0.0 converts to Luma-Y using Matrix arg as used in creating Scan Arrays. If 0.0 < CW, then instead it differences using
                          (AvergeRedPixelDifference + AvergeGreenPixelDifference + AvergeBluePixelDifference) / 3.0.
                    The CW ChromaWeight arg is used during the (new in RT_Stats v2.0 Beta 4)  RT_QwikScan FM FrameMovement mode, See Blk args below.
                    CW==0.0 will be a little faster for YUV, and perhaps a little slower for RGB, suggest keep at default or close, maybe 0.2 or 0.1.

        BlkW,       Default 64 (8 <= BlkW, even only, Silently limited to frame dimensions).
                      Used in the new FM FrameMovement mode of RT_QwikScan.
                      RT_FrameMovement(), splits a frame into BlkW x BlkH blocks (repeated with overlaps of OLapX and OLapY), the result of RT_FrameMovement
                      is the greatest average pixel difference between similar positioned blocks in each frame, and so is more sensitive to localised movement
                      like lips moving, where the rest of the frame stays almost exactly the same, allows us to find the correct Sync frames whilst ignoring
                      most of the noise between clips.
                      Once we find a Sync Frame using RT_QwikScan FM mode (and LumaTol arg), we compare found frames with RT_LumaCorrelation Th arg, if greater
                      or equal, then Sync Frame + 1 also has to match greater or equal to Th. When the pair of Sync Frames match then we do a bi-directional
                      scan to establish the extent of matching frames, these additional frames have to be greater or equal to Th2 to be considered part of a
                      matching range. Lower BlkW will be a bit slower. See Also RT_QwikScan.

        BlkH,       Default BklW. (8 <= BlkH, even only, Silently limited to frame dimensions). See Above BlkW.

        OLapX,      Default BklW/2. (0 <= BlkW/2, Silently limited to frame dimensions). Block Overlap, See Above BlkW.

        OLapY,      Default BlkH/2. (0 <= BlkH/2, Silently limited to frame dimensions). Block Overlap, See Above BlkW.

        Strict,     Default True. If True, then compared ranges must match 1:1, if replacement rep clip has extra frames or fewer frames in places,
                    then matched ranges will break at those points.
                    If False, then will try to see if match will be re-established if allowing for fewer or more frames in the replacement clip.
                    NOTE, if set false, then audio must use audio from the 'Prune'ed clips to maintain audio sync, if the src and rep clips are NOT
                    of similar volume, then the effect will not be good (change in volume where ranges are replaced, the alternative is out of sync audio).
                    Suggest audio pre-normalizing of both clips, if Strict=False (Can just use original source audio if Strict=True).

        InsMode,    Default 0 (0->2).
                      0) Replace matching ranges.
                      1) Insert unique extra ranges in rep clip into src, at approximate correct postition (matching ranges not replaced).
                      2) Replace and Insert extras mode.
                        When inserting extra ranges into the source clip, we can never be always correct in the ordering (but we do try to predict correct order),
                      when we have a unique sequence in both clips, we do not know which should be inserted first, indeed one of the sequences may have to
                      be inserted midway in the other to be correct, we have no way of telling, but do try to match end of sequence frames to foretell
                      the correct ordering.

        Project,    Default "Default". Empty string "" will be converted to the default.
                    Project is the name prefix given to output command and log files. (Below output files using default project).
                        "Default_Command.txt"       # Prune Command file to create result clip.
                        "Default_UnUsed.txt"        # Prune Command file to create clip of 'unused' frames from rep replacement clip.
                        "Default_SirPlant.LOG"      # The log file.

        Debug,      Default True. Send info to DebugView (Google).

        Verbosity,  Default 1. (0 -> 2) higher more info when Debug=true.
*/

Function SirPlant(clip src,clip rep,string srcARR,string srcNxtARR,string repARR,string repNxtARR,
        \ Float "Th",Float "Th2",Float "LumaTol",Int "MatchLen",Int "SearchStep",Float "CW",Int "BlkW",Int "BlkH",Int "OLapX",int "OLapY",
        \ Bool "Strict",Int "InsMode",String "Project", Bool "Debug",Int "Verbosity") {
    myName="SirPlant: "
	IsAvsPlus=(FindStr(UCase(versionString),"AVISYNTH+")!=0)    HasGScript=RT_FunctionExist("GScript")
	Assert(IsAvsPlus || HasGScript,RT_String("%sNeed either GScript or AVS+",myName))

	GS="""
	    # Sundry scan function
		Function SirPlant_BiDiScan(clip ScanC,String ScanARR,String ScanNxtARR,Int ScanStart,Int ScanEnd,clip FndC,int FndStart,int FndEnd,Int FndI,
		        \ Float LumaTol,Float Th,Float Th2,Bool Strict,Float CW,Int BlkW,Int BlkH,Int OLapX,Int OLapY) {
		    Got=-1 SEARCHED=0
		    MaxDistance=ScanEnd-1-ScanStart
		    LumaTolMax=20.0 FpFailMax=8
		    if(MaxDistance>0) {
		        LT=LumaTol  QWKS_BM_FLAGS=0
		        while (QWKS_BM_FLAGS==0 && LT<=LumaTolMax) {
		            RT_QwikScan(ScanC,ScanStart,FndC,FndI,ScanARR,ScanNxtARR,LumaTol=LT,Flags=$20,FM=0.0,MaxDistance=MaxDistance,xp=3,
		                \ ChromaWeight=CW,BlkW=BlkW,BlkH=BlkH,OlapX=OLapX,OLapY=OLapY,FpFailMax=FpFailMax)
		            if(QWKS_BM_FLAGS==0) {SEARCHED=SEARCHED+1 LT=Float(Int(LT)+2)   LT=(LT<LumaTolMax+2.0) ? Min(LT,LumaTolMax) : LT}
		            Else                 {SEARCHED=SEARCHED+MaxDistance+1}
		        }
		        if(QWKS_BM_FLAGS!=0) {
		            False=False True=True # Locals Faster
		            Jumped=False
		            Got=0 # We at least found something via RT_QwikScan
		            Matrix=RT_ArrayGetID(ScanARR,6)  X=RT_ArrayGetID(ScanARR,8)    Y=RT_ArrayGetID(ScanARR,9)    W=RT_ArrayGetID(ScanARR,10)  H=RT_ArrayGetID(ScanARR,11)
		            ScanI = QWKS_BM_FM_FRM      # Best Match Frame Found via FrameMovement mode
		            Sync1 = RT_LumaCorrelation(ScanC,FndC,n=ScanI  ,n2=FndI,  x=X,y=Y,w=W,h=H,matrix=Matrix)      # Corr for best match frame
		            Sync2 = RT_LumaCorrelation(ScanC,FndC,n=ScanI+1,n2=FndI+1,x=X,y=Y,w=W,h=H,matrix=Matrix)      # For client metrics
		            SEARCHED=SEARCHED+2
		            ScanIs=ScanI ScanIe=ScanI
		            FndIs=FndI   FndIe=FndI
		            StartFailCor=-1.0 StartCor=0.0 Mincor=0.0 EndCor=0.0 EndFailCor=-1.0
		            if(Sync1>=Th) {
		                Got=1
		                if(Sync2>=Th) {
		                    Got=2
		                    StartCor=Sync1 Cor=Sync1  MinCor=Sync1
		                    if(Strict) { # Strict Backward search
		                        Brk=False
		                        While(!Brk && ScanStart<ScanIs && FndStart<FndIs) {
		                            Cor = RT_LumaCorrelation(ScanC,FndC,n=ScanIs-1,n2=FndIs-1,x=X,y=Y,w=W,h=H,matrix=Matrix)
		                            if(Cor>=Th2) {ScanIs=ScanIs-1 FndIs=FndIs-1 MinCor=Min(MinCor,Cor) EndCor=cor}
		                            else         {StartFailCor=Cor Brk=True}                                      # Break
		                        }
		                    } else { # Loose Backward search
		                        Brk=False Jump=False
		                        While(!Brk && ScanStart<ScanIs && FndStart<FndIs) {
		                            Cor= RT_LumaCorrelation(ScanC,FndC,n=ScanIs-1,n2=FndIs-1,x=X,y=Y,w=W,h=H,matrix=Matrix)
		                            if(Cor>=Th2) {                                                      # Both match aligned OK
		                                ScanIs=ScanIs-1 FndIs=FndIs-1 MinCor=Min(MinCor,Cor) StartCor=Cor Jump=False  # Good match, allow leeway on next frame
		                            } else if(Jump || (ScanStart>ScanIs-2 && FndStart>FndIs-2)) {                  # If disallow leeway or dupe/missing not possible, fail
		                                StartFailCor=Cor
		                                Brk=True                                                                   # Break
		                            } else {
		                                if(ScanStart<=ScanIs-2) {
		                                    Cor=RT_LumaCorrelation(ScanC,FndC,n=ScanIs-2,n2=FndIs-1,x=X,y=Y,w=W,h=H,matrix=Matrix)
		                                    if(Cor>=Th2) {                                                         # rep seems to have duplicate/extra frame
		                                        ScanIs=ScanIs-2  FndIs=FndIs-1  EndCor=cor Jump=True Jumped=True   # Good match, Disallow leeway on next frame
		                                    } else {
		                                        StartFailCor=Cor
		                                    }
		                                }
		                                if(!Jump && FndStart<=FndIs-2) {
		                                    Cor=RT_LumaCorrelation(ScanC,FndC,n=ScanIs-1,n2=FndIs-2,x=X,y=Y,w=W,h=H,matrix=Matrix)
		                                    if(Cor>=Th2) {                                                         # rep seems to have missing frame
		                                        ScanIs=ScanIs-1  FndIs=FndIs-2  EndCor=Cor Jump=True Jumped=True   # Good match, Disallow leeway on next frame
		                                    } else {
		                                        StartFailCor=Cor
		                                    }
		                                }
		                                brk = ! Jump                                                   # break if not Jump
		                            }
		                        }
		                    }
		                    EndCor=Sync2   MinCor=Min(MinCor,Sync2)
		                    ScanIe=ScanI   FndIe=FndI
		                    if(Strict) { # Strict Forward Search
		                        Brk=False
		                        While(!Brk && ScanIe<ScanEnd && FndIe<FndEnd) {
		                            Cor=RT_LumaCorrelation(ScanC,FndC,n=ScanIe+1,n2=FndIe+1,x=X,y=Y,w=W,h=H,matrix=Matrix)
		                            if(Cor>=Th2) {ScanIe=ScanIe+1 FndIe=FndIe+1 MinCor=Min(MinCor,Cor) EndCor=Cor}
		                            else         {EndFailCor=Cor Brk=True}                               # Break
		                        }
		                    } else { # Loose Forward Search
		                        Brk=False Jump=False
		                        While(!Brk && ScanIe<ScanEnd && FndIe<FndEnd) {
		                            Cor=RT_LumaCorrelation(ScanC,FndC,n=ScanIe+1,n2=FndIe+1,x=X,y=Y,w=W,h=H,matrix=Matrix)
		                            if(Cor>=Th2) {                                                           # Both match aligned OK
		                                ScanIe=ScanIe+1 FndIe=FndIe+1 MinCor=Min(MinCor,Cor) EndCor=Cor Jump=False    # Good match, allow leeway on next frame
		                            } else if(Jump || (ScanIe+2>ScanEnd && FndIe+2>FndEnd)) {
		                                EndFailCor=Cor
		                                Brk=True                                                            # Break
		                            } else {
		                                if(ScanIe+2<=ScanEnd) {
		                                    Cor=RT_LumaCorrelation(ScanC,FndC,n=ScanIe+2,n2=FndIe+1,x=X,y=Y,w=W,h=H,matrix=Matrix)
		                                    if(Cor>=Th2) {                                                   # rep seems to have duplicate/extra frame
		                                        ScanIe=ScanIe+2 FndIe=FndIe+1 EndCor=Cor Jump=True Jumped=True        # Good match, Disallow leeway on next frame
		                                    } else {
		                                        EndFailCor=Cor
		                                    }
		                                }
		                                if(!Jump && FndIe+2<=FndEnd) {
		                                    Cor=RT_LumaCorrelation(ScanC,FndC,n=ScanIe+1,n2=FndIe+2,x=X,y=Y,w=W,h=H,matrix=Matrix)
		                                    if(Cor>=Th2) {                                                   # rep seems to have missing frame
		                                        ScanIe=ScanIe+1  FndIe=FndIe+2  EndCor=Cor Jump=True Jumped=True      # Good match, Disallow leeway on next frame
		                                    } else {
		                                        EndFailCor=Cor
		                                    }
		                                }
		                                brk = ! Jump                                                        # break if not Jump
		                            }
		                        }
		                    }
		                    Got = FndIe-FndIs+1
		                    SEARCHED=SEARCHED+Got
		                } # end, Sync2>=Th
		            } # End, Sync1>=Th
		            Global G_FndIs=FndIs   Global G_FndIe=FndIe
		            Global G_ScanI=ScanI   Global G_ScanIs=ScanIs  Global G_ScanIe=ScanIe
		            Global G_Jumped=Jumped Global G_Sync1=Sync1    Global G_Sync2=sync2
		            Global G_StartFailCor=StartFailCor Global G_StartCor=StartCor Global G_MinCor=MinCor Global G_EndCor=EndCor Global G_EndFailCor=EndFailCor
		        } # End, QWKS_BM_FLAGS!=0
		    } # End, MaxDistance>0
		    Global G_SEARCHED=SEARCHED
		    return Got
		}
	    Th           = Default(Th,0.90)
	    Th2          = Default(Th2,0.75)
	    LumaTol      = Float(Default(LumaTol,8.0))
	    MatchLen     = Default(MatchLen,60)
	    SearchStep   = Default(SearchStep,MatchLen/4)
	    CW           = Float(Default(CW,1.0/3.0))
	    BlkW         = Default(BlkW,64)
	    BlkH         = Default(BlkH,BlkW)
	    OLapX        = Default(OLapX,BlkW/2)
	    OLapY        = Default(OLapY,BlkH/2)
	    Strict       = Default(Strict,True)
	    InsMode      = Default(InsMode,0)
	    Project      = Default(Project,"")
	    Debug        = Default(Debug,True)
	    Verbosity    = (Debug) ? Default(Verbosity,1) : 0
	    Verbosity=Min(max(0,Verbosity),2)
	    Project = (Project!="")?Project:"Default"
	    Assert(Exist(srcARR),RT_String("%ssrcArr does not Exist, use RT_QwikScanCreate\n('%s')",myName,srcARR))
	    Assert(Exist(srcNxtARR),RT_String("%ssrcNxtARR does not Exist, use RT_QwikScanCreate\n('%s')",myName,srcNxtARR))
	    Assert(Exist(repARR),RT_String("%srepArr does not Exist, use RT_QwikScanCreate\n('%s')",myName,repARR))
	    Assert(Exist(repNxtARR),RT_String("%srepNxtARR does not Exist, use RT_QwikScanCreate\n('%s')",myName,repNxtARR))
	    Assert(0.0 < Th <= 1.0,RT_String("%s0.0 < Th <= 1.0 ('%.3f')",myName,Th))
	    Assert(0.0 < Th2 <= Th,RT_String("%s0.0 < Th2 <= Th('Th2=%.3f:Th=%.3f')",myName,Th2,Th))
	    Assert(0.0 <= LumaTol <= 20.0,RT_string("%s0.0 <= LumaTol <= 20.0(%.3f)",myName,Lumatol))
	    Assert(16 <= MatchLen,RT_string("%s16 <= MatchLen(%d)",myName,MatchLen))
	    Assert(1 <= SearchStep <= MatchLen,RT_string("%s1 <= SearchStep <= MatchLen (%d)",myName,SearchStep))
	    Assert(0.0 <= CW <= 1.0,RT_string("%s0.0 <= CW <= 1.0(%.3f)",myName,CW))
	    Assert(BlkW%2==0 && BlkW>=8,RT_string("%sBlkW Even && BlkW>=8(%d)",myName,BlkW))
	    Assert(BlkH%2==0 && BlkH>=8,RT_string("%sBlkH Even && BlkH>=8(%d)",myName,BlkH))
	    Assert(0<=OLapX,RT_string("%s0<=OLapX(%d)",myName,OLapX))
	    Assert(0<=OLapY,RT_string("%s0<=OLapY(%d)",myName,OLapY))
	    Assert(0 <= InsMode <= 2,RT_string("%s0 <= InsMode <= 2(%d)",myName,InsMode))
	    #
	    LOG     = Project+"_SirPlant.LOG"
	    Cmd     = Project+"_Command.txt"
	    UnUsed  = Project+"_UnUsed.txt"                                 # Prune format.
	    RT_WriteFile(Cmd,"######\n#\n# Splice replacements\n#\n# Prune Command File\n#")
	    RT_WriteFile(UnUsed,"######\n#\n# Extract Unused frames from rep clip\n#\n# Prune Command file\n#")
	    RT_WriteFile(LOG,"######\n#\n# LOG\n#")
	    S=RT_string("###\n#\n# Local Start Time = %s\n#\n# Th=%.3f  Th2=%.3f  LumaTol=%.3f\n#",RT_LocalTimeString(false),Th,Th2,LumaTol)
	    (Debug) ? RT_DebugF("###%s",S,name=myName) :NOP
	    RT_WriteFile(LOG,"%s",S,Append=True)  RT_WriteFile(Cmd,"%s",S,Append=True)  RT_WriteFile(UnUsed,"%s",S,Append=True)
	    S=RT_string("# MatchLen=%d SearchStep=%d Strict=%s Project='%s'\n#",Matchlen,SearchStep,Strict,Project)
	    (Debug) ? RT_DebugF("%s",S,name=myName) : NOP
	    RT_WriteFile(LOG,"%s\n",S,Append=True)   RT_WriteFile(Cmd,"%s",S,Append=True)  RT_WriteFile(UnUsed,"%s",S,Append=True)
	    S=RT_string("# CW=%.2f BlkW=%d BlkH=%d OLapX=%d OLapY=%d\n#",CW,BlkW,BlkH,OLapX,OLapY)
	    (Debug) ? RT_DebugF("%s",S,name=myName) : NOP
	    RT_WriteFile(LOG,"%s\n",S,Append=True)   RT_WriteFile(Cmd,"%s",S,Append=True)  RT_WriteFile(UnUsed,"%s",S,Append=True)
	    S=RT_string("# InsMode=%d (%s)\n#\n######\n",InsMode,(InsMode==0)?"REPLACE ONLY":(InsMode==1)?"INSERT EXTRAS ONLY":"REPLACE & INSERT EXTRAS")
	    (Debug) ? RT_DebugF("%s",S,name=myName) : NOP
	    RT_WriteFile(LOG,"%s\n",S,Append=True)   RT_WriteFile(Cmd,"%s",S,Append=True)  RT_WriteFile(UnUsed,"%s",S,Append=True)
	    TimSTART = RT_TimerHP
	    # Must use same values as set in QwikScan Array ID's
	    Matrix=RT_ArrayGetID(srcARR,6)  X=RT_ArrayGetID(srcARR,8)    Y=RT_ArrayGetID(srcARR,9)    W=RT_ArrayGetID(srcARR,10)  H=RT_ArrayGetID(srcARR,11)
	    #
	    False=False True=True           # Locals (faster)
	    O=0  EXTCNT=0  REPCNT=0  SEARCHED=0  REPMATCHED=0 PROGRESS=0 JUMPING=0
	    srcNext=0   srcEnd=src.FrameCount-1  sRun=0  sStop=srcEnd-1
	    repNext=0   repEnd=rep.FrameCount-1  rRun=0  rStop=repEnd-1
	    ###
	    While(rRun<=rStop && sRun<=sStop) { # Detect fully done
	        sGot=0
	        While(rRun<=rStop && sRun<=sStop && sGot<MatchLen) {
	            # We do not track Gray start frames
	            MinMxDif=RT_YPlaneMinMaxDifference(rep,n=rRun,Threshold=1.0)
	            if(MinMxDif >= 16) {
	                sGot=0 ScanMode=0
	                # Here align, look for BEST MATCH rep[rRun] in src[], if fail then look for BEST MATCH src[sRun] in rep[].
	                while(rRun<=rStop && sRun<=sStop && sGot<MatchLen && ScanMode<2) {
	                    PROGRESS=PROGRESS+1
	                    if(Verbosity==1 && PROGRESS>=20) {
	                        RT_DebugF("%6d] Progress : rRun=%d srun=%d",O,rRun,sRun,name=myName)
	                        PROGRESS=0
	                    }
	                    sGot=0
	                    ScanMode=ScanMode+1
	                    if(ScanMode==1) {
	                        sGot=SirPlant_BiDiScan(src,srcARR,srcNxtARR,srcNext,srcEnd,rep,repNext,repEnd,rRun,LumaTol,Th,Th2,Strict,CW,BlkW,BlkH,OLapX,OLapY)
	                        SEARCHED=SEARCHED+G_SEARCHED
	                        if(sGot<0) {
	                            (Verbosity>=2)?RT_DebugF("%6d] Search rep[%6d] in src[%6d,%6d] RT_QwikScan Fails find any frame even @ maximum LumaTol=20.0",
	                                    \ O,rRun,sRun,sStop,name=myName):NOP
	                        } else {
	                            rIs=G_FndIs rIe=G_FndIe sIs=G_ScanIs sIe=G_ScanIe sI=G_ScanI rI=rRun
	                            sGot=(sGot>0)?sIe-sIs+1:0
	                            (Verbosity>=2)?RT_DebugF("%6d] Search rep[%6d] in src[%6d,%6d] Got=%-5d Sync1=%6.3f Sync2=%6.3f sI=%5d",
	                                    \ O,rRun,sRun,sStop,sGot,G_Sync1,G_Sync2,sI,name=myName):NOP
	                        }
	                    } else if(ScanMode==2) {
	                        MinMxDif=RT_YPlaneMinMaxDifference(src,n=sRun,Threshold=1.0)
	                        if(MinMxDif>=16) {
	                            sGot=SirPlant_BiDiScan(rep,repARR,repNxtARR,repNext,repEnd,src,srcNext,srcEnd,sRun,LumaTol,Th,Th2,Strict,CW,BlkW,BlkH,OLapX,OLapY)
	                            SEARCHED=SEARCHED+G_SEARCHED
	                            if(sGot<0) {
	                                (Verbosity>=2)?RT_DebugF("%6d] Search src[%6d] in rep[%6d,%6d] RT_QwikScan Fails find any frame even @ maximum LumaTol=20.0",
	                                        \ O,sRun,rRun,rStop,name=myName):NOP
	                            } else {
	                                sIs=G_FndIs sIe=G_FndIe rIs=G_ScanIs rIe=G_ScanIe rI=G_ScanI sI=sRun
	                                sGot=(sGot>0)?sIe-sIs+1:0
	                                (Verbosity>=2)?RT_DebugF("%6d] Search src[%6d] in rep[%6d,%6d] Got=%-5d Sync1=%6.3f Sync2=%6.3f rI=%5d",
	                                        \ O,sRun,rRun,rStop,sGot,G_Sync1,G_Sync2,rI,name=myName):NOP
	                            }
	                        } else {
	                            (Verbosity>=2) ? RT_DebugF("%6d] sRun=%d GREY FRAME MinMxDif=%d: No detection attempt",O,sRun,MinMxDif,name=myName) : NOP
	                        }
	                    }
	                    if(sGot<MatchLen) {
	                        if(ScanMode==1) {rRun=rRun+SearchStep}
	                        else            {sRun=sRun+SearchStep}
	                    }
	                } # End, while(rRun<=rStop && sRun<=sStop && sGot<MatchLen && ScanMode<2)
	                if(sGot>=MatchLen) {
	                    BackGot=sI-sIs
	                    if(BackGot>0 && Verbosity>=2) {
	                        RT_DebugF("%6d] BACKWARDS Got=%d rRun=%d rI=%d sRun=%d sI=%d StartFailCor=%.3f StartCor=%.3f",
	                            \ O,BackGot,rRun,rI,sRun,sI,G_StartFailCor,G_StartCor,name=myName)
	                    }
	                    FwdGot=sIe-sI+1
	                    if(FwdGot>0 && Verbosity>=2) {
	                        RT_DebugF("%6d] FORWARD Got=%d rRun=%d sRun=%d rI=%d sI=%d EndCor=%.3f EndFailCor=%.3f",
	                            \ O,FwdGot,rRun,sRun,rI,sI,G_EndCor,G_EndFailCor,name=myName)
	                    }
	                    rRun=rIs
	                    sRun=sIs
	                }
	            } else {
	                (Verbosity>=2) ? RT_DebugF("%6d] rRun=%d GREY FRAME MinMxDif=%d: No detection attempt",O,rRun,MinMxDif,name=myName) : NOP
	                rRun = rRun + SearchStep
	            } # end if YPlaneMinMaxDifference
	        } # End, While(rRun<rStop && Got<MatchLen)

	        if(sGot>=Matchlen) {
	            if(Debug) {
	                RT_DebugF("%6d] *** ALIGNMENT SUCCEED *** rep[%d,%d]->src[%d,%d]",O,rIs,rIe,sIs,sIe,name=myName)
	                RT_DebugF("%6d]   StartFailCor=%.3f StartCor=%.3f Sync1=%6.3f Sync2=%6.3f MinCor=%.3f EndCor=%.3f EndFailCor=%.3f",
	                    \ O,G_StartFailCor,G_StartCor,G_Sync1,G_Sync2,G_MinCor,G_EndCor,G_EndFailCor,name=myName)
	                (G_JUMPED)?RT_DebugF("%6d]  *** JUMPING SEQUENCE(Strict=False) SrcLen=%d RepLen=%d",O,sIe-sIs+1,rIe-rIs+1,name=myName):NOP
	            }
	            Extras=rIs-repNext
	            if(srcNext<sIs) {
	                WrFirst=0
	                if(Extras>=MatchLen && InsMode!=0) {
	                    # We are writing both intervening source and Extra range, but which first ?
	                    dS1=(0<srcNext) ? RT_FrameDifference(src,src,n=srcNext-1,n2=srcNext, x=X,y=Y,w=W,h=H,ChromaWeight=1.0/3.0,matrix=Matrix) : 256.0
	                    dS2=              RT_FrameDifference(src,rep,n=sIe,      n2=rIs,     x=X,y=Y,w=W,h=H,ChromaWeight=1.0/3.0,matrix=Matrix)
	                    dS3=(rIe<repEnd)? RT_FrameDifference(rep,rep,n=rIe,      n2=rIe+1,   x=X,y=Y,w=W,h=H,ChromaWeight=1.0/3.0,matrix=Matrix) : 256.0
	                    dR1=(0<repNext) ? RT_FrameDifference(rep,rep,n=repNext-1,n2=repNext, x=X,y=Y,w=W,h=H,ChromaWeight=1.0/3.0,matrix=Matrix) : 256.0
	                    dR2=              RT_FrameDifference(rep,rep,n=rIe,      n2=sIs,     x=X,y=Y,w=W,h=H,ChromaWeight=1.0/3.0,matrix=Matrix)
	                    dR3=(sIe<srcEnd)? RT_FrameDifference(src,src,n=sIe,      n2=sIe+1,   x=X,y=Y,w=W,h=H,ChromaWeight=1.0/3.0,matrix=Matrix) : 256.0
	                    wrS=Min(dS1,dS2,dS3)       wrR=min(dR1,dR2,dR3)
	                    if     (dS1 <= 3.0 < dR1)  {WrFirst=1}
	                    else if(dR1 <= 3.0 < dS1)  {WrFirst=2}
	                    else                       {WrFirst=(wrS==wrR)?0:(wrS<wrR)?1:2}
	                    (Verbosity>=2)?RT_DebugF("%6d]   dS1=%.2f dS2=%.2f dS3=%.2f : dR1=%.2f dR2=%.2f dR3=%.2f",O,dS1,dS2,dS3,dR1,dR2,dR3,name=myName):NOP
	                    (Verbosity>=2)?RT_DebugF("%6d]   WrFirst=%s",O,(wrFirst<=1)?"Intervening Source":"Extras",name=myName):NOP
	                    if((WrFirst==1 && wrR<wrS)||(WrFirst==2 && wrS<wrR)) {
	                        (Debug)?RT_DebugF("%6d] !!! Following two sections may need hand edit for order !!!",O,name=myName):NOP
	                        RT_WriteFile(LOG,"%6d] !!! Following two sections may need hand edit for order !!!",O,Append=True)
	                    }
	                }
	                if(wrFirst<=1) {
	                    (Debug) ? RT_DebugF("%6d]   Writing Intervening src[%d,%d] Len=%d",O,srcNext,sIs-1,sIs-srcNext,name=myName):NOP
	                    RT_Writefile(LOG,"%6d] Writing Intervening src[%d,%d] Len=%d",O,srcNext,sIs-1,sIs-srcNext,Append=true)
	                    RT_WriteFile(Cmd,"0 %6d,%6d\t # %6d] Len=%-6d",srcNext,sIs-1,O,sIs-srcNext,Append=True)
	                    O=O+sIs-srcNext
	                    srcNext=sIs
	                }
	            }

	            if(Extras>0) {
	                if(Extras>=MatchLen) {
	                    if(InsMode!=0) {
	                        (Debug) ? RT_DebugF("%6d]   *** Writing seemingly EXTRA range rep[%d,%d] Len=%d",O,repNext,rIs-1,Extras,name=myName):NOP
	                        RT_Writefile(LOG,"%6d] Writing seemingly EXTRA range rep[%d,%d] Len=%d",O,repNext,rIs-1,Extras,Append=True)
	                        RT_WriteFile(Cmd,"4 %6d,%6d\t # %6d] Len=%-6d *** Seemingly EXTRA Replacement frames",repNext,rIs-1,O,Extras,Append=True)
	                        EXTCNT=EXTCNT+Extras
	                        O=O+Extras
	                    } else {
	                        (Debug) ? RT_DebugF("%6d]   Skipping seemingly extra range rep[%d,%d] Len=%d",O,repNext,rIs-1,Extras,name=myName):NOP
	                        RT_Writefile(LOG,"%6d] Skipping seemingly extra range frames rep[%d,%d] Len=%d",O,repNext,rIs-1,Extras,Append=True)
	                        RT_WriteFile(UnUsed,"1 %6d,%6d\t # Len=%-6d *** Seemingly Extra Replacement frames",repNext,rIs-1,Extras,Append=True)
	                    }
	                } Else {
	                    (Debug) ? RT_DebugF("%6d]   Ignoring Short length seemingly extra range rep[%d,%d] Len=%d",O,repNext,rIs-1,Extras,name=myName):NOP
	                    RT_WriteFile(LOG,"%6d] Ignoring Short length seemingly extra range rep[%d,%d] Len=%d",O,repNext,rIs-1,Extras,Append=True)
	                    RT_WriteFile(UnUsed,"0 %6d,%6d\t # Len=%-6d Ignoring Short Range",repNext,rIs-1,Extras,Append=True)
	                }
	                repNext=rIs
	            }

	            if(srcNext<sIs) {
	                (Debug) ? RT_DebugF("%6d]   Writing Intervening src[%d,%d] Len=%d",O,srcNext,sIs-1,sIs-srcNext,name=myName):NOP
	                RT_Writefile(LOG,"%6d] Writing Intervening src[%d,%d] Len=%d",O,srcNext,sIs-1,sIs-srcNext,Append=true)
	                RT_WriteFile(Cmd,"0 %6d,%6d\t # %6d] Len=%-6d",srcNext,sIs-1,O,sIs-srcNext,Append=True)
	                O=O+sIs-srcNext
	                srcNext=sIs
	            }

	            REPMATCHED=REPMATCHED+rIe-rIs+1
	            if(InsMode==1) {
	                (Debug) ? RT_DebugF("%6d]   Writing matching SOURCE range src[%d,%d] -> rep[%d,%d] Len=%d",O,sIs,sIe,rIs,rIe,sIe-sIs+1,name=myName):NOP
	                RT_Writefile(LOG,"%6d] Writing matching SOURCE range src[%d,%d] -> rep[%d,%d] Len=%d",O,sIs,sIe,rIs,rIe,sIe-sIs+1,Append=True)
	                RT_WriteFile(Cmd,"1 %6d,%6d\t # %6d] Len=%-6d (matched rep[%d,%d])",sIs,sIe,O,rIs,rIe,sIe-sIs+1,Append=True)
	                sGot=sIe-sIs+1
	                O=O+sGot
	                srcNext=sIe+1
	            } else {
	                (Debug) ? RT_DebugF("%6d]   Writing matching REPLACEMENT range rep[%d,%d] -> src[%d,%d] Len=%d",O,rIs,rIe,sIs,sIe,rIe-rIs+1,name=myName):NOP
	                RT_Writefile(LOG,"%6d] Writing matching REPLACEMENT range rep[%d,%d] -> src[%d,%d] Len=%d%s",O,rIs,rIe,sIs,sIe,rIe-rIs+1,G_Jumped?" (*** JUMPED ***)":"",Append=True)
	                RT_WriteFile(LOG,"        StartFailCor=%.3f StartCor=%.3f Sync1=%.3f Sync2=%.3f MinCor=%.3f EndCor=%.3f EndFailCor=%.3f%s",
	                    \ G_StartFailCor,G_StartCor,G_Sync1,G_Sync2,G_MinCor,G_EndCor,G_EndFailCor,G_Jumped?" *** JUMPED *** ":"",Append=True)
	                RT_WriteFile(Cmd,"3 %6d,%6d\t # %6d] -> src[%d,%d] Len=%-6d StartFailCor=%.3f StartCor=%.3f Sync1=%.3f Sync2=%.3f MinCor=%.3f EndCor=%.3f EndFailCor=%.3f%s",
	                    \ rIs,rIe,O,sIs,sIe,rIe-rIs+1,G_StartFailCor,G_StartCor,G_Sync1,G_Sync2,G_MinCor,G_EndCor,G_EndFailCor,G_Jumped?" *** JUMPED *** ":"",Append=True)
	                rGot=rIe-rIs+1  REPCNT=REPCNT+rGot  O=O+rGot
	                repNext=rIe+1
	            }
	            repNext=rIe+1   rRun=repNext
	            srcNext=sIe+1   sRun=srcNext
	            JUMPING = G_JUMPED ? JUMPING+1:JUMPING
	        } # End, sGot>=Matchlen
	    } # End, While(rRun<=rStop && sRun<=sStop)

	    Extras=repEnd-repNext+1
	    if(srcNext<=srcEnd && Extras>0) {
	        WrFirst=0
	        if(Extras>=MatchLen && InsMode!=0) {
	            # We are writing both End ranges range, but which first ?
	            dS1=(0<srcNext) ? RT_FrameDifference(src,src,n=srcNext-1,n2=srcNext, x=X,y=Y,w=W,h=H,ChromaWeight=1.0/3.0,matrix=Matrix) : 256.0
	            dS2=              RT_FrameDifference(src,rep,n=sIe,      n2=rIs,     x=X,y=Y,w=W,h=H,ChromaWeight=1.0/3.0,matrix=Matrix)
	            dR1=(0<repNext) ? RT_FrameDifference(rep,rep,n=repNext-1,n2=repNext, x=X,y=Y,w=W,h=H,ChromaWeight=1.0/3.0,matrix=Matrix) : 256.0
	            dR2=              RT_FrameDifference(rep,rep,n=rIe,      n2=sIs,     x=X,y=Y,w=W,h=H,ChromaWeight=1.0/3.0,matrix=Matrix)
	            wrS=Min(dS1,dS2)       wrR=min(dR1,dR2)
	            if     (dS1 <= 3.0 < dR1)  {WrFirst=1}
	            else if(dR1 <= 3.0 < dS1)  {WrFirst=2}
	            else                       {WrFirst=(wrS==wrR)?0:(wrS<wrR)?1:2}
	            (Verbosity>=2)?RT_DebugF("%6d]   dS1=%.2f dS2=%.2f : dR1=%.2f dR2=%.2f",O,dS1,dS2,dR1,dR2,name=myName):NOP
	            (Verbosity>=2)?RT_DebugF("%6d]   WrFirst=%s",O,(wrFirst<=1)?"Intervening Source":"Extras",name=myName):NOP
	            if((WrFirst==1 && wrR<wrS)||(WrFirst==2 && wrS<wrR)) {
	                (Debug)?RT_DebugF("%6d] !!! Following two sections may need hand edit for order !!!",O,name=myName):NOP
	                        RT_WriteFile(LOG,"%6d] !!! Following two sections may need hand edit for order !!!",O,Append=True)
	            }
	        }
	        if(wrFirst==1) {
	            (Debug) ? RT_DebugF("%6d] Writing SOURCE End Range src[%d,%d] Len=%d",O,srcNext,srcEnd,srcEnd-srcNext+1,name=myName):NOP
	            RT_WriteFile(LOG,"%6d] Writing End Range src[%d,%d] Len=%d",O,srcNext,srcEnd,srcEnd-srcNext+1,Append=True)
	            RT_WriteFile(Cmd,"2 %6d,%6d\t # %6d] Len=%-6d",srcNext,srcEnd,O,srcEnd-srcNext+1,Append=True)
	            Got=srcEnd-srcNext+1
	            O=O+Got
	            srcNext=srcEnd+1
	        }
	    }

	    if(repNext<=repEnd) {
	        Extras=repEnd-repNext+1
	        if(Extras>=MatchLen) {
	            if(InsMode!=0) {
	                (Debug) ? RT_DebugF("%6d] *** Writing seemingly extra END range rep[%d,%d] Len=%d",O,repNext,repEnd,Extras,name=myName):NOP
	                RT_WriteFile(LOG,"%6d] * Writing seemingly extra range rep[%d,%d] Len=%d",O,repNext,repEnd,Extras,Append=True)
	                RT_WriteFile(Cmd,"5 %6d,%6d\t # %6d] Len=%-6d rep[%d,%d] *** Seemingly Extra Replacement frames",repNext,repEnd,O,Extras,repNext,repEnd,Append=True)
	                EXTCNT=EXTCNT+Extras
	            } else {
	                (Debug) ? RT_DebugF("%6d] *** Skipping seemingly extra END range frames rep[%d,%d] Len=%d",O,repNext,repEnd,Extras,name=myName):NOP
	                RT_WriteFile(LOG,"%6d] * Skipping seemingly extra END range rep[%d,%d] Len=%d",O,repNext,repEnd,Extras,Append=True)
	                RT_WriteFile(UnUsed,"1 %6d,%6d\t # Len=%-6d Seemingly Extra END Replacement frames",repNext,repEnd,Extras,Append=True)
	            }
	        } else {
	            (Debug) ? RT_DebugF("%6d] Ignoring seemingly extra END range rep[%d,%d] Len=%d",O,repNext,repEnd,Extras,name=myName):NOP
	            RT_WriteFile(LOG,"%6d] Ignoring seemingly extra END range rep[%d,%d] Len=%d",O,repNext,repEnd,Extras,Append=True)
	            RT_WriteFile( UnUsed,"0 %6d,%6d\t # Len=%-6d Extra END Range",repNext,repEnd,Extras,Append=True)
	            Extras=0
	        }
	        repNext=repNext+Extras  O=O+Extras
	    }
	    if(srcNext<=srcEnd) {
	        (Debug) ? RT_DebugF("%6d] Writing SOURCE END Range src[%d,%d] Len=%d",O,srcNext,srcEnd,srcEnd-srcNext+1,name=myName):NOP
	        RT_WriteFile(LOG,"%6d] Writing END Range src[%d,%d] Len=%d",O,srcNext,srcEnd,srcEnd-srcNext+1,Append=True)
	        RT_WriteFile(Cmd,"2 %6d,%6d\t # %6d] Len=%-6d",srcNext,srcEnd,O,srcEnd-srcNext+1,Append=True)
	        Got=srcEnd-srcNext+1
	        O=O+Got
	        srcNext=srcEnd+1
	    }
	    S=RT_String("\n######\n# SrcLen=%6d RepLen=%d OutLen=%6d RepMatched=%d Replaced=%d ExtrasInserted=%d RepUnused=%d",
	            \ src.FrameCount,rep.FrameCount,O,REPMATCHED,REPCNT,EXTCNT,rep.FrameCount-REPMATCHED-EXTCNT)
	    (Debug) ? RT_DebugF("%s",S,name=myName):NOP
	    RT_WriteFile(LOG,"%s",S,Append=True)
	    S=RT_String("# Approx Frames Searched=%d",SEARCHED)
	    (Debug) ? RT_DebugF("%s",S,name=myName):NOP
	    RT_WriteFile(LOG,"%s",S,Append=True)
	    if(JUMPING>0) {
	        S=RT_String("# *** %d JUMPING *** sequences detected (Strict=False)",JUMPING)
	        (Debug) ? RT_DebugF("%s",S,name=myName):NOP
	        RT_WriteFile(LOG,"%s",S,Append=True)
	    }
	    Tim = RT_TimerHP-TimStart
	    S=RT_String ("# Local Stop Time = %s : Time Taken=%.3f Secs (%.3f mins)",RT_LocalTimeString(False),tim,tim/60.0)
	    (Debug) ? RT_DebugF("%s\n######",S,name=myName):NOP
	    RT_WriteFile(LOG,"%s\n######",S,Append=True)
	"""
	HasGScript ? GScript(GS) : Eval(GS) # Use GSCript if installed (loaded plugs override builtin)
	Return Last
}
