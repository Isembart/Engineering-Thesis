use axum::{
    extract::{Query, State},
    Json,
};
use serde::Deserialize;

use crate::{
    db::DbPool,
    error::AppError,
    model::board_settings,
    model_operations::board_settings_operations::{self, BoardSettingsDTO},
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

#[derive(Deserialize)]
pub struct BoardSettingsQueryDTO {
    mac_address: i64,
}

pub async fn insert_board_settings(
    State(pool): State<DbPool>,
    Query(query): Query<BoardSettingsQueryDTO>,
    Json(payload): Json<BoardSettingsDTO>,
) -> Result<Json<board_settings::Model>, AppError> {
    println!(
        "Inserting board settings for MAC address: {}",
        query.mac_address
    );
    println!(
        "Payload: scans_per_send: {}, wifi_scan_time: {}, bluetooth_scan_time: {}, wifi_channel_scan_time: {}, bluetooth_channel_scan_time: {}, minimal_encounter_count: {}, min_rssi: {}, server_endpoint: {}",
        payload.scans_per_send,
        payload.wifi_scan_time,
        payload.bluetooth_scan_time,
        payload.wifi_channel_scan_time,
        payload.bluetooth_channel_scan_time,
        payload.minimal_encounter_count,
        payload.min_rssi,
        payload.server_endpoint
    );
    let new_settings =
        board_settings_operations::insert_board_settings(query.mac_address, payload, &pool).await?;
    Ok(Json(new_settings))
}

pub async fn update_board_settings(
    State(pool): State<DbPool>,
    Query(query): Query<BoardSettingsQueryDTO>,
    Json(payload): Json<BoardSettingsDTO>,
) -> Result<Json<board_settings::Model>, AppError> {
    let updated_settings =
        board_settings_operations::update_board_settings(query.mac_address, payload, &pool).await?;
    Ok(Json(updated_settings))
}
