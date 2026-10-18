#!/usr/bin/env bash
set -e

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/Jackett"
INDEXERS_DIR="$CONFIG_DIR/Indexers"
mkdir -p "$CONFIG_DIR" "$INDEXERS_DIR"

SERVER_CONFIG_FILE="$CONFIG_DIR/ServerConfig.json"

# 1. First restore configuration archive if CONFIG_URL or INDEXER_CONFIGS_BASE64 is provided
if [ -n "$CONFIG_URL" ]; then
    echo "Restoring configuration from CONFIG_URL..."
    if [[ "$CONFIG_URL" =~ ^https:// ]]; then
        tmp_archive=$(mktemp)
        if curl -sSL "$CONFIG_URL" -o "$tmp_archive"; then
            tar -xzf "$tmp_archive" -C "$CONFIG_DIR" 2>/dev/null || unzip -o "$tmp_archive" -d "$CONFIG_DIR" 2>/dev/null || echo "Warning: Failed to extract archive from CONFIG_URL."
            rm -f "$tmp_archive"
        else
            echo "Warning: Failed to download configuration from CONFIG_URL."
        fi
    else
        echo "Error: CONFIG_URL must start with https:// for security."
    fi
elif [ -n "$INDEXER_CONFIGS_BASE64" ]; then
    echo "Restoring indexer configs from INDEXER_CONFIGS_BASE64..."
    tmp_archive=$(mktemp)
    if echo "$INDEXER_CONFIGS_BASE64" | base64 -d > "$tmp_archive" 2>/dev/null; then
        tar -xzf "$tmp_archive" -C "$CONFIG_DIR" 2>/dev/null || unzip -o "$tmp_archive" -d "$CONFIG_DIR" 2>/dev/null || echo "Warning: Failed to extract archive from INDEXER_CONFIGS_BASE64."
    else
        echo "Warning: Failed to base64 decode INDEXER_CONFIGS_BASE64."
    fi
    rm -f "$tmp_archive"
fi

if [ ! -f "$SERVER_CONFIG_FILE" ]; then
    echo "{}" > "$SERVER_CONFIG_FILE"
fi

# 2. Determine effective API Key and Admin Password hash
EXISTING_API_KEY=$(jq -r '.APIKey // empty' "$SERVER_CONFIG_FILE" 2>/dev/null || true)
EFFECTIVE_API_KEY="${API_KEY:-${EXISTING_API_KEY}}"

if [ -z "$EFFECTIVE_API_KEY" ]; then
    EFFECTIVE_API_KEY=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' || date +%s%N | sha256sum | head -c 32)
fi

HASHED_ADMIN_PASSWORD=""
if [ -n "$ADMIN_PASSWORD" ]; then
    HASHED_ADMIN_PASSWORD=$(printf "%s%s" "$ADMIN_PASSWORD" "$EFFECTIVE_API_KEY" | iconv -f UTF-8 -t UTF-16LE | sha512sum | awk '{print $1}')
fi

# 3. Apply ServerConfig.json overrides
echo "Updating ServerConfig.json..."
jq_filter="."
jq_filter="$jq_filter | .APIKey = \$api_key"
if [ -n "$HASHED_ADMIN_PASSWORD" ]; then
    jq_filter="$jq_filter | .AdminPassword = \$admin_password"
fi
if [ -n "$BASE_PATH" ]; then
    jq_filter="$jq_filter | .BasePathOverride = \$base_path"
fi
jq_filter="$jq_filter | .UpdateDisabled = true"

tmp_file=$(mktemp)
jq --arg api_key "$EFFECTIVE_API_KEY" \
   --arg admin_password "$HASHED_ADMIN_PASSWORD" \
   --arg base_path "${BASE_PATH:-}" \
   "$jq_filter" "$SERVER_CONFIG_FILE" > "$tmp_file" && mv "$tmp_file" "$SERVER_CONFIG_FILE"

PORT="${PORT:-9117}"

# Filter command-line arguments to ensure positional args and deprecated options (e.g., -c from shell wrappers) are ignored
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--UseClient)
            shift 2 2>/dev/null || shift 1
            ;;
        -c*)
            shift 1
            ;;
        -*)
            ARGS+=("$1")
            shift 1
            ;;
        *)
            shift 1
            ;;
    esac
done

echo "Starting Jackett on port $PORT..."
exec /opt/Jackett/jackett --Port "$PORT" --ListenPublic --NoUpdates "${ARGS[@]}"
