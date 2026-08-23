-- Padi Graph Schema for LadybugDB
--
-- This schema defines the knowledge graph structure used by the
-- Cybernetic BEAM Harness for tracking code relationships.

-- ============================================================
-- Node Tables
-- ============================================================

-- Requirements specifications (what the code should do)
CREATE NODE TABLE IF NOT EXISTS SpecRequirement (
  id STRING,
  text STRING,
  source STRING,                    -- Where this spec came from
  priority STRING,                   -- high, medium, low
  status STRING,                     -- pending, in_progress, done
  created_at INT64,
  PRIMARY KEY (id)
);

-- Abstract Syntax Tree nodes (functions, classes, modules, etc.)
CREATE NODE TABLE IF NOT EXISTS ASTNode (
  id STRING,                         -- Unique identifier: filepath:line:symbol
  filepath STRING,                   -- Source file path
  start_line INT64,                  -- Start line in file
  end_line INT64,                    -- End line in file
  symbol_name STRING,               -- Function/class/module name
  node_type STRING,                 -- function_definition, class, module, etc.
  language STRING,                   -- elixir, rust, python, etc.
  complexity INT64,                  -- Cyclomatic complexity
  is_testable BOOLEAN,               -- Whether this node can be tested
  last_modified INT64,               -- Timestamp of last modification
  PRIMARY KEY (id)
);

-- Git commits
CREATE NODE TABLE IF NOT EXISTS Commit (
  hash STRING,                       -- Git commit hash
  author STRING,                     -- Author name/email
  message STRING,                    -- Commit message
  timestamp INT64,                   -- Commit timestamp
  branch STRING,                    -- Branch name
  PRIMARY KEY (hash)
);

-- Unit tests
CREATE NODE TABLE IF NOT EXISTS UnitTest (
  id STRING,                        -- Unique identifier
  filepath STRING,                   -- Test file path
  test_name STRING,                  -- Name of the test
  framework STRING,                  -- exunit, jest, pytest, etc.
  status STRING,                     -- passing, failing, skipped
  last_run INT64,                   -- Timestamp of last run
  duration_ms INT64,                 -- Average execution time
  PRIMARY KEY (id)
);

-- ============================================================
-- Relationship Tables
-- ============================================================

-- Links requirements to the AST nodes that satisfy them
CREATE REL TABLE IF NOT EXISTS SATISFIES_BY (
  FROM SpecRequirement TO ASTNode
);

-- Call graph relationships (function A calls function B)
CREATE REL TABLE IF NOT EXISTS CALLS (
  FROM ASTNode TO ASTNode
);

-- Links AST nodes to the commits that last modified them
CREATE REL TABLE IF NOT EXISTS MODIFIED_IN (
  FROM ASTNode TO Commit
);

-- Links tests to the AST nodes they exercise
CREATE REL TABLE IF NOT EXISTS EXERCISES (
  FROM UnitTest TO ASTNode
);

-- Parent-child relationships in the AST (e.g., class contains method)
CREATE REL TABLE IF NOT EXISTS CONTAINS (
  FROM ASTNode TO ASTNode
);

-- ============================================================
-- Indexes for common query patterns
-- ============================================================

-- These will be created by LadybugDB automatically for primary keys
-- Additional indexes can be created for specific query patterns
