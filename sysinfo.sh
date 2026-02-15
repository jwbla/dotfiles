#!/bin/bash

# System Information Script
# Displays comprehensive system hardware and software information
# Usage: ./sysinfo.sh [--json] [--minimal]

# Catppuccin Mocha Colors
RED='\033[38;2;243;139;168m'      # @red
GREEN='\033[38;2;166;227;161m'    # @green
YELLOW='\033[38;2;249;226;175m'   # @yellow
BLUE='\033[38;2;137;180;250m'     # @blue
PURPLE='\033[38;2;203;166;247m'   # @mauve
CYAN='\033[38;2;148;226;213m'     # @teal
PEACH='\033[38;2;250;179;135m'    # @peach
PINK='\033[38;2;245;194;231m'     # @pink
SKY='\033[38;2;137;220;235m'      # @sky
LAVENDER='\033[38;2;180;190;254m' # @lavender
TEXT='\033[38;2;205;214;244m'     # @text
SUBTEXT='\033[38;2;186;194;222m'  # @subtext1
OVERLAY='\033[38;2;127;132;156m'  # @overlay1
SURFACE='\033[38;2;69;71;90m'     # @surface1
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
JSON_OUTPUT=false
MINIMAL_OUTPUT=false

# Function to print colored output
print_header() {
    local color=$1
    local title=$2
    echo -e "\n${color}${BOLD}=== $title ===${NC}"
}

print_info() {
    local label=$1
    local value=$2
    local color=${3:-$SKY}
    echo -e "${color}${label}:${NC} $value"
}

print_section() {
    local title=$1
    echo -e "\n${PURPLE}${BOLD}▸ $title${NC}"
}

