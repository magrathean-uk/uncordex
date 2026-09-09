After installation, open Uncordex from Applications. The package alone does not start the background service.

The app requires blueutil, available with `brew install blueutil`. In the app, open Speaker & Rule, discover your paired speaker and connected source, preview the rule, then choose Save & Start. That explicit action installs and starts the logged-in user's background service.

Installing or upgrading the app preserves existing per-user configuration, state, logs, and LaunchAgents. Apply setup in the updated app when you want to update the running service files.
