# cw — keep your Mac awake while Claude Code works

Normally a Mac goes to sleep when you close the lid, which stops anything running —
including [Claude Code](https://claude.com/claude-code). `cw` keeps the Mac awake so
Claude can keep working with the lid closed, then lets it sleep normally again when you're done.

**macOS only.**

## Install

Paste this into Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/jeevithreddyofficial/claude-awake/main/install.sh | bash
```

It may ask for your Mac password. You also need Claude Code installed
(`curl -fsSL https://claude.ai/install.sh | bash`).

## Commands

| Command  | What it does |
|----------|--------------|
| `cw`     | Keeps the Mac awake and starts Claude Code. Type `claude` for normal mode, or `c` to skip permission prompts. |
| `cw-on`  | Keeps the Mac awake without starting Claude. Stays on until you run `cw-off`. |
| `cw-off` | Lets the Mac sleep normally again. Use this if anything ever seems stuck. |
| `cw --status` | Shows whether the Mac is currently being kept awake. |

## When does the Mac go back to sleeping normally?

You don't need to remember to turn it off. When you use `cw`, normal sleep comes back on its own when:

- you quit Claude Code, **or**
- you close the Terminal window, **or**
- you're unplugged and the battery drops below 20%. You'll get a notification and
  the Mac can sleep again, so it doesn't run itself flat.

`cw-on` only stops on `cw-off` or low battery.

## Why does it ask for my password?

Changing whether a Mac is allowed to sleep is an admin setting, so macOS asks for your
password each time you start `cw` or `cw-on`. Nothing is stored or sent anywhere.

## Tips

- Plug in for long tasks.
- Don't put the Mac in a bag while it's awake. It can overheat.
- To change the battery cutoff: `CW_MIN_BATTERY=30 cw`

## Uninstall

```bash
cw-off
sudo rm /usr/local/bin/cw /usr/local/bin/cw-on /usr/local/bin/cw-off
```
