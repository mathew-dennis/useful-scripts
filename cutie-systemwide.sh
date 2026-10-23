#!/bin/bash

# Base workspace directory for cloning/building source code
BASE_DIR=~/cutie-sources
mkdir -p "$BASE_DIR"

# All projects, in dependency (build) order; menu numbers are position + 1
PROJECTS=(
    layer-shell-qt libcutiewlc libcutiestore libcutievolume libcutiefeedback
    libcutienetworking libcutiemodem libcutiedesktopfileparser
    libcutiesysteminfo libcutiewaydroid libcutiedatetime libatmosphere
    qt6-screencopy qt6-foreign-toplevel-management qt6-output-power-management
    atmospheres qml-module-cutiewlc qml-module-cutie cutie-wlc cutie-home
    cutie-launcher cutie-panel cutie-keyboard cutie-settings cutie-the-explorer
)
# Subset for building Cutie apps
ESSENTIALS=(libcutiestore libatmosphere atmospheres libcutiefeedback qml-module-cutie)

echo "Welcome to Cutie Generic System-Wide Project Builder"
echo "Available projects:"
echo "   0: BUILD ALL IN ORDER"
echo "   e: BUILD ESSENTIALS FOR CUTIE APPS (${ESSENTIALS[*]})"
for i in "${!PROJECTS[@]}"; do printf '  %2d: %s\n' $((i + 1)) "${PROJECTS[i]}"; done
read -rp "Please input project name or number: " input

# GitHub organisation that hosts each project
repo_org() {
    case $1 in
        layer-shell-qt) echo KDE ;;
        qt6-screencopy|qml-module-cutie|libatmosphere|atmospheres|libcutiestore|\
        qt6-foreign-toplevel-management|qt6-output-power-management|cutie-panel|\
        libcutievolume|libcutiefeedback|cutie-keyboard|libcutienetworking|libcutiemodem)
            echo cutie-shell ;;
        *) echo mathew-dennis ;;
    esac
}

# Install the Debian build-deps, skipping packages we build from source here
# (apt-get build-dep aborts entirely when one of them isn't in the archive)
install_build_deps() {
    local skip deps
    skip=$(IFS='|'; echo "${PROJECTS[*]}")
    deps=$(dpkg-checkbuilddeps 2>&1 \
        | sed -n 's/.*Unmet build dependencies: //p' \
        | sed -E 's/\([^)]*\)|\[[^]]*\]|<[^>]*>//g; s/\|[[:space:]]*[^[:space:]]+//g' \
        | tr -s ' ' '\n' | grep -vE "^($skip)|^$")
    if [ -n "$deps" ]; then
        sudo apt-get -y install $deps || echo "Note: some build dependencies could not be installed."
    fi
}

build_project() {
    local project=$1
    echo "=========================================="
    echo "BUILDING SYSTEM-WIDE: $project"
    echo "=========================================="

    cd "$BASE_DIR" || return 1
    if [ -d "$project" ]; then
        echo "Directory $project exists. Updating..."
        git -C "$project" pull
    else
        echo "Cloning $project repository..."
        git clone --depth=1 "https://github.com/$(repo_org "$project")/$project.git" || return 1
    fi
    cd "$project" || return 1
    install_build_deps

    # No CMakeLists.txt (e.g. atmospheres): just copy the files
    if [ ! -f CMakeLists.txt ]; then
        echo "No CMakeLists.txt found. Copying files directly..."
        sudo cp -rv ./* /usr/share/
        return
    fi

    rm -rf build && mkdir build && cd build &&
        cmake --install-prefix=/usr .. && make && sudo make install ||
        { echo "Build or install failed for $project."; return 1; }

    echo "$project has been successfully built and installed!"
    echo "----------------------------------------------------"
}

case $input in
    0|all) set -- "${PROJECTS[@]}" ;;
    e|essentials) set -- "${ESSENTIALS[@]}" ;;
    *)
        [[ $input =~ ^[1-9][0-9]*$ ]] && input=${PROJECTS[input-1]}
        printf '%s\n' "${PROJECTS[@]}" | grep -qxF -- "$input" || { echo "Invalid input."; exit 1; }
        set -- "$input"
        ;;
esac

for p; do build_project "$p" || exit 1; done
echo "BUILT AND INSTALLED SYSTEM-WIDE: $*"
