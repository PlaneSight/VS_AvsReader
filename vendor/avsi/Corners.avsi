# Corners.avsi, https://forum.doom9.org/showthread.php?p=1819881#post1819881
# Crops all 4 corners of input and outputs stack4 window clip of those corners, allows viewing of corners without scrolling large input clip.
# Giving W=Width(default width/4) and H=Height(default Height/4) of corners. (Default output dim half of input dim, ie 2*Width/4, 2*Height/4).
# (Max W=c.Width, H=c.Height, where output 4 window stack of double dimensions to input).
Function Corners(clip c, Int "W", Int "H") {
    c
    W = Default(W, 720)
    H = Default(H, 360)
    W = Default(W,Width/4)          H = Default(H,Height/4)             # Default corners quarter of dimensions
    W=W/4*4                         H=H/4*4                             # W Mod4 (YV411 compat), H Mod4 (YV12 Interlaced compat)
    Assert(0 < W <= Width , "Corners: Invalid W"+String(W,"(%.0f)"))
    Assert(0 < H <= Height, "Corners: Invalid H"+String(H,"(%.0f)"))
    tl=crop(0,0,W,H)                tr=crop(Width-W,0,W,H)
    bl=crop(0,Height-H,W,H)         br=crop(Width-W,Height-H,W,H)
    Top=StackHorizontal(tl,tr)      bot=StackHorizontal(bl,br)
    Return StackVertical(Top,Bot)
}

# Alternate function, Giving W=Width and H=Height of output clip (should be W=Mod8 for YV411 and H=Mod8 for Interlaced YV12)
# (Max W=c.Width*2, H=c.Height*2, where output 4 window stack of double dimensions to input).
Function Corners2(clip c, Int "W", Int "H") { return c.Corners( Default(W,c.Width/2)/8*4, Default(H,c.Height/2)/8*4) }

# Return stack4 window, double dim of input clip. (Maybe of use if some plugin metrics are too big for the input clip [some metrics missing])
Function CornersX4(clip c) { return c.Corners(c.Width,c.Height) }