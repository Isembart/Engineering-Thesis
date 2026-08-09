use sea_orm::{
    ActiveModelTrait, ColumnTrait, DatabaseConnection,
    DbErr::{self, RecordNotFound},
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
    if let Some(existing_settings) = board_settings::Entity::find()
        .filter(board_settings::Column::BoardId.eq(settings.board_id))
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
            "Board settings for board ID {} not found",
            settings.board_id
        )));
    }
}

pub async fn insert_board_settings(
    settings: board_settings::Model,
    db: &DatabaseConnection,
) -> Result<board_settings::Model, sea_orm::DbErr> {
    if let None = boards::Entity::find()
        .filter(boards::Column::Id.eq(settings.board_id))
        .one(db)
        .await?
    {
        return Err(RecordNotFound(format!(
            "Board with ID {} not found",
            settings.board_id
        )));
    }
    let active_model: board_settings::ActiveModel = settings.into();
    active_model.insert(db).await
}
