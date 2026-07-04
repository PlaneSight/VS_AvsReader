/*
 * plugin.cpp
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

#include "AvsReader.h"
#include "myvshelper.h"
#include <new>
#include <string>

// Shared reader refcount. Each output node increments this; the last free
// deletes the underlying AvsReader.
int g_readerRefCount = 0;

// VS4 filter get_frame callback. Dispatches to the per-output writer stored
// in AvsReaderOutput.
static const VSFrame* VS_CC
get_frame(int n, int activationReason, void* instanceData,
          void** frameData, VSFrameContext* frameCtx,
          VSCore* core, const VSAPI* api)
{
    (void) frameData;

    if (activationReason != arInitial)
        return nullptr;

    auto* out = static_cast<AvsReaderOutput*>(instanceData);
    AvsReader* reader = out->reader;
    const VSVideoInfo& ovi = out->vi;

    const VSVideoInfo* rvi = reader->getVSVideoInfo();
    n = std::min(std::max(n, 0), rvi->numFrames - 1);

    VSFrame* dst = api->newVideoFrame(&ovi.format, ovi.width, ovi.height,
                                       nullptr, core);

    VSMap* props = api->getFramePropertiesRW(dst);
    api->mapSetInt(props, "_DurationNum", rvi->fpsDen, maReplace);
    api->mapSetInt(props, "_DurationDen", rvi->fpsNum, maReplace);

    try {
        PVideoFrame src = reader->getAvisynthFrame(n);
        VSFrame* dsts[2] = { dst, nullptr };
        out->write_frame(dsts, src, ovi.format.numPlanes, api);
        return dst;
    } catch (const AvisynthError& e) {
        api->freeFrame(dst);
        api->setFilterError((std::string("AviSynth: ") + e.msg).c_str(), frameCtx);
    } catch (const std::string& e) {
        api->freeFrame(dst);
        api->setFilterError((std::string("AviSynth: ") + e).c_str(), frameCtx);
    } catch (...) {
        api->freeFrame(dst);
        api->setFilterError("AviSynth: unknown frame error", frameCtx);
    }
    return nullptr;
}

// Frees an AvsReaderOutput and its shared reader when the last output dies.
static void VS_CC
free_filter(void* instanceData, VSCore* core, const VSAPI* api)
{
    (void) core;
    (void) api;
    auto* out = static_cast<AvsReaderOutput*>(instanceData);
    if (--g_readerRefCount <= 0)
        delete out->reader;
    delete out;
}

// Extracts the alpha channel from an RGB32 AviSynth frame as Gray8.
static void VS_CC
write_alpha(VSFrame** dsts, PVideoFrame& src, int, const VSAPI* api) noexcept
{
    VSFrame* dst = dsts[0];
    const ptrdiff_t spitch = src->GetPitch();
    const ptrdiff_t dstride = api->getStride(dst, 0);
    const int width = src->GetRowSize() / 4;
    const int height = src->GetHeight();
    const uint8_t* srcp = src->GetReadPtr() + spitch * (height - 1);
    uint8_t* dstp = api->getWritePtr(dst, 0);

    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x)
            dstp[x] = srcp[4 * x + 3];
        srcp -= spitch;
        dstp += dstride;
    }
}

// Called by both Import and Eval. Reads arguments, creates the AvsReader,
// then registers one or two filter nodes.
static void VS_CC
create_avsr(const VSMap* in, VSMap* out, void* userData,
            VSCore* core, const VSAPI* api)
{
    const char* mode = static_cast<const char*>(userData);

    int bd = get_arg("bitdepth", 8, 0, in, api);
    const char* input = get_arg(
        mode[0] == 'E' ? "lines" : "script", "", 0, in, api);
    bool alpha = get_arg("alpha", true, 0, in, api);

    try {
        if (bd != 8 && bd != 9 && bd != 10 && bd != 16)
            throw std::string("invalid bitdepth was specified.");
        if (std::strlen(input) < 1)
            throw std::string("zero length avs.");

#ifdef _WIN32
        AvsReader* reader = AvsReader::createWin32(
            input, bd, alpha, mode, core, api);
#elif defined(_POSIX) && defined(HAVE_AVISYNTH)
        AvsReader* reader = AvsReader::createPosix(
            input, bd, alpha, mode, core, api);
#else
        AvsReader* reader = AvsReader::create(
            input, bd, alpha, mode, core, api);
#endif

        if (!reader)
            throw std::string("failed to create AvsReader instance.");

        const VSVideoInfo* rvi = reader->getVSVideoInfo();
        int numOutputs = reader->getNumOutputs();
        g_readerRefCount = 0;

        // Register the base output node.
        {
            auto* od = new (std::nothrow) AvsReaderOutput();
            if (!od)
                throw std::string("memory allocation failed.");
            od->reader = reader;
            od->outputIndex = 0;
            od->vi = *rvi;
            g_readerRefCount++;

            int avsPixelType = reader->getAvisynthPixelType();
            if (avsPixelType == VideoInfo::CS_BGR32)
                od->write_frame = AvsReader::writeRGB32;
            else if (avsPixelType == VideoInfo::CS_BGR24)
                od->write_frame = AvsReader::writeRGB24;
            else
                od->write_frame = AvsReader::writeYUV;

            api->createVideoFilter(
                out, numOutputs > 1 ? "Import" : mode,
                &od->vi, get_frame, free_filter,
                fmUnordered, nullptr, 0, od, core);
        }

        // Register the alpha output node when RGB32 with alpha enabled.
        if (numOutputs > 1) {
            auto* od = new (std::nothrow) AvsReaderOutput();
            if (!od)
                throw std::string("memory allocation failed.");
            od->reader = reader;
            od->outputIndex = 1;
            od->vi = *rvi;

            VSVideoFormat grayFmt{};
            api->queryVideoFormat(&grayFmt, cfGray, stInteger, 8, 0, 0, core);
            od->vi.format = grayFmt;
            od->write_frame = write_alpha;
            g_readerRefCount++;

            api->createVideoFilter(
                out, "Import_Alpha",
                &od->vi, get_frame, free_filter,
                fmUnordered, nullptr, 0, od, core);
        }

    } catch (std::string& e) {
        auto msg = std::string(mode) + ": " + e;
        api->mapSetError(out, msg.c_str());
    }
}

// Plugin entry point for VapourSynth API v4. Registers Import and Eval.
VS_EXTERNAL_API(void) VapourSynthPluginInit2(
    VSPlugin* plugin, const VSPLUGINAPI* vspapi)
{
    vspapi->configPlugin(
        "chikuzen.does.not.have.his.own.domain.avsr",
        "avsr",
        "AviSynth Script Reader for VapourSynth v" VSAVSREADER_VERSION,
        VS_MAKE_VERSION(2, 0),
        VAPOURSYNTH_API_VERSION,
        0,
        plugin);

    vspapi->registerFunction(
        "Import",
        "script:data;bitdepth:int:opt;alpha:int:opt;",
        "clip:vnode;",
        create_avsr,
        const_cast<char*>("Import"),
        plugin);

    vspapi->registerFunction(
        "Eval",
        "lines:data;bitdepth:int:opt;alpha:int:opt;",
        "clip:vnode;",
        create_avsr,
        const_cast<char*>("Eval"),
        plugin);
}
