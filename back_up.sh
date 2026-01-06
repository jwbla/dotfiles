#!/bin/bash

# Backup script that compresses directories into tar.gz files with high compression
# and splits them into 100MB chunks for easy syncing to NAS

# Array of directories to backup (add your directories here)
DIRS=(
    # "/path/to/directory1"
    # "/path/to/directory2"
    # "/path/to/directory3"
)

# Backup destination directory
BACKUP_DIR="$HOME/backup"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to backup a directory
backup_directory() {
    local dir="$1"
    local dir_name=$(basename "$dir")
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_name="${dir_name}_${timestamp}"
    local backup_path="${BACKUP_DIR}/${backup_name}.tar.gz"
    
    # Check if directory exists
    if [ ! -d "$dir" ]; then
        echo "Warning: Directory '$dir' does not exist. Skipping..."
        return 1
    fi
    
    echo "Backing up: $dir"
    echo "Output: ${backup_path}.*"
    
    # Create tar.gz with maximum compression (level 9) and split into 100MB chunks
    # Using --use-compress-program to set gzip compression level to 9
    tar -c -f - --use-compress-program="gzip -9" "$dir" | split -b 100M - "${backup_path}."
    
    if [ $? -eq 0 ]; then
        echo "Successfully backed up: $dir"
        echo "Chunks saved to: ${BACKUP_DIR}/${backup_name}.tar.gz.*"
    else
        echo "Error: Failed to backup $dir"
        return 1
    fi
    
    echo ""
}

# Main backup loop
if [ ${#DIRS[@]} -eq 0 ]; then
    echo "No directories specified in DIRS array. Please add directories to backup."
    exit 1
fi

echo "Starting backup process..."
echo "Backup destination: $BACKUP_DIR"
echo ""

# Backup each directory
for dir in "${DIRS[@]}"; do
    # Skip empty entries and comments
    if [ -z "$dir" ] || [[ "$dir" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    backup_directory "$dir"
done

echo "Backup process completed!"
echo ""
echo "To restore a backup, use:"
echo "  cat ${BACKUP_DIR}/backup_name.tar.gz.* | tar -xzf -"
