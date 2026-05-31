mod db;
mod error;
mod model;
mod routes;

use axum::http::{header, Method};
use dotenv::dotenv;
use tower_http::cors::{AllowOrigin, Any, CorsLayer};

#[tokio::main]
async fn main() {
    dotenv().ok();

    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set in .env file or environment variable");

    let pool = db::init_pool(&database_url).await;

    // initialize db schema
    pool.get_schema_registry("inzynierka_backend::model::*")
        .sync(&*pool)
        .await
        .expect("Cannot synchronize the database schema with entities definition.");

    let cors = if let Ok(origins) = std::env::var("CORS_ORIGINS") {
        let origins: Vec<_> = origins
            .split(',')
            .filter_map(|o| o.trim().parse().ok())
            .collect();
        CorsLayer::new()
            .allow_origin(AllowOrigin::list(origins))
            .allow_methods([Method::GET, Method::POST, Method::PUT, Method::OPTIONS])
            .allow_headers([header::CONTENT_TYPE])
    } else {
        CorsLayer::new()
            .allow_origin(Any)
            .allow_methods(Any)
            .allow_headers(Any)
    };

    let app = routes::router().with_state(pool.clone()).layer(cors);

    let addr = std::env::var("SERVER_ADDRESS").unwrap_or_else(|_| "0.0.0.0:3000".into());
    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    println!("Server running at http://{}", &addr);
    axum::serve(listener, app).await.unwrap();
}
