"""
Architecture Parser Module

Parses and validates YAML architecture files that define pipeline structure
for the RiscVibe visualizer.
"""

import yaml
from typing import Any


# Valid format types for field rendering
VALID_FORMATS = {
    'hex_compact',   # Hex with minimal padding (0x0004)
    'hex',           # Full 8-digit hex (0x00000004)
    'decimal',       # Decimal number
    'hex_smart',     # Decimal if small, hex if large
    'disasm',        # Run through ISA disassembler
    'register',      # Format as register name (x5)
    'string',        # Pass through unchanged
    'static',        # Show label only, no data key
    'memory_op',     # Special: R/W @addr or ---
    'writeback',     # Special: xN <- val or ---
}


class ArchitectureError(Exception):
    """Raised when architecture file is invalid."""
    pass


def parse_architecture(yaml_content: str) -> dict:
    """
    Parse and validate a YAML architecture file.

    Args:
        yaml_content: Raw YAML string content

    Returns:
        Parsed and validated architecture dictionary

    Raises:
        ArchitectureError: If the architecture is invalid
    """
    try:
        arch = yaml.safe_load(yaml_content)
    except yaml.YAMLError as e:
        raise ArchitectureError(f"Invalid YAML syntax: {e}")

    if not isinstance(arch, dict):
        raise ArchitectureError("Architecture must be a YAML mapping/dictionary")

    _validate_architecture(arch)
    return arch


def _validate_architecture(arch: dict) -> None:
    """Validate architecture structure and contents."""

    # Required top-level fields
    if 'name' not in arch:
        raise ArchitectureError("Missing required field 'name'")
    if 'stages' not in arch:
        raise ArchitectureError("Missing required field 'stages'")

    # Validate stages
    stages = arch['stages']
    if not isinstance(stages, list):
        raise ArchitectureError("'stages' must be a list")
    if len(stages) == 0:
        raise ArchitectureError("At least one stage required")

    stage_ids = set()
    for i, stage in enumerate(stages):
        _validate_stage(stage, i, stage_ids)

    # Validate hazards if present
    if 'hazards' in arch:
        _validate_hazards(arch['hazards'], stage_ids)

    # Validate forwarding if present
    if 'forwarding' in arch:
        _validate_forwarding(arch['forwarding'], stage_ids)

    # Validate register_file if present
    if 'register_file' in arch:
        _validate_register_file(arch['register_file'])

    # Validate validation config if present
    if 'validation' in arch:
        _validate_validation_config(arch['validation'])


def _validate_stage(stage: dict, index: int, stage_ids: set) -> None:
    """Validate a single stage definition."""
    if not isinstance(stage, dict):
        raise ArchitectureError(f"Stage {index} must be a mapping/dictionary")

    # Required stage fields
    if 'id' not in stage:
        raise ArchitectureError(f"Stage {index}: missing required field 'id'")
    if 'name' not in stage:
        raise ArchitectureError(f"Stage {index}: missing required field 'name'")
    if 'letter' not in stage:
        raise ArchitectureError(f"Stage {index}: missing required field 'letter'")

    stage_id = stage['id']

    # Check for duplicate IDs
    if stage_id in stage_ids:
        raise ArchitectureError(f"Duplicate stage id '{stage_id}'")
    stage_ids.add(stage_id)

    # Validate letter is single character
    if not isinstance(stage['letter'], str) or len(stage['letter']) != 1:
        raise ArchitectureError(f"Stage '{stage_id}': 'letter' must be a single character")

    # Validate fields if present
    if 'fields' in stage:
        _validate_fields(stage['fields'], stage_id, 'fields')

    # Validate detail_fields if present
    if 'detail_fields' in stage:
        _validate_fields(stage['detail_fields'], stage_id, 'detail_fields')


def _validate_fields(fields: list, stage_id: str, field_type: str) -> None:
    """Validate a list of field definitions."""
    if not isinstance(fields, list):
        raise ArchitectureError(f"Stage '{stage_id}': '{field_type}' must be a list")

    for i, field in enumerate(fields):
        if not isinstance(field, dict):
            raise ArchitectureError(
                f"Stage '{stage_id}': {field_type}[{i}] must be a mapping"
            )

        # 'key' can be null for static fields
        if 'format' not in field:
            raise ArchitectureError(
                f"Stage '{stage_id}': {field_type}[{i}] missing 'format'"
            )

        fmt = field['format']
        if fmt not in VALID_FORMATS:
            raise ArchitectureError(
                f"Stage '{stage_id}': {field_type}[{i}] has unknown format type '{fmt}'"
            )


def _validate_signal_list(
    signals: list,
    path: str,
    required_fields: list[str],
    stage_ids: set
) -> None:
    """Validate a list of signal definitions with required fields and stage references."""
    if not isinstance(signals, list):
        raise ArchitectureError(f"{path} must be a list")

    for i, signal in enumerate(signals):
        if not isinstance(signal, dict):
            raise ArchitectureError(f"{path}[{i}] must be a mapping")

        for field in required_fields:
            if field not in signal:
                raise ArchitectureError(f"{path}[{i}] missing '{field}'")

        if 'stage' in required_fields and signal['stage'] not in stage_ids:
            raise ArchitectureError(f"{path}[{i}]: stage '{signal['stage']}' not defined")


def _validate_hazards(hazards: dict, stage_ids: set) -> None:
    """Validate hazards configuration."""
    if not isinstance(hazards, dict):
        raise ArchitectureError("'hazards' must be a mapping/dictionary")

    for signal_type in ['stall_signals', 'flush_signals']:
        if signal_type in hazards:
            _validate_signal_list(
                hazards[signal_type],
                f"hazards.{signal_type}",
                ['key', 'stage'],
                stage_ids
            )


