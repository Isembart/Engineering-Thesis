use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, DatabaseConnection, DbErr::RecordNotFound,
    EntityTrait, QueryFilter,
};
use serde::{Deserialize, Serialize};

use crate::model::{board_settings, boards};

pub async fn get_settings_by_board_mac(
    board_mac: i64,
    db: &DatabaseConnection,
) -> Result<Option<board_settings::Model>, sea_orm::DbErr> {
    if let Some(board) = boards::Entity::find()
        .filter(boards::Column::BoardMac.eq(board_mac))
        .one(db)
        .await?
    {
        board_settings::Entity::find()
            .filter(board_settings::Column::BoardId.eq(board.id))
            .one(db)
            .await
    } else {
        Err(RecordNotFound(format!(
            "Board with MAC {} not found",
            board_mac
        )))
    }
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

pub async fn update_board_settings(
    mac_address: i64,
    settings: BoardSettingsDTO,
    db: &DatabaseConnection,
) -> Result<board_settings::Model, sea_orm::DbErr> {
    let board = match boards::Entity::find()
        .filter(boards::Column::BoardMac.eq(mac_address))
        .one(db)
        .await?
    {
        Some(board) => board,
        None => {
            return Err(RecordNotFound(format!(
                "Board with MAC {} not found",
                mac_address
            )))
        }
    };

    if let Some(existing_settings) = board_settings::Entity::find()
        .filter(board_settings::Column::BoardId.eq(board.id))
        .one(db)
        .await?
    {
        let mut active_model: board_settings::ActiveModel = existing_settings.into();
        let json = serde_json::to_value(&settings).map_err(|e| {
            sea_orm::DbErr::Custom(format!("Failed to serialize settings to JSON: {}", e))
        })?;
        active_model.set_from_json(json)?;
        active_model.update(db).await
    } else {
        return Err(RecordNotFound(format!(
            "Board settings for board with MAC {} not found",
            mac_address
        )));
    }
}

pub async fn insert_board_settings(
    mac_address: i64,
    settings: BoardSettingsDTO,
    db: &DatabaseConnection,
) -> Result<board_settings::Model, sea_orm::DbErr> {
    let board = match boards::Entity::find()
        .filter(boards::Column::BoardMac.eq(mac_address))
        .one(db)
        .await?
    {
        Some(board) => board,
        None => {
            return Err(RecordNotFound(format!(
                "Board with MAC {} not found",
                mac_address
            )));
        }
    };

    let active_model = board_settings::ActiveModel {
        board_id: Set(board.id),
        scans_per_send: Set(settings.scans_per_send),
        wifi_scan_time: Set(settings.wifi_scan_time),
        bluetooth_scan_time: Set(settings.bluetooth_scan_time),
        wifi_channel_scan_time: Set(settings.wifi_channel_scan_time),
        bluetooth_channel_scan_time: Set(settings.bluetooth_channel_scan_time),
        minimal_encounter_count: Set(settings.minimal_encounter_count),
        min_rssi: Set(settings.min_rssi),
        server_endpoint: Set(settings.server_endpoint),
    };
    active_model.insert(db).await
}
