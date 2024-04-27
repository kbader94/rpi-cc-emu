#! /bin/bash

. install-latest-qemu.sh

# Qemu args
QEMU_BIN_LOCATION=""
QEMU_SD_LOCATION="/raspios.img"
QEMU_MACHINE=""
QEMU_CPU=""
QEMU_MEMORY=""
QEMU_KERNEL=""
QEMU_DTB=""
QEMU_DTB=""

get_free_port() {
  start_port=${1:-"2000"}
  end_port=${2:-"4000"}
  # Loop through the port range and check for availability
  for port in $(seq "$start_port" "$end_port"); do
    # Check if the port is available
    (echo >/dev/tcp/localhost/"$port") >/dev/null 2>&1 || {
      echo $port
      return $SUCCESS
    }
  done
}

check_qemu_supports_rpi() { #rpi_version, rpi_arch
  local rpi_version="${1:?$(print_error "rpi_arch paramater is null")}"
  local rpi_arch=${2:-"arm"}

  # Set qemu_arch accoording to rpi_arch
  if [[ $rpi_arch == "arm" ]]; then
    qemu_arch="arm"
  elif [[ $rpi_arch == "arm64" ]]; then
    qemu_arch="aarch64"
  fi

  # Check to see if qemu supports rpi version
  machine_output=$("qemu-system-$qemu_arch" -machine ?)
  if grep -q "raspi$rpi_version" <<<"$machine_output"; then
    echo true
  else
    echo false
  fi

}

# Set Qemu args according to rpi version
get_qemu_args_from_rpi_version() { # rpi_version, [ optional ] rpi_arch=arm64
  local rpi_version="${1:?$(print_error "rpi_version parameter is null or unset")}"
  local rpi_arch=${2:-"arm64"}

  #TODO: Prompt for additional board options. RPI
  case $rpi_version in
  1)
    # bcm2708-rpi-b-plus.dtb
    # bcm2708-rpi-b-rev1.dtb
    # bcm2708-rpi-b.dtb
    # bcm2708-rpi-cm.dtb
    # bcm2708-rpi-zero-w.dtb
    # bcm2708-rpi-zero.dtb

    # raspi0 and raspi1ap
    # ARM1176JZF-S core, 512 MiB of RAM

    QEMU_DTB="bcm2708-rpi-b-plus"
    QEMU_CPU="arm1176"
    QEMU_MEMORY="512"
    QEMU_MACHINE="raspi1ap"
    ;;
  2)
    # bcm2709-rpi-2-b.dtb
    # bcm2709-rpi-cm2.dtb
    # bcm2710-rpi-2-b.dtb
    # bcm2710-rpi-zero-2-w.dtb
    # bcm2710-rpi-zero-2.dtb

    # raspi2b
    # Cortex-A7 (4 cores), 1 GiB of RAM

    QEMU_DTB="bcm2710-rpi-2-b"
    QEMU_CPU="cortex-a7"
    QEMU_MEMORY="1G"
    QEMU_MACHINE="raspi2b"
    ;;
  3)
    # bcm2710-rpi-3-b-plus.dtb
    # bcm2710-rpi-3-b.dtb
    # bcm2710-rpi-cm3.dtb

    # raspi3ap
    # Cortex-A53 (4 cores), 512 MiB of RAM
    # raspi3b
    # Cortex-A53 (4 cores), 1 GiB of RAM
    QEMU_DTB="bcm2837-rpi-3-b-plus"
    QEMU_CPU="cortex-a53"
    QEMU_MEMORY="1G"
    QEMU_MACHINE="raspi3b"
    ;;
  4)
    # bcm2711-rpi-4-b.dtb
    # bcm2711-rpi-400.dtb
    # bcm2711-rpi-cm4-io.dtb
    # bcm2711-rpi-cm4.dtb
    # bcm2711-rpi-cm4s.dtb

    # raspi4b
    # Cortex-A72 (4 cores), 2 GiB of RAM
    QEMU_DTB="bcm2711-rpi-4-b"
    QEMU_CPU="cortex-a72"
    QEMU_MEMORY="2G"
    QEMU_MACHINE="raspi4b"
    ;;
  5)
    # TODO: RPI 5 not supported natively in qemu, but could be via virt
    print_warning "RPI 5 not supported, yet!"
    print_info "Falling back to RPI 4"
    # support via virt?
    # bcm2712-rpi-5-b.dtb
    # bcm2712-rpi-cm5-cm4io.dtb
    # bcm2712-rpi-cm5-cm5io.dtb
    # bcm2712d0-rpi-5-b.dtb
    QEMU_DTB="bcm2711-rpi-4-b"
    QEMU_CPU="cortex-a72"
    QEMU_MEMORY="4G"
    QEMU_MACHINE="raspi4b"
    ;;
  esac

  QEMU_KERNEL="linux/arch/$rpi_arch/boot/Image"
  QEMU_DTB="linux/arch/$rpi_arch/boot/dts/broadcom/$QEMU_DTB.dtb"

  print_verbose "QEMU_DTB: $QEMU_DTB"
  print_verbose "QEMU_CPU: $QEMU_CPU"
  print_verbose "QEMU_MEMORY: $QEMU_MEMORY"
  print_verbose "QEMU_MACHINE: $QEMU_MACHINE"
  print_verbose "QEMU_DTB: $QEMU_DTB"
  print_verbose "QEMU_KERNEL: $QEMU_KERNEL"
}

