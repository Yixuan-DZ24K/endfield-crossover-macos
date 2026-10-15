/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Yixuan Zhang
 */
#include <dispatch/dispatch.h>
#include <crt_externs.h>
#include <dlfcn.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Keep this native-Wine startup bootstrap free of Objective-C classes/framework references.
   AppKit must not be initialized under Wine's worker-thread loader lock. */
__attribute__((constructor)) static void load_endfield_compatibility(void)
{
    const char *enabled = getenv("ENDFIELD_NOTCH_SAFE");
    if (!enabled || strcmp(enabled, "1")) return;
    int game = 0, argc = *_NSGetArgc();
    char **argv = *_NSGetArgv();
    const char *preloader_name = getenv("WINEPRELOADERAPPNAME");
    if (preloader_name && (!strcasecmp(preloader_name, "Endfield") || !strcasecmp(preloader_name, "Endfield.exe"))) game = 1;
    for (int i = 0; i < argc && i < 8; i++)
    {
        const char *name = argv[i], *slash;
        if ((slash = strrchr(name, '/'))) name = slash + 1;
        if ((slash = strrchr(name, '\\'))) name = slash + 1;
        if (!strcasecmp(name, "Endfield.exe")) game = 1;
    }
    if (!game) {
        fprintf(stderr, "[EndfieldNotch] renderer loaded; window changes inactive in this non-game process\n");
        return;
    }
    fprintf(stderr, "[EndfieldNotch] Endfield process selected; scheduling compatibility on the main thread\n");
    Dl_info image;
    if (!dladdr((void *)load_endfield_compatibility, &image)) return;
    char path[PATH_MAX];
    if (strlcpy(path, image.dli_fname, sizeof(path)) >= sizeof(path)) return;
    char *slash = strrchr(path, '/');
    if (!slash) return;
    *slash = '\0';
    if (strlcat(path, "/EndfieldNotch.dylib", sizeof(path)) >= sizeof(path)) return;
    char *owned = strdup(path);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!dlopen(owned, RTLD_NOW | RTLD_LOCAL))
            fprintf(stderr, "[EndfieldNotch] main-thread compatibility load failed: %s\n", dlerror());
        free(owned);
    });
}
