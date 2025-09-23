#!/bin/bash

# Split Tar Archive Script
# Creates a tar.gz archive of a directory and splits it into 1GB chunks
# Usage: ./split_tar.sh <directory> [output_name] [chunk_size_gb]
#
# Dependencies:
#   - tar (coreutils) - for creating archives
#   - pigz - for parallel gzip compression (much faster than gzip)
#   - split (coreutils) - for splitting files
#   - bc - for calculations
#   - pv - for progress monitoring (optional, but recommended)
#
# Install with: sudo apt install tar pigz split bc pv

# Configuration
DEFAULT_CHUNK_SIZE_GB=1
CHUNK_SIZE_BYTES=$((DEFAULT_CHUNK_SIZE_GB * 1024 * 1024 * 1024))
OUTPUT_DIR="$HOME/.archivist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <directory> [output_name] [chunk_size_gb]"
    echo ""
    echo "Arguments:"
    echo "  directory      - Directory to archive (required)"
    echo "  output_name    - Base name for output files (optional, defaults to directory name)"
    echo "  chunk_size_gb  - Size of each chunk in GB (optional, defaults to 1GB)"
    echo ""
    echo "Examples:"
    echo "  $0 /home/user/documents"
    echo "  $0 /var/log my_logs 2"
    echo "  $0 /path/to/data backup_data 0.5"
    echo ""
    echo "Output files will be created in: ~/.archivist/"
    echo "Files will be named: <output_name>.tar.gz.001, <output_name>.tar.gz.002, etc."
    echo ""
    echo "Extraction instructions:"
    echo "  cat ~/.archivist/<output_name>.tar.gz.* | tar -xzf -"
    echo "  # Or extract to specific directory:"
    echo "  cat ~/.archivist/<output_name>.tar.gz.* | tar -xzf - -C /path/to/destination"
}

# Function to check if directory exists
check_directory() {
    local dir=$1
    if [[ ! -d "$dir" ]]; then
        print_status $RED "Error: Directory '$dir' does not exist or is not accessible."
        return 1
    fi
    return 0
}

# Function to get directory size
get_directory_size() {
    local dir=$1
    du -sb "$dir" 2>/dev/null | cut -f1
}

# Function to format bytes to human readable
format_bytes() {
    local bytes=$1
    if [[ $bytes -ge 1073741824 ]]; then
        echo "$(( bytes / 1073741824 ))GB"
    elif [[ $bytes -ge 1048576 ]]; then
        echo "$(( bytes / 1048576 ))MB"
    elif [[ $bytes -ge 1024 ]]; then
        echo "$(( bytes / 1024 ))KB"
    else
        echo "${bytes}B"
    fi
}

# Function to calculate number of chunks needed
calculate_chunks() {
    local total_size=$1
    local chunk_size=$2
    echo $(( (total_size + chunk_size - 1) / chunk_size ))
}

# Function to create the split tar archive
create_split_tar() {
    local source_dir=$1
    local output_name=$2
    local chunk_size=$3
    
    # Create output directory if it doesn't exist
    mkdir -p "$OUTPUT_DIR"
    
    print_status $BLUE "Creating split tar archive..."
    print_status $CYAN "Source: $source_dir"
    print_status $CYAN "Output: $OUTPUT_DIR/${output_name}.tar.gz.*"
    print_status $CYAN "Chunk size: $(format_bytes $chunk_size)"
    
    # Create the tar archive and pipe it through split
    print_status $YELLOW "Archiving and splitting..."
    
    # Choose compression method based on available tools
    local compression_cmd=""
    local file_extension=".tar.gz"
    
    if command -v pigz >/dev/null 2>&1; then
        compression_cmd="pigz -c"
        print_status $GREEN "Using pigz for parallel gzip compression (much faster!)"
    else
        compression_cmd="gzip -c"
        print_status $YELLOW "Using single-threaded gzip (install 'pigz' for parallel compression)"
    fi
    
    # Use tar with progress if pv is available, otherwise use regular tar
    if command -v pv >/dev/null 2>&1; then
        print_status $GREEN "Using pv for progress monitoring..."
        tar -cf - -C "$(dirname "$source_dir")" "$(basename "$source_dir")" | \
        pv -s "$(get_directory_size "$source_dir")" | \
        $compression_cmd | \
        split -b "$chunk_size" - "$OUTPUT_DIR/${output_name}${file_extension}."
    else
        print_status $YELLOW "Progress monitoring not available (install 'pv' for progress bars)"
        tar -cf - -C "$(dirname "$source_dir")" "$(basename "$source_dir")" | \
        $compression_cmd | \
        split -b "$chunk_size" - "$OUTPUT_DIR/${output_name}${file_extension}."
    fi
    
    # Add .001, .002, etc. extensions to the split files
    local chunk_num=1
    for file in "$OUTPUT_DIR/${output_name}${file_extension}."*; do
        if [[ -f "$file" ]]; then
            local new_name="$OUTPUT_DIR/${output_name}${file_extension}.$(printf "%03d" $chunk_num)"
            if [[ "$file" != "$new_name" ]]; then
                mv "$file" "$new_name"
            fi
            ((chunk_num++))
        fi
    done
}

