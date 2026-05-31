use sea_orm::{entity::prelude::*, ActiveValue::Set};
use serde::Serialize;

#[sea_orm::model]
#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize)]
#[sea_orm(table_name = "board_data_records")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub board_id: i64,
    #[sea_orm(belongs_to, from = "board_id", to = "board_mac")]
    pub board: HasOne<super::board::Entity>,
    #[sea_orm(primary_key)]
    pub timestamp: DateTime,
    pub clients_count: i32,
}

// #[derive(Debug, Clone, EnumIter, DeriveRelation)]
// pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}

pub async fn add_board_data_record(
    board_id: i64,
    timestamp: DateTime,
    clients_count: i32,
    db: &DatabaseConnection,
) -> Result<Model, sea_orm::DbErr> {
    let new_record = ActiveModel {
        board_id: Set(board_id),
        timestamp: Set(timestamp),
        clients_count: Set(clients_count),
        ..Default::default()
    };
    new_record.insert(db).await
}

pub async fn get_board_data_records_for_board(
    board_id: i64,
    db: &DatabaseConnection,
) -> Result<Vec<Model>, sea_orm::DbErr> {
    Entity::find()
        .filter(Column::BoardId.eq(board_id))
        .all(db)
        .await
}

pub async fn get_board_data_records_for_board_in_time_range(
    board_id: i64,
    start: DateTime,
    end: DateTime,
    db: &DatabaseConnection,
) -> Result<Vec<Model>, sea_orm::DbErr> {
    Entity::find()
        .filter(Column::BoardId.eq(board_id))
        .filter(Column::Timestamp.gte(start))
        .filter(Column::Timestamp.lte(end))
        .all(db)
        .await
}
