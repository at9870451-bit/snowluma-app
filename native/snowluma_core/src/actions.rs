//! actions — OneBot v11 动作构建与参数校验
use serde_json::{json, Value};

/// 常用动作参数校验表（核心必填参数）
const REQUIRED_PARAMS: [(&str, &[&str]); 12] = [
    ("send_private_msg", &["user_id", "message"]),
    ("send_group_msg", &["group_id", "message"]),
    ("send_msg", &["message"]),
    ("delete_msg", &["message_id"]),
    ("get_login_info", &[]),
    ("get_friend_list", &[]),
    ("get_group_list", &[]),
    ("get_group_member_list", &["group_id"]),
    ("set_group_ban", &["group_id", "user_id", "duration"]),
    ("set_group_kick", &["group_id", "user_id"]),
    ("set_friend_add_request", &["flag"]),
    ("set_group_add_request", &["request_id"]),
];

/// 构建 OneBot v11 动作请求体（对齐 /api/debug/invoke）
pub fn build_action(name: &str, uin: i64, params: &Value) -> Value {
    json!({
        "uin": uin,
        "action": name,
        "params": params,
    })
}

/// 校验动作参数，返回错误列表（空=通过）
pub fn validate_action(name: &str, params: &Value) -> Vec<String> {
    let mut errs = Vec::new();
    let obj = match params.as_object() {
        Some(o) => o,
        None => return vec!["params 必须是 JSON 对象".to_string()],
    };
    let Some((_, required)) = REQUIRED_PARAMS.iter().find(|(n, _)| *n == name) else {
        // 未知动作：不阻塞，仅检查是否为对象
        return errs;
    };
    // required: &&[&str]，*required: &[&str] 可迭代
    for key in *required {
        let v = obj.get(*key);
        if v.is_none() {
            errs.push(format!("缺少必填参数 {key}"));
        } else if v.is_some_and(|x| matches!(x, Value::Null)) {
            errs.push(format!("参数 {key} 为空"));
        }
    }
    if errs.is_empty() {
        // 发送消息类动作的消息内容检查
        if matches!(name, "send_private_msg" | "send_group_msg" | "send_msg") {
            let msg = obj.get("message");
            let empty = match msg {
                Some(Value::String(s)) => s.trim().is_empty(),
                Some(Value::Array(a)) => a.is_empty(),
                _ => false,
            };
            if empty {
                errs.push("message 为空，请输入要发送的内容".to_string());
            }
        }
    }
    errs
}

/// 按 schema 生成默认参数（取第一个 example.params 作为模板）
pub fn example_params(action: &Value) -> Value {
    let ex = action.get("examples").and_then(|e| e.as_array());
    if let Some(arr) = ex {
        for item in arr {
            if let Some(p) = item.get("params") {
                return p.clone();
            }
        }
    }
    json!({})
}

/// 把消息文本封装成 OneBot message segment 数组
pub fn message_segments(text: &str) -> Value {
    json!([{ "type": "text", "data": { "text": text } }])
}

/// 动作分类（按名字前缀归类，用于前端分组展示）
pub fn category_of(name: &str) -> &'static str {
    if name.starts_with("send_") {
        "消息"
    } else if name.starts_with("delete_") || name.starts_with("set_") {
        "管理"
    } else if name.starts_with("get_") || name.starts_with("_get_") {
        "查询"
    } else if name.starts_with("_") {
        "高级"
    } else {
        "其他"
    }
}
