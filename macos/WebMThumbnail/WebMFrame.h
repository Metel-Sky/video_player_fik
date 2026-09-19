#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Decodes the first video frame of [path] into tightly packed RGBA.
/// On success [rgba] is malloc'd; caller must fik_free_frame().
bool fik_extract_first_frame(
    const char *path,
    int max_dim,
    uint8_t **rgba,
    int *width,
    int *height
);

void fik_free_frame(uint8_t *rgba);

#ifdef __cplusplus
}
#endif
