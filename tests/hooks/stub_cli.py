"""Stand-in for the bluebox CLI. STUB_MODE picks a CLI with or without `hooks`."""

import os
import sys
import time


def main() -> int:
    data = sys.stdin.buffer.read()
    log = os.environ.get("STUB_LOG")
    if log:
        with open(log, "ab") as f:
            f.write(" ".join(sys.argv[1:]).encode() + b"\n" + data + b"\n")
    time.sleep(float(os.environ.get("STUB_SLEEP", "0")))
    if os.environ.get("STUB_MODE") == "hooks" and sys.argv[1:2] == ["hooks"]:
        sys.stdout.write("cli says hi to the model\n")
        sys.stderr.write("cli says hi to the user\n")
        return int(os.environ.get("STUB_EXIT", "0"))
    # A release before the hooks command: the CLI's unknown-command error.
    sys.stderr.write(f"unknown command: {sys.argv[1] if len(sys.argv) > 1 else ''}\n")
    sys.stderr.write("Usage: bluebox <command> [arguments]\n")
    return 1


if __name__ == "__main__":
    sys.exit(main())
