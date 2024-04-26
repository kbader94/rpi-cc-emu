#! /bin/bash

# Kernel build args

KERNEL_CONFIG=""     # Name of Kernel defconfig for specified RPI
KERNEL_NAME=""       # Name of kernel on RaspiOS NOTE: set during kernel make_install
KERNEL_BUILD_NAME="" # Name of kernel in build output

line_of_text_in_file() {
  local search_text="$1"
  local file="$2"
  local line_number=$(grep -nF "$search_text" "$file" | cut -d : -f 1 | tail -n 1)
  # Check if the text was found in the file
  if [[ $line_number != "" && $(is_integer $line_number) ]]; then
    echo "$line_number"
  else
    echo "-1" # Return -1 if not found
  fi
}

lines_in_file() {
  local file="$1"
  local line_count=$(wc -l <"$file")
  echo "$line_count"
}

calculate_progress_from_prev_log() {
  local log_entry="${1:?$(print_error "log_entry paramater is null")}"
  local prev_log="${2:?$(print_error "prev_log paramater is null")}"
  local line_num=$(line_of_text_in_file "$log_entry" "$prev_log")

  if [[ ! -e "$prev_log" ]]; then
    echo "-1" # Previous log does not exist
    return
  fi

  if [[ ! $(is_integer $line_num) ]]; then
    echo "-1" # Line not found
    return
  fi

  if [[ $line_num == "-1" ]]; then
    echo "-1" # Line not found
    return
  fi

  local total_lines=$(lines_in_file "$prev_log")
  if [[ $total_lines -lt 1 ]]; then
    echo "-1" # Previous log is empty OR not found
    return
  fi

  # Calculate the progress
  return_progress=$(($line_num * 100 / $total_lines))
  local progress_int=$(printf "%.0f" "$return_progress")

  if [[ $progress_int -lt 0 ]]; then
    echo "-1" # Progress OOB
    return
  fi
  if [[ $progress_int -gt 100 ]]; then
    echo "-1" # Progress OOB
    return
  fi
  echo "$return_progress"
}

build_kernel_show_progressbar() {
  local rpi_arch="${1:?$(print_error "rpi_arch paramater is null")}"
  local cross_compiler="${2:?$(print_error "cross_compiler parameter is null")}"
  local cpu_cores=$(grep -c '^processor' /proc/cpuinfo)

  # Copy previous log for progress comp
  cp ../kernel_build.log ../kernel_build.log.old

  # Build the Linux kernel in bg, output to log and monitor
  print_info "Building linux kernel"
  # fixme: contrary to the official rpi guide, we only use Image, this might break things for 32 bit
  # However, testing is required because we do specify the kernel name in config.txt, we might get away with this
  make ARCH="$rpi_arch" -j"$cpu_cores" CROSS_COMPILE="$cross_compiler" Image modules dtbs >../kernel_build.log 2>&1 &
  local pid=$!

  # Monitor the progress and update the status bar
  while kill -0 $pid >/dev/null 2>&1; do
    sleep 1

    # Sanitize git_clone_output
    local cleaned_output=$(tr -d '\000' <../kernel_build.log)
    # Extract progress information from the last line
    local last_line=$(echo "$cleaned_output" | tail -n 1)

    # Calculate progress from previous log and update progress bar
    local progress=$(calculate_progress_from_prev_log "$last_line" ../kernel_build.log.old)
    update_progressbar $progress
  done

  check_error "Failed to build the Linux kernel"
  complete_progressbar
  print_success "Kernel compilation completed successfully"
}

install_kernel_show_progressbar() {
  local rpi_arch="${1:?$(print_error "rpi_arch paramater is null")}"
  local cross_compiler="${2:?$(print_error "cross_compiler parameter is null")}"

  # Copy previous log for progress comp
  cp ../kernel_install.log ../kernel_install.log.old

  # Build modules
  make ARCH="$rpi_arch" CROSS_COMPILE="$cross_compiler" INSTALL_MOD_PATH=build modules_install >../kernel_install.log 2>&1 &
  local pid=$!

  # Monitor the progress and update the status bar
  while kill -0 $pid >/dev/null 2>&1; do
    sleep 1

    local cleaned_output=$(tr -d '\000' <../kernel_install.log)
    # Extract progress information from the last line
    local last_line=$(echo "$cleaned_output" | tail -n 1)
    # Check if last_line contains the text "build/lib/modules/"
    if [[ $last_line == *"/kernel/"* ]]; then

      # search for text after kernel name, because kernel name is unique
      last_line=$(echo "$last_line" | awk -F '/kernel/' '{print $2}')

    fi

    # Update progress bar based on kernel build output
    local progress=$(calculate_progress_from_prev_log "$last_line" ../kernel_install.log.old)
    update_progressbar $progress
  done

  check_error "Failed to build the Linux kernel"
  complete_progressbar
  print_success "Kernel compilation completed successfully"
}

