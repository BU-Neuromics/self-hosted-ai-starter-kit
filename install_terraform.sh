#!/bin/bash

# Set Terraform version
TERRAFORM_VERSION="1.10.5"

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Convert architecture naming
case "${ARCH}" in
    x86_64)
        ARCH=amd64
        ;;
    aarch64)
        ARCH=arm64
        ;;
esac

# Construct download URL
DOWNLOAD_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${OS}_${ARCH}.zip"

echo "Downloading Terraform ${TERRAFORM_VERSION}..."
curl -LO "${DOWNLOAD_URL}"

echo "Extracting Terraform..."
unzip "terraform_${TERRAFORM_VERSION}_${OS}_${ARCH}.zip"

echo "Cleaning up..."
rm "terraform_${TERRAFORM_VERSION}_${OS}_${ARCH}.zip"

echo "Making Terraform executable..."
chmod +x terraform

echo "Terraform has been installed successfully!"
echo "Current version:"
./terraform version 