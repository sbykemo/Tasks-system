/*
================================================================================
  Daily Tasks Tracking System (TTS)
  File: apex_shared_components.sql
  Description: Creates Shared Components inside APEX using APEX APIs
               Run this script in APEX > SQL Workshop > SQL Scripts
  APEX Version: 24.2.17
  Author: TTS Development Team
  Created: 2026-07-08
================================================================================
  PREREQUISITES:
    1. Create APEX Application first (Application ID will be needed)
    2. schema.sql, seed_data.sql must be already installed
    3. Run this in: SQL Workshop > SQL Scripts > Run
================================================================================
*/

-- ============================================================
-- NOTE: Replace &APP_ID. with your actual APEX Application ID
-- throughout this file before running.
-- ============================================================

PROMPT ============================================================
PROMPT  TTS APEX Shared Components Setup
PROMPT ============================================================

-- ============================================================
-- SECTION 1: APPLICATION ITEMS
-- ============================================================
-- These must be created manually in APEX Builder:
-- Shared Components > Application Items
--
-- Item Name       | Scope       | Session State Protection
-- F_USER_ID       | Application | Restricted
-- F_USER_ROLE     | Application | Restricted
-- F_FULL_NAME     | Application | Restricted
-- F_DEPT_ID       | Application | Restricted
-- ============================================================


-- ============================================================
-- SECTION 2: APPLICATION COMPUTATIONS
-- ============================================================
-- No computations needed — session state is set via
-- tts_pkg_security.post_auth in the Post-Authentication process.


-- ============================================================
-- SECTION 3: LIST OF VALUES (LOVs) — SQL Queries
-- ============================================================
-- Create these as Shared Components > List of Values > Create
-- Type: Dynamic (SQL Query)
--
-- Use the SQL below for each LOV definition.
-- ============================================================

/*
LOV Name: LOV_SYSTEMS
Type: Dynamic
SQL Query:
*/
-- SELECT system_name d, system_id r
-- FROM tts_systems
-- WHERE is_active = 'Y'
-- ORDER BY system_name;

/*
LOV Name: LOV_USERS_ACTIVE
Type: Dynamic
SQL Query:
*/
-- SELECT full_name || ' (' || username || ')' d, user_id r
-- FROM tts_users
-- WHERE is_active = 'Y'
-- ORDER BY full_name;

/*
LOV Name: LOV_TEAM_MEMBERS
Type: Dynamic
SQL Query:
-- Admins see all users, Managers see only their team
*/
-- SELECT full_name || ' (' || username || ')' d, user_id r
-- FROM tts_users
-- WHERE is_active = 'Y'
-- AND (
--     :F_USER_ROLE = 'ADMIN'
--     OR (
--         :F_USER_ROLE = 'MANAGER'
--         AND (manager_id = TO_NUMBER(:F_USER_ID) OR user_id = TO_NUMBER(:F_USER_ID))
--     )
--     OR (
--         :F_USER_ROLE = 'EMPLOYEE'
--         AND user_id = TO_NUMBER(:F_USER_ID)
--     )
-- )
-- ORDER BY full_name;

/*
LOV Name: LOV_TASK_STATUS
Type: Dynamic
SQL Query:
*/
-- SELECT display_name d, lookup_code r
-- FROM tts_lookups
-- WHERE lookup_type = 'TASK_STATUS'
-- AND is_active = 'Y'
-- ORDER BY display_order;

/*
LOV Name: LOV_PRIORITY
Type: Dynamic
SQL Query:
*/
-- SELECT display_name d, lookup_code r
-- FROM tts_lookups
-- WHERE lookup_type = 'PRIORITY'
-- AND is_active = 'Y'
-- ORDER BY display_order;

/*
LOV Name: LOV_APPROVAL_STATUS
Type: Dynamic
SQL Query:
*/
-- SELECT display_name d, lookup_code r
-- FROM tts_lookups
-- WHERE lookup_type = 'APPROVAL_STATUS'
-- AND is_active = 'Y'
-- ORDER BY display_order;

/*
LOV Name: LOV_DEPARTMENTS
Type: Dynamic
SQL Query:
*/
-- SELECT dept_name d, dept_id r
-- FROM tts_departments
-- WHERE is_active = 'Y'
-- ORDER BY dept_name;

/*
LOV Name: LOV_TAGS
Type: Dynamic
SQL Query:
*/
-- SELECT tag_name d, tag_id r
-- FROM tts_tags
-- ORDER BY tag_name;

/*
LOV Name: LOV_USER_ROLES
Type: Static
Values:
  ADMIN    - Administrator
  MANAGER  - Manager
  EMPLOYEE - Employee
*/

/*
LOV Name: LOV_YES_NO
Type: Static
Values:
  Y - Yes
  N - No
*/


-- ============================================================
-- SECTION 4: AUTHORIZATION SCHEMES
-- ============================================================
-- Create in: Shared Components > Authorization Schemes
-- ============================================================

/*
Scheme 1: IS_ADMIN
  Type: PL/SQL Function (returning Boolean)
  PL/SQL:
*/
-- RETURN :F_USER_ROLE = 'ADMIN';

/*
Scheme 2: IS_MANAGER_OR_ADMIN
  Type: PL/SQL Function (returning Boolean)
  PL/SQL:
*/
-- RETURN :F_USER_ROLE IN ('ADMIN', 'MANAGER');

/*
Scheme 3: IS_AUTHENTICATED
  Type: PL/SQL Function (returning Boolean)
  PL/SQL:
*/
-- RETURN :F_USER_ROLE IS NOT NULL;


