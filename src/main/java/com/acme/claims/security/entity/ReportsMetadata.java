package com.acme.claims.security.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

/**
 * Reports metadata entity for managing report definitions and status
 */
@Entity
@Table(name = "reports_metadata", schema = "claims")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReportsMetadata {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "report_code", nullable = false, unique = true, length = 50)
    private String reportCode;
    
    @Column(name = "report_name", nullable = false, length = 100)
    private String reportName;
    
    @Column(name = "description", columnDefinition = "TEXT")
    private String description;
    
    @Column(name = "status", nullable = false, length = 1)
    private String status; // 'A' for Active, 'I' for Inactive
    
    @Column(name = "category", length = 50)
    private String category;
    
    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
    
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by")
    private User createdBy;
    
    /**
     * Check if the report is active
     */
    public boolean isActive() {
        return "A".equals(status);
    }
    
    /**
     * Check if the report is inactive
     */
    public boolean isInactive() {
        return "I".equals(status);
    }
}
