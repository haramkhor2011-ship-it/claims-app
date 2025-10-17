# Architecture & System Design
## Claims Processing System - Complete Technical Reference

---

## 📋 Overview

This document provides a comprehensive technical reference for the Claims Processing System architecture, covering system design, database architecture, data flow, security implementation, and technical decisions.

---

## 🏗️ System Architecture

### **High-Level Architecture**

```
┌─────────────────────────────────────────────────────────────────┐
│                    Claims Processing System                     │
├─────────────────────────────────────────────────────────────────┤
│  🌐 Presentation Layer    │  🔐 Security Layer                 │
│  • REST API (Spring Boot) │  • JWT Authentication              │
│  • Swagger Documentation  │  • Role-Based Access Control       │
│  • Health Monitoring      │  • Multi-Tenancy Support          │
├─────────────────────────────────────────────────────────────────┤
│  🧠 Business Logic Layer  │  📊 Data Processing Layer          │
│  • Ingestion Orchestrator │  • XML Parser (StAX)              │
│  • Claim Processing       │  • DTO Mapping (MapStruct)        │
│  • Event Projection       │  • Data Validation                │
│  • Report Generation      │  • Materialized Views             │
├─────────────────────────────────────────────────────────────────┤
│  🗄️ Data Layer           │  🔄 Integration Layer              │
│  • PostgreSQL Database    │  • SOAP Client (DHPO)             │
│  • Reference Data         │  • File System Integration        │
│  • Audit & Logging        │  • External API Integration       │
└─────────────────────────────────────────────────────────────────┘
```

### **Core Components**

#### **1. Ingestion Orchestrator**
- **Purpose**: Coordinates the complete claims ingestion pipeline
- **Flow**: `Fetcher → Queue → Parser → Batcher → Persist → Verify → ACK`
- **Profiles**: `localfs`, `soap`, `api`, `adminjobs`
- **Key Features**:
  - Idempotent processing (no duplicate claims)
  - Backpressure handling with bounded queues
  - Graceful error handling and recovery
  - Comprehensive audit logging

#### **2. Data Processing Pipeline**
- **XML Parser**: StAX-based streaming parser for memory efficiency
- **DTO Mapping**: MapStruct-based mapping to database entities
- **Validation**: XSD schema validation with business rule validation
- **Persistence**: JPA/Hibernate with PostgreSQL backend

#### **3. Event-Driven Architecture**
- **Event Stream**: Complete claim lifecycle tracking
- **Timeline Projection**: Real-time status updates
- **Audit Trail**: Comprehensive operational logging
- **Verification**: Automated data quality checks

---

## 🗄️ Database Architecture

### **Schema Design**

#### **Core Schemas**
- **`claims`**: Main processing and data storage
- **`claims_ref`**: Reference data (payers, providers, facilities)
- **`auth`**: User management and security (future)

#### **Key Tables**

##### **Ingestion & Processing**
```sql
-- File-level tracking
ingestion_file (file_id, sender_id, receiver_id, transaction_date, record_count, disposition_flag, raw_xml)

-- Run-level tracking  
ingestion_run (id, started_at, ended_at, status, files_processed, claims_parsed, errors)

-- File-level audit
ingestion_file_audit (file_id, run_id, parsed_claims, persisted_claims, verified, errors)
```

##### **Claim Data Model**
```sql
-- Spine table for claim lifecycle
claim_key (id, claim_id, created_at, updated_at)

-- Submission data
submission (id, file_id, sender_id, receiver_id, transaction_date)
claim (id, submission_id, claim_key_id, payer_id, provider_id, emirates_id, gross, patient_share, net)

-- Encounter details
encounter (id, claim_id, facility_id, type, patient_id, start_at, end_at)
diagnosis (id, encounter_id, code, description)

-- Activity details
activity (id, claim_id, start_at, type, code, quantity, net, clinician_ref_id)
observation (id, activity_id, type, code, value_text, value_type)

-- Resubmission tracking
claim_resubmission (id, claim_event_id, type, comment, attachment_data)
claim_event (id, claim_key_id, type, event_time, details)
```

