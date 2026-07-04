// capi.h — C-compatible AviSynth+ bridge API for Zig @cImport
#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct AVSR_Env AVSR_Env;

typedef struct {
    int width, height, num_frames;
    int fps_num, fps_den;
    int pixel_type, num_planes, bits_per_sample, has_alpha;
} AVSR_VideoInfo;

typedef struct {
    const uint8_t *read_ptr[4];
    int             pitch[4];
    int             row_size[4];
    int             height[4];
} AVSR_FramePlanes;

AVSR_Env      *avsr_import(const char *path);
AVSR_Env      *avsr_eval(const char *lines);
int            avsr_get_info(AVSR_Env *e, AVSR_VideoInfo *vi);
int            avsr_get_vs_format(int pixel_type, int *color_family, int *subW, int *subH);
int            avsr_get_frame(AVSR_Env *e, int n, AVSR_FramePlanes *fp);
void           avsr_close(AVSR_Env *e);
const char    *avsr_last_error(void);

#ifdef __cplusplus
}
#endif
