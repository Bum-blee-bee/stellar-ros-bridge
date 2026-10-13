//! Runtime library for Stellar ROS Bridge.
//!
//! Scaffolding for the runtime task lifecycle and its wiring of a `Transport`
//! to a `Settlement` is tracked by the task-lifecycle work.

pub mod health;

/// The crate version, sourced from `Cargo.toml`.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
