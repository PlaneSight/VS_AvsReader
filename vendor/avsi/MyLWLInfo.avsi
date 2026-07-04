### A simple version of LWLInfo displaying only frame number, picture type, cfr time


### Usage ###
###
# MyLWLInfo(clip c, string "bonus_text", int "bonus_text_color")
###
## Parameters ##
#---------------
# c: The input clip.
#---------------
# bonus_text (default none): Additional text.
#---------------
# bonus_text_color (default yellow): Color of the additional text.


### Changelog ###
#---------------
# Removed the dependency of grunt.
#---------------
# Added check for existing of _PictType frame property.
#---------------
# Added predefined colors. (pcroland)
# Auto change text_size, bonus_text_size, bonus_text_pos when clip width < 1024. (pcroland)
#---------------
# Initial release.


red     = $FF7C7C
green   = $B2FF7C
blue    = $8F97FF
yellow  = $FFE07C
orange  = $FFB97C
magenta = $FF77FF
violet  = $C787FF
cyan    = $7DF9FF
white   = $FFFFFF
azure   = $86C8FF


Function MyLWLInfo(clip c, string "bonus_text", int "bonus_text_color")
{
    bonus_text = default(bonus_text, "")
    bonus_text_color = default(bonus_text_color, $FFE07C)
    Width(c) < 1024 ? Eval("""
    text_size       = 16
    bonus_text_size = 25
    bonus_text_pos  = 54
""") : Eval("""
    text_size       = 18
    bonus_text_size = 28
    bonus_text_pos  = 60
""")

    ScriptClip(c, """
    if (propGetType("_PictType") > 0) { prop = "Picture Type: " + String(propGetString("_PictType")) + "\n" }
    else { prop = "" }
    Subtitle("Frame Number: " + String(current_frame) + " of " + String(FrameCount()) + "\n" +
    \ prop +
    \ "CFR Time: " + FFFormatTime(Round((current_frame * 1000) / FrameRate())) + "\n", y=5, size="""+ String(text_size) +""", text_color=$FFFFFF, halo_color=$000000, lsp=1)
    return Subtitle(""""+ bonus_text +"""", y="""+ String(bonus_text_pos) +""", size="""+ String(bonus_text_size) +""", text_color="""+ String(bonus_text_color) +""")""", after_frame=true)
}
