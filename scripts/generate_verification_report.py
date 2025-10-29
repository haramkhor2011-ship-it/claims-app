#!/usr/bin/env python3
"""
Report Generator for SQL Verification
Generates markdown reports with high-level summaries and detailed comparisons
"""

import os
from typing import Dict, List
from sql_parser import SQLParser, SQLObject
from sql_comparator import SQLComparator, ComparisonResult

class ReportGenerator:
    def __init__(self, output_dir: str = "docs/verification"):
        self.output_dir = output_dir
        self.parser = SQLParser()
        self.comparator = SQLComparator()
        
        # Ensure output directory exists
        os.makedirs(output_dir, exist_ok=True)
        os.makedirs(f"{output_dir}/checklists", exist_ok=True)
    
    def generate_all_reports(self) -> None:
        """Generate all verification reports"""
        print("Generating SQL verification reports...")
        
        # Define file pairs to compare
        file_pairs = [
            {
                'source': '../src/main/resources/db/claims_unified_ddl_fresh.sql',
                'docker': '../docker/db-init/02-core-tables.sql',
                'report': '02-core-tables-verification.md',
                'title': 'Core Tables Verification'
            },
            {
                'source': '../src/main/resources/db/claims_ref_ddl.sql',
                'docker': '../docker/db-init/03-ref-data-tables.sql',
                'report': '03-ref-data-tables-verification.md',
                'title': 'Reference Data Tables Verification'
            },
            {
                'source': '../src/main/resources/db/dhpo_config.sql',
                'docker': '../docker/db-init/04-dhpo-config.sql',
                'report': '04-dhpo-config-verification.md',
                'title': 'DHPO Configuration Verification'
            },
            {
                'source': '../src/main/resources/db/user_management_schema.sql',
                'docker': '../docker/db-init/05-user-management.sql',
                'report': '05-user-management-verification.md',
                'title': 'User Management Verification'
            },
            {
                'source': '../src/main/resources/db/reports_sql/',
                'docker': '../docker/db-init/06-report-views.sql',
                'report': '06-report-views-verification.md',
                'title': 'Report Views Verification'
            },
            {
                'source': '../src/main/resources/db/reports_sql/sub_second_materialized_views.sql',
                'docker': '../docker/db-init/07-materialized-views.sql',
                'report': '07-materialized-views-verification.md',
                'title': 'Materialized Views Verification'
            },
            {
                'source': '../src/main/resources/db/claim_payment_functions.sql',
                'docker': '../docker/db-init/08-functions-procedures.sql',
                'report': '08-functions-procedures-verification.md',
                'title': 'Functions and Procedures Verification'
            }
        ]
        
        all_results = []
        
        for pair in file_pairs:
            print(f"Processing {pair['title']}...")
            
            if pair['source'].endswith('/'):
                # Handle multiple source files (like reports_sql/)
                results = self._process_multiple_sources(pair)
            else:
                results = self._process_single_pair(pair)
            
            all_results.extend(results)
            
            # Generate individual report
            self._generate_individual_report(pair, results)
        
        # Generate master summary
        self._generate_master_summary(all_results)
        
        # Generate checklists
        self._generate_checklists()
        
        print(f"All reports generated in {self.output_dir}/")
    
    def _process_single_pair(self, pair: Dict) -> List[ComparisonResult]:
        """Process a single source-docker file pair"""
        if not os.path.exists(pair['source']) or not os.path.exists(pair['docker']):
            print(f"Warning: Files not found for {pair['title']}")
            return []
        
        source_objects = self.parser.parse_file(pair['source'])
        docker_objects = self.parser.parse_file(pair['docker'])
        
        return self.comparator.compare_files(source_objects, docker_objects)
    
    def _process_multiple_sources(self, pair: Dict) -> List[ComparisonResult]:
        """Process multiple source files against one docker file"""
        source_dir = pair['source']
        docker_file = pair['docker']
        
        if not os.path.exists(docker_file):
            print(f"Warning: Docker file not found: {docker_file}")
            return []
        
        # Get all SQL files in source directory
        source_files = []
        if os.path.exists(source_dir):
            for file in os.listdir(source_dir):
                if file.endswith('.sql'):
                    source_files.append(os.path.join(source_dir, file))
        
        if not source_files:
            print(f"Warning: No SQL files found in {source_dir}")
            return []
        
        # Parse all source files
        all_source_objects = []
        for source_file in source_files:
            objects = self.parser.parse_file(source_file)
            all_source_objects.extend(objects)
        
        # Parse docker file
        docker_objects = self.parser.parse_file(docker_file)
        
        return self.comparator.compare_files(all_source_objects, docker_objects)
    
    def _generate_individual_report(self, pair: Dict, results: List[ComparisonResult]) -> None:
        """Generate individual verification report"""
        report_path = os.path.join(self.output_dir, pair['report'])
        
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write(f"# {pair['title']}\n\n")
            f.write(f"**Generated:** {self._get_timestamp()}\n\n")
            
            # Summary section
            f.write("## Summary\n\n")
            summary_stats = self._calculate_summary_stats(results)
            f.write(f"- **Source Files:** {pair['source']}\n")
            f.write(f"- **Docker File:** {pair['docker']}\n")
            f.write(f"- **Total Objects Expected:** {summary_stats['total_expected']}\n")
            f.write(f"- **Total Objects Found:** {summary_stats['total_found']}\n")
            f.write(f"- **Completeness:** {summary_stats['completeness']:.1f}%\n")
            f.write(f"- **Overall Accuracy:** {summary_stats['accuracy']:.1f}%\n\n")
            
            # Objects overview
            f.write("## Objects Overview\n\n")
            f.write("| Object Name | Type | Status | Completeness | Accuracy | Notes |\n")
            f.write("|-------------|------|--------|--------------|----------|-------|\n")
            
            for result in results:
                status_icon = self._get_status_icon(result.status)
                f.write(f"| {result.object_name} | {result.object_type.value} | {status_icon} | {result.completeness_percentage:.1f}% | {result.accuracy_percentage:.1f}% | {self._get_result_notes(result)} |\n")
            
            f.write("\n")
            
            # Missing objects
            missing_objects = [r for r in results if r.status == 'MISSING']
            if missing_objects:
                f.write("## Missing Objects\n\n")
                for result in missing_objects:
                    f.write(f"- **{result.object_name}** ({result.object_type.value})\n")
                f.write("\n")
            
            # Extra objects
            extra_objects = [r for r in results if r.status == 'EXTRA']
            if extra_objects:
                f.write("## Extra Objects\n\n")
                for result in extra_objects:
                    f.write(f"- **{result.object_name}** ({result.object_type.value})\n")
                f.write("\n")
            
            # Issues found
            issues = [r for r in results if r.differences]
            if issues:
                f.write("## Issues Found\n\n")
                for result in issues:
                    f.write(f"### {result.object_name}\n\n")
                    for diff in result.differences:
                        f.write(f"- {diff}\n")
                    f.write("\n")
            
            # Detailed comparisons
            f.write("## Detailed Comparisons\n\n")
            for result in results:
                if result.status in ['DIFFERENT', 'MISSING', 'EXTRA']:
                    self._write_detailed_comparison(f, result)
    
    def _write_detailed_comparison(self, f, result: ComparisonResult) -> None:
        """Write detailed comparison for a single object"""
        f.write(f"### {result.object_name}\n\n")
        
        f.write(f"**Type:** {result.object_type.value}\n")
        f.write(f"**Status:** {result.status}\n")
        f.write(f"**Completeness:** {result.completeness_percentage:.1f}%\n")
        f.write(f"**Accuracy:** {result.accuracy_percentage:.1f}%\n\n")
        
        if result.missing_components:
            f.write("**Missing Components:**\n")
            for comp in result.missing_components:
                f.write(f"- {comp}\n")
            f.write("\n")
        
        if result.extra_components:
            f.write("**Extra Components:**\n")
            for comp in result.extra_components:
                f.write(f"- {comp}\n")
            f.write("\n")
        
        if result.line_by_line_diff:
            f.write("**Line-by-Line Diff:**\n")
            f.write("```diff\n")
            for line in result.line_by_line_diff[:50]:  # Limit to first 50 lines
                f.write(f"{line}\n")
            if len(result.line_by_line_diff) > 50:
                f.write("... (truncated)\n")
            f.write("```\n\n")
    
    def _generate_master_summary(self, all_results: List[ComparisonResult]) -> None:
        """Generate master summary report"""
        report_path = os.path.join(self.output_dir, "00-MASTER-VERIFICATION-SUMMARY.md")
        
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write("# Master Verification Summary\n\n")
            f.write(f"**Generated:** {self._get_timestamp()}\n\n")
            
            # Overall statistics
            total_objects = len(all_results)
            matching_objects = len([r for r in all_results if r.status == 'MATCH'])
            different_objects = len([r for r in all_results if r.status == 'DIFFERENT'])
            missing_objects = len([r for r in all_results if r.status == 'MISSING'])
            extra_objects = len([r for r in all_results if r.status == 'EXTRA'])
            
            avg_completeness = sum(r.completeness_percentage for r in all_results) / total_objects if total_objects > 0 else 0
            avg_accuracy = sum(r.accuracy_percentage for r in all_results) / total_objects if total_objects > 0 else 0
            
            f.write("## Overall Statistics\n\n")
            f.write(f"- **Total Objects:** {total_objects}\n")
            if total_objects > 0:
                f.write(f"- **Matching Objects:** {matching_objects} ({matching_objects/total_objects*100:.1f}%)\n")
                f.write(f"- **Different Objects:** {different_objects} ({different_objects/total_objects*100:.1f}%)\n")
                f.write(f"- **Missing Objects:** {missing_objects} ({missing_objects/total_objects*100:.1f}%)\n")
                f.write(f"- **Extra Objects:** {extra_objects} ({extra_objects/total_objects*100:.1f}%)\n")
            else:
                f.write(f"- **Matching Objects:** {matching_objects} (0.0%)\n")
                f.write(f"- **Different Objects:** {different_objects} (0.0%)\n")
                f.write(f"- **Missing Objects:** {missing_objects} (0.0%)\n")
                f.write(f"- **Extra Objects:** {extra_objects} (0.0%)\n")
            f.write(f"- **Average Completeness:** {avg_completeness:.1f}%\n")
            f.write(f"- **Average Accuracy:** {avg_accuracy:.1f}%\n\n")
            
            # Summary by object type
            f.write("## Summary by Object Type\n\n")
            f.write("| Type | Total | Matching | Different | Missing | Extra | Avg Completeness | Avg Accuracy |\n")
            f.write("|------|-------|----------|-----------|---------|-------|------------------|-------------|\n")
            
            type_stats = {}
            for result in all_results:
                obj_type = result.object_type.value
                if obj_type not in type_stats:
                    type_stats[obj_type] = {
                        'total': 0, 'matching': 0, 'different': 0, 'missing': 0, 'extra': 0,
                        'completeness': [], 'accuracy': []
                    }
                
                type_stats[obj_type]['total'] += 1
                status_key = result.status.lower()
                if status_key == 'match':
                    status_key = 'matching'
                type_stats[obj_type][status_key] += 1
                type_stats[obj_type]['completeness'].append(result.completeness_percentage)
                type_stats[obj_type]['accuracy'].append(result.accuracy_percentage)
            
            for obj_type, stats in type_stats.items():
                avg_comp = sum(stats['completeness']) / len(stats['completeness']) if stats['completeness'] else 0
                avg_acc = sum(stats['accuracy']) / len(stats['accuracy']) if stats['accuracy'] else 0
                
                f.write(f"| {obj_type} | {stats['total']} | {stats['matching']} | {stats['different']} | {stats['missing']} | {stats['extra']} | {avg_comp:.1f}% | {avg_acc:.1f}% |\n")
            
            f.write("\n")
            
            # Critical issues
            critical_issues = [r for r in all_results if r.status in ['MISSING', 'DIFFERENT'] and r.completeness_percentage < 80]
            if critical_issues:
                f.write("## Critical Issues (Completeness < 80%)\n\n")
                for result in critical_issues:
                    f.write(f"- **{result.object_name}** ({result.object_type.value}): {result.completeness_percentage:.1f}% complete\n")
                f.write("\n")
            
            # Recommendations
            f.write("## Recommendations\n\n")
            if missing_objects > 0:
                f.write(f"- **{missing_objects} objects** are missing from Docker files and need to be added\n")
            if different_objects > 0:
                f.write(f"- **{different_objects} objects** have differences and need to be reviewed/corrected\n")
            if extra_objects > 0:
                f.write(f"- **{extra_objects} objects** exist in Docker but not in source (verify if intentional)\n")
            
            if avg_completeness < 95:
                f.write(f"- Overall completeness is {avg_completeness:.1f}% - aim for 95%+\n")
            if avg_accuracy < 95:
                f.write(f"- Overall accuracy is {avg_accuracy:.1f}% - aim for 95%+\n")
    
    def _generate_checklists(self) -> None:
        """Generate verification checklists"""
        checklist_path = os.path.join(self.output_dir, "checklists", "verification-checklist.md")
        
        with open(checklist_path, 'w', encoding='utf-8') as f:
            f.write("# SQL Verification Checklist\n\n")
            f.write("Use this checklist to manually verify critical SQL objects.\n\n")
            
            # General checklist
            f.write("## General Verification Checklist\n\n")
            f.write("- [ ] All source files have been parsed successfully\n")
            f.write("- [ ] All Docker files have been parsed successfully\n")
            f.write("- [ ] No critical objects are missing from Docker files\n")
            f.write("- [ ] No unexpected objects exist in Docker files\n")
            f.write("- [ ] All differences have been reviewed and documented\n")
            f.write("- [ ] All intentional differences have been justified\n\n")
            
            # Object-specific checklists
            object_types = ['VIEW', 'MATERIALIZED_VIEW', 'FUNCTION', 'TABLE', 'INDEX', 'TRIGGER', 'GRANT']
            
            for obj_type in object_types:
                f.write(f"## {obj_type} Verification Checklist\n\n")
                f.write(f"### For each {obj_type}:\n")
                f.write("- [ ] Object name matches exactly\n")
                f.write("- [ ] Object type is correct\n")
                
                if obj_type in ['VIEW', 'MATERIALIZED_VIEW']:
                    f.write("- [ ] All columns are present and in correct order\n")
                    f.write("- [ ] All CTEs/subqueries are present\n")
                    f.write("- [ ] All JOINs are correct (type, tables, conditions)\n")
                    f.write("- [ ] WHERE clause is complete and accurate\n")
                    f.write("- [ ] GROUP BY clause matches\n")
                    f.write("- [ ] ORDER BY clause matches\n")
                    f.write("- [ ] All comments are preserved\n")
                
                elif obj_type == 'FUNCTION':
                    f.write("- [ ] Function parameters match exactly\n")
                    f.write("- [ ] Return type matches\n")
                    f.write("- [ ] Function body/logic is identical\n")
                    f.write("- [ ] All comments are preserved\n")
                
                elif obj_type == 'TABLE':
                    f.write("- [ ] All columns are present\n")
                    f.write("- [ ] Column data types match\n")
                    f.write("- [ ] All constraints are present\n")
                    f.write("- [ ] All indexes are present\n")
                    f.write("- [ ] All triggers are present\n")
                    f.write("- [ ] All comments are preserved\n")
                
                elif obj_type == 'INDEX':
                    f.write("- [ ] Index name matches\n")
                    f.write("- [ ] Index type (UNIQUE, etc.) matches\n")
                    f.write("- [ ] Indexed columns match\n")
                    f.write("- [ ] Index options match\n")
                
                elif obj_type == 'TRIGGER':
                    f.write("- [ ] Trigger name matches\n")
                    f.write("- [ ] Trigger timing matches\n")
                    f.write("- [ ] Trigger events match\n")
                    f.write("- [ ] Trigger function matches\n")
                
                elif obj_type == 'GRANT':
                    f.write("- [ ] Privileges match\n")
                    f.write("- [ ] Target object matches\n")
                    f.write("- [ ] Grantee matches\n")
                
                f.write("- [ ] GRANT statements are present (if applicable)\n")
                f.write("- [ ] Sign-off: [ ] Verified by: ___________ Date: ___________\n\n")
    
    def _calculate_summary_stats(self, results: List[ComparisonResult]) -> Dict:
        """Calculate summary statistics for results"""
        total_expected = len(results)
        total_found = len([r for r in results if r.status != 'MISSING'])
        
        if total_expected > 0:
            completeness = sum(r.completeness_percentage for r in results) / total_expected
            accuracy = sum(r.accuracy_percentage for r in results) / total_expected
        else:
            completeness = accuracy = 0
        
        return {
            'total_expected': total_expected,
            'total_found': total_found,
            'completeness': completeness,
            'accuracy': accuracy
        }
    
    def _get_status_icon(self, status: str) -> str:
        """Get status icon for markdown table"""
        icons = {
            'MATCH': '✓',
            'DIFFERENT': '⚠',
            'MISSING': '✗',
            'EXTRA': '?'
        }
        return icons.get(status, '?')
    
    def _get_result_notes(self, result: ComparisonResult) -> str:
        """Get notes for result"""
        if result.status == 'MATCH':
            return 'Perfect match'
        elif result.status == 'MISSING':
            return 'Missing from Docker'
        elif result.status == 'EXTRA':
            return 'Extra in Docker'
        else:
            return f"{len(result.differences)} differences"
    
    def _get_timestamp(self) -> str:
        """Get current timestamp"""
        from datetime import datetime
        return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

if __name__ == "__main__":
    generator = ReportGenerator()
    generator.generate_all_reports()
