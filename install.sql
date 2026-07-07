/*
================================================================================
  Daily Tasks Tracking System (TTS)
  File: install.sql
  Description: Master installation script — runs all scripts in correct order
  APEX Version: 24.2.17
  Author: TTS Development Team
  Created: 2026-07-07
================================================================================
  USAGE:
    Connect to your Oracle database as the target schema user, then run:
    
    SQL> @install.sql
    
  PREREQUISITES:
    1. Schema user must have EXECUTE privilege on DBMS_CRYPTO
       GRANT EXECUTE ON DBMS_CRYPTO TO your_schema;
    2. Schema user must have CREATE TABLE, CREATE VIEW, CREATE SEQUENCE,
       CREATE TRIGGER, CREATE PROCEDURE privileges
    3. For email notifications: APEX instance SMTP must be configured
================================================================================
*/

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET DEFINE OFF;
SET ECHO OFF;
SET FEEDBACK OFF;

PROMPT
PROMPT ╔══════════════════════════════════════════════════════════════╗
PROMPT ║     Daily Tasks Tracking System (TTS) — Installation       ║
PROMPT ║     Oracle APEX 24.2.17                                    ║
PROMPT ╚══════════════════════════════════════════════════════════════╝
PROMPT

-- Step 1: Schema (Tables, Sequences, Indexes)
PROMPT ▶ Step 1/5: Creating database schema...
@@schema.sql

-- Step 2: Seed Data (Lookups, Default Admin, Sample Data)
PROMPT ▶ Step 2/5: Loading seed data...
@@seed_data.sql

-- Step 3: Views
PROMPT ▶ Step 3/5: Creating database views...
@@views.sql

-- Step 4: Triggers
PROMPT ▶ Step 4/5: Creating triggers...
@@triggers.sql

-- Step 5: PL/SQL Packages
PROMPT ▶ Step 5/5: Creating PL/SQL packages...
@@packages.sql

PROMPT
PROMPT ╔══════════════════════════════════════════════════════════════╗
PROMPT ║     Installation Complete!                                  ║
PROMPT ║                                                             ║
PROMPT ║     Default Admin Login:                                    ║
PROMPT ║       Username: admin                                       ║
PROMPT ║       Password: Admin@123                                   ║
PROMPT ║                                                             ║
PROMPT ║     Next Steps:                                             ║
PROMPT ║       1. Run test_suite.sql to validate installation        ║
PROMPT ║       2. Create APEX Application (see implementation plan)  ║
PROMPT ║       3. Change the default admin password                  ║
PROMPT ╚══════════════════════════════════════════════════════════════╝
PROMPT

SET FEEDBACK ON;
SET ECHO ON;

