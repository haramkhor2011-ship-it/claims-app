# Multi-Tenancy Enablement TODOs

This document contains all the TODOs that need to be addressed when enabling multi-tenancy in the future.

## Configuration Changes

### 1. Enable Multi-Tenancy in application.yml
```yaml
claims:
  security:
    multi-tenancy:
      enabled: true  # Change from false to true
      default-facility-code: "DEFAULT"
```

## Code Changes Required

### 2. UserContext.java - Uncomment Multi-Tenancy Logic
**File**: `src/main/java/com/acme/claims/security/context/UserContext.java`
**Method**: `hasFacilityAccess(String facilityCode)`

**Current (Multi-tenancy disabled)**:
```java
// TODO: When multi-tenancy is enabled, uncomment the following logic:
// if (facilities == null) {
//     return false;
// }
// return facilities.contains(facilityCode);

// For now (multi-tenancy disabled), all authenticated users can access all facilities
return true;
```

**Required Change**:
```java
if (facilities == null) {
    return false;
}
return facilities.contains(facilityCode);
```

### 3. UserContextService.java - Uncomment Multi-Tenancy Logic
**File**: `src/main/java/com/acme/claims/security/service/UserContextService.java`
**Methods**: `buildUserContext()` and `buildServiceUserContext()`

**Current (Multi-tenancy disabled)**:
```java
// TODO: When multi-tenancy is enabled, uncomment the following logic:
// When multi-tenancy is disabled, return empty set to indicate no restrictions
if (!securityProperties.getMultiTenancy().isEnabled()) {
    log.debug("Multi-tenancy disabled - returning empty facilities set (no restrictions) for user: {}", user.getUsername());
    facilities = Set.of(); // Empty set means no facility restrictions
}
```

**Required Change**: Remove the if condition and let facilities be populated from database:
```java
// Get user facilities
Set<String> facilities = user.getFacilityCodes();
```

### 4. FacilityAdminController.java - Uncomment Access Control Logic
**File**: `src/main/java/com/acme/claims/admin/FacilityAdminController.java`

#### 4.1 Create/Update Facility Access Control
**Method**: `createOrUpdate()`

**Current (Multi-tenancy disabled)**:
```java
// TODO: When multi-tenancy is enabled, add facility access checks here
log.info("FACILITY_ADMIN {} managing facility {} (multi-tenancy disabled)", 
        userContext.getUsername(), dto.facilityCode());
```

**Required Change**:
```java
// Check if this is an existing facility that the user doesn't have access to
try {
    FacilityAdminService.FacilityView existingFacility = svc.get(dto.facilityCode());
    if (existingFacility != null && !userContext.hasFacilityAccess(dto.facilityCode())) {
        log.warn("User {} (ID: {}) attempted to update facility {} without permission", 
                userContext.getUsername(), userContext.getUserId(), dto.facilityCode());
        return ResponseEntity.status(403)
                .body(Map.of("error", "You can only manage facilities you have access to"));
    }
} catch (IllegalArgumentException e) {
    // Facility doesn't exist, FACILITY_ADMIN can create it
    log.info("Creating new facility {} by FACILITY_ADMIN {}", dto.facilityCode(), userContext.getUsername());
}
```

#### 4.2 Get Facility Access Control
**Method**: `get(String code)`

**Current (Multi-tenancy disabled)**:
```java
// TODO: When multi-tenancy is enabled, add facility access checks here
log.info("FACILITY_ADMIN {} accessing facility {} (multi-tenancy disabled)", 
        userContext.getUsername(), code);
```

**Required Change**:
```java
// Check if user has access to this facility (for FACILITY_ADMIN)
if (userContext.isFacilityAdmin() && !userContext.hasFacilityAccess(code)) {
    log.warn("User {} (ID: {}) attempted to access facility {} without permission", 
            userContext.getUsername(), userContext.getUserId(), code);
    return ResponseEntity.status(403).build();
}
```

#### 4.3 Activate/Deactivate Facility Access Control
**Method**: `activate(String code, boolean active)`

**Current (Multi-tenancy disabled)**:
```java
// TODO: When multi-tenancy is enabled, add facility access checks here
log.info("FACILITY_ADMIN {} {} facility {} (multi-tenancy disabled)", 
        userContext.getUsername(), active ? "activating" : "deactivating", code);
```

**Required Change**:
```java
// For FACILITY_ADMIN: Only allow managing facilities they have access to
if (userContext.isFacilityAdmin() && !userContext.isSuperAdmin()) {
    if (!userContext.hasFacilityAccess(code)) {
        log.warn("User {} (ID: {}) attempted to {} facility {} without permission", 
                userContext.getUsername(), userContext.getUserId(), 
                active ? "activate" : "deactivate", code);
        return ResponseEntity.status(403)
                .body(Map.of("error", "You can only manage facilities you have access to"));
    }
}
```

#### 4.4 List Facilities Access Control
**Method**: `getAllFacilities()`

**Current (Multi-tenancy disabled)**:
```java
// TODO: When multi-tenancy is enabled, implement proper facility filtering
Set<String> accessibleFacilities = userContext.getFacilities();
```

**Required Change**:
```java
// Get facilities based on user role
Set<String> accessibleFacilities = userContext.getFacilities();

// For super admin, get all facilities from database
if (userContext.isSuperAdmin()) {
    // TODO: Implement getAllFacilities() method in FacilityAdminService
    // For now, return user's assigned facilities
    log.info("Super admin {} requesting all facilities", userContext.getUsername());
}
```

