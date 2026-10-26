// snowluma_core — SnowLuma 前端 Rust Core 入口
//
// 桥接协议（C FFI JSON 总线）：
//   Dart 调用 snowluma_call(method, payload_json) -> resp_json
//   统一信封：{ "ok": true, "data": ... } 或 { "ok": false, "error": { "code", "message" } }
//
// 模块：
//   session  — 连接会话（服务器地址 + token 受保护存储）
//   models   — API 数据模型（QQ 账号 / OneBot 动作）
//   actions  — OneBot v11 动作构建与参数校验
//   crypto   — 凭据保护（xor+base64 存储 / sha256 摘要）

mod actions;
mod crypto;
mod models;
mod session;

use std::cell::RefCell;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

use serde_json::{json, Value};

pub use models::{ActionDef, ActionExample, QqAccount, SessionState};

thread_local! {
    static DATA_DIR: RefCell<String> = const { RefCell::new(String::new()) };
}

fn data_dir() -> String {
    DATA_DIR.with(|d| d.borrow().clone())
}

fn ok(data: Value) -> String {
    serde_json::to_string(&json!({ "ok": true, "data": data })).unwrap_or_default()
}

fn err(code: &str, message: &str) -> String {
    serde_json::to_string(&json!({ "ok": false, "error": { "code": code, "message": message } }))
        .unwrap_or_default()
}

fn get<'a>(p: &'a Value, key: &str) -> &'a Value {
    p.get(key).unwrap_or(&Value::Null)
}

fn get_str(p: &Value, key: &str) -> String {
    get(p, key).as_str().unwrap_or("").to_string()
}

