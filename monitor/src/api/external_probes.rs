//! Bounded server-side external checks. Built-ins are whitelisted; arbitrary
//! destinations require the same full-access grant as a shell or TCP forwarding.
use std::collections::HashMap;
use std::sync::{Arc, OnceLock};
use std::time::{Duration, Instant};

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use tokio::sync::{Mutex, Semaphore};

use super::server::{AppState, verify_auth};
use super::ws;

const MAX_BODY: usize = 65536;

#[derive(Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Target {
    id: String,
    address: String,
    protocol: String,
    method: String,
    timeout_seconds: u64,
    follow_redirects: bool,
    status_min: u16,
    status_max: u16,
    keyword: String,
}

#[derive(Deserialize)]
pub struct Request { targets: Vec<Target> }

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Observation {
    id: String,
    state: &'static str,
    reason: &'static str,
    checked_at: String,
    http_status: Option<u16>,
    elapsed_ms: Option<u64>,
    remote_ip: Option<String>,
    transport: &'static str,
}

impl Observation {
    fn unknown(id: &str, reason: &'static str) -> Self {
        Self { id: id.to_owned(), state: "unknown", reason,
            checked_at: chrono::Utc::now().to_rfc3339(), http_status: None,
            elapsed_ms: None, remote_ip: None, transport: "Monitor" }
    }
}

fn builtin(id: &str) -> Option<&'static str> {
    Some(match id {
        "chatGpt" => "https://chatgpt.com/",
        "gemini" => "https://gemini.google.com/",
        "claude" => "https://claude.ai/",
        "copilot" => "https://copilot.microsoft.com/",
        "netflix" => "https://www.netflix.com/",
        "youtube" => "https://www.youtube.com/",
        "disney" => "https://www.disneyplus.com/",
        "spotify" => "https://open.spotify.com/",
        "telegram" => "https://web.telegram.org/",
        "discord" => "https://discord.com/",
        "x" => "https://x.com/",
        "instagram" => "https://www.instagram.com/",
        "reddit" => "https://www.reddit.com/",
        "github" => "https://github.com/",
        "docker" => "https://hub.docker.com/",
        "npm" => "https://registry.npmjs.org/",
        "pypi" => "https://pypi.org/",
        "google" => "https://www.google.com/",
        "bing" => "https://www.bing.com/",
        "wikipedia" => "https://www.wikipedia.org/",
        _ => return None,
    })
}

fn validate(target: &mut Target) -> Result<(), &'static str> {
    if target.id.is_empty() || target.id.len() > 80 ||
        !target.id.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'_') {
        return Err("Invalid target id");
    }
    if let Some(address) = builtin(&target.id) {
        // A client cannot turn a whitelisted service into an arbitrary URL.
        target.address = address.to_owned();
        target.protocol = "http".into();
    } else if !target.id.starts_with("custom_") { return Err("Unknown service"); }
    if !(2..=15).contains(&target.timeout_seconds) || target.status_min < 100 ||
        target.status_max > 599 || target.status_min > target.status_max ||
        !["GET", "HEAD"].contains(&target.method.as_str()) ||
        target.keyword.chars().count() > 200 || target.keyword.contains(['\n', '\r', '\0']) ||
        (target.method == "HEAD" && !target.keyword.is_empty()) {
        return Err("Invalid check options");
    }
    if target.address.len() > 2048 || target.address.bytes().any(|c| c <= b' ') {
        return Err("Invalid address");
    }
    let url = reqwest::Url::parse(&target.address).map_err(|_| "Invalid address")?;
    if url.host_str().is_none() || !url.username().is_empty() || url.password().is_some() {
        return Err("Invalid address");
    }
    match target.protocol.as_str() {
        "http" if ["http", "https"].contains(&url.scheme()) => {},
        "tcp" if url.scheme() == "tcp" && url.port().is_some_and(|p| p > 0) &&
            url.path().is_empty() && url.query().is_none() && url.fragment().is_none() => {},
        _ => return Err("Invalid protocol or port"),
    }
    Ok(())
}

fn slots() -> &'static Semaphore {
    static SLOTS: OnceLock<Semaphore> = OnceLock::new();
    SLOTS.get_or_init(|| Semaphore::new(3))
}

