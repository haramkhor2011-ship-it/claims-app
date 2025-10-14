# Multi-stage Dockerfile for Claims Backend Application
# Stage 1: Build stage with Maven and Java 21
FROM eclipse-temurin:21-jdk-alpine AS builder

# Set working directory
WORKDIR /app

# Copy Maven configuration files
COPY pom.xml .

# Copy source code
COPY src/ src/

# Build the application
RUN mvn clean package -DskipTests

# Stage 2: Runtime stage with JRE
FROM eclipse-temurin:21-jre-alpine

# Create non-root user for security
RUN addgroup -g 1001 -S claims && \
    adduser -u 1001 -S claims -G claims

# Set working directory
WORKDIR /app

# Create necessary directories
RUN mkdir -p data/ready data/archive/done data/archive/error config logs && \
    chown -R claims:claims /app

# Copy the built JAR from builder stage
COPY --from=builder /app/target/claims-backend.jar app.jar

# Copy reference data CSVs
COPY --from=builder /app/src/main/resources/refdata/ refdata/

# Change ownership to claims user
RUN chown -R claims:claims /app

# Switch to non-root user
USER claims

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Set JVM options
ENV JAVA_OPTS="-Xms512m -Xmx2048m -XX:+UseG1GC -XX:+UseContainerSupport"

# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