##### **Remittance Processing**
```sql
-- Remittance grouping
remittance (id, file_id, sender_id, receiver_id, transaction_date)

-- Claim-level remittance
remittance_claim (id, remittance_id, claim_key_id, id_payer, provider_id, denial_code, payment_reference, date_settlement)

-- Activity-level remittance
remittance_activity (id, remittance_claim_id, activity_id, net, gross, patient_share, payment_amount, denial_code)
```

##### **Status & Timeline**
```sql
-- Event tracking
claim_event (id, claim_key_id, type, event_time, details)
claim_event_activity (id, claim_event_id, activity_id, state_snapshot)

-- Status projection
claim_status_timeline (claim_key_id, status, status_date, details)
```

### **Data Relationships**

#### **Claim Lifecycle Pattern**
```
Submission → Remittance → Resubmission → Remittance (repeatable)
     ↓           ↓            ↓            ↓
  SUBMITTED → PAID/REJECTED → RESUBMITTED → PAID/REJECTED
```

#### **Key Relationships**
- **Spine Table**: `claim_key` serves as the central reference
- **One-to-Many**: Claims can have multiple encounters, activities, events
- **Many-to-Many**: Activities can have multiple observations
- **Temporal**: Events are append-only with timeline projection

### **Performance Optimizations**

#### **Indexing Strategy**
- **Unique Indexes**: Prevent duplicates (file_id, claim_key_id combinations)
- **Covering Indexes**: Support common query patterns
- **Partial Indexes**: Optimize for active data only
- **Composite Indexes**: Multi-column queries

#### **Materialized Views**
- **Purpose**: Sub-second report performance
- **Refresh Strategy**: Concurrent refresh for zero-downtime
- **Storage**: Optimized for common reporting patterns
- **Maintenance**: Automated refresh scheduling

---

## 🔄 Data Flow Architecture

### **Ingestion Flow**

#### **1. File Acquisition**
```
Local Filesystem → LocalFsFetcher → Queue
SOAP Endpoint → SoapFetcher → Queue
```

#### **2. Processing Pipeline**
```
Queue → Parser → DTO → Validate → Map → Persist → Verify → ACK
```

#### **3. Data Transformation**
```
XML → StAX Parser → DTOs → MapStruct → JPA Entities → PostgreSQL
```

### **Event Processing**

#### **Event Types**
- **SUBMISSION** (1): Initial claim submission
- **RESUBMISSION** (2): Claim resubmission with changes
- **REMITTANCE** (3): Payment/adjudication response

#### **Event Projection**
- **Real-time**: Events processed immediately
- **Timeline**: Status derived from event sequence
- **Audit**: Complete event history maintained

---

## 🔐 Security Architecture

### **Authentication & Authorization**

#### **JWT-Based Authentication**
- **Access Tokens**: 15-minute expiration
- **Refresh Tokens**: 7-day expiration
- **Algorithm**: HMAC-SHA256
- **Claims**: User ID, roles, facilities, permissions

#### **Role-Based Access Control**
- **SUPER_ADMIN**: Full system access
- **FACILITY_ADMIN**: Facility-scoped management
- **STAFF**: Read-only access to assigned data

#### **Multi-Tenancy Support**
- **Toggle-Ready**: Can be enabled/disabled
- **Facility-Based**: Data filtered by user's facilities
- **SQL Filtering**: Automatic WHERE clause generation
- **Aspect Integration**: Transparent data filtering

### **Data Security**

#### **Encryption**
- **AME (Application-Managed Encryption)**: DHPO credentials
- **Password Hashing**: BCrypt with salt
- **Sensitive Data**: Emirates ID hashing/masking
- **Transport**: TLS for all external communications

