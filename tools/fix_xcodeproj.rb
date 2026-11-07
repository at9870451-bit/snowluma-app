#!/usr/bin/env ruby
# 向 Runner 工程注入 Rust 静态库链接设置（绕过 pods 配置链的不确定性）
require 'xcodeproj'

project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

lib_flags = '$(inherited) -force_load "$(SRCROOT)/../native/libs/ios/libsnowluma_core.a"'

# iSH（内嵌 Linux 沙盒）静态库：先只链接纯 C 内核（libiSHApp 依赖 iOS App 专用符号，桥接另行处理）
ish_libs = %w[libish.a libish_emu.a libfakefs.a]
ish_flags = ish_libs.map { |l| "-force_load \"$(SRCROOT)/../native/libs/ios/#{l}\"" }.join(' ')
lib_flags = "#{lib_flags} #{ish_flags} -lsqlite3"

target = project.targets.find { |t| t.name == 'Runner' }
abort('Runner target not found') unless target

target.build_configurations.each do |cfg|
  cfg.build_settings['OTHER_LDFLAGS'] = lib_flags
  cfg.build_settings['DEAD_CODE_STRIPPING'] = 'NO'
  cfg.build_settings['STRIP_INSTALLED_PRODUCT'] = 'NO'
  # 未签名构建（Flutter --no-codesign 下 pods 路径仍可能要求 team）
  cfg.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
  cfg.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
  cfg.build_settings['CODE_SIGN_IDENTITY'] = ''
  # iSH 头文件搜索路径（桥接文件需要 xX_main_Xx.h 等）
  hp = cfg.build_settings['HEADER_SEARCH_PATHS'] || '$(inherited)'
  hp = "#{hp} \"$(SRCROOT)/../native/ish\"" unless hp.include?('native/ish')
  cfg.build_settings['HEADER_SEARCH_PATHS'] = hp
  # Swift 桥接头（AppDelegate 调 ISHBridge）
  cfg.build_settings['SWIFT_OBJC_BRIDGING_HEADER'] = 'Runner/Runner-Bridging-Header.h'
  puts "#{cfg.name}: ldflags + strip + 签名禁用 + iSH 头文件路径 已注入"
end

# 把 iSH 桥接文件加进 Runner 编译源（幂等）
runner_group = project.main_group.find_subpath('Runner', false) ||
               project.main_group.new_group('Runner', 'Runner')
bridge_m = runner_group.files.find { |f| f.path == 'ish_bridge.m' }
if bridge_m.nil?
  ref = runner_group.new_file('ish_bridge.m')
  target.source_build_phase.add_file_reference(ref)
  puts 'ish_bridge.m 已加入 Runner 编译源'
else
  puts 'ish_bridge.m 已在工程中'
end
runner_group.new_file('ish_bridge.h') if runner_group.files.none? { |f| f.path == 'ish_bridge.h' }

project.save
puts 'Runner.xcodeproj 注入完成'
