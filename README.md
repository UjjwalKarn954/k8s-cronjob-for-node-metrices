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

```

### 5. Create Dockerfile
- We will create a Dockerfile to containerise the script
```sh
# Use a lightweight base image
FROM alpine:3.19.1

# Create a non-root user to run the application
RUN adduser -D appuser

# Install curl
RUN apk --no-cache add curl

# Copy the bash script into the container
COPY node_metrics_collector.sh /node_metrics_collector.sh

# Change ownership and permissions of the script
RUN chown appuser:appuser /node_metrics_collector.sh \
    && chmod 755 /node_metrics_collector.sh

# Switch to the non-root user
USER appuser

# Run the script when the container starts
CMD ["sh", "/node_metrics_collector.sh"]

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

### 9. Deploying a long live pod

- To continously access the files written by a cronjob that runs every minute and mounts a PV, we need to presist data beyound the lifetime of each pod. So we deploy a long running pod `debug-pod.yaml` that mounts the same PV to access the files any time.

### 10. Accessing the files containing node metrics

```sh
 kubectl exec -it node-metrics-collector-debug-pod -n monitoring -- cat metrics/<Recent file name>
 ```

