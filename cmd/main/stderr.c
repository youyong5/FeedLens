#include <stdio.h>
#include <wchar.h>

#include "moonbit.h"

MOONBIT_FFI_EXPORT void feedlens_cli_write_stderr(moonbit_string_t message) {
#ifdef _WIN32
  fputws((const wchar_t *)message, stderr);
#else
  fputs((const char *)message, stderr);
#endif
  fputc('\n', stderr);
  fflush(stderr);
}
