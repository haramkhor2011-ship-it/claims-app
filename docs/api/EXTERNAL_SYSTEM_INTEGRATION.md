# External System Integration Guide

## Overview

This guide provides comprehensive instructions for integrating external systems with the reports API, covering authentication requirements, rate limiting considerations, data export formats, and best practices for both local development and production environments.

## Integration Architecture

### API Gateway Integration
```
External System → API Gateway → Reports API → Database
                ↓
            Rate Limiting
            Authentication
            Logging/Monitoring
```

### Direct Integration
```
External System → Reports API → Database
                ↓
            Authentication
            Rate Limiting
            Data Validation
```

## Authentication Requirements

### API Key Authentication
```http
POST /api/reports/data/balance-amount
Authorization: Bearer <api_key>
Content-Type: application/json

{
  "reportType": "BALANCE_AMOUNT",
  "facilityCode": "FAC001",
  "fromDate": "2024-01-01T00:00:00Z",
  "toDate": "2024-12-31T23:59:59Z"
}
```

### OAuth2 Integration
```http
POST /api/reports/data/balance-amount
Authorization: Bearer <oauth2_token>
Content-Type: application/json

{
  "reportType": "BALANCE_AMOUNT",
  "facilityCode": "FAC001",
  "fromDate": "2024-01-01T00:00:00Z",
  "toDate": "2024-12-31T23:59:59Z"
}
```

### Service Account Authentication
```yaml
# Service account configuration
service_account:
  client_id: "external_system_client"
  client_secret: "{{external_system_secret}}"
  grant_type: "client_credentials"
  scope: "reports:read"
  token_endpoint: "{{base_url}}/api/auth/oauth/token"
```

## Rate Limiting Considerations

### Rate Limit Headers
```http
HTTP/1.1 200 OK
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1640995200
X-RateLimit-Retry-After: 60
```

### Rate Limit Policies

#### Local Development
```yaml
rate_limiting:
  local:
    requests_per_minute: 1000
    burst_limit: 100
    window_size: 60
```

#### Production Environment
```yaml
rate_limiting:
  production:
    requests_per_minute: 100
    burst_limit: 20
    window_size: 60
    per_client_limit: 50
```

### Rate Limit Handling
```python
import requests
import time
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

class RateLimitedClient:
    def __init__(self, base_url, api_key):
        self.base_url = base_url
        self.api_key = api_key
        self.session = requests.Session()
        
        # Configure retry strategy
        retry_strategy = Retry(
            total=3,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504],
        )
        
        adapter = HTTPAdapter(max_retries=retry_strategy)
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)
    
    def make_request(self, endpoint, data):
        headers = {
            'Authorization': f'Bearer {self.api_key}',
            'Content-Type': 'application/json'
        }
        
        response = self.session.post(
            f"{self.base_url}{endpoint}",
            json=data,
            headers=headers
        )
        
        if response.status_code == 429:
            retry_after = int(response.headers.get('Retry-After', 60))
            time.sleep(retry_after)
            return self.make_request(endpoint, data)
        
        response.raise_for_status()
        return response.json()
```

## Data Export Formats

### JSON Format
```json
{
  "data": [
    {
      "facilityCode": "FAC001",
      "facilityName": "Main Hospital",
      "claimId": "CLM123456",
      "billedAmount": 1500.00,
      "paymentAmount": 1200.00,
      "deniedAmount": 0.00,
      "pendingAmount": 300.00,
      "agingDays": 45,
      "status": "PARTIALLY_PAID"
    }
  ],
  "metadata": {
    "totalElements": 150,
    "totalPages": 2,
    "page": 0,
    "size": 100,
    "exportedAt": "2024-03-15T14:30:00Z",
    "reportType": "BALANCE_AMOUNT",
    "filters": {
      "facilityCode": "FAC001",
      "fromDate": "2024-01-01T00:00:00Z",
      "toDate": "2024-12-31T23:59:59Z"
    }
  }
}
```

### CSV Format
```csv
facilityCode,facilityName,claimId,billedAmount,paymentAmount,deniedAmount,pendingAmount,agingDays,status
FAC001,Main Hospital,CLM123456,1500.00,1200.00,0.00,300.00,45,PARTIALLY_PAID
FAC001,Main Hospital,CLM123457,2000.00,2000.00,0.00,0.00,30,FULLY_PAID
```

