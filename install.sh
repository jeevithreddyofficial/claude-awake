#!/bin/bash
# Installs cw, cw-on and cw-off.
#   curl -fsSL https://raw.githubusercontent.com/jeevithreddyofficial/claude-awake/main/install.sh | bash
set -e

URL="https://raw.githubusercontent.com/jeevithreddyofficial/claude-awake/main/cw"
DEST="/usr/local/bin"

if [ "$(uname)" != "Darwin" ]; then
  echo "cw only works on macOS."; exit 1
fi

echo "Installing cw to $DEST (you may be asked for your Mac password)..."
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
curl -fsSL "$URL" -o "$tmp"

sudo mkdir -p "$DEST"
sudo install -m 755 "$tmp" "$DEST/cw"
sudo ln -sf cw "$DEST/cw-on"
sudo ln -sf cw "$DEST/cw-off"

echo
echo "Installed: cw, cw-on, cw-off"

case ":$PATH:" in
  *":$DEST:"*) ;;
  *)
    echo
    echo "Note: $DEST is not on your PATH. Run this, then open a new Terminal window:"
    echo "  echo 'export PATH=\"$DEST:\$PATH\"' >> ~/.zshrc"
    ;;
esac

if ! command -v claude >/dev/null 2>&1; then
  echo
  echo "Claude Code isn't installed yet. Install it with:"
  echo "  curl -fsSL https://claude.ai/install.sh | bash"
fi

echo
echo "Run 'cw' to start."
