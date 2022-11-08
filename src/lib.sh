#!/usr/bin/env bash

# Bash strict mode
set -eo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

# Constants
readonly SCRIPTY_VERSION="1.0.0"

# Found current script directory
readonly RELATIVE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Found project directory
readonly BASE_PROJECT="$(dirname "${RELATIVE_DIR}")"

#######################################
# Log an action.
# Globals:
#   DISABLE_CONSOLE_COLORS
# Arguments:
#   ${@}: Any texts.
# Outputs:
#   Log a message as action.
#######################################
function log::action {
  local disable_console_colors; disable_console_colors=$(env::get_or_empty "DISABLE_CONSOLE_COLORS")
  if [ -z "${disable_console_colors}" ]; then
    echo -e "\033[33m⇒\033[0m ${@}"
  else
    echo -e "${@}"
  fi
}

#######################################
# Log a failure.
# Globals:
#   DISABLE_CONSOLE_COLORS
# Arguments:
#   ${@}: Any texts.
# Outputs:
#   Log a message as failure.
#######################################
function log::failure {
  local disable_console_colors; disable_console_colors=$(env::get_or_empty "DISABLE_CONSOLE_COLORS")
  if [ -z "${disable_console_colors}" ]; then
    echo -e "\033[31m✗\033[0m Failed to ${@}" >&2
  else
    echo -e "Failed to ${@}" >&2
  fi
}

#######################################
# Log a success.
# Globals:
#   DISABLE_CONSOLE_COLORS
# Arguments:
#   ${@}: Any texts.
# Outputs:
#   Log a message as success.
#######################################
function log::success {
  local disable_console_colors; disable_console_colors=$(env::get_or_empty "DISABLE_CONSOLE_COLORS")
  if [ -z "${disable_console_colors}" ]; then
    echo -e "\033[32m✓\033[0m Succeeded to ${@}"
  else
    echo -e "Succeeded to ${@}"
  fi
}

#######################################
# Print a variable in hex.
# Arguments:
#   ${1}: Variable to print in hex.
# Outputs:
#   Hex representation.
#######################################
function helper::print_to_hex {
  printf "%s" "${1}" | hexdump -C
}

#######################################
# Execute a command with arguments.
# Globals:
#   SILENT_STDOUT
# Arguments:
#   ${@}: Any arguments.
# Returns:
#   Exit status of the command executed.
#######################################
function helper::exec {
  local silent_stdout; silent_stdout=$(env::get_or_empty "SILENT_STDOUT")
  local err_exit_ctx=$(shopt -o errexit)

  set +e
  if [ -z "${silent_stdout}" ]; then
    ${@}
  else
    ${@} > /dev/null
  fi
  local status=$?
  if [ $(echo "${err_exit_ctx}" | grep "on") ]; then
    set -e
  fi
  return ${status}
}

#######################################
# Try to run a command with arguments.
# Globals:
#   SILENT_STDOUT
#   CATCH_ERROR
# Arguments:
#   $1: Suffix for log success or error.
#   ${@:2}: Any arguments.
# Returns:
#   Exit status of the command executed.
#######################################
function helper::try {
  helper::exec ${@:2}
  local status=$?
  if [ ${status} -eq 0 ]; then
    log::success "${1}"
  else
    log::failure "${1}"
    local catch_error; catch_error=$(env::get_or_empty "CATCH_ERROR")
    if [ ${status} -ne 0 ] && [ ! -z "${catch_error}" ]; then
      return 0
    else
      exit ${status}
    fi
  fi
  return ${status}
}

#######################################
# Run a command with arguments and propagate errors if any.
# Arguments:
#   ${1}: Suffix for log success or error.
#   ${@:2}: Any arguments.
# Returns:
#   Exit status of the command executed.
#######################################
function helper::propagate_error {
  SILENT_STDOUT="true" helper::exec ${@:2}
  local status=$?
  if [ ${status} -ne 0 ]; then
    log::failure "${1}"
    exit ${status}
  fi
  return 0
}

#######################################
# Raise an error and exit.
# Arguments:
#   ${1}: Any textual reason.
# Returns:
#   Always exit 1.
#######################################
function helper::raise_error {
  log::failure "$@"
  exit 1
}

#######################################
# Check if a list of command is present in the current context.
# Arguments:
#   ${@}: Commands to check.
# Returns:
#   0 if the command is present.
#   1 otherwise.
#######################################
function helper::commands_are_present {
  for cmd in "${@}"; do
    if ! [ -x "$(command -v "${cmd}")" ]; then
      helper::raise_error "locate command '${cmd}'"
    fi
  done
}

#######################################
# Retrive an environment variable.
# Arguments:
#   ${1}: Environment variable to get.
# Outputs:
#   Environment variable value.
# Returns:
#   0 if the environment variable is present.
#   1 otherwise.
#######################################
function env::get {
  local var; var=$(printf '%s\n' "${!1}")
  if [ -z "${var}" ]; then
    helper::raise_error "retrieve environment '${1}' variable"
  fi
  echo -e "${var}"
}

#######################################
# Retrive an environment variable or return default value.
# Arguments:
#   ${1}: Environment variable to get.
#   ${2}: Default value.
# Outputs:
#   Environment variable value or default value.
#######################################
function env::get_or_default {
  local var; var=$(printf '%s\n' "${!1}")
  if [ -z "${var}" ]; then
    echo -e "${2}"
  else
    echo -e "${var}"
  fi
}

#######################################
# Retrive an environment variable or return empty value.
# Arguments:
#   ${1}: Environment variable to get.
# Outputs:
#   Environment variable value or empty value.
#######################################
function env::get_or_empty {
  env::get_or_default "${1}" ""
}

#######################################
# Retrive an environment variable or return readed value.
# Arguments:
#   ${1}: Environment variable to get.
# Outputs:
#   Environment variable value or readed value.
# Returns:
#   0 if the environment variable is present or readed.
#   1 otherwise.
#######################################
function env::get_or_read {
  local var; var=$(printf '%s\n' "${!1}")
  if [ -z "${var}" ]; then
    read -p "Value for ${1}: `echo $'\n> '`" var
  fi
  echo -e "${var}"
}

#######################################
# Print a random char sequence suitable for id.
# Outputs:
#   Random char sequence containing alphanumeric.
#######################################
function str::random {
  cat /dev/urandom | env LC_ALL="C.UTF-8" LANG="C.UTF-8" LC_CTYPE="C" tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
}

log::action "The script you are running has basename $(basename "${0}"), dirname $(dirname "${0}")"
log::action "The base project directory is ${BASE_PROJECT}"
log::action "The present working directory is $(pwd)"
