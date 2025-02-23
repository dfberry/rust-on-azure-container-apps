#!/bin/bash

## Prerequisites
## az login --use-device-code
##

set -euo pipefail

# Check if the user is logged in to Azure CLI.
if ! az account show >/dev/null 2>&1; then
  echo "Error: You must be logged in to Azure CLI. Run 'az login' to continue."
  exit 1
fi

# Path to .env file
DOTENV_PATH=".env"

# Load environment variables from .env file into the script's environment
if [ -f "$DOTENV_PATH" ]; then
  set -a
  source "$DOTENV_PATH"
  set +a
else
  echo "Error: .env file not found at $DOTENV_PATH"
  exit 1
fi

## Prerequisites
## az login --use-device-code
az containerapp logs show \
--name $AZURE_CONTAINER_APP_NAME \
--resource-group $AZURE_RESOURCE_GROUP_NAME \
--follow