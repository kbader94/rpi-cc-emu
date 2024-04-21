#! /bin/bash

# Kernel build args
CORES=$(grep -c '^processor' /proc/cpuinfo)
RPI_VERSION=""
RPI_ARCH=""
RPI_CC=""
KERNEL=""
KERNEL_CONFIG=""
KERNEL_NAME=""
KERNEL_IMAGE_TYPE=""

MAKE_OUTPUT="make_output.log"

line_of_text_in_file() {
  local search_text="$1"
  local file="$2"
  local line_number=$(grep -nF "$search_text" $file | cut -d : -f 1)
  # Check if the text was found in the file
  if [[ -n $line_number ]]; then
    echo "$line_number"
  else
    echo "-1"  # Return -1 if not found
  fi
}

lines_in_file() {
  local file="$1"
  local line_count=$(wc -l < "$file")
  echo "$line_count"
}


progress_from_kernel_build_output() {
  local kernel_build_text="$1"
  local line_num=$(line_of_text_in_file "$kernel_build_text" "../$MAKE_OUTPUT")

    if [[ $line_num -lt 0 ]]; then
        echo "-1"
        return
    fi

    local total_lines=$(lines_in_file "../$MAKE_OUTPUT")
    if [[ $total_lines -lt 0 ]]; then
        echo "-1"
        return
    fi

    local progress_dec=$(echo "scale=6; $line_num / $total_lines" | bc)
    if [[ $(echo "$progress_dec < 0" | bc) -eq 1 ]]; then
        echo "-1"
        return
    fi

    local return_progress=$(echo "$progress_dec * 100" | bc)
    echo "$return_progress"
}

# Check if option is present and enabled in .config
config_option_enabled() {
  grep -q "^$1=" .config
}

# Check if option is present but disables in .config
config_option_disabled() {
  grep -q "$1 is not set" .config
}

# Function to modify an existing config option or append it to the end of the .config file
change_config_option() {
    if config_option_enabled "$1"; then
        # Modify the existing config option
        sed -i "s/^$1=\".*\"/$1=\"$2\"/" .config
    elif config_option_disabled "$1"; then
        # Enable and set the config option
        sed -i "s/^# $1 is not set$/$1=\"$2\"/" .config
    else
        printf "WARNING: $1 not found in existing .config file, appending to end\n"
        # Append the config option to the end of the file       
        # echo "$1=$2" >> .config
    fi
}

# Download kernel .config for specified RPI_ARCH and KERNEL_CONFIG
download_kernel_config() {
  printf "Downloading kernel config...\n"
  # Download kernel config from the specified URL
  curl -o "arch/$RPI_ARCH/configs/$KERNEL_CONFIG" "https://raw.githubusercontent.com/raspberrypi/linux/rpi-6.1.y/arch/arm/configs/$KERNEL_CONFIG"
  check_error "Could not download kernel config\n"
  printf "Kernel config successfully downloaded\n"
}

