#!/usr/bin/env bash
set -e

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/Jackett"
mkdir -p "$CONFIG_DIR"

SERVER_CONFIG_FILE="$CONFIG_DIR/ServerConfig.json"

if [ ! -f "$SERVER_CONFIG_FILE" ]; then
    echo "{}" > "$SERVER_CONFIG_FILE"
fi

# Update ServerConfig.json from environment variables
if [ -n "$API_KEY" ] || [ -n "$ADMIN_PASSWORD" ] || [ -n "$BASE_PATH" ]; then
    echo "Updating ServerConfig.json from environment variables..."
    jq_filter="."
    if [ -n "$API_KEY" ]; then
        jq_filter="$jq_filter | .APIKey = \$api_key"
    fi
    if [ -n "$ADMIN_PASSWORD" ]; then
        jq_filter="$jq_filter | .AdminPassword = \$admin_password"
    fi
    if [ -n "$BASE_PATH" ]; then
        jq_filter="$jq_filter | .BasePathOverride = \$base_path"
    fi
    jq_filter="$jq_filter | .UpdateDisabled = true"

    tmp_file=$(mktemp)
    jq --arg api_key "${API_KEY:-}" \
       --arg admin_password "${ADMIN_PASSWORD:-}" \
       --arg base_path "${BASE_PATH:-}" \
       "$jq_filter" "$SERVER_CONFIG_FILE" > "$tmp_file" && mv "$tmp_file" "$SERVER_CONFIG_FILE"
fi

INDEXERS_DIR="$CONFIG_DIR/Indexers"
mkdir -p "$INDEXERS_DIR"

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

PORT="${PORT:-9117}"

echo "Starting Jackett on port $PORT..."
exec /opt/Jackett/jackett --Port "$PORT" --ListenPublic --NoUpdates "$@"
