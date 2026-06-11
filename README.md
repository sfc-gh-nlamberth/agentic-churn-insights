# Agentic Churn Insights

A Snowflake demo that creates a Cortex Agent for analyzing customer churn using ML model insights. The agent combines customer-level data with feature importance from a churn prediction model to provide actionable retention strategies.

## What's Included

- **CUSTOMER_DATA** — 1M rows of synthetic telecom customer data with demographics, service metrics, billing, and churn indicators
- **Feature Importance & Model Evaluation** — Pre-computed ML model outputs showing which features drive churn predictions
- **Semantic Views** — Two Cortex Analyst semantic views that give the agent structured access to the data
- **Cortex Agent** — `CUSTOMER_CHURN_MODELING` agent that can analyze churn cohorts and recommend retention strategies

## Prerequisites

- Snowflake account with **ACCOUNTADMIN** access
- Cortex AI enabled on the account (for Cortex Agent and Semantic Views)

## Setup

### Option 1: Snowflake Git Integration

1. Create a Git repository integration pointing to this repo
2. Create a Git workspace from the integration
3. Open `setup.sql` and run all statements

### Option 2: Manual Worksheet

1. Copy the contents of `setup.sql` into a Snowflake SQL worksheet
2. Run as ACCOUNTADMIN

### What Gets Created

| Object | Name |
|--------|------|
| Role | `CHURN_AGENT_ROLE` |
| Warehouse | `CHURN_AGENT_WH` (X-Small) |
| Database | `CHURN_AGENT_DB` |
| Schemas | `DATA`, `AGENTS` |
| Tables | `CUSTOMER_DATA`, `feature_importance`, `model_evaluation` |
| Semantic Views | `CUSTOMER_DATA_SEMANTIC_VIEW`, `CHURN_MODEL_DETAILS` |
| Agent | `CUSTOMER_CHURN_MODELING` |

## Using the Agent

After setup, find the agent in **Snowflake Intelligence** or query it directly:

```sql
USE ROLE CHURN_AGENT_ROLE;
USE WAREHOUSE CHURN_AGENT_WH;

-- Example question
SELECT SNOWFLAKE.CORTEX.AGENT(
    'CHURN_AGENT_DB.AGENTS.CUSTOMER_CHURN_MODELING',
    'Using the feature weights available to this model, please provide a detailed analysis of the churn cohort from September 2025 and provide recommended next steps in a strategy to retain similar customers'
);
```

## Teardown

To remove all demo objects:

```sql
-- Run teardown.sql as ACCOUNTADMIN
```

Or open `teardown.sql` in a worksheet and execute all statements.

## Architecture

```
CHURN_AGENT_DB
├── DATA
│   ├── CUSTOMER_DATA (table, 1M rows)
│   ├── feature_importance (table, 25 rows)
│   ├── model_evaluation (table, 1 row)
│   ├── CUSTOMER_DATA_SEMANTIC_VIEW (semantic view)
│   └── CHURN_MODEL_DETAILS (semantic view)
└── AGENTS
    └── CUSTOMER_CHURN_MODELING (cortex agent)
```

The agent uses two `cortex_analyst_text_to_sql` tools — one for querying customer data and one for querying model details — to combine individual customer analysis with aggregate model insights.
