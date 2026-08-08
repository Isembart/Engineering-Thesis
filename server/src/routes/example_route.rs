use axum::{extract::State, Json};

use crate::db::DbPool;
use crate::error::AppError;
use crate::model::hello::Model as HelloModel;

pub async fn hello_handler(State(pool): State<DbPool>) -> Result<Json<HelloModel>, AppError> {
    let result = crate::model::hello::get_first(pool)
        .await
        .map_err(AppError::from)?;

    Ok(Json(result))
}
