#! /bin/bash

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