# Check if option is present and enabled in .config
config_option_enabled() {
  grep -q "^$1=" .config
}

# Check if option is present but disabled in .config
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
    RPI_ARCH="arm" # only supports 32 bit
    ;;
  2 | 3)
    KERNEL_CONFIG="bcm2709_defconfig"
    RPI_ARCH="arm" # only supports 32 bit
    ;;
  4)
    KERNEL_CONFIG="bcm2711_defconfig"
    if [[ $arch == "arm64" ]]; then
      RPI_ARCH="arm64"
    elif [[ $arch == "arm" ]]; then
      RPI_ARCH="arm"
    fi
    ;;
  5)
    KERNEL_CONFIG="bcm2712_defconfig"
    RPI_ARCH="arm64"
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

  print_verbose "cpu_cores: $cpu_cores"
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

  print_info "Downloading linux kernel"

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

  # Clone the specified Linux kernel version from the provided repository
  if [ ! -d "linux" ]; then
    # Clone in bg, redirect output
    git clone --progress --depth 1 --branch "$linux_branch" "$linux_repo" &>git_clone_output.log &
    local pid=$!

    # Monitor git clone progress and update progress bar
    while kill -0 "$pid" >/dev/null 2>&1; do
      if [[ -f git_clone_output.log ]]; then

        # Sanitize git_clone_output
        cleaned_output=$(tr -d '\000' <git_clone_output.log | tr '\r' '\n')
        # Extract progress information from the last line
        last_line=$(echo "$cleaned_output" | tail -n 1)
        # Update progress bar
        if [[ $last_line =~ "Receiving objects:" && $last_line =~ ([0-9]+)% ]]; then
          progress="${BASH_REMATCH[1]}"
          update_progressbar "$progress"
        fi

      fi
      sleep 1
    done

    # git finished
    check_error "Could not download kernel"
    complete_progressbar
    print_success "Kernel acquired"

  fi

}

# Function to configure and build the Linux kernel
build_kernel() { # rpi_arch, cross_compiler, kernel_config, [ true | false ] debug config, [ optional ] kernel_name
  local rpi_arch="${1:?$(print_error "rpi_arch paramater is null")}"
  local cross_compiler="${2:?$(print_error "cross_compiler parameter is null")}"
  local kernel_config="${3:?$(print_error "kernel_config parameter is null")}"
  local use_debug_config=${4:-false}
  local kernel_name=${5:-"rpi-qemu"}

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

  if [[ ! $ARG_NO_BUILD ]]; then
    build_kernel_show_progressbar $rpi_arch $cross_compiler
  fi

  if [[ ! $ARG_NO_INSTALL ]]; then
    install_kernel_show_progressbar $rpi_arch $cross_compiler
  fi

  cd ../
}

# Function to copy kernel files to the specified boot and root locations
copy_kernel_to_rpi() { #rpi-arch, boot_mount, root_mount
  local rpi_arch="${1:?$(print_error "rpi_arch parameter is null or unset")}"
  local boot_mount="${2:?$(print_error "boot_mount parameter is null or unset")}"
  local root_mount="${3:?$(print_error "root_mount parameter is null or unset")}"

  print_info "Installing kernel files to RaspiOS image"

  # Copy kernel image
  cp "linux/arch/$rpi_arch/boot/Image" "$boot_mount/$KERNEL_NAME.img"
  check_error "Could not copy kernel image to raspios"
  # Copy Device Tree Blobs
  cp "linux/arch/$rpi_arch/boot/dts/broadcom/"*.dtb "$boot_mount/"
  check_error "Could not copy device tree blobs to raspios"
  # Copy Device Tree overlay
  # fixme: not available with mainline. We COULD include these with a patch from rpi kernel src
  # cp "linux/arch/$rpi_arch/boot/dts/overlays/"*.dtb* "$boot_mount/overlays"
  # check_error "Could not copy device tree overlays to raspios"
  # Copy Kernel modules
  echo $ARG_US_PWD | sudo -S  cp -r "linux/build/lib/modules" "$root_mount/lib/modules"
  check_error "Could not copy kernel modules to raspios"

  # Set this kernel to the active kernel in config.txt
  if grep -q "^kernel=" "$boot_mount/config.txt"; then
    # Update config.txt to reflect the new kernel image filename
    echo $ARG_US_PWD | sudo -S  sed -i "s|^kernel=.*$|kernel=$kernel_name.img|" "$boot_mount/config.txt"
  else
    # If 'kernel' line doesn't exist, append it to config.txt
    echo kernel=$kernel_name.img | sudo tee -a "$boot_mount/config.txt" >/dev/null
  fi

  print_success "Kernel installed to RaspiOS image"

}
