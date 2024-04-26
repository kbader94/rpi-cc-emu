#!/bin/bash
. kernel.sh
. emulate.sh
. install-latest-qemu.sh

declare SUCCESS='0'
PACKAGES=("git" "bc" "libssl-dev" "flex" "bison" "libncurses-dev" "sshpass" "crossbuild-essential-armhf" "crossbuild-essential-arm64")

# Foreground Colors
ANSI_BLACK='\033[30m'
ANSI_RED='\033[31m'
ANSI_GREEN='\033[32m'
ANSI_YELLOW='\033[33m'
ANSI_BLUE='\033[34m'
ANSI_MAGENTA='\033[35m'
ANSI_CYAN='\033[36m'
ANSI_WHITE='\033[37m'

# Background Colors
ANSI_BG_BLACK='\033[40m'
ANSI_BG_RED='\033[41m'
ANSI_BG_GREEN='\033[42m'
ANSI_BG_YELLOW='\033[43m'
ANSI_BG_BLUE='\033[44m'
ANSI_BG_MAGENTA='\033[45m'
ANSI_BG_CYAN='\033[46m'
ANSI_BG_WHITE='\033[47m'

# Reset
ANSI_RESET='\033[0m'

# Arg Flags
ARG_FORCE=false           # force our way through errors
ARG_VERBOSE=false         # output extra information
ARG_DEBUG=false           # output commands as executed AKA set -x
ARG_NO_INTERACTION=false  # No user intaction AKA silent
ARG_NO_BUILD=false        # skip building kernel
ARG_NO_INSTALL=false      # skip installing kernel
ARG_NO_QEMU=false         # skip emulation via qemu
ARG_US_PWD=""             # User Password
ARG_KERNEL_VERSION=""     # Kernel Version
ARG_RASPIOS_VERSION=""    # Raspios Version

RPI_VERSION=""         # RPI Model Version [ 1-5 ]
RPI_ARCH=""          # 32 bit = arm, 64 bit =arm64
RPI_CC=""            # make cross compiler

# Print verbose message, only if verbose output is enabled
print_verbose() {
  if [[ $ARG_VERBOSE == true ]]; then
    printf "${ANSI_LIGHT_YELLOW}[ INFO ]${ANSI_RESET} %s\n" "$1"
  fi
}

print_success() {
  printf "${ANSI_GREEN}[ SUCCESS ]${ANSI_RESET} %s\n" "$1"
}

print_info() {
  printf "[ INFO ] %s\n" "$1"
}

print_warning() {
  printf "${ANSI_YELLOW}[ WARNING ]${ANSI_RESET} %s\n" "$1"
}

exit_error() {
  if [[ $ARG_FORCE == false ]]; then
    exit 1
  fi
}

# Print error and exit status 1
print_error() {
  printf "${ANSI_RED}[ ERROR ]${ANSI_RESET}: %s\n" "$1"
  exit_error
}

# Check if last command was successful, otherwise print_error
check_error() {
  if [ $? -ne 0 ]; then
    print_error "$1"
  fi
}

# Check if last command was successful, otherwise print_warning
check_warning() {
  if [ $? -ne 0 ]; then
    print_warning "$1"
  fi
}

# Package dependency check
check_packages() {
  for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -l "$pkg" &>/dev/null; then
      printf "Installing $pkg\n"
      echo $ARG_US_PWD | sudo -S  apt-get install -y $pkg
    fi
  done
  printf "All required packages are installed.\n"
  return 0
}