fn dispatch(method: &str, payload: &Value) -> String {
    match method {
        "core.ping" => ok(json!({ "pong": true })),
        "core.version" => ok(json!({
            "name": "SnowLumaCore",
            "version": env!("CARGO_PKG_VERSION"),
            "api": 1,
            "platform": std::env::consts::OS,
            "arch": std::env::consts::ARCH,
        })),
        "core.init" => {
            let dir = get_str(payload, "data_dir");
            if dir.is_empty() {
                return err("missing_data_dir", "缺少 data_dir");
            }
            DATA_DIR.with(|d| *d.borrow_mut() = dir.clone());
            ok(session::init(&dir))
        }
        "session.save" => {
            let dir = data_dir();
            let url = get_str(payload, "baseUrl");
            let token = get_str(payload, "token");
            if url.is_empty() || token.is_empty() {
                return err("missing_field", "baseUrl 与 token 不能为空");
            }
            match session::save(&dir, &url, &token) {
                Ok(v) => ok(v),
                Err(e) => err("save_failed", &e),
            }
        }
        "session.load" => ok(session::load(&data_dir())),
        "session.clear" => ok(session::clear(&data_dir())),
        "session.normalize" => ok(json!({ "url": session::normalize_base_url(&get_str(payload, "url")) })),
        "session.save_vnc" => match session::save_vnc(&data_dir(), &get_str(payload, "password")) {
            Ok(v) => ok(v),
            Err(e) => err("save_vnc_failed", &e),
        },
        "session.load_vnc" => ok(session::load_vnc(&data_dir())),
        "auth.parse_login" => {
            let body = get(payload, "body");
            let mut state = SessionState::Invalid;
            let mut token = String::new();
            let mut message = String::new();
            if body.get("needsTotp").and_then(|v| v.as_bool()) == Some(true) {
                state = SessionState::NeedTotp;
            } else if body.get("token").and_then(|v| v.as_str()).is_some() {
                token = body["token"].as_str().unwrap_or_default().to_string();
                state = if body.get("mustChangePassword").and_then(|v| v.as_bool()) == Some(true) {
                    SessionState::NeedChangePassword
                } else {
                    SessionState::Ready
                };
            } else {
                message = body
                    .get("message")
                    .and_then(|v| v.as_str())
                    .unwrap_or("登录失败，请检查密码")
                    .to_string();
            }
            ok(json!({
                "state": state.as_str(),
                "token": token,
                "message": message,
            }))
        }
        "auth.parse_state" => ok(json!({
            "mustChangePassword": get(payload, "body")["mustChangePassword"] == json!(true),
        })),
        "agreement.parse" => {
            let body = get(payload, "body");
            let version = body["version"].as_str().unwrap_or_default().to_string();
            let consent = body.get("consentRequired").and_then(|v| v.as_bool()).unwrap_or(false);
            let docs = body.get("documents").and_then(|d| d.as_array()).cloned().unwrap_or_default();
            ok(json!({
                "version": version,
                "consentRequired": consent,
                "documents": docs,
            }))
        },
        "password.check_strength" => ok(session::check_password_strength(&get_str(payload, "password"))),
        "hash.digest" => ok(json!({
            "digest": crypto::digest(&get_str(payload, "text")),
            "length": get_str(payload, "text").len(),
        })),
        "account.parse" => {
            let list = get(payload, "body")["list"].as_array().cloned().unwrap_or_default();
            let mut accounts = Vec::new();
            for item in &list {
                let mut acc: QqAccount = match serde_json::from_value(item.clone()) {
                    Ok(a) => a,
                    Err(_) => QqAccount { raw: Some(item.clone()), ..Default::default() },
                };
                acc.raw = Some(item.clone());
                if acc.nickname.is_empty() {
                    acc.nickname = acc.nick.clone();
                }
                accounts.push(acc);
            }
            ok(json!({ "accounts": accounts, "count": accounts.len() }))
        }
        "action.parse" => {
            let actions = get(payload, "body")["actions"].as_array().cloned().unwrap_or_default();
            let mut defs = Vec::new();
            for item in &actions {
                match serde_json::from_value::<ActionDef>(item.clone()) {
                    Ok(mut d) => {
                        d.summary = if d.summary.is_empty() { d.name.clone() } else { d.summary };
                        defs.push(json!({
                            "name": d.name,
                            "summary": d.summary,
                            "category": actions::category_of(&d.name),
                            "example": actions::example_params(item),
                            "required": actions::validate_action(&d.name, &actions::example_params(item)),
                        }));
                    }
                    Err(_) => {}
                }
            }
            ok(json!({ "actions": defs, "count": defs.len() }))
        }
        "action.build" => {
            let name = get_str(payload, "name");
            if name.is_empty() {
                return err("missing_name", "缺少动作名");
            }
            let uin = get(payload, "uin").as_i64().unwrap_or(0);
            let params = get(payload, "params").clone();
            let errs = actions::validate_action(&name, &params);
            let mut r = actions::build_action(&name, uin, &params);
            r["errors"] = json!(errs);
            ok(r)
        }
        "action.validate" => {
            let name = get_str(payload, "name");
            let params = get(payload, "params").clone();
            let errs = actions::validate_action(&name, &params);
            ok(json!({ "valid": errs.is_empty(), "errors": errs }))
        }
        "action.category" => ok(json!({ "category": actions::category_of(&get_str(payload, "name")) })),
        "action.example" => ok(actions::example_params(get(payload, "action"))),
        "action.message_segments" => ok(actions::message_segments(&get_str(payload, "text"))),
        "invoke.build" => {
            let uin = get(payload, "uin").as_i64().unwrap_or(0);
            let action = get_str(payload, "action");
            let params = get(payload, "params").clone();
            if action.is_empty() {
                return err("missing_action", "缺少动作名");
            }
            let errs = actions::validate_action(&action, &params);
            if !errs.is_empty() {
                return err("invalid_params", &errs.join("；"));
            }
            ok(actions::build_action(&action, uin, &params))
        },
        _ => err("unknown_method", &format!("未知方法: {method}")),
    }
}

fn run(method: &CStr, payload: &CStr) -> String {
    let payload_json = match serde_json::from_str::<Value>(payload.to_str().unwrap_or("{}")) {
        Ok(v) => v,
        Err(e) => return err("bad_payload", &format!("payload 不是合法 JSON: {e}")),
    };
    dispatch(method.to_str().unwrap_or(""), &payload_json)
}

#[no_mangle]
pub unsafe extern "C" fn snowluma_call(method: *mut c_char, payload: *mut c_char) -> *mut c_char {
    if method.is_null() || payload.is_null() {
        return CString::new("").unwrap().into_raw();
    }
    let m = CStr::from_ptr(method);
    let p = CStr::from_ptr(payload);
    let out = run(m, p);
    CString::new(out).unwrap_or_default().into_raw()
}

#[no_mangle]
pub unsafe extern "C" fn snowluma_free(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    drop(CString::from_raw(ptr));
}
