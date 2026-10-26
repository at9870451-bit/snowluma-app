//! crypto — 凭据保护（token xor+base64 存储 / 密码 sha256 摘要）
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use sha2::{Digest, Sha256};
use std::fs;

const KEY: &[u8] = b"snowluma-frontend-2026-xor-key";

/// 保护凭据：xor 流 + base64（避免明文落盘，非抗破解密码学）
pub fn protect(plain: &str) -> String {
    let bytes = plain.as_bytes();
    let enc: Vec<u8> = bytes.iter().enumerate().map(|(i, b)| b ^ KEY[i % KEY.len()]).collect();
    B64.encode(enc)
}

/// 还原凭据；失败返回 None
pub fn unprotect(enc: &str) -> Option<String> {
    let bytes = B64.decode(enc).ok()?;
    let plain: Vec<u8> = bytes.iter().enumerate().map(|(i, b)| b ^ KEY[i % KEY.len()]).collect();
    String::from_utf8(plain).ok()
}

/// 密码摘要（sha256 小写 hex）——只存摘要，不存原文
pub fn digest(text: &str) -> String {
    let mut h = Sha256::new();
    h.update(text.as_bytes());
    hex(h.finalize())
}

pub fn hex(bytes: impl AsRef<[u8]>) -> String {
    bytes.as_ref().iter().map(|b| format!("{b:02x}")).collect()
}

/// 读取受保护文件；不存在或非法返回 None
pub fn read_protected(path: &str) -> Option<String> {
    let raw = fs::read_to_string(path).ok()?;
    unprotect(raw.trim())
}

pub fn write_protected(path: &str, value: &str) -> std::io::Result<()> {
    fs::write(path, protect(value))
}
