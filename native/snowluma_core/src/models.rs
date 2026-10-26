//! models — SnowLuma WebUI API 数据模型（serde 解析）
use serde::{Deserialize, Serialize};

/// QQ 账号（GET /api/qq-list → { list: [...] }）
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct QqAccount {
    /// QQ 号（OneBot 账号标识）
    #[serde(default, alias = "uin", alias = "user_id", alias = "userId", alias = "id")]
    pub account_id: i64,
    /// 昵称（可能为空）
    #[serde(default)]
    pub nickname: String,
    /// 昵称回退字段
    #[serde(default, alias = "nick")]
    pub nick: String,
    /// 是否在线
    #[serde(default)]
    pub online: Option<bool>,
    /// 登录状态文本
    #[serde(default)]
    pub status: Option<String>,
    /// 头像 URL
    #[serde(default, alias = "face_url", alias = "faceUrl")]
    pub avatar: Option<String>,
    /// 原始 JSON（透传，用于展示未知字段）
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub raw: Option<serde_json::Value>,
}

/// OneBot 动作定义（GET /api/debug/actions → { actions: [...] }）
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ActionDef {
    /// 动作名，如 send_private_msg
    pub name: String,
    /// 别名
    #[serde(default)]
    pub aliases: Vec<String>,
    /// 动作摘要（中文说明）
    #[serde(default)]
    pub summary: String,
    /// 参数 schema
    #[serde(default)]
    pub params_schema: Option<serde_json::Value>,
    /// 返回 schema
    #[serde(default)]
    pub returns_schema: Option<serde_json::Value>,
    /// 示例
    #[serde(default)]
    pub examples: Vec<ActionExample>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ActionExample {
    #[serde(default)]
    pub summary: String,
    #[serde(default)]
    pub params: serde_json::Value,
    #[serde(default)]
    pub notes: Option<String>,
}

/// 登录响应状态机
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SessionState {
    /// 可直接使用
    Ready,
    /// 需先同意协议
    NeedConsent,
    /// 需先改初始密码
    NeedChangePassword,
    /// 需 2FA
    NeedTotp,
    /// 凭据错误
    Invalid,
}

impl SessionState {
    pub fn as_str(self) -> &'static str {
        match self {
            SessionState::Ready => "ready",
            SessionState::NeedConsent => "need_consent",
            SessionState::NeedChangePassword => "need_change_password",
            SessionState::NeedTotp => "need_totp",
            SessionState::Invalid => "invalid",
        }
    }
}
