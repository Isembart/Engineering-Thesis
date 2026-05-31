use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use sea_orm::DbErr;
use serde_json::json;

#[derive(Debug)]
pub enum AppError {
    NotFound,
    Internal(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, error_message) = match &self {
            AppError::NotFound => {
                eprintln!("AppError: NotFound");
                (StatusCode::NOT_FOUND, "Not found".to_string())
            }
            AppError::Internal(msg) => {
                eprintln!("AppError Internal: {}", msg);
                (StatusCode::INTERNAL_SERVER_ERROR, msg.clone())
            }
        };

        let body = Json(json!({
            "error": error_message,
        }));

        (status, body).into_response()
    }
}

impl From<DbErr> for AppError {
    fn from(err: DbErr) -> Self {
        match err {
            DbErr::RecordNotFound(_) => AppError::NotFound,
            _ => AppError::Internal("Database error".to_string()),
        }
    }
}
