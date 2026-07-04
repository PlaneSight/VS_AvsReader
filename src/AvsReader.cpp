/*
 * AvsReader.cpp
 *
 * This file is a part of VS_AvsReader
 *
 * Copyright (C) 2016  Oka Motofumi
 * Copyright (C) 2026  PlaneSight
 *
 * Author: Oka Motofumi (chikuzen.mo at gmail dot com)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with Libav; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#include <cstdint>
#include <algorithm>
#include <vector>
#include "AvsReader.h"
#include "myvshelper.h"
#ifdef _POSIX
#include <dlfcn.h>
#endif

const AVS_Linkage* AVS_linkage = nullptr;

#ifdef _WIN32
// Converts a UTF-8 string to the thread's active ANSI code page. Needed
// because AviSynth's script environment expects ANSI paths on Windows.
static void convert_utf8_to_ansi(const char* utf8, std::vector<char>& ansi)
{
    int length = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, NULL, 0);
    std::vector<wchar_t> wchar(static_cast<size_t>(length));
    MultiByteToWideChar(CP_UTF8, 0, utf8, -1, wchar.data(), length);

    length = WideCharToMultiByte(CP_THREAD_ACP, 0, wchar.data(), -1,
                                 nullptr, 0, 0, 0);
    ansi.resize(static_cast<size_t>(length));
    WideCharToMultiByte(CP_THREAD_ACP, 0, wchar.data(), -1,
                        ansi.data(), length, 0, 0);
}
#endif

// Resolves an AviSynth pixel type enum + bitdepth to a VSVideoFormat via
// queryVideoFormat. Returns non-zero on success.
static int
get_vs_video_format(VSVideoFormat* fmt, int pixel_type, int bitdepth,
                     VSCore* core, const VSAPI* api)
{
    static const struct {
        uint64_t avsType;
        int colorFamily;
        int subW;
        int subH;
    } table[] = {
        { static_cast<uint64_t>(VideoInfo::CS_BGR32), cfRGB, 0, 0 },
        { static_cast<uint64_t>(VideoInfo::CS_BGR24), cfRGB, 0, 0 },
        { static_cast<uint64_t>(VideoInfo::CS_YV24),  cfYUV, 0, 0 },
        { static_cast<uint64_t>(VideoInfo::CS_YV16),  cfYUV, 1, 0 },
        { static_cast<uint64_t>(VideoInfo::CS_YV411), cfYUV, 2, 0 },
        { static_cast<uint64_t>(VideoInfo::CS_I420),  cfYUV, 1, 1 },
        { static_cast<uint64_t>(VideoInfo::CS_YV12),  cfYUV, 1, 1 },
        { static_cast<uint64_t>(VideoInfo::CS_Y8),    cfGray, 0, 0 },
        { 0, 0, 0, 0 },
    };

    auto pix = static_cast<uint64_t>(pixel_type);
    for (int i = 0; table[i].avsType != 0; ++i) {
        if (table[i].avsType == pix)
            return api->queryVideoFormat(fmt, table[i].colorFamily,
                                         stInteger, bitdepth,
                                         table[i].subW, table[i].subH, core);
    }
    return 0;
}

// Writes BGR[A] interleaved AviSynth data to planar RGB[A] VS frames.
template <bool ALPHA, int CHANNELS>
static void VS_CC
write_rgb(VSFrame** dsts, PVideoFrame& src, int, const VSAPI* api) noexcept
{
    VSFrame* dst = dsts[0];
    const ptrdiff_t spitch = src->GetPitch();
    const ptrdiff_t dstride = api->getStride(dst, 0);
    const int width = src->GetRowSize() / CHANNELS;
    const int height = src->GetHeight();
    const uint8_t* srcp = src->GetReadPtr() + spitch * (height - 1);

    uint8_t* dstpr = api->getWritePtr(dst, 0);
    uint8_t* dstpg = api->getWritePtr(dst, 1);
    uint8_t* dstpb = api->getWritePtr(dst, 2);
    uint8_t* dstpa = ALPHA ? api->getWritePtr(dsts[1], 0) : nullptr;

    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            dstpb[x] = srcp[CHANNELS * x + 0];
            dstpg[x] = srcp[CHANNELS * x + 1];
            dstpr[x] = srcp[CHANNELS * x + 2];
            if (ALPHA)
                dstpa[x] = srcp[4 * x + 3];
        }
        srcp -= spitch;
        dstpr += dstride;
        dstpg += dstride;
        dstpb += dstride;
        if (ALPHA)
            dstpa += dstride;
    }
}

// Copies YUV planar data from an AviSynth frame to a VS frame.
static void VS_CC
write_yuv(VSFrame** dsts, PVideoFrame& src, int num_planes,
          const VSAPI* api) noexcept
{
    static const int planes[] = { PLANAR_Y, PLANAR_U, PLANAR_V };
    VSFrame* dst = dsts[0];
    for (int i = 0; i < num_planes; ++i) {
        int plane = planes[i];
        bitblt(api->getWritePtr(dst, i), api->getStride(dst, i),
               src->GetReadPtr(plane), src->GetPitch(plane),
               static_cast<size_t>(src->GetRowSize(plane)),
               static_cast<size_t>(src->GetHeight(plane)));
    }
}

#ifdef _WIN32
AvsReader::AvsReader(HMODULE d, ise_t* e, PClip c, int n, int bit_depth,
                     VSCore* core, const VSAPI* api) :
    dll(d), env(e), clip(c), numOutputs(n), bitDepth(bit_depth), vi{}
{
    viAVS = clip->GetVideoInfo();

    // Resolve the VSVideoFormat from the AviSynth pixel type and bitdepth.
    VSVideoFormat fmt{};
    get_vs_video_format(&fmt, viAVS.pixel_type, bit_depth, core, api);
    vi.format = fmt;
    vi.fpsNum = viAVS.fps_numerator;
    vi.fpsDen = viAVS.fps_denominator;
    vi.width = bit_depth > 8 ? viAVS.width / 2 : viAVS.width;
    vi.height = viAVS.height;
    vi.numFrames = viAVS.num_frames;

    if (viAVS.IsRGB32()) {
        write_frame = write_rgb<true, 4>;
    } else if (viAVS.IsRGB24()) {
        write_frame = write_rgb<false, 3>;
    } else {
        write_frame = write_yuv;
    }
}
#endif

AvsReader::AvsReader(ise_t* e, PClip c, int n, int bit_depth,
                     VSCore* core, const VSAPI* api) :
    env(e), clip(c), numOutputs(n), bitDepth(bit_depth), vi{}
{
#ifdef _WIN32
    dll = nullptr;
#endif
#ifdef _POSIX
    dll = nullptr;
#endif
    viAVS = clip->GetVideoInfo();

    VSVideoFormat fmt{};
    get_vs_video_format(&fmt, viAVS.pixel_type, bit_depth, core, api);
    vi.format = fmt;
    vi.fpsNum = viAVS.fps_numerator;
    vi.fpsDen = viAVS.fps_denominator;
    vi.width = bit_depth > 8 ? viAVS.width / 2 : viAVS.width;
    vi.height = viAVS.height;
    vi.numFrames = viAVS.num_frames;

    if (viAVS.IsRGB32()) {
        write_frame = write_rgb<true, 4>;
    } else if (viAVS.IsRGB24()) {
        write_frame = write_rgb<false, 3>;
    } else {
        write_frame = write_yuv;
    }
}

AvsReader::~AvsReader()
{
    AVS_linkage = nullptr;
    if (env) {
        env->DeleteScriptEnvironment();
        env = nullptr;
    }
#ifdef _WIN32
    if (dll) {
        FreeLibrary(dll);
        dll = nullptr;
    }
#endif
#ifdef _POSIX
    if (dll) {
        dlclose(dll);
        dll = nullptr;
    }
#endif
}

const VSFrame* VS_CC AvsReader::getFrame(int n, VSFrameContext* ctx,
                                          VSCore* core, const VSAPI* api)
{
    (void) ctx;
    n = std::min(std::max(n, 0), viAVS.num_frames - 1);

    VSFrame* dst = api->newVideoFrame(&vi.format, vi.width, vi.height,
                                       nullptr, core);

    VSMap* props = api->getFramePropertiesRW(dst);
    api->mapSetInt(props, "_DurationNum", viAVS.fps_denominator, maReplace);
    api->mapSetInt(props, "_DurationDen", viAVS.fps_numerator, maReplace);

    PVideoFrame src = clip->GetFrame(n, env);
    VSFrame* dsts[2] = { dst, nullptr };
    write_frame(dsts, src, vi.format.numPlanes, api);
    return dst;
}

PVideoFrame AvsReader::getAvisynthFrame(int n)
{
    n = std::min(std::max(n, 0), viAVS.num_frames - 1);
    return clip->GetFrame(n, env);
}

// POSIX factory: dlopen libavisynth at runtime.
#ifdef _POSIX
AvsReader* AvsReader::createPosix(const char* input, int bit_depth,
                                   bool alpha, const char* mode,
                                   VSCore* core, const VSAPI* api)
{
    typedef ise_t* (*cse_t)(int);

    void* dll = nullptr;
    ise_t* env = nullptr;
    std::string libPath;

    try {
#ifdef __APPLE__
        libPath = "libavisynth.dylib";
#else
        libPath = "libavisynth.so";
#endif

#ifdef AVISYNTH_LIB_DIR
        {
            std::string fullPath = std::string(AVISYNTH_LIB_DIR) + "/" + libPath;
            dll = dlopen(fullPath.c_str(), RTLD_NOW | RTLD_LOCAL);
        }
#endif
        if (!dll)
            dll = dlopen(libPath.c_str(), RTLD_NOW | RTLD_LOCAL);

        if (!dll)
            validate(true, ("failed to load libavisynth: " + std::string(dlerror())).c_str());

        auto* create_env = reinterpret_cast<cse_t>(
            dlsym(dll, "CreateScriptEnvironment"));
        if (!create_env)
            validate(true, ("failed to find CreateScriptEnvironment: " +
                     std::string(dlerror())).c_str());

        env = create_env(AVISYNTH_INTERFACE_VERSION);
        validate(!env, "failed to create avisynth script environment.");
        AVS_linkage = env->GetAVSLinkage();

        // On POSIX, AviSynth+ paths are UTF-8 native; no ANSI conversion.
        AVSValue res = env->Invoke(mode, AVSValue(input));
        validate(!res.IsClip(), "failed to evaluate avs clip.");

        PClip clip = res.AsClip();
        const VideoInfo& vi = clip->GetVideoInfo();
        validate(!vi.HasVideo(), "avs clip has no video.");

        if (bit_depth > 8)
            validate(!vi.IsPlanar() || vi.IsYV411() || (vi.width & 1)
                     || (vi.IsY8() && bit_depth != 16)
                     || ((vi.IsYV16() || vi.IsYV12()) && (vi.width & 3)),
                     "invalid bitdepth or resolution");

        if (vi.IsYUY2())
            clip = env->Invoke("ConvertToYV16", clip).AsClip();

        int outputs = vi.IsRGB32() && alpha ? 2 : 1;
        return new AvsReader(env, clip, outputs, bit_depth, core, api);

    } catch (std::string&) {
        AVS_linkage = nullptr;
        if (env) env->DeleteScriptEnvironment();
        if (dll) dlclose(dll);
        throw;
    } catch (AvisynthError e) {
        auto msg = std::string(e.msg);
        AVS_linkage = nullptr;
        env->DeleteScriptEnvironment();
        dlclose(dll);
        throw msg;
    } catch (...) {
        AVS_linkage = nullptr;
        if (env) env->DeleteScriptEnvironment();
        if (dll) dlclose(dll);
        throw std::string("uncaught AviSynth exception");
    }
    return nullptr;
}
#endif

// Portable factory. Requires AviSynth+ to be linked externally.
AvsReader* AvsReader::create(const char* input, int bit_depth,
                              bool alpha, const char* mode,
                              VSCore* core, const VSAPI* api)
{
    (void) core;
    (void) api;
    (void) input;
    (void) bit_depth;
    (void) alpha;
    (void) mode;
    validate(true, "portable create() not yet implemented; use createWin32 on Windows");
    return nullptr;
}

#ifdef _WIN32
// Win32 factory: dynamically loads avisynth.dll, creates a script environment,
// evaluates the AviSynth code, and wraps the resulting clip.
AvsReader* AvsReader::createWin32(const char* input, int bit_depth,
                                   bool alpha, const char* mode,
                                   VSCore* core, const VSAPI* api)
{
    typedef ise_t* (__stdcall *cse_t)(int);

    HMODULE dll = nullptr;
    ise_t* env = nullptr;

    try {
        dll = LoadLibrary("avisynth");
        validate(!dll, "failed to load avisynth.dll");

        cse_t create_env = reinterpret_cast<cse_t>(
            GetProcAddress(dll, "CreateScriptEnvironment"));
        validate(!create_env, "failed to load CreateScriptEnvironment().");

        env = create_env(AVISYNTH_INTERFACE_VERSION);
        validate(!env, "failed to create avisynth script environment.");
        AVS_linkage = env->GetAVSLinkage();

        std::vector<char> ansi;
        convert_utf8_to_ansi(input, ansi);
        AVSValue res = env->Invoke(mode, AVSValue(ansi.data()));
        validate(!res.IsClip(), "failed to evaluate avs clip.");

        PClip clip = res.AsClip();
        const VideoInfo& vi = clip->GetVideoInfo();
        validate(!vi.HasVideo(), "avs clip has no video.");

        if (bit_depth > 8)
            validate(!vi.IsPlanar() || vi.IsYV411() || (vi.width & 1)
                     || (vi.IsY8() && bit_depth != 16)
                     || ((vi.IsYV16() || vi.IsYV12()) && (vi.width & 3)),
                     "invalid bitdepth or resolution");

        if (vi.IsYUY2())
            clip = env->Invoke("ConvertToYV16", clip).AsClip();

        int outputs = vi.IsRGB32() && alpha ? 2 : 1;
        return new AvsReader(dll, env, clip, outputs, bit_depth, core, api);

    } catch (std::string e) {
        AVS_linkage = nullptr;
        if (env) env->DeleteScriptEnvironment();
        if (dll) FreeLibrary(dll);
        throw e;
    } catch (AvisynthError e) {
        auto msg = std::string(e.msg);
        AVS_linkage = nullptr;
        env->DeleteScriptEnvironment();
        FreeLibrary(dll);
        throw msg;
    }
    return nullptr;
}
#endif

void VS_CC AvsReader::writeRGB24(VSFrame** dsts, PVideoFrame& src,
                                  int num_planes, const VSAPI* api)
{
    write_rgb<false, 3>(dsts, src, num_planes, api);
}

void VS_CC AvsReader::writeRGB32(VSFrame** dsts, PVideoFrame& src,
                                  int num_planes, const VSAPI* api)
{
    write_rgb<false, 4>(dsts, src, num_planes, api);
}

void VS_CC AvsReader::writeYUV(VSFrame** dsts, PVideoFrame& src,
                                int num_planes, const VSAPI* api)
{
    write_yuv(dsts, src, num_planes, api);
}
