/*
=============================================================================
  Agentic Churn Insights - Setup Script
  
  Run as ACCOUNTADMIN in a Snowflake worksheet or via Git integration.
  Creates: role, warehouse, database, tables, semantic views, and Cortex Agent.
=============================================================================
*/

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- 1. ROLE & WAREHOUSE
-- ============================================================================

CREATE OR REPLACE ROLE CHURN_AGENT_ROLE;
GRANT ROLE CHURN_AGENT_ROLE TO ROLE ACCOUNTADMIN;

CREATE OR REPLACE WAREHOUSE CHURN_AGENT_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

GRANT USAGE ON WAREHOUSE CHURN_AGENT_WH TO ROLE CHURN_AGENT_ROLE;

-- ============================================================================
-- 2. DATABASE & SCHEMAS
-- ============================================================================

CREATE OR REPLACE DATABASE CHURN_AGENT_DB;
GRANT OWNERSHIP ON DATABASE CHURN_AGENT_DB TO ROLE CHURN_AGENT_ROLE COPY CURRENT GRANTS;

USE DATABASE CHURN_AGENT_DB;

CREATE SCHEMA IF NOT EXISTS DATA;
CREATE SCHEMA IF NOT EXISTS AGENTS;

GRANT OWNERSHIP ON SCHEMA DATA TO ROLE CHURN_AGENT_ROLE COPY CURRENT GRANTS;
GRANT OWNERSHIP ON SCHEMA AGENTS TO ROLE CHURN_AGENT_ROLE COPY CURRENT GRANTS;

-- ============================================================================
-- 3. TABLES & DATA GENERATION
-- ============================================================================

USE ROLE CHURN_AGENT_ROLE;
USE WAREHOUSE CHURN_AGENT_WH;
USE SCHEMA CHURN_AGENT_DB.DATA;

-- Customer data table (1M rows of synthetic data)
CREATE OR REPLACE TABLE CUSTOMER_DATA (
    CUSTOMER_ID NUMBER(18,0),
    REGION VARCHAR(7),
    PAYMENT_METHOD VARCHAR(13),
    NUM_DEVICES NUMBER(5,0),
    HAS_OFFER BOOLEAN,
    CONTRACT_DURATION_MONTHS NUMBER(2,0),
    MONTHLY_BILL NUMBER(6,1),
    DATA_USAGE_GB NUMBER(7,1),
    SUPPORT_CALLS_LAST_6M FLOAT,
    CUSTOMER_SINCE DATE,
    CHURNED BOOLEAN,
    CHURN_DATE DATE
);

INSERT INTO CUSTOMER_DATA
WITH raw_data AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SEQ8()) AS CUSTOMER_ID,
        UNIFORM(1, 5, RANDOM()) AS region_id,
        UNIFORM(0, 1, RANDOM()) AS payment_id,
        UNIFORM(1, 5, RANDOM()) AS NUM_DEVICES,
        UNIFORM(0, 1, RANDOM()) AS offer_flag,
        CASE WHEN UNIFORM(0, 1, RANDOM()) = 0 THEN 1 ELSE 24 END AS CONTRACT_DURATION_MONTHS,
        ROUND(UNIFORM(500, 3250, RANDOM()) / 10.0, 1) AS MONTHLY_BILL,
        ROUND(UNIFORM(0, 1100, RANDOM()) / 10.0, 1) AS DATA_USAGE_GB,
        CASE WHEN UNIFORM(0, 1, RANDOM()) = 1 THEN 15.0 ELSE 0.0 END AS SUPPORT_CALLS_LAST_6M,
        DATEADD('day', -UNIFORM(120, 1800, RANDOM()), CURRENT_DATE()) AS CUSTOMER_SINCE,
        UNIFORM(0, 1, RANDOM()) AS churn_flag
    FROM TABLE(GENERATOR(ROWCOUNT => 1000000))
)
SELECT
    CUSTOMER_ID,
    CASE region_id
        WHEN 1 THEN 'NORTH'
        WHEN 2 THEN 'SOUTH'
        WHEN 3 THEN 'EAST'
        WHEN 4 THEN 'WEST'
        WHEN 5 THEN 'CENTRAL'
    END AS REGION,
    CASE payment_id
        WHEN 0 THEN 'CREDIT_CARD'
        WHEN 1 THEN 'MAILED_CHECK'
    END AS PAYMENT_METHOD,
    NUM_DEVICES,
    CASE WHEN offer_flag = 1 THEN TRUE ELSE FALSE END AS HAS_OFFER,
    CONTRACT_DURATION_MONTHS,
    MONTHLY_BILL,
    DATA_USAGE_GB,
    SUPPORT_CALLS_LAST_6M,
    CUSTOMER_SINCE,
    CASE WHEN churn_flag = 1 THEN TRUE ELSE FALSE END AS CHURNED,
    CASE WHEN churn_flag = 1
        THEN DATEADD('day', UNIFORM(30, 365, RANDOM()), CUSTOMER_SINCE)
        ELSE NULL
    END AS CHURN_DATE
