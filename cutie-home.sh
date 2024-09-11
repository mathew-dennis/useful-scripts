#!/bin/bash

if [ -d "cutie-home" ] ;then
 cd cutie-home
 git pull

else 
  sudo apt-get -y install git
  git clone --depth=1 https://github.com/mathew-dennis/cutie-home.git
  cd cutie-home
  sudo apt-get -y build-dep .
fi

mkdir build
cd build
cmake --install-prefix=/usr ..
make
sudo make install


