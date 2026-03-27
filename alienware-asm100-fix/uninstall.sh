#!/bin/bash

# Uninstall Alienware ASM100 shutdown fix

echo "Removing Alienware ASM100 shutdown fix..."

# Remove the boot hook from custom.sh
CUSTOM_SH="/userdata/system/custom.sh"
if [ -f "$CUSTOM_SH" ]; then
    # Remove the hook lines
    sed -i '/# ASM100 shutdown fix/d' "$CUSTOM_SH"
    sed -i '/asm100_poweroff/d' "$CUSTOM_SH"
    echo "Removed boot hook from custom.sh"
fi

# Remove the addon directory
rm -rf /userdata/system/add-ons/alienware-asm100-fix
echo "Removed addon files"

echo ""
echo "Alienware ASM100 shutdown fix has been uninstalled."
echo "The original poweroff behavior will be restored on next reboot."
echo "Note: The fix is still active for this session until you reboot."
