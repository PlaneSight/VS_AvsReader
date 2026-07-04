### Description
# It trims frames from both ends, then calculates the every value based on the duration. The result is longer by 1-199 frames, so after SelectRangeEvery it makes a final Trim to the exact duration.


### Usage examples
# myselectrange("5000") # creates a 5000 frame long clip
# myselectrange()       # creates a 3000 (default) frame long clip


function myselectrange(clip c, int "duration", int "length", int "trim")
{
   duration = default(duration, 3000)
   length = default(length, 200)
   trim = default(trim, 2000)
   c
   Trim(trim, FrameCount() - trim)
   SelectRangeEvery(FrameCount() / ((duration + length) / length), length)
   Trim(0, -duration)
}