# Get Kernel build args from RPI_VERSION and RPI_ARCH
get_kernel_build_args() { # rpi_version, [optional] rpi_arch
    local rpi_version=${1:-"4"}
    local arch=${2:-"arm64"}

    # Set KERNEL, KERNEL_CONFIG, and RPI_ARCH according to rpi version and arch
    # Note: RPI 4 is 64 bit by default, unless rpi_arch == arm
    case $rpi_version in
        1)
            KERNEL_CONFIG="bcmrpi_defconfig"
            KERNEL=kernel  
            RPI_ARCH="arm" # only supports 32 bit
            ;;
        2 | 3)
            KERNEL=kernel7
            KERNEL_CONFIG="bcm2709_defconfig"
            RPI_ARCH="arm" # only supports 32 bit
            ;;
        4)
            KERNEL_CONFIG="bcm2711_defconfig"
            if [[ $arch == "arm64" ]]; then
              KERNEL=kernel8
              RPI_ARCH="arm64"
              print_verbose "Raspberry Pi 4 also supports 32 bit kernel
              (kernel7l) by specifying arch=arm"
            elif [[ $arch == "arm" ]]; then
              KERNEL=kernel7l
              RPI_ARCH="arm"
              print_verbose "Raspberry Pi 4 also supports 64 bit kernel
              (kernel8) by specifying arch=arm64"
            else
              print_error "Invalid RPI_ARCH"
            fi
            ;;
        5)
            KERNEL=kernel_2712
            KERNEL_CONFIG="bcm2712_defconfig"
            RPI_ARCH="arm64"
            print_verbose "The standard, bcm2711_defconfig-based kernel
    (kernel8.img) also runs on Raspberry Pi 5."
            print_verbose "For best performance you should use kernel_2712.img, 
            but for situations where a 4KB page size is required then kernel8.img 
            (kernel=kernel8.img) should be used."
            ;;
        *)
            print_error "Invalid Raspberry Pi version: $rpi_version"
            ;;
    esac

    if [[ $arch == "arm" ]]; then
        RPI_ARCH="arm"
        RPI_CC="arm-linux-gnueabihf-"
    elif [[ $arch == "arm64" ]]; then
        RPI_ARCH="arm64"
        RPI_CC="aarch64-linux-gnu-"
    else
        print_error "Invalid Raspberry Pi architecture: $arch"
    fi

    print_verbose "CORES: $CORES"
    print_verbose "RPI_VERSION: $RPI_VERSION"
    print_verbose "RPI_ARCH: $RPI_ARCH"
    print_verbose "RPI_CC: $RPI_CC"
    print_verbose "KERNEL: $KERNEL"
    print_verbose "KERNEL_CONFIG: $KERNEL_CONFIG"
    print_verbose "KERNEL_NAME: $KERNEL_NAME"

}

git_kernel() { # [ optional ] linux_version, [ optional ] linux_repo
  local linux_version="$1"
  local linux_repo="$2"
  local linux_branch=""

  # Check if $linux_version is provided
  if [ -z "$linux_version" ]; then
    # No version, use master
    linux_branch="master"
  else
    linux_branch="v$linux_version"
  fi

  # Check if $linux_repo is provided
  if [ -z "$linux_repo" ]; then
    # No linux repo, use mainline
    linux_repo="https://github.com/torvalds/linux.git"
  fi

  print_info "Downloading linux kernel"

  # Clone the specified Linux kernel version from the provided repository
  if [ ! -d "linux" ]; then
    # Clone in bg, redirect output
    git clone --progress --depth 1 --branch "$linux_branch" "$linux_repo" &> git_clone_output.log &
    local pid=$!

    # Monitor git clone progress and update progress bar
    while kill -0 "$pid" >/dev/null 2>&1; do
      if [[ -f git_clone_output.log ]]; then
       
        # Sanitize git_clone_output
        cleaned_output=$(tr -d '\000' < git_clone_output.log | tr '\r' '\n')
        # Extract progress information from the last line
        last_line=$(echo "$cleaned_output" | tail -n 1)
        # Update progress bar
        if [[ $last_line =~ "Receiving objects:" && $last_line =~ ([0-9]+)% ]]; then
          progress="${BASH_REMATCH[1]}"
          update_progress "$progress"
        fi

      fi     
      sleep 1 
    done

    # git finished
    check_error "Could not download kernel"
    complete_progress
    print_success "Kernel acquired"

  fi

}

