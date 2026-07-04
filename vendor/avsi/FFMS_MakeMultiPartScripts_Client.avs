# FFMS_MakeMultiPartScripts_Client.avs

Import(".\FFMS_MakeMultiPartScripts.avsi")

#######
# To Create Multi-Part Scripts, USE VDub2 or any Player Except VLC, and MPC-HC only if nothing else available. Do NOT USE AvsPMod (it dont work well with RT_FselOpen file selector).
#######
PARTS    = 4    # Part Scripts to create.
FSEL_DIR = "."  # Start Path for File Selector, current directory.
OUTPATH  = ""   # Output Path where avs files created, ""=Same directory as source files. ["." = current directory]
#######
myName="FFMS_MakeMultiPartScript_Client: "
FSEL_TITLE="Select AVS files"
FSEL_FILT="AVS files|*.AVS"
FSEL_MULTI=True       # Allow Multi-Select of input avs files.
FILE_LIST = RT_FSelOpen(title=FSEL_TITLE,dir=FSEL_DIR,filt=FSEL_FILT,multi=FSEL_MULTI)
Assert(!(FILE_LIST.IsInt && FILE_LIST==0),RT_String("%sUser Cancelled in FileSelector - No action taken",myName))
Assert(FILE_LIST.IsString,RT_String("%sRT_FSelOpen Error=%s",myName,String(FILE_LIST)))
###
Return FFMS_MakeMultiPartScript(FILE_LIST,OutPath=OUTPATH,Parts=PARTS)