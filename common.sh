#! /bin/bash

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
  calling_function="${FUNCNAME[1]}"
  printf "${ANSI_RED}[ ERROR ]${ANSI_RESET} ${calling_function}: %s\n" "$1"
  printf ""
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