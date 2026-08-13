use sea_orm_migration::{prelude::*, schema::*};

use crate::m20260808_141636_create_board_settings::BoardSettings;

pub struct Migration;

impl MigrationName for Migration {
    fn name(&self) -> &str {
        "m20260813_204810_add_min_ble_rssi_and_add__ms_to_settings_names"
    }
}

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, _manager: &SchemaManager) -> Result<(), DbErr> {
        _manager
            .alter_table(
                Table::alter()
                    .table(BoardSettings::Table)
                    .rename_column("wifi_scan_time", "wifi_scan_time_ms")
                    .to_owned(),
            )
            .await?;

        _manager
            .alter_table(
                Table::alter()
                    .table(BoardSettings::Table)
                    .rename_column("bluetooth_scan_time", "bluetooth_scan_time_ms")
                    .to_owned(),
            )
            .await?;
        _manager
            .alter_table(
                Table::alter()
                    .table(BoardSettings::Table)
                    .rename_column("wifi_channel_scan_time", "wifi_channel_scan_time_ms")
                    .to_owned(),
            )
            .await?;
        _manager
            .alter_table(
                Table::alter()
                    .table(BoardSettings::Table)
                    .add_column(integer("min_rssi_ble").default(-85))
                    .to_owned(),
            )
            .await?;

        _manager
            .alter_table(
                Table::alter()
                    .table(BoardSettings::Table)
                    .drop_column("bluetooth_channel_scan_time")
                    .to_owned(),
            )
            .await
    }

    async fn down(&self, _manager: &SchemaManager) -> Result<(), DbErr> {
        _manager
            .alter_table(
                Table::alter()
                    .table(BoardSettings::Table)
                    .rename_column("wifi_scan_time_ms", "wifi_scan_time")
                    .to_owned(),
            )
            .await?;

        _manager
            .alter_table(
                Table::alter()
                    .table(BoardSettings::Table)
                    .rename_column("bluetooth_scan_time_ms", "bluetooth_scan_time")
                    .to_owned(),
            )
            .await?;
        _manager
            .alter_table(
                Table::alter()
                    .table(BoardSettings::Table)
                    .rename_column("wifi_channel_scan_time_ms", "wifi_channel_scan_time")
                    .to_owned(),
            )
            .await?;
        _manager
            .alter_table(
                Table::alter()
                    .table(BoardSettings::Table)
                    .drop_column("min_rssi_ble")
                    .to_owned(),
            )
            .await?;

        _manager
            .alter_table(
                Table::alter()
                    .table(BoardSettings::Table)
                    .add_column(integer("bluetooth_channel_scan_time").default(1000))
                    .to_owned(),
            )
            .await
    }
}
