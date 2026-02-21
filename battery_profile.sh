#!/bin/bash
# battery_profile.sh - Battery drain profiler
# Usage: battery_profile.sh start | stop
#
# start - snapshots current battery state to ~/.battery_profile.tmp
# stop  - computes drain summary and saves timestamped JSON to ~

TMP_FILE="$HOME/.battery_profile.tmp"
POWER_SUPPLY="/sys/class/power_supply"

read_sysfs() { cat "$1" 2>/dev/null || echo ""; }

detect_batteries() {
    ls "$POWER_SUPPLY" 2>/dev/null | grep -E "^BAT"
}

detect_ac() {
    ls "$POWER_SUPPLY" 2>/dev/null | grep -E "^AC|^ADP|^ACAD"
}

snapshot_battery() {
    local bat="$1"
    local p="$POWER_SUPPLY/$bat"
    local prefix="$2"

    echo "${prefix}_status=$(read_sysfs "$p/status")"
    echo "${prefix}_capacity=$(read_sysfs "$p/capacity")"
    echo "${prefix}_energy_now=$(read_sysfs "$p/energy_now")"
    echo "${prefix}_energy_full=$(read_sysfs "$p/energy_full")"
    echo "${prefix}_energy_full_design=$(read_sysfs "$p/energy_full_design")"
    echo "${prefix}_charge_now=$(read_sysfs "$p/charge_now")"
    echo "${prefix}_charge_full=$(read_sysfs "$p/charge_full")"
    echo "${prefix}_charge_full_design=$(read_sysfs "$p/charge_full_design")"
    echo "${prefix}_voltage_now=$(read_sysfs "$p/voltage_now")"
    echo "${prefix}_voltage_min_design=$(read_sysfs "$p/voltage_min_design")"
    echo "${prefix}_power_now=$(read_sysfs "$p/power_now")"
    echo "${prefix}_current_now=$(read_sysfs "$p/current_now")"
    echo "${prefix}_cycle_count=$(read_sysfs "$p/cycle_count")"
    echo "${prefix}_technology=$(read_sysfs "$p/technology")"
    echo "${prefix}_manufacturer=$(read_sysfs "$p/manufacturer")"
    echo "${prefix}_model_name=$(read_sysfs "$p/model_name")"
    echo "${prefix}_serial_number=$(read_sysfs "$p/serial_number")"
    echo "${prefix}_health=$(read_sysfs "$p/health")"
}

do_start() {
    local batteries
    batteries=$(detect_batteries)
    if [[ -z "$batteries" ]]; then
        echo "No batteries detected."
        exit 1
    fi

    {
        echo "start_epoch=$(date +%s)"
        echo "start_time=$(date -Iseconds)"
        echo "batteries=$batteries"

        for bat in $batteries; do
            snapshot_battery "$bat" "start_${bat}"
        done

        for ac in $(detect_ac); do
            echo "start_ac_${ac}=$(read_sysfs "$POWER_SUPPLY/$ac/online")"
        done
    } > "$TMP_FILE"

    echo "Battery profiling started at $(date '+%Y-%m-%d %H:%M:%S')"
    for bat in $batteries; do
        local cap
        cap=$(read_sysfs "$POWER_SUPPLY/$bat/capacity")
        local status
        status=$(read_sysfs "$POWER_SUPPLY/$bat/status")
        echo "  $bat: ${cap}% ($status)"
    done
    echo "Temp file: $TMP_FILE"
    echo "Run '$(basename "$0") stop' when done."
}

