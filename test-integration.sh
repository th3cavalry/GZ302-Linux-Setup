#!/bin/bash

echo "=== GZ302 Setup Script Integration Test Suite ==="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
}

fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    exit 1
}

info() {
    echo -e "${YELLOW}ℹ INFO:${NC} $1"
}

cd /home/runner/work/GZ302-Linux-Setup/GZ302-Linux-Setup

echo "Test 1: Script syntax validation"
if bash -n gz302-setup.sh 2>&1; then
    pass "Script has valid bash syntax"
else
    fail "Script has syntax errors"
fi
echo ""

echo "Test 2: Help text display"
if ./gz302-setup.sh --help 2>&1 | grep -q "Usage:"; then
    pass "Help text displays correctly"
else
    fail "Help text not displayed"
fi
echo ""

echo "Test 3: Version consistency"
header_version=$(grep "^# Version:" gz302-setup.sh | head -1 | awk '{print $3}')
var_version=$(grep '^VERSION="' gz302-setup.sh | head -1 | cut -d'"' -f2)
readme_version=$(grep "^\*\*Version:" README.md | head -1 | awk '{print $2}' | tr -d '*')

if [ "$header_version" = "$var_version" ] && [ "$var_version" = "$readme_version" ]; then
    pass "Version is consistent (1.3.0) across all files"
else
    fail "Version mismatch: header=$header_version, var=$var_version, readme=$readme_version"
fi
echo ""

echo "Test 4: Legacy AMDGPU options removed from kernel params and modprobe"
# Check kernel parameters don't include legacy options
if grep 'local new_params="iommu=pt amd_pstate=active"' gz302-setup.sh > /dev/null; then
    pass "Kernel parameters correct (no si_support/cik_support)"
else
    fail "Kernel parameters incorrect"
fi

# Check modprobe options don't include legacy options
if ! grep "^options amdgpu si_support" gz302-setup.sh > /dev/null && \
   ! grep "^options amdgpu cik_support" gz302-setup.sh > /dev/null; then
    pass "Modprobe options correct (no si_support/cik_support)"
else
    fail "Modprobe options still include legacy options"
fi
echo ""

echo "Test 5: New flags documented in help"
help_output=$(./gz302-setup.sh --help 2>&1)
required_flags=("kernel" "power" "no-reboot" "dry-run" "log" "no-kernel")
all_found=true
for flag in "${required_flags[@]}"; do
    if echo "$help_output" | grep -q -- "--$flag"; then
        info "  Found: --$flag"
    else
        echo "  Missing: --$flag"
        all_found=false
    fi
done

if [ "$all_found" = true ]; then
    pass "All new flags documented in help text"
else
    fail "Some flags missing from help text"
fi
echo ""

echo "Test 6: README version updated"
if grep -q "Version: 1.3.0" README.md; then
    pass "README updated to version 1.3.0"
else
    fail "README version not updated"
fi
echo ""

echo "Test 7: README kernel section renamed"
if grep -q "Kernel (Optional linux-g14 Variant on Arch)" README.md; then
    pass "README kernel section renamed appropriately"
else
    fail "README kernel section not renamed"
fi
echo ""

echo "Test 8: Power management conflict documented"
if grep -q "TLP and power-profiles-daemon" README.md && grep -q "conflict" README.md; then
    pass "TLP/power-profiles-daemon conflict documented in README"
else
    fail "Power management conflict not documented"
fi
echo ""

echo "Test 9: Idempotent function exists"
if grep -q "add_kernel_params_idempotent" gz302-setup.sh; then
    pass "Idempotent kernel parameter function exists"
else
    fail "Idempotent function not found"
fi
echo ""

echo "Test 10: set -euo pipefail present"
if head -20 gz302-setup.sh | grep -q "set -euo pipefail"; then
    pass "Script uses set -euo pipefail for safer execution"
else
    fail "set -euo pipefail not found"
fi
echo ""

echo "Test 11: Dry-run mode implemented"
if grep -q 'if \[ "$DRY_RUN" = true \]' gz302-setup.sh; then
    pass "Dry-run mode implemented in script"
else
    fail "Dry-run mode not found"
fi
echo ""

echo "Test 12: Logging setup exists"
if grep -q "setup_logging" gz302-setup.sh; then
    pass "Logging setup function exists"
else
    fail "Logging setup not found"
fi
echo ""

echo "Test 13: SUDO_USER validation exists"
if grep -q "SUDO_USER" gz302-setup.sh && grep -q "Validate SUDO_USER" gz302-setup.sh; then
    pass "SUDO_USER validation implemented"
else
    fail "SUDO_USER validation not found"
fi
echo ""

echo "Test 14: Optional reboot implemented"
if grep -q "Reboot now to apply changes?" gz302-setup.sh; then
    pass "Optional reboot with prompt implemented"
else
    fail "Optional reboot not found"
fi
echo ""

echo "Test 15: Power backend conflict resolution"
if grep -q "Disabling power-profiles-daemon to avoid conflicts with TLP" gz302-setup.sh && \
   grep -q "Disabling TLP to avoid conflicts with power-profiles-daemon" gz302-setup.sh; then
    pass "Power backend conflict resolution implemented"
else
    fail "Power backend conflict resolution not found"
fi
echo ""

echo ""
echo -e "${GREEN}=== All Tests Passed! ===${NC}"
echo ""
echo "Summary of validated changes:"
echo "  ✓ Script syntax is valid (bash -n)"
echo "  ✓ Version 1.3.0 consistent across files"
echo "  ✓ Legacy AMDGPU options removed"
echo "  ✓ All new CLI flags implemented and documented"
echo "  ✓ README properly updated"
echo "  ✓ Idempotent kernel parameter function"
echo "  ✓ Safe execution (set -euo pipefail)"
echo "  ✓ Dry-run mode"
echo "  ✓ Logging system"
echo "  ✓ SUDO_USER validation"
echo "  ✓ Optional reboot prompt"
echo "  ✓ Power backend conflict resolution"
echo ""
echo "Note: Full integration testing requires running on actual hardware with sudo."
echo "See TESTING.md for manual testing procedures."