### XML Format
```xml
<?xml version="1.0" encoding="UTF-8"?>
<report>
  <metadata>
    <reportType>BALANCE_AMOUNT</reportType>
    <exportedAt>2024-03-15T14:30:00Z</exportedAt>
    <totalElements>150</totalElements>
    <totalPages>2</totalPages>
    <page>0</page>
    <size>100</size>
  </metadata>
  <data>
    <record>
      <facilityCode>FAC001</facilityCode>
      <facilityName>Main Hospital</facilityName>
      <claimId>CLM123456</claimId>
      <billedAmount>1500.00</billedAmount>
      <paymentAmount>1200.00</paymentAmount>
      <deniedAmount>0.00</deniedAmount>
      <pendingAmount>300.00</pendingAmount>
      <agingDays>45</agingDays>
      <status>PARTIALLY_PAID</status>
    </record>
  </data>
</report>
```

## Batch Processing

### Batch Request Format
```json
{
  "batchId": "batch_123456",
  "requests": [
    {
      "requestId": "req_001",
      "reportType": "BALANCE_AMOUNT",
      "facilityCode": "FAC001",
      "fromDate": "2024-01-01T00:00:00Z",
      "toDate": "2024-01-31T23:59:59Z"
    },
    {
      "requestId": "req_002",
      "reportType": "BALANCE_AMOUNT",
      "facilityCode": "FAC001",
      "fromDate": "2024-02-01T00:00:00Z",
      "toDate": "2024-02-29T23:59:59Z"
    }
  ]
}
```

### Batch Response Format
```json
{
  "batchId": "batch_123456",
  "status": "COMPLETED",
  "totalRequests": 2,
  "completedRequests": 2,
  "failedRequests": 0,
  "results": [
    {
      "requestId": "req_001",
      "status": "SUCCESS",
      "data": {
        "totalElements": 50,
        "data": [...]
      }
    },
    {
      "requestId": "req_002",
      "status": "SUCCESS",
      "data": {
        "totalElements": 45,
        "data": [...]
      }
    }
  ]
}
```

### Batch Processing Implementation
```python
class BatchProcessor:
    def __init__(self, api_client):
        self.api_client = api_client
        self.batch_size = 10
        self.max_concurrent = 5
    
    def process_batch(self, requests):
        results = []
        
        # Process requests in batches
        for i in range(0, len(requests), self.batch_size):
            batch = requests[i:i + self.batch_size]
            batch_results = self.process_batch_chunk(batch)
            results.extend(batch_results)
        
        return results
    
    def process_batch_chunk(self, batch):
        import concurrent.futures
        
        results = []
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=self.max_concurrent) as executor:
            future_to_request = {
                executor.submit(self.api_client.get_report, req): req 
                for req in batch
            }
            
            for future in concurrent.futures.as_completed(future_to_request):
                request = future_to_request[future]
                try:
                    result = future.result()
                    results.append({
                        'requestId': request['requestId'],
                        'status': 'SUCCESS',
                        'data': result
                    })
                except Exception as e:
                    results.append({
                        'requestId': request['requestId'],
                        'status': 'FAILED',
                        'error': str(e)
                    })
        
        return results
```

## Webhook Support

### Webhook Configuration
```json
{
  "webhookUrl": "https://external-system.com/webhooks/reports",
  "events": ["report.completed", "report.failed"],
  "secret": "webhook_secret_key",
  "retryPolicy": {
    "maxRetries": 3,
    "retryDelay": 60,
    "backoffMultiplier": 2
  }
}
```

### Webhook Payload
```json
{
  "event": "report.completed",
  "timestamp": "2024-03-15T14:30:00Z",
  "data": {
    "reportId": "report_123456",
    "reportType": "BALANCE_AMOUNT",
    "status": "COMPLETED",
    "totalElements": 150,
    "downloadUrl": "https://api.claims.com/api/reports/download/report_123456",
    "expiresAt": "2024-03-16T14:30:00Z"
  }
}
```

### Webhook Verification
```python
import hmac
import hashlib

def verify_webhook_signature(payload, signature, secret):
    expected_signature = hmac.new(
        secret.encode('utf-8'),
        payload.encode('utf-8'),
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(signature, expected_signature)
```

## Error Handling

