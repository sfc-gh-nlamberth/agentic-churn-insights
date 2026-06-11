/*
=============================================================================
  Agentic Churn Insights - Teardown Script
  
  Run as ACCOUNTADMIN to remove all objects created by setup.sql.
=============================================================================
*/

USE ROLE ACCOUNTADMIN;

-- Drop the agent
DROP AGENT IF EXISTS CHURN_AGENT_DB.AGENTS.CUSTOMER_CHURN_MODELING;

-- Drop semantic views
DROP SEMANTIC VIEW IF EXISTS CHURN_AGENT_DB.DATA.CUSTOMER_DATA_SEMANTIC_VIEW;
DROP SEMANTIC VIEW IF EXISTS CHURN_AGENT_DB.DATA.CHURN_MODEL_DETAILS;

-- Drop database (cascades all schemas, tables, views)
DROP DATABASE IF EXISTS CHURN_AGENT_DB;

-- Drop warehouse
DROP WAREHOUSE IF EXISTS CHURN_AGENT_WH;

-- Drop role
DROP ROLE IF EXISTS CHURN_AGENT_ROLE;

SELECT 'Teardown complete. All demo objects removed.' AS STATUS;
