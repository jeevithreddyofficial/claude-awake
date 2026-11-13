# cw — keep your Mac awake while Claude Code works

Normally a Mac goes to sleep when you close the lid, which stops anything running,
including [Claude Code](https://claude.com/claude-code). `cw` keeps the Mac awake so
Claude can keep working with the lid closed. **This works plugged in or on battery.**

**macOS only.**

## Install

With [Homebrew](https://brew.sh):

```bash
brew install jeevithreddyofficial/tap/cw
```

Or without Homebrew:

```bash
curl -fsSL https://raw.githubusercontent.com/jeevithreddyofficial/claude-awake/main/install.sh | bash
```

You also need Claude Code installed
(`curl -fsSL https://claude.ai/install.sh | bash`).

## Commands

| Command  | What it does |
|----------|--------------|
| `cw`     | Shows whether stay-awake is **ON** or **OFF**. |
| `cw-on`  | Turns stay-awake **ON** and starts Claude Code. Type `claude` for normal mode, or `c` to skip permission prompts. |
| `cw-off` | Turns stay-awake **OFF**, so the Mac sleeps normally again. |

## It turns itself off

You don't have to remember to run `cw-off`. Stay-awake switches **OFF** on its own when:

- you quit Claude Code, **or**
- you close the Terminal window, **or**
- you're unplugged and the battery drops below **10%**. You'll get a notification.

## Why does it ask for my password?

Changing whether a Mac is allowed to sleep is an admin setting, so macOS asks for your
password when you run `cw-on` or `cw-off`. Nothing is stored or sent anywhere.

## Tips

- Don't put the Mac in a bag while it's ON. It can overheat.
- To change the battery cutoff: `CW_MIN_BATTERY=20 cw-on`

## Uninstall

```bash
cw-off
brew uninstall cw                      # if installed with Homebrew
sudo rm /usr/local/bin/cw /usr/local/bin/cw-on /usr/local/bin/cw-off   # if installed with the script
```
