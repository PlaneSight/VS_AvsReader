green  = $B2FF7C
blue   = $8F97FF
yellow = $FFE07C
orange = $FFB97C
red    = $FF7C7C
cyan   = $7DF9FF
magenta= $FF7CCB
purple = $B788FF

function myffinfo(clip c, string "bonus_text", int "bonus_text_color") {
    varprefix = FFVAR_PREFIX
    bonus_text = default(bonus_text, "")
    bonus_text_color = default(bonus_text_color, color_yellow)

    c.frameevaluate("""
        fftempstring = ""
        varprefix = """" + varprefix + """"
    """)

    frameevaluate("""
        fftempstring = fftempstring + "Frame Number: " + string(current_frame) + " of " + string(framecount()) + "\n"
        fftempstring = fftempstring + "Picture Type: " + chr(eval(varprefix + "FFPICT_TYPE")) + "\n"
        fftempstring = fftempstring + "CFR Time: " + FFFormatTime(round((current_frame * 1000) / framerate())) + "\n"
    """, after_frame=true)

    return scriptclip("""
        subtitle(fftempstring, y=5, size=18, halo_color=$000000, lsp=1)
        subtitle("""" + bonus_text + """", y=60, size=28, text_color=""" + string(bonus_text_color) + """)
    """, after_frame=true)
}
