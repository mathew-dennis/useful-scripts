#!/bin/bash

echo "Welcome to Cutie Generic Project Builder
        Please input a project name to build
        Available projects are:
         1: cutie-home
         2: cutie-launcher
         3: libcutiedesktopfileparser
         4: qml-module-cutiewlc
         5: cutie-wlc
         6: libcutiewlc
         7: cutie-settings
         8: cutie-panel
         9: libcutiesysteminfo"
         
read -p "Please input project name: " input

# Handle project selection
if [[ "$input" == "cutie-home" || "$input" == "1" ]]; then
  project="cutie-home"
elif [[ "$input" == "cutie-launcher" || "$input" == "2" ]]; then
  project="cutie-launcher"
elif [[ "$input" == "libcutiedesktopfileparser" || "$input" == "3" ]]; then
  project="libcutiedesktopfileparser"
elif [[ "$input" == "qml-module-cutiewlc" || "$input" == "4" ]]; then
  project="qml-module-cutiewlc"
elif [[ "$input" == "cutie-wlc" || "$input" == "5" ]]; then
  project="cutie-wlc"
elif [[ "$input" == "libcutiewlc" || "$input" == "6" ]]; then
  project="libcutiewlc"
elif [[ "$input" == "cutie-settings" || "$input" == "7" ]]; then
  project="cutie-settings"
elif [[ "$input" == "cutie-panel" || "$input" == "8" ]]; then
  project="cutie-panel"
elif [[ "$input" == "libcutiesysteminfo" || "$input" == "9" ]]; then
  project="libcutiesysteminfo"
else
  echo "Invalid input. Please try again." && exit 1
fi

echo "Building $project ..."
sleep .5

if [ -d "$project" ] ;then
  echo "Directory $project exists. Pulling latest changes..."
  cd "$project" || exit 1
  git pull
else
  echo "Cloning $project repository..."
  sudo apt-get -y install git
  git clone --depth=1 "https://github.com/mathew-dennis/$project.git"
  cd "$project" || exit 1
  sudo apt-get -y build-dep .
fi

# Clean up old build dir if it exists from a previous pull run
rm -rf build
mkdir build
cd build || exit 1

# Run cmake and make
cmake --install-prefix=/usr .. || { echo "CMake failed."; exit 1; }
make || { echo "Make failed."; exit 1; }

# Install the project
sudo make install || { echo "Installation failed."; exit 1; }

echo "$project has been successfully built and installed!"
