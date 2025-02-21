//! Run with
//!
//! ```not_rust
//! cargo run 
//! ```

use axum::{
    extract::Extension,
    http::StatusCode,
    response::{Html, IntoResponse, Json},
    routing::get,
    Router,
};
use dotenvy::dotenv;
use serde::Serialize;
use std::{env, sync::Arc};
use tower::ServiceBuilder;
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[derive(Clone)]
pub struct SharedState {
    pub my_secret: String,
}

#[derive(Serialize)]
struct User {
    id: u32,
    name: String,
    email: String,
}

#[tokio::main]
async fn main() {
    tracing_subscriber::registry()
        .with(tracing_subscriber::fmt::layer())
        .init();

    if env::var("ENVIRONMENT")
        .unwrap_or_else(|_| "development".to_string()) != "production"
    {
        dotenv().ok();
    }

    let port: u16 = env::var("PORT")
        .unwrap_or_else(|_| "3000".to_string())
        .parse::<u16>()
        .expect("PORT must be a number");
    tracing::info!("Starting server on port {}", port);

    // Load MY_SECRET from the environment.
    let my_secret = env::var("MY_SECRET").expect("MY_SECRET must be set");
    tracing::info!("MY_SECRET loaded");
    let shared_state = Arc::new(SharedState { my_secret });

    let app = Router::new()
        .route("/", get(root_get_handler))
        .route("/api/users", get(users_handler))
        .fallback(not_found_handler)
        .layer(Extension(shared_state))
        .layer(
            ServiceBuilder::new()
                .layer(TraceLayer::new_for_http())
                .into_inner(),
        );

    let addr = format!("0.0.0.0:{}", port);
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("Failed to bind TCP listener");
    tracing::info!("Listening on {}", listener.local_addr().expect("Failed to get local address"));
    axum::serve(listener, app)
        .await
        .expect("Server failed");
}

pub async fn root_get_handler(Extension(state): Extension<Arc<SharedState>>) -> Html<String> {
    let my_secret = &state.my_secret;
    let html_content = format!("<h1>Rust server</h1> <p>My secret: {my_secret}</p>");
    Html(html_content)
}

async fn users_handler() -> Json<Vec<User>> {
    let users = vec![
        User {
            id: 1,
            name: "Alice".into(),
            email: "alice@example.com".into(),
        },
        User {
            id: 2,
            name: "Bob".into(),
            email: "bob@example.com".into(),
        },
        User {
            id: 3,
            name: "Charlie".into(),
            email: "charlie@example.com".into(),
        },
    ];
    Json(users)
}

async fn not_found_handler() -> impl IntoResponse {
    (StatusCode::NOT_FOUND, "Route not found")
}