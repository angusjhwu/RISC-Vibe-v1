"""
RISC-V register definitions and name mappings.

Supports both numeric names (x0-x31) and ABI names (zero, ra, sp, etc.).
"""

# Register number to ABI name mapping
REG_ABI_NAMES = {
    0: "zero",
    1: "ra",
    2: "sp",
    3: "gp",
    4: "tp",
    5: "t0",
    6: "t1",
    7: "t2",
    8: "s0",  # Also fp (frame pointer)
    9: "s1",
    10: "a0",
    11: "a1",
    12: "a2",
    13: "a3",
    14: "a4",
    15: "a5",
    16: "a6",
    17: "a7",
    18: "s2",
    19: "s3",
    20: "s4",
    21: "s5",
    22: "s6",
    23: "s7",
    24: "s8",
    25: "s9",
    26: "s10",
    27: "s11",
    28: "t3",
    29: "t4",
    30: "t5",
    31: "t6",
}

# Build the reverse mapping (name to number)
# Include all possible names: x0-x31, ABI names, and aliases
REGISTER_MAP = {}

# Add numeric names (x0-x31)
for i in range(32):
    REGISTER_MAP[f"x{i}"] = i

# Add ABI names
for num, name in REG_ABI_NAMES.items():
    REGISTER_MAP[name] = num

# Add alias: fp = s0 = x8
REGISTER_MAP["fp"] = 8


def parse_register(name: str) -> int:
    """
    Parse a register name and return its number.

    Args:
        name: Register name (e.g., "x0", "zero", "ra", "s0", "fp")

    Returns:
        Register number (0-31)

    Raises:
        ValueError: If the register name is invalid
    """
    name_lower = name.lower().strip()
    if name_lower in REGISTER_MAP:
        return REGISTER_MAP[name_lower]
    raise ValueError(f"Invalid register name: {name}")


def is_valid_register(name: str) -> bool:
    """Check if a string is a valid register name."""
    return name.lower().strip() in REGISTER_MAP


def get_register_name(num: int, use_abi: bool = True) -> str:
    """
    Get the name for a register number.

    Args:
        num: Register number (0-31)
        use_abi: If True, return ABI name; otherwise return x-name

    Returns:
        Register name string
    """
    if not 0 <= num <= 31:
        raise ValueError(f"Invalid register number: {num}")
    if use_abi:
        return REG_ABI_NAMES[num]
    return f"x{num}"
