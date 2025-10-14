FROM postgres:16-alpine

# Install additional tools if needed
RUN apk add --no-cache bash

# Copy initialization scripts
COPY *.sql /docker-entrypoint-initdb.d/
COPY init.sh /docker-entrypoint-initdb.d/

# Make init script executable
RUN chmod +x /docker-entrypoint-initdb.d/init.sh

# Set working directory
WORKDIR /docker-entrypoint-initdb.d

# Healthcheck
HEALTHCHECK --interval=5s --timeout=3s --retries=3 \
  CMD pg_isready -h postgres -U claims_user || exit 1