#### **Audit & Compliance**
- **Security Events**: Complete authentication logging
- **Data Access**: All data access tracked
- **Administrative Actions**: Full audit trail
- **Compliance**: Ready for regulatory requirements

---

## 📊 Performance Architecture

### **Scalability Design**

#### **Horizontal Scaling**
- **Stateless Design**: JWT-based authentication
- **Load Balancing**: Compatible with multiple instances
- **Database**: Connection pooling and read replicas
- **Caching**: Redis integration ready

#### **Vertical Scaling**
- **Memory Management**: Efficient object lifecycle
- **Connection Pooling**: Optimized database connections
- **Batch Processing**: Configurable batch sizes
- **Resource Monitoring**: JVM metrics and alerts

### **Performance Optimizations**

#### **Database Performance**
- **Materialized Views**: Pre-computed aggregations
- **Indexing Strategy**: Optimized for query patterns
- **Query Optimization**: Efficient SQL generation
- **Connection Pooling**: HikariCP optimization

#### **Application Performance**
- **Streaming Processing**: StAX for large XML files
- **Batch Operations**: Bulk database operations
- **Caching Strategy**: Reference data caching
- **Async Processing**: Non-blocking operations

---

## 🔧 Configuration Architecture

### **Profile-Based Configuration**

#### **Development Profiles**
- **`localfs`**: Local file processing
- **`soap`**: SOAP integration
- **`api`**: REST API server
- **`adminjobs`**: Administrative tasks

#### **Environment Configuration**
- **Development**: Local development setup
- **Testing**: Test-specific configuration
- **Production**: Production-optimized settings
- **Docker**: Container-specific configuration

### **External Configuration**

#### **Environment Variables**
- **Database**: Connection strings and credentials
- **Security**: JWT secrets and encryption keys
- **Integration**: SOAP endpoints and credentials
- **Monitoring**: Logging and metrics configuration

#### **Configuration Management**
- **Spring Profiles**: Environment-specific settings
- **External Files**: Configuration file overrides
- **Secrets Management**: Secure credential handling
- **Validation**: Configuration validation on startup

---

## 🚀 Deployment Architecture

### **Container Strategy**

#### **Docker Configuration**
- **Multi-Stage Build**: Optimized image size
- **Health Checks**: Container health monitoring
- **Volume Mounts**: Persistent data storage
- **Network**: Service communication

#### **Docker Compose**
- **PostgreSQL**: Database service
- **Application**: Claims processing service
- **Initialization**: Database setup service
- **Monitoring**: Log aggregation

### **Production Deployment**

#### **Infrastructure Requirements**
- **CPU**: 2+ cores recommended
- **Memory**: 4GB+ RAM recommended
- **Storage**: 20GB+ disk space
- **Network**: Ports 8080 (API), 5432 (Database)

#### **High Availability**
- **Load Balancing**: Multiple application instances
- **Database**: Primary/replica setup
- **Monitoring**: Health checks and alerting
- **Backup**: Automated backup strategy

---

## 📈 Monitoring & Observability

### **Application Monitoring**

#### **Health Endpoints**
- **`/actuator/health`**: Application health status
- **`/actuator/metrics`**: Performance metrics
- **`/actuator/info`**: Application information
- **`/actuator/prometheus`**: Prometheus metrics

#### **Custom Metrics**
- **Ingestion KPIs**: Files processed, claims parsed
- **Performance Metrics**: Processing times, throughput
- **Error Rates**: Failure rates and error types
- **Resource Usage**: Memory, CPU, database connections

### **Database Monitoring**

#### **Performance Metrics**
- **Query Performance**: Slow query identification
- **Connection Pool**: Pool utilization and health
- **Index Usage**: Index effectiveness analysis
- **Storage**: Database size and growth

#### **Operational Metrics**
- **Backup Status**: Backup success and timing
- **Replication Lag**: Replica synchronization
- **Lock Contention**: Database lock analysis
- **Transaction Rates**: Transaction throughput

---

