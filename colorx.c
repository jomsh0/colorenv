#include <stdio.h>
#include <string.h>
#include "colorx.h"

const float MAX_RGB=255;
const float MAX_HSL=100;
int isDebug=0;

int rgb_op(const char prop, float inc, float r, float g, float b) {
    isDebug && fprintf(stderr, "[input]: rgb:%.2f,%.2f,%.2f\n", r, g, b);
    inc *= MAX_RGB/100;
    switch (prop) {
        case 'R': r = MAX(0, MIN(r + inc, MAX_RGB)); break;
        case 'G': g = MAX(0, MIN(g + inc, MAX_RGB)); break;
        case 'B': b = MAX(0, MIN(b + inc, MAX_RGB)); break;
    }
    printf("%02x%02x%02x\n", (int)r, (int)g, (int)b);
    return 0;
}

int hsl_op(const char prop, float inc, float h, float s, float l) {
    isDebug && fprintf(stderr, "[input]: hsl:%.2f,%.2f,%.2f\n", h, s, l);
    switch (prop) {
        case 'H': h += inc; h = (h > MAX_HSL) ? h - MAX_HSL : h; h = (h < 0) ? MAX_HSL + h : h; break;
        case 'S': s = MAX(0, MIN(s + inc, MAX_HSL)); break;
        case 'L': l = MAX(0, MIN(l + inc, MAX_HSL)); break;
    }
    RGB res = hsl2rgb(h/MAX_HSL, s/MAX_HSL, l/MAX_HSL);
    printf("%02x%02x%02x\n", (int)res.r, (int)res.g, (int)res.b);
    return 0;
}

int main(int argc, char* const argv[]) {
    int r=0, inc, x1, x2, x3;
    int in_isHsl = 0, req_isHsl = 0;
    float v1, v2, v3;
    char prop[2], type[4];

    if (argc <= 1) {
        return 1;
    }
    if (2 != sscanf(argv[1], "%1[HSLRGB]%d", prop, &inc)) {
        return 1;
    }
    switch (*prop) {
        case 'H':
        case 'S': 
        case 'L': req_isHsl = 1; break;
        case 'R': 
        case 'G': 
        case 'B': break;
         default: return 1;
    }

    for (int i=2; i < argc; i++)
    {
        if (4 == sscanf(argv[i], "%3s:%f,%f,%f", type, &v1, &v2, &v3))
        {
            if      (!strcasecmp(type, "rgb")) { in_isHsl = 0; }
            else if (!strcasecmp(type, "hsl")) { in_isHsl = 1; }
            else { goto err; }
        }
        else if (3 == sscanf(argv[i], "#%02x%02x%02x", &x1, &x2, &x3) ||
                 3 == sscanf(argv[i], "%02x%02x%02x", &x1, &x2, &x3))
        {
            v1 = x1;  v2 = x2;  v3 = x3;
        }
        else err:
        {
            fprintf(stderr, "[colorx error]: couldn't parse arg: %s\n", argv[i]);
            r++;
            break;
        }

        if (in_isHsl && MAX(MAX(v1, v2), v3) > 1)
        {
            v1 /= 100;  v2 /= 100;  v3 /= 100;
        }
        if (in_isHsl && !req_isHsl)
        {
            RGB trgb = hsl2rgb(v1, v2, v3);
            v1 = trgb.r;  v2 = trgb.g;  v3 = trgb.b;
        }
        if (!in_isHsl && req_isHsl)
        {
            HSL thsl = rgb2hsl(v1, v2, v3);
            v1 = thsl.h*100;  v2 = thsl.s*100;  v3 = thsl.l*100;
        }
        if (req_isHsl) { hsl_op(*prop, inc, v1, v2, v3); }
        else           { rgb_op(*prop, inc, v1, v2, v3); }
    }
    return r;
}
