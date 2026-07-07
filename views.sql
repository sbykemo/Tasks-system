/*
================================================================================
  Daily Tasks Tracking System (TTS)
  File: views.sql
  Description: Database Views for reporting, dashboards, and APEX data sources
  APEX Version: 24.2.17
  Author: TTS Development Team
  Created: 2026-07-07
================================================================================
  EXECUTION ORDER: Run AFTER schema.sql and seed_data.sql
================================================================================
*/

SET SERVEROUTPUT ON;
SET DEFINE OFF;

PROMPT ============================================================
PROMPT  TTS Views Installation — Starting...
PROMPT ============================================================

-- ============================================================
-- VIEW 1: v_tasks_full — Master Task View (used across all pages)
-- ============================================================
PROMPT Creating view: v_tasks_full...

CREATE OR REPLACE VIEW v_tasks_full AS
SELECT 
    -- Task core fields
    t.task_id,
    t.task_number,
    t.title,
    t.description,
    t.start_date,
    t.due_date,
    t.estimated_hours,
    t.actual_hours,
    t.completion_date,
    t.created_at,
    t.updated_at,
    -- Status with display name
    t.status,
    ls.display_name    AS status_display,
    ls.display_name_ar AS status_display_ar,
    -- Priority with display name
    t.priority,
    lp.display_name    AS priority_display,
    lp.display_name_ar AS priority_display_ar,
    -- Approval with display name
    t.approval_status,
    la.display_name    AS approval_display,
    la.display_name_ar AS approval_display_ar,
    t.approval_notes,
    -- System info
    s.system_id,
    s.system_name,
    -- Assigned To user info
    ua.user_id   AS assigned_to_id,
    ua.full_name AS assigned_to_name,
    ua.username  AS assigned_to_user,
    ua.manager_id,
    -- Created By user info
    uc.user_id   AS created_by_id,
    uc.full_name AS created_by_name,
    uc.username  AS created_by_user,
    -- Approver info
    t.approved_by,
    uap.full_name AS approved_by_name,
    -- Department info
    ua.dept_id   AS assigned_dept_id,
    d.dept_name  AS assigned_dept_name,
    -- Computed: Overdue flag
    CASE 
        WHEN t.due_date < TRUNC(SYSDATE) 
         AND t.status NOT IN ('COMPLETED', 'CANCELLED') 
        THEN 'Y' 
        ELSE 'N' 
    END AS is_overdue,
    -- Computed: Days remaining (negative = overdue)
    TRUNC(t.due_date) - TRUNC(SYSDATE) AS days_remaining,
    -- Computed: Hours variance
    NVL(t.estimated_hours, 0) - NVL(t.actual_hours, 0) AS hours_remaining,
    -- Computed: Completion percentage
    CASE 
        WHEN NVL(t.estimated_hours, 0) = 0 THEN 0
        ELSE ROUND((NVL(t.actual_hours, 0) / t.estimated_hours) * 100, 1)
    END AS completion_pct,
    -- Subquery: Comments count
    (SELECT COUNT(*) FROM tts_comments c WHERE c.task_id = t.task_id) AS comments_count,
    -- Subquery: Attachments count
    (SELECT COUNT(*) FROM tts_attachments a WHERE a.task_id = t.task_id) AS attachments_count,
    -- Subquery: Tags (comma-separated)
    (SELECT LISTAGG(tg.tag_name, ', ') WITHIN GROUP (ORDER BY tg.tag_name)
     FROM tts_task_tags tt 
     JOIN tts_tags tg ON tg.tag_id = tt.tag_id
     WHERE tt.task_id = t.task_id
    ) AS tags_list
FROM tts_tasks t
    JOIN tts_systems    s   ON s.system_id  = t.system_id
    JOIN tts_users      ua  ON ua.user_id   = t.assigned_to
    JOIN tts_users      uc  ON uc.user_id   = t.created_by
    LEFT JOIN tts_users uap ON uap.user_id  = t.approved_by
    LEFT JOIN tts_departments d ON d.dept_id = ua.dept_id
    LEFT JOIN tts_lookups ls ON ls.lookup_type = 'TASK_STATUS'     AND ls.lookup_code = t.status
    LEFT JOIN tts_lookups lp ON lp.lookup_type = 'PRIORITY'        AND lp.lookup_code = t.priority
    LEFT JOIN tts_lookups la ON la.lookup_type = 'APPROVAL_STATUS' AND la.lookup_code = t.approval_status;

COMMENT ON TABLE v_tasks_full IS 'Master task view with all joins and computed columns — primary data source for APEX pages';

-- ============================================================
-- VIEW 2: v_user_workload — Employee Workload Summary
-- ============================================================
PROMPT Creating view: v_user_workload...

