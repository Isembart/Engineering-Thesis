use sea_orm::entity::prelude::*;
use sea_orm::{DatabaseConnection, DbErr, EntityTrait, QuerySelect};
use serde::Serialize;

use crate::db::DbPool;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Serialize)]
#[sea_orm(table_name = "hello")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: i32,
    pub message: String,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}

pub async fn get_first(pool: DbPool) -> Result<Model, DbErr> {
    let db: &DatabaseConnection = &*pool;
    let res = Entity::find().limit(1).one(db).await?;
    match res {
        Some(model) => Ok(model),
        None => Err(DbErr::RecordNotFound("No rows".into())),
    }
}
