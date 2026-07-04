function ApplyGradationCurves(clip input, string "lumaPoints", string "redPoints", string "greenPoints", string "bluePoints", string "curvesFile", string "plotsPath"){
    lumaPoints = Default(lumaPoints, "")
    redPoints = Default(redPoints, "")
    greenPoints = Default(greenPoints, "")
    bluePoints = Default(bluePoints, "")
    
    plotFileY = plotsPath.Defined() ? plotsPath+"/gradationCurve_y_"+Time("%Y%m%d%H%M%S")+".bmp" : ""
    plotFileR = plotsPath.Defined() ? plotsPath+"/gradationCurve_r_"+Time("%Y%m%d%H%M%S")+".bmp" : ""
    plotFileG = plotsPath.Defined() ? plotsPath+"/gradationCurve_g_"+Time("%Y%m%d%H%M%S")+".bmp" : ""
    plotFileB = plotsPath.Defined() ? plotsPath+"/gradationCurve_b_"+Time("%Y%m%d%H%M%S")+".bmp" : ""
    
    plotsStringY = plotsPath.Defined() ? ",plotpath=plotFileY)" : ")"
    plotsStringR = plotsPath.Defined() ? ",plotpath=plotFileR)" : ")"
    plotsStringG = plotsPath.Defined() ? ",plotpath=plotFileG)" : ")"
    plotsStringB = plotsPath.Defined() ? ",plotpath=plotFileB)" : ")"
    
    lumaCurve = (StrLen(lumaPoints)>0) ? Eval("GradationCurveExpression(input,"+lumaPoints+plotsStringY) : (curvesFile.Defined()) ? Eval("""GradationCurveExpression(input,curvesfileplane="y",curvesfile=curvesFile"""+plotsStringY) : ""
    redCurve = (StrLen(redPoints)>0) ? Eval("GradationCurveExpression(input,"+redPoints+plotsStringR) : (curvesFile.Defined()) ? Eval("""GradationCurveExpression(input,curvesfileplane="r",curvesfile=curvesFile"""+plotsStringR) : ""
    greenCurve = (StrLen(greenPoints)>0) ? Eval("GradationCurveExpression(input,"+greenPoints+plotsStringG) :  (curvesFile.Defined()) ? Eval("""GradationCurveExpression(input,curvesfileplane="g",curvesfile=curvesFile"""+plotsStringG) : ""
    blueCurve = (StrLen(bluePoints)>0) ? Eval("GradationCurveExpression(input,"+bluePoints+plotsStringB) :  (curvesFile.Defined()) ? Eval("""GradationCurveExpression(input,curvesfileplane="b",curvesfile=curvesFile"""+plotsStringB) : ""
 
    output = (input.IsRGB()) ? input.Expr(redCurve,greenCurve,blueCurve) : input
    output = (input.IsRGB() || input.NumComponents()==1) ? output.Expr(lumaCurve) : output.Expr(lumaCurve,"","")
    return output
}
