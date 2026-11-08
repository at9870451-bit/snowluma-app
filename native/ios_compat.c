// ios_compat.c — 为 libiSHApp.a 提供缺失的 iOS 专用符号（在 iSH 构建环境编译）
// 让 Runner 能完整链接 libiSHApp.a（官方 iOS 集成层），走 linux_start_session 启动。
#include <stddef.h>
#include <string.h>
#include <netinet/in.h>

#include "kernel/fs.h"
#include "fs/real.h"
#include "fs/dev.h"
#include "fs/devices.h"
#include "app/iOSFS.h"

// ---------- iOSFS 兼容实现：挂载到宿主文件系统 ----------
const struct fs_ops iosfs = {
    .name = "iosfs",
};
const struct fs_ops iosfs_unsafe = {
    .name = "iosfs_unsafe",
};

void iosfs_init(void) {}
void iosfs_clear_all_bookmarks(void) {}

// ---------- Location 兼容（最小 dev_ops） ----------
struct dev_ops location_dev = {0};

// ---------- DNS（libresolv res_9_*） ----------
int res_9_ninit(void) { return 0; }
int res_9_getservers(void *res, void *servers, int nservers) {
    (void)res; (void)servers; (void)nservers;
    return 0;
}