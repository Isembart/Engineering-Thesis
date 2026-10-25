use chrono::{naive, Days, Local, TimeZone, Utc};
use sea_orm::{entity::prelude::*, sea_query::Expr, ActiveValue::Set, QueryOrder, QuerySelect};

use crate::model::board_data_records::{ActiveModel, Column, Entity, Model};

pub async fn add_board_data_record(
    board_id: i64,
    timestamp: DateTimeWithTimeZone,
    clients_count: i64,
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

pub async fn get_board_data_records_bucketed(
    board_id: i64,
    start: Option<DateTimeWithTimeZone>,
    end: Option<DateTimeWithTimeZone>,
    db: &DatabaseConnection,
) -> Result<Vec<Model>, sea_orm::DbErr> {
    let mut query = Entity::find().filter(Column::BoardId.eq(board_id));

    if let Some(s) = start {
        query = query.filter(Column::Timestamp.gte(s));
    }
    if let Some(e) = end {
        query = query.filter(Column::Timestamp.lte(e));
    }

    // FIXED BUCKET SIZE: 1 hour
    let bucket_size_secs = 60 * 60;
    let bucket_expr = Expr::cust_with_values(
        "strftime('%Y-%m-%dT%H:%M:%S+00:00', (CAST(strftime('%s', timestamp) AS INTEGER) / ?) * ?, 'unixepoch')",
        vec![bucket_size_secs, bucket_size_secs]
    );

    query
        .select_only()
        .column_as(Expr::cust("MIN(id)"), "id")
        .column(Column::BoardId)
        .column_as(bucket_expr.clone(), "timestamp")
        .column_as(
            Expr::cust("CAST(ROUND(AVG(clients_count)) AS INTEGER)"),
            "clients_count",
        )
        .group_by(Column::BoardId)
        .group_by(bucket_expr)
        .order_by_asc(Column::Timestamp)
        .into_model::<Model>()
        .all(db)
        .await
}

#[derive(serde::Serialize)]
pub struct HourPrediction {
    pub timestamp: DateTimeUtc,
    pub samples: u8,
    pub mean: Option<f64>,
    pub min: Option<i64>,
    pub max: Option<i64>,
}
// find the timestamp of the same hour X weeks ago, or None if it doesn't exists. Calculates in local time to account for DST changes, then converts back to UTC
fn weeks_ago(t: DateTimeUtc, weeks: u64) -> Option<DateTimeUtc> {
    let localDateTime = t.with_timezone(&Local).naive_local();
    let weeks_ago = localDateTime.checked_sub_days(Days::new(7 * weeks))?;

    let weeks_ago = Local.from_local_datetime(&weeks_ago).single()?;
    Some(weeks_ago.with_timezone(&Utc))
}

fn predict(
    buckets: &std::collections::HashMap<i64, i64>,
    start: DateTimeUtc,
    end: DateTimeUtc,
) -> Vec<HourPrediction> {
    let mut out = Vec::new();
    let mut t = start;
    while t < end {
        // a vector that will contain the values of the same hour in the last 4 weeks, if they exist
        let vals: Vec<i64> = (1..=4)
            .filter_map(|k| weeks_ago(t, k))
            .filter_map(|w| buckets.get(&w.timestamp()).copied())
            .collect();
        out.push(HourPrediction {
            timestamp: t,
            samples: vals.len() as u8,
            mean: (!vals.is_empty()).then(|| vals.iter().sum::<i64>() as f64 / vals.len() as f64),
            min: vals.iter().min().copied(),
            max: vals.iter().max().copied(),
        });
        t += chrono::TimeDelta::hours(1);
    }
    out
}

pub async fn get_board_data_predictions(
    board_id: i64,
    start: DateTimeUtc,
    end: DateTimeUtc,
    db: &DatabaseConnection,
) -> Result<Vec<HourPrediction>, DbErr> {
    // extra hour covers a DST shift; the bucketed query's end is inclusive, so step back 1 s
    let from = start - chrono::TimeDelta::days(28) - chrono::TimeDelta::hours(1);
    let to = end - chrono::TimeDelta::seconds(1);
    let records = get_board_data_records_bucketed(
        board_id,
        Some(from.fixed_offset()),
        Some(to.fixed_offset()),
        db,
    )
    .await?;
    let buckets = records
        .into_iter()
        .map(|r| (r.timestamp.timestamp(), r.clients_count))
        .collect();
    Ok(predict(&buckets, start, end))
}
