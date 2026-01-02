"""
RISC-Vibe Pipeline Visualizer - Flask Backend

Provides REST API endpoints for the pipeline visualization frontend.
Handles trace file uploads and provides cycle-by-cycle pipeline state.
"""

import os
import tempfile
from flask import Flask, request, jsonify, render_template
from werkzeug.utils import secure_filename

from trace_parser import TraceParser


# Flask application setup
app = Flask(
    __name__,
    template_folder='templates',
    static_folder='static'
)

# Configuration
app.config['MAX_CONTENT_LENGTH'] = 100 * 1024 * 1024  # 100MB max upload
app.config['DEBUG'] = os.environ.get('FLASK_DEBUG', 'false').lower() == 'true'

# Global trace parser instance
_trace_parser: TraceParser | None = None


def get_parser() -> TraceParser | None:
    """Get the current trace parser instance."""
    return _trace_parser


def set_parser(parser: TraceParser | None) -> None:
    """Set the trace parser instance."""
    global _trace_parser
    _trace_parser = parser


# CORS middleware for local development
@app.after_request
def add_cors_headers(response):
    """Add CORS headers to all responses for local development."""
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    return response


# Error handlers
@app.errorhandler(400)
def bad_request(error):
    """Handle 400 Bad Request errors."""
    return jsonify({'error': 'Bad request', 'message': str(error.description)}), 400


@app.errorhandler(404)
def not_found(error):
    """Handle 404 Not Found errors."""
    return jsonify({'error': 'Not found', 'message': str(error.description)}), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 Internal Server errors."""
    return jsonify({'error': 'Internal server error', 'message': str(error.description)}), 500


# Routes
@app.route('/')
def index():
    """Serve the main HTML page."""
    return render_template('index.html')


@app.route('/api/load', methods=['POST', 'OPTIONS'])
def load_trace():
    """
    Upload and load a trace file.

    Expects multipart form data with 'file' field containing the JSONL trace.

    Returns:
        JSON: {"success": true, "cycles": N} on success
        JSON: {"error": "...", "message": "..."} on failure
    """
    # Handle CORS preflight
    if request.method == 'OPTIONS':
        return '', 204

    # Check for file in request
    if 'file' not in request.files:
        return jsonify({
            'error': 'No file provided',
            'message': 'Request must include a file field'
        }), 400

    file = request.files['file']

    # Check for empty filename
    if file.filename == '':
        return jsonify({
            'error': 'No file selected',
            'message': 'File field is empty'
        }), 400

    try:
        # Save to temporary file
        filename = secure_filename(file.filename)
        temp_dir = tempfile.mkdtemp()
        filepath = os.path.join(temp_dir, filename)
        file.save(filepath)

        # Parse the trace
        parser = TraceParser(filepath)
        set_parser(parser)

        # Clean up temp file (data is now in memory)
        os.remove(filepath)
        os.rmdir(temp_dir)

        return jsonify({
            'success': True,
            'cycles': parser.total_cycles
        })

    except Exception as e:
        return jsonify({
            'error': 'Failed to parse trace',
            'message': str(e)
        }), 400


@app.route('/api/cycle/<int:n>', methods=['GET'])
def get_cycle(n: int):
    """
    Get pipeline state at cycle n.

    Args:
        n: Cycle number

    Returns:
        JSON: Cycle state object
        404: If cycle is out of range or no trace loaded
    """
    parser = get_parser()

    if parser is None:
        return jsonify({
            'error': 'No trace loaded',
            'message': 'Upload a trace file first using /api/load'
        }), 404

    cycle_data = parser.get_cycle(n)

    if cycle_data is None:
        return jsonify({
            'error': 'Cycle not found',
            'message': f'Cycle {n} is out of range (0-{parser.total_cycles - 1})'
        }), 404

    return jsonify(cycle_data)


@app.route('/api/cycles', methods=['GET'])
def get_total_cycles():
    """
    Get total number of cycles in the loaded trace.

    Returns:
        JSON: {"total": N}
        404: If no trace is loaded
    """
    parser = get_parser()

    if parser is None:
        return jsonify({
            'error': 'No trace loaded',
            'message': 'Upload a trace file first using /api/load'
        }), 404

    return jsonify({'total': parser.total_cycles})


@app.route('/api/stats', methods=['GET'])
def get_stats():
    """
    Get execution statistics for the loaded trace.

    Returns:
        JSON: Statistics object with total_cycles, stall_cycles,
              flush_cycles, instructions_retired, cpi
        404: If no trace is loaded
    """
    parser = get_parser()

    if parser is None:
        return jsonify({
            'error': 'No trace loaded',
            'message': 'Upload a trace file first using /api/load'
        }), 404

    return jsonify(parser.get_stats())


@app.route('/api/range/<int:start>/<int:end>', methods=['GET'])
def get_range(start: int, end: int):
    """
    Get cycles in range [start, end) for buffering.

    Args:
        start: Start cycle (inclusive)
        end: End cycle (exclusive)

    Returns:
        JSON: {"cycles": [...]} array of cycle states
        404: If no trace is loaded
    """
    parser = get_parser()

    if parser is None:
        return jsonify({
            'error': 'No trace loaded',
            'message': 'Upload a trace file first using /api/load'
        }), 404

    cycles = parser.get_range(start, end)

    return jsonify({'cycles': cycles})


if __name__ == '__main__':
    # Get port from environment or default to 5050 (5000 is often used by macOS AirPlay)
    port = int(os.environ.get('PORT', 5050))
    debug = os.environ.get('FLASK_DEBUG', 'false').lower() == 'true'

    print(f"Starting RISC-Vibe Pipeline Visualizer on port {port}")
    print(f"Debug mode: {debug}")
    print(f"Open http://localhost:{port} in your browser")

    app.run(host='0.0.0.0', port=port, debug=debug)
