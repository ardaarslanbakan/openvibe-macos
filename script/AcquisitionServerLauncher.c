#include <libgen.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char *argv[])
{
    char executable[PATH_MAX];
    if (!realpath(argv[0], executable)) return 127;

    char macosDir[PATH_MAX];
    char contentsDir[PATH_MAX];
    strncpy(macosDir, executable, sizeof(macosDir));
    macosDir[sizeof(macosDir) - 1] = '\0';
    char *lastSlash = strrchr(macosDir, '/');
    if (!lastSlash) return 127;
    *lastSlash = '\0';
    strncpy(contentsDir, macosDir, sizeof(contentsDir));
    contentsDir[sizeof(contentsDir) - 1] = '\0';
    lastSlash = strrchr(contentsDir, '/');
    if (!lastSlash) return 127;
    *lastSlash = '\0';

    char resources[PATH_MAX];
    char frameworks[PATH_MAX];
    char data[PATH_MAX];
    char server[PATH_MAX];
    snprintf(resources, sizeof(resources), "%s/Resources", contentsDir);
    snprintf(frameworks, sizeof(frameworks), "%s/Frameworks", contentsDir);
    snprintf(data, sizeof(data), "%s/share/openvibe", resources);
    snprintf(server, sizeof(server), "%s/openvibe-acquisition-server.bin", macosDir);

    setenv("OV_PATH_ROOT", resources, 1);
    setenv("OV_PATH_BIN", macosDir, 1);
    setenv("OV_PATH_LIB", frameworks, 1);
    setenv("OV_PATH_DATA", data, 1);
	argv[0] = server;
    execv(server, argv);
    perror("Unable to launch OpenViBE Acquisition Server");
    return 127;
}
