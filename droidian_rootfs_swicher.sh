#!/system/bin/sh

# 1. Initialize file and find the current OS name
sudo touch /userdata/current_os_name
CURRENT_OS=$(cat /userdata/current_os_name)

if [ -z "$CURRENT_OS" ]; then
    CURRENT_OS="primary"
fi

echo "Current OS: $CURRENT_OS"
echo "-----------------------------------"

# 2. Print available OS list by trimming the path and prefix
echo "Available OS List:"
find /userdata/ -name "rootfs.img-*" | sed 's|/userdata/rootfs.img-||'

# 3. Take user input
echo "-----------------------------------"
echo -n "Enter the OS you want to switch to: "
read choice

# 4. Exit if choice is already the active OS
if [ "$choice" = "$CURRENT_OS" ]; then
    echo "You are already on $choice. Exiting."
    exit 0
fi

# 5. Verify the chosen OS backup file exists before continuing
if [ ! -f "/userdata/rootfs.img-$choice" ]; then
    echo "Error: OS '$choice' not found in /userdata/!"
    exit 1
fi

# 6. Generate the OpenRecoveryScript for TWRP
# (Using single quotes 'EOF' prevents commands from evaluating prematurely)
cat << 'EOF' > /cache/recovery/openrecoveryscript
# Mount system partitions inside TWRP
mount /data
mount /userdata

# Backup current running OS image back to its named slot
mv /data/rootfs.img /userdata/rootfs.img-__CURRENT_OS_PLACEHOLDER__

# Deploy the selected OS image to active slot
mv /userdata/rootfs.img-__CHOICE_PLACEHOLDER__ /data/rootfs.img

# Update the OS tracking text file
cmd echo "__CHOICE_PLACEHOLDER__" > /userdata/current_os_name

# Boot back into normal Android system
reboot
EOF

# 7. Dynamically swap the variables cleanly into the script file
sed -i "s/__CURRENT_OS_PLACEHOLDER__/$CURRENT_OS/g" /cache/recovery/openrecoveryscript
sed -i "s/__CHOICE_PLACEHOLDER__/$choice/g" /cache/recovery/openrecoveryscript

# 8. Set permissions and trigger TWRP automation
chmod 0777 /cache/recovery/openrecoveryscript
echo "Rebooting to TWRP to swap operating systems..."
sudo reboot recovery
