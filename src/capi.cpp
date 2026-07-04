// capi.cpp — AviSynth+ bridge via dlopen/dlsym (POSIX)
// Every CPU cycle matters. Memory is a resource.
#include "capi.h"
#include <avisynth.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

// ---------------------------------------------------------------------------
// Thread-local last error
// ---------------------------------------------------------------------------
static pthread_key_t  error_key;
static pthread_once_t error_key_once = PTHREAD_ONCE_INIT;

static void make_error_key(void) { pthread_key_create(&error_key, free); }

static void set_error(const char *msg) {
    pthread_once(&error_key_once, make_error_key);
    char *copy = strdup(msg);
    pthread_setspecific(error_key, copy);
}

const char *avsr_last_error(void) {
    pthread_once(&error_key_once, make_error_key);
    return (const char *)pthread_getspecific(error_key);
}

// ---------------------------------------------------------------------------
// AVSR_Env — wraps IScriptEnvironment + PClip
// ---------------------------------------------------------------------------
struct AVSR_Env {
    IScriptEnvironment *env;
    PClip               clip;
    void               *dll;       // dlopen handle
    const AVS_Linkage  *linkage;
};

// ---------------------------------------------------------------------------
// Platform helpers
// ---------------------------------------------------------------------------
static void *load_avisynth(const char **lib_path) {
#ifdef __APPLE__
    *lib_path = "libavisynth.dylib";
#else
    *lib_path = "libavisynth.so";
#endif
    void *dll = dlopen(*lib_path, RTLD_NOW | RTLD_LOCAL);
    if (!dll) {
        set_error(dlerror());
    }
    return dll;
}

// ---------------------------------------------------------------------------
// Common: create environment + evaluate script
// ---------------------------------------------------------------------------
typedef IScriptEnvironment *(*cse_t)(int);

static AVSR_Env *create_and_eval(const char *script, const char *mode) {
    const char *lib_path = NULL;
    void *dll = load_avisynth(&lib_path);
    if (!dll) return NULL;

    cse_t create_env = (cse_t)dlsym(dll, "CreateScriptEnvironment");
    if (!create_env) {
        set_error(dlerror());
        dlclose(dll);
        return NULL;
    }

    IScriptEnvironment *env = create_env(AVISYNTH_INTERFACE_VERSION);
    if (!env) {
        set_error("failed to create avisynth script environment");
        dlclose(dll);
        return NULL;
    }

    const AVS_Linkage *linkage = env->GetAVSLinkage();
    ((void)linkage); // stored for future use

    AVSValue res;
    try {
        res = env->Invoke(mode, AVSValue(script));
    } catch (AvisynthError &e) {
        set_error(e.msg);
        env->DeleteScriptEnvironment();
        dlclose(dll);
        return NULL;
    } catch (...) {
        set_error("uncaught AviSynth exception");
        env->DeleteScriptEnvironment();
        dlclose(dll);
        return NULL;
    }

    if (!res.IsClip()) {
        set_error("script did not return a clip");
        env->DeleteScriptEnvironment();
        dlclose(dll);
        return NULL;
    }

    PClip clip = res.AsClip();
    const VideoInfo &vi = clip->GetVideoInfo();
    if (!vi.HasVideo()) {
        set_error("clip has no video");
        env->DeleteScriptEnvironment();
        dlclose(dll);
        return NULL;
    }

    AVSR_Env *e = (AVSR_Env *)calloc(1, sizeof(AVSR_Env));
    if (!e) {
        set_error("allocation failed");
        env->DeleteScriptEnvironment();
        dlclose(dll);
        return NULL;
    }

    e->env     = env;
    e->clip    = clip;
    e->dll     = dll;
    e->linkage = linkage;
    return e;
}

AVSR_Env *avsr_import(const char *path) {
    return create_and_eval(path, "Import");
}

AVSR_Env *avsr_eval(const char *lines) {
    return create_and_eval(lines, "Eval");
}

// ---------------------------------------------------------------------------
// Video info
// ---------------------------------------------------------------------------
int avsr_get_info(AVSR_Env *e, AVSR_VideoInfo *vi) {
    if (!e || !vi) return -1;
    const VideoInfo &avi = e->clip->GetVideoInfo();

    vi->width      = avi.width;
    vi->height     = avi.height;
    vi->num_frames = avi.num_frames;
    vi->fps_num    = avi.fps_numerator;
    vi->fps_den    = avi.fps_denominator;
    vi->pixel_type = avi.pixel_type;
    vi->has_alpha  = avi.IsRGB32() ? 1 : 0;

    if (avi.IsRGB32()) {
        vi->num_planes = 3;       // RGB planes only (alpha separate)
    } else if (avi.IsRGB24()) {
        vi->num_planes = 3;
    } else if (avi.IsY8()) {
        vi->num_planes = 1;
    } else {
        vi->num_planes = 3;       // YUV
    }

    vi->bits_per_sample = 8;
    return 0;
}