FROM raw_data;

-- Feature importance table (lowercase names required by semantic view)
CREATE OR REPLACE TABLE "feature_importance" (
    "feature" VARCHAR(16777216),
    "importance" FLOAT
);

INSERT INTO "feature_importance" ("feature", "importance") VALUES
    ('PAYMENT_METHOD_CREDIT_CARD', 0.2377617657),
    ('HAS_OFFER_STR_FALSE', 0.2177548409),
    ('SUPPORT_CALLS_PER_MONTH', 0.2014738023),
    ('CONTRACT_DURATION_MONTHS', 0.1552140415),
    ('SUPPORT_CALLS_LAST_6M', 0.1476135552),
    ('PAYMENT_METHOD_MAILED_CHECK', 0.01511742827),
    ('HEAVY_DATA_USER_HEAVY', 0.01490842365),
    ('HIGH_BILL_CUSTOMER_HIGH', 0.008392181247),
    ('HEAVY_DATA_USER_MEDIUM', 0.000275039085),
    ('REGION_EAST', 0.0001886069804),
    ('CUSTOMER_TENURE_DAYS', 0.0001602704288),
    ('BILL_PER_DEVICE', 0.0001589263848),
    ('NUM_DEVICES', 0.0001547170395),
    ('DATA_USAGE_PER_DEVICE', 0.0001451625867),
    ('REGION_SOUTH', 0.0001337015565),
    ('MONTHLY_BILL', 0.0001306860941),
    ('REGION_WEST', 0.0001292156812),
    ('DATA_USAGE_GB', 0.0001223496511),
    ('CUSTOMER_TENURE_MONTHS', 0.00011777693),
    ('REGION_NORTH', 4.756978888e-05),
    ('HIGH_BILL_CUSTOMER_MEDIUM', 0),
    ('HEAVY_DATA_USER_LIGHT', 0),
    ('HIGH_BILL_CUSTOMER_LOW', 0),
    ('REGION_CENTRAL', 0),
    ('HAS_OFFER_STR_TRUE', 0);

-- Model evaluation table (lowercase names required by semantic view)
CREATE OR REPLACE TABLE "model_evaluation" (
    "accuracy" FLOAT,
    "precision" FLOAT,
    "recall" FLOAT,
    "f1_score" FLOAT,
    "cv_mean_accuracy" FLOAT,
    "cv_std_accuracy" FLOAT
);

INSERT INTO "model_evaluation" VALUES (0.594431, 0.5203451611, 0.0215580341, 0.04140082151, NULL, NULL);

-- ============================================================================
-- 4. SEMANTIC VIEWS
-- ============================================================================

CREATE OR REPLACE SEMANTIC VIEW CUSTOMER_DATA_SEMANTIC_VIEW
  TABLES (
    CHURN_AGENT_DB.DATA.CUSTOMER_DATA
  )
  FACTS (
    CUSTOMER_DATA.CONTRACT_DURATION_MONTHS AS CONTRACT_DURATION_MONTHS COMMENT='The number of months a customer has committed to a contract.',
    CUSTOMER_DATA.CUSTOMER_ID AS CUSTOMER_ID COMMENT='Unique identifier for each customer in the database, used to distinguish and track individual customer records.',
    CUSTOMER_DATA.DATA_USAGE_GB AS DATA_USAGE_GB COMMENT='The total amount of data used by a customer in gigabytes.',
    CUSTOMER_DATA.MONTHLY_BILL AS MONTHLY_BILL COMMENT='The average monthly bill amount paid by a customer.',
    CUSTOMER_DATA.NUM_DEVICES AS NUM_DEVICES COMMENT='The number of devices associated with a customer.',
    CUSTOMER_DATA.SUPPORT_CALLS_LAST_6M AS SUPPORT_CALLS_LAST_6M COMMENT='The total number of support calls made by the customer in the last 6 months.'
  )
  DIMENSIONS (
    CUSTOMER_DATA.CHURNED AS CHURNED COMMENT='Indicates whether a customer has stopped doing business with the company.',
    CUSTOMER_DATA.HAS_OFFER AS HAS_OFFER COMMENT='Indicates whether the customer currently has an active offer or promotion associated with their account.',
    CUSTOMER_DATA.PAYMENT_METHOD AS PAYMENT_METHOD COMMENT='The method by which the customer made payment for their purchase.',
    CUSTOMER_DATA.REGION AS REGION COMMENT='Geographic region where the customer is located.',
    CUSTOMER_DATA.CHURN_DATE AS CHURN_DATE COMMENT='Date when the customer''s subscription or service was cancelled or terminated, indicating the end of their relationship with the company.',
    CUSTOMER_DATA.CUSTOMER_SINCE AS CUSTOMER_SINCE COMMENT='Date the customer first started doing business with the company.'
  );

