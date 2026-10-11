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
    pub wifi_scan_time_ms: i64,
    pub bluetooth_scan_time_ms: i64,
    pub wifi_channel_scan_time_ms: i64,
    pub minimal_encounter_count: i64,
    pub min_rssi: i64,
    pub min_rssi_ble: i64,
}

impl BoardSettingsDTO {
    /// Same bounds the board enforces in `BoardSettings::tunablesInBounds()`
    /// (board/lib/board_settings/src/board_settings.cpp) and the app in its settings form.
    /// The board ignores settings outside them, so storing such values would only mislead.
    fn validate(&self) -> Result<(), AppError> {
        let bounds = [
            ("scans_per_send", self.scans_per_send, 1, 10),
            ("wifi_scan_time_ms", self.wifi_scan_time_ms, 1000, 5 * 60 * 1000),
            ("bluetooth_scan_time_ms", self.bluetooth_scan_time_ms, 1000, 60 * 1000),
            ("wifi_channel_scan_time_ms", self.wifi_channel_scan_time_ms, 50, 5000),
            ("minimal_encounter_count", self.minimal_encounter_count, 1, 100),
            ("min_rssi", self.min_rssi, -100, 0),
            ("min_rssi_ble", self.min_rssi_ble, -100, 0),
        ];
        for (name, value, min, max) in bounds {
            if value < min || value > max {
                return Err(AppError::BadRequest(format!(
                    "{name} must be between {min} and {max}, got {value}"
                )));
            }
        }
        Ok(())
    }
}

pub async fn insert_board_settings(
    State(pool): State<DbPool>,
    Query(query): Query<BoardSettingsQueryDTO>,
    Json(payload): Json<BoardSettingsDTO>,
) -> Result<Json<board_settings::Model>, AppError> {
    // let new_settings =
    //     board_settings_operations::insert_board_settings(query.mac_address, payload, &pool).await?;
    payload.validate()?;

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
        wifi_scan_time_ms: payload.wifi_scan_time_ms,
        bluetooth_scan_time_ms: payload.bluetooth_scan_time_ms,
        wifi_channel_scan_time_ms: payload.wifi_channel_scan_time_ms,
        minimal_encounter_count: payload.minimal_encounter_count,
        min_rssi: payload.min_rssi,
        min_rssi_ble: payload.min_rssi_ble,
        // server_endpoint: payload.server_endpoint,
    };

    let new_settings = board_settings_operations::insert_board_settings(settings, &pool).await?;

    Ok(Json(new_settings))
}

pub async fn update_board_settings(
    State(pool): State<DbPool>,
    Query(query): Query<BoardSettingsQueryDTO>,
    Json(payload): Json<BoardSettingsDTO>,
) -> Result<Json<board_settings::Model>, AppError> {
    payload.validate()?;

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
        wifi_scan_time_ms: payload.wifi_scan_time_ms,
        bluetooth_scan_time_ms: payload.bluetooth_scan_time_ms,
        wifi_channel_scan_time_ms: payload.wifi_channel_scan_time_ms,
        minimal_encounter_count: payload.minimal_encounter_count,
        min_rssi: payload.min_rssi,
        min_rssi_ble: payload.min_rssi_ble,
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

#[cfg(test)]
mod tests {
    use super::BoardSettingsDTO;

    fn defaults() -> BoardSettingsDTO {
        BoardSettingsDTO {
            scans_per_send: 1,
            wifi_scan_time_ms: 40_000,
            bluetooth_scan_time_ms: 12_000,
            wifi_channel_scan_time_ms: 200,
            minimal_encounter_count: 2,
            min_rssi: -75,
            min_rssi_ble: -85,
        }
    }

    #[test]
    fn rejects_out_of_bounds_settings() {
        assert!(defaults().validate().is_ok());
        assert!(BoardSettingsDTO { scans_per_send: 0, ..defaults() }.validate().is_err());
        assert!(BoardSettingsDTO { wifi_scan_time_ms: 300_001, ..defaults() }.validate().is_err());
        assert!(BoardSettingsDTO { min_rssi_ble: 1, ..defaults() }.validate().is_err());
    }
}