# Function to calculate the length of a string
str_length() {
  local str="$1"
  local length=${#str}
  echo $length
}

# Check whether variable is integer
is_integer() {
  local var="$1"
  if [[ $var =~ ^[0-9]+$ ]]; then
    echo true
  else
    echo false
  fi
}

# Check whether variable is float
is_float() {
  local value="$1"
  # Regular expression to match a float number
  local float_regex='^[0-9]+([.][0-9]+)?$'
  if [[ $value =~ $float_regex ]]; then
    return 0 # True
  else
    return 1 # False
  fi
}

# Update progress to 100 and skip line
complete_progressbar() {
  update_progressbar 100
  printf "\n"
}

# Function to update progress with a progress bar
update_progressbar() { # float progress, [ optional ] str text, [ optional ] color=ANSI_BLUE, [ optional ] size=50
  local progress="$1"
  local text="$2"              # Text of progress bar
  local color=${3:-$ANSI_BLUE} # Color of progress bar
  local length=${4:-50}        # Length of the progress bar
  local bar=""                 # String to store the progress bar

  # Calculate how many chars to fill with color
  local progress_int=$(printf "%.0f" "$progress")
  local progress_decimal=$(echo "scale=6; $progress / 100" | bc)
  local float_filled_chars=$(echo "scale=6; $progress_decimal * $length" | bc)
  local filled_chars=$(printf "%.0f" "$float_filled_chars")

  # Create the progress bar string with blue background
  bar+=$ANSI_BG_GREEN # ANSI escape code for blue background
  for ((i = 0; i < filled_chars; i++)); do
    bar+=" "
  done
  bar+=$ANSI_RESET # Reset color
  for ((i = filled_chars; i < length; i++)); do
    bar+=" "
  done

  # Print the progress bar with carriage return to overwrite the previous line
  echo -en "\r[${bar}] ${progress_int}%"
}

###########################################################
#####################   ENTRY  POINT   ####################
###########################################################

# Script should not be run with sudo
if [ "$(id -u)" -eq 0 ]; then
  print_warning "This script should not be run with root permissions!"
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help)
    usage
    ;;
  --password)
    if [[ ! -z $2 ]]; then
      ARG_US_PWD="$2"
      shift
    else
      print_error "Password not provided"
    fi
    ;;
  --rpi-version)
    if [[ ! -z $2 && $2 =~ ^[1-5] ]]; then
      RPI_VERSION="$2"
      shift
    else
      print_error "Error: rpi-version not provided or invalid"
    fi
    ;;
  --raspios-version)
    if [[ -z $2 ]]; then
      local raspios-version="$2"
      case "$2" in
        bookworm | Bookworm | BookWorm)
          ARG_RASPIOS_VERSION="bookworm"
        ;;
        bullseeye | Bullseye | BullsEye)
          ARG_RASPIOS_VERSION="bullseye"
        ;;
        buster | Buster)
          ARG_RASPIOS_VERSION="buster"
        ;;
        stretch | Stretch)
          ARG_RASPIOS_VERSION="stretch"
        ;;

      esac
      echo "Error: raspios_version not provided."
      usage
    fi
    # TODO: handle raspios version
    print_error "raspios-version unimplemented"
    shift
    ;;
  --kernel-version)
    if [[ ! -z $2 && $2 =~ "^[0-9]+\.[0-9]+\.[0-9]+$" ]]; then
      ARG_KERNEL_VERSION="$2"
    else
      echo "Error: linux-version not provided."
      usage
    fi
    # TODO: handle linux version
    print_error "linux_version unimplemented"
    shift
    ;;
  -v | --verbose)
    ARG_VERBOSE=true
    ;;
  -d | --debug)
    set -x
    ARG_DEBUG=true
    ;;
  -f | --force)
    ARG_FORCE=true
    ;;
  --no-interaction)
    ARG_NO_INTERACTION=true
    ;;
  --purge | --cleanup-loop-devs)
    print_info "Unmounting and removing loop devices"
    loop_devices=$(losetup -a | grep "raspios-arm" | cut -d: -f1)
    # Unmount and delete loop devices associated with raspios images
    for loop_dev in $loop_devices; do
      # Unmount
      udisksctl unmount --block-device "$loop_dev"
      check_warning "could not unmount $loop_dev. Not mounted?"
      # Detach loop devices
      udisksctl loop-delete --block-device "$loop_dev"
      check_error "could not delete $loop_dev"
    done
    ;;
  --purge | --purge-raspios)
    print_info "Purging RaspiOS"
    rm raspios-arm.img
    rm rapsios-arm64.img
    ;;
  --purge | --purge-raspios.xz)
    print_info "Purging raspios.xz"
    rm raspios-arm.img.xz
    rm rapsios-arm64.img.xz
    ;;
  --purge | --purge-kernel)
    print_info "Purging Linux Kernel"
    rm -r linux
    rm -r linux
    ;;
  --purge | --purge-logs)
    print_info "Purging Logs"
    rm *.log
    rm *.log.old
    ;;
  *)
    print_error "Error: Unknown option $1"
    usage
    ;;
  esac
  shift
done

# Prompt for Raspberry Pi version
while [[ -z $RPI_VERSION ]]; do
  if [[ $ARG_NO_INTERACTION ]]; then
    RPI_VERSION=3 # Set default if no-interaction and rpi version no specified
    break
  fi
  # Otherwise prompt for RPI model number
  read -p "Enter the model number of Raspberry Pi (1-5): " ARG_RPI_VERION
  if [[ $RPI_VERSION =~ ^[1-5]$ ]]; then
    break
  else
    print_warning "Invalid RPI model number"
    RPI_VERSION=""
  fi
done

# fixme: should be recursive, but we should also validate, maybe via sudo -v
if [[ -z $ARG_US_PWD ]]; then
  if [[ $ARG_NO_INTERACTION ]]; then
    print_error "No root password given, cannot continue"
  fi
  print_warning "This script requries root privileges"
  read -p "Password: " ARG_US_PWD
fi

# Only the newest version of qemu supports raspi4b machines
# We can either install the latest qemu, or support raspi4 and 5 via virt machines
# For now here's a script to install the latest qemu
# There is no raspi5 qemu machine ATM
# But still, this fact supports using virt for rpi5 at least

if [[ $RPI_VERSION == 4 ]]; then
  if [[ $(check_qemu_supports_rpi $RPI_VERSION $RPI_ARCH) == false ]]; then
    print_warning "The version of qemu currently installed does not natively support RPI 4"
    print_info "Installing latest qemu"
    install_qemu
    QEMU_BIN_LOCATION=$(installed_qemu_location)
  fi
fi

get_kernel_build_args $RPI_VERSION $RPI_ARCH

# TODO: Prompt for linux version
git_kernel

build_kernel $RPI_ARCH $RPI_CC $KERNEL_CONFIG false

setup_raspios $RPI_ARCH

get_qemu_args_from_rpi_version $RPI_VERSION $RPI_ARCH

emulate_kernel $QEMU_MACHINE $QEMU_CPU $QEMU_MEMORY $QEMU_DTB $QEMU_SD_LOCATION $QEMU_KERNEL $RPI_ARCH $QEMU_BIN_LOCATION
