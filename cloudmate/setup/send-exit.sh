#!/bin/bash
# Send !pwd to save directory, then exit Claude Code

PANE_ID="$1"

# Send ! first (by itself)
tmux send-keys -t "$PANE_ID" '!'
sleep 0.5

# Use tee to save directory
tmux send-keys -t "$PANE_ID" "pwd | tee /tmp/.cc-dir-${PANE_ID}"
sleep 0.3
tmux send-keys -t "$PANE_ID" Enter
sleep 0.5

# Now send /exit
tmux send-keys -t "$PANE_ID" -l '/exit'
sleep 0.5
tmux send-keys -t "$PANE_ID" Enter
sleep 2
tmux send-keys -t "$PANE_ID" Enter
