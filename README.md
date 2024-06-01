# KUBERNETES CRONJOB FOR NODE METRICS CLLECTION
### Task: Create a Kubernetes cron job that pulls node metrics like (CPU, Memory, Disk usages) and stores them in a file.

## Tools and Technologies used.
1. Kubernetes : Orchestration tool
2. Minikube : Local k8s setup
3. Kubectl : Command line tool for k8s management
4. node Exporter : Tool for extracting Hardware and OS metrics
5. Docker : Containerisation platform
6. Shell Script : Scripting 
7. Helm :  Package manager for Kubernetes, simplifies the deployment and management of applications on k8s using Helm Chart.

## Installation
- Moving ahead with the Installation and Deployment.

### 1. Install Minikube
- We have to setup Kubernetes cluster on our machine before deploying any Kubernetes cluster such as cron job. We will use Minikube for this.
```sh
brew install minikube
```

### 2. Install Kubectl 
- We have to install kubectl (Command line tool) for interacting with Kubernetes cluster.
```sh
brew install kubectl
```

### 3. Start and Verify Minikube
```sh
minikube start
minikube status
```

### 4. Create Script (node_metrics_collector.sh).
- We have to write the script to collect the metrics form nodes and save them in a file.
```sh
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

```

### 5. Create Dockerfile
- We will create a Dockerfile to containerise the script
```sh
# Use an official lightweight image
FROM alpine:latest

# Install necessary packages
RUN apk --no-cache add curl bash

# Set working directory
WORKDIR /usr/src/app

# Copy the script into the container
COPY node_metrics_collector.sh .

# Make the script executable
RUN chmod +x node_metrics_collector.sh

# Run the script
CMD ["./node_metrics_collector.sh"]

```

### 6. Build Docker Image
```sh
docker build -t node-metrics-collector:0.0.1
```

### 7. Deploying Node Exporter
- We will create a monotoring namespace for exporting metrics.
- We will create node-exporter as a daemonset as we have to run this pod on all the nodes.
- We will create to expose our application to outer world.
- We will create Kustomize to install node-exporter.
- Finally we will deploy the node metrics to the cluster using kustomize.
```sh
kubectl apply -k node-exporter/.
```

- Can verify if namespace and daemon set are created or not.
```sh
kubectl get namespace
```
```sh
kubectl get daemonset -n monitoring
```
### 8. Deploying Cronjob
- We will create cronjob that will run the script.
- We will create PV and PVC for storing the log file.
- Finally we will deploy the cronjob with PV and PVC using helm.
```sh
helm install node-metrics-collector node-metrics-collector/.
```
- We can verify if cronjob is created or not.

```sh
kubectl get cronjob -n monitoring
```

- We have sucessfully deployes the cronjob that collects the node metrics using node-exporter, we can see the log files in the PV mounted at `/persistent/metrics/node`.

