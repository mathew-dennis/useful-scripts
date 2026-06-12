#!/bin/bash

# Define the base directory and install prefix
BASE_DIR=~/Desktop/cutie
export PREFIX=$BASE_DIR/install

# 1. Create the folder if it doesn't exist
mkdir -p $PREFIX/lib/cmake/LayerShellQt6
echo 'include("${CMAKE_CURRENT_LIST_DIR}/../LayerShellQt/LayerShellQtConfig.cmake")' > $PREFIX/lib/cmake/LayerShellQt6/LayerShellQt6Config.cmake

echo "Welcome to Cutie Generic Project Builder
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
         22: libcutiesysteminfo"
         
read -p "Please input project name: " input

# 1. Function to handle the build process
build_project() {
    local project=$1
    echo "=========================================="
    echo "BUILDING: $project"
    echo "=========================================="
    
    cd "$BASE_DIR" || exit 1

    if [ -d "$project" ] ;then
        echo "Directory $project exists. Updating..."
        cd "$project" && git pull
    else
        echo "Cloning $project repository..."
        # Unified organization logic
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
        cd "$project"
        sudo apt-get -y build-dep .
    fi

    # Check for CMakeLists.txt (Atmospheres fix)
    if [ ! -f "CMakeLists.txt" ]; then
        echo "No CMakeLists.txt found. Copying files directly..."
        cp -rv ./* "$PREFIX/share"
        return 0
    fi

    mkdir -p build && cd build
    export PKG_CONFIG_PATH=$PREFIX/lib/x86_64-linux-gnu/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
    export CMAKE_PREFIX_PATH=$PREFIX:$CMAKE_PREFIX_PATH

cmake .. \
      -DCMAKE_INSTALL_PREFIX="$PREFIX" \
      -DCMAKE_PREFIX_PATH="$PREFIX" \
      -DCMAKE_INSTALL_BINDIR=bin \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DKDE_INSTALL_QTPLUGINDIR="$PREFIX/lib/qt6/plugins" \
      -DKDE_INSTALL_QMLDIR="$PREFIX/lib/qt6/qml" \
      -DQT_PLUGIN_INSTALL_DIR="$PREFIX/lib/qt6/plugins"
      
    make -j$(nproc) || { echo "Make failed on $project"; return 1; }
    make install || { echo "Install failed on $project"; return 1; }
    
    return 0
}

# 2. Logic for Build Sequence
if [[ "$input" == "0" ]]; then
    # layer-shell-qt MUST be built very early as it is a core dependency
    # Note: Added "libcutiesysteminfo" alongside the other structural/info libraries
    projects=(
        "layer-shell-qt" "libcutiewlc" "libcutiestore" "libcutievolume" 
        "libcutiefeedback" "libcutienetworking" "libcutiemodem" 
        "libcutiedesktopfileparser" "libcutiesysteminfo" "libatmosphere" "qt6-screencopy" 
        "qt6-foreign-toplevel-management" "qt6-output-power-management" 
        "atmospheres" "qml-module-cutiewlc" "qml-module-cutie" 
        "cutie-wlc" "cutie-home" "cutie-launcher" "cutie-panel" 
        "cutie-keyboard" "cutie-settings"
    )
    for p in "${projects[@]}"; do
        build_project "$p" || exit 1
    done
    echo "ALL PROJECTS BUILT SUCCESSFULLY!"
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
        *) echo "Invalid input." && exit 1 ;;
    esac
    build_project "$project"
fi