def _validate_forwarding(forwarding: dict, stage_ids: set) -> None:
    """Validate forwarding configuration."""
    if not isinstance(forwarding, dict):
        raise ArchitectureError("'forwarding' must be a mapping/dictionary")

    if forwarding.get('enabled') is False:
        return

    if 'paths' not in forwarding:
        return

    paths = forwarding['paths']
    if not isinstance(paths, list):
        raise ArchitectureError("forwarding.paths must be a list")

    for i, path in enumerate(paths):
        if not isinstance(path, dict):
            raise ArchitectureError(f"forwarding.paths[{i}] must be a mapping")

        for field in ['key', 'target_stage']:
            if field not in path:
                raise ArchitectureError(f"forwarding.paths[{i}] missing '{field}'")

        if path['target_stage'] not in stage_ids:
            raise ArchitectureError(
                f"forwarding.paths[{i}]: target_stage '{path['target_stage']}' not defined"
            )

        if 'sources' in path:
            _validate_signal_list(
                path['sources'],
                f"forwarding.paths[{i}].sources",
                ['stage', 'value'],
                stage_ids
            )


def _require_positive_int(value: any, field_path: str) -> None:
    """Validate that a value is a positive integer."""
    if not isinstance(value, int) or value <= 0:
        raise ArchitectureError(f"{field_path} must be a positive integer")


def _require_list(value: any, field_path: str) -> None:
    """Validate that a value is a list."""
    if not isinstance(value, list):
        raise ArchitectureError(f"{field_path} must be a list")


def _validate_register_file(reg_file: dict) -> None:
    """Validate register file configuration."""
    if not isinstance(reg_file, dict):
        raise ArchitectureError("'register_file' must be a mapping/dictionary")

    if reg_file.get('enabled') is False:
        return

    if 'count' in reg_file:
        _require_positive_int(reg_file['count'], "register_file.count")

    if 'width' in reg_file:
        _require_positive_int(reg_file['width'], "register_file.width")

    if 'abi_names' in reg_file:
        _require_list(reg_file['abi_names'], "register_file.abi_names")


def _validate_validation_config(validation: dict) -> None:
    """Validate the validation configuration."""
    if not isinstance(validation, dict):
        raise ArchitectureError("'validation' must be a mapping/dictionary")

    for field in ['required_top_level', 'required_per_stage']:
        if field in validation:
            _require_list(validation[field], f"validation.{field}")


def validate_trace_against_architecture(
    cycle_data: dict,
    architecture: dict,
    line_num: int
) -> list[str]:
    """
    Validate a single trace cycle against the architecture.

    Args:
        cycle_data: Parsed JSON for one cycle
        architecture: Validated architecture definition
        line_num: Line number in trace file (for error messages)

    Returns:
        List of error messages (empty if valid)
    """
    errors = []

    # Check required top-level fields
    validation = architecture.get('validation', {})
    required_top = validation.get('required_top_level', ['cycle'])

    for field in required_top:
        if field not in cycle_data:
            errors.append(f"Line {line_num}: Missing required field '{field}'")

    # Check all stages exist
    required_per_stage = validation.get('required_per_stage', ['pc', 'valid'])

    for stage in architecture['stages']:
        stage_id = stage['id']

        if stage_id not in cycle_data:
            errors.append(f"Line {line_num}: Missing stage '{stage_id}'")
            continue

        stage_data = cycle_data[stage_id]
        if not isinstance(stage_data, dict):
            errors.append(f"Line {line_num}: Stage '{stage_id}' must be an object")
            continue

        # Check required fields per stage
        for field in required_per_stage:
            if field not in stage_data:
                errors.append(
                    f"Line {line_num}: Stage '{stage_id}' missing field '{field}'"
                )

    # Check hazard object if hazards defined
    if 'hazards' in architecture:
        hazards = architecture['hazards']
        if 'hazard' not in cycle_data:
            errors.append(f"Line {line_num}: Missing 'hazard' object")
        else:
            hazard_data = cycle_data['hazard']

            # Check all expected hazard signals
            for signal_type in ['stall_signals', 'flush_signals']:
                for signal in hazards.get(signal_type, []):
                    key = signal['key']
                    if key not in hazard_data:
                        errors.append(
                            f"Line {line_num}: Missing hazard signal '{key}'"
                        )

    # Check forward object if forwarding enabled
    forwarding = architecture.get('forwarding', {})
    if forwarding.get('enabled', True) and 'paths' in forwarding:
        source_field = forwarding.get('source_field', 'forward')

        if source_field not in cycle_data:
            errors.append(f"Line {line_num}: Missing '{source_field}' object")
        else:
            forward_data = cycle_data[source_field]

            for path in forwarding['paths']:
                key = path['key']
                if key not in forward_data:
                    errors.append(
                        f"Line {line_num}: Missing forward path '{key}'"
                    )

    return errors


def get_architecture_summary(architecture: dict) -> dict:
    """
    Get a summary of the architecture for display.

    Args:
        architecture: Validated architecture definition

    Returns:
        Summary dictionary with key info
    """
    stages = architecture['stages']

    return {
        'name': architecture.get('name', 'Unknown'),
        'description': architecture.get('description', ''),
        'stage_count': len(stages),
        'stage_names': [s['name'] for s in stages],
        'stage_letters': ''.join(s['letter'] for s in stages),
        'has_hazards': 'hazards' in architecture,
        'has_forwarding': architecture.get('forwarding', {}).get('enabled', False),
        'has_register_file': architecture.get('register_file', {}).get('enabled', False),
    }
