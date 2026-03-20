##!/bin/bash
#
## Reads total system power draw from ACPI power supply
## Works for most systems via /sys/class/power_supply
#
#get_watts() {
#    # Try battery discharge rate first (laptops)
#    for bat in /sys/class/power_supply/BAT*; do
#        [ -d "$bat" ] || continue
#
#        if [ -f "$bat/power_now" ]; then
#            microwatts=$(cat "$bat/power_now")
#            echo "scale=1; $microwatts / 1000000" | bc
#            return
#        fi
#
#        # Fallback: voltage * current
#        if [ -f "$bat/voltage_now" ] && [ -f "$bat/current_now" ]; then
#            uv=$(cat "$bat/voltage_now")
#            ua=$(cat "$bat/current_now")
#            echo "scale=1; ($uv * $ua) / 1000000000000" | bc
#            return
#        fi
#    done
#
#    # Desktop/AC: try RAPL (Intel/AMD energy reporting)
#    rapl_path="/sys/class/powercap/intel-rapl:0/energy_uj"
#    if [ -f "$rapl_path" ]; then
#        e1=$(cat "$rapl_path")
#        sleep 1
#        e2=$(cat "$rapl_path")
#        uj_diff=$((e2 - e1))
#        echo "scale=1; $uj_diff / 1000000" | bc
#        return
#    fi
#
#    echo "N/A"
#}
#
#watts=$(get_watts)
#echo "{\"text\": \"⚡︎ ${watts}W\", \"tooltip\": \"System power draw: ${watts} watts\"}"
#

#!/usr/bin/env bash
# power.sh - Emit system power draw for waybar with warning/critical thresholds
#
# Usage (in waybar config):
#   "exec": "/path/to/power.sh --warn=80 --crit=120"
#
# The script accepts:
#   --warn=<watts>    (threshold to mark WARNING)
#   --crit=<watts>    (threshold to mark CRITICAL)
# Or set environment variables POWER_WARN and POWER_CRIT instead.
#
# Colors:
#  - warning: pastel yellow  -> #F6E27F
#  - critical: pastel red    -> #FF9B9B
#  - ok: pastel green        -> #A8E6CF
#  - unknown/N/A: grey       -> #9E9E9E
set -euo pipefail

# Defaults (empty = disabled)
WARN="${POWER_WARN:-}"
CRIT="${POWER_CRIT:-}"

# Parse CLI args (--warn=, --crit= or --warn 80)
while [ $# -gt 0 ]; do
    case "$1" in
        --warn=*) WARN="${1#*=}"; shift ;;
        --crit=*) CRIT="${1#*=}"; shift ;;
        --warn) WARN="$2"; shift 2 ;;
        --crit) CRIT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Colors (hex)
COLOR_OK="#A8E6CF"
COLOR_WARN="#F6E27F"
COLOR_CRIT="#FF9B9B"
COLOR_UNKNOWN="#9E9E9E"

# Read power in watts (returns number like 12.3 or N/A)
get_watts() {
    # Try battery discharge rate first (laptops)
    for bat in /sys/class/power_supply/BAT*; do
        [ -d "$bat" ] || continue

        if [ -f "$bat/power_now" ]; then
            microwatts=$(cat "$bat/power_now")
            # power_now is in microwatts -> convert to watts
            echo "scale=1; $microwatts / 1000000" | bc
            return
        fi

        # Fallback: voltage * current (voltage in microvolts, current in microamps)
        if [ -f "$bat/voltage_now" ] && [ -f "$bat/current_now" ]; then
            uv=$(cat "$bat/voltage_now")
            ua=$(cat "$bat/current_now")
            # (uv * ua) / 1e12 -> watts
            echo "scale=1; ($uv * $ua) / 1000000000000" | bc
            return
        fi
    done

    # Desktop/AC: try RAPL (Intel/AMD energy reporting) - measure over 1 second
    rapl_path="/sys/class/powercap/intel-rapl:0/energy_uj"
    if [ -f "$rapl_path" ]; then
        e1=$(cat "$rapl_path")
        sleep 1
        e2=$(cat "$rapl_path")
        uj_diff=$((e2 - e1))
        # uj_diff microjoules per 1 second = microwatts -> divide by 1e6 to get watts
        echo "scale=1; $uj_diff / 1000000" | bc
        return
    fi

    # Nothing found
    echo "N/A"
}

watts="$(get_watts)"

# Helper: numeric compare using awk (handles floats)
# returns 0 or 1
num_ge() {
    local val="$1"
    local thr="$2"
    if [ -z "$thr" ] || [ -z "$val" ]; then
        echo 0
        return
    fi
    # ensure "N/A" or non-numeric yields 0
    awk -v v="$val" -v t="$thr" 'BEGIN{if(v+0 >= t+0) print 1; else print 0}'
}

text=""
tooltip="System power draw: ${watts} W"
color=""
class=""

if [ "$watts" = "N/A" ]; then
    text="⚡︎ N/A"
    color="$COLOR_UNKNOWN"
    class="unknown"
else
    # Normalize to one decimal (script already returns one decimal) but ensure consistent display
    # (no expensive conversions; keep as-is)
    text="⚡︎ ${watts}W"

    # Check critical first
    if [ -n "$CRIT" ] && [ "$(num_ge "$watts" "$CRIT")" -eq 1 ]; then
        color="$COLOR_CRIT"
        class="critical"
    elif [ -n "$WARN" ] && [ "$(num_ge "$watts" "$WARN")" -eq 1 ]; then
        color="$COLOR_WARN"
        class="warning"
    else
        color="$COLOR_OK"
        class="normal"
    fi
fi

# Emit JSON for waybar (return-type: json)
# includes `text`, `tooltip`, `class` and `color` (hex)
printf '{"text":"%s","tooltip":"%s","class":"%s","color":"%s"}\n' \
    "$text" "$tooltip" "$class" "$color"
