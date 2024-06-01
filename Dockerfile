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
