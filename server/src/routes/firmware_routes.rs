use axum::{
    extract::{Query, State},
    Json,
};
use serde::Deserialize;
use serde_json::{json, Value};

use crate::{db::DbPool, error::AppError, model_operations::boards_operations};

/// Directory holding published firmware images named `<version>.bin`.
pub fn firmware_dir() -> String {
    std::env::var("FIRMWARE_DIR").unwrap_or_else(|_| "./firmware".into())
}

/// Highest version among files named exactly `<version>.bin`, 0 when there is none.
/// Anything else (partial uploads, `007.bin`) is ignored, boards download `<version>.bin`.
fn latest_version(file_names: &[String]) -> u32 {
    file_names
        .iter()
        .filter_map(|name| {
            let version: u32 = name.strip_suffix(".bin")?.parse().ok()?;
            (format!("{version}.bin") == *name).then_some(version)
        })
        .max()
        .unwrap_or(0)
}

#[derive(Deserialize)]
pub struct LatestFirmwareQuery {
    pub mac_address: i64,
    pub version: i64,
}

/// Boards call this every cycle: it records the version they run and tells them the
/// latest published one. A board confirms a freshly installed firmware only after this
/// answers, so it must keep returning 200 with a `version` number.
pub async fn latest_firmware(
    State(pool): State<DbPool>,
    Query(query): Query<LatestFirmwareQuery>,
) -> Result<Json<Value>, AppError> {
    boards_operations::set_firmware_version(query.mac_address, query.version, &pool).await?;

    let file_names: Vec<String> = std::fs::read_dir(firmware_dir())
        .map(|dir| {
            dir.filter_map(|entry| entry.ok()?.file_name().into_string().ok())
                .collect()
        })
        .unwrap_or_default();

    Ok(Json(json!({ "version": latest_version(&file_names) })))
}

#[cfg(test)]
mod tests {
    use super::latest_version;

    #[test]
    fn picks_highest_well_formed_version() {
        let names = ["2.bin", "10.bin", "11.bin.part", "012.bin", "notes.txt", "x.bin"]
            .map(String::from);
        assert_eq!(latest_version(&names), 10);
        assert_eq!(latest_version(&[]), 0);
    }
}
