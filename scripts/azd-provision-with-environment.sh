#!/bin/bash

## Prerequisites
## az login --use-device-code
##

set -euo pipefail
trap 'echo "Error occurred in ${BASH_SOURCE[0]} at line ${LINENO}"' ERR

# Check if the user is logged in to Azure CLI.
if ! az account show >/dev/null 2>&1; then
  echo "Error: You must be logged in to Azure CLI. Run 'az login' to continue."
  exit 1
fi

# Function to count environment variable lines (ignoring comments and blank lines)
count_env_vars() {
  local file=$1
  grep -E '^\s*[A-Za-z_][A-Za-z0-9_]*=' "$file" | wc -l
}

# Load variables from .env file and export them
if [ -f .env ]; then
    original_count=$(count_env_vars .env)
    echo "Original .env variable count: $original_count"
    set -o allexport
    source .env
    set +o allexport
else
    echo ".env file not found. Exiting."
    exit 1
fi
echo "-------------------------"
echo "Running azd provision with environment variables loaded from .env"
azd provision
echo "-------------------------"
# Path to the .azure config file
CONFIG_FILE=".azure/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found."
  exit 1
fi

# Extract the defaultEnvironment value
DEFAULT_ENV=$(jq -r '.defaultEnvironment' "$CONFIG_FILE")
if [ -z "$DEFAULT_ENV" ] || [ "$DEFAULT_ENV" = "null" ]; then
  echo "Error: defaultEnvironment property not found or empty in $CONFIG_FILE."
  exit 1
fi

# Construct the path to the subfolder's .env file
SUBFOLDER_ENV=".azure/$DEFAULT_ENV/.env"
if [ ! -f "$SUBFOLDER_ENV" ]; then
  echo "Error: .env file not found in subfolder $DEFAULT_ENV."
  exit 1
fi

# Count the environment variables in the subfolder's .env
append_count=$(count_env_vars "$SUBFOLDER_ENV")
echo "Subfolder .env variable count: $append_count"

# Ensure appended variables start on a new line
echo "" >> .env

# Append the values from the subfolder .env to the root .env.
echo "-------------------------\n"
echo "Appending values from $SUBFOLDER_ENV to .env"
cat "$SUBFOLDER_ENV" >> .env

# Verify by counting new total environment variables
new_count=$(count_env_vars .env)
expected_count=$(( original_count + append_count ))
echo "New total .env variable count: $new_count (expected: $expected_count)"

if [ "$new_count" -ne "$expected_count" ]; then
  echo "Error: The total number of environment variables ($new_count) does not match the sum of original plus appended ($expected_count)."
  exit 1
fi

echo "Finished appending. Root .env updated with values from $SUBFOLDER_ENV"

