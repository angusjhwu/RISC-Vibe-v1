#!/bin/bash
#==============================================================================
# RISC-Vibe Pipeline Visualizer Launch Script
#==============================================================================
# This script sets up a Python virtual environment and starts the visualizer.
#
# Usage:
#   ./run_visualizer.sh
#
# Prerequisites:
#   - Python 3.6+
#   - A trace.jsonl file in sim/ (generate with: make trace)
#==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/sim/visualizer/.venv"
VISUALIZER_DIR="$SCRIPT_DIR/sim/visualizer"

echo "========================================"
echo "RISC-Vibe Pipeline Visualizer"
echo "========================================"

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Activate virtual environment
echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Install dependencies
echo "Installing dependencies..."
pip install --quiet -r "$VISUALIZER_DIR/requirements.txt"

# Check for trace file
if [ ! -f "$SCRIPT_DIR/sim/trace.jsonl" ]; then
    echo ""
    echo "WARNING: No trace file found at sim/trace.jsonl"
    echo "Generate one with: make trace TESTPROG=programs/test_fib.hex"
    echo ""
fi

# Start the server
echo ""
echo "Starting visualizer server..."
echo "Open http://localhost:5050 in your browser"
echo "Press Ctrl+C to stop"
echo "========================================"
echo ""

cd "$VISUALIZER_DIR"
python app.py
