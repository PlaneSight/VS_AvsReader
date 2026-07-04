# Changelog:
# fixed Ylevels high bit depth gamma calculation (todo: the other functions).
###
# fixed bug, high bit depth support
###
# added restrictions "input_low and input_high must be different" and "output_low and output_high must be different" to prevent division by zero; fixed show_function type int -> bool and the processing when true


########
# Levels transforms by Didée
# Requires MaskTools v2.0 or greater
# last revision 2004-12-07; update to MaskTools v2.0 semantics 2008-03-09
#
# PARAMETERS:
#   "input_low"     : (Default: 0)
#   "gamma"         : (Default: 1.0)
#   "input_high"    : (Default: 255)
#   "output_low"    : (Default: 0)
#   "output_high"   : (Default: 255)
#   "show_function" : (Default: false) - the function to be made into a lookup-table
#                                        transform, shown in postfix notation
#
# USAGE:
#   YLevels(0, 1.2, 255, 0, 255, false)
#   YLevels(0, 1.2, 255)
#   YLevels(gamma=1.2)



# Constant
function Ylevels(clip clp,
\                int "input_low", float "gamma", int "input_high",
\                int "output_low", int "output_high", bool "show_function")
{ 
    input_low = Default(input_low, 0)
    gamma = Default(gamma, 1.0)
    input_high = Default(input_high, 255)
    output_low = Default(output_low, 0)
    output_high = Default(output_high, 255)
    show_function = Default(show_function, false)
    
    Assert(input_low != input_high, "input_low and input_high must be different.")
    Assert(output_low != output_high, "output_low and output_high must be different.")
    
    pixelsize = ComponentSize(clp)
    
    wicked = (pixelsize == 1) ? "x " +string(input_low)+ " scalef - " +string(input_high)+ " scalef " +string(input_low)+ " scalef - / 1 " +string(gamma)+
    \        " / ^ " +string(output_high)+ " scalef " +string(output_low)+ " scalef - * " +string(output_low)+ " scalef +" :
    \ (pixelsize == 2) ? "x " +string(input_low)+ " scalef - " +string(input_high)+ " scalef " +string(input_low)+ " scalef - / 0 1.0915 " +string(gamma)+ " * clip 1 " +string(gamma)+
    \        " / ^ " +string(output_high)+ " scalef " +string(output_low)+ " scalef - * " +string(output_low)+ " scalef +" :
    \        "x " +string(input_low)+ " scalef - " +string(input_high)+ " scalef " +string(input_low)+ " scalef - / 0 1.0915 " +string(gamma)+ " " +string(gamma)+ " * " +string(gamma)+ " / ^ clip 1 " +string(gamma)+
    \        " / ^ " +string(output_high)+ " scalef " +string(output_low)+ " scalef - * " +string(output_low)+ " scalef +"
        
    return( show_function ? clp.mt_lut(Yexpr = wicked, use_expr=2, chroma="copy").subtitle(wicked) : clp.mt_lut(Yexpr = wicked, use_expr=2, chroma="copy"))  
}
         
# Gradient
function YlevelsG(clip clp,
\                int "input_low", float "gamma", int "input_high",
\                int "output_low", int "output_high", bool "show_function")
{ 
    input_low = Default(input_low, 0)
    gamma = Default(gamma, 1.0)
    input_high = Default(input_high, 255)
    output_low = Default(output_low, 0)
    output_high = Default(output_high, 255)
    show_function = Default(show_function, false)

    Assert(input_low != input_high, "input_low and input_high must be different.")
    Assert(output_low != output_high, "output_low and output_high must be different.")
    
    wicked = BitsPerComponent(clp) < 32 ? gamma > 1.0
    \      ? "x " +string(input_low)+ " scalef - " +string(input_high)+ " scalef " +string(input_low)+ " scalef - / 1 " +string(gamma)+
    \        " / ^ " +string(output_high)+ " scalef " +string(output_low)+ " scalef - * " +string(output_low)+ " scalef + x * x 255 scalef x - * + 255 scalef /"
    \      : "x " +string(input_low)+ " scalef - " +string(input_high)+ " scalef " +string(input_low)+ " scalef - / 1 " +string(gamma)+
    \        " / ^ " +string(output_high)+ " scalef " +string(output_low)+ " scalef - * " +string(output_low)+ " scalef + 255 scalef x - * x x * + 255 scalef /" :
    \        gamma > 1.0 ? "x " +string(input_low)+ " scalef - " +string(input_high)+ " scalef " +string(input_low)+ " scalef - / 0 1 clip 1 " +string(gamma)+
    \        " / ^ " +string(output_high)+ " scalef " +string(output_low)+ " scalef - * " +string(output_low)+ " scalef + x * x 255 scalef x - * + 255 scalef /" :
    \        "x " +string(input_low)+ " scalef - " +string(input_high)+ " scalef " +string(input_low)+ " scalef - / 1 " +string(gamma)+
    \        " / ^ " +string(output_high)+ " scalef " +string(output_low)+ " scalef - * " +string(output_low)+ " scalef + 255 scalef x - * x x * + 255 scalef /"
    
    
    return( show_function ? clp.mt_lut(Yexpr = wicked, use_expr=2, chroma="copy").subtitle(wicked) : clp.mt_lut(Yexpr = wicked, use_expr=2, chroma="copy") )  
}

