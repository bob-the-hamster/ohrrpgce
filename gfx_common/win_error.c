// This module is linked into all OHRRPGCE utilities on Windows, and also gfx_directx.dll

#include "../config.h"
#include <windows.h>
#include <string.h>
#include <stdio.h>
#include "../os.h"


static void _TrimTrailingNewline(char *buf) {
	char *last = buf + strlen(buf) - 1;
	while (last >= buf && (*last == '\n' || *last == '\r'))
		*last-- = '\0';
}

const char *win_error_str(int errcode) {
	#define BUFLEN 256
	static char buf[BUFLEN];
        buf[0] = '\0';
	if (errcode == -1)
		errcode = GetLastError();
        if (!FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM, NULL, errcode, 0, buf, BUFLEN, NULL)) {
		snprintf(buf, BUFLEN, "error 0x%x; FormatMessage failed: error 0x%lx", errcode, GetLastError());
        }
	_TrimTrailingNewline(buf);
	return buf;
}
