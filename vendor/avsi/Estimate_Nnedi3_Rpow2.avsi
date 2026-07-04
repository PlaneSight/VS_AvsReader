# Estimate_Nnedi3_Rpow2.avsi

Function Estimate_Nnedi3_Rpow2(clip c,Int OutW,Int OutH, Float "Th",Float "Th2",Bool "Debug") {
/*
    Estimate_Nnedi3_Rpow2() v1.02        (c) StainlessS @ Doom9 :  https://forum.doom9.org/showthread.php?t=176437

    Requires:- RT_Stats if DEBUG==True, else no requirements.

    Estimate required rfactor for nnedi3_rpow2() based on greatest output dimension.
      Purpose is to enable automated decision for rFactor without human intervention.

    We use the term OutDim below where OutDim=Max(OutW,OutH)
    We use the term InDim below where InDim=(OutW>=OutH) ? c.Width : c.Height
    We use the term Scale below where Scale = Float(OutDim)/InDim, ie upscaling factor.
    For any given Scale, we have 2^x <= Scale < 2^(x+1), [ Where x = Int(Log2(Scale)) ].
    It is our task to choose and return either 2^x or 2^(x+1) using a threhold as a boundary condition to make that choice.
    If Scale < 1.0, then we're downscaling and function result will be always be 1, ie DONT use Nnedi_RPow2, just a simple resize.
    The lower choice power of 2 rfLo = 2^x or Pow(2.0, Int(Log2(Scale))) and the higher choice power of 2, is double that ie 2^(x+1) or rfLo*2.0 or Pow(2.0, Int(Log2(Scale))+1)
    Where 1.0 <= Scale < 2.0 : rfLo=1 and rfHi=2, and we use Th threshold for the boundary condition, if Scale >= Th, then will choose rfHi [ie 2] and rfLo[ie 1] if not.
        NOTE, even when Scale=1.0 (no upsizing at all), can force rFactor of 2.0 by setting Th to 1.0 (who knows why you might want that).
    Where 2.0 <= Scale < 4.0 : rfLo=2 and rfHi=4, and we use Th2 threshold to make choice, NOTE Th2 not Th. Can eg use Th to set lowest boundary condition for using
        Nnedi3_RPow2 processing, and use Th2 for other higher upscale decision ranges.
        Higher upscale decision ranges work the same as this 2.0 -> 4.0 upscale decision range, eg 4.0->8.0, and 8.0->16 etc, and all use Th2 for boundary condition.

    Estimate_Nnedi3_Rpow2(clip c, Int OutW, Int OutH, Float "Th"=Sqrt(2.0), Float "Th2"=Th, Bool "Debug"=False)
      Returns Int, 1(dont use nnedi3_rpow2), or rFactor of 2^(1->10).

      Args:-

      c,      Input clip, used to obtain input frame size.

      OutW,   Target resize clip Width.
      OutH,   Target resize clip Height.

      Th,     Default SqRt(2.0) [~1.4142] (range 1.0 <= Th <= 2.0), SWITCH_ON Nnedi3_Rpow2 processing threshold, used when Scale < 2.0.
                A Th of 1.0, would always select the higher rfHi 2^(x+1).
                A Th of 2.0, would Never select the higher rFactor (always the lower rfactor for 2^x, who knows why you might want that).
                A Th of eg 1.5, will set the boundary midway between 2^x and 2^(x+1).
                Default Th=SqRt(2.0), Assuming both dimensions equally scaled and upscaling between 1.0 and 2.0 times, then SqRt(2.0) threshold is broken when Input clip is to be doubled in Area.

      Th2,    Default Th, (range 1.0 <= Th2 <= 2.0), additional threshold to choose rFactor, used if at least doubling target size (where Th not used).
              Works exactly the same as Th threshold, only used where Scale >= 2.0.
              If you for whatever reason want to set Th2 lower than Th, eg Th2 midway between 1.0 and Th, can use Th2 = Int(Th)+Frac(Th)/2.0 or simpler (Th+1.0)/2.0.
              Th2 can be either higher than Th or lower, you choice, but lower might sometimes be the more obvious choice.

                If Th2 == Th, THEN
                    Eg,  InDim=100, Th=Th2=1.5(150%),
                         rF = (OutDim>=150)  ?  2 : 1             Breaks thresh at 150% of (InDim*1)
                         rF = (OutDim>=300)  ?  4 : 2             Breaks thresh at 150% of (InDim*2)
                         rF = (OutDim>=600)  ?  8 : 4             Breaks thresh at 150% of (InDim*4)
                         rF = (OutDim>=1200) ? 16 : 8             Breaks thresh at 150% of (InDim*8)
                    Eg,  InDim=100, Th=Th2=1.1(110%),
                         rf = (Outdim>=110)  ?  2 : 1             Breaks thresh at 110% of (InDim*1)
                         rf = (Outdim>=220)  ?  4 : 2             Breaks thresh at 110% of (InDim*2)
                         rf = (Outdim>=440)  ?  8 : 4             Breaks thresh at 110% of (InDim*4)
                         rf = (Outdim>=880)  ? 16 : 8             Breaks thresh at 110% of (InDim*8)
                Else if Th2 != Th THEN:-
                    Eg, InDim=100, Th=1.5(150%), Th2=1.25(125%)
                         rf = (Outdim>=150)  ?  2 : 1             Breaks thresh at 150% of (InDim*1)  Not doubling size, Using Th(150%)
                         rf = (Outdim>=250)  ?  4 : 2             Breaks thresh at 125% of (InDim*2)  Using Th2(125%)
                         rf = (Outdim>=500)  ?  8 : 4             Breaks thresh at 125% of (InDim*4)  Using Th2(125%)
                         rf = (Outdim>=1000) ? 16 : 8             Breaks thresh at 125% of (InDim*8)  Using Th2(125%)
                     Eg, InDim=100, Th=1.1(110%), Th2=1.05(105%)
                         rf = (Outdim>=110)  ?  2 : 1             Breaks thresh at 110% of (InDim*1)  Not doubling size, Using Th(110%)
                         rf = (Outdim>=210)  ?  4 : 2             Breaks thresh at 105% of (InDim*2)  Using Th2(105%)
                         rf = (Outdim>=420)  ?  8 : 4             Breaks thresh at 105% of (InDim*4)  Using Th2(105%)
                         rf = (Outdim>=840)  ? 16 : 8             Breaks thresh at 105% of (InDim*8)  Using Th2(105%)
                End if

      Debug,    Default False. When true return Messageclip with some debug info, else return Int rFactor result.

      Example:
        BlankClip(width=100,height=100)
        Th=1.5
        Th2=Th
        Return Estimate_nnedi3_rpow2(100,600,Th,Th2=Th2,Debug=TRUE)
*/
    Function Log2(Float n)      { return Log(n)/Log(2.0) }             # Log to base 2
    Function InvLog2(Float n)   { return Pow(2.0,n) }                  # Inverse
    myName = "Estimate_Nnedi3_Rpow2: "     Th=Default(Th,Sqrt(2.0))         Th2=Default(Th2,Th)     Debug=Default(Debug,False)
    Assert(1.0 <= Th  <= 2.0,myName+String(Th, "1.0 <= Th(%f)  <= 2.0"))    Assert(1.0 <= Th2 <= 2.0,myName+String(Th2,"1.0 <= Th2(%f) <= 2.0"))
    InDim = (OutW>=OutH) ? c.Width : c.Height
    Scale = (OutW>=OutH) ? OutW/c.Width.Float : OutH/c.Height.Float    # Based on greatest OUTPUT dimension
    ScaleLg2   = Log2(Scale)                                           # Scale to Log Base 2
    x_Lo       = Min(ScaleLg2.Int,10)                                  # x       : Limited  to Nnedi3_Rpow2 Max of 10 = upscale * 1024
    x_Hi       = Min((Scale<1?x_Lo:x_Lo+1),10)                         # x+1     : limit Rf to 1024 as above. If Scale < 1.0 lock to always return rFactor=1.
    rfLo       = InvLog2(x_Lo).Round                                   # 2^x     : Lower Rf, Int
    rfHi       = InvLog2(x_Hi).Round                                   # 2^(x+1) : Hier  Rf, Int
    UseTh2     = (x_Lo>0)                                              # Use Th2 if at least doubling target size, Else using Th.
    lim        = (UseTh2) ? rfLo*Th2 : rFlo*Th                         # Boundary, Upsize scaling factor has to be at least this to choose higher power of 2.
    RF         = Max((Scale >= Lim ? rfHi : rfLo),1)                   # Choose rFactor, 2^(x+1) or 2^x : Minimum of 1.
    return (!Debug)
        \ ? RF
        \ : MessageClip(RT_String("%s\nTh=%f : Th2=%f : Scale=%f : UseTh2=%.1s\nx_Lo=%d : x_Hi=%d : rFlo=%d : rFhi=%d : Lim=%f : LimDim=%.2f\nRF=%d",
        \       myName,Th,Th2,Scale,UseTh2,x_Lo,x_Hi,rfLo,rfHi,Lim,InDim*Lim,RF))
}