# Sine
function YlevelsS(clip clp,
\                int "input_low", float "gamma", int "input_high",
\                int "output_low", int "output_high", bool "show_function")
{ 
    input_low = Default(input_low, 0)
    gamma = Default(gamma, 1.0)
    input_high = Default(input_high, 255)
    output_low = Default(output_low, 0)
    output_high = Default(output_high, 255)
    show_function = Default(show_function, false)
    
    Assert(input_low != input_high, "input_low and input_high must be different.")
    Assert(output_low != output_high, "output_low and output_high must be different.")
    
    wicked = BitsPerComponent(clp) < 32 ? "x " +string(input_low)+ " scalef - " +string(input_high)+ " scalef " +string(input_low)+ " scalef - / 1 " +string(gamma)+
    \      " / ^ " +string(output_high)+ " scalef " +string(output_low)+ " scalef - * " +string(output_low)+ " scalef + x 162.97466 scalef /" +
    \      " sin 255 scalef * * x 255 scalef x 162.97466 scalef / sin 255 scalef * - * + 255 scalef /" :
    \      "x " +string(input_low)+ " scalef - " +string(input_high)+ " scalef " +string(input_low)+ " scalef - / 0 1 clip 1 " +string(gamma)+
    \      " / ^ " +string(output_high)+ " scalef " +string(output_low)+ " scalef - * " +string(output_low)+ " scalef + x 162.97466 scalef /" +
    \      " sin 255 scalef * * x 255 scalef x 162.97466 scalef / sin 255 scalef * - * + 255 scalef /"
    
    return( show_function ? clp.mt_lut(Yexpr = wicked, use_expr=2, chroma="copy").subtitle(wicked) : clp.mt_lut(Yexpr = wicked, use_expr=2, chroma="copy") )  
}

# Cosine
function YlevelsC(clip clp,
\                int "input_low", float "gamma", int "input_high",
\                int "output_low", int "output_high", bool "show_function")
{ 
    input_low = Default(input_low, 0)
    gamma = Default(gamma, 1.0)
    input_high = Default(input_high, 255)
    output_low = Default(output_low, 0)
    output_high = Default(output_high, 255)
    show_function = Default(show_function, false)
    
    Assert(input_low != input_high, "input_low and input_high must be different.")
    Assert(output_low != output_high, "output_low and output_high must be different.")
    
    wicked = BitsPerComponent(clp) < 32 ? "x " +string(input_low)+ " scalef - "+ string(input_high)+ " scalef " +string(input_low)+ " scalef - / 1 "+string(gamma)+
    \      " / ^ " +string(output_high)+ " scalef " +string(output_low)+ " scalef - * " +string(output_low)+ " scalef + 255 scalef x 162.97466 scalef " +
    \      " / cos 255 scalef * - * x x 162.97466 scalef / cos 255 scalef * * + 255 scalef /" :
    \      "x " +string(input_low)+ " scalef - "+ string(input_high)+ " scalef " +string(input_low)+ " scalef - / 0 1 clip 1 "+string(gamma)+
    \      " / ^ " +string(output_high)+ " scalef " +string(output_low)+ " scalef - * " +string(output_low)+ " scalef + 255 scalef x 162.97466 scalef " +
    \      " / cos 255 scalef * - * x x 162.97466 scalef / cos 255 scalef * * + 255 scalef /"
    
    return( show_function ? clp.mt_lut(Yexpr = wicked, use_expr=2, chroma="copy").subtitle(wicked) : clp.mt_lut(Yexpr = wicked, use_expr=2, chroma="copy") )  
}
