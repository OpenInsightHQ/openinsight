#!/bin/bash
# Entrypoint script for Python execution container
# Supports two modes:
#   1. REPL mode (REPL_MODE=true): Run the REPL server for fast execution
#   2. Default mode: Run the command passed as arguments (backward compatible)

set -e

# Check if REPL mode is enabled
if [ "$REPL_MODE" = "true" ]; then
    # Run the REPL server
    exec python3 /opt/repl_server.py
else
    # Run the default command or passed arguments
    if [ $# -eq 0 ]; then
        # No arguments, run default Python
        exec python3
    else
        # Run the passed command
        exec "$@"
    fi
fi
