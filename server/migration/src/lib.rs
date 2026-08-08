pub use sea_orm_migration::prelude::*;

mod m20260725_193502_create_boards_table;
mod m20260808_141636_create_board_settings;
mod m20260808_141701_create_boards_data_records;

pub struct Migrator;

#[async_trait::async_trait]
impl MigratorTrait for Migrator {
    fn migrations() -> Vec<Box<dyn MigrationTrait>> {
        vec![
            Box::new(m20260725_193502_create_boards_table::Migration),
            Box::new(m20260808_141636_create_board_settings::Migration),
            Box::new(m20260808_141701_create_boards_data_records::Migration),
        ]
    }
}
