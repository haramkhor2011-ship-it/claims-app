# Frontend Integration Guide

## Overview

This guide provides comprehensive instructions for integrating the reports API with frontend applications, covering authentication, API calls, error handling, and best practices for both local development and production environments.

## Authentication Setup

### JWT Token Management

#### Obtaining Authentication Token
```javascript
// Authentication service
class AuthService {
  constructor() {
    this.baseURL = this.getBaseURL();
    this.token = localStorage.getItem('auth_token');
  }

  getBaseURL() {
    // Environment-specific URLs
    if (process.env.NODE_ENV === 'development') {
      return 'http://localhost:8080';
    } else if (process.env.NODE_ENV === 'staging') {
      return 'https://staging-api.claims.com';
    } else {
      return 'https://api.claims.com';
    }
  }

  async login(username, password) {
    try {
      const response = await fetch(`${this.baseURL}/api/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ username, password }),
      });

      if (!response.ok) {
        throw new Error('Authentication failed');
      }

      const data = await response.json();
      this.token = data.access_token;
      localStorage.setItem('auth_token', this.token);
      
      return data;
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  }

  getAuthHeaders() {
    return {
      'Authorization': `Bearer ${this.token}`,
      'Content-Type': 'application/json',
    };
  }

  isTokenExpired() {
    if (!this.token) return true;
    
    try {
      const payload = JSON.parse(atob(this.token.split('.')[1]));
      return Date.now() >= payload.exp * 1000;
    } catch {
      return true;
    }
  }

  async refreshToken() {
    // Implement token refresh logic
    const response = await fetch(`${this.baseURL}/api/auth/refresh`, {
      method: 'POST',
      headers: this.getAuthHeaders(),
    });
    
    const data = await response.json();
    this.token = data.access_token;
    localStorage.setItem('auth_token', this.token);
  }
}
```

### Local Development Authentication

#### Development Mode Setup
```javascript
// For local development, you might use a mock token
const mockToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';

// Or disable authentication entirely for development
const isDevelopment = process.env.NODE_ENV === 'development';
const authService = isDevelopment ? new MockAuthService() : new AuthService();
```

## API Integration

### Report Service Class

#### Base Report Service
```javascript
class ReportService {
  constructor(authService) {
    this.authService = authService;
    this.baseURL = authService.baseURL;
  }

  async makeRequest(endpoint, options = {}) {
    const url = `${this.baseURL}${endpoint}`;
    
    // Check if token is expired
    if (this.authService.isTokenExpired()) {
      await this.authService.refreshToken();
    }

    const defaultOptions = {
      headers: this.authService.getAuthHeaders(),
      ...options,
    };

    try {
      const response = await fetch(url, defaultOptions);
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error('API request failed:', error);
      throw error;
    }
  }

  async getAvailableReports() {
    return this.makeRequest('/api/reports/data/available');
  }

  async getReportData(reportType, requestData) {
    return this.makeRequest(`/api/reports/data/${reportType.toLowerCase()}`, {
      method: 'POST',
      body: JSON.stringify(requestData),
    });
  }
}
```

#### Specific Report Services
```javascript
class BalanceAmountReportService extends ReportService {
  async getBalanceAmountReport(filters) {
    const requestData = {
      reportType: 'BALANCE_AMOUNT',
      tab: filters.tab || 'A',
      facilityCode: filters.facilityCode,
      payerCodes: filters.payerCodes,
      fromDate: filters.fromDate,
      toDate: filters.toDate,
      page: filters.page || 0,
      size: filters.size || 100,
    };

    return this.getReportData('balance-amount', requestData);
  }

  async getTabA_BalanceToBeReceived(filters) {
    return this.getBalanceAmountReport({ ...filters, tab: 'A' });
  }

  async getTabB_InitialNotRemitted(filters) {
    return this.getBalanceAmountReport({ ...filters, tab: 'B' });
  }

  async getTabC_PostResubmission(filters) {
    return this.getBalanceAmountReport({ ...filters, tab: 'C' });
  }
}

class RejectedClaimsReportService extends ReportService {
  async getRejectedClaimsReport(filters) {
    const requestData = {
      reportType: 'REJECTED_CLAIMS',
      tab: filters.tab || 'A',
      facilityCode: filters.facilityCode,
      payerCodes: filters.payerCodes,
      fromDate: filters.fromDate,
      toDate: filters.toDate,
      page: filters.page || 0,
      size: filters.size || 100,
    };

    return this.getReportData('rejected-claims', requestData);
  }
}
```

## React Integration

### Custom Hooks

#### Report Data Hook
```javascript
import { useState, useEffect, useCallback } from 'react';

