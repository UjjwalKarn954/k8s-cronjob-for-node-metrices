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
