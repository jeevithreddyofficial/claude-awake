# claude-awake

Run [Claude Code](https://claude.com/claude-code) on macOS and keep your Mac awake, even with the lid closed.

## Install

```bash
curl -o /usr/local/bin/claude-awake https://raw.githubusercontent.com/jeevithreddyofficial/claude-awake/main/claude-awake
chmod +x /usr/local/bin/claude-awake
```

## Usage

```
claude-awake            start Claude Code (extra args are passed to claude)
claude-awake --off      emergency reset: turn normal sleep back on
claude-awake --status   show whether lid-closed mode is on
```

After starting, type `claude` to launch Claude Code normally, or `c` to launch it with `--dangerously-skip-permissions`.

Normal sleep is restored automatically when Claude Code exits, the Terminal window closes, or the battery drops below `MIN_BATTERY` (default 20%) while unplugged.

Requires `sudo` once per run (uses `pmset disablesleep`).
