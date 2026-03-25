#!/bin/bash

# Strip extended attributes from build artifacts to fix codesigning issues
echo "Removing extended attributes from build artifacts..."

if [ -d "${BUILT_PRODUCTS_DIR}" ]; then
    xattr -cr "${BUILT_PRODUCTS_DIR}"
fi

if [ -d "${BUILD_DIR}" ]; then
    xattr -cr "${BUILD_DIR}" 2>/dev/null || true
fi

echo "Extended attributes removed successfully"
