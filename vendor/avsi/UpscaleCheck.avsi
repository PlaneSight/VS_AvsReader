### Script to check if the video is upscaled.


### Usage ###
###
# UpscaleCheck(clip c, int "resolution", bool "show", bool "interlaced")
###
## Parameters ##
#---------------
# c: The clip that will be processed.
#---------------
# resolution (default 720): The resolution that will be used for resizing to and then resizing from to the original resolution.
#---------------
# show (default false): Whether to show FFT Spectrum.
# False: the video is downsampled and upsampled then the frames from the processed video and the original video are interleaved.
#---------------
# interlaced (default false): Whether the video is interlaced.


/*
How to use UpscaleCheck(show=true) (1080p source assumed):
1. Find several high motion and complex frames for testing.
2. UpscaleCheck(1080, show=true) - check the source resolution.
3. Look if the spectrum does touch the borders. If so - the video has 1080 details.
4. If the spectrum doesn't touch the borders - check with lower resolution: UpscaleCheck(720, show=true).
4a. Look if the spectrum does touch the borders. If so - the video has 720 details.
5. If the spectrum doesn't touch the borders - check with lower resolution: UpscaleCheck(480, show=true).
5a. ... and so on.
*/


### Changelog ###
#---------------
# 1.0.1
# Added parameter interlaced.
# Fixed show=true when bit depth > 8.
#---------------
# 1.0.0
# Changed the behavior when show=true.
#---------------
# Replaced myffinfo with MyLWLInfo.
#---------------
# Changed parameter resolution to int for AutoResize func.
#---------------
# Added show parameter.
#---------------
# Initial version.


function UpscaleCheck(clip c, int "resolution", bool "show", bool "interlaced")
{
    resolution = default(resolution, 720)
    show = default(show, false)
    interlaced = default(interlaced, false)

    if (!show)
    {
        Interleave(MyLWLInfo(c, "source", color_lawngreen), AutoResize(c, resolution, dither_type="none", interlaced=interlaced).z_ConvertFormat(c.Width, c.Height, resample_filter="spline36", interlaced=interlaced, dither_type="none").MyLWLInfo("source -> " + String(resolution) + " -> source", color_cyan))
    }
    else
    {
        if (ComponentSize(c) > 1)
        {
            c = (ComponentSize(c) == 2) ? ConvertBits(c, 8) : ConvertBits(c, 8, fulls=true, fulld=false)
        }

        AutoResize(c, resolution, dither_type="none", interlaced=interlaced)
        FFTSpectrum()
    }
}
