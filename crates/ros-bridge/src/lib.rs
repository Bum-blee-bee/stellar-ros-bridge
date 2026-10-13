//! ROS 2 integration via [`rclrs`](https://github.com/ros2-rust/ros2_rust).
//!
//! Scaffolding only. The transport implementation behind the `ros` feature is
//! tracked by the "ROS 2 rclrs transport" Wave issue. Building with `--features
//! ros` will require a sourced ROS 2 (Jazzy+) environment.

pub mod config;

/// The crate version, sourced from `Cargo.toml`.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
