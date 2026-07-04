/*
 * myvshelper.h
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

#ifndef MY_VAPOURSYNTH_HELPER_H
#define MY_VAPOURSYNTH_HELPER_H

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <VapourSynth4.h>

// Templated property extractor with explicit specializations for each type.
template <typename T>
T get_prop(const VSAPI*, const VSMap*, const char*, int, int*);

template <>
inline int
get_prop<int>(const VSAPI* api, const VSMap* in, const char* name, int idx,
              int* e)
{
    return api->mapGetIntSaturated(in, name, idx, e);
}

template <>
inline int64_t
get_prop<int64_t>(const VSAPI* api, const VSMap* in, const char* name, int idx,
                  int* e)
{
    return api->mapGetInt(in, name, idx, e);
}

template <>
inline bool
get_prop<bool>(const VSAPI* api, const VSMap* in, const char* name, int idx,
               int* e)
{
    int err = 0;
    int64_t val = api->mapGetInt(in, name, idx, &err);
    if (e)
        *e = err;
    return val != 0;
}

template <>
inline float
get_prop<float>(const VSAPI* api, const VSMap* in, const char* name, int idx,
                int* e)
{
    return api->mapGetFloatSaturated(in, name, idx, e);
}

template <>
inline double
get_prop<double>(const VSAPI* api, const VSMap* in, const char* name, int idx,
                 int* e)
{
    return api->mapGetFloat(in, name, idx, e);
}

template <>
inline const char*
get_prop<const char*>(const VSAPI* api, const VSMap* in, const char* name,
                      int idx, int* e)
{
    return api->mapGetData(in, name, idx, e);
}

// Reads `name` from the input map, falling back to `default_value` on error.
template <typename T>
static inline T get_arg(const char* name, T default_value, int index,
                        const VSMap* in, const VSAPI* api)
{
    int err = 0;
    T ret = get_prop<T>(api, in, name, index, &err);
    if (err)
        ret = default_value;
    return ret;
}

// Optimized plane-copy: byte-per-sample, handles non-contiguous strides.
template <typename T>
static inline void
bitblt(T* dstp, const ptrdiff_t dstride, const T* srcp, const ptrdiff_t sstride,
       const size_t width, const size_t height)
{
    if (height == 0)
        return;
    const size_t w = width * sizeof(T);
    if (sstride == dstride && sstride == static_cast<ptrdiff_t>(width)) {
        memcpy(dstp, srcp, w * height);
        return;
    }
    for (size_t y = 0; y < height; ++y) {
        memcpy(dstp, srcp, w);
        srcp += sstride;
        dstp += dstride;
    }
}

#endif