CREATE OR REPLACE VIEW v_user_workload AS
SELECT 
    u.user_id,
    u.full_name,
    u.username,
    u.role,
    u.manager_id,
    d.dept_id,
    d.dept_name,
    -- Task counts by status
    COUNT(t.task_id) AS total_tasks,
    SUM(CASE WHEN t.status = 'CREATED'     THEN 1 ELSE 0 END) AS created_count,
    SUM(CASE WHEN t.status = 'IN_PROGRESS' THEN 1 ELSE 0 END) AS in_progress_count,
    SUM(CASE WHEN t.status = 'ON_HOLD'     THEN 1 ELSE 0 END) AS on_hold_count,
    SUM(CASE WHEN t.status = 'COMPLETED'   THEN 1 ELSE 0 END) AS completed_count,
    SUM(CASE WHEN t.status = 'CANCELLED'   THEN 1 ELSE 0 END) AS cancelled_count,
    -- Hours summary
    SUM(NVL(t.estimated_hours, 0)) AS total_estimated_hours,
    SUM(NVL(t.actual_hours, 0))    AS total_actual_hours,
    -- Overdue count
    SUM(CASE 
        WHEN t.due_date < TRUNC(SYSDATE) 
         AND t.status NOT IN ('COMPLETED', 'CANCELLED') 
        THEN 1 ELSE 0 
    END) AS overdue_count,
    -- Pending approval count
    SUM(CASE WHEN t.approval_status = 'PENDING' THEN 1 ELSE 0 END) AS pending_approval_count
FROM tts_users u
    LEFT JOIN tts_tasks t ON t.assigned_to = u.user_id
    LEFT JOIN tts_departments d ON d.dept_id = u.dept_id
WHERE u.is_active = 'Y'
GROUP BY 
    u.user_id, u.full_name, u.username, u.role, u.manager_id,
    d.dept_id, d.dept_name;

COMMENT ON TABLE v_user_workload IS 'Aggregated workload statistics per user — used in team overview and manager dashboards';

-- ============================================================
-- VIEW 3: v_overdue_tasks — Overdue Tasks Only
-- ============================================================
PROMPT Creating view: v_overdue_tasks...

CREATE OR REPLACE VIEW v_overdue_tasks AS
SELECT *
FROM v_tasks_full
WHERE is_overdue = 'Y';

COMMENT ON TABLE v_overdue_tasks IS 'Filtered view showing only overdue tasks — used in dashboard alerts and reports';

-- ============================================================
-- VIEW 4: v_dashboard_stats — Dashboard Aggregate Statistics
-- ============================================================
PROMPT Creating view: v_dashboard_stats...

CREATE OR REPLACE VIEW v_dashboard_stats AS
SELECT
    COUNT(*) AS total_tasks,
    -- Status breakdown
    SUM(CASE WHEN status = 'CREATED'     THEN 1 ELSE 0 END) AS created_count,
    SUM(CASE WHEN status = 'IN_PROGRESS' THEN 1 ELSE 0 END) AS in_progress_count,
    SUM(CASE WHEN status = 'ON_HOLD'     THEN 1 ELSE 0 END) AS on_hold_count,
    SUM(CASE WHEN status = 'COMPLETED'   THEN 1 ELSE 0 END) AS completed_count,
    SUM(CASE WHEN status = 'CANCELLED'   THEN 1 ELSE 0 END) AS cancelled_count,
    -- Approval breakdown
    SUM(CASE WHEN approval_status = 'PENDING' THEN 1 ELSE 0 END) AS pending_approval_count,
    -- Overdue
    SUM(CASE 
        WHEN due_date < TRUNC(SYSDATE) 
         AND status NOT IN ('COMPLETED', 'CANCELLED') 
        THEN 1 ELSE 0 
    END) AS overdue_count,
    -- Hours totals
    SUM(NVL(estimated_hours, 0)) AS total_estimated_hours,
    SUM(NVL(actual_hours, 0))    AS total_actual_hours,
    -- Completion rate
    CASE 
        WHEN COUNT(*) = 0 THEN 0
        ELSE ROUND(
            SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1
        )
    END AS completion_rate_pct
FROM tts_tasks;

COMMENT ON TABLE v_dashboard_stats IS 'Single-row aggregate view for dashboard KPI cards and summary charts';

-- ============================================================
-- VIEW 5: v_manager_team_tasks — Manager Team Tasks
-- ============================================================
PROMPT Creating view: v_manager_team_tasks...

CREATE OR REPLACE VIEW v_manager_team_tasks AS
SELECT vt.*
FROM v_tasks_full vt;
-- Usage in APEX: Add WHERE clause to filter by manager:
-- WHERE vt.manager_id = :F_USER_ID OR vt.assigned_to_id = :F_USER_ID

COMMENT ON TABLE v_manager_team_tasks IS 'Base view for manager team tasks — filter by manager_id in APEX query';

-- ============================================================
-- DONE
-- ============================================================
PROMPT ============================================================
PROMPT  TTS Views Installation — COMPLETED SUCCESSFULLY
PROMPT  Views created: 5
PROMPT    1. v_tasks_full          (Master task view)
PROMPT    2. v_user_workload       (Employee workload summary)
PROMPT    3. v_overdue_tasks       (Overdue tasks filter)
PROMPT    4. v_dashboard_stats     (Dashboard aggregation)
PROMPT    5. v_manager_team_tasks  (Manager team view)
PROMPT ============================================================

