"""
Tests for the architecture parser module.
"""

import pytest
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from architecture_parser import (
    parse_architecture,
    validate_trace_against_architecture,
    get_architecture_summary,
    ArchitectureError,
    VALID_FORMATS
)


class TestParseArchitecture:
    """Tests for parse_architecture function."""

    def test_valid_minimal_architecture(self):
        """Test parsing a minimal valid architecture."""
        yaml_content = """
name: "test_arch"
stages:
  - id: "fetch"
    name: "FETCH"
    letter: "F"
"""
        arch = parse_architecture(yaml_content)
        assert arch['name'] == 'test_arch'
        assert len(arch['stages']) == 1
        assert arch['stages'][0]['id'] == 'fetch'

    def test_valid_full_architecture(self):
        """Test parsing a full architecture with all features."""
        yaml_content = """
name: "full_arch"
version: "1.0"
description: "Full test architecture"
stages:
  - id: "if"
    name: "IF"
    letter: "F"
    fields:
      - key: "pc"
        format: "hex_compact"
    detail_fields:
      - key: null
        label: "Fetching"
        format: "static"
  - id: "ex"
    name: "EX"
    letter: "X"
    fields:
      - key: "pc"
        format: "hex_compact"
hazards:
  stall_signals:
    - key: "stall_if"
      stage: "if"
      label: "Stall IF"
  flush_signals:
    - key: "flush_ex"
      stage: "ex"
      label: "Flush EX"
forwarding:
  enabled: true
  source_field: "forward"
  paths:
    - key: "a"
      label: "rs1"
      target_stage: "ex"
      sources:
        - stage: "ex"
          value: "EX"
          color: "#ff0000"
register_file:
  enabled: true
  source_field: "regs"
  count: 32
  width: 32
validation:
  required_top_level:
    - "cycle"
  required_per_stage:
    - "pc"
    - "valid"
"""
        arch = parse_architecture(yaml_content)
        assert arch['name'] == 'full_arch'
        assert len(arch['stages']) == 2
        assert arch['hazards']['stall_signals'][0]['key'] == 'stall_if'
        assert arch['forwarding']['enabled'] is True
        assert arch['register_file']['count'] == 32

    def test_invalid_yaml_syntax(self):
        """Test that invalid YAML raises error."""
        yaml_content = """
name: "test"
stages:
  - id: "fetch"
    name: FETCH  # missing quotes after colon with special char
    invalid: [
"""
        with pytest.raises(ArchitectureError, match="Invalid YAML syntax"):
            parse_architecture(yaml_content)

    def test_missing_name(self):
        """Test that missing 'name' field raises error."""
        yaml_content = """
stages:
  - id: "fetch"
    name: "FETCH"
    letter: "F"
"""
        with pytest.raises(ArchitectureError, match="Missing required field 'name'"):
            parse_architecture(yaml_content)

    def test_missing_stages(self):
        """Test that missing 'stages' field raises error."""
        yaml_content = """
name: "test_arch"
"""
        with pytest.raises(ArchitectureError, match="Missing required field 'stages'"):
            parse_architecture(yaml_content)

    def test_empty_stages(self):
        """Test that empty stages list raises error."""
        yaml_content = """
name: "test_arch"
stages: []
"""
        with pytest.raises(ArchitectureError, match="At least one stage required"):
            parse_architecture(yaml_content)

    def test_duplicate_stage_ids(self):
        """Test that duplicate stage IDs raise error."""
        yaml_content = """
name: "test_arch"
stages:
  - id: "fetch"
    name: "FETCH"
    letter: "F"
  - id: "fetch"
    name: "FETCH2"
    letter: "G"
"""
        with pytest.raises(ArchitectureError, match="Duplicate stage id 'fetch'"):
            parse_architecture(yaml_content)

    def test_stage_missing_id(self):
        """Test that stage without ID raises error."""
        yaml_content = """
name: "test_arch"
stages:
  - name: "FETCH"
    letter: "F"
"""
        with pytest.raises(ArchitectureError, match="missing required field 'id'"):
            parse_architecture(yaml_content)

    def test_stage_missing_name(self):
        """Test that stage without name raises error."""
        yaml_content = """
name: "test_arch"
stages:
  - id: "fetch"
    letter: "F"
"""
        with pytest.raises(ArchitectureError, match="missing required field 'name'"):
            parse_architecture(yaml_content)

    def test_stage_missing_letter(self):
        """Test that stage without letter raises error."""
        yaml_content = """
name: "test_arch"
stages:
  - id: "fetch"
    name: "FETCH"
"""
        with pytest.raises(ArchitectureError, match="missing required field 'letter'"):
            parse_architecture(yaml_content)

    def test_stage_letter_not_single_char(self):
        """Test that multi-char letter raises error."""
        yaml_content = """
name: "test_arch"
stages:
  - id: "fetch"
    name: "FETCH"
    letter: "FE"
"""
        with pytest.raises(ArchitectureError, match="'letter' must be a single character"):
            parse_architecture(yaml_content)

    def test_invalid_format_type(self):
        """Test that invalid format type raises error."""
        yaml_content = """
name: "test_arch"
stages:
  - id: "fetch"
    name: "FETCH"
    letter: "F"
    fields:
      - key: "pc"
        format: "invalid_format"
"""
        with pytest.raises(ArchitectureError, match="unknown format type 'invalid_format'"):
            parse_architecture(yaml_content)

    def test_hazard_invalid_stage_ref(self):
        """Test that hazard referencing non-existent stage raises error."""
        yaml_content = """
name: "test_arch"
stages:
  - id: "fetch"
    name: "FETCH"
    letter: "F"
hazards:
  stall_signals:
    - key: "stall_decode"
      stage: "decode"
      label: "Stall Decode"
"""
        with pytest.raises(ArchitectureError, match="stage 'decode' not defined"):
            parse_architecture(yaml_content)

    def test_forwarding_invalid_target_stage(self):
        """Test that forwarding with invalid target stage raises error."""
        yaml_content = """
name: "test_arch"
stages:
  - id: "fetch"
    name: "FETCH"
    letter: "F"
forwarding:
  enabled: true
  paths:
    - key: "a"
      target_stage: "execute"
"""
        with pytest.raises(ArchitectureError, match="target_stage 'execute' not defined"):
            parse_architecture(yaml_content)

    def test_forwarding_disabled_no_validation(self):
        """Test that disabled forwarding skips path validation."""
        yaml_content = """
name: "test_arch"
stages:
  - id: "fetch"
    name: "FETCH"
    letter: "F"
forwarding:
  enabled: false
  paths:
    - key: "a"
      target_stage: "nonexistent"
"""
        # Should not raise - forwarding is disabled
        arch = parse_architecture(yaml_content)
        assert arch['forwarding']['enabled'] is False


