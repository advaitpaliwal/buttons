# Buttons

Buttons is a native macOS app for creating, running, customizing, and sharing one-click AI workflow buttons.

The app opens directly to a button board. Every button is a saved prompt with a physical button face. The user can design the face, set a category, write the prompt, choose Codex or Claude Code, choose a model override, choose thinking level, choose permission level, and review every run log.

Buttons does not store OpenAI or Anthropic API keys. It runs the locally installed Codex or Claude Code CLI using the login already present on the Mac.

Buttons keeps its runtime state in `~/.buttons`. Each button gets its own editable slug workspace at `~/.buttons/buttons/<slug>/` with:

- `button.md` for the current button instructions and latest run prompt.
- `logs/` for per-run logs.

Every button is a saved prompt, but the board separates opening from running. Click the button face to enter the button room. Click the visible play control to run the saved prompt, show live state, and save the run log.

Each button is a tactile object with distinct affordances. The face opens the button room where the prompt, face, category, execution details, live state, and logs live together. The play control runs the saved prompt. Buttons set to always confirm, or buttons whose permission mode requires confirmation, open an armed run state first. Safe play presses start immediately and show live state. While a run is active, another play press focuses the live run instead of starting a duplicate; the live run exposes Stop and saves a stopped receipt when canceled.

## Build

```sh
swift build
swift test
scripts/package-buttons-app.sh debug
open .build/debug/Buttons.app
```

Build a local release DMG:

```sh
scripts/build-dmg.sh release
open dist
```

GitHub Actions builds the same DMG on every push to `main` and exposes it as the `Buttons.dmg` workflow artifact.

## Button runtime

- Prompt button workflow
- Codex or Claude Code runner
- Optional model override
- Thinking level
- Permission mode
- One saved prompt per button; risky runs let the user review before launch.
- Per-button workspace under `~/.buttons/buttons/<slug>/`
- Per-button run logs
- The saved prompt is the only user-provided run input for a button click.

Dangerous agent buttons require approval by default.

The “Star Repo” starter has no repository preselected. Edit its saved prompt to
name the repository you want; without one, the prompt instructs the agent to
report failure rather than infer a target from your workspace or account.
Existing saved prompts are preserved, not rewritten to promote this repository.

## Local agents

Authenticate the local CLIs before running agent buttons:

```sh
codex login
claude auth login
```

Agent permissions map directly to the CLI permission modes:

- Answer only: read-only Codex / plan-mode Claude.
- Workspace write: workspace-write Codex / auto Claude.
- Dangerous run: Codex `--dangerously-bypass-approvals-and-sandbox` or Claude `--dangerously-skip-permissions`.
