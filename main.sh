#!/bin/bash
. kernel.sh
. emulate.sh
. install-latest-qemu.sh

declare SUCCESS='0'
PACKAGES=("git" "bc" "libssl-dev" "flex" "bison" "libncurses-dev" "sshpass" "crossbuild-essential-armhf" "crossbuild-essential-arm64")
VERBOSE=false
DEBUG=false

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

# Print verbose message, only if verbose output is enabled
print_verbose() {
  if [[ $VERBOSE == true ]]; then
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
  if [[ $DEBUG == false ]]; then
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

# Package dependency check
check_packages() {
  for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -l "$pkg" &> /dev/null; then
      printf "Installing $pkg\n"
      sudo apt-get install -y $pkg
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
        return 0  # True
    else
        return 1  # False
    fi
}

# Update progress to 100 and skip line
complete_progress() {
  update_progress 100
  printf "\n"
}

# Function to update progress with a progress bar
update_progress() { # float progress, [ optional ] str text, [ optional ] color=ANSI_BLUE, [ optional ] size=50 
    local progress="$1"
    local text="$2" # Text of progress bar
    local color=${3:-$ANSI_BLUE} # Color of progress bar
    local length=${4:-50}  # Length of the progress bar
    local bar=""     # String to store the progress bar

    # Calculate how many chars to fill with color
    local progress_int=$(printf "%.0f" "$progress")
    local progress_decimal=$(echo "scale=6; $progress / 100" | bc)
    local float_filled_chars=$(echo "scale=6; $progress_decimal * $length" | bc)
    local filled_chars=$(printf "%.0f" "$float_filled_chars")
    
    # Create the progress bar string with blue background
    bar+=$ANSI_BG_GREEN  # ANSI escape code for blue background
    for (( i = 0; i < filled_chars; i++ )); do
        bar+=" "
    done
    bar+=$ANSI_RESET # Reset color
    for (( i = filled_chars; i < length; i++ )); do
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
        -h|--help)
            usage
            ;;
        --rpi_version)
            if [[ -z $2 ]]; then
                echo "Error: rpi_version not provided."
                usage
            fi
            # TODO: handle raspios version
            print_error "rpi_version unimplemented"
            shift
            ;;
        --raspios_version)
            if [[ -z $2 ]]; then
                echo "Error: raspios_version not provided."
                usage
            fi
            # TODO: handle raspios version
            print_error "raspios_version unimplemented"
            shift
            ;;
        -l|--linux_version)
            if [[ -z $2 ]]; then
                echo "Error: linux_version not provided."
                usage
            fi
            # TODO: handle linux version
            print_error "linux_version unimplemented"
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            ;;
        -d|--debug)
            set -x
            DEBUG=true
            ;;
        *)
            echo "Error: Unknown option $1"
            usage
            ;;
    esac
    shift
done

RPI_VERSION=3

# Prompt for Raspberry Pi version
# while true; do
#     read -p "Enter the version of Raspberry Pi (1-5): " RPI_VERSION
#     if [[ $RPI_VERSION =~ ^[1-5]$ ]]; then
#         break
#     else
#         printf "Invalid input. Please enter a number between 1 and 5.\n"
#     fi
# done

# Only the newest version of qemu supports raspi4b machines
# We can either install the latest qemu, or support raspi4 and 5 via virt machines
# For now I haven't looked into virt machines, so here's a script to install the latest qemu

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

emulate_kernel $QEMU_MACHINE $QEMU_CPU $QEMU_MEMORY $QEMU_DTB_LOCATION $QEMU_SD_LOCATION $QEMU_KERNEL_LOCATION $RPI_ARCH $QEMU_BIN_LOCATION

