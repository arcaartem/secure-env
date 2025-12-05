use anyhow::Result;
use clap::{Parser, Subcommand};
use std::path::PathBuf;

mod commands;
mod config;
mod git;
mod sops;
mod utils;

use config::Config;

#[derive(Parser)]
#[command(name = "senv", version, about = "Secure Environment File Manager")]
#[command(long_about = "Manages encrypted .env files using SOPS (backend-agnostic)")]
struct Cli {
    /// Use specified project instead of current directory name
    #[arg(short = 'p', long, global = true)]
    project: Option<String>,

    /// Use specified secrets repo path
    #[arg(short = 's', long, global = true)]
    secrets_path: Option<PathBuf>,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Initialize senv (interactive backend selection)
    Init,

    /// Decrypt environment and write .env
    Use {
        /// Environment name (e.g., local, staging, production)
        env: String,
    },

    /// Edit encrypted environment file
    Edit {
        /// Environment name to edit
        env: String,
    },

    /// Encrypt current .env back to secrets repo
    Save,

    /// List available environments for current project
    #[command(alias = "ls")]
    List,

    /// Show diff between local .env and stored version
    Diff {
        /// Environment name (defaults to current .env's environment)
        env: Option<String>,
    },

    /// Delete an environment permanently
    #[command(alias = "rm")]
    Delete {
        /// Environment name to delete
        env: String,
    },

    /// Show current project status
    Status,

    /// Print secrets repo path
    #[command(alias = "cd")]
    Repo,

    /// Export all environments as .env.<env> files
    Export {
        /// Export to specified directory (default: current)
        #[arg(long)]
        output_dir: Option<PathBuf>,

        /// Overwrite existing files
        #[arg(long)]
        force: bool,
    },

    /// Import all .env.<env> files into secrets repo
    Import {
        /// Overwrite existing environments in repo
        #[arg(long)]
        force: bool,

        /// Keep source .env files after import (default: delete)
        #[arg(long)]
        keep: bool,
    },

}

fn main() -> Result<()> {
    let cli = Cli::parse();

    let config = Config::new(cli.project, cli.secrets_path)?;

    match cli.command {
        Commands::Init => commands::init::run(&config),
        Commands::Use { env } => commands::use_env::run(&config, &env),
        Commands::Edit { env } => commands::edit::run(&config, &env),
        Commands::Save => commands::save::run(&config),
        Commands::List => commands::list::run(&config),
        Commands::Diff { env } => commands::diff::run(&config, env.as_deref()),
        Commands::Delete { env } => commands::delete::run(&config, &env),
        Commands::Status => commands::status::run(&config),
        Commands::Repo => commands::repo::run(&config),
        Commands::Export { output_dir, force } => {
            commands::export::run(&config, output_dir.as_deref(), force)
        }
        Commands::Import { force, keep } => commands::import::run(&config, force, keep),
    }
}
