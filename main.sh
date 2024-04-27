#!/bin/bash
# Imports
. common.sh
. progressbar.sh
. kernel.sh
. raspios.sh
. emulate.sh

declare SUCCESS='0'
declare ERROR='1'
declare TRUE='0'
declare FALSE='1'

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
ARG_NO_INTERACTION=false  # No user interaction AKA silent TODO: this should be no-input, we also might want no-output and silent for both
ARG_NO_KERNEL_BUILD=false        # skip building kernel
ARG_NO_Kernel_INSTALL=false      # skip installing kernel
# TODO: ARG_NO_QEMU=false         # skip emulation via qemu
ARG_US_PWD=""             # User Password
ARG_KERNEL_VERSION=""     # Kernel Version
ARG_RASPIOS_VERSION=""    # Raspios Version

# RPI
RPI_VERSION=""            # RPI Model Version [ 1-5 ]
RPI_ARCH=""               # 32 bit = arm, 64 bit =arm64
RPI_CC=""                 # make cross compiler
RASPIOS_BOOT_MOUNT=""     # Mount point for RaspiOS bootfs
RASPIOS_ROOT_MOUNT=""     # Mount point for RaspiOS rootfs

usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -h, --help                   Display this help message"
  echo "  --password <password>        The password for the user executing script, required to install kernel"
  echo "  --rpi-version <version>      Set the Raspberry Pi version (1-5)"
  echo "  --raspios-version <version>  Set the Raspberry Pi OS version (bookworm, bullseye, buster, stretch)"
  echo "  --kernel-version <version>   Set the Linux kernel version (x.y.z)"
  echo "  -v, --verbose                Enable verbose output mode"
  echo "  -d, --debug                  Enable script debug mode, equivalent to set -x"
  echo "  -f, --force                  Ignore errors and force execution of subsequent commands"
  echo "  --no-interaction             Disables user prompts and uses default parameters when not provided"
  echo "  --purge                      Purge and free all resources including images, binaries, logs and loop devices"
  echo "  --cleanup-loop-devs          Unmount and remove loop devices associated with RaspiOS images"
  echo "  --purge-raspios              Purge RaspiOS images"
  echo "  --purge-raspios.xz           Purge compressed RaspiOS images"
  echo "  --purge-kernel               Purge Linux kernel"
  echo "  --purge-logs                 Purge logs"
  exit 1
}

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
  --no-kernel-build)
    ARG_NO_KERNEL_BUILD=true
    ;;
  --no-kernel-install)
    ARG_NO_Kernel_INSTALL=true
    ;;

  --purge | --cleanup-loop-devs)
    print_error "UNIMPLEMENTED"
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
    rm raspios-arm64.img
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

# Done parsing arguments, begin main execution

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
