# FFMS_MakeMultiPartScripts.avsi

Function FFMS_MakeMultiPartScript(String FnList,String "OutPath",Int "Parts") {
/*
    FFMS_MakeMultiPartScripts v0.04  :::  Requires RT_Stats, Avs+ OR GScript.

    FFMS_MakeMultiPartScript(String FnList,String "OutPath"="",Int "Parts"=4)
        FnList,   No default. Multi-line string of avs filenames(1 or more).
                  Source scripts to split must use FFMS2 source filter.
                  Source scripts clip length must be at least (20 * Parts) frames else error abort.
                  This function sets a Global FFMS_MakeMultiPartScript_Glb variable, can be detected in source
                    avs scripts so as to determine if called by this function (for whatever reason).
        OutPath,  Default "", Same Directory as source file directory. Path (must exist) where output scripts written.
                  Where OutPath = default "", and multiple input files with different directories given in FnList, OutPath will use input file directory
                  for each input file (even when different directories, will not be different paths where fileSelector client script used).
                  Use "." for current directory.
        Parts,    Default 4. Number of parts that source script is split into.
*/
    myName="FFMS_MakeMultiPartScript: "
    Global FFMS_MakeMultiPartScript_Glb="Sausages"             # *** NOTE *** Exported as Global for possible use via avs Script that will be split.
    OutPath=Default(OutPath,"")    Parts=Default(Parts,4)
    Assert(Parts>1,RT_String("MakeMultiPartScripts.avs: PARTS MUST be greater than 1 (%d)",Parts))
    IsAvsPlus=(FindStr(UCase(versionString),"AVISYNTH+")!=0)    HasGScript=RT_FunctionExist("GScript")
    Assert(IsAvsPlus || HasGScript,RT_string("%sEssential Avs+ OR GScript installed",myName))
    Assert(FnList!="",RT_String("%sFn Cannot be ''",myName))
    Script_Tmpt = """Return Import("%s").Trim(%d,%d)  # PART %d of %d"""
    ORG_OutPath=OutPath
    GS="""
        NLINES = RT_TxtQueryLines(FnList)
        for(i=0,NLINES-1) { # Check Input files Exist
            InFn=RT_TxtGetLine(FnList,i).RT_GetFullPathName
            Assert(Exist(InFn),RT_String("%sFn Does Not Exist\n'%s'",myName,InFn))
        }
        for(i=0,NLINES-1) {
            InFn = RT_TxtGetLine(FnList,i).RT_GetFullPathName
            OutPath  = (ORG_OutPath=="") ? InFn.RT_FilenameSplit(3) : ORG_OutPath.RT_GetFullPathName
            OutPath=OutPath.RevStr
            While(OutPath.FindStr("\")==1 || OutPath.FindStr("/")==1) { OutPath=OutPath.MidStr(2) }
            OutPath=OutPath.RevStr
            Assert(Exist(OutPath),RT_String("%sOutPath Does Not Exist\n'%s'",myName,OutPath))
            OutPath=OutPath + "\"
            OutFn = OutPath + RT_FilenameSplit(InFn,4)
            c  = Import(InFn)
            FC = c.FrameCount
            c.RT_AverageLuma(n=FC-1,w=1,h=1)
            Assert(RT_VarExist("FFPICT_TYPE"),RT_String("%sFFVideoSource FFPICT_TYPE does not exist\n'%s'",myName,InFn))
            Assert(FC>=20*PARTS,RT_String("%sClip length(%d) must be at least 20*Parts(%d) frames\n'%s'",myName,FC,20*PARTS,InFn))
            End = -1
            for(part=0,PARTS-1) {
                Start = End + 1
                if(Part == Parts-1) {
                    End = FC -1
                } Else {
                    ChkEnd = (FC - Start) / (PARTS - part) + Start
                    ChkLim = 3 * (FC - Start) / (2*(PARTS - part)) + Start
                    End=-1
                    for(j=ChkEnd+1,ChkLim) {
                        c.RT_AverageLuma(n=j,w=1,h=1)
                        if(FFPICT_TYPE == 73) { End = j-1  j=FC }
                    }
                    if(End<0) {
                        ES=RT_String("%sCannot find I Frame for part %d\n'%s'",myName,Part+1,InFn)
                        RT_DebugF("%s",ES,name=myName)
                        for(j=0,part-1) {
                            OutPartName = RT_String("%s_PART_%d.avs",OutFn,j+1)
                            RT_DebugF("Deleting %s",OutPartName,name=myName)
                            RT_FileDelete(OutPartName)
                        }
                        Assert(False,ES)
                    }
                }
                OutPartName = RT_String("%s_PART_%d.avs",OutFn,part+1)
                ScriptInst=RT_String(Script_Tmpt,InFn,Start,End,part+1,PARTS)
                RT_DebugF("Writing '%s'\n  '%s'",OutPartName,ScriptInst,name=myName)
                RT_WriteFile(OutPartName,"%s",ScriptInst)
            }
        }
    """
    HasGScript ? GScript(GS) : Eval(GS) # Use GScript if installed (loaded plugs override builtin)
    Return MessageClip(RT_String("ALL DONE, Processed %d avs files of %d parts each",NLINES,PARTS))
}