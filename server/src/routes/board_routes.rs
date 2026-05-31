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
    match board::add_board(payload.mac_address, payload.name, &pool).await {
        Ok(board) => Ok(Json(board)),
        Err(e) => Err(AppError::Internal(e.to_string())),
    }
}

pub async fn rename_board(
    State(pool): State<DbPool>,
    Json(payload): Json<AddBoardRequest>,
) -> Result<Json<board::Model>, AppError> {
    match board::rename_board(payload.mac_address, payload.name, &pool).await {
        Ok(board) => Ok(Json(board)),
        Err(e) => Err(AppError::Internal(e.to_string())),
    }
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
    // if the board doesnt exist, create it with null name
    match board::get_board_by_mac(payload.mac_address, &pool).await? {
        Some(_board) => {}
        None => {
            //board doesn't exist, create it with null name
            board::add_board(payload.mac_address, String::new(), &pool).await?;
        }
    };

    //upload the data
    let timestamp = chrono::Utc::now().naive_utc();

    match board_data_record::add_board_data_record(
        payload.mac_address,
        timestamp,
        payload.clients_count,
        &pool,
    )
    .await
    {
        Ok(board_data_record) => Ok(Json(board_data_record)),
        Err(err) => Err(AppError::Internal(err.to_string())),
    }
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
    //if the timeRange is not provided, get all records for the board
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
pub struct GetBoardNameQuery {
    pub mac_address: i64,
}
pub async fn get_board_name(
    State(pool): State<DbPool>,
    Query(query): Query<GetBoardNameQuery>,
) -> Result<Json<Option<String>>, AppError> {
    match board::get_board_by_mac(query.mac_address, &pool).await? {
        Some(board) => Ok(Json(Some(board.name))),
        None => Ok(Json(None)),
    }
}
