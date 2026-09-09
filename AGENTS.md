# Project instructions

## Work style

- Infer routine intent from the request and repository context. Complete authorized, reversible work without repeatedly asking for confirmation.
- User instructions take precedence over skill guidance. If an instruction file or skill makes you pause or leave requested work unfinished, name the exact file and rule.
- Lead with the result. Use concise, plain language and only enough formatting to make the answer easy to scan.
- Match reasoning, tests, and verification to the risk of the change. Run the focused checks once after the final edit; broaden them only when a failure or unresolved risk justifies it.
- Use subagents only when the user explicitly authorizes them and the work can be split into independent tasks.

These practices follow the [GPT-6 Astra prompting guidance](https://developers.openai.com/api/docs/guides/latest-model#prompting-best-practices), reviewed 2026-09-09.

## Repository map

- `install.sh`: validates setup, learns a power-source rule, and manages the per-user LaunchAgent.
- `watch-power`: observes power/source state and owns Bluetooth disconnect/restore decisions.
- `lib/source.sh`: reads and matches stable macOS hardware identities.
- `uninstall.sh`: stops the canonical LaunchAgent and leaves configuration, state, and logs.
- `tests/run.sh`: runs simulated hardware and service tests without touching the user's Bluetooth devices or LaunchAgents.

## Safety and scope

- Preserve unrelated and untracked work. Never edit `.serena/`.
- Source changes, local commits, installation, publishing, tags, and GitHub releases are separate actions.
- `install.sh` and `uninstall.sh` affect the logged-in user's real service. Do not run them during automated tests or ordinary source verification.
- Do not connect or disconnect real Bluetooth devices during automated tests. Substitute the external power, hardware, Bluetooth, clock, sleep, and LaunchAgent boundaries.
- Do not add telemetry, accounts, cloud services, automatic Bluetooth pairing, or Bluetooth-radio toggling.
- Keep scripts compatible with macOS Bash 3.2 and both Apple Silicon and Intel Homebrew paths.

## Verification

Run:

```bash
bash -n install.sh uninstall.sh watch-power lib/source.sh tests/run.sh
bash tests/run.sh
```

Run `shellcheck install.sh uninstall.sh watch-power lib/source.sh tests/run.sh` when ShellCheck is already installed. Report simulated verification separately from physical hardware acceptance.
