// ios_bridge.c — 在 iSH 的 meson 构建环境内编译的桥接层。
// 给 Flutter Runner 提供无需 include iSH 内部头文件的启动入口。
#include <errno.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "kernel/calls.h"
#include "kernel/task.h"
#include "kernel/errno.h"
#include "kernel/fs.h"
#include "kernel/init.h"
#include "fs/real.h"
#include "xX_main_Xx.h"

// 用 adhoc fd 包装宿主管道，挂到 iSH 的 fd 表上（不改动进程自身的 0/1/2）
static struct fd *bridge_std_fd(int fd_no) {
    struct fd *fd = adhoc_fd_create(&realfs_fdops);
    if (fd == NULL) return NULL;
    fd->real_fd = fd_no;
    fd->dir = NULL;
    return fd;
}

// 启动 Linux 会话（stdio 走调用方提供的宿主 fd）
int ish_bridge_start_fds(const char *rootfs, const char *exe, const char *envp,
                         int stdin_fd, int stdout_fd) {
    struct stat st;
    if (stat(rootfs, &st) != 0 || !S_ISDIR(st.st_mode)) {
        return -ENOENT;
    }

    char *argv[4];
    argv[0] = (char *)"ish";
    argv[1] = (char *)"-f";
    argv[2] = (char *)rootfs;
    argv[3] = (char *)exe;
    int err = xX_main_Xx(4, argv, envp);
    if (err < 0) {
        return err;
    }

    // 关键：不要 dup2 进程级 fd（会劫持整个 App 的 stdout/stderr），
    // 只替换 iSH 内 current 进程的 fd 表项。
    if (current != NULL && current->files != NULL) {
        if (stdin_fd >= 0) {
            struct fd *f = bridge_std_fd(stdin_fd);
            if (f != NULL) current->files->files[0] = f;
        }
        if (stdout_fd >= 0) {
            struct fd *f1 = bridge_std_fd(stdout_fd);
            if (f1 != NULL) current->files->files[1] = f1;
            struct fd *f2 = bridge_std_fd(stdout_fd);
            if (f2 != NULL) current->files->files[2] = f2;
        }
    }

    create_some_device_nodes();
    do_mount(&procfs, "proc", "/proc", "", 0);
    do_mount(&devptsfs, "devpts", "/dev/pts", "", 0);
    task_run_current();
    return 0;
}