class TestValidFormats:
    """Tests for valid format types."""

    def test_all_format_types_defined(self):
        """Verify all expected format types are in VALID_FORMATS."""
        expected = {
            'hex_compact', 'hex', 'decimal', 'hex_smart', 'disasm',
            'register', 'string', 'static', 'memory_op', 'writeback'
        }
        assert VALID_FORMATS == expected


class TestTraceValidation:
    """Tests for validate_trace_against_architecture function."""

    @pytest.fixture
    def simple_arch(self):
        """Simple architecture for testing."""
        return {
            'stages': [
                {'id': 'if', 'name': 'IF', 'letter': 'F'},
                {'id': 'ex', 'name': 'EX', 'letter': 'X'}
            ],
            'hazards': {
                'stall_signals': [{'key': 'stall_if', 'stage': 'if'}],
                'flush_signals': [{'key': 'flush_ex', 'stage': 'ex'}]
            },
            'forwarding': {
                'enabled': True,
                'source_field': 'forward',
                'paths': [{'key': 'a', 'target_stage': 'ex'}]
            },
            'validation': {
                'required_top_level': ['cycle'],
                'required_per_stage': ['pc', 'valid']
            }
        }

    def test_valid_trace_cycle(self, simple_arch):
        """Test validation of a valid trace cycle."""
        cycle_data = {
            'cycle': 1,
            'if': {'pc': '0x0000', 'valid': True},
            'ex': {'pc': '0x0000', 'valid': True},
            'hazard': {'stall_if': False, 'flush_ex': False},
            'forward': {'a': 'NONE'}
        }
        errors = validate_trace_against_architecture(cycle_data, simple_arch, 1)
        assert errors == []

    def test_missing_stage(self, simple_arch):
        """Test validation catches missing stage."""
        cycle_data = {
            'cycle': 1,
            'if': {'pc': '0x0000', 'valid': True},
            # 'ex' is missing
            'hazard': {'stall_if': False, 'flush_ex': False},
            'forward': {'a': 'NONE'}
        }
        errors = validate_trace_against_architecture(cycle_data, simple_arch, 1)
        assert any("Missing stage 'ex'" in e for e in errors)

    def test_missing_required_field(self, simple_arch):
        """Test validation catches missing required field in stage."""
        cycle_data = {
            'cycle': 1,
            'if': {'pc': '0x0000'},  # missing 'valid'
            'ex': {'pc': '0x0000', 'valid': True},
            'hazard': {'stall_if': False, 'flush_ex': False},
            'forward': {'a': 'NONE'}
        }
        errors = validate_trace_against_architecture(cycle_data, simple_arch, 1)
        assert any("missing field 'valid'" in e for e in errors)

    def test_missing_hazard_object(self, simple_arch):
        """Test validation catches missing hazard object."""
        cycle_data = {
            'cycle': 1,
            'if': {'pc': '0x0000', 'valid': True},
            'ex': {'pc': '0x0000', 'valid': True},
            # 'hazard' is missing
            'forward': {'a': 'NONE'}
        }
        errors = validate_trace_against_architecture(cycle_data, simple_arch, 1)
        assert any("Missing 'hazard' object" in e for e in errors)

    def test_missing_hazard_signal(self, simple_arch):
        """Test validation catches missing hazard signal."""
        cycle_data = {
            'cycle': 1,
            'if': {'pc': '0x0000', 'valid': True},
            'ex': {'pc': '0x0000', 'valid': True},
            'hazard': {'stall_if': False},  # missing flush_ex
            'forward': {'a': 'NONE'}
        }
        errors = validate_trace_against_architecture(cycle_data, simple_arch, 1)
        assert any("Missing hazard signal 'flush_ex'" in e for e in errors)

    def test_missing_forward_object(self, simple_arch):
        """Test validation catches missing forward object."""
        cycle_data = {
            'cycle': 1,
            'if': {'pc': '0x0000', 'valid': True},
            'ex': {'pc': '0x0000', 'valid': True},
            'hazard': {'stall_if': False, 'flush_ex': False},
            # 'forward' is missing
        }
        errors = validate_trace_against_architecture(cycle_data, simple_arch, 1)
        assert any("Missing 'forward' object" in e for e in errors)

    def test_missing_forward_path(self, simple_arch):
        """Test validation catches missing forward path."""
        cycle_data = {
            'cycle': 1,
            'if': {'pc': '0x0000', 'valid': True},
            'ex': {'pc': '0x0000', 'valid': True},
            'hazard': {'stall_if': False, 'flush_ex': False},
            'forward': {}  # missing 'a'
        }
        errors = validate_trace_against_architecture(cycle_data, simple_arch, 1)
        assert any("Missing forward path 'a'" in e for e in errors)