# Function to get CPU information
get_cpu_info() {
    if [[ -f /proc/cpuinfo ]]; then
        local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[ \t]*//')
        local cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
        local cpu_cores_physical=$(grep "cpu cores" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[ \t]*//')
        local cpu_threads=$(grep "siblings" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[ \t]*//')
        local cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[ \t]*//')
        local cpu_cache=$(grep "cache size" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[ \t]*//')
        
        echo "$cpu_model"
        echo "Cores: $cpu_cores_physical physical, $cpu_cores logical"
        echo "Threads: $cpu_threads"
        echo "Frequency: ${cpu_freq} MHz"
        echo "Cache: $cpu_cache"
    else
        echo "CPU information not available"
    fi
}

# Function to get memory information
get_memory_info() {
    if [[ -f /proc/meminfo ]]; then
        local total_mem=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        local total_mem_gb=$((total_mem / 1024 / 1024))
        local available_mem=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
        local available_mem_gb=$((available_mem / 1024 / 1024))
        local used_mem_gb=$((total_mem_gb - available_mem_gb))
        
        echo "Total RAM: ${total_mem_gb}GB"
        echo "Used RAM: ${used_mem_gb}GB"
        echo "Available RAM: ${available_mem_gb}GB"
        echo "Usage: $(( (used_mem_gb * 100) / total_mem_gb ))%"
    else
        echo "Memory information not available"
    fi
}

# Function to get disk information
get_disk_info() {
    echo "Disk Usage:"
    df -h | grep -E '^/dev/' | while read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local size=$(echo "$line" | awk '{print $2}')
        local used=$(echo "$line" | awk '{print $3}')
        local available=$(echo "$line" | awk '{print $4}')
        local usage=$(echo "$line" | awk '{print $5}')
        local mount=$(echo "$line" | awk '{print $6}')
        
        echo "  $device: $size total, $used used, $available available ($usage) -> $mount"
    done
    
    echo ""
    echo "Physical Disks:"
    if command -v lsblk >/dev/null 2>&1; then
        lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -v "loop" | while read -r line; do
            if [[ ! "$line" =~ ^NAME ]]; then
                echo "  $line"
            fi
        done
    else
        echo "  lsblk not available"
    fi
}

# Function to get laptop/desktop model information
get_system_model() {
    local system_info=""
    
    # Try to get system model from DMI
    if [[ -f /sys/devices/virtual/dmi/id/product_name ]]; then
        local product_name=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)
        local product_version=$(cat /sys/devices/virtual/dmi/id/product_version 2>/dev/null)
        local product_serial=$(cat /sys/devices/virtual/dmi/id/product_serial 2>/dev/null)
        
        if [[ -n "$product_name" && "$product_name" != "To be filled by O.E.M." ]]; then
            system_info="$product_name"
            if [[ -n "$product_version" && "$product_version" != "To be filled by O.E.M." ]]; then
                system_info="$system_info ($product_version)"
            fi
        fi
    fi
    
    # Try to get manufacturer
    if [[ -f /sys/devices/virtual/dmi/id/sys_vendor ]]; then
        local manufacturer=$(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null)
        if [[ -n "$manufacturer" && "$manufacturer" != "To be filled by O.E.M." ]]; then
            if [[ -z "$system_info" ]]; then
                system_info="$manufacturer"
            else
                system_info="$manufacturer $system_info"
            fi
        fi
    fi
    
    # Fallback to hostname if no model info
    if [[ -z "$system_info" ]]; then
        system_info="$(hostname) (model unknown)"
    fi
    
    echo "$system_info"
}

# Function to get GPU information
get_gpu_info() {
    local gpu_info=""
    
    # Check for NVIDIA
    if command -v nvidia-smi >/dev/null 2>&1; then
        local nvidia_gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [[ -n "$nvidia_gpu" ]]; then
            gpu_info="$nvidia_gpu (NVIDIA)"
        fi
    fi
    
    # Check for AMD
    if [[ -z "$gpu_info" ]] && command -v lspci >/dev/null 2>&1; then
        local amd_gpu=$(lspci | grep -i "vga\|3d\|display" | grep -i amd | head -1 | sed 's/.*: //')
        if [[ -n "$amd_gpu" ]]; then
            gpu_info="$amd_gpu (AMD)"
        fi
    fi
    
    # Check for Intel
    if [[ -z "$gpu_info" ]] && command -v lspci >/dev/null 2>&1; then
        local intel_gpu=$(lspci | grep -i "vga\|3d\|display" | grep -i intel | head -1 | sed 's/.*: //')
        if [[ -n "$intel_gpu" ]]; then
            gpu_info="$intel_gpu (Intel)"
        fi
    fi
    
    # Generic fallback
    if [[ -z "$gpu_info" ]] && command -v lspci >/dev/null 2>&1; then
        gpu_info=$(lspci | grep -i "vga\|3d\|display" | head -1 | sed 's/.*: //')
    fi
    
    if [[ -n "$gpu_info" ]]; then
        echo "$gpu_info"
    else
        echo "GPU information not available"
    fi
}

# Function to get network information
get_network_info() {
    echo "Network Interfaces:"
    ip -o link show | grep -v "lo:" | while read -r line; do
        local interface=$(echo "$line" | awk '{print $2}' | sed 's/://')
        local state=$(echo "$line" | awk '{print $9}')
        echo "  $interface: $state"
    done
    
    echo ""
    echo "Active Connections:"
    if command -v ss >/dev/null 2>&1; then
        ss -tuln | grep LISTEN | head -5 | while read -r line; do
            local protocol=$(echo "$line" | awk '{print $1}')
            local local_addr=$(echo "$line" | awk '{print $4}')
            echo "  $protocol: $local_addr"
        done
    else
        echo "  ss command not available"
    fi
}

# Function to get OS information
get_os_info() {
    local os_name=""
    local os_version=""
    local kernel=""
    
    # Get OS name and version
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        os_name="$NAME"
        os_version="$VERSION"
    elif [[ -f /etc/redhat-release ]]; then
        os_name=$(cat /etc/redhat-release)
    elif [[ -f /etc/debian_version ]]; then
        os_name="Debian $(cat /etc/debian_version)"
    else
        os_name="Unknown"
    fi
    
    # Get kernel version
    kernel=$(uname -r)
    
    echo "OS: $os_name"
    echo "Version: $os_version"
    echo "Kernel: $kernel"
    echo "Architecture: $(uname -m)"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime | sed 's/.*up //' | sed 's/,.*//')"
}

# Function to get temperature information
get_temperature_info() {
    local temp_info=""
    
    # Check for thermal zones
    if [[ -d /sys/class/thermal ]]; then
        local thermal_zones=$(ls /sys/class/thermal/ | grep thermal_zone)
        if [[ -n "$thermal_zones" ]]; then
            echo "Temperatures:"
            for zone in $thermal_zones; do
                local temp=$(cat /sys/class/thermal/$zone/temp 2>/dev/null)
                local type=$(cat /sys/class/thermal/$zone/type 2>/dev/null)
                if [[ -n "$temp" && "$temp" != "0" ]]; then
                    local temp_c=$((temp / 1000))
                    echo "  $type: ${temp_c}°C"
                fi
            done
        fi
    fi
    
    # Check for sensors if available
    if command -v sensors >/dev/null 2>&1; then
        echo ""
        echo "Hardware Sensors:"
        sensors 2>/dev/null | grep -E "Core|Package|CPU|GPU" | head -5
    fi
}

# Function to get battery information
get_battery_info() {
    if [[ -d /sys/class/power_supply ]]; then
        local batteries=$(ls /sys/class/power_supply/ | grep BAT)
        if [[ -n "$batteries" ]]; then
            echo "Battery Information:"
            for battery in $batteries; do
                local bat="/sys/class/power_supply/$battery"
                local capacity=$(cat "$bat/capacity" 2>/dev/null)
                local status=$(cat "$bat/status" 2>/dev/null)
                local health=$(cat "$bat/health" 2>/dev/null)
                local technology=$(cat "$bat/technology" 2>/dev/null)
                local cycle_count=$(cat "$bat/cycle_count" 2>/dev/null)
                local voltage_now=$(cat "$bat/voltage_now" 2>/dev/null)
                local voltage_min=$(cat "$bat/voltage_min_design" 2>/dev/null)
                local power_now=$(cat "$bat/power_now" 2>/dev/null)
                local current_now=$(cat "$bat/current_now" 2>/dev/null)
                local energy_now=$(cat "$bat/energy_now" 2>/dev/null)
                local energy_full=$(cat "$bat/energy_full" 2>/dev/null)
                local energy_full_design=$(cat "$bat/energy_full_design" 2>/dev/null)
                local charge_now=$(cat "$bat/charge_now" 2>/dev/null)
                local charge_full=$(cat "$bat/charge_full" 2>/dev/null)
                local charge_full_design=$(cat "$bat/charge_full_design" 2>/dev/null)

                if [[ -n "$capacity" ]]; then
                    echo "  $battery: ${capacity}% ($status)"

                    if [[ -n "$technology" ]]; then
                        echo "    Technology: $technology"
                    fi

                    if [[ -n "$health" ]]; then
                        echo "    Health: $health"
                    fi

                    if [[ -n "$cycle_count" && "$cycle_count" != "0" ]]; then
                        echo "    Cycle Count: $cycle_count"
                    fi

                    # Capacity wear level (energy-based or charge-based)
                    if [[ -n "$energy_full" && -n "$energy_full_design" && "$energy_full_design" -gt 0 ]]; then
                        local wear=$(( (energy_full * 100) / energy_full_design ))
                        local full_wh=$(awk "BEGIN {printf \"%.1f\", $energy_full / 1000000}")
                        local design_wh=$(awk "BEGIN {printf \"%.1f\", $energy_full_design / 1000000}")
                        echo "    Capacity: ${full_wh} Wh / ${design_wh} Wh design (${wear}% remaining)"
                    elif [[ -n "$charge_full" && -n "$charge_full_design" && "$charge_full_design" -gt 0 ]]; then
                        local wear=$(( (charge_full * 100) / charge_full_design ))
                        local full_mah=$(( charge_full / 1000 ))
                        local design_mah=$(( charge_full_design / 1000 ))
                        echo "    Capacity: ${full_mah} mAh / ${design_mah} mAh design (${wear}% remaining)"
                    fi

                    # Current energy level
                    if [[ -n "$energy_now" && -n "$energy_full" ]]; then
                        local energy_wh=$(awk "BEGIN {printf \"%.1f\", $energy_now / 1000000}")
                        local full_wh=$(awk "BEGIN {printf \"%.1f\", $energy_full / 1000000}")
                        echo "    Energy: ${energy_wh} / ${full_wh} Wh"
                    fi

                    # Voltage
                    if [[ -n "$voltage_now" ]]; then
                        local volts=$(awk "BEGIN {printf \"%.2f\", $voltage_now / 1000000}")
                        local volt_str="Voltage: ${volts}V"
                        if [[ -n "$voltage_min" ]]; then
                            local min_volts=$(awk "BEGIN {printf \"%.2f\", $voltage_min / 1000000}")
                            volt_str="$volt_str (min design: ${min_volts}V)"
                        fi
                        echo "    $volt_str"
                    fi

                    # Power draw / charge rate
                    if [[ -n "$power_now" && "$power_now" -gt 0 ]]; then
                        local watts=$(awk "BEGIN {printf \"%.1f\", $power_now / 1000000}")
                        if [[ "$status" == "Discharging" ]]; then
                            echo "    Power Draw: ${watts}W"
                        else
                            echo "    Charge Rate: ${watts}W"
                        fi
                    elif [[ -n "$current_now" && -n "$voltage_now" && "$current_now" -gt 0 ]]; then
                        local watts=$(awk "BEGIN {printf \"%.1f\", ($current_now * $voltage_now) / 1000000000000.0}")
                        if [[ "$status" == "Discharging" ]]; then
                            echo "    Power Draw: ${watts}W"
                        else
                            echo "    Charge Rate: ${watts}W"
                        fi
                    fi

                    # Time estimate
                    if [[ "$status" == "Discharging" && -n "$energy_now" && -n "$power_now" && "$power_now" -gt 0 ]]; then
                        local minutes=$(( (energy_now * 60) / power_now ))
                        local hours=$(( minutes / 60 ))
                        local mins=$(( minutes % 60 ))
                        echo "    Time Remaining: ~${hours}h ${mins}m"
                    elif [[ "$status" == "Charging" && -n "$energy_now" && -n "$energy_full" && -n "$power_now" && "$power_now" -gt 0 ]]; then
                        local remaining=$(( energy_full - energy_now ))
                        local minutes=$(( (remaining * 60) / power_now ))
                        local hours=$(( minutes / 60 ))
                        local mins=$(( minutes % 60 ))
                        echo "    Time to Full: ~${hours}h ${mins}m"
                    fi
                fi
            done
        fi

        # AC adapter status
        local ac_adapters=$(ls /sys/class/power_supply/ | grep -E "^AC|^ADP|^ACAD")
        if [[ -n "$ac_adapters" ]]; then
            for ac in $ac_adapters; do
                local online=$(cat /sys/class/power_supply/$ac/online 2>/dev/null)
                if [[ "$online" == "1" ]]; then
                    echo "  AC Adapter: Connected"
                else
                    echo "  AC Adapter: Disconnected"
                fi
            done
        fi
    fi
}

# Function to display system information
display_system_info() {
    clear
    echo -e "${TEXT}${BOLD}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${TEXT}${BOLD}║                             SYSTEM INFORMATION                               ║${NC}"
    echo -e "${TEXT}${BOLD}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    # System Model
    print_section "System Model"
    get_system_model | while read -r line; do
        print_info "Model" "$line"
    done
    
    # Operating System
    print_section "Operating System"
    get_os_info | while read -r line; do
        local label=$(echo "$line" | cut -d: -f1)
        local value=$(echo "$line" | cut -d: -f2- | sed 's/^[ \t]*//')
        print_info "$label" "$value"
    done
    
    # CPU Information
    print_section "Processor"
    get_cpu_info | while read -r line; do
        if [[ "$line" =~ ^[A-Za-z].*: ]]; then
            local label=$(echo "$line" | cut -d: -f1)
            local value=$(echo "$line" | cut -d: -f2- | sed 's/^[ \t]*//')
            print_info "$label" "$value"
        else
            print_info "Model" "$line"
        fi
    done
    
    # Memory Information
    print_section "Memory"
    get_memory_info | while read -r line; do
        local label=$(echo "$line" | cut -d: -f1)
        local value=$(echo "$line" | cut -d: -f2- | sed 's/^[ \t]*//')
        print_info "$label" "$value"
    done
    
    # GPU Information
    print_section "Graphics"
    print_info "GPU" "$(get_gpu_info)"
    
    # Disk Information
    print_section "Storage"
    get_disk_info | while read -r line; do
        if [[ "$line" =~ ^[A-Za-z].*: ]]; then
            local label=$(echo "$line" | cut -d: -f1)
            local value=$(echo "$line" | cut -d: -f2- | sed 's/^[ \t]*//')
            print_info "$label" "$value"
        else
            echo "  $line"
        fi
    done
    
    # Network Information
    print_section "Network"
    get_network_info | while read -r line; do
        if [[ "$line" =~ ^[A-Za-z].*: ]]; then
            local label=$(echo "$line" | cut -d: -f1)
            local value=$(echo "$line" | cut -d: -f2- | sed 's/^[ \t]*//')
            print_info "$label" "$value"
        else
            echo "  $line"
        fi
    done
    
    # Temperature Information
    print_section "Temperature"
    get_temperature_info | while read -r line; do
        if [[ "$line" =~ ^[A-Za-z].*: ]]; then
            local label=$(echo "$line" | cut -d: -f1)
            local value=$(echo "$line" | cut -d: -f2- | sed 's/^[ \t]*//')
            print_info "$label" "$value"
        else
            echo "  $line"
        fi
    done
    
    # Battery Information
    print_section "Power"
    get_battery_info | while read -r line; do
        if [[ "$line" =~ ^[A-Za-z].*: ]]; then
            local label=$(echo "$line" | cut -d: -f1)
            local value=$(echo "$line" | cut -d: -f2- | sed 's/^[ \t]*//')
            print_info "$label" "$value"
        else
            echo "  $line"
        fi
    done
    
    echo -e "\n${GREEN}${BOLD}System information gathered successfully!${NC}"
}

# Function to display minimal information
display_minimal_info() {
    echo "System: $(get_system_model)"
    echo "OS: $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo 'Unknown')"
    echo "Kernel: $(uname -r)"
    echo "CPU: $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[ \t]*//')"
    echo "RAM: $(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024) "GB"}')"
    echo "GPU: $(get_gpu_info)"
}

# Function to display JSON output
display_json_info() {
    echo "{"
    echo "  \"system\": {"
    echo "    \"model\": \"$(get_system_model)\","
    echo "    \"os\": \"$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo 'Unknown')\","
    echo "    \"kernel\": \"$(uname -r)\","
    echo "    \"architecture\": \"$(uname -m)\""
    echo "  },"
    echo "  \"cpu\": {"
    echo "    \"model\": \"$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[ \t]*//')\","
    echo "    \"cores\": $(grep -c "^processor" /proc/cpuinfo),"
    echo "    \"physical_cores\": $(grep "cpu cores" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[ \t]*//')"
    echo "  },"
    echo "  \"memory\": {"
    echo "    \"total_gb\": $(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)}'),"
    echo "    \"available_gb\": $(grep MemAvailable /proc/meminfo | awk '{print int($2/1024/1024)}')"
    echo "  },"
    echo "  \"gpu\": \"$(get_gpu_info)\""
    echo "}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [--json] [--minimal] [--help]"
    echo ""
    echo "Options:"
    echo "  --json     Output in JSON format"
    echo "  --minimal  Show only essential information"
    echo "  --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Full system information"
    echo "  $0 --minimal    # Essential info only"
    echo "  $0 --json       # JSON output"
}

# Main function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --minimal)
                MINIMAL_OUTPUT=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Display appropriate output
    if [[ "$JSON_OUTPUT" == true ]]; then
        display_json_info
    elif [[ "$MINIMAL_OUTPUT" == true ]]; then
        display_minimal_info
    else
        display_system_info
    fi
}

# Run main function
main "$@"
