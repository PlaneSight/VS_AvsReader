### A sharpening script with aSobel and CAS plugins
### https://forum.doom9.org/showthread.php?p=2003218#post2003218

### Requirements: CAS, aSobel


Function MCAS(clip video,float "Strength")
{
    Assert(ComponentSize(video) < 4, "MCAS: video must be 8/10/12/14/16-bit.")
    Assert(!IsRGB(video), "MCAS: video must be in Y/YUV format.")

    Strength = Default(Strength,1.0)

    LevelLimit=BitShl(1, BitsPerComponent(video)) - 1
    IntensityMask=ConvertToY(video).Levels(0,2,LevelLimit,0,LevelLimit,coring=false)
    EdgeMask=aSobel(IntensityMask,chroma=0,thresh=255,SetAffinity=false).invert.Levels(0,2,LevelLimit,0,LevelLimit,coring=false).Blur(1)
    SharpMask=Overlay(IntensityMask,EdgeMask,mode="Multiply",opacity=1.0)
    SharpenedVideo=CAS(video,1.0)
    video=Overlay(video,SharpenedVideo,mask=SharpMask,opacity=Strength)

    return video
}
