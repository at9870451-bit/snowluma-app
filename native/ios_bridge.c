// ios_bridge.c — 在 iSH 的 meson 构建环境内编译的桥接层。
// 用途：给 Flutter Runner 提供一个无需 include iSH 内部头文件的启动入口。
// 编译方式：由 CI 复制到 iSH 源码 kernel/ 目录并加入 libish 的源文件列表。
#include <errno.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

// 必须先包含这些内核头文件，xX_main_Xx.h 才能解析 current/task/exit_hook/do_execve
#include "kernel/calls.h"
#include "kernel/task.h"
#include "kernel/errno.h"
#include "kernel/fs.h"
#include "kernel/init.h"
#include "xX_main_Xx.h"

// 启动一个 Linux 会话（stdio 使用调用方提供的宿主文件描述符）：
//   rootfs:   已包含 Alpine 目录的路径（fakefs 会挂载 rootfs/data）
//   exe:      要执行的程序（如 /bin/sh）
//   envp:     以 \0 结尾的键值对字符串（可为空串）
//   stdin_fd: 宿主管道读端（iSH 从这里读输入）
//   stdout_fd:宿主管道写端（iSH 把输出写到这里）
// 返回 0 表示已进入内核主循环（通常不返回）；负值为 -errno。
int ish_bridge_start_fds(const char *rootfs, const char *exe, const char *envp,
                         int stdin_fd, int stdout_fd) {
    struct stat st;
    if (stat(rootfs, &st) != 0 || !S_ISDIR(st.st_mode)) {
        return -ENOENT;
    }

    // 把宿主管道接上 STDIN/STDOUT/STDERR：
    // create_piped_stdio() 会把宿主 fd 0/1/2 直接包装成 iSH 的 stdio。
    if (stdin_fd >= 0) {
        dup2(stdin_fd, STDIN_FILENO);
    }
    if (stdout_fd >= 0) {
        dup2(stdout_fd, STDOUT_FILENO);
        dup2(stdout_fd, STDERR_FILENO);
    }

    // 复用 xX_main_Xx 的命令行解析：ish -f <rootfs> <exe>
    char *argv[4];
    argv[0] = (char *)"ish";
    argv[1] = (char *)"-f";
    argv[2] = (char *)rootfs;
    argv[3] = (char *)exe;
    int err = xX_main_Xx(4, argv, envp);
    if (err < 0) {
        return err;
    }

    // main.c 中的后续初始化：设备节点、/proc、/dev/pts、进入主循环
    create_some_device_nodes();
    do_mount(&procfs, "proc", "/proc", "", 0);
    do_mount(&devptsfs, "devpts", "/dev/pts", "", 0);
    task_run_current();
    return 0;
}