-- ============================================================
-- SECTION 5: AUTHENTICATION SCHEME
-- ============================================================
-- Create in: Shared Components > Authentication Schemes
--
-- Name: TTS Custom Authentication
-- Scheme Type: Custom
-- Authentication Function Name: tts_pkg_security.authenticate_user
-- Post-Authentication Procedure Name: tts_pkg_security.post_auth
-- Invalid Session URL: Leave default (Login page)
-- ============================================================


-- ============================================================
-- SECTION 6: NAVIGATION MENU ENTRIES
-- ============================================================
-- Create in: Shared Components > Navigation Menu > Desktop Navigation Menu
-- 
-- The following SQL can help populate the navigation menu if
-- you prefer to do it via SQL. However, APEX Builder is
-- recommended for menu management.
-- ============================================================

/*
Menu Structure:
  
  1. Dashboard               -> Page 2    Auth: IS_AUTHENTICATED    Icon: fa-home
  2. My Tasks                -> Page 3    Auth: IS_AUTHENTICATED    Icon: fa-tasks
  3. Kanban Board            -> Page 6    Auth: IS_AUTHENTICATED    Icon: fa-columns
  4. Daily Time Log          -> Page 11   Auth: IS_AUTHENTICATED    Icon: fa-clock-o
  --- separator ---
  5. Team Overview           -> Page 10   Auth: IS_MANAGER_OR_ADMIN Icon: fa-users
  6. Pending Approvals       -> Page 12   Auth: IS_MANAGER_OR_ADMIN Icon: fa-check-square-o
  --- separator ---
  7. Administration (Parent) ->           Auth: IS_ADMIN            Icon: fa-gear
     7.1 Users Management    -> Page 8    Auth: IS_ADMIN            Icon: fa-user
     7.2 Departments         -> Page 13   Auth: IS_ADMIN            Icon: fa-building
     7.3 Systems Management  -> Page 7    Auth: IS_ADMIN            Icon: fa-server
     7.4 Lookups Management  -> Page 14   Auth: IS_ADMIN            Icon: fa-list
  --- separator ---
  8. My Profile              -> Page 9    Auth: IS_AUTHENTICATED    Icon: fa-user-circle
*/


-- ============================================================
-- SECTION 7: CSS CUSTOM THEME
-- ============================================================
-- Add to: Shared Components > User Interface > CSS > Inline CSS
-- Or create as a separate .css file in Static Application Files
-- ============================================================

/*
Paste into: Page > CSS > Inline:

:root {
    --tts-primary:       #1a73e8;
    --tts-success:       #34a853;
    --tts-warning:       #fbbc04;
    --tts-danger:        #ea4335;
    --tts-info:          #4285f4;
    --tts-dark:          #202124;
    --tts-muted:         #5f6368;
    --tts-bg-light:      #f8f9fa;
    --tts-border-radius: 12px;
}

/* Status badges */
.status-badge {
    display: inline-block;
    padding: 4px 12px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}
.status-created     { background: #e8f0fe; color: #1967d2; }
.status-in_progress { background: #fef7e0; color: #ea8600; }
.status-on_hold     { background: #fce8e6; color: #c5221f; }
.status-completed   { background: #e6f4ea; color: #137333; }
.status-cancelled   { background: #f1f3f4; color: #5f6368; }

/* Priority badges */
.priority-low      { background: #e8f5e9; color: #2e7d32; }
.priority-medium   { background: #fff3e0; color: #ef6c00; }
.priority-high     { background: #fce4ec; color: #c62828; }
.priority-critical { background: #c62828; color: #ffffff; }

/* KPI Cards on Dashboard */
.tts-kpi-card {
    background: white;
    border-radius: var(--tts-border-radius);
    padding: 24px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.12);
    text-align: center;
    transition: transform 0.2s, box-shadow 0.2s;
}
.tts-kpi-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
}
.tts-kpi-card .kpi-value {
    font-size: 36px;
    font-weight: 700;
    color: var(--tts-primary);
}
.tts-kpi-card .kpi-label {
    font-size: 14px;
    color: var(--tts-muted);
    margin-top: 8px;
}

/* Task Cards */
.tts-task-card {
    border-left: 4px solid var(--tts-primary);
    border-radius: var(--tts-border-radius);
    padding: 16px;
    margin-bottom: 12px;
    background: white;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    transition: all 0.2s;
}
.tts-task-card:hover {
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    cursor: pointer;
}
.tts-task-card.priority-high   { border-left-color: var(--tts-danger); }
.tts-task-card.priority-critical { border-left-color: #b71c1c; }
.tts-task-card.priority-medium { border-left-color: var(--tts-warning); }
.tts-task-card.priority-low    { border-left-color: var(--tts-success); }

/* Notification bell badge */
.tts-notif-badge {
    position: absolute;
    top: -4px;
    right: -4px;
    background: var(--tts-danger);
    color: white;
    border-radius: 50%;
    padding: 2px 6px;
    font-size: 10px;
    font-weight: 700;
    min-width: 18px;
    text-align: center;
}

/* Overdue indicator */
.overdue-row {
    background-color: #fff5f5 !important;
}
.overdue-text {
    color: var(--tts-danger);
    font-weight: 600;
}

/* Progress bar for completion */
.tts-progress {
    height: 8px;
    background: #e0e0e0;
    border-radius: 4px;
    overflow: hidden;
}
.tts-progress-bar {
    height: 100%;
    border-radius: 4px;
    transition: width 0.3s;
}
.tts-progress-bar.green  { background: var(--tts-success); }
.tts-progress-bar.yellow { background: var(--tts-warning); }
.tts-progress-bar.red    { background: var(--tts-danger); }
*/

PROMPT ============================================================
PROMPT  TTS APEX Shared Components Reference — COMPLETE
PROMPT  Use this file as a reference when building in APEX Builder
PROMPT ============================================================