CREATE OR REPLACE SEMANTIC VIEW CHURN_MODEL_DETAILS
  TABLES (
    FEATURE_IMPORTANCE AS CHURN_AGENT_DB.DATA."feature_importance",
    MODEL_EVALUATION AS CHURN_AGENT_DB.DATA."model_evaluation"
  )
  FACTS (
    FEATURE_IMPORTANCE.IMPORTANCE AS "importance",
    MODEL_EVALUATION.ACCURACY AS "accuracy",
    MODEL_EVALUATION.CV_MEAN_ACCURACY AS "cv_mean_accuracy",
    MODEL_EVALUATION.CV_STD_ACCURACY AS "cv_std_accuracy",
    MODEL_EVALUATION.F1_SCORE AS "f1_score",
    MODEL_EVALUATION.PRECISION AS "precision",
    MODEL_EVALUATION.RECALL AS "recall"
  )
  DIMENSIONS (
    FEATURE_IMPORTANCE.FEATURE AS "feature"
  );

-- ============================================================================
-- 5. CORTEX AGENT
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE SCHEMA CHURN_AGENT_DB.AGENTS;

CREATE OR REPLACE AGENT CUSTOMER_CHURN_MODELING
PROFILE='{"display_name":"Customer Churn Modeling"}'
FROM SPECIFICATION
$$
models:
  orchestration: "auto"
orchestration: {}
instructions:
  orchestration: "The tables in Churn_Model_Details cortex analyst model detail the\
    \ feature importance and model score of a churn prediction model trained on the\
    \ customer data in the Customer_Data cortex analyst model. The feature weights\
    \ are in aggregate while the customer data is at the individual user level.\n\n\
    Use the Customer_Data model to identify the churn cohorts and analyze them based\
    \ on the important features identified in Churn_Model_Details."
  sample_questions:
    - question: "Using the feature weights available to this model, please provide\
        \ a detailed analysis of the churn cohort from September 2025 and provide\
        \ recommended next steps in a strategy to retain similar customers"
tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "Customer_Data"
      description: "This view contains detailed customer information including demographics\
        \ (region, payment methods), service metrics (data usage, device counts, contract\
        \ duration), financial data (monthly billing), and behavioral indicators (support\
        \ calls, active offers). The dataset tracks the complete customer lifecycle\
        \ from acquisition date through potential churn events, enabling analysis\
        \ of customer retention patterns and identification of at-risk segments. This\
        \ semantic view is ideal for predictive modeling, customer segmentation, revenue\
        \ analysis, and developing targeted retention strategies across different\
        \ geographic regions and customer profiles."
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "Churn_Model_Details"
      description: "The tables in this model provide information about a churn prediction\
        \ model that was trained on the customer data in CUSTOMER_DATA. One table\
        \ has the accuracy metrics for the model, the other has the feature importance."
tool_resources:
  Churn_Model_Details:
    execution_environment:
      type: "warehouse"
      warehouse: "CHURN_AGENT_WH"
    semantic_view: "CHURN_AGENT_DB.DATA.CHURN_MODEL_DETAILS"
  Customer_Data:
    execution_environment:
      type: "warehouse"
      warehouse: "CHURN_AGENT_WH"
    semantic_view: "CHURN_AGENT_DB.DATA.CUSTOMER_DATA_SEMANTIC_VIEW"
$$;

-- ============================================================================
-- 6. GRANTS
-- ============================================================================

USE ROLE ACCOUNTADMIN;

GRANT USAGE ON DATABASE CHURN_AGENT_DB TO ROLE CHURN_AGENT_ROLE;
GRANT USAGE ON SCHEMA CHURN_AGENT_DB.DATA TO ROLE CHURN_AGENT_ROLE;
GRANT USAGE ON SCHEMA CHURN_AGENT_DB.AGENTS TO ROLE CHURN_AGENT_ROLE;
GRANT USAGE ON AGENT CHURN_AGENT_DB.AGENTS.CUSTOMER_CHURN_MODELING TO ROLE CHURN_AGENT_ROLE;

-- Done! Switch to the demo role to verify.
USE ROLE CHURN_AGENT_ROLE;
USE WAREHOUSE CHURN_AGENT_WH;

SELECT 'Setup complete! Agent CHURN_AGENT_DB.AGENTS.CUSTOMER_CHURN_MODELING is ready.' AS STATUS;
