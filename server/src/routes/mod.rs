mod board_routes;

mod board_settings_routes;

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
        .route("/get-board", get(board_routes::get_board))
        .route("/get-all-boards", get(board_routes::get_all_boards))
        // board settings routes
        .route(
            "/board-settings",
            get(board_settings_routes::get_board_settings_by_mac),
        )
        .route(
            "/board-settings",
            post(board_settings_routes::insert_board_settings),
        )
        .route(
            "/board-settings",
            put(board_settings_routes::update_board_settings),
        )
}
