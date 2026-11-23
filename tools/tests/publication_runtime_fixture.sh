# Test-only runtime: called in an isolated local or Slurm test directory.
IAPLACS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
iaplacs_runtime_root() { printf '%s\n' "$MOCK_ROOT"; }