# Function to verify the split archive
verify_archive() {
    local output_name=$1
    local source_dir=$2
    
    print_status $BLUE "Verifying split archive..."
    
    # Use gzip file extension
    local file_extension=".tar.gz"
    
    # Check if all parts exist
    local parts=("$OUTPUT_DIR/${output_name}${file_extension}."*)
    if [[ ! -f "${parts[0]}" ]]; then
        print_status $RED "Error: No split files found!"
        return 1
    fi
    
    local part_count=${#parts[@]}
    print_status $GREEN "Found $part_count part(s):"
    
    local total_size=0
    for part in "${parts[@]}"; do
        if [[ -f "$part" ]]; then
            local part_size=$(stat -c%s "$part" 2>/dev/null || echo "0")
            total_size=$((total_size + part_size))
            print_status $CYAN "  $(basename "$part"): $(format_bytes $part_size)"
        fi
    done
    
    print_status $GREEN "Total archive size: $(format_bytes $total_size)"
    
    # Test extraction to verify integrity
    print_status $YELLOW "Testing archive integrity..."
    local test_dir="/tmp/split_tar_test_$$"
    mkdir -p "$test_dir"
    
    if cat "$OUTPUT_DIR/${output_name}${file_extension}."* | tar -tzf - >/dev/null 2>&1; then
        print_status $GREEN "✓ Archive integrity verified successfully!"
        rm -rf "$test_dir"
        return 0
    else
        print_status $RED "✗ Archive integrity check failed!"
        rm -rf "$test_dir"
        return 1
    fi
}

# Function to show extraction instructions
show_extraction_instructions() {
    local output_name=$1
    
    # Use gzip file extension
    local file_extension=".tar.gz"
    
    print_status $BLUE "=== Extraction Instructions ==="
    echo ""
    print_status $CYAN "To extract the split archive:"
    echo "  cat $OUTPUT_DIR/${output_name}${file_extension}.* | tar -xzf -"
    echo ""
    print_status $CYAN "Or extract to a specific directory:"
    echo "  cat $OUTPUT_DIR/${output_name}${file_extension}.* | tar -xzf - -C /path/to/destination"
    echo ""
    print_status $CYAN "To verify before extracting:"
    echo "  cat $OUTPUT_DIR/${output_name}${file_extension}.* | tar -tzf -"
    echo ""
    print_status $CYAN "Archive location: $OUTPUT_DIR/"
    echo ""
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        show_usage
        exit 1
    fi
    
    local source_dir="$1"
    local output_name="${2:-$(basename "$source_dir")}"
    local chunk_size_gb="${3:-$DEFAULT_CHUNK_SIZE_GB}"
    
    # Validate chunk size
    if ! [[ "$chunk_size_gb" =~ ^[0-9]+\.?[0-9]*$ ]] || (( $(echo "$chunk_size_gb <= 0" | bc -l) )); then
        print_status $RED "Error: Chunk size must be a positive number."
        exit 1
    fi
    
    # Convert chunk size to bytes
    local chunk_size_bytes=$(echo "$chunk_size_gb * 1024 * 1024 * 1024" | bc)
    chunk_size_bytes=${chunk_size_bytes%.*}  # Remove decimal part
    
    # Check if source directory exists
    if ! check_directory "$source_dir"; then
        exit 1
    fi
    
    # Get directory size
    print_status $BLUE "Analyzing source directory..."
    local dir_size=$(get_directory_size "$source_dir")
    local dir_size_formatted=$(format_bytes $dir_size)
    
    print_status $CYAN "Directory size: $dir_size_formatted"
    
    # Calculate number of chunks needed
    local chunks_needed=$(calculate_chunks $dir_size $chunk_size_bytes)
    print_status $CYAN "Estimated chunks needed: $chunks_needed"
    
    # Confirm before proceeding
    echo ""
    print_status $YELLOW "About to create split archive:"
    print_status $CYAN "  Source: $source_dir"
    print_status $CYAN "  Output: $OUTPUT_DIR/${output_name}.tar.gz.*"
    print_status $CYAN "  Chunk size: $(format_bytes $chunk_size_bytes)"
    print_status $CYAN "  Estimated chunks: $chunks_needed"
    echo ""
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status $YELLOW "Operation cancelled."
        exit 0
    fi
    
    # Create the split archive
    if create_split_tar "$source_dir" "$output_name" "$chunk_size_bytes"; then
        print_status $GREEN "✓ Split archive created successfully!"
        
        # Verify the archive
        if verify_archive "$output_name" "$source_dir"; then
            print_status $GREEN "✓ Archive verification completed!"
            show_extraction_instructions "$output_name"
        else
            print_status $RED "✗ Archive verification failed!"
            exit 1
        fi
    else
        print_status $RED "✗ Failed to create split archive!"
        exit 1
    fi
}

# Check dependencies
if ! command -v bc >/dev/null 2>&1; then
    print_status $RED "Error: 'bc' calculator is required but not installed."
    print_status $YELLOW "Install with: sudo apt install bc (Ubuntu/Debian) or sudo pacman -S bc (Arch)"
    exit 1
fi

# Run main function
main "$@"
