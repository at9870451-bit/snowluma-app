//
//  ish_bridge.m
//  Runner
//
//  iSH 内嵌 Linux 沙盒桥接：
//  - 创建管道，stdin/stdout 接入 iSH（libish.a 的 ish_bridge_start_fds）
//  - 读取线程把内核输出通过回调推给 Flutter（EventChannel）
//  - writeInput 把 Flutter 输入写入 iSH stdin
//
#import "ish_bridge.h"

#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// 由 libish.a 提供（见 native/ios_bridge.c）
extern int ish_bridge_start_fds(const char *rootfs, const char *exe,
                                const char *envp, int stdin_fd, int stdout_fd);

typedef struct {
    char *rootfs;
    char *exe;
    char *envp;
    int stdin_fd;
    int stdout_fd;
} session_args_t;

@interface ISHBridge ()
@property(nonatomic) int inputWriteFd;
@property(nonatomic) int outputReadFd;
@property(nonatomic, copy) void (^outputCallback)(NSString *);
@end

@implementation ISHBridge

static ISHBridge *sharedInstance = nil;

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      sharedInstance = [[ISHBridge alloc] init];
      sharedInstance.inputWriteFd = -1;
      sharedInstance.outputReadFd = -1;
    });
    return sharedInstance;
}

static void *run_linux_thread(void *arg) {
    session_args_t *sa = (session_args_t *)arg;
    intptr_t err = (intptr_t)ish_bridge_start_fds(
        sa->rootfs, sa->exe, sa->envp, sa->stdin_fd, sa->stdout_fd);
    // 内核通常不返回；返回则关闭 fd
    if (sa->stdin_fd >= 0) close(sa->stdin_fd);
    if (sa->stdout_fd >= 0) close(sa->stdout_fd);
    free(sa->rootfs);
    free(sa->exe);
    free(sa->envp);
    free(sa);
    return (void *)err;
}

static void *output_reader_thread(void *arg) {
    ISHBridge *bridge = (__bridge_transfer ISHBridge *)arg;
    char buf[1024];
    ssize_t n;
    while ((n = read(bridge.outputReadFd, buf, sizeof(buf))) > 0) {
        NSString *text = [[NSString alloc] initWithBytes:buf
                                                  length:(NSUInteger)n
                                                encoding:NSUTF8StringEncoding];
        if (text && bridge.outputCallback) {
            bridge.outputCallback(text);
        }
    }
    return NULL;
}

@implementation ISHBridge (Shared)

+ (int)startLinuxWithRootfs:(NSString *)rootfs
                        exe:(NSString *)exe
                       envp:(NSString *)envp {
    if (rootfs.length == 0 || exe.length == 0) return -EINVAL;

    int in_pipe[2];
    int out_pipe[2];
    if (pipe(in_pipe) != 0) return -1;
    if (pipe(out_pipe) != 0) {
        close(in_pipe[0]);
        close(in_pipe[1]);
        return -1;
    }

    ISHBridge *bridge = [self sharedInstance];
    bridge.inputWriteFd = in_pipe[1];
    bridge.outputReadFd = out_pipe[0];

    session_args_t *sa = malloc(sizeof(session_args_t));
    if (!sa) {
        close(in_pipe[0]);
        close(in_pipe[1]);
        close(out_pipe[0]);
        close(out_pipe[1]);
        return -ENOMEM;
    }
    sa->rootfs = strdup(rootfs.UTF8String);
    sa->exe = strdup(exe.UTF8String);
    sa->envp = strdup((envp ?: @"").UTF8String);
    sa->stdin_fd = in_pipe[0];
    sa->stdout_fd = out_pipe[1];

    pthread_t t;
    if (pthread_create(&t, NULL, run_linux_thread, sa) != 0) {
        free(sa->rootfs);
        free(sa->exe);
        free(sa->envp);
        free(sa);
        close(in_pipe[0]);
        close(in_pipe[1]);
        close(out_pipe[0]);
        close(out_pipe[1]);
        return -1;
    }
    pthread_detach(t);

    // 启动输出读取线程（bridge 通过 __bridge_retained 保持存活）
    pthread_t rt;
    if (pthread_create(&rt, NULL, output_reader_thread,
                       (__bridge_retained void *)bridge) == 0) {
        pthread_detach(rt);
    }
    return 0;
}

+ (int)writeInput:(NSString *)text {
    ISHBridge *bridge = [self sharedInstance];
    if (bridge.inputWriteFd < 0) return -EAGAIN;
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    const char *bytes = (const char *)data.bytes;
    size_t len = data.length;
    size_t off = 0;
    while (off < len) {
        ssize_t w = write(bridge.inputWriteFd, bytes + off, len - off);
        if (w <= 0) return -1;
        off += (size_t)w;
    }
    return 0;
}

+ (void)setOutputCallback:(void (^)(NSString *))callback {
    [self sharedInstance].outputCallback = callback;
}

@end