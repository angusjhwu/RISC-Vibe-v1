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
from architecture_parser import (
    parse_architecture,
    validate_trace_against_architecture,
    get_architecture_summary,
    ArchitectureError
)


app = Flask(__name__, template_folder='templates', static_folder='static')
app.config['MAX_CONTENT_LENGTH'] = 100 * 1024 * 1024  # 100MB max upload
app.config['DEBUG'] = os.environ.get('FLASK_DEBUG', 'false').lower() == 'true'

# Global state
_trace_parser: TraceParser | None = None
_architecture: dict | None = None


def error_response(error: str, message: str, status: int = 400) -> tuple:
    """Create a standardized error response."""
    return jsonify({'error': error, 'message': message}), status


def require_file_upload() -> tuple | None:
    """Validate file upload and return error response if invalid, None if valid."""
    if 'file' not in request.files:
        return error_response('No file provided', 'Request must include a file field')
    if request.files['file'].filename == '':
        return error_response('No file selected', 'File field is empty')
    return None


@app.after_request
def add_cors_headers(response):
    """Add CORS headers to all responses for local development."""
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    return response


@app.errorhandler(400)
def bad_request(error):
    return error_response('Bad request', str(error.description), 400)


@app.errorhandler(404)
def not_found(error):
    return error_response('Not found', str(error.description), 404)


@app.errorhandler(500)
def internal_error(error):
    return error_response('Internal server error', str(error.description), 500)


@app.route('/')
def index():
    """Serve the main HTML page."""
    return render_template('index.html')


@app.route('/api/architecture', methods=['POST', 'OPTIONS'])
def load_architecture():
    """Upload and load an architecture definition file."""
    global _architecture, _trace_parser

    if request.method == 'OPTIONS':
        return '', 204

    file_error = require_file_upload()
    if file_error:
        return file_error

    try:
        yaml_content = request.files['file'].read().decode('utf-8')
        _architecture = parse_architecture(yaml_content)
        _trace_parser = None  # Clear trace since it may not match new architecture

        return jsonify({
            'success': True,
            'architecture': _architecture,
            'summary': get_architecture_summary(_architecture)
        })
    except ArchitectureError as e:
        return error_response('Invalid architecture file', str(e))
    except Exception as e:
        return error_response('Failed to parse architecture', str(e))


@app.route('/api/architecture', methods=['GET'])
def get_current_architecture():
    """Get the currently loaded architecture definition."""
    if _architecture is None:
        return error_response(
            'No architecture loaded',
            'Upload an architecture file first using POST /api/architecture',
            404
        )

    return jsonify({
        'architecture': _architecture,
        'summary': get_architecture_summary(_architecture)
    })


@app.route('/api/load', methods=['POST', 'OPTIONS'])
def load_trace():
    """Upload and load a trace file. Requires an architecture to be loaded first."""
    global _trace_parser

    if request.method == 'OPTIONS':
        return '', 204

    if _architecture is None:
        return error_response(
            'No architecture loaded',
            'Load an architecture file first using /api/architecture'
        )

    file_error = require_file_upload()
    if file_error:
        return file_error

    try:
        file = request.files['file']
        filename = secure_filename(file.filename)
        temp_dir = tempfile.mkdtemp()
        filepath = os.path.join(temp_dir, filename)
        file.save(filepath)

        parser = TraceParser(filepath)

        # Validate trace against architecture (check first few cycles)
        validation_errors = []
        for i in range(min(10, parser.total_cycles)):
            cycle_data = parser.get_cycle(i)
            if cycle_data:
                errors = validate_trace_against_architecture(cycle_data, _architecture, i + 1)
                validation_errors.extend(errors)

        os.remove(filepath)
        os.rmdir(temp_dir)

        if validation_errors:
            return jsonify({
                'error': 'Trace validation failed',
                'message': 'Trace file does not match the loaded architecture',
                'details': validation_errors[:20]
            }), 400

        _trace_parser = parser
        return jsonify({'success': True, 'cycles': parser.total_cycles})

    except Exception as e:
        return error_response('Failed to parse trace', str(e))


def require_trace_loaded() -> tuple | None:
    """Return error response if no trace is loaded, None otherwise."""
    if _trace_parser is None:
        return error_response('No trace loaded', 'Upload a trace file first using /api/load', 404)
    return None


@app.route('/api/cycle/<int:n>', methods=['GET'])
def get_cycle(n: int):
    """Get pipeline state at cycle n."""
    trace_error = require_trace_loaded()
    if trace_error:
        return trace_error

    cycle_data = _trace_parser.get_cycle(n)
    if cycle_data is None:
        return error_response(
            'Cycle not found',
            f'Cycle {n} is out of range (0-{_trace_parser.total_cycles - 1})',
            404
        )

    return jsonify(cycle_data)


@app.route('/api/cycles', methods=['GET'])
def get_total_cycles():
    """Get total number of cycles in the loaded trace."""
    trace_error = require_trace_loaded()
    if trace_error:
        return trace_error

    return jsonify({'total': _trace_parser.total_cycles})


@app.route('/api/stats', methods=['GET'])
def get_stats():
    """Get execution statistics for the loaded trace."""
    trace_error = require_trace_loaded()
    if trace_error:
        return trace_error

    return jsonify(_trace_parser.get_stats(_architecture))


@app.route('/api/range/<int:start>/<int:end>', methods=['GET'])
def get_range(start: int, end: int):
    """Get cycles in range [start, end) for buffering."""
    trace_error = require_trace_loaded()
    if trace_error:
        return trace_error

    return jsonify({'cycles': _trace_parser.get_range(start, end)})


if __name__ == '__main__':
    # Get port from environment or default to 5050 (5000 is often used by macOS AirPlay)
    port = int(os.environ.get('PORT', 5050))
    debug = os.environ.get('FLASK_DEBUG', 'false').lower() == 'true'

    print(f"Starting RISC-Vibe Pipeline Visualizer on port {port}")
    print(f"Debug mode: {debug}")
    print(f"Open http://localhost:{port} in your browser")

    app.run(host='0.0.0.0', port=port, debug=debug)
