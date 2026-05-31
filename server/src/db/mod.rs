use sea_orm::{Database, DatabaseConnection};
use std::sync::Arc;

pub type DbPool = Arc<DatabaseConnection>;

pub async fn init_pool(database_url: &str) -> DbPool {
    // For SQLite, SeaORM uses sqlx internally. Use SqlxSqliteConnector via Database::connect
    let conn = Database::connect(database_url)
        .await
        .expect("Failed to connect to DB");

    // Run a simple migration: create table if not exists using raw SQL
    // let sql = r#"
    // CREATE TABLE IF NOT EXISTS hello (
    //     id INTEGER PRIMARY KEY AUTOINCREMENT,
    //     message TEXT NOT NULL
    // );
    // "#;
    // let stmt = Statement::from_string(DatabaseBackend::Sqlite, sql.to_owned());
    // let _ = conn.execute_raw(stmt).await.ok();

    Arc::new(conn)
}