fn attempts() -> &'static Mutex<HashMap<String, Instant>> {
    static ATTEMPTS: OnceLock<Mutex<HashMap<String, Instant>>> = OnceLock::new();
    ATTEMPTS.get_or_init(|| Mutex::new(HashMap::new()))
}

pub async fn check(req: HttpRequest, body: web::types::Json<Request>,
    app: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let claims = match verify_auth(&req, &app.config.get_jwt_secret()) {
        Ok(claims) => claims,
        Err(_) => return Ok(HttpResponse::Unauthorized().finish()),
    };
    let mut targets = body.into_inner().targets;
    if targets.is_empty() || targets.len() > 3 {
        return Ok(HttpResponse::BadRequest().json(&serde_json::json!({"error": "Select one to three targets"})));
    }
    let mut ids = std::collections::HashSet::new();
    for target in &mut targets {
        if let Err(reason) = validate(target) {
            return Ok(HttpResponse::BadRequest().json(&serde_json::json!({"error": reason})));
        }
        if !ids.insert(target.id.clone()) {
            return Ok(HttpResponse::BadRequest().json(&serde_json::json!({"error": "Duplicate target"})));
        }
    }
    let full_access = app.full_access_allowed(ws::is_secure_transport(&req, app.tls_active));
    let mut immediate = Vec::new();
    let mut admitted = Vec::new();
    {
        let mut times = attempts().lock().await;
        times.retain(|_, at| at.elapsed() < Duration::from_secs(60));
        for target in targets {
            if builtin(&target.id).is_none() && !full_access {
                immediate.push(Observation::unknown(&target.id, "permission"));
                continue;
            }
            let key = format!("{}:{}", claims.sub, target.id);
            if times.contains_key(&key) || times.len() >= 1024 {
                immediate.push(Observation::unknown(&target.id, "rateLimited"));
                continue;
            }
            times.insert(key, Instant::now());
            admitted.push(target);
        }
    }
    let mut results = futures::future::join_all(admitted.iter().map(probe)).await;
    results.extend(immediate);
    Ok(HttpResponse::Ok().json(&serde_json::json!({"results": results})))
}

fn http_outcome(status: u16, target: &Target, keyword_match: bool) -> (&'static str, &'static str) {
    if (target.status_min..=target.status_max).contains(&status) {
        if target.keyword.is_empty() || keyword_match { ("reachable", "httpResponse") }
        else { ("rejected", "keywordMismatch") }
    } else {
        ("rejected", match status {
            401 => "authentication", 403 => "accessDenied", 429 => "rateLimited",
            500..=599 => "serviceError", 300..=399 => "redirect", _ => "unexpectedStatus",
        })
    }
}

