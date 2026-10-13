//! Runtime library for Stellar ROS Bridge.
//!
//! Scaffolding for the runtime task lifecycle and its wiring of a `Transport`
//! to a `Settlement` is tracked by the task-lifecycle work.

use ros_bridge::config::NodeConfig;
use std::error::Error;
use std::path::Path;

/// Health and readiness endpoints for the node.
pub mod health;

/// The crate version, sourced from `Cargo.toml`.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Load node configuration from a parameter file, or use documented defaults.
pub fn load_config(params_file: Option<&Path>) -> Result<NodeConfig, Box<dyn Error>> {
    match params_file {
        Some(path) => NodeConfig::from_parameter_file(path),
        None => Ok(NodeConfig::default()),
    }
}
