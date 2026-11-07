//
//  ish_bridge.h
//  Runner
//
//  iSH 内嵌 Linux 沙盒桥接：管道 stdio + 输出回调。
//
#ifndef ish_bridge_h
#define ish_bridge_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ISHBridge : NSObject

/// 在后台线程启动 Linux 会话（stdio 走内部管道）。
/// 返回 0 表示启动请求成功。
+ (int)startLinuxWithRootfs:(NSString *)rootfs
                        exe:(NSString *)exe
                       envp:(NSString *)envp;

/// 向 iSH 的 stdin 写入文本（命令/输入）。
/// 返回 0 表示写入成功。
+ (int)writeInput:(NSString *)text;

/// 设置终端输出回调（iSH stdout/stderr 的文本块）。
+ (void)setOutputCallback:(void (^)(NSString *text))callback;

@end

NS_ASSUME_NONNULL_END
#endif /* ish_bridge_h */