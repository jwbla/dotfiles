#!/bin/bash

# Backup script that creates a single archive with all directories,
# a JSON manifest, and a restore script

# Array of directories to backup (add your directories here)
DIRS=(
    "/home/jwbla/.task"
    "/home/jwbla/.config/timewarrior"
    # "/path/to/directory1"
    # "/path/to/directory2"
    # "/path/to/directory3"
)

# Backup destination directory
BACKUP_DIR="$HOME/backup"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create timestamp for backup
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="backup_${TIMESTAMP}"
TEMP_BACKUP_DIR="${BACKUP_DIR}/${BACKUP_NAME}"
MANIFEST_FILE="${TEMP_BACKUP_DIR}/manifest.json"
RESTORE_SCRIPT="${TEMP_BACKUP_DIR}/restore.sh"

# Create temporary backup directory
mkdir -p "$TEMP_BACKUP_DIR"

# Initialize JSON manifest array
echo "[" > "$MANIFEST_FILE"
FIRST_ENTRY=true

# Function to backup a directory
backup_directory() {
    local original_path="$1"
    local dir_name=$(basename "$original_path")
    local backup_path="${TEMP_BACKUP_DIR}/${dir_name}"
    
    # Check if directory exists
    if [ ! -d "$original_path" ]; then
        echo "Warning: Directory '$original_path' does not exist. Skipping..."
        return 1
    fi
    
    echo "Backing up: $original_path"
    
    # Copy directory to backup location
    cp -r "$original_path" "$backup_path"
    
    if [ $? -eq 0 ]; then
        echo "Successfully backed up: $original_path"
        
        # Add entry to manifest JSON
        if [ "$FIRST_ENTRY" = false ]; then
            echo "," >> "$MANIFEST_FILE"
        fi
        echo "  {" >> "$MANIFEST_FILE"
        echo "    \"original_path\": \"$original_path\"," >> "$MANIFEST_FILE"
        echo "    \"backup_name\": \"$dir_name\"" >> "$MANIFEST_FILE"
        echo "  }" >> "$MANIFEST_FILE"
        FIRST_ENTRY=false
    else
        echo "Error: Failed to backup $original_path"
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
echo "Backup destination: $TEMP_BACKUP_DIR"
echo ""

# Backup each directory
for dir in "${DIRS[@]}"; do
    # Skip empty entries and comments
    if [ -z "$dir" ] || [[ "$dir" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    backup_directory "$dir"
done

# Close JSON manifest array
echo "]" >> "$MANIFEST_FILE"

# Create restore script
cat > "$RESTORE_SCRIPT" << 'RESTORE_EOF'
#!/bin/bash

# Restore script that reads manifest.json and restores files to their original locations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="${SCRIPT_DIR}/manifest.json"

if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Error: manifest.json not found in $SCRIPT_DIR"
    exit 1
fi

echo "Reading manifest from: $MANIFEST_FILE"
echo ""

# Check if jq is available for JSON parsing
if command -v jq &> /dev/null; then
    # Use jq to parse JSON
    TOTAL=$(jq 'length' "$MANIFEST_FILE")
    echo "Found $TOTAL items to restore"
    echo ""
    
    for i in $(seq 0 $((TOTAL - 1))); do
        ORIGINAL_PATH=$(jq -r ".[$i].original_path" "$MANIFEST_FILE")
        BACKUP_NAME=$(jq -r ".[$i].backup_name" "$MANIFEST_FILE")
        BACKUP_PATH="${SCRIPT_DIR}/${BACKUP_NAME}"
        
        if [ ! -d "$BACKUP_PATH" ]; then
            echo "Warning: Backup directory '$BACKUP_PATH' not found. Skipping..."
            continue
        fi
        
        echo "Restoring: $BACKUP_NAME -> $ORIGINAL_PATH"
        
        # Create parent directory if it doesn't exist
        PARENT_DIR=$(dirname "$ORIGINAL_PATH")
        mkdir -p "$PARENT_DIR"
        
        # Remove existing directory if it exists (with confirmation prompt)
        if [ -e "$ORIGINAL_PATH" ]; then
            echo "  Warning: '$ORIGINAL_PATH' already exists."
            read -p "  Overwrite? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "  Skipping..."
                continue
            fi
            rm -rf "$ORIGINAL_PATH"
        fi
        
        # Copy backup to original location
        cp -r "$BACKUP_PATH" "$ORIGINAL_PATH"
        
        if [ $? -eq 0 ]; then
            echo "  Successfully restored: $ORIGINAL_PATH"
        else
            echo "  Error: Failed to restore $ORIGINAL_PATH"
        fi
        echo ""
    done
else
    # Fallback: use basic parsing without jq
    echo "Warning: 'jq' not found. Using basic JSON parsing."
    echo "Consider installing 'jq' for better JSON parsing: sudo pacman -S jq"
    echo ""
    
    # Parse JSON entries - each entry is on multiple lines, extract pairs
    CURRENT_ORIGINAL=""
    CURRENT_BACKUP=""
    
    while IFS= read -r line; do
        # Extract original_path
        if [[ "$line" =~ \"original_path\":[[:space:]]*\"([^\"]+)\" ]]; then
            CURRENT_ORIGINAL="${BASH_REMATCH[1]}"
        # Extract backup_name
        elif [[ "$line" =~ \"backup_name\":[[:space:]]*\"([^\"]+)\" ]]; then
            CURRENT_BACKUP="${BASH_REMATCH[1]}"
            # When we have both, process the entry
            if [ -n "$CURRENT_ORIGINAL" ] && [ -n "$CURRENT_BACKUP" ]; then
                ORIGINAL_PATH="$CURRENT_ORIGINAL"
                BACKUP_NAME="$CURRENT_BACKUP"
                BACKUP_PATH="${SCRIPT_DIR}/${BACKUP_NAME}"
                
                if [ ! -d "$BACKUP_PATH" ]; then
                    echo "Warning: Backup directory '$BACKUP_PATH' not found. Skipping..."
                    CURRENT_ORIGINAL=""
                    CURRENT_BACKUP=""
                    continue
                fi
                
                echo "Restoring: $BACKUP_NAME -> $ORIGINAL_PATH"
                
                # Create parent directory if it doesn't exist
                PARENT_DIR=$(dirname "$ORIGINAL_PATH")
                mkdir -p "$PARENT_DIR"
                
                # Remove existing directory if it exists (with confirmation prompt)
                if [ -e "$ORIGINAL_PATH" ]; then
                    echo "  Warning: '$ORIGINAL_PATH' already exists."
                    read -p "  Overwrite? (y/N): " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                        echo "  Skipping..."
                        CURRENT_ORIGINAL=""
                        CURRENT_BACKUP=""
                        continue
                    fi
                    rm -rf "$ORIGINAL_PATH"
                fi
                
                # Copy backup to original location
                cp -r "$BACKUP_PATH" "$ORIGINAL_PATH"
                
                if [ $? -eq 0 ]; then
                    echo "  Successfully restored: $ORIGINAL_PATH"
                else
                    echo "  Error: Failed to restore $ORIGINAL_PATH"
                fi
                echo ""
                
                # Reset for next entry
                CURRENT_ORIGINAL=""
                CURRENT_BACKUP=""
            fi
        fi
    done < "$MANIFEST_FILE"
fi

echo "Restore process completed!"
RESTORE_EOF

# Make restore script executable
chmod +x "$RESTORE_SCRIPT"

echo "Creating archive..."
ARCHIVE_PATH="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"

# Create tar.gz archive with maximum compression
tar -czf "$ARCHIVE_PATH" -C "$BACKUP_DIR" "$BACKUP_NAME"

if [ $? -eq 0 ]; then
    echo "Successfully created archive: $ARCHIVE_PATH"
    
    # Remove the temporary directory after successful archive creation
    rm -rf "$TEMP_BACKUP_DIR"
    echo "Removed temporary backup directory"
    
    echo ""
    echo "Backup process completed!"
    echo ""
    echo "To restore:"
    echo "  1. Extract the archive: tar -xzf ${ARCHIVE_PATH}"
    echo "  2. cd into the extracted directory: cd ${BACKUP_NAME}"
    echo "  3. Run the restore script: ./restore.sh"
else
    echo "Error: Failed to create archive"
    exit 1
fi
