#!/bin/bash
#This script is intended to build and install adapttion package for redmi note 7 pro  

#Temporary fix for bluetooth
sudo touch /var/lib/bluetooth/board-address

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



