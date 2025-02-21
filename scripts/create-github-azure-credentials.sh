#!/bin/bash

## Prerequisites
## az login --use-device-code
## gh auth login
##

set -euo pipefail

# Check if the user is logged in to Azure CLI.
if ! az account show >/dev/null 2>&1; then
  echo "Error: You must be logged in to Azure CLI. Run 'az login' to continue."
  exit 1
fi

# Check if the user is logged in to GitHub CLI.
if ! gh auth status >/dev/null 2>&1; then
  echo "Error: You must be logged in to GitHub CLI. Run 'gh auth login' to continue."
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

# Create the service principal and capture its JSON output.
sp_output=$(az ad sp create-for-rbac \
  --name "$AZURE_CONTAINER_APP_NAME" \
  --role Contributor \
  --scopes "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP_NAME" \
  --output json)

# Assign final_output from sp_output. Adjust the jq filter as needed.
final_output=$(echo "$sp_output" | jq --arg subId "$AZURE_SUBSCRIPTION_ID" '{
  clientSecret: .password,
  subscriptionId: $subId,
  tenantId: .tenant,
  clientId: .appId
}')

# Retrieve the Azure Container Registry login URL.
acr_login=$(az acr show --name "$AZURE_CONTAINER_REGISTRY_NAME" --query "loginServer" --output tsv)
echo "ACR Login URL: $acr_login"

# Retrieve the ACR credentials (username and password).
acr_creds=$(az acr credential show --name "$AZURE_CONTAINER_REGISTRY_NAME" --output json)
acr_username=$(echo "$acr_creds" | jq -r '.username')
acr_password=$(echo "$acr_creds" | jq -r '.passwords[0].value')

# Verify that none of the required values are empty.
if [ -z "$final_output" ]; then
  echo "Error: final_output is empty. Cannot proceed."
  exit 1
fi
if [ -z "$acr_login" ]; then
  echo "Error: ACR login URL is empty. Check AZURE_CONTAINER_REGISTRY_NAME."
  exit 1
fi
if [ -z "$acr_username" ]; then
  echo "Error: ACR username is empty."
  exit 1
fi
if [ -z "$acr_password" ]; then
  echo "Error: ACR password is empty."
  exit 1
fi
if [ -z "$AZURE_CONTAINER_APP_NAME" ]; then
  echo "Error: AZURE_CONTAINER_APP_NAME is empty."
  exit 1
fi
if [ -z "$AZURE_RESOURCE_GROUP_NAME" ]; then
  echo "Error: AZURE_RESOURCE_GROUP_NAME is empty."
  exit 1
fi
if [ -z "$AZURE_CONTAINER_REGISTRY_NAME" ]; then
  echo "Error: AZURE_CONTAINER_REGISTRY_NAME is empty."
  exit 1
fi

# WARNING: The following prints include sensitive credentials.
# Do NOT leave this in production environments.
echo "-------------------------"
echo "Printing secrets for debugging:"

echo "ACR Login URL: $acr_login"
echo "ACR Username: $acr_username"
echo "ACR Password: $acr_password"

echo "AZURE_CONTAINER_REGISTRY_LOGIN_SERVER: $acr_login"
echo "AZURE_CONTAINER_REGISTRY_NAME_USERNAME: $acr_username"
echo "AZURE_CONTAINER_REGISTRY_NAME_PASSWORD: $acr_password"
echo "AZURE_CONTAINER_APP_NAME: $AZURE_CONTAINER_APP_NAME"
echo "AZURE_CREDENTIALS: $final_output"
echo "AZURE_RESOURCE_GROUP_NAME: $AZURE_RESOURCE_GROUP_NAME"
echo "IMAGE_NAME: $AZURE_CONTAINER_APP_NAME"
echo "-------------------------"

# Set the secrets using GitHub CLI for deployment.
gh secret set AZURE_CONTAINER_REGISTRY_LOGIN_SERVER -b"$acr_login"
gh secret set AZURE_CONTAINER_REGISTRY_NAME_USERNAME -b"$acr_username"
gh secret set AZURE_CONTAINER_REGISTRY_NAME_PASSWORD -b"$acr_password"
gh secret set AZURE_CONTAINER_APP_NAME -b"$AZURE_CONTAINER_APP_NAME"
gh secret set AZURE_CREDENTIALS -b"$final_output"
gh secret set AZURE_RESOURCE_GROUP_NAME -b"$AZURE_RESOURCE_GROUP_NAME"
gh secret set IMAGE_NAME -b"$AZURE_CONTAINER_APP_NAME"

echo "Secrets have been set successfully."


