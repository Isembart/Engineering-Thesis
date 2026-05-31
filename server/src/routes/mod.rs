mod board_routes;
// pub mod hello;

use crate::db::DbPool;
use axum::{
    routing::{get, post, put},
    Router,
};

pub fn router() -> Router<DbPool> {
    Router::new()
        // .route("/hello", axum::routing::get(hello::hello_handler))
        .route("/add-board", post(board_routes::add_board))
        .route("/rename-board", put(board_routes::rename_board))
        .route("/upload-board-data", post(board_routes::upload_board_data))
        .route("/get-board-data", get(board_routes::get_board_data))
        .route("/get-board-name", get(board_routes::get_board_name))
        .route("/get-all-boards", get(board_routes::get_all_boards))
}