export const useReportData = (reportService, reportType, filters) => {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [pagination, setPagination] = useState({
    page: 0,
    size: 100,
    totalElements: 0,
    totalPages: 0,
  });

  const fetchData = useCallback(async () => {
    if (!filters.facilityCode) return;

    setLoading(true);
    setError(null);

    try {
      const response = await reportService.getReportData(reportType, {
        ...filters,
        page: pagination.page,
        size: pagination.size,
      });

      setData(response.data);
      setPagination({
        page: response.page,
        size: response.size,
        totalElements: response.totalElements,
        totalPages: response.totalPages,
      });
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [reportService, reportType, filters, pagination.page, pagination.size]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const changePage = useCallback((newPage) => {
    setPagination(prev => ({ ...prev, page: newPage }));
  }, []);

  const changeSize = useCallback((newSize) => {
    setPagination(prev => ({ ...prev, size: newSize, page: 0 }));
  }, []);

  return {
    data,
    loading,
    error,
    pagination,
    changePage,
    changeSize,
    refetch: fetchData,
  };
};
```

#### Report Filters Hook
```javascript
export const useReportFilters = (initialFilters = {}) => {
  const [filters, setFilters] = useState({
    facilityCode: '',
    payerCodes: [],
    fromDate: '',
    toDate: '',
    tab: 'A',
    ...initialFilters,
  });

  const updateFilter = useCallback((key, value) => {
    setFilters(prev => ({ ...prev, [key]: value }));
  }, []);

  const updateFilters = useCallback((newFilters) => {
    setFilters(prev => ({ ...prev, ...newFilters }));
  }, []);

  const resetFilters = useCallback(() => {
    setFilters({
      facilityCode: '',
      payerCodes: [],
      fromDate: '',
      toDate: '',
      tab: 'A',
    });
  }, []);

  return {
    filters,
    updateFilter,
    updateFilters,
    resetFilters,
  };
};
```

### React Components

#### Report Component
```javascript
import React from 'react';
import { useReportData, useReportFilters } from '../hooks/useReportData';

const BalanceAmountReport = ({ reportService }) => {
  const { filters, updateFilter, updateFilters } = useReportFilters();
  const { data, loading, error, pagination, changePage, changeSize } = useReportData(
    reportService,
    'BALANCE_AMOUNT',
    filters
  );

  const handleTabChange = (tab) => {
    updateFilter('tab', tab);
  };

  const handleDateRangeChange = (fromDate, toDate) => {
    updateFilters({ fromDate, toDate });
  };

  const handleFacilityChange = (facilityCode) => {
    updateFilter('facilityCode', facilityCode);
  };

  if (loading) {
    return <div className="loading">Loading report data...</div>;
  }

  if (error) {
    return <div className="error">Error: {error}</div>;
  }

  return (
    <div className="balance-amount-report">
      <div className="report-header">
        <h2>Balance Amount Report</h2>
        <div className="tab-buttons">
          <button 
            className={filters.tab === 'A' ? 'active' : ''}
            onClick={() => handleTabChange('A')}
          >
            Tab A: Overall Balances
          </button>
          <button 
            className={filters.tab === 'B' ? 'active' : ''}
            onClick={() => handleTabChange('B')}
          >
            Tab B: Initial Not Remitted
          </button>
          <button 
            className={filters.tab === 'C' ? 'active' : ''}
            onClick={() => handleTabChange('C')}
          >
            Tab C: Post-Resubmission
          </button>
        </div>
      </div>

      <div className="report-filters">
        <FacilitySelector 
          value={filters.facilityCode}
          onChange={handleFacilityChange}
        />
        <DateRangeSelector 
          fromDate={filters.fromDate}
          toDate={filters.toDate}
          onChange={handleDateRangeChange}
        />
      </div>

      <div className="report-content">
        <ReportTable data={data} />
        <Pagination 
          pagination={pagination}
          onPageChange={changePage}
          onSizeChange={changeSize}
        />
      </div>
    </div>
  );
};
```

#### Report Table Component
```javascript
const ReportTable = ({ data }) => {
  if (!data || data.length === 0) {
    return <div className="no-data">No data available</div>;
  }

  return (
    <div className="report-table">
      <table>
        <thead>
          <tr>
            <th>Facility Code</th>
            <th>Facility Name</th>
            <th>Claim ID</th>
            <th>Billed Amount</th>
            <th>Payment Amount</th>
            <th>Denied Amount</th>
            <th>Pending Amount</th>
            <th>Aging Days</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {data.map((row, index) => (
            <tr key={index}>
              <td>{row.facilityCode}</td>
              <td>{row.facilityName}</td>
              <td>{row.claimId}</td>
              <td>{formatCurrency(row.billedAmount)}</td>
              <td>{formatCurrency(row.paymentAmount)}</td>
              <td>{formatCurrency(row.deniedAmount)}</td>
              <td>{formatCurrency(row.pendingAmount)}</td>
              <td>{row.agingDays}</td>
              <td>{row.status}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};
```

## Error Handling

### Error Boundary Component
```javascript
class ReportErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('Report error:', error, errorInfo);
    // Log to error reporting service
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="error-boundary">
          <h2>Something went wrong with the report</h2>
          <p>{this.state.error?.message}</p>
          <button onClick={() => this.setState({ hasError: false, error: null })}>
            Try Again
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}
```

### API Error Handling
```javascript
class APIErrorHandler {
  static handleError(error) {
    if (error.status === 401) {
      // Unauthorized - redirect to login
      window.location.href = '/login';
    } else if (error.status === 403) {
      // Forbidden - show access denied message
      return 'Access denied. You do not have permission to view this report.';
    } else if (error.status === 404) {
      // Not found - show not found message
      return 'Report not found. Please check your request.';
    } else if (error.status === 500) {
      // Server error - show generic error message
      return 'Server error. Please try again later.';
    } else {
      // Generic error
      return error.message || 'An unexpected error occurred.';
    }
  }
}
```

## Data Visualization

### Chart Components
```javascript
import { LineChart, BarChart, PieChart } from 'recharts';

const ReportCharts = ({ data }) => {
  const chartData = data.map(item => ({
    name: item.facilityName,
    billed: item.billedAmount,
    paid: item.paymentAmount,
    pending: item.pendingAmount,
  }));

  return (
    <div className="report-charts">
      <div className="chart-container">
        <h3>Amounts by Facility</h3>
        <BarChart width={600} height={300} data={chartData}>
          <XAxis dataKey="name" />
          <YAxis />
          <Tooltip />
          <Legend />
          <Bar dataKey="billed" fill="#8884d8" />
          <Bar dataKey="paid" fill="#82ca9d" />
          <Bar dataKey="pending" fill="#ffc658" />
        </BarChart>
      </div>

      <div className="chart-container">
        <h3>Payment Status Distribution</h3>
        <PieChart width={400} height={300}>
          <Pie
            data={chartData}
            dataKey="paid"
            nameKey="name"
            cx="50%"
            cy="50%"
            outerRadius={80}
            fill="#8884d8"
          />
          <Tooltip />
          <Legend />
        </PieChart>
      </div>
    </div>
  );
};
```

## Caching Strategies

### Client-Side Caching
```javascript
class ReportCache {
  constructor() {
    this.cache = new Map();
    this.ttl = 5 * 60 * 1000; // 5 minutes
  }

  get(key) {
    const item = this.cache.get(key);
    if (!item) return null;

    if (Date.now() - item.timestamp > this.ttl) {
      this.cache.delete(key);
      return null;
    }

    return item.data;
  }

  set(key, data) {
    this.cache.set(key, {
      data,
      timestamp: Date.now(),
    });
  }

  generateKey(reportType, filters) {
    return `${reportType}_${JSON.stringify(filters)}`;
  }
}

// Usage in report service
class CachedReportService extends ReportService {
  constructor(authService) {
    super(authService);
    this.cache = new ReportCache();
  }

  async getReportData(reportType, requestData) {
    const cacheKey = this.cache.generateKey(reportType, requestData);
    const cachedData = this.cache.get(cacheKey);

    if (cachedData) {
      return cachedData;
    }

    const data = await super.getReportData(reportType, requestData);
    this.cache.set(cacheKey, data);
    return data;
  }
}
```

## Environment-Specific Configuration

### Environment Variables
```javascript
// .env.development
REACT_APP_API_BASE_URL=http://localhost:8080
REACT_APP_ENABLE_MOCK_AUTH=true
REACT_APP_LOG_LEVEL=debug

// .env.staging
REACT_APP_API_BASE_URL=https://staging-api.claims.com
REACT_APP_ENABLE_MOCK_AUTH=false
REACT_APP_LOG_LEVEL=info

// .env.production
REACT_APP_API_BASE_URL=https://api.claims.com
REACT_APP_ENABLE_MOCK_AUTH=false
REACT_APP_LOG_LEVEL=error
```

### Configuration Service
```javascript
class ConfigService {
  constructor() {
    this.config = {
      apiBaseURL: process.env.REACT_APP_API_BASE_URL || 'http://localhost:8080',
      enableMockAuth: process.env.REACT_APP_ENABLE_MOCK_AUTH === 'true',
      logLevel: process.env.REACT_APP_LOG_LEVEL || 'info',
    };
  }

  getApiBaseURL() {
    return this.config.apiBaseURL;
  }

  isMockAuthEnabled() {
    return this.config.enableMockAuth;
  }

  getLogLevel() {
    return this.config.logLevel;
  }
}
```

## Testing

### Unit Tests
```javascript
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { BalanceAmountReport } from './BalanceAmountReport';

describe('BalanceAmountReport', () => {
  const mockReportService = {
    getReportData: jest.fn(),
  };

  beforeEach(() => {
    mockReportService.getReportData.mockClear();
  });

  it('renders report with data', async () => {
    const mockData = {
      data: [
        {
          facilityCode: 'FAC001',
          facilityName: 'Test Hospital',
          claimId: 'CLM123',
          billedAmount: 1000,
          paymentAmount: 800,
          pendingAmount: 200,
        },
      ],
      totalElements: 1,
      totalPages: 1,
    };

    mockReportService.getReportData.mockResolvedValue(mockData);

    render(<BalanceAmountReport reportService={mockReportService} />);

    await waitFor(() => {
      expect(screen.getByText('Test Hospital')).toBeInTheDocument();
      expect(screen.getByText('CLM123')).toBeInTheDocument();
    });
  });

  it('handles tab changes', async () => {
    render(<BalanceAmountReport reportService={mockReportService} />);

    const tabBButton = screen.getByText('Tab B: Initial Not Remitted');
    fireEvent.click(tabBButton);

    await waitFor(() => {
      expect(mockReportService.getReportData).toHaveBeenCalledWith(
        'BALANCE_AMOUNT',
        expect.objectContaining({ tab: 'B' })
      );
    });
  });
});
```

### Integration Tests
```javascript
import { render, screen, waitFor } from '@testing-library/react';
import { AuthService, ReportService } from '../services';

describe('Report Integration', () => {
  it('fetches and displays report data', async () => {
    const authService = new AuthService();
    const reportService = new ReportService(authService);

    // Mock authentication
    jest.spyOn(authService, 'login').mockResolvedValue({
      access_token: 'mock-token',
    });

    // Mock report data
    jest.spyOn(reportService, 'getReportData').mockResolvedValue({
      data: [{ facilityCode: 'FAC001', facilityName: 'Test Hospital' }],
    });

    render(<BalanceAmountReport reportService={reportService} />);

    await waitFor(() => {
      expect(screen.getByText('Test Hospital')).toBeInTheDocument();
    });
  });
});
```

## Best Practices

### Development Best Practices
1. **Use TypeScript**: Add type safety to your React components
2. **Implement Error Boundaries**: Catch and handle errors gracefully
3. **Use Custom Hooks**: Encapsulate logic in reusable hooks
4. **Implement Loading States**: Show loading indicators during API calls
5. **Add Form Validation**: Validate user inputs before API calls

### Production Best Practices
1. **Implement Caching**: Cache report data to reduce API calls
2. **Add Retry Logic**: Retry failed API calls with exponential backoff
3. **Monitor Performance**: Track API response times and error rates
4. **Implement Offline Support**: Cache data for offline viewing
5. **Add Analytics**: Track user interactions with reports

### Security Best Practices
1. **Secure Token Storage**: Use secure storage for authentication tokens
2. **Validate Inputs**: Validate all user inputs on the client side
3. **Implement CSRF Protection**: Use CSRF tokens for state-changing operations
4. **Sanitize Data**: Sanitize data before displaying to prevent XSS
5. **Use HTTPS**: Always use HTTPS in production

## Related Documentation
- [API Reference](../api/REPORT_API_REFERENCE.md)
- [API Authentication Guide](../api/API_AUTHENTICATION_GUIDE.md)
- [API Error Codes](../api/API_ERROR_CODES.md)
- [Environment Behavior Guide](./ENVIRONMENT_BEHAVIOR_GUIDE.md)
- [Postman Collection Guide](./POSTMAN_COLLECTION_GUIDE.md)
