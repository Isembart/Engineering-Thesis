use std::sync::OnceLock;

use axum::{
    extract::Request,
    http::header::AUTHORIZATION,
    middleware::Next,
    response::{IntoResponse, Response},
};
use qrcode::{render::unicode::Dense1x2, QrCode};
use subtle::ConstantTimeEq;

use crate::error::AppError;

// Shorter secrets are refused at startup, `openssl rand -base64 32` gives 44 characters
const MIN_TOKEN_LENGTH: usize = 32;

/// The two shared secrets of a deployment. Guests need neither: they can only read
/// boards and their data.
struct Tokens {
    /// Held by people: lets the app rename boards and read or change their settings.
    admin: String,
    /// Provisioned into every board: lets it upload data, sync settings and fetch firmware.
    board: String,
}

static TOKENS: OnceLock<Tokens> = OnceLock::new();

fn tokens() -> &'static Tokens {
    TOKENS
        .get()
        .expect("auth::init must run before the server starts")
}

fn check_tokens(admin: &str, board: &str) -> Result<(), String> {
    for (name, token) in [("ADMIN_TOKEN", admin), ("BOARD_TOKEN", board)] {
        if token.len() < MIN_TOKEN_LENGTH {
            return Err(format!(
                "{name} must be at least {MIN_TOKEN_LENGTH} characters, generate one with `openssl rand -base64 32`"
            ));
        }
    }
    if admin == board {
        return Err("ADMIN_TOKEN and BOARD_TOKEN must differ".into());
    }
    Ok(())
}

/// Reads both tokens from the environment. The server must not start without them:
/// an unset token silently meaning "no check" is how a deployment ends up open.
pub fn init() -> Result<(), String> {
    let read = |name: &str| std::env::var(name).map_err(|_| format!("{name} must be set"));
    let (admin, board) = (read("ADMIN_TOKEN")?, read("BOARD_TOKEN")?);
    check_tokens(&admin, &board)?;
    TOKENS
        .set(Tokens { admin, board })
        .map_err(|_| "auth::init called twice".to_string())
}

/// Prints the admin token as text and as a QR code the app scans in "Admin access".
pub fn print_admin_token() {
    let token = &tokens().admin;
    println!("Admin token: {token}");
    match QrCode::new(token) {
        // Colors are swapped so the code is dark-on-light in a dark terminal
        Ok(code) => println!(
            "{}",
            code.render::<Dense1x2>()
                .dark_color(Dense1x2::Light)
                .light_color(Dense1x2::Dark)
                .build()
        ),
        Err(e) => eprintln!("Could not render the admin token as a QR code: {e}"),
    }
}

/// True when `header` is `Bearer <token>` for one of the `allowed` tokens.
fn is_authorized(header: Option<&str>, allowed: &[&str]) -> bool {
    let Some(presented) = header.and_then(|h| h.strip_prefix("Bearer ")) else {
        return false;
    };
    // Constant-time comparison, and no early exit between tokens
    allowed.iter().fold(false, |ok, token| {
        ok | bool::from(presented.as_bytes().ct_eq(token.as_bytes()))
    })
}

async fn require(allowed: &[&str], request: Request, next: Next) -> Response {
    let header = request
        .headers()
        .get(AUTHORIZATION)
        .and_then(|value| value.to_str().ok());
    if is_authorized(header, allowed) {
        next.run(request).await
    } else {
        AppError::Unauthorized("Missing or invalid token".into()).into_response()
    }
}

pub async fn require_admin(request: Request, next: Next) -> Response {
    require(&[&tokens().admin], request, next).await
}

pub async fn require_board(request: Request, next: Next) -> Response {
    require(&[&tokens().board], request, next).await
}

pub async fn require_admin_or_board(request: Request, next: Next) -> Response {
    require(&[&tokens().admin, &tokens().board], request, next).await
}

#[cfg(test)]
mod tests {
    use super::{check_tokens, is_authorized};

    #[test]
    fn accepts_only_an_allowed_bearer_token() {
        let allowed = ["admin-secret", "board-secret"];
        assert!(is_authorized(Some("Bearer admin-secret"), &allowed));
        assert!(is_authorized(Some("Bearer board-secret"), &allowed));
        assert!(!is_authorized(
            Some("Bearer board-secret"),
            &["admin-secret"]
        ));
        assert!(!is_authorized(Some("Bearer admin-secre"), &allowed));
        assert!(!is_authorized(Some("admin-secret"), &allowed));
        assert!(!is_authorized(Some("Bearer "), &allowed));
        assert!(!is_authorized(None, &allowed));
    }

    #[test]
    fn rejects_weak_or_shared_tokens() {
        let (a, b) = ("a".repeat(32), "b".repeat(32));
        assert!(check_tokens(&a, &b).is_ok());
        assert!(check_tokens("short", &b).is_err());
        assert!(check_tokens(&a, "short").is_err());
        assert!(check_tokens(&a, &a).is_err());
    }
}
