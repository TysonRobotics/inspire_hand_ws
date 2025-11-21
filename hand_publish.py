#!/usr/bin/env python3
import argparse
import time
import numpy as np
import os
from typing import List

from unitree_sdk2py.core.channel import ChannelPublisher, ChannelFactoryInitialize
from inspire_sdkpy import inspire_hand_defaut, inspire_dds


def send_angles(pubr: ChannelPublisher, target: List[int], steps: int = 30, dt: float = 0.05) -> None:
    cmd = inspire_hand_defaut.get_inspire_hand_ctrl()
    cmd.mode = 0b0001  # angle mode
    start = np.array([200, 200, 200, 200, 200, 500], dtype=int)
    target_np = np.array(target, dtype=int)
    for a in np.linspace(start, target_np, steps):
        cmd.angle_set = a.astype(int).tolist()
        pubr.Write(cmd)
        time.sleep(dt)


def hold(pubr: ChannelPublisher, target: List[int], duration: float = 1.0, dt: float = 0.1) -> None:
    cmd = inspire_hand_defaut.get_inspire_hand_ctrl()
    cmd.mode = 0b0001
    cmd.angle_set = target
    t = time.time() + duration
    while time.time() < t:
        pubr.Write(cmd)
        time.sleep(dt)


def main() -> int:
    parser = argparse.ArgumentParser(description="Publish Inspire hand gesture via DDS")
    parser.add_argument("--hand", choices=["l", "r"], required=True, help="Which hand to control")
    parser.add_argument("--gesture", choices=["open", "close", "pinch"], required=True, help="Gesture to perform")
    parser.add_argument("--nic", default=os.environ.get("DDS_NIC", "eth0"), help="DDS network interface (default: eth0)")
    args = parser.parse_args()

    # Initialize DDS
    if args.nic:
        ChannelFactoryInitialize(0, args.nic)
    else:
        ChannelFactoryInitialize(0)

    topic = f"rt/inspire_hand/ctrl/{args.hand}"
    pub = ChannelPublisher(topic, inspire_dds.inspire_hand_ctrl)
    pub.Init()

    # Note: OPEN/CLOSE as requested (previously reversed)
    OPEN: List[int] = [800, 800, 800, 800, 800, 500]
    CLOSE: List[int] = [200, 200, 200, 200, 200, 500]
    PINCH: List[int] = [200, 200, 200, 800, 800, 600]

    if args.gesture == "open":
        target = OPEN
    elif args.gesture == "close":
        target = CLOSE
    else:
        target = PINCH

    send_angles(pub, target)
    hold(pub, target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())