do_stop() {
    if [[ ! -f "$TMP_FILE" ]]; then
        echo "No profiling session found. Run '$(basename "$0") start' first."
        exit 1
    fi

    source "$TMP_FILE"

    local stop_epoch
    stop_epoch=$(date +%s)
    local stop_time
    stop_time=$(date -Iseconds)
    local duration_s=$(( stop_epoch - start_epoch ))
    local duration_m=$(( duration_s / 60 ))
    local duration_h=$(( duration_m / 60 ))
    local duration_rm=$(( duration_m % 60 ))

    # Take stop snapshots
    for bat in $batteries; do
        snapshot_battery "$bat" "stop_${bat}" >> "$TMP_FILE"
    done
    source "$TMP_FILE"

    local json_file="$HOME/battery_profile_$(date '+%Y%m%d_%H%M%S').json"

    # Build JSON
    local bat_json=""
    local first=true
    for bat in $batteries; do
        local s_cap_var="start_${bat}_capacity"
        local e_cap_var="stop_${bat}_capacity"
        local s_energy_var="start_${bat}_energy_now"
        local e_energy_var="stop_${bat}_energy_now"
        local s_charge_var="start_${bat}_charge_now"
        local e_charge_var="stop_${bat}_charge_now"
        local ef_var="stop_${bat}_energy_full"
        local efd_var="stop_${bat}_energy_full_design"
        local cf_var="stop_${bat}_charge_full"
        local cfd_var="stop_${bat}_charge_full_design"
        local cycle_var="stop_${bat}_cycle_count"
        local tech_var="stop_${bat}_technology"
        local mfr_var="stop_${bat}_manufacturer"
        local model_var="stop_${bat}_model_name"
        local serial_var="stop_${bat}_serial_number"
        local health_var="stop_${bat}_health"
        local s_status_var="start_${bat}_status"
        local e_status_var="stop_${bat}_status"
        local s_power_var="start_${bat}_power_now"
        local e_power_var="stop_${bat}_power_now"
        local s_volt_var="start_${bat}_voltage_now"
        local e_volt_var="stop_${bat}_voltage_now"
        local vmin_var="stop_${bat}_voltage_min_design"

        local s_cap="${!s_cap_var}"
        local e_cap="${!e_cap_var}"
        local cap_drain=$(( s_cap - e_cap ))

        local s_current_var="start_${bat}_current_now"
        local e_current_var="stop_${bat}_current_now"

        # Energy consumed (Wh) - prefer energy_now, fall back to charge*voltage
        local energy_consumed_wh="null"
        local s_energy_wh="null"
        local e_energy_wh="null"
        local energy_full_wh="null"
        local energy_full_design_wh="null"
        local wear_pct="null"
        local charge_full_mah="null"
        local charge_full_design_mah="null"

        if [[ -n "${!s_energy_var}" && -n "${!e_energy_var}" && "${!s_energy_var}" -gt 0 ]] 2>/dev/null; then
            # Direct energy reporting (Wh-based systems)
            energy_consumed_wh=$(awk "BEGIN {printf \"%.2f\", (${!s_energy_var} - ${!e_energy_var}) / 1000000}")
            s_energy_wh=$(awk "BEGIN {printf \"%.2f\", ${!s_energy_var} / 1000000}")
            e_energy_wh=$(awk "BEGIN {printf \"%.2f\", ${!e_energy_var} / 1000000}")
            if [[ -n "${!ef_var}" && "${!ef_var}" -gt 0 ]] 2>/dev/null; then
                energy_full_wh=$(awk "BEGIN {printf \"%.2f\", ${!ef_var} / 1000000}")
            fi
            if [[ -n "${!efd_var}" && "${!efd_var}" -gt 0 ]] 2>/dev/null; then
                energy_full_design_wh=$(awk "BEGIN {printf \"%.2f\", ${!efd_var} / 1000000}")
            fi
            if [[ -n "${!ef_var}" && -n "${!efd_var}" && "${!efd_var}" -gt 0 ]] 2>/dev/null; then
                wear_pct=$(awk "BEGIN {printf \"%.1f\", (${!ef_var} * 100.0) / ${!efd_var}}")
            fi
        elif [[ -n "${!cf_var}" && "${!cf_var}" -gt 0 ]] 2>/dev/null; then
            # Charge-based systems: compute Wh from charge (µAh) * voltage (µV)
            charge_full_mah=$(awk "BEGIN {printf \"%.0f\", ${!cf_var} / 1000}")
            # Use nominal voltage (average of start/stop) for Wh conversion
            local nom_volt="${!s_volt_var}"
            [[ -z "$nom_volt" || "$nom_volt" == "0" ]] && nom_volt="${!e_volt_var}"
            if [[ -n "$nom_volt" && "$nom_volt" -gt 0 ]] 2>/dev/null; then
                energy_full_wh=$(awk "BEGIN {printf \"%.2f\", (${!cf_var} * $nom_volt) / 1000000000000.0}")
                if [[ -n "${!s_charge_var}" && -n "${!e_charge_var}" ]]; then
                    local avg_volt=$(awk "BEGIN {print (${!s_volt_var} + ${!e_volt_var}) / 2}")
                    s_energy_wh=$(awk "BEGIN {printf \"%.2f\", (${!s_charge_var} * ${!s_volt_var}) / 1000000000000.0}")
                    e_energy_wh=$(awk "BEGIN {printf \"%.2f\", (${!e_charge_var} * ${!e_volt_var}) / 1000000000000.0}")
                    energy_consumed_wh=$(awk "BEGIN {printf \"%.2f\", $s_energy_wh - $e_energy_wh}")
                fi
            fi
            if [[ -n "${!cfd_var}" && "${!cfd_var}" -gt 0 ]] 2>/dev/null; then
                charge_full_design_mah=$(awk "BEGIN {printf \"%.0f\", ${!cfd_var} / 1000}")
                wear_pct=$(awk "BEGIN {printf \"%.1f\", (${!cf_var} * 100.0) / ${!cfd_var}}")
                if [[ -n "$nom_volt" && "$nom_volt" -gt 0 ]] 2>/dev/null; then
                    energy_full_design_wh=$(awk "BEGIN {printf \"%.2f\", (${!cfd_var} * $nom_volt) / 1000000000000.0}")
                fi
            fi
        fi

        # Average power draw
        local avg_power="null"
        if [[ "$energy_consumed_wh" != "null" && "$duration_s" -gt 0 ]]; then
            avg_power=$(awk "BEGIN {printf \"%.2f\", $energy_consumed_wh / ($duration_s / 3600.0)}")
        fi

        # Instantaneous power: prefer power_now, fall back to current*voltage
        local s_watts="null" e_watts="null"
        if [[ -n "${!s_power_var}" && "${!s_power_var}" -gt 0 ]] 2>/dev/null; then
            s_watts=$(awk "BEGIN {printf \"%.2f\", ${!s_power_var} / 1000000}")
        elif [[ -n "${!s_current_var}" && "${!s_current_var}" -gt 0 && -n "${!s_volt_var}" && "${!s_volt_var}" -gt 0 ]] 2>/dev/null; then
            s_watts=$(awk "BEGIN {printf \"%.2f\", (${!s_current_var} * ${!s_volt_var}) / 1000000000000.0}")
        fi
        if [[ -n "${!e_power_var}" && "${!e_power_var}" -gt 0 ]] 2>/dev/null; then
            e_watts=$(awk "BEGIN {printf \"%.2f\", ${!e_power_var} / 1000000}")
        elif [[ -n "${!e_current_var}" && "${!e_current_var}" -gt 0 && -n "${!e_volt_var}" && "${!e_volt_var}" -gt 0 ]] 2>/dev/null; then
            e_watts=$(awk "BEGIN {printf \"%.2f\", (${!e_current_var} * ${!e_volt_var}) / 1000000000000.0}")
        fi

        # Voltages
        local s_volts="null" e_volts="null" min_volts="null"
        if [[ -n "${!s_volt_var}" && "${!s_volt_var}" -gt 0 ]] 2>/dev/null; then
            s_volts=$(awk "BEGIN {printf \"%.2f\", ${!s_volt_var} / 1000000}")
        fi
        if [[ -n "${!e_volt_var}" && "${!e_volt_var}" -gt 0 ]] 2>/dev/null; then
            e_volts=$(awk "BEGIN {printf \"%.2f\", ${!e_volt_var} / 1000000}")
        fi
        if [[ -n "${!vmin_var}" && "${!vmin_var}" -gt 0 ]] 2>/dev/null; then
            min_volts=$(awk "BEGIN {printf \"%.2f\", ${!vmin_var} / 1000000}")
        fi

        # Cycle count
        local cycles="${!cycle_var}"
        [[ -z "$cycles" || "$cycles" == "0" ]] && cycles="null" || cycles="$cycles"

        # Quote string values, leave null/numbers unquoted, empty -> null
        q() { [[ -z "$1" ]] && echo "null" && return; [[ "$1" == "null" || "$1" =~ ^-?[0-9] ]] && echo "$1" || echo "\"$1\""; }

        $first || bat_json+=","
        first=false
        bat_json+="
    \"$bat\": {
      \"identity\": {
        \"manufacturer\": $(q "${!mfr_var}"),
        \"model\": $(q "${!model_var}"),
        \"serial\": $(q "${!serial_var}"),
        \"technology\": $(q "${!tech_var}")
      },
      \"health\": {
        \"status\": $(q "${!health_var}"),
        \"cycle_count\": $(q "$cycles"),
        \"capacity_full_wh\": $(q "$energy_full_wh"),
        \"capacity_design_wh\": $(q "$energy_full_design_wh"),
        \"capacity_full_mah\": $(q "$charge_full_mah"),
        \"capacity_design_mah\": $(q "$charge_full_design_mah"),
        \"capacity_remaining_pct\": $(q "$wear_pct")
      },
      \"profile\": {
        \"start_pct\": $s_cap,
        \"stop_pct\": $e_cap,
        \"drain_pct\": $cap_drain,
        \"start_status\": \"${!s_status_var}\",
        \"stop_status\": \"${!e_status_var}\",
        \"energy_start_wh\": $(q "$s_energy_wh"),
        \"energy_stop_wh\": $(q "$e_energy_wh"),
        \"energy_consumed_wh\": $(q "$energy_consumed_wh"),
        \"avg_power_w\": $(q "$avg_power"),
        \"start_power_w\": $(q "$s_watts"),
        \"stop_power_w\": $(q "$e_watts"),
        \"start_voltage_v\": $(q "$s_volts"),
        \"stop_voltage_v\": $(q "$e_volts"),
        \"min_design_voltage_v\": $(q "$min_volts")
      }
    }"
    done

    # TLP charge thresholds if available
    local tlp_json=""
    if command -v tlp-stat &>/dev/null; then
        local tlp_out
        tlp_out=$(tlp-stat -b 2>/dev/null || sudo tlp-stat -b 2>/dev/null)
        if [[ -n "$tlp_out" ]]; then
            local tlp_thresholds=""
            local tfirst=true
            for bat in $batteries; do
                local thresh_start thresh_stop
                thresh_start=$(echo "$tlp_out" | grep -A5 "$bat" | grep -i "charge_start\|start_charge" | grep -oP '[0-9]+' | tail -1)
                thresh_stop=$(echo "$tlp_out" | grep -A5 "$bat" | grep -i "charge_stop\|stop_charge" | grep -oP '[0-9]+' | tail -1)
                if [[ -n "$thresh_start" || -n "$thresh_stop" ]]; then
                    $tfirst || tlp_thresholds+=","
                    tfirst=false
                    tlp_thresholds+="\"$bat\": {\"start_threshold\": ${thresh_start:-null}, \"stop_threshold\": ${thresh_stop:-null}}"
                fi
            done
            [[ -n "$tlp_thresholds" ]] && tlp_json=",
  \"tlp_thresholds\": {$tlp_thresholds}"
        fi
    fi

    # AC status
    local ac_json=""
    for ac in $(detect_ac); do
        local s_ac_var="start_ac_${ac}"
        local e_ac=$(read_sysfs "$POWER_SUPPLY/$ac/online")
        local s_ac="${!s_ac_var}"
        ac_json+="
    \"$ac\": {\"start_connected\": $([ "$s_ac" = "1" ] && echo true || echo false), \"stop_connected\": $([ "$e_ac" = "1" ] && echo true || echo false)},"
    done
    ac_json="${ac_json%,}"

    # Write JSON
    cat > "$json_file" << ENDJSON
{
  "profile": {
    "start_time": "$start_time",
    "stop_time": "$stop_time",
    "duration_seconds": $duration_s,
    "duration_human": "${duration_h}h ${duration_rm}m"
  },
  "batteries": {$bat_json
  },
  "ac_adapters": {$ac_json
  }${tlp_json}
}
ENDJSON

    # Print summary
    echo ""
    echo "=== Battery Profile Summary ==="
    echo "Duration: ${duration_h}h ${duration_rm}m (${duration_s}s)"
    echo ""
    for bat in $batteries; do
        local s_cap_var="start_${bat}_capacity"
        local e_cap_var="stop_${bat}_capacity"
        local s_status_var="start_${bat}_status"
        local e_status_var="stop_${bat}_status"
        local mfr_var="stop_${bat}_manufacturer"
        local model_var="stop_${bat}_model_name"
        local health_var="stop_${bat}_health"
        local cycle_var="stop_${bat}_cycle_count"
        local ef_var="stop_${bat}_energy_full"
        local efd_var="stop_${bat}_energy_full_design"

        local cf_var="stop_${bat}_charge_full"
        local cfd_var="stop_${bat}_charge_full_design"
        local s_volt_var="start_${bat}_voltage_now"

        echo "--- $bat (${!mfr_var} ${!model_var}) ---"
        echo "  Drain: ${!s_cap_var}% -> ${!e_cap_var}% ($(( ${!s_cap_var} - ${!e_cap_var} ))% used)"

        if [[ -n "${!ef_var}" && -n "${!efd_var}" && "${!efd_var}" -gt 0 ]] 2>/dev/null; then
            local full_wh=$(awk "BEGIN {printf \"%.1f\", ${!ef_var} / 1000000}")
            local design_wh=$(awk "BEGIN {printf \"%.1f\", ${!efd_var} / 1000000}")
            local wear=$(awk "BEGIN {printf \"%.1f\", (${!ef_var} * 100.0) / ${!efd_var}}")
            echo "  Health: ${!health_var:-N/A} | ${full_wh}/${design_wh} Wh (${wear}% of design)"
        elif [[ -n "${!cf_var}" && "${!cf_var}" -gt 0 ]] 2>/dev/null; then
            local full_mah=$(awk "BEGIN {printf \"%.0f\", ${!cf_var} / 1000}")
            local nom_volt="${!s_volt_var}"
            local full_wh=""
            local design_wh=""
            if [[ -n "$nom_volt" && "$nom_volt" -gt 0 ]] 2>/dev/null; then
                full_wh=$(awk "BEGIN {printf \"%.1f\", (${!cf_var} * $nom_volt) / 1000000000000.0}")
            fi
            if [[ -n "${!cfd_var}" && "${!cfd_var}" -gt 0 ]] 2>/dev/null; then
                local design_mah=$(awk "BEGIN {printf \"%.0f\", ${!cfd_var} / 1000}")
                local wear=$(awk "BEGIN {printf \"%.1f\", (${!cf_var} * 100.0) / ${!cfd_var}}")
                if [[ -n "$nom_volt" && "$nom_volt" -gt 0 ]] 2>/dev/null; then
                    design_wh=$(awk "BEGIN {printf \"%.1f\", (${!cfd_var} * $nom_volt) / 1000000000000.0}")
                    echo "  Health: ${!health_var:-N/A} | ${full_wh}/${design_wh} Wh [${full_mah}/${design_mah} mAh] (${wear}% of design)"
                else
                    echo "  Health: ${!health_var:-N/A} | ${full_mah}/${design_mah} mAh (${wear}% of design)"
                fi
            else
                echo "  Health: ${!health_var:-N/A} | ${full_mah} mAh"
            fi
        fi

        local cycles="${!cycle_var}"
        [[ -n "$cycles" && "$cycles" != "0" ]] && echo "  Cycles: $cycles"
        echo ""
    done

    echo "Saved: $json_file"
    rm -f "$TMP_FILE"
}

case "${1:-}" in
    start) do_start ;;
    stop)  do_stop ;;
    *)
        echo "Usage: $(basename "$0") {start|stop}"
        echo "  start  Snapshot battery state and begin profiling"
        echo "  stop   End profiling, show summary, save JSON to ~"
        exit 1
        ;;
esac
