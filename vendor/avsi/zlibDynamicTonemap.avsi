# Requires latest z.lib resizers/avsresize and HDRTools

# Dynamic attribute
# Adjusts the algorithm to increase overall brightness instead of contrast. Lower = brighter.
# Range: 0.25 - 1.00

# Algo attribute
# Selects the local tonemapping algorithm.
# Options: HLG (default)

# Gamma attribute
# Adjusts RGB gamma for HLG tonemapping only.
# Default: 1.00

# ManHLG attribute
# Sets the HLGLw manually instead of calculated.
# Also disables zimg
# Default: Disabled

function dynamicTonemap(clip c, bool "zimg", float "dynamic", string "algo", float "gamma", int "manHLG", bool "show")
{

  global zimg = default(zimg, true)
  global dynamic = default(dynamic, 1.00)
  global algo = default(algo, "HLG")
  global gamma = default(gamma, 1.00)
  global manHLG = default(manHLG, 0)
  global show = default(show, false)

  ScriptClip(c,"""
    dynamic = dynamic < 0.25 ? 0.25 : dynamic > 1.00 ? 1.00 : dynamic

    avg = AverageLuma()
    max_50 = YPlaneMax(50)
    max_25 = YPlaneMax(25)
    max_10 = YPlaneMax(10)
    max_5 = YPlaneMax(5)
    max_1 = YPlaneMax(1)
    max = YPlaneMax(0.05)

    cond = (max_50 >= 500 && max_10 >= max_50+100) || max_1 >= 500 && (max - avg) >= 450 && ((max_50 * 3) >= max || max > 800)
    cond2 = max_1 >= 500 && (max_1 - avg) >= 250 && (max_25 - avg) >= 200

    cond ? Eval("
      lum = ((4 * avg) + (0.5 * max * (dynamic * dynamic)) + (1.5 * max_1 * (dynamic * dynamic)) + (2 * max_25) + (1 * max_50))/9
    ") : cond2 ? Eval("
      lum = ((3 * avg) + (1 * max * (dynamic * dynamic)) + (2 * max_1 * (dynamic * dynamic)) + (1.5 * max_25) + (1 * max_50))/8.5
    ") : Eval("
      lum = ((4 * (avg/3)) + (0.5 * max * (dynamic * dynamic)) + (0.5 * max_1 * (dynamic * dynamic)) + (2 * (max_25/3)) + (1 * max_50))/8
    ")

    lum = lum < 100 ? 100 : Round(lum)
    algo = LCase(algo)

    cond_hlg = lum <= 150

    cond_hlg ? Eval("
      lumHLG = ((1 * avg) + (4 * max * (dynamic * dynamic)) + (2 * max_1 * (dynamic * dynamic)) + (2 * max_10) + (1 * max_25) + (1 * max_50))/11
    ") : Eval("
      lumHLG = ((2 * avg) + (2 * max * (dynamic * dynamic)) + (3 * max_1 * (dynamic * dynamic)) + (2 * max_25) + (2 * (max_50/2)))/11

      cond_hlg = lumHLG >= lum * 2 && (max - lum) < 400 && ((max_5 - max_25) <= 125 || max_5 - max_10 <= 50)
      cond_hlg2 = max >= 800 || (cond || cond2 || max_1 >= lum * 3) && (max - avg) >= 450 && !cond_hlg

      #Restore brightness
      cond_hlg3 = lum >= 200 && (max_5 < 450 || (max_5 - max_10 <= 50)) && (lumHLG >= max_50 || lumHLG >= avg)

      lumHLG = cond_hlg ? lum : cond_hlg2 ? lumHLG * 2 : cond_hlg3 ? lumHLG - max_50/3 : lumHLG
    ")

    #Manual HLGLw param
    lumHLG = manHLG == 0 && zimg ? lumHLG : manHLG != 0 && !zimg ? manHLG : lumHLG * 2.0

    #Disable zimg when manual HLGLw is specified
    zimg = manHLG != 0 ? false : zimg

    lumHLG = Round(lumHLG)

    #Adjust gamma for semi-dark scenes
    finalGamma = zimg && lum > 150 ? 1 + (((lum/100.0) * 0.025) + (gamma - 1.00)) : 1.00 + (gamma - 1.00)

    final =  algo == "hlg" ? tonemapHLG(last, zimg, lum, lumHLG, finalGamma) : Blackness(last, length=24, pixel_type="YUV420P10").Subtitle("Invalid tonemap algorithm", x=-1, y=-1)

    show == true ? final.Subtitle("Algo: "+algo+"\nAvg: "+String(avg)+"\nMax 0.05%: "+String(max)+"\nMax 1%: "+String(max_1)+"\nMax 5%: "+String(max_5)+"\nMax 10%: "+String(max_10)+"\nMax 25%: "+String(max_25)+"\nMax 50%: "+String(max_50)+"\nLuminance: "+String(lum)+"\nHLGLw: "+String(lumHLG)+"\nApplied gamma: "+String(finalGamma), lsp=10) : final
  """)
}

function tonemapHLG(clip c, bool zimg, int lum, int lumHLG, float finalGamma){

  final = zimg ? ScriptClip(c,"""
      #Convert to linear & apply nominal_luminance
      z_ConvertFormat(pixel_type="RGBPS", resample_filter_uv="spline36", colorspace_op="2020:st2084:2020:l=>rgb:linear:2020:l", nominal_luminance=lum)
      z_ConvertFormat(colorspace_op="rgb:linear:2020:l=>rgb:st2084:2020:l")

      #Convert to HLG
      ConvertRGBtoXYZ(Color=0, OOTF=false, OutputMode=2)
      ConvertXYZtoYUV(Color=0, HDRMode=1, HLGLw=lumHLG, HLGColor=1, OOTF=false)

      #Convert 2020 primaries to 709
      ConvertYUVtoXYZ(Color=1, OutputMode=2)
      ConvertXYZtoYUV(Color=2, pColor=1)

      #Fix red hue caused by HDRTools
      Tweak(hue=-2, startHue=28,endHue=180,sat=0.95)

      #Adjust gamma, limit to dark areas
      ConvertToStacked()
      SmoothLevels16(gamma=finalGamma, Lmode=2, brightStr=200)
      ConvertFromStacked(16)

      z_ConvertFormat(pixel_type="YUV420P10")
    """) : ScriptClip(c,"""
      #Convert to HLG
      ConvertYUVtoXYZ(Color=0,OOTF=false,OutputMode=2)
      ConvertXYZtoYUV(Color=0, HDRMode=1, HLGLw=lumHLG, HLGColor=1, OOTF=false)

      #Convert 2020 primaries to 709
      ConvertYUVtoXYZ(Color=1, OutputMode=2)
      ConvertXYZtoYUV(Color=2, pColor=1)

      #Adjust gamma, limit to dark areas
      ConvertToStacked()
      SmoothLevels16(gamma=finalGamma, Lmode=2, brightStr=200)
      ConvertFromStacked(16)

      z_ConvertFormat(pixel_type="YUV420P10")
    """)

    final
}