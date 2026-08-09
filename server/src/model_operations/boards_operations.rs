use sea_orm::{entity::prelude::*, ActiveValue::Set};

use crate::model::boards;

pub async fn add_board(
    mac_address: i64,
    name: Option<String>,
    db: &DatabaseConnection,
) -> Result<boards::Model, sea_orm::DbErr> {
    let new_board = boards::ActiveModel {
        board_mac: Set(mac_address),
        name: Set(name),
        ..Default::default()
    };
    new_board.insert(db).await
}

pub async fn rename_board(
    mac_address: i64,
    new_name: String,
    db: &DatabaseConnection,
) -> Result<boards::Model, sea_orm::DbErr> {
    let board: boards::Model = boards::Entity::find()
        .filter(boards::Column::BoardMac.eq(mac_address))
        .one(db)
        .await?
        .ok_or_else(|| {
            sea_orm::DbErr::RecordNotFound(format!("Board with MAC {} not found", mac_address))
        })?;

    let mut board: boards::ActiveModel = board.into();
    board.name = Set(Some(new_name));
    board.update(db).await
}

pub async fn get_all_boards(db: &DatabaseConnection) -> Result<Vec<boards::Model>, sea_orm::DbErr> {
    boards::Entity::find().all(db).await
}

pub async fn get_board_by_mac(
    mac_address: i64,
    db: &DatabaseConnection,
) -> Result<Option<boards::Model>, sea_orm::DbErr> {
    boards::Entity::find()
        .filter(boards::Column::BoardMac.eq(mac_address))
        .one(db)
        .await
}