### Error Response Format
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid facility code provided",
    "details": {
      "field": "facilityCode",
      "value": "INVALID_FACILITY",
      "constraint": "Must be a valid facility code"
    },
    "timestamp": "2024-03-15T14:30:00Z",
    "requestId": "req_123456"
  }
}
```

### Error Handling Implementation
```python
class APIError(Exception):
    def __init__(self, code, message, details=None):
        self.code = code
        self.message = message
        self.details = details
        super().__init__(self.message)

class ReportsAPIClient:
    def handle_error(self, response):
        if response.status_code == 400:
            error_data = response.json()
            raise APIError(
                error_data['error']['code'],
                error_data['error']['message'],
                error_data['error'].get('details')
            )
        elif response.status_code == 401:
            raise APIError('UNAUTHORIZED', 'Invalid or expired authentication token')
        elif response.status_code == 403:
            raise APIError('FORBIDDEN', 'Insufficient permissions for this operation')
        elif response.status_code == 404:
            raise APIError('NOT_FOUND', 'Requested resource not found')
        elif response.status_code == 429:
            raise APIError('RATE_LIMITED', 'Rate limit exceeded')
        elif response.status_code >= 500:
            raise APIError('SERVER_ERROR', 'Internal server error')
        else:
            raise APIError('UNKNOWN_ERROR', f'Unexpected error: {response.status_code}')
```

## Monitoring and Logging

### API Monitoring
```python
import logging
import time
from functools import wraps

