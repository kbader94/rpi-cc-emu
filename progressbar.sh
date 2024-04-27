#! /bin/bash

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
