#!/bin/bash

# Define the base workspace directory for cloning/building source code
BASE_DIR=~/cutie-sources
mkdir -p "$BASE_DIR"

echo "Welcome to Cutie Generic System-Wide Project Builder
        Please input a project name to build
        Available projects are:
         0: BUILD ALL IN ORDER
         1: cutie-home
         2: cutie-launcher
         3: libcutiedesktopfileparser
         4: qml-module-cutiewlc
         5: cutie-wlc
         6: libcutiewlc
         7: qt6-screencopy
         8: qml-module-cutie
         9: libatmosphere
         10: atmospheres
         11: libcutiestore
         12: qt6-foreign-toplevel-management
         13: qt6-output-power-management
         14: cutie-panel
         15: libcutievolume
         16: libcutiefeedback
         17: cutie-keyboard
         18: libcutienetworking
         19: libcutiemodem
         20: cutie-settings
         21: layer-shell-qt (KDE dependency)
         22: libcutiesysteminfo
         23: libcutiewaydroid
         24: libcutiedatetime
         25: cutie-the-explorer"

read -p "Please input project name or number: " input

# Function to handle the build and system-wide installation process
build_project() {
    local project=$1
    echo "=========================================="
    echo "BUILDING SYSTEM-WIDE: $project"
    echo "=========================================="

    cd "$BASE_DIR" || exit 1

    if [ -d "$project" ] ;then
        echo "Directory $project exists. Updating..."
        cd "$project" && git pull
    else
        echo "Cloning $project repository..."
        if [[ "$project" == "layer-shell-qt" ]] ;then
            git clone --depth=1 "https://github.com/KDE/layer-shell-qt.git"
        elif [[ "$project" == "qt6-screencopy" || "$project" == "qml-module-cutie" || \
              "$project" == "libatmosphere" || "$project" == "atmospheres" || \
              "$project" == "libcutiestore" || "$project" == "qt6-foreign-toplevel-management" || \
              "$project" == "qt6-output-power-management" || "$project" == "cutie-panel" || \
              "$project" == "libcutievolume" || "$project" == "libcutiefeedback" || \
              "$project" == "cutie-keyboard" || "$project" == "libcutienetworking" || \
              "$project" == "libcutiemodem"  ]] ;then
            git clone --depth=1 "https://github.com/cutie-shell/$project.git"
        else
            git clone --depth=1 "https://github.com/mathew-dennis/$project.git"
        fi
        cd "$project" || exit 1
        sudo apt-get -y build-dep . || echo "Note: build-dep skipped or not required."
    fi

    # Check for CMakeLists.txt (Atmospheres fix)
    if [ ! -f "CMakeLists.txt" ]; then
        echo "No CMakeLists.txt found. Copying files directly..."
        sudo cp -rv ./* /usr/share/
        return 0
    fi

    # Clean previous build artifacts
    rm -rf build
    mkdir build && cd build || exit 1

    # Configure CMake for standard system-wide installation (/usr)
    cmake .. \
      -DCMAKE_INSTALL_PREFIX="/usr" \
      -DCMAKE_INSTALL_BINDIR=bin \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DKDE_INSTALL_QTPLUGINDIR="/usr/lib/x86_64-linux-gnu/qt6/plugins" \
      -DKDE_INSTALL_QMLDIR="/usr/lib/x86_64-linux-gnu/qt6/qml" \
      -DQT_PLUGIN_INSTALL_DIR="/usr/lib/x86_64-linux-gnu/qt6/plugins"

    make -j$(nproc) || { echo "Make failed on $project"; return 1; }
    sudo make install || { echo "Install failed on $project"; return 1; }

    return 0
}

# Logic for Build Sequence
if [[ "$input" == "0" || "$input" == "all" ]]; then
    projects=(
        "layer-shell-qt" "libcutiewlc" "libcutiestore" "libcutievolume"
        "libcutiefeedback" "libcutienetworking" "libcutiemodem"
        "libcutiedesktopfileparser" "libcutiesysteminfo" "libcutiewaydroid" "libcutiedatetime"
        "libatmosphere" "qt6-screencopy" "qt6-foreign-toplevel-management" "qt6-output-power-management"
        "atmospheres" "qml-module-cutiewlc" "qml-module-cutie"
        "cutie-wlc" "cutie-home" "cutie-launcher" "cutie-panel"
        "cutie-keyboard" "cutie-settings"
    )
    for p in "${projects[@]}"; do
        build_project "$p" || exit 1
    done
    echo "ALL PROJECTS BUILT AND INSTALLED SYSTEM-WIDE SUCCESSFULLY!"
else
    case $input in
        1|cutie-home) project="cutie-home" ;;
        2|cutie-launcher) project="cutie-launcher" ;;
        3|libcutiedesktopfileparser) project="libcutiedesktopfileparser" ;;
        4|qml-module-cutiewlc) project="qml-module-cutiewlc" ;;
        5|cutie-wlc) project="cutie-wlc" ;;
        6|libcutiewlc) project="libcutiewlc" ;;
        7|qt6-screencopy) project="qt6-screencopy" ;;
        8|qml-module-cutie) project="qml-module-cutie" ;;
        9|libatmosphere) project="libatmosphere" ;;
        10|atmospheres) project="atmospheres" ;;
        11|libcutiestore) project="libcutiestore" ;;
        12|qt6-foreign-toplevel-management) project="qt6-foreign-toplevel-management" ;;
        13|qt6-output-power-management) project="qt6-output-power-management" ;;
        14|cutie-panel) project="cutie-panel" ;;
        15|libcutievolume) project="libcutievolume" ;;
        16|libcutiefeedback) project="libcutiefeedback" ;;
        17|cutie-keyboard) project="cutie-keyboard" ;;
        18|libcutienetworking) project="libcutienetworking" ;;
        19|libcutiemodem) project="libcutiemodem" ;;
        20|cutie-settings) project="cutie-settings" ;;
        21|layer-shell-qt) project="layer-shell-qt" ;;
        22|libcutiesysteminfo) project="libcutiesysteminfo" ;;
        23|libcutiewaydroid) project="libcutiewaydroid" ;;
        24|libcutiedatetime) project="libcutiedatetime" ;;
        25|cutie-the-explorer) project="cutie-the-explorer" ;;
        *) echo "Invalid input." && exit 1 ;;
    esac
    build_project "$project"
fi
