/*
AvsReader.h

This file is a part of VS_AvsReader

Copyright (C) 2016  Oka Motofumi
Copyright (C) 2026  PlaneSight

Author: Oka Motofumi (chikuzen.mo at gmail dot com)

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with Libav; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
*/

#ifndef VS_AVS_READER_H
#define VS_AVS_READER_H

#include <string>
#include <cstdint>
#include <cstring>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#define VC_EXTRALEAN
#define NOMINMAX
#define NOGDI
#include <windows.h>
#endif

#include <avisynth.h>
#include <VapourSynth4.h>


#define VSAVSREADER_VERSION "2.0.0"


/* Wrapper holding a per-output reader + index for multi-output filters.
   Each filter node gets its own AvsReaderOutput so get_frame() knows
   which clip to produce. */
struct AvsReaderOutput {
    class AvsReader* reader;
    int outputIndex;        /* 0 = base clip, 1 = alpha clip */
    VSVideoInfo vi;         /* per-output video info (base or alpha) */
    void (*write_frame)(VSFrame** dst, PVideoFrame& src,
                        int num_planes, const VSAPI* api);
};

/* Number of active AvsReader references across outputs.
   The last freed output deletes the shared reader. */
extern int g_readerRefCount;


class AvsReader {

    typedef IScriptEnvironment ise_t;

#ifdef _WIN32
    HMODULE dll;
#endif
    ise_t* env;
    PClip clip;

    VideoInfo viAVS;
    VSVideoInfo vi;

    int numOutputs;
    int bitDepth;

    void (*write_frame)(
        VSFrame** dst, PVideoFrame& src, int num_planes, const VSAPI* api);

    AvsReader(ise_t* env, PClip clip, int outputs, int bit_depth,
              VSCore* core, const VSAPI* api);

public:
#ifdef _WIN32
    AvsReader(HMODULE dll, ise_t* e, PClip c, int n, int bit_depth,
              VSCore* core, const VSAPI* api);
#endif

    ~AvsReader();

    const VSFrame* VS_CC getFrame(int n, VSFrameContext* ctx,
                                   VSCore* core, const VSAPI* api);

    const VSVideoInfo* getVSVideoInfo() { return &vi; }
    const int getNumOutputs() { return numOutputs; }

    /* Expose AviSynth internals for per-output frame handling */
    PVideoFrame getAvisynthFrame(int n);
    int getAvisynthPixelType() { return viAVS.pixel_type; }
    const VideoInfo& getAvisynthVideoInfo() { return viAVS; }

    /* Write function pointers usable from plugin.cpp */
    static void VS_CC writeRGB24(VSFrame** dsts, PVideoFrame& src,
                                  int num_planes, const VSAPI* api);
    static void VS_CC writeRGB32(VSFrame** dsts, PVideoFrame& src,
                                  int num_planes, const VSAPI* api);
    static void VS_CC writeYUV(VSFrame** dsts, PVideoFrame& src,
                                int num_planes, const VSAPI* api);

#ifdef _WIN32
    static AvsReader* createWin32(const char* input, int bit_depth,
                                   bool alpha, const char* mode,
                                   VSCore* core, const VSAPI* api);
#endif
    static AvsReader* create(const char* input, int bit_depth,
                              bool alpha, const char* mode,
                              VSCore* core, const VSAPI* api);
};


#endif
