#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/unitree/robot-os/third_party/inspire_hand_ws"
VENV="$BASE_DIR/.venv"
DRIVER="$BASE_DIR/inspire_hand_sdk/example/Headless_driver_r.py"

# Activate venv
if [[ -f "$VENV/bin/activate" ]]; then
  # shellcheck disable=SC1090
  source "$VENV/bin/activate"
else
  echo "Virtualenv not found at $VENV" >&2
  exit 1
fi

# Start headless driver if not running
if pgrep -f "$DRIVER" >/dev/null 2>&1; then
  echo "Headless driver already running."
else
  echo "Starting headless driver (right hand)..."
  nohup python "$DRIVER" >/dev/null 2>&1 &
  sleep 1
fi

menu() {
  echo
  echo "Select state: [o]pen, [c]lose, [p]inch, [q]uit"
  printf "> "
}

send_state() {
  local state="$1"
  STATE="$state" python - << 'PY'
import time
import numpy as np
import os
from unitree_sdk2py.core.channel import ChannelPublisher, ChannelFactoryInitialize
from inspire_sdkpy import inspire_hand_defaut, inspire_dds

# Bind to eth0 as in examples
ChannelFactoryInitialize(0, 'eth0')
pubr = ChannelPublisher('rt/inspire_hand/ctrl/r', inspire_dds.inspire_hand_ctrl)
pubr.Init()

def send_angles(target, steps=30, dt=0.05):
    cmd = inspire_hand_defaut.get_inspire_hand_ctrl()
    cmd.mode = 0b0001  # angle mode
    start = np.array([200,200,200,200,200,500], dtype=int)
    target = np.array(target, dtype=int)
    for a in np.linspace(start, target, steps):
        cmd.angle_set = a.astype(int).tolist()
        pubr.Write(cmd)
        time.sleep(dt)

def hold(target, duration=1.0, dt=0.1):
    cmd = inspire_hand_defaut.get_inspire_hand_ctrl()
    cmd.mode = 0b0001
    cmd.angle_set = target
    t = time.time() + duration
    while time.time() < t:
        pubr.Write(cmd)
        time.sleep(dt)

# Presets (exact values from earlier)
OPEN  = [200,200,200,200,200,500]
CLOSE = [800,800,800,800,800,500]
PINCH = [200,200,200,800,800,600]

# Read desired state from environment
state = os.environ.get('STATE','').strip().upper()
if state == 'OPEN':
    target = OPEN
elif state == 'CLOSE':
    target = CLOSE
elif state == 'PINCH':
    target = PINCH
else:
    raise SystemExit('Unknown state: ' + state)

send_angles(target)
hold(target)
print('Sent', state)
PY
}

while true; do
  menu
  read -r choice || exit 0
  case "$choice" in
    o|O)
      send_state OPEN
      ;;
    c|C)
      send_state CLOSE
      ;;
    p|P)
      send_state PINCH
      ;;
    q|Q)
      echo "Bye."
      exit 0
      ;;
    *)
      echo "Invalid choice."
      ;;
  esac
done


