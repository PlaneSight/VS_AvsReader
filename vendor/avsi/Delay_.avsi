/*
A simple script for adding frames to or removing frames from specific position.
Added frames are black frames.

This function could be used when wanting to compare two videos and one of them is shorter or longer with one or few  frames.

Author of the initial script - nyuszika7h
*/


### Usage ###
###
# Delay(clip c, int x, int "position", string "frame_type")
###
## Parameters ##
#---------------
# c: Input clip.
#---------------
# x: The number of the frames that will be added or removed.
#---------------
# position (default 0): It specifies where to add or remove frame(s). Frame counting starts from 0.
#---------------
# frame_type (not specified): Set frame property '_PictType' for the added frames.


### Examples ###
# Delay(-10) # Cut 10 frames from the beginning.
# Delay(10) # Add 10 frames at the beginning.
# Delay(3, 1000) # Add 3 frames after frame 1000.
# Delay(-5, 3) # Remove 5 frames after frame 3.


### Changelog ###
#---------------
# 1.0.1
# Added parameter `frame_type`.
#---------------
# Added parameter 'position'.
#---------------
# Initial version.


Function Delay(clip c, int x, int "position", string "frame_type")
{
    position = Default(position, 0)
    c

    if (x < 0)
    {
        return (position == 0) ? Trim(-x, 0) : (Trim(0, -position) + Trim(-x + position, 0))
    }
    else
    {
        if (!Defined(frame_type))
        {
            return (position == 0) ? (BlankClip(c, x) + c) : (Trim(0, -position) + BlankClip(c, x) + Trim(position, 0))
        }
        else
        {
            Assert(frame_type == "I" || frame_type == "B" || frame_type == "P", """Delay: frame_type must be "I", "P", or "B".""")
            return (position == 0) ? (propSet(BlankClip(c, x), "_PictType", UCase(frame_type)) + c) : (Trim(0, -position) + propSet(BlankClip(c, x), "_PictType", UCase(frame_type)) + Trim(position, 0))
        }
    }
}
