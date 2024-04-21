#! /bin/bash

# Print verbose message, only if verbose output is enabled
print_verbose() {
  if [[ $VERBOSE == true ]]; then
    printf "${BLUE}[ INFO ]${RESET} %s\n" "$1"
  fi
}

print_info() {
  printf "[ INFO ] %s\n" "$1"
}

print_warning() {
  printf "${YELLOW}[ WARNING ]${RESET} %s\n" "$1"
}

exit_error() {
  if [[ $DEBUG == false ]]; then
    exit 1
  fi
}

# Print error and exit status 1
print_error() {
  printf "${RED}[ ERROR ]${RESET}: %s\n" "$1"
  exit_error
}

# Check if last command was successful, otherwise print_error
check_error() {
  if [ $? -ne 0 ]; then
    print_error "$1"
  fi
}

# Function to install dependencies
install_dependencies() {
    echo "Installing dependencies..."
    apt-get update
    check_error "Could not update apt"
    apt-get install -y build-essential ninja-build libslirp-dev python3-venv pkg-config libglib2.0-dev libpixman-1-dev zlib1g-dev
    check_error "Could not install packages"
    echo "Dependencies installed successfully."
}

# Function to download and install the latest QEMU from source
install_qemu_from_source() {
    echo "Downloading QEMU source..."
    # Download if not already existing
    if [[ ! -e $QEMU_VERSION.tar.xz ]]; then
        wget https://download.qemu.org/$QEMU_VERSION.tar.xz
        check_error "Could not download qemu"
    else
        print_verbose "Qemu already downloaded, skipping..."
    fi
    # Extract if not already extracted
    if [[ ! -d $QEMU_VERSION ]]; then
        tar xvJf $QEMU_VERSION.tar.xz
        check_error "Could not extract qemu"
    else
        print_verbose "Qemu already extracted, skipping..."
    fi

    # Build qemu if not already built
    if [[ ! -e $(installed_qemu_location) ]]; then
        cd $QEMU_VERSION
        check_error "Could not find qemu"
        echo "Configuring QEMU..."
        ./configure
        check_error "Could not configure qemu"
        echo "Building QEMU..."
        make -j$(nproc)
        check_error "Could not build qemu"
        cd ../
        echo "QEMU built successfully."
    else
        print_verbose "Qemu already built, skipping.."
    fi

}

installed_qemu_location() {
    echo $(readlink -f "$QEMU_VERSION/build")

}

install_qemu() {
    install_dependencies
    install_qemu_from_source
    return 0
}

# install_qemu

