use sea_orm_migration::prelude::*;

pub struct Migration;

impl MigrationName for Migration {
    fn name(&self) -> &str {
        "m20261020_172129_remove_timezone"
    }
}

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    // Rewrites every timestamp to UTC, keeping the fractional seconds:
    // "2026-10-12T18:56:41.948772535+02:00" -> "2026-10-12T16:56:41.948772535+00:00".
    // With one offset everywhere, text comparison and ordering match time order.
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .get_connection()
            .execute_unprepared(
                "UPDATE board_data_records
                 SET timestamp = strftime('%Y-%m-%dT%H:%M:%S', timestamp)
                     || substr(timestamp, 20, length(timestamp) - 25)
                     || '+00:00'
                 WHERE timestamp NOT LIKE '%+00:00'",
            )
            .await?;
        Ok(())
    }

    // The original offsets are not kept, and UTC values are still valid instants.
    async fn down(&self, _manager: &SchemaManager) -> Result<(), DbErr> {
        Ok(())
    }
}
