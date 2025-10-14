package com.acme.claims;

import com.acme.claims.util.MaterializedViewFixer;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Profile;

/**
 * Command line runner to fix materialized view duplicates
 * 
 * Usage: java -jar claims-backend.jar --spring.profiles.active=local --mv.fix.enabled=true
 */
@SpringBootApplication
@Profile("local")
public class MaterializedViewFixRunner implements CommandLineRunner {

    @Autowired
    private MaterializedViewFixer materializedViewFixer;

    public static void main(String[] args) {
        SpringApplication.run(MaterializedViewFixRunner.class, args);
    }

    @Override
    public void run(String... args) throws Exception {
        System.out.println("=== MATERIALIZED VIEW FIX RUNNER ===");
        System.out.println("This utility fixes duplicate key violations in materialized views");
        System.out.println("caused by multiple remittances per claim.");
        System.out.println();
        
        // Check if fix is enabled
        boolean fixEnabled = false;
        for (String arg : args) {
            if (arg.contains("mv.fix.enabled=true")) {
                fixEnabled = true;
                break;
            }
        }
        
        if (!fixEnabled) {
            System.out.println("Materialized view fix is not enabled.");
            System.out.println("To enable, add: --mv.fix.enabled=true");
            System.out.println("Example: java -jar claims-backend.jar --spring.profiles.active=local --mv.fix.enabled=true");
            return;
        }
        
        System.out.println("Materialized view fix is enabled. Starting fix process...");
        System.out.println();
        
        try {
            // Run the complete fix process
            materializedViewFixer.runCompleteFix();
            
            System.out.println("\n=== FIX COMPLETED SUCCESSFULLY ===");
            System.out.println("You can now run reports without duplicate key violations.");
            
        } catch (Exception e) {
            System.err.println("\n=== FIX FAILED ===");
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }
}
