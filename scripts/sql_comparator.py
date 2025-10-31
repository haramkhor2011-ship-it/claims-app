#!/usr/bin/env python3
"""
SQL Comparator for Database Object Comparison
Compares SQL objects between source and Docker files
"""

import difflib
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
from sql_parser import SQLObject, SQLObjectType

@dataclass
class ComparisonResult:
    object_name: str
    object_type: SQLObjectType
    status: str  # 'MATCH', 'DIFFERENT', 'MISSING', 'EXTRA'
    completeness_percentage: float
    accuracy_percentage: float
    differences: List[str]
    missing_components: List[str]
    extra_components: List[str]
    line_by_line_diff: List[str]

class SQLComparator:
    def __init__(self):
        self.results = []
    
    def compare_files(self, source_objects: List[SQLObject], docker_objects: List[SQLObject]) -> List[ComparisonResult]:
        """Compare objects between source and Docker files"""
        self.results = []
        
        # Create lookup dictionaries
        source_lookup = {obj.name: obj for obj in source_objects}
        docker_lookup = {obj.name: obj for obj in docker_objects}
        
        # Find all unique object names
        all_names = set(source_lookup.keys()) | set(docker_lookup.keys())
        
        for name in all_names:
            source_obj = source_lookup.get(name)
            docker_obj = docker_lookup.get(name)
            
            if source_obj and docker_obj:
                # Both exist - compare them
                result = self._compare_objects(source_obj, docker_obj)
            elif source_obj and not docker_obj:
                # Missing in Docker
                result = ComparisonResult(
                    object_name=name,
                    object_type=source_obj.type,
                    status='MISSING',
                    completeness_percentage=0.0,
                    accuracy_percentage=0.0,
                    differences=[f"Object '{name}' exists in source but missing in Docker"],
                    missing_components=[],
                    extra_components=[],
                    line_by_line_diff=[]
                )
            else:
                # Extra in Docker
                result = ComparisonResult(
                    object_name=name,
                    object_type=docker_obj.type,
                    status='EXTRA',
                    completeness_percentage=0.0,
                    accuracy_percentage=0.0,
                    differences=[f"Object '{name}' exists in Docker but not in source"],
                    missing_components=[],
                    extra_components=[],
                    line_by_line_diff=[]
                )
            
            self.results.append(result)
        
        return self.results
    
    def _compare_objects(self, source_obj: SQLObject, docker_obj: SQLObject) -> ComparisonResult:
        """Compare two SQL objects in detail"""
        differences = []
        missing_components = []
        extra_components = []
        
        # Compare basic properties
        if source_obj.type != docker_obj.type:
            differences.append(f"Type mismatch: source={source_obj.type.value}, docker={docker_obj.type.value}")
        
        # Compare columns
        column_comparison = self._compare_columns(source_obj.columns, docker_obj.columns)
        differences.extend(column_comparison['differences'])
        missing_components.extend(column_comparison['missing'])
        extra_components.extend(column_comparison['extra'])
        
        # Compare CTEs
        cte_comparison = self._compare_ctes(source_obj.ctes, docker_obj.ctes)
        differences.extend(cte_comparison['differences'])
        missing_components.extend(cte_comparison['missing'])
        extra_components.extend(cte_comparison['extra'])
        
        # Compare JOINs
        join_comparison = self._compare_joins(source_obj.joins, docker_obj.joins)
        differences.extend(join_comparison['differences'])
        missing_components.extend(join_comparison['missing'])
        extra_components.extend(join_comparison['extra'])
        
        # Compare WHERE clause
        where_comparison = self._compare_clauses(source_obj.where_clause, docker_obj.where_clause, "WHERE")
        differences.extend(where_comparison['differences'])
        
        # Compare GROUP BY clause
        group_by_comparison = self._compare_clauses(source_obj.group_by, docker_obj.group_by, "GROUP BY")
        differences.extend(group_by_comparison['differences'])
        
        # Compare ORDER BY clause
        order_by_comparison = self._compare_clauses(source_obj.order_by, docker_obj.order_by, "ORDER BY")
        differences.extend(order_by_comparison['differences'])
        
        # Compare comments
        comment_comparison = self._compare_comments(source_obj.comments, docker_obj.comments)
        differences.extend(comment_comparison['differences'])
        
        # Compare function-specific properties
        if source_obj.type == SQLObjectType.FUNCTION:
            func_comparison = self._compare_functions(source_obj, docker_obj)
            differences.extend(func_comparison['differences'])
            missing_components.extend(func_comparison['missing'])
            extra_components.extend(func_comparison['extra'])
        
        # Generate line-by-line diff
        line_by_line_diff = self._generate_line_diff(source_obj.definition, docker_obj.definition)
        
        # Calculate completeness and accuracy percentages
        completeness = self._calculate_completeness(source_obj, docker_obj)
        accuracy = self._calculate_accuracy(source_obj, docker_obj)
        
        # Determine status
        if not differences:
            status = 'MATCH'
        else:
            status = 'DIFFERENT'
        
        return ComparisonResult(
            object_name=source_obj.name,
            object_type=source_obj.type,
            status=status,
            completeness_percentage=completeness,
            accuracy_percentage=accuracy,
            differences=differences,
            missing_components=missing_components,
            extra_components=extra_components,
            line_by_line_diff=line_by_line_diff
        )
    
    def _compare_columns(self, source_cols: List[str], docker_cols: List[str]) -> Dict:
        """Compare column lists"""
        differences = []
        missing = []
        extra = []
        
        source_set = set(source_cols)
        docker_set = set(docker_cols)
        
        missing_cols = source_set - docker_set
        extra_cols = docker_set - source_set
        
        if missing_cols:
            missing.extend([f"Missing column: {col}" for col in missing_cols])
            differences.append(f"Missing columns: {', '.join(missing_cols)}")
        
        if extra_cols:
            extra.extend([f"Extra column: {col}" for col in extra_cols])
            differences.append(f"Extra columns: {', '.join(extra_cols)}")
        
        # Check order differences
        if source_cols != docker_cols and not missing_cols and not extra_cols:
            differences.append("Column order differs")
        
        return {
            'differences': differences,
            'missing': missing,
            'extra': extra
        }
    
    def _compare_ctes(self, source_ctes: List[Dict], docker_ctes: List[Dict]) -> Dict:
        """Compare CTE lists"""
        differences = []
        missing = []
        extra = []
        
        source_names = {cte['name'] for cte in source_ctes}
        docker_names = {cte['name'] for cte in docker_ctes}
        
        missing_ctes = source_names - docker_names
        extra_ctes = docker_names - source_names
        
        if missing_ctes:
            missing.extend([f"Missing CTE: {cte}" for cte in missing_ctes])
            differences.append(f"Missing CTEs: {', '.join(missing_ctes)}")
        
        if extra_ctes:
            extra.extend([f"Extra CTE: {cte}" for cte in extra_ctes])
            differences.append(f"Extra CTEs: {', '.join(extra_ctes)}")
        
        # Compare CTE definitions for common CTEs
        common_ctes = source_names & docker_names
        for cte_name in common_ctes:
            source_cte = next(cte for cte in source_ctes if cte['name'] == cte_name)
            docker_cte = next(cte for cte in docker_ctes if cte['name'] == cte_name)
            
            if source_cte['definition'] != docker_cte['definition']:
                differences.append(f"CTE '{cte_name}' definition differs")
        
        return {
            'differences': differences,
            'missing': missing,
            'extra': extra
        }
    
    def _compare_joins(self, source_joins: List[Dict], docker_joins: List[Dict]) -> Dict:
        """Compare JOIN lists"""
        differences = []
        missing = []
        extra = []
        
        # Create comparable representations
        source_join_strs = [f"{join['type']} {join['table']} ON {join['condition']}" for join in source_joins]
        docker_join_strs = [f"{join['type']} {join['table']} ON {join['condition']}" for join in docker_joins]
        
        source_set = set(source_join_strs)
        docker_set = set(docker_join_strs)
        
        missing_joins = source_set - docker_set
        extra_joins = docker_set - source_set
        
        if missing_joins:
            missing.extend([f"Missing JOIN: {join}" for join in missing_joins])
            differences.append(f"Missing JOINs: {len(missing_joins)}")
        
        if extra_joins:
            extra.extend([f"Extra JOIN: {join}" for join in extra_joins])
            differences.append(f"Extra JOINs: {len(extra_joins)}")
        
        return {
            'differences': differences,
            'missing': missing,
            'extra': extra
        }
    
    def _compare_clauses(self, source_clause: Optional[str], docker_clause: Optional[str], clause_type: str) -> Dict:
        """Compare WHERE/GROUP BY/ORDER BY clauses"""
        differences = []
        
        if source_clause != docker_clause:
            if source_clause is None:
                differences.append(f"Missing {clause_type} clause in Docker")
            elif docker_clause is None:
                differences.append(f"Missing {clause_type} clause in source")
            else:
                differences.append(f"{clause_type} clause differs")
        
        return {
            'differences': differences,
            'missing': [],
            'extra': []
        }
    
    def _compare_comments(self, source_comments: List[str], docker_comments: List[str]) -> Dict:
        """Compare comment lists"""
        differences = []
        
        source_set = set(source_comments)
        docker_set = set(docker_comments)
        
        missing_comments = source_set - docker_set
        extra_comments = docker_set - source_set
        
        if missing_comments:
            differences.append(f"Missing comments: {len(missing_comments)}")
        
        if extra_comments:
            differences.append(f"Extra comments: {len(extra_comments)}")
        
        return {
            'differences': differences,
            'missing': [],
            'extra': []
        }
    
    def _compare_functions(self, source_func: SQLObject, docker_func: SQLObject) -> Dict:
        """Compare function-specific properties"""
        differences = []
        missing = []
        extra = []
        
        # Compare parameters
        if source_func.parameters != docker_func.parameters:
            differences.append("Function parameters differ")
        
        # Compare return type
        if source_func.return_type != docker_func.return_type:
            differences.append(f"Return type differs: source={source_func.return_type}, docker={docker_func.return_type}")
        
        return {
            'differences': differences,
            'missing': missing,
            'extra': extra
        }
    
    def _generate_line_diff(self, source_def: str, docker_def: str) -> List[str]:
        """Generate line-by-line diff between definitions"""
        source_lines = source_def.splitlines()
        docker_lines = docker_def.splitlines()
        
        diff = list(difflib.unified_diff(
            source_lines,
            docker_lines,
            fromfile='source',
            tofile='docker',
            lineterm=''
        ))
        
        return diff
    
    def _calculate_completeness(self, source_obj: SQLObject, docker_obj: SQLObject) -> float:
        """Calculate completeness percentage"""
        total_components = 0
        matching_components = 0
        
        # Count columns
        total_components += len(source_obj.columns)
        matching_components += len(set(source_obj.columns) & set(docker_obj.columns))
        
        # Count CTEs
        total_components += len(source_obj.ctes)
        source_cte_names = {cte['name'] for cte in source_obj.ctes}
        docker_cte_names = {cte['name'] for cte in docker_obj.ctes}
        matching_components += len(source_cte_names & docker_cte_names)
        
        # Count JOINs
        total_components += len(source_obj.joins)
        source_join_strs = [f"{join['type']} {join['table']}" for join in source_obj.joins]
        docker_join_strs = [f"{join['type']} {join['table']}" for join in docker_obj.joins]
        matching_components += len(set(source_join_strs) & set(docker_join_strs))
        
        # Count clauses
        clauses = ['where_clause', 'group_by', 'order_by']
        for clause in clauses:
            source_clause = getattr(source_obj, clause)
            docker_clause = getattr(docker_obj, clause)
            if source_clause:
                total_components += 1
                if source_clause == docker_clause:
                    matching_components += 1
        
        if total_components == 0:
            return 100.0
        
        return (matching_components / total_components) * 100
    
    def _calculate_accuracy(self, source_obj: SQLObject, docker_obj: SQLObject) -> float:
        """Calculate accuracy percentage based on definition similarity"""
        source_def = source_obj.definition
        docker_def = docker_obj.definition
        
        # Normalize whitespace
        source_normalized = ' '.join(source_def.split())
        docker_normalized = ' '.join(docker_def.split())
        
        # Calculate similarity using difflib
        matcher = difflib.SequenceMatcher(None, source_normalized, docker_normalized)
        return matcher.ratio() * 100

if __name__ == "__main__":
    import sys
    from sql_parser import SQLParser
    
    if len(sys.argv) != 3:
        print("Usage: python sql_comparator.py <source_file> <docker_file>")
        sys.exit(1)
    
    parser = SQLParser()
    source_objects = parser.parse_file(sys.argv[1])
    docker_objects = parser.parse_file(sys.argv[2])
    
    comparator = SQLComparator()
    results = comparator.compare_files(source_objects, docker_objects)
    
    print(f"Comparison Results:")
    for result in results:
        print(f"- {result.object_name} ({result.object_type.value}): {result.status}")
        print(f"  Completeness: {result.completeness_percentage:.1f}%")
        print(f"  Accuracy: {result.accuracy_percentage:.1f}%")
        if result.differences:
            print(f"  Differences: {len(result.differences)}")