### 5. JwtService.java - Uncomment Multi-Tenancy Logic
**File**: `src/main/java/com/acme/claims/security/service/JwtService.java`
**Method**: `generateAccessToken(User user)`

**Current (Multi-tenancy disabled)**:
```java
// TODO: When multi-tenancy is enabled, uncomment the following logic:
// When multi-tenancy is disabled, return empty facilities in JWT (no restrictions)
if (!securityProperties.getMultiTenancy().isEnabled()) {
    claims.put("facilities", new String[0]); // Empty array means no restrictions
    claims.put("primaryFacility", null); // No primary facility when multi-tenancy disabled
}
```

**Required Change**: Remove the if condition and let facilities be populated from database:
```java
claims.put("facilities", user.getFacilityCodes());
claims.put("primaryFacility", user.getPrimaryFacilityCode());
```

### 6. AuthenticationController.java - Uncomment Multi-Tenancy Logic
**File**: `src/main/java/com/acme/claims/security/controller/AuthenticationController.java`
**Method**: `login()` response building

**Current (Multi-tenancy disabled)**:
```java
// TODO: When multi-tenancy is enabled, uncomment the following logic:
// When multi-tenancy is disabled, return empty facilities in response (no restrictions)
if (!securityProperties.getMultiTenancy().isEnabled()) {
    response.getUser().facilities = List.of(); // Empty list means no restrictions
    response.getUser().primaryFacility = null; // No primary facility when multi-tenancy disabled
}
```

**Required Change**: Remove the if condition and let facilities be populated from database.

### 7. AdminController.java - Uncomment Multi-Tenancy Logic
**File**: `src/main/java/com/acme/claims/security/controller/AdminController.java`
**Method**: `getLockedAccounts()`

**Current (Multi-tenancy disabled)**:
```java
// TODO: When multi-tenancy is enabled, uncomment the following logic:
// Facility admins can only see users from their facilities
// if (currentUser.hasRole(com.acme.claims.security.Role.FACILITY_ADMIN)) {
//     Set<String> currentUserFacilities = currentUser.getFacilityCodes();
//     return user.getFacilityCodes().stream()
//             .anyMatch(currentUserFacilities::contains);
// }
return true; // When multi-tenancy disabled, all users can see all locked accounts
```

**Required Change**: Uncomment the facility filtering logic.

### 8. UserController.java - Uncomment Multi-Tenancy Logic
**File**: `src/main/java/com/acme/claims/security/controller/UserController.java`
**Methods**: `getAllUsers()` and `UserResponse.fromUser()`

**Current (Multi-tenancy disabled)**:
```java
// TODO: When multi-tenancy is enabled, uncomment the following logic:
// Facility admin can only see users from their facilities
// Set<String> facilityCodes = currentUser.getFacilityCodes();
// users = userService.getAllUsers().stream()
//         .filter(user -> user.getFacilityCodes().stream()
//                 .anyMatch(facilityCodes::contains))
//         .toList();

// When multi-tenancy disabled, facility admins can see all users
users = userService.getAllUsers();
```

**Required Change**: Uncomment the facility filtering logic and remove the fallback.

**Current (Multi-tenancy disabled)**:
```java
// TODO: When multi-tenancy is enabled, uncomment the following logic:
// When multi-tenancy is disabled, return empty facilities (no restrictions)
if (!securityProperties.getMultiTenancy().isEnabled()) {
    response.facilities = List.of(); // Empty list means no restrictions
    response.primaryFacility = null; // No primary facility when multi-tenancy disabled
}
```

**Required Change**: Remove the if condition and let facilities be populated from database.

## Database Setup Required

### 5. Populate user_facilities Table
When enabling multi-tenancy, ensure all users have appropriate facility assignments:

```sql
-- Example: Assign FACILITY_ADMIN users to their facilities
INSERT INTO claims.user_facilities (user_id, facility_code, is_primary) 
SELECT u.id, 'FACILITY_001', true 
FROM claims.users u 
JOIN claims.user_roles ur ON u.id = ur.user_id 
WHERE ur.role = 'FACILITY_ADMIN';

-- Example: Assign STAFF users to their facilities
INSERT INTO claims.user_facilities (user_id, facility_code, is_primary) 
SELECT u.id, 'FACILITY_001', true 
FROM claims.users u 
JOIN claims.user_roles ur ON u.id = ur.user_id 
WHERE ur.role = 'STAFF';
```

## Testing Required

### 6. Test Multi-Tenancy Functionality
1. **Test facility access control** - Verify FACILITY_ADMIN can only access assigned facilities
2. **Test data filtering** - Verify reports show only data from assigned facilities
3. **Test facility management** - Verify FACILITY_ADMIN can only manage assigned facilities
4. **Test super admin access** - Verify SUPER_ADMIN retains full access

## Rollback Plan

### 7. Rollback Multi-Tenancy
If issues arise, rollback by:
1. Set `claims.security.multi-tenancy.enabled: false` in application.yml
2. Revert code changes using this TODO list
3. Restart application

## Notes

- **DataFilteringService** already properly respects the multi-tenancy toggle
- **ServiceUserContext.hasFacilityAccess()** already handles empty facilities correctly
- All access control logic is already implemented, just commented out
- Multi-tenancy can be enabled/disabled without code changes to core filtering logic
