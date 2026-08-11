use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, DatabaseConnection, DbErr::RecordNotFound,
    EntityTrait, QueryFilter,
};

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

pub async fn update_board_settings(
    settings: board_settings::Model,
    db: &DatabaseConnection,
) -> Result<board_settings::Model, sea_orm::DbErr> {
    let existing_settings = match board_settings::Entity::find()
        .filter(board_settings::Column::BoardId.eq(settings.board_id))
        .one(db)
        .await?
    {
        Some(existing_settings) => existing_settings,
        None => {
            return Err(RecordNotFound(format!("Board settings not found",)));
        }
    };

    let mut active_model: board_settings::ActiveModel = existing_settings.into();
    active_model.scans_per_send = Set(settings.scans_per_send);
    active_model.wifi_scan_time = Set(settings.wifi_scan_time);
    active_model.bluetooth_scan_time = Set(settings.bluetooth_scan_time);
    active_model.wifi_channel_scan_time = Set(settings.wifi_channel_scan_time);
    active_model.bluetooth_channel_scan_time = Set(settings.bluetooth_channel_scan_time);
    active_model.minimal_encounter_count = Set(settings.minimal_encounter_count);
    active_model.min_rssi = Set(settings.min_rssi);
    // active_model.server_endpoint = Set(settings.server_endpoint);
    active_model.update(db).await
}

pub async fn insert_board_settings(
    settings: board_settings::Model,
    db: &DatabaseConnection,
) -> Result<board_settings::Model, sea_orm::DbErr> {
    let active_model: board_settings::ActiveModel = settings.into();
    active_model.insert(db).await
}
