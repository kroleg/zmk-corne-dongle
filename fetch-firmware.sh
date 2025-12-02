#!/bin/bash
# Fetch latest firmware artifact from GitHub Actions
# Requires: curl, jq, unzip
# Store GITHUB_TOKEN in .env file

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="kroleg/zmk-corne-dongle"
WORKFLOW="build.yml"
OUTPUT_DIR="${1:-$HOME/Downloads}"

# Load token from .env
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env"
fi

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "Error: GITHUB_TOKEN not found."
    echo "Create .env file with: GITHUB_TOKEN=ghp_xxx"
    exit 1
fi

API_URL="https://api.github.com/repos/$REPO"
AUTH_HEADER="Authorization: Bearer $GITHUB_TOKEN"

fetch() {
    curl -sL -H "$AUTH_HEADER" -H "Accept: application/vnd.github+json" -o "$2" "$1"
}

fetch_json() {
    curl -sL -H "$AUTH_HEADER" -H "Accept: application/vnd.github+json" "$1"
}

echo "Fetching latest build from $REPO..."

# Get latest workflow run (any status)
RUN_DATA=$(fetch_json "$API_URL/actions/workflows/$WORKFLOW/runs?per_page=1")
RUN_ID=$(echo "$RUN_DATA" | jq -r '.workflow_runs[0].id')

if [[ -z "$RUN_ID" || "$RUN_ID" == "null" ]]; then
    echo "Error: No builds found."
    exit 1
fi

# Wait for workflow to complete if still running
while true; do
    RUN_DATA=$(fetch_json "$API_URL/actions/runs/$RUN_ID")
    RUN_STATUS=$(echo "$RUN_DATA" | jq -r '.status')
    RUN_CONCLUSION=$(echo "$RUN_DATA" | jq -r '.conclusion')

    if [[ "$RUN_STATUS" == "completed" ]]; then
        if [[ "$RUN_CONCLUSION" != "success" ]]; then
            echo "Error: Build failed (conclusion: $RUN_CONCLUSION)"
            echo "Check: https://github.com/$REPO/actions/runs/$RUN_ID"
            exit 1
        fi
        break
    fi

    echo "Workflow in progress (status: $RUN_STATUS)... waiting 10s"
    sleep 10
done

RUN_DATE=$(echo "$RUN_DATA" | jq -r '.created_at')
echo "Found run #$RUN_ID from $RUN_DATE"

# Get artifacts
ARTIFACTS=$(fetch_json "$API_URL/actions/runs/$RUN_ID/artifacts")
ARTIFACT_COUNT=$(echo "$ARTIFACTS" | jq -r '.total_count')

if [[ "$ARTIFACT_COUNT" -eq 0 ]]; then
    echo "Error: No artifacts found."
    exit 1
fi

echo "Found $ARTIFACT_COUNT artifact(s)"
mkdir -p "$OUTPUT_DIR"

# Download each artifact
echo "$ARTIFACTS" | jq -r '.artifacts[] | "\(.id) \(.name)"' | while read -r ID NAME; do
    echo "Downloading: $NAME..."
    TEMP_ZIP=$(mktemp)
    fetch "$API_URL/actions/artifacts/$ID/zip" "$TEMP_ZIP"

    ARTIFACT_DIR="$OUTPUT_DIR/$NAME"
    mkdir -p "$ARTIFACT_DIR"
    unzip -o -q "$TEMP_ZIP" -d "$ARTIFACT_DIR"
    rm "$TEMP_ZIP"
    echo "  Extracted to: $ARTIFACT_DIR"
done

echo "Done!"

# Notification
osascript -e 'display notification "Firmware downloaded" with title "ZMK Build"' 2>/dev/null || printf '\a'
