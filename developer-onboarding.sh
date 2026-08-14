#!/bin/bash
clear

# Configuration file path
CONFIG_FILE="onboarding-config.yml"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found."
    exit 1
fi

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: 'yq' tool is required but not installed."
    echo "Install it via homebrew (brew install yq) or visit https://github.com"
    exit 1
fi

# Check if yq is installed
if ! command -v docker &> /dev/null; then
    echo "Error: 'docker' tool is required but not installed."
    echo "Install it via homebrew (brew install docker) or visit https://www.docker.com/get-started"
    exit 1
fi


# Extract organization name
ORG=$(yq '.github-organization' "$CONFIG_FILE")

if [ -z "$ORG" ] || [ "$ORG" = "null" ]; then
    echo "Error: Could not find 'github-organization' in $CONFIG_FILE."
    exit 1
fi

# Prompt user for protocol preference
echo "Select the cloning protocol for github.com/${ORG}:"
echo "1) HTTPS"
echo "2) SSH"
read -rp "Enter choice [1 or 2]: " PROTOCOL_CHOICE

# Get total number of repositories
REPO_COUNT=$(yq '.repositories | length' "$CONFIG_FILE")

if [ "$REPO_COUNT" -eq 0 ] || [ "$REPO_COUNT" = "null" ]; then
    echo "No repositories found to clone."
    exit 0
fi

clear

echo "Found $REPO_COUNT repositories. Starting cloning process..."
echo "----------------------------------------"
echo ""

# Loop through repositories using their index array
for ((i=0; i<REPO_COUNT; i++)); do
    # Extract repository name
    REPO_NAME=$(yq ".repositories[$i].name" "$CONFIG_FILE")
    
    if [ -z "$REPO_NAME" ] || [ "$REPO_NAME" = "null" ]; then
        continue
    fi
    
    # Construct URL based on protocol choice
    if [ "$PROTOCOL_CHOICE" = "2" ]; then
        CLONE_URL="git@github.com:${ORG}/${REPO_NAME}.git"
    else
        CLONE_URL="https://github.com/${ORG}/${REPO_NAME}.git"
    fi
    
    # Check if the folder already exists
    if [ -d "$REPO_NAME" ]; then
        echo "✅ $REPO_NAME already exists."
    else
        echo "📥 $REPO_NAME not found. Cloning via $CLONE_URL..."
        git clone "$CLONE_URL"
    fi

done
echo ""
echo "----------------------------------------"
echo "Finished processing all repositories."
