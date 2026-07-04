# added usage and changes info; added missing helper function; 8/10-bit ~10% speedup, 16-bit significant speedup; removed full_range parameter;
# added bool full_range* parameter (default=false) for processing high bit depth - full_range=false usually for limited range YUV
# removed the helper functions; fixed the 16-bit processing

# Toon() - port of vs havsfunc.Toon
# Line darkener. It enhances "cartoon-like" sources, such as anime, by applying filtering to edges and such.
#
# needed filters:
#	- MaskTools2
#	- aWarpSharp2
#
# parameters:
#	str	- strength of the line darken				    1.0
#	l_thr	- lower threshold for the linemask			2
#	u_thr	- upper threshold for the linemask			12
#	depth	- warping depth (awarpsharp readme)			32
#	blur	- warping blur (awarpsharp readme)			2	(1 is faster)


Function Toon(clip input, float "str", int "l_thr", int "u_thr", int "blur", int "depth")
{
    Assert(IsYUV(input), "Only YUV clips allowed.")
    
    str         = Default(str, 1)
    l_thr       = Default(l_thr, 2)
    u_thr       = Default(u_thr, 12)
    blur        = Default(blur, 2)
    depth       = Default(depth, 32)
    
    orig = input   
    if (NumComponents(input) > 1)
    {
        input = ExtractY(input)
    }
    
    usee = BitsPerComponent(input) > 10 ? 3 : 0
        
    ludiff  = u_thr - l_thr
    
    mt_makediff(mt_expand(input).mt_inpand(), input)
    mt_logic(last, Padding(6,6,6,6).aWarpSharp2(blur = blur, depth = depth).Crop(6,6,-6,-6), "min")
    expr = "y 128 scaleb "+ string(l_thr) +" scaleb + <= 128 scaleb y 128 scaleb "+ string(u_thr) +" scaleb + >= x 128 scaleb "+ string(u_thr) +" scaleb + y - 128 scaleb * x y 128 scaleb "+ string(l_thr) +" scaleb + - * + "+ string(ludiff) +" scaleb / ? 128 scaleb - "+ string(str) +" * 128 scaleb + ?"
    mt_makediff(input, mt_lutxy(last, mt_expand(), expr, use_expr=usee))
    
    NumComponents(orig) > 1 ? CombinePlanes(last, orig, planes="YUV", sample_clip = orig) : last
}

function Padding(clip c, int left, int top, int right, int bottom)
{
w = c.width()
h = c.height()
c.pointresizemt( w+left+right, h+top+bottom, -left, -top, w+left+right, h+top+bottom )
}