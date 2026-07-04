# MakeMultiPartScripts.avs : v1.00
#######
PARTS=4             # Edit as appropriate
#######
myName="MakeMultiPartScripts: "
Assert(PARTS>1,RT_String("MakeMultiPartScripts.avs: PARTS MUST be greater than 1 (%d)",PARTS))
IsAvsPlus=(FindStr(VersionString, "AviSynth+")>0 || FindStr(VersionString, " Neo")>0)
HasGScript=RT_FunctionExist("GScript")
Assert(IsAvsPlus || HasGScript,RT_String("%sNeed either GScript or AVS+",myName))
#######
FSEL_TITLE="Select AVS files"
FSEL_DIR="."
FSEL_FILT="AVS files|*.AVS"
FSEL_MULTI=True
FILE_LIST = RT_FSelOpen(title=FSEL_TITLE,dir=FSEL_DIR,filt=FSEL_FILT,multi=FSEL_MULTI)
Assert(!(FILE_LIST.IsInt && FILE_LIST==0),RT_String("%sUser Cancelled in FileSelector - No action taken",myName))
Assert(FILE_LIST.IsString,RT_String("%sRT_FSelOpen Error=%s",myName,String(FILE_LIST)))

SCRIPT_TMPT = """
    PART  = %d
    PARTS = %d
    Import("%s")
    FC = FrameCount
    Start = ((part==0      ) ?   -1 : part     * (FC-1) / PARTS) + 1
    End   = ((part==PARTS-1) ? FC-1 : (part+1) * (FC-1) / PARTS)
    End   = (End == Start)   ?   -1 : End
    Trim(Start,End)
#    Subtitle("Trim("+String(Start)+","+String(End)+")")
    Return Last
"""

GS="""
    NLINES = RT_TxtQueryLines(FILE_LIST)
    for(i=0,NLINES-1) {
        PARTSNAME = RT_TxtGetLine(FILE_LIST,i)
        for(part=0,PARTS-1) {
            PartName = RT_String("%s_PART_%d.avs",PARTSNAME,part+1)
            ScriptInst=RT_String(SCRIPT_TMPT,part,PARTS,PARTSNAME)
            RT_WriteFile(PartName,"%s",ScriptInst)
        }
    }
"""
HasGScript ? GScript(GS) : Eval(GS) # Use GSCript if installed (loaded plugs override builtin)

MessageClip(RT_String("ALL DONE, Processed %d avs files of %d parts each",NLINES,PARTS))