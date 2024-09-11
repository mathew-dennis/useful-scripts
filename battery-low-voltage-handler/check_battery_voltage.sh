#!/bin/bash

# Path to the power supply directory
POWER_SUPPLY_DIR="/sys/class/power_supply/battery"

# Voltage threshold in microvolts (3.6V)
THRESHOLD=3600000

while true; do
    # Check if the voltage_now file exists
    if [ -f "$POWER_SUPPLY_DIR/voltage_now" ]; then
        # Read the current voltage
        VOLTAGE=$(cat "$POWER_SUPPLY_DIR/voltage_now")

        # Convert microvolts to volts for logging
        VOLTAGE_V=$(echo "scale=6; $VOLTAGE / 1000000" | bc)

        # Log the current voltage
        logger "Current battery voltage: ${VOLTAGE_V}V"

        # Check if the voltage is below the threshold
        if [ "$VOLTAGE" -lt "$THRESHOLD" ]; then
            logger "Battery voltage is below threshold ($VOLTAGE_V V). Shutting down..."
            shutdown -h now
        fi
    else
        logger "voltage_now file not found."
    fi

    # Wait for 1 second before checking again
    sleep 1
done