async fn probe(target: &Target) -> Observation {
    let Ok(_permit) = slots().try_acquire() else {
        return Observation::unknown(&target.id, "busy");
    };
    let start = Instant::now();
    let mut result = Observation::unknown(&target.id, "network");
    let outcome = tokio::time::timeout(Duration::from_secs(target.timeout_seconds), async {
        if target.protocol == "tcp" {
            let url = reqwest::Url::parse(&target.address).expect("validated URL");
            let host = url.host_str().expect("validated host").trim_matches(['[', ']']);
            match tokio::net::TcpStream::connect((host, url.port().expect("validated port"))).await {
                Ok(stream) => {
                    result.state = "reachable"; result.reason = "tcpConnected";
                    result.remote_ip = stream.peer_addr().ok().map(|a| a.ip().to_string());
                },
                Err(_) => result.reason = "connection",
            }
            return;
        }
        let _ = rustls::crypto::ring::default_provider().install_default();
        let client = reqwest::Client::builder()
            .connect_timeout(Duration::from_secs(5))
            .timeout(Duration::from_secs(target.timeout_seconds))
            .redirect(if target.follow_redirects { reqwest::redirect::Policy::limited(5) }
                else { reqwest::redirect::Policy::none() })
            .user_agent("ServerBox external service check").build();
        let Ok(client) = client else { result.reason = "toolError"; return; };
        let request = if target.method == "HEAD" { client.head(&target.address) }
            else { client.get(&target.address) };
        match request.send().await {
            Ok(mut response) => {
                let status = response.status().as_u16();
                result.http_status = Some(status);
                result.remote_ip = response.remote_addr().map(|a| a.ip().to_string());
                let mut matches = target.keyword.is_empty();
                if !matches && (target.status_min..=target.status_max).contains(&status) {
                    let mut bytes = Vec::new();
                    loop {
                        match response.chunk().await {
                            Ok(Some(chunk)) => {
                                if bytes.len() + chunk.len() > MAX_BODY {
                                    result.reason = "responseTooLarge"; return;
                                }
                                bytes.extend_from_slice(&chunk);
                            },
                            Ok(None) => break,
                            Err(error) => {
                                result.reason = if error.is_timeout() { "timeout" } else { "network" };
                                return;
                            },
                        }
                    }
                    matches = String::from_utf8_lossy(&bytes).contains(&target.keyword);
                }
                (result.state, result.reason) = http_outcome(status, target, matches);
            },
            Err(error) => {
                // reqwest does not expose a stable DNS/TLS discriminator.
                result.reason = if error.is_timeout() { "timeout" }
                    else if error.is_redirect() { "redirects" }
                    else if error.is_connect() { "connection" } else { "network" };
            },
        }
    }).await;
    if outcome.is_err() { result.state = "unknown"; result.reason = "timeout"; }
    result.elapsed_ms = Some(start.elapsed().as_millis() as u64);
    result.checked_at = chrono::Utc::now().to_rfc3339();
    result
}

#[cfg(test)]
mod tests {
    use super::*;
    fn target() -> Target { Target { id: "custom_local".into(),
        address: "http://127.0.0.1:1234/".into(), protocol: "http".into(),
        method: "GET".into(), timeout_seconds: 2, follow_redirects: true,
        status_min: 200, status_max: 399, keyword: String::new() } }

    #[test]
    fn validation_and_whitelist() {
        let mut t = target(); assert!(validate(&mut t).is_ok());
        t.id = "github".into(); t.address = "file:///etc/passwd".into();
        assert!(validate(&mut t).is_ok()); assert_eq!(t.address, builtin("github").unwrap());
        t = target(); t.address = "http://user:password@example.com".into();
        assert!(validate(&mut t).is_err());
        t = target(); t.address = "file:///etc/passwd".into(); assert!(validate(&mut t).is_err());
        t = target(); t.protocol = "tcp".into(); t.address = "tcp://example.com:443".into();
        assert!(validate(&mut t).is_ok());
        t.timeout_seconds = 90; assert!(validate(&mut t).is_err());
    }

    #[test]
    fn http_diagnostics_do_not_claim_unlock() {
        let t = target();
        assert_eq!(http_outcome(200, &t, true), ("reachable", "httpResponse"));
        assert_eq!(http_outcome(401, &t, true), ("rejected", "authentication"));
        assert_eq!(http_outcome(403, &t, true), ("rejected", "accessDenied"));
        assert_eq!(http_outcome(429, &t, true), ("rejected", "rateLimited"));
        assert_eq!(http_outcome(503, &t, true), ("rejected", "serviceError"));
        let mut t = target(); t.keyword = "healthy".into();
        assert_eq!(http_outcome(200, &t, false), ("rejected", "keywordMismatch"));
    }

    #[tokio::test]
    async fn real_loopback_http_keyword_and_tcp() {
        use tokio::io::{AsyncReadExt, AsyncWriteExt};
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let server = tokio::spawn(async move {
            let (mut stream, _) = listener.accept().await.unwrap();
            let mut bytes = [0; 4096]; let _ = stream.read(&mut bytes).await;
            stream.write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 7\r\nConnection: close\r\n\r\nhealthy").await.unwrap();
        });
        let mut t = target(); t.address = format!("http://{addr}/"); t.keyword = "healthy".into();
        let result = probe(&t).await; assert_eq!(result.state, "reachable");
        assert_eq!(result.http_status, Some(200)); server.await.unwrap();
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        t.protocol = "tcp".into(); t.address = format!("tcp://{}", listener.local_addr().unwrap());
        let result = probe(&t).await; assert_eq!(result.reason, "tcpConnected");
    }
}
