# SnowLuma App — Flutter + Rust 前端

SnowLuma（QQ 原生会话运行时）的 iOS 前端。Flutter 负责 UI 与状态，Rust Core 负责会话状态机、数据模型解析、OneBot 动作构建校验与凭据保护。

## 架构

```
┌─────────────────────────────────────────────┐
│ Flutter UI (lib/)                           │
│   login_page / home_page / actions / logs   │
│   AppState（连接流程编排）                    │
│   SnowLumaApiClient（HTTP 传输 + bearer）    │
│   SnowLumaBridge（dart:ffi JSON 总线）       │
└───────────────────┬─────────────────────────┘
                    │  snowluma_call(method, json) → json
┌───────────────────▼─────────────────────────┐
│ Rust Core (native/snowluma_core/)           │
│   session  — token 受保护存储 + 密码强度      │
│   models   — QQ 账号 / OneBot 动作模型        │
│   actions  — 动作构建 + 参数校验 + 消息分段    │
│   crypto   — xor+base64 保护 / sha256 摘要    │
└─────────────────────────────────────────────┘
```

- 传输层在 Dart（`http` 包），核心逻辑在 Rust，二者通过 FFI JSON 总线通信。
- Rust 以静态库 `libsnowluma_core.a`（aarch64-apple-ios）链入 Runner，`-force_load` + 禁 strip 保住符号。

## FFI 总线协议

```dart
SnowLumaBridge.call('action.build', {
  'name': 'send_private_msg', 'uin': 123,
  'params': {'user_id': 456, 'message': [...]},
});
```

统一信封：`{"ok":true,"data":...}` 或 `{"ok":false,"error":{"code","message"}}`。

方法清单：`core.init` `core.version` `core.ping` `session.save/load/clear/normalize` `auth.parse_login` `auth.parse_state` `agreement.parse` `password.check_strength` `hash.digest` `account.parse` `action.parse` `action.build/validate/example/category/message_segments` `invoke.build`

## 连接流程

1. `POST /api/login {password}` → token
2. `need_consent` → `GET /api/agreements` + `POST /api/agreements/record-consent {version}`
3. `need_change_password` → `POST /api/auth/change-password` → 重新登录
4. token 受保护写入 App 沙盒，下次启动免登录

## 构建

GitHub Actions：`.github/workflows/build-ios.yml`
Rust 1.84.1 + `aarch64-apple-ios` → `flutter build ios` → 未签名 ipa → Release `snowluma-build-N`

```bash
cargo build --release --target aarch64-apple-ios --manifest-path native/snowluma_core/Cargo.toml
ruby tools/fix_xcodeproj.rb
```
