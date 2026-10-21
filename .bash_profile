# Login bash reads this file instead of ~/.profile when it exists, so hand
# off to ~/.profile (which sets PATH and loads ~/.bashrc).
if [ -r "$HOME/.profile" ]; then
  . "$HOME/.profile"
fi
