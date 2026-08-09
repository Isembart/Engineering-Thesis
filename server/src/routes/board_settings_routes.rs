use axum::{
    extract::{Query, State},
    Json,
};
use serde::Deserialize;

use crate::{
    db::DbPool, error::AppError, model::board_settings, model_operations::board_settings_operations,
};

#[derive(Deserialize)]
pub struct GetBoardSettingsQuery {
    pub mac_address: i64,
}
pub async fn get_board_settings_by_mac(
    State(pool): State<DbPool>,
    Query(query): Query<GetBoardSettingsQuery>,
) -> Result<Json<board_settings::Model>, AppError> {
    match board_settings_operations::get_settings_by_board_mac(query.mac_address, &pool).await? {
        Some(settings) => Ok(Json(settings)),
        None => Err(AppError::NotFound(format!(
            "Board settings for MAC address {} not found",
            query.mac_address
        ))),
    }
}

pub async fn insert_board_settings(
    State(pool): State<DbPool>,
    Json(payload): Json<board_settings::Model>,
) -> Result<Json<board_settings::Model>, AppError> {
    let new_settings = board_settings_operations::insert_board_settings(payload, &pool).await?;
    Ok(Json(new_settings))
}

pub async fn update_board_settings(
    State(pool): State<DbPool>,
    Json(payload): Json<board_settings::Model>,
) -> Result<Json<board_settings::Model>, AppError> {
    let updated_settings = board_settings_operations::update_board_settings(payload, &pool).await?;
    Ok(Json(updated_settings))
}
