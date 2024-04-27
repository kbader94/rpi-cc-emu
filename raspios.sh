#! /bin/bash

# Import
. mount.sh

# RaspiOS Versions
declare -a RASPI_BOOKWORK_6_6_20=("Bookworm" "6.6.20" "https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2024-03-15/2024-03-15-raspios-bookworm-arm64.img.xz" https://downloads.raspberrypi.com/raspios_armhf/images/raspios_armhf-2024-03-15/2024-03-15-raspios-bookworm-armhf.img.xz)
declare -a RASPI_BOOKWORK_6_1_63=("Bookworm" "6.1.63" "https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2023-12-06/2023-12-05-raspios-bookworm-arm64.img.xz" https://downloads.raspberrypi.com/raspios_armhf/images/raspios_armhf-2023-12-06/2023-12-05-raspios-bookworm-armhf.img.xz)
declare -a RASPI_BULLSEYE_6_1_21=("Bullseye" "6.1.21" "https://downloads.raspberrypi.com/raspios_oldstable_arm64/images/raspios_oldstable_arm64-2024-03-12/2024-03-12-raspios-bullseye-arm64.img.xz" "https://downloads.raspberrypi.com/raspios_oldstable_armhf/images/raspios_oldstable_armhf-2024-03-12/2024-03-12-raspios-bullseye-armhf.img.xz")
declare -a RASPI_BULLSEYE_5_15_84=("Bullseye" "5.15.84" "https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2023-02-22/2023-02-21-raspios-bullseye-arm64.img.xz" "https://downloads.raspberrypi.com/raspios_armhf/images/raspios_armhf-2023-02-22/2023-02-21-raspios-bullseye-armhf.img.xz")
declare -a RASPI_BULLSEYE_5_10_92=("Bullseye" "5.10.92" "https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2022-01-28/2022-01-28-raspios-bullseye-arm64.zip" "https://downloads.raspberrypi.com/raspios_armhf/images/raspios_armhf-2022-01-28/2022-01-28-raspios-bullseye-armhf.zip")
declare -a RASPI_BULLSEYE_5_10_63=("Bullseye" "5.10.63" "https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2021-11-08/2021-10-30-raspios-bullseye-arm64.zip" "https://downloads.raspberrypi.com/raspios_armhf/images/raspios_armhf-2021-11-08/2021-10-30-raspios-bullseye-armhf.zip")
declare -a RASPI_BUSTER_5_10_17=("Buster" "5.10.17" "https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2021-05-28/2021-05-07-raspios-buster-arm64.zip" "https://downloads.raspberrypi.com/raspios_armhf/images/raspios_armhf-2021-05-28/2021-05-07-raspios-buster-armhf.zip")
declare -a RASPI_BUSTER_5_4_42=("Buster" "5.4.42" "https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2020-05-28/2020-05-27-raspios-buster-arm64.zip" "https://downloads.raspberrypi.com/raspios_armhf/images/raspios_armhf-2020-05-28/2020-05-27-raspios-buster-armhf.zip")
declare -a RASPI_BUSTER_4_19_97=("Buster" "4.19.97" "" "https://downloads.raspberrypi.com/raspbian/images/raspbian-2020-02-14/2020-02-13-raspbian-buster.zip")
declare -a RASPI_BUSTER_4_19_50=("Buster" "4.19.50" "" "https://downloads.raspberrypi.com/raspbian/images/raspbian-2019-06-24/2019-06-20-raspbian-buster.zip")
declare -a RASPI_STRETCH_4_14_98=("Stretch" "4.14.98" "" "https://downloads.raspberrypi.com/raspbian/images/raspbian-2019-04-09/2019-04-08-raspbian-stretch.zip")
declare -a RASPI_STRETCH_4_9_41=("Stretch" "4.9.41" "" "https://downloads.raspberrypi.com/raspbian/images/raspbian-2017-08-17/2017-08-16-raspbian-stretch.zip")

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

get_raspios() {
  local raspios_arch=${1:-"arm64"}
  local raspios_version=${2:-"buster"}
  local raspios_url="https://downloads.raspberrypi.com/raspios_oldstable_arm64/images/raspios_oldstable_arm64-2024-03-12/2024-03-12-raspios-bullseye-arm64.img.xz"

  # Set raspios_url depending on arch, default is bullseye
  if [[ ! $raspios_url ]]; then
    if [[ $rpi_arch == "arm" ]]; then
      raspios_url="https://downloads.raspberrypi.com/raspios_oldstable_armhf/images/raspios_oldstable_armhf-2024-03-12/2024-03-12-raspios-bullseye-armhf.img.xz"
    fi
  fi

  # Download Raspios
  if [[ ! -e "$raspios_image.xz" ]]; then
    print_info "Downloading Raspios..."
    curl_progress $raspios_image.xz $raspios_url
    check_error "Could not download Raspios"
    print_success "Raspios successfully downloaded"
  else
    print_verbose "Raspios.img.xz already exists, skipping download"
  fi

  # Extract Raspios
  if [[ ! -e "$raspios_image" ]]; then
    print_info "Extracting Raspios..."
    xzd_progress "$raspios_image.xz"
    check_error "Could not extract Raspios"
    print_success "Raspios successfully downloaded"
  else
    print_verbose "Raspios.img already exists, skipping extraction"
  fi

}

resize_raspios() {
  local raspios_image="${1:?$(print_error "raspios_image parameter is null or unset")}"

  # Expand RaspiOS image and rootfs partition
  print_info "Resizing RaspiOS"
  qemu-img resize "$raspios_image" 16G #
  check_error "Could not resize RaspiOS image"

  # Resize Rootfs on disk image
  echo $ARG_US_PWD | sudo -S parted -s "$raspios_image" resizepart 2 100%
  check_error "Could not resize RaspiOS rootfs partition"

  # Mount rootfs
  loop_dev=$(get_loop_dev_from_img_partition $raspios_image 2)
  mount_point=$(get_mount_point_from_loop_dev $loop_dev)

  # Ensure it's not mounted before resizing
  unmount_loop_dev $loop_dev

  # Resize rootfs fs to use all available space on disk image
  echo $ARG_US_PWD | sudo -S e2fsck -fp $loop_dev
  echo $ARG_US_PWD | sudo -S resize2fs "$loop_dev"
  check_error "Could not resize RaspiOS rootfs filesystem from $mount_point @$loop_dev"

  # Use partprobe to inform the kernel about partition changes
  echo $ARG_US_PWD | sudo -S partprobe "$loop_dev" # Maybe not necessary?
  check_error "Could not inform kernel about partition size changes"

  # Detach loop device
  delete_loop_dev $loop_dev
  check_error "could not delete $loop_dev"
  print_success "RaspiOS resized"

}

# For qemu, in addition to a kernel and dtb's, we need a rootfs
# We will get our rootfs from the specified RaspiOS.img
# download the [latest] raspios image and extract
# mount boot and root partitions
# enable ssl and create password
# copy kernel, modules, device tree blobs to raspios.img
# set kernel as active on raspios.img
# umount raspios.img
# Side note: raspios.img is now configured with newly built kernel
# fixme: this function is getting long and convoluted, future changes should
# consider breaking it up into subroutines such as get_raspios, mount_raspios, install_kernel_to_raspios , unmount_raspios
setup_raspios() { # rpi_arch, [optional] raspios_img_filename, [optional] raspios url, [ optional ] rpi_password
  local rpi_arch=${1:-"arm64"}
  local raspios_image=${2:-"raspios-$rpi_arch.img"}
  local raspios_url="$3" # Set below, according to arch
  local rpi_password=${4:-"raspberry"}
  local boot_loop_dev=""
  local root_loop_dev=""
  local boot_mount_point=""
  local root_mount_point=""

  # Download RaspiOS image
  get_raspios $rpi_arch

  # Resize to base-2 to make qemu happy, plus add room for compiled modules
  resize_raspios $raspios_image

  # Mount RaspiOS BootFS
  boot_loop_dev=$(get_loop_dev_from_img_partition $raspios_image 1)
  boot_mount_point=$(get_mount_point_from_loop_dev $boot_loop_dev)

  # Mount RaspiOS RootFS
  root_loop_dev=$(get_loop_dev_from_img_partition $raspios_image 2)
  root_mount_point=$(get_mount_point_from_loop_dev $root_loop_dev)

  # Set rpi password and enable ssh
  local password_hash=$(openssl passwd -6 "$rpi_password")
  touch "$boot_mount_point/ssh"
  check_warning "Could not enable ssh"
  echo "pi:$password_hash" >"$boot_mount_point/userconf"

  # Copy kernel, modules, device tree blobs and set active kernel in config.txt
  copy_kernel_to_rpi "$RPI_ARCH" "$boot_mount_point" "$root_mount_point"

  unmount_and_delete_loop_dev $boot_loop_dev
  unmount_and_delete_loop_dev $root_loop_dev

  QEMU_SD_LOCATION=$raspios_image

}