## 🔄 Integration Architecture

### **External Integrations**

#### **DHPO SOAP Integration**
- **Authentication**: Encrypted credential management
- **Error Handling**: Circuit breaker pattern
- **Retry Logic**: Exponential backoff
- **Monitoring**: Integration health tracking

#### **File System Integration**
- **Local Processing**: File system monitoring
- **Remote Processing**: SOAP-based file retrieval
- **Error Handling**: File processing error recovery
- **Audit**: Complete file processing audit

### **API Integration**

#### **REST API Design**
- **RESTful Principles**: Standard HTTP methods
- **Versioning**: API version management
- **Documentation**: OpenAPI/Swagger documentation
- **Security**: JWT-based authentication

#### **Data Access Patterns**
- **Pagination**: Large dataset handling
- **Filtering**: Flexible data filtering
- **Sorting**: Configurable data ordering
- **Projection**: Field selection optimization

---

## 🎯 Key Design Decisions

### **Architectural Decisions**

#### **1. Event-Driven Architecture**
- **Decision**: Use event sourcing for claim lifecycle
- **Rationale**: Complete audit trail and timeline projection
- **Trade-offs**: Additional complexity vs. complete history

#### **2. Materialized Views**
- **Decision**: Pre-compute report aggregations
- **Rationale**: Sub-second report performance
- **Trade-offs**: Storage overhead vs. query performance

#### **3. Idempotent Processing**
- **Decision**: Prevent duplicate claim processing
- **Rationale**: Data integrity and reliability
- **Trade-offs**: Additional complexity vs. data safety

#### **4. Multi-Tenancy Design**
- **Decision**: Toggle-ready multi-tenancy
- **Rationale**: Future scalability and flexibility
- **Trade-offs**: Development complexity vs. future flexibility

### **Technology Decisions**

#### **1. Spring Boot Framework**
- **Decision**: Use Spring Boot for application framework
- **Rationale**: Rapid development and ecosystem
- **Trade-offs**: Framework lock-in vs. development speed

#### **2. PostgreSQL Database**
- **Decision**: Use PostgreSQL as primary database
- **Rationale**: ACID compliance and advanced features
- **Trade-offs**: Learning curve vs. reliability

#### **3. JWT Authentication**
- **Decision**: Use JWT for stateless authentication
- **Rationale**: Scalability and simplicity
- **Trade-offs**: Token size vs. stateless design

---

## 🔮 Future Architecture Considerations

### **Scalability Roadmap**

#### **Short Term (3-6 months)**
- **Caching Layer**: Redis integration for performance
- **API Gateway**: Centralized API management
- **Monitoring**: Enhanced observability

#### **Medium Term (6-12 months)**
- **Microservices**: Service decomposition
- **Event Streaming**: Kafka for event processing
- **Cloud Migration**: Cloud-native deployment

#### **Long Term (12+ months)**
- **Multi-Region**: Geographic distribution
- **AI/ML Integration**: Intelligent processing
- **Real-Time Analytics**: Stream processing

### **Technology Evolution**

#### **Database Evolution**
- **Partitioning**: Table partitioning for large datasets
- **Read Replicas**: Read scaling optimization
- **Sharding**: Horizontal database scaling

#### **Application Evolution**
- **Reactive Programming**: Non-blocking I/O
- **GraphQL**: Flexible data querying
- **gRPC**: High-performance RPC

---

## 📚 Related Documentation

- [Operations & Deployment Guide](OPERATIONS_AND_DEPLOYMENT.md)
- [Development & Implementation Guide](DEVELOPMENT_AND_IMPLEMENTATION.md)
- [Troubleshooting & Analysis Guide](TROUBLESHOOTING_AND_ANALYSIS.md)
- [Security Implementation Guide](SECURITY_IMPLEMENTATION_COMPLETE.md)

---

*This document serves as the complete technical reference for the Claims Processing System architecture. It should be updated whenever architectural decisions are made or system components are modified.*