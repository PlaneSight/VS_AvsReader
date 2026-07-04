# DenoiseSelective by SlowDelivery, mod by StainlessS and GPo (v1.0.3) # https://forum.doom9.org/showthread.php?p=1914252#post1914252
# thr       : Noise level threshold
# thr_min   : Noise or Denoise Level must be greater than thr_min, otherwise no filtering.
# soft=True : Applies a chosen denoiser with smooth transition dependent on the noise level and threshold.
# soft=False: Applies chosen denoiser (denoiser, denoiser2) dependent on the noise level and threshold.
# If an empty string is specified for denoiser2 (""), only denoiser is used.

          
# The script requires SMDegrain and Grunt for Args.
#
# You can change the SMDegrain settings or use denoisers other than SMDegrain.
# Example:
# DenoiseSelective(thr=0.7, denoiser="""MCTemporalDenoise(settings="low", sigma=2, strength=100, tovershoot=1, GPU=True)""",
# \denoiser2="""MCTemporalDenoise(settings="low", sigma=4, strength=120, tovershoot=1, GPU=True)""",
# \denoiserTest="FFT3DGPU(sigma=1)", soft=False, thr_min=0.2, show=True)
#
Function DenoiseSelective(clip c, float "thr", string "denoiser", string "denoiser2", string "denoiserTest", bool "soft", float "thr_min", bool "show") {
    c
    thr     = Default(thr, 1.0)
    thr_min = Default(thr_min, 0.2)
    denoiser     = Default(denoiser, "SMDegrain(tr=3,thSAD=200)")
    denoiser2    = Default(denoiser2, "SMDegrain(tr=3,thSAD=400)")
    denoiserTest = Default(denoiserTest, "SMDegrain(tr=1,thSAD=400,chroma=false)")
    soft         = Default(soft, False)
    show         = Default(show, False)
    Assert(!soft || thr>0, "DenoiseSelective: Threshold must be greater then 0")

    x0 = (Width +4)/8*2
    y0 = (Height+4)/8*2
    window    = Spline36Resize(x0*2,y0*2,x0,y0,-x0,-y0)
    tested    = window.Eval(denoiserTest)
    useD2     = (denoiser2 != "")
    denoised  = Eval(denoiser)
    denoised2 = !soft ? useD2 ? Eval(denoiser2) : denoised : last
    
    sss = (soft) ? """
        noise  = LumaDifference(window,tested)
        weight = Min(noise/thr,1)
        weight = weight > thr_min ? weight : 0
        weight > 0 ? merge(last, denoised, weight=weight) : last
    """ : """
        noise = LumaDifference(window,tested)
        T = (noise>thr)
        noise > thr_min ? (T) ? denoised2 : useD2 ? denoised : last : last
    """
    sss = sss + (
        \ (!show)
        \   ? ""
        \   : (!soft)
        \     ? """Subtitle( "Noise Level: "+String(noise) + (noise > thr_min ? T ?  useD2 ? " D2" : " D1" : useD2 ? " D1" : " F" : " F"))"""
        \     : """Subtitle( "Noise Level: "+String(noise) + " - Denoise Level: " + String(weight))"""
    \ )
    Return ScriptClip(sss,Args="window,tested,denoised,denoised2,thr,thr_min,useD2")  # Req Grunt for Args (get rid of Globals).
}