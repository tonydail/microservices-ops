#!/bin/bash

YAML_FILE="onboarding-config.yml"
SECTIONS=("common-db-service" "common-app-service" "core-services" "auth-service" "users-service")

# Ensure yq is installed
if ! command -v yq &> /dev/null; then
    echo "❌ Error: 'yq' (Mike Farah v4+) is required but not installed."
    exit 1
fi

# Function to generate a UUID version 4
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        # Fallback math-based pseudo-UUID generation if uuidgen is missing
        printf '%04x%04x-%04x-%04x-%04x-%04x%04x%04x\n' \
            $((RANDOM)) $((RANDOM)) $((RANDOM)) $((RANDOM)) $((RANDOM)) $((RANDOM)) $((RANDOM)) $((RANDOM))
    fi
}

# Function to securely prompt the user for input
ask_user() {
    local key="$1"
    local service="$2"
    local lower_key
    lower_key=$(echo "$key" | tr '[:upper:]' '[:lower:]')
    local user_input

    # Securely mask the typing input using `read -s` if it looks like a sensitive credential
    # if [[ "$lower_key" == *"password"* || "$lower_key" == *"secret"* || "$lower_key" == *"token"* ]]; then
    #     read -s -p "🔒 Enter password for [$service] -> $key: " user_input </dev/tty
    #     echo "" >&2 # Add newline to console since -s suppresses it
    # else
        read -p "✏️  Enter value for [$service] -> $key: " user_input </dev/tty
    # fi
    echo "$user_input"
}

echo "🚀 Starting interactive Bash environment generation (Bash 3.2+ Compatible)..."

for section in "${SECTIONS[@]}"; do
    # Get total array items in the current section
    length=$(yq ".${section} | length" "$YAML_FILE")
    [[ "$length" -eq 0 || "$length" == "null" ]] && continue

    for ((i=0; i<length; i++)); do
        # Extract metadata and destination env file path
        service_name=$(yq ".${section}[$i].name" "$YAML_FILE")
        env_file=$(yq ".${section}[$i].env_file" "$YAML_FILE")

		prompt_message=$(yq ".${section}[$i].prompt" "$YAML_FILE")
		description=$(yq ".${section}[$i].description" "$YAML_FILE")	
        
        # Skip if no target destination is defined
        [[ "$env_file" == "null" || -z "$env_file" ]] && continue

        echo "-> Processing: $description"
        mkdir -p "$(dirname "$env_file")"
        
        # Initialize/truncate the destination file
        > "$env_file"

        # Bash 3.2 Fix: Use a while-read loop instead of readarray to fetch the keys
        yq ".${section}[$i].environment | keys | .[]" "$YAML_FILE" 2>/dev/null | while IFS= read -r key; do
            # Skip empty lines
            [[ -z "$key" || "$key" == "null" ]] && continue

            # Extract value cleanly
            val=$(yq ".${section}[$i].environment.${key}" "$YAML_FILE")
            
            # Dynamic Key Value Switchboard Interceptor
            if [[ "$val" == "generate_uuid" ]]; then
                val=$(generate_uuid)
            elif [[ "$val" == "ask_user" ]]; then
                val=$(ask_user "$key" "$prompt_message")
            fi

            # Append calculated values directly into properties structure
            echo "${key}=${val}" >> "$env_file"
        done
        echo "💾 Saved to: $env_file"
    done
done

echo -e "\n✅ Environment files built successfully!"
