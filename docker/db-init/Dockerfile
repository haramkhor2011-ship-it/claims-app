FROM alpine:latest

# Install postgresql client tools
RUN apk add --no-cache bash postgresql-client

# Copy initialization scripts
COPY *.sql /scripts/
COPY init.sh /scripts/

# Make init script executable
RUN chmod +x /scripts/init.sh

# Set working directory
WORKDIR /scripts

# Override entrypoint to run our init script
ENTRYPOINT ["/scripts/init.sh"]
