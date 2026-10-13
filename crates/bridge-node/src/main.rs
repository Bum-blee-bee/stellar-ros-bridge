#[tokio::main]
async fn main() {
    let address = std::env::var("HEALTH_ADDR").unwrap_or_else(|_| "0.0.0.0:8080".to_owned());

    let listener = match tokio::net::TcpListener::bind(&address).await {
        Ok(listener) => listener,
        Err(error) => {
            tracing::error!(%address, %error, "Failed to bind health server");
            std::process::exit(1);
        }
    };

    tracing::info!(
        version = bridge_node::VERSION,
        %address,
        "Stellar ROS Bridge health server started"
    );

    // No external dependency checks are wired into the current scaffolding yet.
    let state = bridge_node::health::HealthState::new(true);
    if let Err(error) = axum::serve(listener, bridge_node::health::router(state)).await {
        tracing::error!(%error, "Health server stopped unexpectedly");
        std::process::exit(1);
    }
}
