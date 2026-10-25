mod board_routes;

mod board_settings_routes;

mod firmware_routes;

use crate::{auth, db::DbPool};
use axum::{
    middleware::from_fn,
    routing::{get, post, put},
    Router,
};
use tower_http::services::ServeDir;

pub fn router() -> Router<DbPool> {
    // Open to guests: read-only board list and counts
    let guest = Router::new()
        .route("/get-board-data", get(board_routes::get_board_data))
        .route(
            "/get-board-prediction",
            get(board_routes::get_board_data_predictions),
        )
        .route("/get-board", get(board_routes::get_board))
        .route("/get-all-boards", get(board_routes::get_all_boards));

    let admin = Router::new()
        .route("/rename-board", put(board_routes::rename_board))
        .route(
            "/board-settings",
            put(board_settings_routes::update_board_settings),
        )
        .route_layer(from_fn(auth::require_admin));

    let board = Router::new()
        .route("/upload-board-data", post(board_routes::upload_board_data))
        .route(
            "/board-settings",
            post(board_settings_routes::insert_board_settings),
        )
        // firmware updates: boards poll /firmware/latest, then download /firmware/bin/<version>.bin
        .route("/firmware/latest", get(firmware_routes::latest_firmware))
        .nest_service(
            "/firmware/bin",
            ServeDir::new(firmware_routes::firmware_dir()),
        )
        .route_layer(from_fn(auth::require_board));

    // Settings are private, but both the board and the admin app read them
    let admin_or_board = Router::new()
        .route(
            "/board-settings",
            get(board_settings_routes::get_board_settings_by_mac),
        )
        .route_layer(from_fn(auth::require_admin_or_board));

    guest.merge(admin).merge(board).merge(admin_or_board)
}
