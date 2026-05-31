use sea_orm::{entity::prelude::*, ActiveValue::Set};
use serde::Serialize;

#[sea_orm::model]
#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize)]
#[sea_orm(table_name = "boards")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub board_mac: i64,
    #[sea_orm(nullable)]
    pub name: String,
    #[sea_orm(has_many)]
    pub data_records: HasMany<super::board_data_record::Entity>,
}

// Alias for better readability, only accessible in this file
type Board = Model;

impl ActiveModelBehavior for ActiveModel {}

pub async fn add_board(
    mac_address: i64,
    name: String,
    db: &DatabaseConnection,
) -> Result<Board, sea_orm::DbErr> {
    let new_board = ActiveModel {
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
) -> Result<Board, sea_orm::DbErr> {
    let board: Board = Entity::find_by_id(mac_address)
        .one(db)
        .await?
        .ok_or_else(|| {
            sea_orm::DbErr::RecordNotFound(format!("Board with MAC {} not found", mac_address))
        })?;

    let mut board: ActiveModel = board.into();
    board.name = Set(new_name);
    board.update(db).await
}

pub async fn get_board_by_mac(
    mac_address: i64,
    db: &DatabaseConnection,
) -> Result<Option<Board>, sea_orm::DbErr> {
    Entity::find_by_id(mac_address).one(db).await
}
