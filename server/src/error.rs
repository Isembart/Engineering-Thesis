use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use sea_orm::DbErr;
use serde_json::json;

#[derive(Debug)]
pub enum AppError {
    NotFound(String),
    Internal(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, error_message) = match &self {
            AppError::NotFound(msg) => {
                eprintln!("AppError: NotFound - {}", msg);
                (StatusCode::NOT_FOUND, msg.clone())
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
            DbErr::RecordNotFound(msg) => AppError::NotFound(format!("Record not found: {}", msg)),
            _ => AppError::Internal("Database error".to_string()),
        }
    }
}
