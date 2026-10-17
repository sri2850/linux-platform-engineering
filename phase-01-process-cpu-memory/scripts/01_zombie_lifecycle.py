#!/usr/bin/env python3
"""
Simulate zombie process creation and demonstrate reaping lifecycle.
Execution:
    python3 01_zombie_lifecycle.py
"""

import os
import sys
import time


def main():
    print(f"Parent process running with PID: {os.getpid()}")
    pid = os.fork()

    if pid == 0:
        # Child process exits immediately
        print(f"Child process {os.getpid()} exiting to become a zombie...")
        sys.exit(0)
    else:
        # Parent sleeps without invoking wait() or waitpid()
        print(f"Parent sleeping for 60 seconds without calling wait()...")
        print(f"Run in another terminal: ps -ef | grep -E 'defunct|python3'")
        print(f"Notice child {pid} is <defunct>. Attempt: kill -9 {pid}")
        try:
            time.sleep(60)
        except KeyboardInterrupt:
            print("Interrupted.")


if __name__ == "__main__":
    main()
