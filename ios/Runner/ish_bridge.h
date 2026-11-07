//
//  ish_bridge.h
//  Runner
//
//  iSH 内嵌 Linux 沙盒桥接：暴露给 Flutter/原生侧的启动接口。
//
#ifndef ish_bridge_h
#define ish_bridge_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ISHBridge : NSObject

/// 在后台线程启动一个 Linux 会话。
/// rootfs: Alpine rootfs 所在目录（App Documents 内）
/// exe:    要执行的程序，如 /bin/sh
/// envp:   以 \0 结尾的键值对字符串（如 "TERM=xterm\0PATH=/bin:/usr/bin\0\0"）
/// 返回:   0 表示内核初始化成功并已启动会话（此函数通常不返回）；
///         负值表示初始化失败（-errno）。
+ (int)startLinuxWithRootfs:(NSString *)rootfs
                        exe:(NSString *)exe
                       envp:(NSString *)envp;

@end

NS_ASSUME_NONNULL_END
#endif /* ish_bridge_h */