//! session — 连接会话（服务器地址 + token 受保护存储）
use crate::crypto;
use serde_json::{json, Value};
use std::fs;

const SESSION_FILE: &str = ".snowluma_session.json";

/// 初始化数据目录
pub fn init(data_dir: &str) -> Value {
    let _ = fs::create_dir_all(data_dir);
    json!({ "data_dir": data_dir })
}

/// 保存会话（base_url + token，token 受保护存储）
pub fn save(data_dir: &str, base_url: &str, token: &str) -> Result<Value, String> {
    let path = format!("{data_dir}/{SESSION_FILE}");
    crypto::write_protected(&path, &json!({ "baseUrl": base_url, "token": token }).to_string())
        .map_err(|e| format!("写入会话失败: {e}"))?;
    Ok(json!({ "saved": true, "path": path }))
}

/// 读取会话；无会话返回 exists=false
pub fn load(data_dir: &str) -> Value {
    let path = format!("{data_dir}/{SESSION_FILE}");
    let Some(raw) = crypto::read_protected(&path) else {
        return json!({ "exists": false });
    };
    let Ok(v) = serde_json::from_str::<Value>(&raw) else {
        return json!({ "exists": false, "corrupted": true });
    };
    json!({
        "exists": true,
        "baseUrl": v.get("baseUrl").and_then(|x| x.as_str()).unwrap_or(""),
        "token": v.get("token").and_then(|x| x.as_str()).unwrap_or(""),
    })
}

/// 清除会话
pub fn clear(data_dir: &str) -> Value {
    let path = format!("{data_dir}/{SESSION_FILE}");
    let _ = fs::remove_file(&path);
    json!({ "cleared": true })
}

/// 密码强度校验（对齐 SnowLuma check-strength 规则）
pub fn check_password_strength(password: &str) -> Value {
    let has_upper = password.chars().any(|c| c.is_ascii_uppercase());
    let has_lower = password.chars().any(|c| c.is_ascii_lowercase());
    let has_digit = password.chars().any(|c| c.is_ascii_digit());
    let has_symbol = password
        .chars()
        .any(|c| !c.is_ascii_alphanumeric() && !c.is_whitespace());

    let rules = vec![
        json!({ "id": "length", "label": "至少 8 位", "valid": password.len() >= 8 }),
        json!({ "id": "upper", "label": "含大写字母", "valid": has_upper }),
        json!({ "id": "lower", "label": "含小写字母", "valid": has_lower }),
        json!({ "id": "digit", "label": "含数字", "valid": has_digit }),
        json!({ "id": "symbol", "label": "含符号", "valid": has_symbol }),
    ];
    let valid = rules.iter().all(|r| r["valid"] == json!(true));
    json!({ "rules": rules, "valid": valid })
}

/// 归一化服务器地址（去尾斜杠、补 http://）
pub fn normalize_base_url(raw: &str) -> String {
    let t = raw.trim().trim_end_matches('/');
    if t.is_empty() {
        return String::new();
    }
    if t.starts_with("http://") || t.starts_with("https://") {
        t.to_string()
    } else {
        format!("http://{t}")
    }
}
