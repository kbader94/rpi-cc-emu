#! /bin/bash

# Qemu args
QEMU_BIN_LOCATION=""
QEMU_SD_LOCATION="/raspios.img"
QEMU_MACHINE=""
QEMU_CPU=""
QEMU_MEMORY=""
QEMU_KERNEL=""
QEMU_DTB=""
QEMU_DTB=""

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

# Initiate curl download, monitor progress and update the progress bar
curl_progress() { # filename, url, [ optional ] log_file=curl_output.log
  local filename="${1:?$(print_error "curl_progress: filename paramater is null")}"
  local url="${2:?$(print_error "curl_progress: url paramater is null")}"
  local log_file=${3:-"curl_output.log"}

  # Start curl in the background and redirect output to log file
  curl -o $filename $url >"$log_file" 2>&1 &

  # Get the PID of the curl process
  local pid=$!

  # Monitor the output log file of curl
  while kill -0 "$pid" >/dev/null 2>&1; do
    if [[ -f "$log_file" ]]; then
      # Sanitize git_clone_output
      cleaned_output=$(tr -d '\000' <"$log_file" | tr '\r' '\n')
      # Extract progress information from the last line
      last_line=$(echo "$cleaned_output" | tail -n 1)
      # Extract progress information from the log file
      if [[ -n $last_line ]]; then
        progress=$(echo "$last_line" | awk '{print $1}')
        update_progressbar "$progress"
      fi
    fi
    sleep 1
  done
  complete_progressbar
}

