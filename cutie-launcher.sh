if [ -d "cutie-launcher" ] ;then
 cd cutie-launcher
 git pull

else 
  sudo apt-get -y install git 
  git clone --depth=1 https://github.com/mathew-dennis/cutie-launcher.git
  cd cutie-launcher
  sudo apt-get -y build-dep .
fi

mkdir build
cd build
cmake --install-prefix=/usr ..
make
sudo make install