# Returns the url for the latest raspios.img.xz, depending on arch
latest_raspios_url() { # [ optional ] rpi_arch=arm64
  local raspios_arch=${1:-"raspios_arm64"}
  if [[ raspios_arch != "raspios_arm64" || raspios_arch != "raspios_armhf" ]]; then
    print_error "Invalid raspios_arch parameter"
  fi

  # Get list of images for arch
  html_content=$(curl -s https://downloads.raspberrypi.com/$raspios_arch/images/)
  links_with_dates=$(echo "$html_content" | grep -oP "$raspios_arch-\K\d{4}-\d{2}-\d{2}")
  # The last link is the latest image
  latest_date=$(echo "$links_with_dates" | sort -r | head -n 1)
  latest_url=https://downloads.raspberrypi.com/$raspios_arch/images/$raspios_arch-2024-03-15/2024-03-15-raspios-bookworm-armhf.img.xz"raspios_arm64-$latest_date/"
  # Get the .img.xz link for the latest image
  latest_html_content=$(curl -s "$latest_link")
  img_xz_link=$(echo "$latest_html_content" | grep -oP 'href=".*\.img\.xz"' | sed 's/href="//')
  echo "$img_xz_link"
}

# launch qemu with the newly compiled kernel, dtb's and configured raspios rootfs
emulate_kernel() { # qemu_machine, cpu, mem, dtb_location, raspios_image, kernel_location
  local qemu_machine="${1:?$(print_error "qemu_machine parameter is null or unset")}"
  local cpu="${2:?$(print_error "cpu parameter is null or unset")}"
  local mem="${3:?$(print_error "mem parameter is null or unset")}"
  local dtb_location="${4:?$(print_error "dtb_location parameter is null or unset")}"
  local raspios_image="${5:?$(print_error "raspios_image parameter is null or unset")}"
  local kernel_location="${6:?$(print_error "kernel_location parameter is null or unset")}"
  local rpi_arch="${7:?$(print_error "rpi_arch parameter is null or unset")}"
  local qemu_location="$8"
  local qemu_arch=""

  # append ./ to qemu_location
  if [[ "$8" != "" ]]; then
    qemu_location="$8/"
  fi

  # Set qemu_arch accoording to rpi_arch
  if [[ $rpi_arch == "arm" ]]; then
    qemu_arch="arm"
  elif [[ $rpi_arch == "arm64" ]]; then
    qemu_arch="aarch64"
  fi

  local port=$(get_free_port 2222) # Get first free net port, starting at 2222

  # Run specified qemu with specified args
  "$qemu_location"qemu-system-"$qemu_arch" \
    -machine $qemu_machine \
    -cpu $cpu \
    -nographic \
    -dtb $dtb_location \
    -m $mem \
    -smp 4 \
    -kernel $kernel_location \
    -sd $raspios_image \
    -append "rw earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootdelay=1" \
    -device usb-net,netdev=net0 \
    -netdev "user,id=net0,hostfwd=tcp::$port-:22"

}
