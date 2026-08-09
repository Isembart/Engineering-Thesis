use sea_orm_migration::{prelude::*, schema::*, seaql_migrations::PrimaryKey};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(BoardSettings::Table)
                    .if_not_exists()
                    .col(integer(BoardSettings::BoardId).primary_key())
                    .col(integer(BoardSettings::ScansPerSend))
                    .col(integer(BoardSettings::WifiScanTime))
                    .col(integer(BoardSettings::BluetoothScanTime))
                    .col(integer(BoardSettings::WifiChannelScanTime))
                    .col(integer(BoardSettings::BluetoothChannelScanTime))
                    .col(integer(BoardSettings::MinimalEncounterCount))
                    .col(string(BoardSettings::ServerEndpoint))
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_board_settings_board_id")
                            .from(BoardSettings::Table, BoardSettings::BoardId)
                            .to("boards", "id")
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(BoardSettings::Table).to_owned())
            .await
    }
}

#[derive(DeriveIden)]
enum BoardSettings {
    Table,
    BoardId,
    ScansPerSend,
    WifiScanTime,
    BluetoothScanTime,
    WifiChannelScanTime,
    BluetoothChannelScanTime,
    MinimalEncounterCount,
    ServerEndpoint,
}