class TestGetArchitectureSummary:
    """Tests for get_architecture_summary function."""

    def test_summary_basic(self):
        """Test basic summary generation."""
        arch = {
            'name': 'test_arch',
            'description': 'Test architecture',
            'stages': [
                {'id': 'if', 'name': 'IF', 'letter': 'F'},
                {'id': 'ex', 'name': 'EX', 'letter': 'X'},
                {'id': 'wb', 'name': 'WB', 'letter': 'W'}
            ],
            'hazards': {'stall_signals': [], 'flush_signals': []},
            'forwarding': {'enabled': True, 'paths': []},
            'register_file': {'enabled': True}
        }

        summary = get_architecture_summary(arch)

        assert summary['name'] == 'test_arch'
        assert summary['description'] == 'Test architecture'
        assert summary['stage_count'] == 3
        assert summary['stage_names'] == ['IF', 'EX', 'WB']
        assert summary['stage_letters'] == 'FXW'
        assert summary['has_hazards'] is True
        assert summary['has_forwarding'] is True
        assert summary['has_register_file'] is True

    def test_summary_no_optional_features(self):
        """Test summary when optional features are missing."""
        arch = {
            'name': 'minimal',
            'stages': [{'id': 'if', 'name': 'IF', 'letter': 'F'}]
        }

        summary = get_architecture_summary(arch)

        assert summary['name'] == 'minimal'
        assert summary['stage_count'] == 1
        assert summary['has_hazards'] is False
        assert summary['has_forwarding'] is False
        assert summary['has_register_file'] is False


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
