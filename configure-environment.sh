#!/bin/bash

YAML_FILE="onboarding-config.yml"
SECTIONS=("common-tooling-service" "common-db-service" "common-app-service" "core-services" "auth-service" "users-service")

# ═══════════════════════════════════════════════════════════════════════════
# PREREQUISITE VALIDATION
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Validating Required Tools"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

MISSING_TOOLS=()

# ── Check: yq (YAML processor) ────────────────────────────────────────────
if ! command -v yq &> /dev/null; then
    echo "❌ yq - YAML processor (required)"
    MISSING_TOOLS+=("yq")
else
    YQ_VERSION=$(yq --version 2>&1 | head -n1)
    echo "✅ yq - $YQ_VERSION"
fi

# ── Check: Docker ──────────────────────────────────────────────────────────
if ! command -v docker &> /dev/null; then
    echo "❌ docker - Container runtime (required)"
    MISSING_TOOLS+=("docker")
else
    DOCKER_VERSION=$(docker --version 2>&1)
    echo "✅ docker - $DOCKER_VERSION"
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        echo "   ⚠️  Warning: Docker daemon is not running"
        echo "   → Start Docker Desktop or run: sudo systemctl start docker"
    fi
fi

# ── Check: Docker Compose ──────────────────────────────────────────────────
COMPOSE_FOUND=false
if docker compose version &> /dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version 2>&1)
    echo "✅ docker compose - $COMPOSE_VERSION"
    COMPOSE_FOUND=true
elif command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version 2>&1)
    echo "✅ docker-compose - $COMPOSE_VERSION"
    COMPOSE_FOUND=true
fi

if [ "$COMPOSE_FOUND" = false ]; then
    echo "❌ docker compose - Container orchestration (required)"
    MISSING_TOOLS+=("docker-compose")
fi

# ── Check: Git ─────────────────────────────────────────────────────────────
if ! command -v git &> /dev/null; then
    echo "❌ git - Version control (required)"
    MISSING_TOOLS+=("git")
else
    GIT_VERSION=$(git --version 2>&1)
    echo "✅ git - $GIT_VERSION"
fi

# ── Check: VS Code (recommended, not required) ─────────────────────────────
if command -v code &> /dev/null; then
    VSCODE_VERSION=$(code --version 2>&1 | head -n1)
    echo "✅ code (VS Code) - $VSCODE_VERSION"
    
    # Check for Dev Containers extension (best effort)
    if code --list-extensions 2>&1 | grep -q "ms-vscode-remote.remote-containers"; then
        echo "   ✅ Dev Containers extension installed"
    else
        echo "   ⚠️  Warning: Dev Containers extension not detected"
        echo "   → Install: code --install-extension ms-vscode-remote.remote-containers"
    fi
else
    echo "⚠️  code (VS Code) - Not found (recommended for Dev Container workflow)"
    echo "   → Download: https://code.visualstudio.com/"
fi

# ── Optional: uuidgen (has fallback) ───────────────────────────────────────
if ! command -v uuidgen &> /dev/null; then
    echo "ℹ️  uuidgen - Not found (will use fallback UUID generation)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Exit if required tools are missing ────────────────────────────────────
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo ""
    echo "❌ Missing required tools: ${MISSING_TOOLS[*]}"
    echo ""
    echo "Installation instructions:"
    echo ""
    
    for tool in "${MISSING_TOOLS[@]}"; do
        case $tool in
            yq)
                echo "  • yq (YAML processor):"
                echo "    macOS:   brew install yq"
                echo "    Linux:   wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq"
                echo "    Windows: choco install yq"
                echo "    Docs:    https://github.com/mikefarah/yq"
                echo ""
                ;;
            docker)
                echo "  • Docker:"
                echo "    Download Docker Desktop: https://www.docker.com/get-started"
                echo "    macOS:   brew install --cask docker"
                echo "    Linux:   https://docs.docker.com/engine/install/"
                echo ""
                ;;
            docker-compose)
                echo "  • Docker Compose:"
                echo "    Usually included with Docker Desktop"
                echo "    Linux standalone: https://docs.docker.com/compose/install/"
                echo ""
                ;;
            git)
                echo "  • Git:"
                echo "    macOS:   brew install git"
                echo "    Linux:   sudo apt-get install git (Ubuntu/Debian)"
                echo "    Windows: https://git-scm.com/download/win"
                echo ""
                ;;
        esac
    done
    
    exit 1
fi

echo ""
echo "✅ All required tools are installed!"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# ENVIRONMENT CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

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

# Function to generate a Kafka cluster ID for KRaft mode
# Returns a 22-character base64url-encoded UUID
generate_cluster_id() {
    # Check if Docker is available
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        # Use Kafka's built-in cluster ID generator (most reliable)
        docker run --rm confluentinc/cp-kafka:7.6.1 kafka-storage random-uuid 2>/dev/null
    else
        echo "Error: Docker is required to generate Kafka cluster ID" >&2
        exit 1
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
            elif [[ "$val" == "generate_cluster_id" ]]; then
                val=$(generate_cluster_id)
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
