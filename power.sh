#!/bin/bash

# Reads total system power draw from ACPI power supply
# Works for most systems via /sys/class/power_supply

get_watts() {
    # Try battery discharge rate first (laptops)
    for bat in /sys/class/power_supply/BAT*; do
        [ -d "$bat" ] || continue

        if [ -f "$bat/power_now" ]; then
            microwatts=$(cat "$bat/power_now")
            echo "scale=1; $microwatts / 1000000" | bc
            return
        fi

        # Fallback: voltage * current
        if [ -f "$bat/voltage_now" ] && [ -f "$bat/current_now" ]; then
            uv=$(cat "$bat/voltage_now")
            ua=$(cat "$bat/current_now")
            echo "scale=1; ($uv * $ua) / 1000000000000" | bc
            return
        fi
    done

    # Desktop/AC: try RAPL (Intel/AMD energy reporting)
    rapl_path="/sys/class/powercap/intel-rapl:0/energy_uj"
    if [ -f "$rapl_path" ]; then
        e1=$(cat "$rapl_path")
        sleep 1
        e2=$(cat "$rapl_path")
        uj_diff=$((e2 - e1))
        echo "scale=1; $uj_diff / 1000000" | bc
        return
    fi

    echo "N/A"
}

watts=$(get_watts)
echo "{\"text\": \"⚡︎ ${watts}W\", \"tooltip\": \"System power draw: ${watts} watts\"}"
