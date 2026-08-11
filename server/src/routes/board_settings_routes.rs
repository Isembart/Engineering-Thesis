use axum::{
    extract::{Query, State},
    Json,
};
use sea_orm::DbErr;
use serde::{Deserialize, Serialize};

use crate::{
    db::DbPool,
    error::AppError,
    model::board_settings,
    model_operations::{
        board_settings_operations::{self},
        boards_operations::{self, get_board_by_mac},
    },
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

#[derive(Serialize, Deserialize)]
pub struct BoardSettingsDTO {
    pub scans_per_send: i64,
    pub wifi_scan_time: i64,
    pub bluetooth_scan_time: i64,
    pub wifi_channel_scan_time: i64,
    pub bluetooth_channel_scan_time: i64,
    pub minimal_encounter_count: i64,
    pub min_rssi: i64,
    pub server_endpoint: String,
}
pub async fn insert_board_settings(
    State(pool): State<DbPool>,
    Query(query): Query<BoardSettingsQueryDTO>,
    Json(payload): Json<BoardSettingsDTO>,
) -> Result<Json<board_settings::Model>, AppError> {
    // let new_settings =
    //     board_settings_operations::insert_board_settings(query.mac_address, payload, &pool).await?;

    let board = match get_board_by_mac(query.mac_address, &pool).await? {
        Some(board) => board,
        None => {
            return Err(AppError::NotFound(format!(
                "Board with MAC {} not found",
                query.mac_address
            )));
        }
    };

    let settings = board_settings::Model {
        board_id: board.id,
        scans_per_send: payload.scans_per_send,
        wifi_scan_time: payload.wifi_scan_time,
        bluetooth_scan_time: payload.bluetooth_scan_time,
        wifi_channel_scan_time: payload.wifi_channel_scan_time,
        bluetooth_channel_scan_time: payload.bluetooth_channel_scan_time,
        minimal_encounter_count: payload.minimal_encounter_count,
        min_rssi: payload.min_rssi,
        server_endpoint: payload.server_endpoint,
    };

    let new_settings = board_settings_operations::insert_board_settings(settings, &pool).await?;

    Ok(Json(new_settings))
}

pub async fn update_board_settings(
    State(pool): State<DbPool>,
    Query(query): Query<BoardSettingsQueryDTO>,
    Json(payload): Json<BoardSettingsDTO>,
) -> Result<Json<board_settings::Model>, AppError> {
    let board = match boards_operations::get_board_by_mac(query.mac_address, &pool).await? {
        Some(board) => board,
        None => {
            return Err(AppError::NotFound(format!(
                "Board with MAC {} not found",
                query.mac_address
            )))
        }
    };

    let new_settings = board_settings::Model {
        board_id: board.id,
        scans_per_send: payload.scans_per_send,
        wifi_scan_time: payload.wifi_scan_time,
        bluetooth_scan_time: payload.bluetooth_scan_time,
        wifi_channel_scan_time: payload.wifi_channel_scan_time,
        bluetooth_channel_scan_time: payload.bluetooth_channel_scan_time,
        minimal_encounter_count: payload.minimal_encounter_count,
        min_rssi: payload.min_rssi,
        server_endpoint: payload.server_endpoint,
    };

    match board_settings_operations::update_board_settings(new_settings.clone(), &pool).await {
        Ok(updated_settings) => Ok(Json(updated_settings)),
        // if the settings do not exist, insert them instead
        Err(DbErr::RecordNotFound(_)) => Ok(Json(
            board_settings_operations::insert_board_settings(new_settings, &pool).await?,
        )),
        Err(e) => Err(AppError::Internal(e.to_string())),
    }
}
