Import(".\Duplicity2.Avsi")

######
FN  = "D:\G.AVI"          DBase  = "D:\G_Det.DB"         ThB=2.0
#FN  = "D:\GTEST.AVI"      DBase  = "D:\GTEST_Det.DB"        ThB=2.0
#FN = "D:\HAR.AVI"         DBase  = "D:\HAR_Det.DB"          ThB=2.5
#FN = "D:\DeDupTest.AVI"   DBase  = "D:\DeDupTest_Det.DB"    ThB=2.0
######
Avisource(FN)
SRC=Last
###
Mode=2             # 0=Write Frames only : 1=Replace Dupes with Exact Dupes : 2= Interpolate/Blend Duplicates.
ThG=1.0            # Primary Frame Global Detect
ThP=64             # Pixel Count Detect
MaxDupLen=9        # Max detected, if more then is considered static sequence not duplicate)
MaxInterp=9        # Max Interpolated frames when Mode=2 (More than MaxInterp & less or equal to MaxDupLen then uses Blend mode)
InterpFast=true
Show=True
ShowDot=False
ShowBlk=true
VERB=False
###
TITLE=False
STACK=True
STACK4=False
###

Result=SRC.Duplicity2(Mode=Mode,ThG=ThG,ThB=ThB,ThP=ThP,MaxDupLen=MaxDupLen,MaxInterp=MaxInterp,
    \ Show=False,InterpFast=InterpFast,DBase=(STACK4||!SHOW)?DBase:"")

Metrics=SRC.Duplicity2(Mode=Mode,ThG=ThG,ThB=ThB,ThP=ThP,MaxDupLen=MaxDupLen,MaxInterp=MaxInterp,
    \ Show=True,Verb=VERB,ShowBlk=ShowBlk,ShowDot=ShowDot,InterpFast=InterpFast,DBase=(STACK4||!SHOW)?"":DBase)

Dif=Subtract(Result,SRC)

SRC     = (TITLE) ? SRC.TSub("Src")             : SRC
Result  = (TITLE) ? Result.TSub("Result")       : Result
Metrics = (TITLE) ? Metrics.TSub("Metrics")     : Metrics
Dif     = (TITLE) ? Dif.TSub("Dif(Result,Src)") : Dif

LFT=StackVertical((STACK4||!SHOW)?Result:Metrics,SRC)
RGT=StackVertical(Metrics,Dif)
STK4=StackHorizontal(LFT,RGT)

(STACK4) ? STK4 : (STACK) ? LFT : (Show)?Metrics:Result

Return Last


# Stack Overhead Subtitle Text, with optional FrameNumber shown.
Function TSub(clip c,string Tit,Bool "ShowFrameNo",Int "Col"){
    c.BlankClip(height=20,Color=Default(Col,0))
    (Default(ShowFrameNo,False))?ScriptClip("""Subtitle(String(current_frame,"%.f] """+Tit+""""))"""):Subtitle(Tit)
    Return StackVertical(c).AudioDubEx(c)
}
