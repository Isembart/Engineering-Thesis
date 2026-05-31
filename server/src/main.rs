mod db;
mod error;
mod model;
mod routes;

use dotenv::dotenv;

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

    // Provide the pool via `with_state` instead of `Extension` to act as typed global state
    let app = routes::router().with_state(pool.clone());

    let addr = std::env::var("SERVER_ADDRESS").unwrap_or_else(|_| "0.0.0.0:3000".into());
    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    println!("Server running at http://{}", &addr);
    axum::serve(listener, app).await.unwrap();
}
