//
//  ish_bridge.m
//  Runner
//
//  iSH 内嵌 Linux 沙盒桥接实现：
//  1) 用 iSH 用户模式内核（libish.a）初始化
//  2) 挂载 fakefs rootfs（App Documents 下目录）
//  3) 启动 /bin/sh 会话（当前为后台线程，stdio 走管道）
//
#import "ish_bridge.h"

#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

// iSH 用户模式内核初始化入口（static inline，位于 xX_main_Xx.h）
// 需要 HEADER_SEARCH_PATHS 包含 $(SRCROOT)/../native/ish
#include "xX_main_Xx.h"

// libish.a 提供的符号（部分在头文件里，这里显式声明避免头文件依赖缺失）
extern void create_some_device_nodes(void);
extern int do_mount(const struct fs_ops *fs, const char *source,
                    const char *target, const char *type,
                    unsigned long flags);
extern struct fs_ops procfs;
extern struct fs_ops devptsfs;
extern void task_run_current(void);

static int run_session(const char *rootfs, const char *exe, const char *envp) {
    struct stat st;
    if (stat(rootfs, &st) != 0 || !S_ISDIR(st.st_mode)) {
        return -ENOENT;  // rootfs 目录不存在
    }

    // 复制 xX_main_Xx 的命令行用法：ish -f <rootfs> <exe>
    char *argv[4];
    argv[0] = (char *)"ish";
    argv[1] = (char *)"-f";
    argv[2] = (char *)rootfs;
    argv[3] = (char *)exe;
    int err = xX_main_Xx(4, argv, envp);
    if (err < 0) {
        return err;
    }

    // main.c 中的后续初始化（挂载 /proc、/dev/pts，进入主循环）
    create_some_device_nodes();
    do_mount(&procfs, "proc", "/proc", "", 0);
    do_mount(&devptsfs, "devpts", "/dev/pts", "", 0);
    task_run_current();  // 主循环，通常不返回
    return 0;
}

typedef struct {
    char *rootfs;
    char *exe;
    char *envp;
} session_args_t;

static void *run_linux_thread(void *arg) {
    session_args_t *sa = (session_args_t *)arg;
    intptr_t err = (intptr_t)run_session(sa->rootfs, sa->exe, sa->envp);
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