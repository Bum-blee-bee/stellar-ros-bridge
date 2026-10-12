//! Runtime library for Stellar ROS Bridge.

use ros_bridge::config::NodeConfig;
use std::error::Error;
use std::path::Path;

/// Load node configuration from a parameter file, or use documented defaults.
pub fn load_config(params_file: Option<&Path>) -> Result<NodeConfig, Box<dyn Error>> {
    match params_file {
        Some(path) => NodeConfig::from_parameter_file(path),
        None => Ok(NodeConfig::default()),
    }
}

/// The crate version, sourced from `Cargo.toml`.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

#[cfg(test)]
mod tests {
    use super::load_config;
    use std::fs;
    use std::path::PathBuf;

    #[test]
    fn no_file_uses_documented_defaults() {
        let config = load_config(None).unwrap();
        assert_eq!(config.capabilities_topic, "/robot/capabilities");
        assert_eq!(config.tasks_topic, "/robot/tasks");
        assert_eq!(config.proofs_topic, "/robot/proofs");
        assert_eq!(config.ros_domain_id, 0);
    }

    #[test]
    fn parameter_file_overrides_topics_and_domain() {
        let path: PathBuf = std::env::temp_dir().join(format!(
            "stellar-ros-bridge-params-{}.yaml",
            std::process::id()
        ));
        let yaml = r#"
"/bridge_node":
  ros__parameters:
    capabilities_topic: /custom/capabilities
    tasks_topic: /custom/tasks
    proofs_topic: /custom/proofs
    ros_domain_id: 42
"#;
        fs::write(&path, yaml).unwrap();
        let result = load_config(Some(&path));
        let _ = fs::remove_file(&path);

        let config = result.unwrap();
        assert_eq!(config.capabilities_topic, "/custom/capabilities");
        assert_eq!(config.tasks_topic, "/custom/tasks");
        assert_eq!(config.proofs_topic, "/custom/proofs");
        assert_eq!(config.ros_domain_id, 42);
    }

    #[test]
    fn missing_parameter_file_returns_error() {
        let path = std::env::temp_dir().join(format!(
            "stellar-ros-bridge-missing-{}.yaml",
            std::process::id()
        ));
        let _ = fs::remove_file(&path);
        assert!(load_config(Some(&path)).is_err());
    }
}
