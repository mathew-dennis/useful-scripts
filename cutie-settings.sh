if [ -d "cutie-settings" ] ;then
 cd cutie-settings
 git pull

else 
  sudo apt-get -y install git
  git clone --depth=1 https://github.com/mathew-dennis/cutie-settings.git
  cd cutie-settings
  sudo apt-get -y build-dep .
fi

mkdir build
cd build
cmake --install-prefix=/usr ..
make
sudo make install