# Initiate xz, monitor progress and update the progress bar
xzd_progress() {
  local filename="${1:?$(print_error "xzd_progress: filename paramater is null")}"
  local log_file=${2:-"xz_output.log"}

  # Extract Raspios in bg and log output
  xz -dvk "$filename" >"$log_file" 2>&1 &

  # Get the PID of the curl process
  local pid=$!

  # Monitor the output log file of xz
  while kill -0 "$pid" >/dev/null 2>&1; do
    if [[ -f "$log_file" ]]; then
      sleep 0.5
      # Send ALRM to xz to refresh xz_output.log
      # SEE: https://stackoverflow.com/questions/48452726/how-to-redirect-xzs-normal-stdout-when-do-tar-xz#:~:text=Thus%2C%20after%20stderr,%7D%202%3ELog_File
      kill -ALRM "$pid"

      # Extract progress information from the last line
      last_line=$(tail -n 1 "$log_file")

      # Extract progress information from the log file
      if [[ -n $last_line ]]; then
        progress=$(echo "$last_line" | awk '{print $2}')
        if [[ $(is_float $progress) ]]; then
          update_progressbar "$progress"
        fi
      fi

    fi
  done
  complete_progressbar

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

loop_dev_is_mounted() {
  local loop_device="$1"
  if mount | grep -q "$(readlink -f "$loop_device")"; then
    return $TRUE  # Device is mounted
  else
    return $FALSE  # Device is not mounted
  fi
}

unmount_loop_dev() {
  local loop_dev="${1:?$(print_error "loop_dev is null or unset")}"

  # Check if loop device exists
  if [ ! -e "$loop_dev" ]; then
    print_error "loop_device doesn't exist"
    return $ERROR
  fi

  # Check if mounted
  if ! loop_dev_is_mounted "$loop_dev"; then
    print_verbose "$loop_dev is not mounted"
    return $SUCCESS # loop dev already unmounted
  fi

  # Get list of processes using the loop device
  local proc_list=$(sudo lsof "$loop_dev" | awk 'NR>1 {print $2}' | sort -u)
  for pid in $proc_list; do
    local process_name=$(ps -p $pid -o comm=)
    print_error "Cannot unmount: $process_name is using this loop device"
    # echo $ARG_US_PWD | sudo -S kill -9 "$pid"
    # check_error "Could not kill process $pid using $loop_device"
  done

  # Unmount
  echo $ARG_US_PWD | sudo -S umount -f "$loop_dev"

  # Check if still mounted
  if loop_dev_is_mounted "$loop_dev"; then
    return $ERROR
  else
    return $SUCCESS
  fi
}

delete_loop_dev() {
  local loop_dev="${1:?$(print_error "loop_dev is null or unset")}"

  # Check if loop device exists
  if [ ! -e "$loop_dev" ]; then
    return $SUCCESS # Nothing to do
  fi

  # Remove loop device
  echo $ARG_US_PWD | sudo -S losetup -d $loop_dev

  # Check if loop device exists
  if [ ! -e "$loop_dev" ]; then
    return $SUCCESS # Nothing to do
  fi

}

unmount_and_delete_loop_dev() {
  local loop_dev="${1:?$(print_error "loop_dev is null or unset")}"
  unmount_loop_dev $loop_dev
  delete_loop_dev $loop_dev
}

get_loop_dev_from_img_partition() { # raspios_absolute_location, offset, size
  local raspios_image="${1:?$(print_error "raspios_image parameter is null or unset")}"
  local partition_number="${2:?$(print_error "partition_number is null or unset")}"
  local unmount_other_loop_devs=${3:-false}
  local raspios_absolute_location=$(readlink -f "$raspios_image")

  local part_info=$(parted -s "$raspios_image" unit B print | awk '$1 == '"$partition_number"' {print $1,$2,$3,$4,$5,$6}')
  local offset=$(echo "$part_info" | awk '{print $2}' | tr -d 'B')
  local size=$(echo "$part_info" | awk '{print $4}' | tr -d 'B')

  # Get information for any existing loop_devs
  local loop_devs_info=$(losetup --list --output NAME,BACK-FILE,OFFSET,SIZELIMIT)
  local loop_devs=$(echo "$loop_devs_info" | awk -v file_location="$raspios_absolute_location" -v offset="$offset" -v size_limit="$size" '$2 == file_location && $3 == offset {print $1}')

  # Get all existing loop_devs for this partition of raspios
  for loop_dev in $loop_devs; do

    # fixme: most of this is still unnecessary.
    # the following lines never run because this is never called with unmount_other_loop_devs set true
    # I'm also unsure why we would EVER want to return an already used loop_dev in this context, should be an error?

    # Unmount and delete all loop devs for this partition, we'll create a new loop dev below
    if [[ $unmount_other_loop_devs == true ]]; then
      # Forcibly unmount, killing any processes associated with loop_device to ensure unimpeded resizing
      print_verbose "Unmounting any loop device associated with $raspios_image"
      unmount_and_delete_loop_dev $loop_dev true
    else
      # Otherwise reuse the first existing and mounted loop_dev for this partition of raspios
      # This MAY? be acceptable for emulation, but to setup raspios all other loop devs must be unmounted and freed
      if loop_dev_is_mounted $loop_dev; then
        # This partition of RaspiOS is already mounted so use existing loop_dev
        echo $loop_dev
        return
      fi
    fi

  done

  # If we've made it here, no loop_devices currently exist for the raspios_image(Typical)
  # Create new loop device via udisksctl
  loop_output=$(udisksctl loop-setup --file "$raspios_image" --offset "$offset" --size "$size" --no-user-interaction)
  # Verify successful loop_dev creation
  if [[ "$loop_output" =~ "Mapped file $raspios_image as" ]]; then
    # Use new loop device
    loop_dev=$(echo "$loop_output" | awk '{gsub(/\.$/,""); print $5}')
    echo "$loop_dev"
  else
    print_error "Could not set up loop device"
  fi

}

get_mount_point_from_loop_dev() { # loop_dev
  local loop_dev="${1:?$(print_error "loop_dev parameter is null or unset")}"
  # udiskctl automatically mounts on first access, force mount to avoid error messages
  if ! loop_dev_is_mounted $loop_dev ; then
    udisksctl mount -b $loop_dev
  fi
  # Check if loop dev is succesfully mounted
  local mount_point=$(grep -w "$loop_dev" /proc/mounts | awk '{print $2}')
  if [ -z $mount_point ]; then
    print_error "Could not mount"
  fi
  echo $mount_point
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