# Function to build the Linux kernel
build_kernel() { # rpi_arch, cross_compiler, kernel_config, [ true | false ] debug config, [ optional ] kernel_name
  local rpi_arch="${1:?$(print_error "rpi_arch paramater is null")}"
  local cross_compiler="${2:?$(print_error "cross_compiler parameter is null")}"
  local kernel_config="${3:?$(print_error "kernel_config parameter is null")}"
  local use_debug_config=${4:-false}
  local kernel_name=${5:-"rpi-qemu"}
  
  # Check and install dependencies
  check_packages
  
  # Change to linux dir
  cd linux
  check_error "Invalid linux source directory"

  # Check if the recommended config exists for this rpi, otherwise download it
  if [ ! -e "arch/$rpi_arch/configs/$kernel_config" ]; then
    printf "Missing kernel config\n"
    download_kernel_config
  fi

  # Kernel Default Config
  printf "Configuring linux for Raspberry Pi $RPI_VERSION\n"
  make ARCH="$rpi_arch" CROSS_COMPILE="$cross_compiler" "$kernel_config"
  check_error "Failed to configure the Linux kernel."

  # Kernel Debug Config
  if [[ $use_debug_config == true ]]; then
      # Enable debug info
      change_config_option "CONFIG_DEBUG_KERNEL" "y"
      change_config_option "CONFIG_DEBUG_INFO" "y"
      change_config_option "CONFIG_TRACEPOINTS" "y"
      change_config_option "CONFIG_EVENT_TRACING" "y"
      change_config_option "CONFIG_KASAN" "y"
      change_config_option "CONFIG_KASAN_INLINE" "y"
      change_config_option "CONFIG_KCOV" "y"
      change_config_option "CONFIG_GDB_SCRIPTS" "y"
      change_config_option "CONFIG_GDB_SCRIPTS_ON_ROOTFS" "y"
  fi

  # Generate and set unique kernel name
  KERNEL_NAME="$kernel_name-$(date '+%S%M%H%d%m%y')"
  change_config_option "CONFIG_LOCALVERSION" "-$KERNEL_NAME"
  # sed -i "s/^CONFIG_LOCALVERSION=\".*\"/CONFIG_LOCALVERSION=\"-v8-uartioctl-cc-$kernel_name\"/" .config

  # Set zimage according to arch
  if [[ $rpi_arch == "arm" ]]; then
      KERNEL_IMAGE_TYPE=zImage;
  else
      KERNEL_IMAGE_TYPE=Image;
  fi

  print_info "Building linux kernel"

  # Build the Linux kernel in bg, output to log and monitor 
  # if [[ $ARG_NO_KERNEL_BUILD == false ]]; then 
    make ARCH="$rpi_arch" -j"$CORES" CROSS_COMPILE="$cross_compiler" "$KERNEL_IMAGE_TYPE" modules dtbs > $MAKE_OUTPUT 2>&1 &
    local pid=$!

    # Monitor the progress and update the status bar
    while kill -0 $pid > /dev/null 2>&1; do
        sleep 1

        # Sanitize git_clone_output
        local cleaned_output=$(tr -d '\000' < make_output.log)
        # Extract progress information from the last line
        local last_line=$(echo "$cleaned_output" | tail -n 1)
        
        # Update progress bar based on kernel build output
        local progress=$(progress_from_kernel_build_output "$last_line")
        update_progress $progress
    done

    check_error "Failed to build the Linux kernel"
  # fi
  complete_progress
  print_success "Kernel compilation completed successfully"
  cd ../
}

# Function to copy kernel files to the specified boot and root locations
copy_kernel_to_rpi() { #rpi-arch, boot_mount, root_mount
  local rpi_arch="${1:?$(print_error "rpi_arch parameter is null or unset")}"
  local boot_mount="${2:?$(print_error "boot_mount parameter is null or unset")}"
  local root_mount="${3:?$(print_error "root_mount parameter is null or unset")}"
  if [ ! -d $boot_mount ]; then print_error "invalid boot_mount"; fi # validate boot_mount is directory
  if [ ! -d $root_mount ]; then print_error "invalid root_mount"; fi # validate root_mount is directory

  # Copy kernel image and device tree blobs to the boot mount point
  cp "linux/arch/$rpi_arch/boot/$KERNEL_IMAGE_TYPE.gz" "$boot_mount/$kernel_name.img"
  check_error "Could not copy kernel image to raspios"
  cp "linux/arch/$rpi_arch/boot/dts/broadcom/"*.dtb "$boot_mount/"
  check_error "Could not copy device tree blobs to raspios"
  # Install kernel modules to the root mount point
  cp -r "linux/build/modules/lib/modules" "$root_mount/lib"
  check_error "Could not copy kernel modules to raspios"
  # Set this kernel to the active kernel in config.txt
  if grep -q "^kernel=" "$boot_mount/config.txt"; then
    # Update config.txt to reflect the new kernel image filename
    sudo sed -i "s|^kernel=.*$|kernel=$kernel_name.img|" "$boot_mount/config.txt"
  else
    # If 'kernel' line doesn't exist, append it to config.txt
    echo kernel=$kernel_name.img | sudo tee -a "$boot_mount/config.txt" > /dev/null
  fi

  printf "Kernel files copied to the Raspberry Pi successfully!\n"
  
}