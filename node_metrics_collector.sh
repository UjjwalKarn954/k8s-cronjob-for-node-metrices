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
cpu_stats=$(echo "$metrics" | grep '^node_cpu_seconds_total')
cpu_usage=$(echo "$cpu_stats" | awk '
BEGIN {
  total_time = 0;
  idle_time = 0;
  user_time = 0;
  system_time = 0;
  iowait_time = 0;
}
{
  if ($1 ~ /mode="idle"/) {              # Changed line
    idle_time += $2;                     # Changed line
  } else if ($1 ~ /mode="user"/) {       # Changed line
    user_time += $2;                     # Changed line
  } else if ($1 ~ /mode="system"/) {     # Changed line
    system_time += $2;                   # Changed line
  } else if ($1 ~ /mode="iowait"/) {     # Changed line
    iowait_time += $2;                   # Changed line
  }
  total_time += $2;                      # Changed line
}
END {
  cpu_usage = (1 - (idle_time / total_time)) * 100;
  printf "CPU Usage: %.2f%%\n", cpu_usage;
  printf "User Time: %.2f seconds\n", user_time;
  printf "System Time: %.2f seconds\n", system_time;
  printf "Idle Time: %.2f seconds\n", idle_time;
  printf "I/O Wait Time: %.2f seconds\n", iowait_time;
  printf "Total CPU Time: %.2f seconds\n", total_time;
}')

# Extract and format memory usage
memory_total=$(echo "$metrics" | grep '^node_memory_MemTotal_bytes' | awk '{print $2}')
memory_available=$(echo "$metrics" | grep '^node_memory_MemAvailable_bytes' | awk '{print $2}')
memory_free=$(echo "$metrics" | grep '^node_memory_MemFree_bytes' | awk '{print $2}')
memory_cached=$(echo "$metrics" | grep '^node_memory_Cached_bytes' | awk '{print $2}')
memory_buffers=$(echo "$metrics" | grep '^node_memory_Buffers_bytes' | awk '{print $2}')
memory_usage=$(awk -v total="$memory_total" -v available="$memory_available" -v free="$memory_free" -v cached="$memory_cached" -v buffers="$memory_buffers" 'BEGIN {
  used = total - available;
  usage = (used / total) * 100;
  printf "Memory Usage: %.2f%%\n", usage;
  printf "Total Memory: %.2f MB\n", total / (1024 * 1024);
  printf "Available Memory: %.2f MB\n", available / (1024 * 1024);
  printf "Free Memory: %.2f MB\n", free / (1024 * 1024);
  printf "Cached Memory: %.2f MB\n", cached / (1024 * 1024);
  printf "Buffers: %.2f MB\n", buffers / (1024 * 1024);
}')

# Extract and format disk usage
disk_total=$(echo "$metrics" | grep '^node_filesystem_size_bytes' | awk '{total+=$2} END{print total}')  # Changed line
disk_available=$(echo "$metrics" | grep '^node_filesystem_avail_bytes' | awk '{avail+=$2} END{print avail}')  # Changed line
disk_usage=$(awk -v total="$disk_total" -v available="$disk_available" 'BEGIN {
  used = total - available;
  usage = (used / total) * 100;
  printf "Disk Usage: %.2f%%\n", usage;
  printf "Total Disk Space: %.2f GB\n", total / (1024 * 1024 * 1024);
  printf "Available Disk Space: %.2f GB\n", available / (1024 * 1024 * 1024);
}')

# Save the formatted metrics to a file
echo -e "$cpu_usage\n$memory_usage\n$disk_usage" > $METRICS_FILE  # Changed line

# Log the action
echo "Metrics saved to $METRICS_FILE"
