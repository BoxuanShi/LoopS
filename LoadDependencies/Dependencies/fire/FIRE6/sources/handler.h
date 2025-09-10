/** @file handler.h
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package
 *  It contains the handler used during debugging
 *  There is no preprocessor guard, included only in main files of all 3 binaries
 *
 */

#if defined(WITH_DEBUG) || defined(DOXYGEN_DOCUMENTATION)

#include <cstdio>
#include <stdlib.h>
#include <unistd.h>
#include <execinfo.h>
#include <csignal>

/**
 * A handler for signals (program crashing)
 * @param sig the signal number
 */
void handler(int sig) {
    void *array[32];
    char **messages = nullptr;
    int size;

    // get void*'s for all entries on the stack
    size = backtrace(array, 32);

    // print out all the frames to stderr
    fprintf(stderr, "Error: signal %d:\n", sig);

    fprintf(stderr, "Quick backtrace summary\n");
    backtrace_symbols_fd(array, size, STDERR_FILENO);

    fprintf(stderr, "Detailed backtrace summary\n");
    messages = backtrace_symbols(array, size);
    /* skip first stack frame (points here) */
    printf("[bt] Execution path:\n");
    for (int i = 1; i < size; ++i) {
        printf("[bt] #%d %s\n", i, messages[i]);
        char syscom[256];
        snprintf(syscom, 256, "eu-addr2line -f -i '%p' --pid=%d\n", array[i], getpid());
        if (system(syscom)) printf("eu-addr2line provided no information for this frame \n");
    }
    signal(sig, SIG_DFL);
    raise(sig);
    abort();
    exit(2);
}

/**
 * Attaches the handler to different signals in debug mode
 */
void attach_handler() {
    signal(SIGSEGV, handler);  //install handler to print errors
    signal(SIGBUS, handler);  //bus error, significant memory problems
    signal(SIGTERM, handler);  //termination, for debugging
    signal(SIGABRT, handler);  //throwing
}

#endif
