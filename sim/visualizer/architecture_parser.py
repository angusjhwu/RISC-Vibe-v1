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


def _validate_hazards(hazards: dict, stage_ids: set) -> None:
    """Validate hazards configuration."""
    if not isinstance(hazards, dict):
        raise ArchitectureError("'hazards' must be a mapping/dictionary")

    for signal_type in ['stall_signals', 'flush_signals']:
        if signal_type in hazards:
            signals = hazards[signal_type]
            if not isinstance(signals, list):
                raise ArchitectureError(f"hazards.{signal_type} must be a list")

            for i, signal in enumerate(signals):
                if not isinstance(signal, dict):
                    raise ArchitectureError(
                        f"hazards.{signal_type}[{i}] must be a mapping"
                    )

                if 'key' not in signal:
                    raise ArchitectureError(
                        f"hazards.{signal_type}[{i}] missing 'key'"
                    )
                if 'stage' not in signal:
                    raise ArchitectureError(
                        f"hazards.{signal_type}[{i}] missing 'stage'"
                    )

                stage_ref = signal['stage']
                if stage_ref not in stage_ids:
                    raise ArchitectureError(
                        f"hazards.{signal_type}[{i}]: stage '{stage_ref}' not defined"
                    )


def _validate_forwarding(forwarding: dict, stage_ids: set) -> None:
    """Validate forwarding configuration."""
    if not isinstance(forwarding, dict):
        raise ArchitectureError("'forwarding' must be a mapping/dictionary")

    # 'enabled' is optional, defaults to true
    if 'enabled' in forwarding and forwarding['enabled'] is False:
        return  # No further validation needed if disabled

    if 'paths' in forwarding:
        paths = forwarding['paths']
        if not isinstance(paths, list):
            raise ArchitectureError("forwarding.paths must be a list")

        for i, path in enumerate(paths):
            if not isinstance(path, dict):
                raise ArchitectureError(f"forwarding.paths[{i}] must be a mapping")

            if 'key' not in path:
                raise ArchitectureError(f"forwarding.paths[{i}] missing 'key'")
            if 'target_stage' not in path:
                raise ArchitectureError(f"forwarding.paths[{i}] missing 'target_stage'")

            target = path['target_stage']
            if target not in stage_ids:
                raise ArchitectureError(
                    f"forwarding.paths[{i}]: target_stage '{target}' not defined"
                )

            # Validate sources if present
            if 'sources' in path:
                sources = path['sources']
                if not isinstance(sources, list):
                    raise ArchitectureError(
                        f"forwarding.paths[{i}].sources must be a list"
                    )

                for j, source in enumerate(sources):
                    if not isinstance(source, dict):
                        raise ArchitectureError(
                            f"forwarding.paths[{i}].sources[{j}] must be a mapping"
                        )
                    if 'stage' not in source:
                        raise ArchitectureError(
                            f"forwarding.paths[{i}].sources[{j}] missing 'stage'"
                        )
                    if 'value' not in source:
                        raise ArchitectureError(
                            f"forwarding.paths[{i}].sources[{j}] missing 'value'"
                        )

                    src_stage = source['stage']
                    if src_stage not in stage_ids:
                        raise ArchitectureError(
                            f"forwarding.paths[{i}].sources[{j}]: "
                            f"stage '{src_stage}' not defined"
                        )


def _validate_register_file(reg_file: dict) -> None:
    """Validate register file configuration."""
    if not isinstance(reg_file, dict):
        raise ArchitectureError("'register_file' must be a mapping/dictionary")

    if 'enabled' in reg_file and reg_file['enabled'] is False:
        return  # No further validation needed if disabled

    if 'count' in reg_file:
        count = reg_file['count']
        if not isinstance(count, int) or count <= 0:
            raise ArchitectureError("register_file.count must be a positive integer")

    if 'width' in reg_file:
        width = reg_file['width']
        if not isinstance(width, int) or width <= 0:
            raise ArchitectureError("register_file.width must be a positive integer")

    if 'abi_names' in reg_file:
        names = reg_file['abi_names']
        if not isinstance(names, list):
            raise ArchitectureError("register_file.abi_names must be a list")


def _validate_validation_config(validation: dict) -> None:
    """Validate the validation configuration."""
    if not isinstance(validation, dict):
        raise ArchitectureError("'validation' must be a mapping/dictionary")

    if 'required_top_level' in validation:
        if not isinstance(validation['required_top_level'], list):
            raise ArchitectureError("validation.required_top_level must be a list")

    if 'required_per_stage' in validation:
        if not isinstance(validation['required_per_stage'], list):
            raise ArchitectureError("validation.required_per_stage must be a list")


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
