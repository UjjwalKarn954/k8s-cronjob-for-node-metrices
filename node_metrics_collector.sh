#!/bin/bash

# Define Node Exporter URL
NODE_EXPORTER_URL="http://localhost:9100/metrics"
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
METRICS_DIR="/metrics"
METRICS_FILE="$METRICS_DIR/node_metrics_$TIMESTAMP.txt"

# Create the metrics directory if it doesn't exist
mkdir -p $METRICS_DIR

# Fetch metrics
metrics=$(curl -s $NODE_EXPORTER_URL)

# Extract and format CPU usage
CPU_METRICS=$(curl -s "$NODE_EXPORTER_URL" | grep 'node_cpu_seconds_total')

# Initialize variables for total time and total idle time
TOTAL_CPU=0
TOTAL_FREE_CPU=0

# Loop through each CPU core metric
while IFS= read -r line; do
    # Extract mode and value from the metric
    mode=$(echo "$line" | awk -F '[{},="]' '{print $8}')
    value=$(echo "$line" | awk '{print $2}')

    # If mode is idle, add value to total idle time
    if [ $mode = "idle" ]; then
        TOTAL_FREE_CPU=$(awk "BEGIN {print $TOTAL_FREE_CPU + $value}")
    fi

    # Add value to total time
    TOTAL_CPU=$(awk "BEGIN {print $TOTAL_CPU + $value}")

done < <(echo "$CPU_METRICS")

# Calculate CPU usage percentage
CPU_USAGE_PERCENTAGE=$(awk "BEGIN {print (($TOTAL_CPU - $TOTAL_FREE_CPU) / $TOTAL_CPU) * 100}")


# Retrieve Memory metrics from Node Exporter
TOTAL_MEMORY=$(curl -s $NODE_EXPORTER_URL | grep '^node_memory_MemTotal_bytes' | awk '{print $2}')
FREE_MEMORY=$(curl -s $NODE_EXPORTER_URL | grep '^node_memory_MemFree_bytes' | awk '{print $2}')

# Calculate Memory usage percentage
MEMORY_USAGE_PERCENTAGE=$(awk "BEGIN {print (($TOTAL_MEMORY - $FREE_MEMORY) / $TOTAL_MEMORY) * 100}")


# Retrieve Disk metrics from Node Exporter
DISK_SIZE=$(curl -s $NODE_EXPORTER_URL | awk -F ' ' '/node_filesystem_size_bytes.*device="tmpfs".*mountpoint="\/var"/ {print $2}')
FREE_DISK=$(curl -s $NODE_EXPORTER_URL | awk -F ' ' '/node_filesystem_free_bytes.*device="tmpfs".*mountpoint="\/var"/ {print $2}')

# Calculate Memory usage percentage
DISK_USAGE_PERCENTAGE=$(awk "BEGIN {print (($DISK_SIZE - $FREE_DISK) / $DISK_SIZE) * 100}")


# Write metrics to file with timestamped filename
cat <<EOF > "$METRICS_FILE"
Total CPU: $TOTAL_CPU
Free CPU: $TOTAL_FREE_CPU
CPU Usage Percentage: $CPU_USAGE_PERCENTAGE%

Total Memory: $TOTAL_MEMORY
Free Memory: $FREE_MEMORY
Memory Usage Percentage: $MEMORY_USAGE_PERCENTAGE%

Disk Size: $DISK_SIZE
Free Disk: $FREE_DISK
Disk Usage Percentage: $DISK_USAGE_PERCENTAGE%
EOF
