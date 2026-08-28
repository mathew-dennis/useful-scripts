#!/bin/bash

# Array containing all projects
ALL_PROJECTS=(
  "cutie-home"
  "cutie-launcher"
  "libcutiedesktopfileparser"
  "qml-module-cutiewlc"
  "cutie-wlc"
  "libcutiewlc"
  "cutie-settings"
  "cutie-panel"
  "libcutiesysteminfo"
  "libcutiedatetime"
  "libcutiewaydroid"
  "libcutiescreenlock"
  "qml-module-cutie"
  "libcutiebattery"
  "cutie-system-monitor"
  "cutie-the-explorer"
  "cutie-music"
  "cutie-notes"
  "cutie-gallery"
)

# Build function
build_project() {
  local project=$1
  local base_dir=$(pwd)

  echo "Building $project ..."
  sleep .5

  if [ -d "$project" ]; then
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
  cmake --install-prefix=/usr .. || { echo "CMake failed for $project."; exit 1; }
  make || { echo "Make failed for $project."; exit 1; }

  # Install the project
  sudo make install || { echo "Installation failed for $project."; exit 1; }

  echo "$project has been successfully built and installed!"
  echo "----------------------------------------------------"

  # Return to base directory for sequential calls
  cd "$base_dir" || exit 1
}

# Print dynamic menu
echo "Welcome to Cutie Generic Project Builder"
echo "Please input a project name or number to build"
echo "Available projects are:"
echo "  0: Build ALL projects"

for i in "${!ALL_PROJECTS[@]}"; do
  printf "%3d: %s\n" "$((i + 1))" "${ALL_PROJECTS[$i]}"
done

read -p "Please input project name or number: " input

# Handle option 0 (Build All)
if [[ "$input" == "0" || "$input" == "all" ]]; then
  echo "Starting build process for ALL projects..."
  for proj in "${ALL_PROJECTS[@]}"; do
    build_project "$proj"
  done
  echo "All projects have been successfully built and installed!"
  exit 0
fi

# Convert numeric input to name, or pass raw string
if [[ "$input" =~ ^[0-9]+$ ]]; then
  project="${ALL_PROJECTS[$((input - 1))]}"
else
  project="$input"
fi

# Validate target against array
if [[ -z "$project" ]] || [[ " ${ALL_PROJECTS[*]} " != *" $project "* ]]; then
  echo "Invalid input. Please try again."
  exit 1
fi

# Execute build for the selected project
build_project "$project"
