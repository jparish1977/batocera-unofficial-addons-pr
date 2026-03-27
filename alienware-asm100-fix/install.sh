#!/bin/bash

# -------------------------------------------------------
# Alienware ASM100 (Alpha / Steam Machine) Shutdown Fix
# -------------------------------------------------------
# The ASM100's ACPI power-off implementation is broken under Linux
# due to a kernel regression between 4.16 and 6.x. The kernel
# completes shutdown but the hardware never cuts power.
#
# The original SteamOS avoided this because systemd-logind handled
# S5 transitions via acpid. Batocera's BusyBox init calls poweroff
# directly, exposing the kernel bug.
#
# This fix bypasses the broken ACPI layer by writing the S5 sleep
# type value (0x3C00) directly to the PM1a control register
# (port 0x1804), extracted from the machine's FADT and DSDT tables.
#
# Full writeup: https://github.com/jparish1977/batocera-tools
# Tested on: Alienware ASM100 (Alpha R1), BIOS A08, Batocera 39
# -------------------------------------------------------

# Step 1: Detect hardware
echo "Detecting hardware..."
PRODUCT=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)

if [ "$PRODUCT" != "ASM100" ] || [ "$VENDOR" != "Alienware" ]; then
    echo ""
    echo "WARNING: This machine is $VENDOR $PRODUCT, not Alienware ASM100."
    echo "This fix is hardware-specific. It writes directly to PM registers"
    echo "and should only be used on the Alienware Alpha (ASM100)."
    echo ""
    read -p "Continue anyway? (y/N) " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Aborted."
        exit 1
    fi
fi

echo "Alienware ASM100 detected. Installing shutdown fix..."

# Step 2: Install the power-off script
INSTALL_DIR="/userdata/system/add-ons/alienware-asm100-fix"
mkdir -p "$INSTALL_DIR"

cat > "$INSTALL_DIR/asm100_poweroff.sh" << 'POWEROFF'
#!/bin/bash
# ASM100 direct PM register power off
# Bypasses broken ACPI by writing S5 sleep type (0x3C00) to PM1a_CNT_BLK (port 0x1804)
# Values extracted from this machine's FADT (PM1a_CNT_BLK=0x1804) and DSDT (S5 SLP_TYP=7)
# Register value: (SLP_TYP << 10) | SLP_EN = (7 << 10) | (1 << 13) = 0x3C00
sync; sync
python3 -c "
import struct, os
fd = os.open('/dev/port', os.O_WRONLY)
os.lseek(fd, 0x1804, os.SEEK_SET)
os.write(fd, struct.pack('<H', 0x3C00))
os.close(fd)
"
POWEROFF
chmod +x "$INSTALL_DIR/asm100_poweroff.sh"
echo "Power-off script installed to $INSTALL_DIR/asm100_poweroff.sh"

# Step 3: Hook into custom.sh for boot persistence
# Batocera uses a squashfs root with tmpfs overlay, so /sbin/poweroff
# resets every boot. We replace it on each boot via custom.sh.
CUSTOM_SH="/userdata/system/custom.sh"
HOOK_MARKER="asm100_poweroff"

if grep -qF "$HOOK_MARKER" "$CUSTOM_SH" 2>/dev/null; then
    echo "Boot hook already present in custom.sh, skipping."
else
    if [ ! -f "$CUSTOM_SH" ]; then
        echo "#!/bin/bash" > "$CUSTOM_SH"
        chmod +x "$CUSTOM_SH"
    fi
    cat >> "$CUSTOM_SH" << HOOKEOF

# ASM100 shutdown fix: replace broken ACPI poweroff with direct PM register write
cp /userdata/system/add-ons/alienware-asm100-fix/asm100_poweroff.sh /sbin/poweroff
chmod +x /sbin/poweroff
HOOKEOF
    echo "Boot hook added to custom.sh"
fi

# Step 4: Apply immediately
cp "$INSTALL_DIR/asm100_poweroff.sh" /sbin/poweroff
chmod +x /sbin/poweroff

echo ""
echo "=============================================="
echo " Alienware ASM100 shutdown fix installed!"
echo "=============================================="
echo ""
echo " The fix is active now and will persist"
echo " across reboots."
echo ""
echo " Test by shutting down from the"
echo " EmulationStation menu."
echo ""
echo " To uninstall, run:"
echo " bash /userdata/system/add-ons/alienware-asm100-fix/uninstall.sh"
echo "=============================================="
