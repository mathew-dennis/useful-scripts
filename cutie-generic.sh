#!/bin/bash

echo "Welcome to Cutie Generic Project Builder
       Please input a project name to build
       Available projects are:
        1: cutie-home
        2: cutie-launcher
        3: libcutiedesktopfilephraser"
        
read -p "Please input project name: " input

# Handle project selection
if [[ "$input" == "cutie-home" || "$input" == "1" ]]; then
  project="cutie-home"
elif [[ "$input" == "cutie-launcher" || "$input" == "2" ]]; then
  project="cutie-launcher"
elif [[ "$input" == "libcutiedesktopfilephraser" || "$input" == "3" ]]; then
  project="libcutiedesktopfilephraser"
else
  echo "Invalid input. Please try again." && exit 1
fi

echo "Building $project ..."
sleep .5

if [ -d "$project" ] ;then
 echo "Directory $project exists. Pulling latest changes..."
 cd $project
 git pull

else
  echo "Cloning $project repository..."
  sudo apt-get -y install git
  git clone --depth=1 https://github.com/mathew-dennis/$project.git
  cd $project
  sudo apt-get -y build-dep .
fi


mkdir build
cd build

# Run cmake and make
cmake --install-prefix=/usr .. || { echo "CMake failed."; exit 1; }
make || { echo "Make failed."; exit 1; }

# Install the project
sudo make install || { echo "Installation failed."; exit 1; }

echo "$project has been successfully built and installed!"

