#!/bin/bash
#This script is intended to build and install adapttion package for redmi note 7 pro  

#Temporary fix for bluetooth
sudo touch /var/lib/bluetooth/board-address

# low voltage handler (temperary, don't use if your battery is good)


SERVICE_NAME="battery-low-voltage-handler.service"
SCRIPT_PATH="/usr/local/bin/battery-low-voltage-handler.sh"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

# Check if service is installed and enabled
if systemctl is-enabled --quiet "$SERVICE_NAME" && systemctl is-active --quiet "$SERVICE_NAME"; then
    echo " $SERVICE_NAME is already installed, enabled, and running."
    echo "No action needed"
else
    echo "  $SERVICE_NAME is not fully installed or not enabled. Proceeding with installation..."

# Download the script
echo " Downloading battery-low-voltage-handler.sh..."
curl -L -o "$SCRIPT_PATH" https://raw.githubusercontent.com/mathew-dennis/useful-scripts/main/battery-low-voltage-handler/battery-low-voltage-handler.sh

chmod +x "$SCRIPT_PATH"

# Download the systemd service file
echo "  Downloading battery-low-voltage-handler.service..."
curl -L -o "$SERVICE_PATH" https://raw.githubusercontent.com/mathew-dennis/useful-scripts/main/battery-low-voltage-handler/battery-low-voltage-handler.service


echo "  Enabling the service..."
systemctl enable "$SERVICE_NAME"

echo "✅ Done! The $SERVICE_NAME service is installed."

# Build adaptation for device
if [ -d "droidian-adaptation-xiaomi-violet" ] ;then
 cd droidian-adaptation-xiaomi-violet
 git pull

else 
  sudo apt-get -y install git devscripts equivs build-essential
  git clone --depth=1 https://github.com/mathew-dennis/droidian-adaptation-xiaomi-violet.git
  cd droidian-adaptation-xiaomi-violet

  sudo apt-get -y build-dep .
  sudo mk-build-deps --install --tool='apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes' debian/control
  rm -f *build-deps_*.*
fi

dpkg-buildpackage -us -uc -b -j5

cd ..
sudo apt-get -y droidian-camera
sudo dpkg -i ada*.deb

# Make journal log volatile
config_file="/etc/systemd/journald.conf"

# Replace 'Storage=auto' with 'Storage=volatile'
sudo sed -i 's/^#Storage=auto/Storage=volatile/' "$config_file"

# Enable custom services
sudo systemctl enable binder-perm.service
sudo systemctl enable droidian-perf.service



