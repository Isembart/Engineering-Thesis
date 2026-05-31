use axum::{
    extract::{Query, State},
    Json,
};

use crate::{
    db::DbPool,
    error::AppError,
    model::{board, board_data_record},
};

use serde::Deserialize;

#[derive(Deserialize)]
pub struct AddBoardRequest {
    pub mac_address: i64,
    pub name: String,
}

pub async fn add_board(
    State(pool): State<DbPool>,
    Json(payload): Json<AddBoardRequest>,
) -> Result<Json<board::Model>, AppError> {
    let new_board = board::add_board(payload.mac_address, payload.name, &pool).await?;
    Ok(Json(new_board))
}

pub async fn rename_board(
    State(pool): State<DbPool>,
    Json(payload): Json<AddBoardRequest>,
) -> Result<Json<board::Model>, AppError> {
    let renamed_board = board::rename_board(payload.mac_address, payload.name, &pool).await?;
    Ok(Json(renamed_board))
}

#[derive(Deserialize)]
pub struct UploadBoardDataRequest {
    pub mac_address: i64,
    pub clients_count: i32,
}

pub async fn upload_board_data(
    State(pool): State<DbPool>,
    Json(payload): Json<UploadBoardDataRequest>,
) -> Result<Json<board_data_record::Model>, AppError> {
    let board = board::get_board_by_mac(payload.mac_address, &pool).await?;
    match board {
        Some(_board) => {}
        None => {
            board::add_board(payload.mac_address, String::new(), &pool)
                .await
                .map_err(|e| AppError::Internal(format!("{:?}", e)))?;
        }
    };

    let timestamp = chrono::Utc::now().naive_utc();

    let board_data_record = board_data_record::add_board_data_record(
        payload.mac_address,
        timestamp,
        payload.clients_count,
        &pool,
    )
    .await?;
    Ok(Json(board_data_record))
}

#[derive(Deserialize)]
pub struct GetBoardDataRequest {
    pub mac_address: i64,
    pub start: Option<chrono::NaiveDateTime>,
    pub end: Option<chrono::NaiveDateTime>,
}

pub async fn get_board_data(
    State(pool): State<DbPool>,
    Query(payload): Query<GetBoardDataRequest>,
) -> Result<Json<Vec<board_data_record::Model>>, AppError> {
    let records = if payload.start.is_none() || payload.end.is_none() {
        board_data_record::get_board_data_records_for_board(payload.mac_address, &pool).await?
    } else {
        board_data_record::get_board_data_records_for_board_in_time_range(
            payload.mac_address,
            payload.start.unwrap(),
            payload.end.unwrap(),
            &pool,
        )
        .await?
    };

    Ok(Json(records))
}

#[derive(Deserialize)]
pub struct GetBoardQuery {
    pub mac_address: i64,
}

pub async fn get_board(
    State(pool): State<DbPool>,
    Query(query): Query<GetBoardQuery>,
) -> Result<Json<board::Model>, AppError> {
    match board::get_board_by_mac(query.mac_address, &pool).await? {
        Some(board) => Ok(Json(board)),
        None => Err(AppError::NotFound),
    }
}

pub async fn get_all_boards(
    State(pool): State<DbPool>,
) -> Result<Json<Vec<board::Model>>, AppError> {
    let boards = board::get_all_boards(&pool).await?;
    Ok(Json(boards))
}
