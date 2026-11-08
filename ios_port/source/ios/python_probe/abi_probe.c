/* Standalone SDK ABI measurements. No Python or game headers are used. */
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdarg.h>
#include <wchar.h>
#include <sys/types.h>
#include <pthread.h>

/* LLVM IR records target constants without running a cross-built executable. */
#define MEASURE(name, type) \
    const uint64_t abi_sizeof_##name = (uint64_t)sizeof(type); \
    const uint64_t abi_alignof_##name = (uint64_t)_Alignof(type)

MEASURE(pointer, void *);
MEASURE(long, long);
MEASURE(long_double, long double);
MEASURE(size_t, size_t);
MEASURE(fpos_t, fpos_t);
MEASURE(off_t, off_t);
MEASURE(wchar_t, wchar_t);
MEASURE(pthread_t, pthread_t);
MEASURE(va_list, va_list);

/* This is a measurement, not a generated pyconfig.h or a runtime test. */
const uint64_t abi_char_bit = (uint64_t)__CHAR_BIT__;
