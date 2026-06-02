use sea_orm::{entity::prelude::*, ActiveValue::Set, QueryOrder, QuerySelect, sea_query::Expr};
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
    pub timestamp: DateTimeWithTimeZone,
    pub clients_count: i32,
}

// #[derive(Debug, Clone, EnumIter, DeriveRelation)]
// pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}

pub async fn add_board_data_record(
    board_id: i64,
    timestamp: DateTimeWithTimeZone,
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

pub async fn get_board_data_records(
    board_id: i64,
    start: Option<DateTimeWithTimeZone>,
    end: Option<DateTimeWithTimeZone>,
    bucket_size_minutes: u32,
    db: &DatabaseConnection,
) -> Result<Vec<Model>, sea_orm::DbErr> {
    let mut query = Entity::find().filter(Column::BoardId.eq(board_id));

    if let Some(s) = start {
        query = query.filter(Column::Timestamp.gte(s));
    }
    if let Some(e) = end {
        query = query.filter(Column::Timestamp.lte(e));
    }

    if bucket_size_minutes == 0 {
        return query.order_by_asc(Column::Timestamp).all(db).await;
    }

    let bucket_size_secs = bucket_size_minutes * 60;
    let bucket_expr = Expr::cust_with_values(
        "strftime('%Y-%m-%dT%H:%M:%S+00:00', (CAST(strftime('%s', timestamp) AS INTEGER) / ?) * ?, 'unixepoch')",
        vec![bucket_size_secs, bucket_size_secs]
    );

    query
        .select_only()
        .column(Column::BoardId)
        .column_as(bucket_expr.clone(), "timestamp")
        .column_as(Expr::cust("CAST(ROUND(AVG(clients_count)) AS INTEGER)"), "clients_count")
        .group_by(Column::BoardId)
        .group_by(bucket_expr)
        .order_by_asc(Column::Timestamp)
        .into_model::<Model>()
        .all(db)
        .await
}