def monitor_api_calls(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.time()
        try:
            result = func(*args, **kwargs)
            duration = time.time() - start_time
            logging.info(f"API call {func.__name__} completed in {duration:.2f}s")
            return result
        except Exception as e:
            duration = time.time() - start_time
            logging.error(f"API call {func.__name__} failed after {duration:.2f}s: {str(e)}")
            raise
    return wrapper

class MonitoredAPIClient:
    @monitor_api_calls
    def get_report(self, report_type, filters):
        # API call implementation
        pass
```

### Health Check Integration
```python
class HealthChecker:
    def __init__(self, api_client):
        self.api_client = api_client
    
    def check_health(self):
        try:
            # Simple health check request
            response = self.api_client.get_available_reports()
            return {
                'status': 'healthy',
                'timestamp': time.time(),
                'response_time': response.elapsed.total_seconds()
            }
        except Exception as e:
            return {
                'status': 'unhealthy',
                'timestamp': time.time(),
                'error': str(e)
            }
```

## Security Considerations

### API Key Management
```python
import os
from cryptography.fernet import Fernet

class SecureAPIKeyManager:
    def __init__(self):
        self.encryption_key = os.environ.get('API_KEY_ENCRYPTION_KEY')
        self.cipher = Fernet(self.encryption_key.encode())
    
    def encrypt_api_key(self, api_key):
        return self.cipher.encrypt(api_key.encode()).decode()
    
    def decrypt_api_key(self, encrypted_api_key):
        return self.cipher.decrypt(encrypted_api_key.encode()).decode()
```

### Data Encryption
```python
import ssl
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.ssl_ import create_urllib3_context

class SecureAPIClient:
    def __init__(self, base_url, api_key):
        self.base_url = base_url
        self.api_key = api_key
        self.session = requests.Session()
        
        # Configure SSL context
        context = create_urllib3_context()
        context.set_ciphers('ECDHE+AESGCM:ECDHE+CHACHA20:DHE+AESGCM:DHE+CHACHA20:!aNULL:!MD5:!DSS')
        
        adapter = HTTPAdapter()
        adapter.init_poolmanager(ssl_context=context)
        self.session.mount('https://', adapter)
    
    def make_request(self, endpoint, data):
        headers = {
            'Authorization': f'Bearer {self.api_key}',
            'Content-Type': 'application/json',
            'User-Agent': 'ExternalSystem/1.0'
        }
        
        response = self.session.post(
            f"{self.base_url}{endpoint}",
            json=data,
            headers=headers,
            timeout=30
        )
        
        response.raise_for_status()
        return response.json()
```

## Environment-Specific Configuration

### Local Development
```yaml
# local_config.yml
api:
  base_url: "http://localhost:8080"
  timeout: 30
  retry_attempts: 3
  retry_delay: 1

authentication:
  type: "api_key"
  api_key: "dev_api_key_123"

rate_limiting:
  enabled: false
  requests_per_minute: 1000

logging:
  level: "DEBUG"
  format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
```

### Production Environment
```yaml
# production_config.yml
api:
  base_url: "https://api.claims.com"
  timeout: 60
  retry_attempts: 5
  retry_delay: 2

authentication:
  type: "oauth2"
  client_id: "{{OAUTH_CLIENT_ID}}"
  client_secret: "{{OAUTH_CLIENT_SECRET}}"
  token_endpoint: "https://api.claims.com/api/auth/oauth/token"

rate_limiting:
  enabled: true
  requests_per_minute: 100
  burst_limit: 20

logging:
  level: "INFO"
  format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
```

## Testing Integration

### Unit Tests
```python
import unittest
from unittest.mock import Mock, patch
from reports_api_client import ReportsAPIClient

class TestReportsAPIClient(unittest.TestCase):
    def setUp(self):
        self.client = ReportsAPIClient('http://localhost:8080', 'test_api_key')
    
    @patch('requests.post')
    def test_get_balance_amount_report(self, mock_post):
        # Mock response
        mock_response = Mock()
        mock_response.json.return_value = {
            'data': [{'facilityCode': 'FAC001', 'claimId': 'CLM123'}],
            'totalElements': 1
        }
        mock_response.status_code = 200
        mock_post.return_value = mock_response
        
        # Test
        result = self.client.get_balance_amount_report({
            'facilityCode': 'FAC001',
            'fromDate': '2024-01-01T00:00:00Z',
            'toDate': '2024-12-31T23:59:59Z'
        })
        
        # Assertions
        self.assertEqual(len(result['data']), 1)
        self.assertEqual(result['data'][0]['facilityCode'], 'FAC001')
        mock_post.assert_called_once()
    
    def test_handle_rate_limit_error(self):
        with patch('requests.post') as mock_post:
            mock_response = Mock()
            mock_response.status_code = 429
            mock_response.headers = {'Retry-After': '60'}
            mock_post.return_value = mock_response
            
            with self.assertRaises(APIError) as context:
                self.client.get_balance_amount_report({})
            
            self.assertEqual(context.exception.code, 'RATE_LIMITED')
```

### Integration Tests
```python
class TestIntegration(unittest.TestCase):
    def setUp(self):
        self.client = ReportsAPIClient(
            'http://localhost:8080',
            os.environ.get('TEST_API_KEY')
        )
    
    def test_end_to_end_report_generation(self):
        # Test complete report generation flow
        filters = {
            'facilityCode': 'FAC001',
            'fromDate': '2024-01-01T00:00:00Z',
            'toDate': '2024-12-31T23:59:59Z'
        }
        
        result = self.client.get_balance_amount_report(filters)
        
        self.assertIsInstance(result, dict)
        self.assertIn('data', result)
        self.assertIn('totalElements', result)
        self.assertIsInstance(result['data'], list)
```

## Best Practices

### Development Best Practices
1. **Use Environment Variables**: Store sensitive configuration in environment variables
2. **Implement Retry Logic**: Handle transient failures gracefully
3. **Add Logging**: Log all API interactions for debugging
4. **Test Thoroughly**: Write comprehensive unit and integration tests
5. **Handle Errors**: Implement proper error handling and recovery

### Production Best Practices
1. **Monitor Performance**: Track API response times and error rates
2. **Implement Caching**: Cache frequently accessed data
3. **Use Connection Pooling**: Reuse HTTP connections for efficiency
4. **Implement Circuit Breakers**: Prevent cascading failures
5. **Secure Credentials**: Use secure credential management

### Security Best Practices
1. **Use HTTPS**: Always use HTTPS for API communication
2. **Rotate Keys**: Regularly rotate API keys and tokens
3. **Validate Inputs**: Validate all inputs before sending to API
4. **Implement Timeouts**: Set appropriate timeouts for API calls
5. **Monitor Access**: Monitor API access and usage patterns

## Related Documentation
- [API Reference](./REPORT_API_REFERENCE.md)
- [API Authentication Guide](./API_AUTHENTICATION_GUIDE.md)
- [API Error Codes](./API_ERROR_CODES.md)
- [Frontend Integration Guide](./FRONTEND_INTEGRATION_GUIDE.md)
- [Environment Behavior Guide](../reports/ENVIRONMENT_BEHAVIOR_GUIDE.md)
