use std::sync::Arc;

use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use serde_json::{Value, json};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::external_probes::check;
use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::Config;

const SECRET: &str = "probe-test-secret-at-least-32-characters";

async fn server(full_access: bool) -> TestServer {
    let _ = rustls::crypto::ring::default_provider().install_default();
    let mut config = Config { jwt_secret: Some(SECRET.into()), ..Default::default() };
    let mut remote = config.get_remote_access();
    remote.terminal.enabled = true; remote.full_access = Some(full_access);
    config.remote_access = Some(remote);
    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    let state = AppState::new(Arc::new(config), db);
    web_test::server(move || {
        let state = state.clone();
        async move { App::new().state(state).service(web::resource("/external-probes")
            .route(web::post().to(check))) }
    }).await
}

fn target(id: &str, address: &str) -> Value {
    json!({"id": id, "address": address, "protocol": "http", "method": "GET",
        "timeoutSeconds": 2, "followRedirects": true, "statusMin": 200,
        "statusMax": 399, "keyword": "healthy"})
}

async fn post(srv: &TestServer, targets: Value, user: &str) -> (u16, Value) {
    let response = srv.post("/external-probes")
        .header("Authorization", format!("Bearer {}", generate_token(user, SECRET).unwrap()))
        .send_json(&json!({"targets": targets})).await.unwrap();
    let status = response.status().as_u16();
    (status, response.json().await.unwrap())
}

#[ntex::test]
async fn custom_targets_need_authentication_and_full_access() {
    let srv = server(false).await;
    let response = srv.post("/external-probes")
        .send_json(&json!({"targets": [target("custom_private", "http://127.0.0.1:1/")]}))
        .await.unwrap();
    assert_eq!(response.status().as_u16(), 401);
    let (status, body) = post(&srv, json!([target("custom_private", "http://127.0.0.1:1/")]), "permission-user").await;
    assert_eq!(status, 200); assert_eq!(body["results"][0]["state"], "unknown");
    assert_eq!(body["results"][0]["reason"], "permission");
}

#[ntex::test]
async fn invalid_requests_are_rejected_before_admission() {
    let srv = server(true).await;
    for targets in [json!([]), json!([target("arbitrary_id", "https://example.com/")]),
        json!([target("custom_file", "file:///etc/passwd")]),
        json!([target("custom_dup", "https://example.com/"), target("custom_dup", "https://example.com/")]),
        json!(vec![target("github", "https://github.com/"); 4])] {
        assert_eq!(post(&srv, targets, "invalid-user").await.0, 400);
    }
}

#[ntex::test]
async fn admitted_http_checks_report_evidence_and_enforce_cooldown() {
    let srv = server(true).await;
    let upstream = web_test::server(|| async { App::new().service(web::resource("/")
        .route(web::get().to(|| async { web::HttpResponse::Ok().body("healthy") }))) }).await;
    let address = upstream.url("/");
    let targets = json!([target("custom_loopback", &address)]);
    let (status, body) = post(&srv, targets.clone(), "loopback-user").await;
    assert_eq!(status, 200); assert_eq!(body["results"][0]["state"], "reachable");
    assert_eq!(body["results"][0]["httpStatus"], 200);
    assert!(body["results"][0]["elapsedMs"].is_u64());
    let (_, body) = post(&srv, targets, "loopback-user").await;
    assert_eq!(body["results"][0]["reason"], "rateLimited");
}
