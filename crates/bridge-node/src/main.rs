//! Command-line entry point for Stellar ROS Bridge.

use std::env;
use std::error::Error;
use std::io;
use std::path::PathBuf;

fn main() -> Result<(), Box<dyn Error>> {
    let mut args = env::args().skip(1);
    let mut params_file: Option<PathBuf> = None;

    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--params-file" => {
                let path = args.next().ok_or_else(|| {
                    io::Error::new(
                        io::ErrorKind::InvalidInput,
                        "--params-file requires a file path",
                    )
                })?;
                params_file = Some(PathBuf::from(path));
            }
            "--help" | "-h" => {
                println!(
                    "Usage: bridge-node [--params-file PATH]\n\
                     Alternatively, set ROS_BRIDGE_PARAMS_FILE to a parameter file."
                );
                return Ok(());
            }
            _ => {
                return Err(io::Error::new(
                    io::ErrorKind::InvalidInput,
                    format!("Unknown argument: {arg}"),
                )
                .into());
            }
        }
    }

    let params_file =
        params_file.or_else(|| env::var_os("ROS_BRIDGE_PARAMS_FILE").map(PathBuf::from));

    let config = bridge_node::load_config(params_file.as_deref())?;

    // Set this before any future ROS context initialization.
    env::set_var("ROS_DOMAIN_ID", config.ros_domain_id.to_string());

    tracing::info!(
        version = bridge_node::VERSION,
        capabilities_topic = %config.capabilities_topic,
        tasks_topic = %config.tasks_topic,
        proofs_topic = %config.proofs_topic,
        ros_domain_id = config.ros_domain_id,
        "Stellar ROS Bridge configuration loaded (transport is scaffolding)"
    );

    println!("stellar-ros-bridge {}", bridge_node::VERSION);
    println!("capabilities_topic={}", config.capabilities_topic);
    println!("tasks_topic={}", config.tasks_topic);
    println!("proofs_topic={}", config.proofs_topic);
    println!("ros_domain_id={}", config.ros_domain_id);
    println!("ROS_DOMAIN_ID={}", env::var("ROS_DOMAIN_ID")?);

    Ok(())
}
