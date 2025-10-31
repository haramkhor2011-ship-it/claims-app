#!/usr/bin/env python3
"""
SQL Parser for Database Object Extraction
Extracts views, materialized views, functions, tables, indexes, triggers, and grants from SQL files
"""

import re
import sqlparse
from sqlparse.sql import Statement, TokenList, Token
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
from enum import Enum

class SQLObjectType(Enum):
    VIEW = "VIEW"
    MATERIALIZED_VIEW = "MATERIALIZED_VIEW"
    FUNCTION = "FUNCTION"
    TABLE = "TABLE"
    INDEX = "INDEX"
    TRIGGER = "TRIGGER"
    GRANT = "GRANT"
    COMMENT = "COMMENT"
    CTE = "CTE"

@dataclass
class SQLObject:
    name: str
    type: SQLObjectType
    definition: str
    start_line: int
    end_line: int
    comments: List[str]
    columns: List[str]
    joins: List[Dict]
    where_clause: Optional[str]
    group_by: Optional[str]
    order_by: Optional[str]
    ctes: List[Dict]
    parameters: List[str] = None
    return_type: Optional[str] = None
    grants: List[str] = None

class SQLParser:
    def __init__(self):
        self.objects = []
        self.current_line = 0
        
    def parse_file(self, file_path: str) -> List[SQLObject]:
        """Parse a SQL file and extract all database objects"""
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        self.objects = []
        self.current_line = 0
        
        # Split content into lines for line number tracking
        lines = content.split('\n')
        
        # Parse using sqlparse
        parsed = sqlparse.parse(content)
        
        for statement in parsed:
            self._parse_statement(statement, lines)
            
        return self.objects
    
    def _parse_statement(self, statement: Statement, lines: List[str]) -> None:
        """Parse a single SQL statement"""
        statement_str = str(statement).strip()
        if not statement_str:
            return
            
        # Update line counter
        self.current_line += statement_str.count('\n') + 1
        
        # Determine object type
        obj_type = self._get_object_type(statement_str)
        if obj_type is None:
            return
            
        # Extract object name
        name = self._extract_object_name(statement_str, obj_type)
        if not name:
            return
            
        # Extract comments
        comments = self._extract_comments(statement_str)
        
        # Extract components based on object type
        if obj_type in [SQLObjectType.VIEW, SQLObjectType.MATERIALIZED_VIEW]:
            obj = self._parse_view_or_mv(statement_str, name, obj_type, comments)
        elif obj_type == SQLObjectType.FUNCTION:
            obj = self._parse_function(statement_str, name, comments)
        elif obj_type == SQLObjectType.TABLE:
            obj = self._parse_table(statement_str, name, comments)
        elif obj_type == SQLObjectType.INDEX:
            obj = self._parse_index(statement_str, name, comments)
        elif obj_type == SQLObjectType.TRIGGER:
            obj = self._parse_trigger(statement_str, name, comments)
        elif obj_type == SQLObjectType.GRANT:
            obj = self._parse_grant(statement_str, name, comments)
        else:
            obj = SQLObject(
                name=name,
                type=obj_type,
                definition=statement_str,
                start_line=self.current_line,
                end_line=self.current_line + statement_str.count('\n'),
                comments=comments,
                columns=[],
                joins=[],
                where_clause=None,
                group_by=None,
                order_by=None,
                ctes=[]
            )
            
        self.objects.append(obj)
    
    def _get_object_type(self, statement: str) -> Optional[SQLObjectType]:
        """Determine the type of SQL object"""
        statement_upper = statement.upper()
        
        if statement_upper.startswith('CREATE OR REPLACE VIEW'):
            return SQLObjectType.VIEW
        elif statement_upper.startswith('CREATE MATERIALIZED VIEW'):
            return SQLObjectType.MATERIALIZED_VIEW
        elif statement_upper.startswith('CREATE OR REPLACE FUNCTION'):
            return SQLObjectType.FUNCTION
        elif statement_upper.startswith('CREATE TABLE'):
            return SQLObjectType.TABLE
        elif statement_upper.startswith('CREATE INDEX'):
            return SQLObjectType.INDEX
        elif statement_upper.startswith('CREATE TRIGGER'):
            return SQLObjectType.TRIGGER
        elif statement_upper.startswith('GRANT'):
            return SQLObjectType.GRANT
        elif statement_upper.startswith('COMMENT ON'):
            return SQLObjectType.COMMENT
        
        return None
    
    def _extract_object_name(self, statement: str, obj_type: SQLObjectType) -> Optional[str]:
        """Extract the name of the SQL object"""
        patterns = {
            SQLObjectType.VIEW: r'CREATE\s+(?:OR\s+REPLACE\s+)?VIEW\s+(\w+(?:\.\w+)?)',
            SQLObjectType.MATERIALIZED_VIEW: r'CREATE\s+MATERIALIZED\s+VIEW\s+(\w+(?:\.\w+)?)',
            SQLObjectType.FUNCTION: r'CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(\w+(?:\.\w+)?)',
            SQLObjectType.TABLE: r'CREATE\s+TABLE\s+(\w+(?:\.\w+)?)',
            SQLObjectType.INDEX: r'CREATE\s+(?:UNIQUE\s+)?INDEX\s+(\w+(?:\.\w+)?)',
            SQLObjectType.TRIGGER: r'CREATE\s+TRIGGER\s+(\w+(?:\.\w+)?)',
            SQLObjectType.GRANT: r'GRANT\s+.*?\s+ON\s+(\w+(?:\.\w+)?)',
            SQLObjectType.COMMENT: r'COMMENT\s+ON\s+(\w+(?:\.\w+)?)'
        }
        
        pattern = patterns.get(obj_type)
        if pattern:
            match = re.search(pattern, statement, re.IGNORECASE)
            if match:
                return match.group(1)
        
        return None
    
    def _extract_comments(self, statement: str) -> List[str]:
        """Extract comments from SQL statement"""
        comments = []
        
        # Extract single-line comments
        for line in statement.split('\n'):
            line = line.strip()
            if line.startswith('--'):
                comments.append(line)
        
        # Extract multi-line comments
        multi_line_pattern = r'/\*.*?\*/'
        matches = re.findall(multi_line_pattern, statement, re.DOTALL)
        comments.extend(matches)
        
        return comments
    
    def _parse_view_or_mv(self, statement: str, name: str, obj_type: SQLObjectType, comments: List[str]) -> SQLObject:
        """Parse a view or materialized view"""
        # Extract SELECT statement
        select_match = re.search(r'AS\s+(.*)', statement, re.DOTALL | re.IGNORECASE)
        if not select_match:
            return self._create_basic_object(name, obj_type, statement, comments)
        
        select_statement = select_match.group(1).strip()
        
        # Extract columns
        columns = self._extract_columns(select_statement)
        
        # Extract CTEs
        ctes = self._extract_ctes(select_statement)
        
        # Extract JOINs
        joins = self._extract_joins(select_statement)
        
        # Extract WHERE clause
        where_clause = self._extract_where_clause(select_statement)
        
        # Extract GROUP BY
        group_by = self._extract_group_by(select_statement)
        
        # Extract ORDER BY
        order_by = self._extract_order_by(select_statement)
        
        return SQLObject(
            name=name,
            type=obj_type,
            definition=statement,
            start_line=self.current_line,
            end_line=self.current_line + statement.count('\n'),
            comments=comments,
            columns=columns,
            joins=joins,
            where_clause=where_clause,
            group_by=group_by,
            order_by=order_by,
            ctes=ctes
        )
    
    def _parse_function(self, statement: str, name: str, comments: List[str]) -> SQLObject:
        """Parse a function"""
        # Extract parameters
        params_match = re.search(r'FUNCTION\s+\w+(?:\.\w+)?\s*\((.*?)\)', statement, re.DOTALL | re.IGNORECASE)
        parameters = []
        if params_match:
            params_str = params_match.group(1)
            # Simple parameter extraction (can be enhanced)
            parameters = [p.strip() for p in params_str.split(',') if p.strip()]
        
        # Extract return type
        return_type_match = re.search(r'RETURNS\s+(\w+(?:\([^)]*\))?)', statement, re.IGNORECASE)
        return_type = return_type_match.group(1) if return_type_match else None
        
        return SQLObject(
            name=name,
            type=SQLObjectType.FUNCTION,
            definition=statement,
            start_line=self.current_line,
            end_line=self.current_line + statement.count('\n'),
            comments=comments,
            columns=[],
            joins=[],
            where_clause=None,
            group_by=None,
            order_by=None,
            ctes=[],
            parameters=parameters,
            return_type=return_type
        )
    
    def _parse_table(self, statement: str, name: str, comments: List[str]) -> SQLObject:
        """Parse a table definition"""
        # Extract columns from CREATE TABLE statement
        columns = self._extract_table_columns(statement)
        
        return SQLObject(
            name=name,
            type=SQLObjectType.TABLE,
            definition=statement,
            start_line=self.current_line,
            end_line=self.current_line + statement.count('\n'),
            comments=comments,
            columns=columns,
            joins=[],
            where_clause=None,
            group_by=None,
            order_by=None,
            ctes=[]
        )
    
    def _parse_index(self, statement: str, name: str, comments: List[str]) -> SQLObject:
        """Parse an index definition"""
        return self._create_basic_object(name, SQLObjectType.INDEX, statement, comments)
    
    def _parse_trigger(self, statement: str, name: str, comments: List[str]) -> SQLObject:
        """Parse a trigger definition"""
        return self._create_basic_object(name, SQLObjectType.TRIGGER, statement, comments)
    
    def _parse_grant(self, statement: str, name: str, comments: List[str]) -> SQLObject:
        """Parse a grant statement"""
        return self._create_basic_object(name, SQLObjectType.GRANT, statement, comments)
    
    def _create_basic_object(self, name: str, obj_type: SQLObjectType, statement: str, comments: List[str]) -> SQLObject:
        """Create a basic SQL object"""
        return SQLObject(
            name=name,
            type=obj_type,
            definition=statement,
            start_line=self.current_line,
            end_line=self.current_line + statement.count('\n'),
            comments=comments,
            columns=[],
            joins=[],
            where_clause=None,
            group_by=None,
            order_by=None,
            ctes=[]
        )
    
    def _extract_columns(self, select_statement: str) -> List[str]:
        """Extract column names from SELECT statement"""
        # Find SELECT clause
        select_match = re.search(r'SELECT\s+(.*?)\s+FROM', select_statement, re.DOTALL | re.IGNORECASE)
        if not select_match:
            return []
        
        select_clause = select_match.group(1)
        
        # Split by comma and extract column names
        columns = []
        for col in select_clause.split(','):
            col = col.strip()
            # Extract column name (handle aliases)
            if ' AS ' in col.upper():
                col_name = col.split(' AS ')[0].strip()
            else:
                col_name = col.strip()
            
            # Remove function calls and keep only column name
            col_name = re.sub(r'[^(]*\(([^)]*)\).*', r'\1', col_name)
            col_name = col_name.split('.')[-1]  # Get last part after dot
            
            if col_name and not col_name.upper() in ['*', 'DISTINCT']:
                columns.append(col_name)
        
        return columns
    
    def _extract_ctes(self, select_statement: str) -> List[Dict]:
        """Extract Common Table Expressions (CTEs)"""
        ctes = []
        
        # Look for WITH clause
        with_match = re.search(r'WITH\s+(.*?)\s+SELECT', select_statement, re.DOTALL | re.IGNORECASE)
        if with_match:
            with_clause = with_match.group(1)
            
            # Split CTEs by comma (simplified)
            cte_parts = with_clause.split(',')
            for cte_part in cte_parts:
                cte_part = cte_part.strip()
                if ' AS ' in cte_part.upper():
                    name, definition = cte_part.split(' AS ', 1)
                    ctes.append({
                        'name': name.strip(),
                        'definition': definition.strip()
                    })
        
        return ctes
    
    def _extract_joins(self, select_statement: str) -> List[Dict]:
        """Extract JOIN information"""
        joins = []
        
        # Find all JOIN clauses
        join_pattern = r'(LEFT\s+JOIN|RIGHT\s+JOIN|INNER\s+JOIN|JOIN|FULL\s+OUTER\s+JOIN)\s+(\w+(?:\.\w+)?)\s+(?:ON\s+(.*?))?(?=\s+(?:LEFT\s+JOIN|RIGHT\s+JOIN|INNER\s+JOIN|JOIN|FULL\s+OUTER\s+JOIN|WHERE|GROUP\s+BY|ORDER\s+BY|$))'
        
        for match in re.finditer(join_pattern, select_statement, re.IGNORECASE):
            join_type = match.group(1).upper()
            table = match.group(2)
            condition = match.group(3) if match.group(3) else None
            
            joins.append({
                'type': join_type,
                'table': table,
                'condition': condition
            })
        
        return joins
    
    def _extract_where_clause(self, select_statement: str) -> Optional[str]:
        """Extract WHERE clause"""
        where_match = re.search(r'WHERE\s+(.*?)(?:\s+GROUP\s+BY|\s+ORDER\s+BY|$)', select_statement, re.DOTALL | re.IGNORECASE)
        return where_match.group(1).strip() if where_match else None
    
    def _extract_group_by(self, select_statement: str) -> Optional[str]:
        """Extract GROUP BY clause"""
        group_match = re.search(r'GROUP\s+BY\s+(.*?)(?:\s+ORDER\s+BY|$)', select_statement, re.DOTALL | re.IGNORECASE)
        return group_match.group(1).strip() if group_match else None
    
    def _extract_order_by(self, select_statement: str) -> Optional[str]:
        """Extract ORDER BY clause"""
        order_match = re.search(r'ORDER\s+BY\s+(.*?)$', select_statement, re.DOTALL | re.IGNORECASE)
        return order_match.group(1).strip() if order_match else None
    
    def _extract_table_columns(self, table_statement: str) -> List[str]:
        """Extract column names from CREATE TABLE statement"""
        columns = []
        
        # Find column definitions between parentheses
        columns_match = re.search(r'\(\s*(.*?)\s*\)', table_statement, re.DOTALL)
        if columns_match:
            columns_str = columns_match.group(1)
            
            # Split by comma and extract column names
            for col_def in columns_str.split(','):
                col_def = col_def.strip()
                if col_def and not col_def.upper().startswith(('PRIMARY KEY', 'FOREIGN KEY', 'UNIQUE', 'CHECK')):
                    # Extract column name (first word)
                    col_name = col_def.split()[0]
                    columns.append(col_name)
        
        return columns

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) != 2:
        print("Usage: python sql_parser.py <sql_file_path>")
        sys.exit(1)
    
    parser = SQLParser()
    objects = parser.parse_file(sys.argv[1])
    
    print(f"Found {len(objects)} SQL objects:")
    for obj in objects:
        print(f"- {obj.name} ({obj.type.value})")
        if obj.columns:
            print(f"  Columns: {', '.join(obj.columns[:5])}{'...' if len(obj.columns) > 5 else ''}")
        if obj.ctes:
            print(f"  CTEs: {len(obj.ctes)}")
        if obj.joins:
            print(f"  JOINs: {len(obj.joins)}")















