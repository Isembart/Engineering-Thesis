use sea_orm_migration::{prelude::*, schema::*};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(BoardDataRecords::Table)
                    .if_not_exists()
                    .col(pk_auto(BoardDataRecords::Id))
                    .col(integer(BoardDataRecords::BoardId))
                    .col(timestamp_with_time_zone(BoardDataRecords::Timestamp))
                    .col(integer(BoardDataRecords::ClientsCount))
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_board_data_records_board_id")
                            .from(BoardDataRecords::Table, BoardDataRecords::BoardId)
                            .to("boards", "id")
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await

        // manager
        //     .create_foreign_key(
        //         sea_query::ForeignKey::create()
        //             .name("fk_board_data_records_board_id")
        //             .from(BoardDataRecords::Table, BoardDataRecords::BoardId)
        //             .to("Boards", "Id")
        //             .on_delete(ForeignKeyAction::Cascade)
        //             .to_owned(),
        //     )
        //     .await?;
        // Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(BoardDataRecords::Table).to_owned())
            .await
    }
}

#[derive(DeriveIden)]
enum BoardDataRecords {
    Table,
    Id,
    BoardId,
    Timestamp,
    ClientsCount,
}
