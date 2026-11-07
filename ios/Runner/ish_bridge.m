//
//  ish_bridge.m
//  Runner
//
//  iSH 内嵌 Linux 沙盒桥接：调用 libish.a 里编译好的 ish_bridge_start。
//  （ish_bridge_start 在 iSH 的 meson 构建环境内编译，无需在此 include 内核头文件）
//
#import "ish_bridge.h"

#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// 由 libish.a 提供（见 native/ios_bridge.c）
extern int ish_bridge_start(const char *rootfs, const char *exe,
                            const char *envp);

typedef struct {
    char *rootfs;
    char *exe;
    char *envp;
} session_args_t;

static void *run_linux_thread(void *arg) {
    session_args_t *sa = (session_args_t *)arg;
    intptr_t err = (intptr_t)ish_bridge_start(sa->rootfs, sa->exe, sa->envp);
    free(sa->rootfs);
    free(sa->exe);
    free(sa->envp);
    free(sa);
    return (void *)err;
}

@implementation ISHBridge

+ (int)startLinuxWithRootfs:(NSString *)rootfs
                        exe:(NSString *)exe
                       envp:(NSString *)envp {
    if (rootfs.length == 0 || exe.length == 0) return -EINVAL;
    session_args_t *sa = malloc(sizeof(session_args_t));
    if (!sa) return -ENOMEM;
    sa->rootfs = strdup(rootfs.UTF8String);
    sa->exe = strdup(exe.UTF8String);
    sa->envp = strdup((envp ?: @"").UTF8String);
    pthread_t t;
    if (pthread_create(&t, NULL, run_linux_thread, sa) != 0) {
        free(sa->rootfs);
        free(sa->exe);
        free(sa->envp);
        free(sa);
        return -1;
    }
    pthread_detach(t);
    return 0;
}

@end