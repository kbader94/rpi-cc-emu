#! /bin/bash

# Qemu args
QEMU_BIN_LOCATION=""
QEMU_SD_LOCATION="/raspios.img"
QEMU_MACHINE=""
QEMU_CPU=""
QEMU_MEMORY=""                             
QEMU_KERNEL_LOCATION=""
QEMU_DTB=""
QEMU_DTB_LOCATION=""

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

# Function to monitor curl progress and update the progress bar
curl_progress() { # filename, url, [ optional ] log_file=curl_output.log
    local filename="${1:?$(print_error "curl_progress: filename paramater is null")}"
    local url="${2:?$(print_error "curl_progress: url paramater is null")}"
    local log_file=${3:-"curl_output.log"}

    # Start curl in the background and redirect output to log file
    curl -o $filename $url > "$log_file" 2>&1 &

    # Get the PID of the curl process
    local pid=$!

    # Monitor the output log file of curl
    while kill -0 "$pid" > /dev/null 2>&1; do
        if [[ -f "$log_file" ]]; then
            # Extract progress information from the log file
            progress_line=$(tail -n 1 "$log_file" | awk '{print $1}')
            if [[ -n $progress_line ]]; then
                update_progress "$progress_line"
            fi
        fi
        sleep 1
    done

}

check_qemu_supports_rpi() { #rpi_version, rpi_arch
  local rpi_version="${1:?$(print_error "rpi_arch paramater is null")}"
  local rpi_arch=${2:-"arm"}

  # Set qemu_system accoording to rpi_arch
    if [[ $rpi_arch == "arm" ]]; then
      qemu_system="arm"
    elif [[ $rpi_arch == "arm64" ]]; then
      qemu_system="aarch64"
    fi

  # Check to see if qemu supports rpi version
  machine_output=$("qemu-system-$qemu_system" -machine ?)
  if grep -q "raspi$rpi_version" <<< "$machine_output"; then
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

  QEMU_KERNEL_LOCATION="linux/arch/$rpi_arch/boot/$KERNEL_IMAGE_TYPE"
  QEMU_DTB_LOCATION="linux/arch/$rpi_arch/boot/dts/broadcom/$QEMU_DTB.dtb"

  print_verbose "QEMU_DTB: $QEMU_DTB"
  print_verbose "QEMU_CPU: $QEMU_CPU"
  print_verbose "QEMU_MEMORY: $QEMU_MEMORY"
  print_verbose "QEMU_MACHINE: $QEMU_MACHINE"
  print_verbose "QEMU_DTB_LOCATION: $QEMU_DTB_LOCATION"
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
emulate_kernel() { # qemu_machine, cpu, mem, dtb_location, raspios_location, kernel_location
  local qemu_machine="${1:?$(print_error "qemu_machine parameter is null or unset")}"
  local cpu="${2:?$(print_error "cpu parameter is null or unset")}"
  local mem="${3:?$(print_error "mem parameter is null or unset")}"
  local dtb_location="${4:?$(print_error "dtb_location parameter is null or unset")}"
  local raspios_location="${5:?$(print_error "raspios_location parameter is null or unset")}"
  local kernel_location="${6:?$(print_error "kernel_location parameter is null or unset")}"
  local rpi_arch="${7:?$(print_error "rpi_arch parameter is null or unset")}"
  local qemu_location="$8"
  local qemu_system=""

  # append ./ to qemu_location
  if [[ "$8" != "" ]]; then
    qemu_location="$8/" 
  fi

  # Set qemu_system accoording to rpi_arch
  if [[ $rpi_arch == "arm" ]]; then
    qemu_system="arm"
  elif [[ $rpi_arch == "arm64" ]]; then
    qemu_system="aarch64"
  fi
  
  # Run qemu with specified args
  "$qemu_location"qemu-system-"$qemu_system" \
  -machine $qemu_machine \
  -cpu $cpu \
  -nographic \
  -dtb $dtb_location \
  -m $mem \
  -smp 4 \
  -kernel $kernel_location \
  -sd $raspios_location \
  -append "rw earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootdelay=1" \
  -device usb-net,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22

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
setup_raspios() { # rpi_arch, [optional] mount point, [optional] raspios url, [ optional ] rpi_password
  local rpi_arch=${1:-"arm64"}
  local mount_point=${2:-"/tmp/rpi"} # temporary mount point
  local raspios_url="$3" # Set below, according to arch
  local rpi_password=${4:-"raspberry"}
  local raspios_location="raspios-$rpi_arch.img"
  local boot_mount_point="$mount_point/boot"
  local root_mount_point="$mount_point/root"

  # Set raspios_url depending on arch
  if [[ ! $raspios_url ]]; then
    if [[ $rpi_arch == "arm" ]]; then
      raspios_url="https://downloads.raspberrypi.com/raspios_armhf/images/raspios_armhf-2024-03-15/2024-03-15-raspios-bookworm-armhf.img.xz"
    else #arm64
      raspios_url="https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2024-03-15/2024-03-15-raspios-bookworm-arm64.img.xz"
    fi
  fi

  # Download Raspios
  if [[ ! -e "$raspios_location.xz" ]]; then
    print_info "Downloading Raspios...\n"
    curl_progress $raspios_location.xz $raspios_url
    check_error "Could not download Raspios\n"
    print_verbose "Raspios successfully downloaded\n"
  else
    print_verbose "Raspios already exists, skipping download\n"
  fi

  # Extract Raspios
  print_warning "This may take a while"
  xz_output=$(xz -d -k "$raspios_location.xz" 2>&1)  # Capture both stdout and stderr
  xz_pid=$!  # Save the PID of the background process
  wait "$xz_pid"  # Wait for the xz extraction to finish
  # Check if the output contains the text "file exists"
  if [[ "$xz_output" != *"File exists"* ]]; then
      # If the output doesn't contain "file exists", treat it as an error
      check_error "Error while extracting Raspios: $xz_output"
  fi
  print_info "Raspios successfully extracted"

  # Create temporary directories for mounting
  mkdir -p "$mount_point"
  mkdir -p "$boot_mount_point"
  mkdir -p "$root_mount_point"

  # Get Boot partition info
  boot_part_info=$(parted -s "$raspios_location" unit B print | awk '$0 ~ /fat32/ {print $1,$2,$3,$4,$5,$6}')
  boot_start=$(echo "$boot_part_info" | awk '{print $2}' | tr -d 'B')
  boot_size=$(echo "$boot_part_info" | awk '{print $4}' | tr -d 'B')
  boot_fs_type=$(echo "$boot_part_info" | awk '{print $6}')

  # Setup loop device for Boot partition
  boot_loop_device=$(udisksctl loop-setup --file "$raspios_location" | awk '{print $4}')

  # Mount Boot partition
  udisksctl mount --block-device "$boot_loop_device" --options="fstype=vfat" --no-user-interaction
  check_error "Error mounting RaspiOS boot partition"
  dosfslabel "$boot_loop_device" qemu-boot
  print_info "Raspios boot partition successfully mounted at $boot_mount_point"

  # Get Root partition info
  root_part_info=$(parted -s "$raspios_location" unit B print | awk '$0 ~ /ext4/ {print $1,$2,$3,$4,$5,$6}')
  root_start=$(echo "$root_part_info" | awk '{print $2}' | tr -d 'B')
  root_size=$(echo "$root_part_info" | awk '{print $4}' | tr -d 'B')
  root_fs_type=$(echo "$root_part_info" | awk '{print $6}')

  # Setup loop device for Root partition
  root_loop_device=$(udisksctl loop-setup --file "$raspios_location" | awk '{print $4}')

  # Mount Root partition
  udisksctl mount --block-device "$root_loop_device" --options="fstype=ext4" --no-user-interaction
  check_error "Error mounting RaspiOS root partition"
  e2label "$root_loop_device" qemu-root
  print_info "Raspios root partition successfully mounted at $root_mount_point"

  # Set rpi password and enable ssh
  password_hash=$(openssl passwd -6 "$rpi_password")
  touch "$boot_mount_point/ssh"
  echo "pi:$password_hash" > "$boot_mount_point/userconf"

  # Copy kernel, modules, device tree blobs and set active kernel in config.txt
  copy_kernel_to_rpi "$RPI_ARCH" "$boot_mount_point" "$root_mount_point"

  # Unmount boot and root of RaspiOS
  udisksctl unmount --block-device "$boot_loop_device"
  udisksctl unmount --block-device "$root_loop_device"

  # Detach loop devices
  udisksctl loop-delete --block-device "$boot_loop_device"
  udisksctl loop-delete --block-device "$root_loop_device"

  # Remove temporary directories
  rm -r "$boot_mount_point"
  rm -r "$root_mount_point"
  rm -r "$mount_point"


  QEMU_SD_LOCATION=$raspios_location
} 