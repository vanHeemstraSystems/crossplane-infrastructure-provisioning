#!/bin/bash
# validate.sh
# Validates Crossplane XRDs and Compositions

set -e

echo "=========================================="
echo "Validating Crossplane Manifests"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}ERROR: kubectl not found${NC}"
    exit 1
fi

# Validate XRDs
echo ""
echo "Validating XRDs..."
for xrd_file in manifests/xrds/*.yaml; do
    if [ -f "$xrd_file" ]; then
        echo -n "  $(basename $xrd_file)... "
        if kubectl apply --dry-run=client -f "$xrd_file" &> /dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
            kubectl apply --dry-run=client -f "$xrd_file"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# Validate Compositions
echo ""
echo "Validating Compositions..."
for comp_file in manifests/compositions/*.yaml; do
    if [ -f "$comp_file" ]; then
        echo -n "  $(basename $comp_file)... "
        if kubectl apply --dry-run=client -f "$comp_file" &> /dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
            kubectl apply --dry-run=client -f "$comp_file"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# Validate Examples
echo ""
echo "Validating Examples..."
for example_file in examples/*.yaml; do
    if [ -f "$example_file" ]; then
        echo -n "  $(basename $example_file)... "
        if kubectl apply --dry-run=client -f "$example_file" &> /dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
            kubectl apply --dry-run=client -f "$example_file"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# Check Crossplane installation
echo ""
echo "Checking Crossplane installation..."
if kubectl get namespace crossplane-system &> /dev/null; then
    echo -e "${GREEN}✓ crossplane-system namespace exists${NC}"
    
    # Check if Crossplane is running
    if kubectl get pods -n crossplane-system -l app=crossplane | grep -q "Running"; then
        echo -e "${GREEN}✓ Crossplane is running${NC}"
    else
        echo -e "${YELLOW}⚠ Crossplane pods not running${NC}"
        kubectl get pods -n crossplane-system
    fi
else
    echo -e "${YELLOW}⚠ Crossplane not installed${NC}"
fi

# Summary
echo ""
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All validations passed!${NC}"
    echo "=========================================="
    exit 0
else
    echo -e "${RED}Validation failed with $ERRORS error(s)${NC}"
    echo "=========================================="
    exit 1
fi