// ---------------------------------------------------------------------------
// Frame fetch — fills plane pointers
// ---------------------------------------------------------------------------
static const int avs_plane_y = 0; // PLANAR_Y in avisynth.h

int avsr_get_frame(AVSR_Env *e, int n, AVSR_FramePlanes *fp) {
    if (!e || !fp) return -1;
    const VideoInfo &vi = e->clip->GetVideoInfo();
    if (n < 0 || n >= vi.num_frames) return -1;

    PVideoFrame f;
    try {
        f = e->clip->GetFrame(n, e->env);
    } catch (AvisynthError &err) {
        set_error(err.msg);
        return -1;
    } catch (...) {
        set_error("frame fetch failed");
        return -1;
    }

    if (vi.IsRGB32() || vi.IsRGB24()) {
        // Interleaved BGR(A) — single plane, Zig handles deinterleave
        fp->read_ptr[0] = f->GetReadPtr();
        fp->pitch[0]     = f->GetPitch();
        fp->row_size[0]  = f->GetRowSize();
        fp->height[0]    = f->GetHeight();
        fp->read_ptr[1]  = NULL;
        fp->read_ptr[2]  = NULL;
        fp->read_ptr[3]  = NULL;
    } else if (vi.IsY8()) {
        fp->read_ptr[0] = f->GetReadPtr();
        fp->pitch[0]     = f->GetPitch();
        fp->row_size[0]  = f->GetRowSize();
        fp->height[0]    = f->GetHeight();
    } else {
        // YUV planar: Y, U, V
        fp->read_ptr[0] = f->GetReadPtr(PLANAR_Y);
        fp->pitch[0]     = f->GetPitch(PLANAR_Y);
        fp->row_size[0]  = f->GetRowSize(PLANAR_Y);
        fp->height[0]    = f->GetHeight(PLANAR_Y);

        fp->read_ptr[1] = f->GetReadPtr(PLANAR_U);
        fp->pitch[1]     = f->GetPitch(PLANAR_U);
        fp->row_size[1]  = f->GetRowSize(PLANAR_U);
        fp->height[1]    = f->GetHeight(PLANAR_U);

        fp->read_ptr[2] = f->GetReadPtr(PLANAR_V);
        fp->pitch[2]     = f->GetPitch(PLANAR_V);
        fp->row_size[2]  = f->GetRowSize(PLANAR_V);
        fp->height[2]    = f->GetHeight(PLANAR_V);
    }
    return 0;
}

// ---------------------------------------------------------------------------
// Format resolution — mirrors the old AvsReader.cpp get_vs_video_format
// ---------------------------------------------------------------------------
int avsr_get_vs_format(int pixel_type, int *color_family, int *subW, int *subH) {
    static const struct {
        uint64_t avsType;
        int      cf;   // 1=Gray, 2=RGB, 3=YUV
        int      sw;
        int      sh;
    } table[] = {
        { static_cast<uint64_t>(VideoInfo::CS_BGR32), 2, 0, 0 },
        { static_cast<uint64_t>(VideoInfo::CS_BGR24), 2, 0, 0 },
        { static_cast<uint64_t>(VideoInfo::CS_YV24),  3, 0, 0 },
        { static_cast<uint64_t>(VideoInfo::CS_YV16),  3, 1, 0 },
        { static_cast<uint64_t>(VideoInfo::CS_YV411), 3, 2, 0 },
        { static_cast<uint64_t>(VideoInfo::CS_I420),  3, 1, 1 },
        { static_cast<uint64_t>(VideoInfo::CS_YV12),  3, 1, 1 },
        { static_cast<uint64_t>(VideoInfo::CS_Y8),    1, 0, 0 },
        { 0, 0, 0, 0 },
    };

    uint64_t pix = static_cast<uint64_t>(pixel_type);
    for (int i = 0; table[i].avsType != 0; ++i) {
        if (table[i].avsType == pix) {
            *color_family = table[i].cf;
            *subW = table[i].sw;
            *subH = table[i].sh;
            return 0;
        }
    }
    return -1;
}

// ---------------------------------------------------------------------------
// Cleanup
// ---------------------------------------------------------------------------
void avsr_close(AVSR_Env *e) {
    if (!e) return;
    if (e->clip)  e->clip  = NULL;
    if (e->env) {
        e->env->DeleteScriptEnvironment();
        e->env = NULL;
    }
    if (e->dll) {
        dlclose(e->dll);
        e->dll = NULL;
    }
    free(e);
}
