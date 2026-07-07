/*
================================================================================
  Daily Tasks Tracking System (TTS)
  File: triggers.sql
  Description: Database Triggers — Auto timestamps, task numbering, hour calc
  APEX Version: 24.2.17
  Author: TTS Development Team
  Created: 2026-07-07
================================================================================
  EXECUTION ORDER: Run AFTER schema.sql and seed_data.sql
                   Run BEFORE packages.sql (triggers are independent of packages)
================================================================================
*/

SET SERVEROUTPUT ON;
SET DEFINE OFF;

PROMPT ============================================================
PROMPT  TTS Triggers Installation — Starting...
PROMPT ============================================================

-- ============================================================
-- TRIGGER 1: Auto-update updated_at on tts_users
-- ============================================================
PROMPT Creating trigger: trg_users_updated...

CREATE OR REPLACE TRIGGER trg_users_updated
    BEFORE UPDATE ON tts_users
    FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END trg_users_updated;
/

-- ============================================================
-- TRIGGER 2: Auto-update updated_at on tts_tasks
-- ============================================================
PROMPT Creating trigger: trg_tasks_updated...

CREATE OR REPLACE TRIGGER trg_tasks_updated
    BEFORE UPDATE ON tts_tasks
    FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END trg_tasks_updated;
/

-- ============================================================
-- TRIGGER 3: Auto-update updated_at on tts_systems
-- ============================================================
PROMPT Creating trigger: trg_systems_updated...

CREATE OR REPLACE TRIGGER trg_systems_updated
    BEFORE UPDATE ON tts_systems
    FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END trg_systems_updated;
/

-- ============================================================
-- TRIGGER 4: Auto-update updated_at on tts_departments
-- ============================================================
PROMPT Creating trigger: trg_depts_updated...

CREATE OR REPLACE TRIGGER trg_depts_updated
    BEFORE UPDATE ON tts_departments
    FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END trg_depts_updated;
/

-- ============================================================
-- TRIGGER 5: Auto-generate task_number on new task creation
-- ============================================================
PROMPT Creating trigger: trg_task_number...

CREATE OR REPLACE TRIGGER trg_task_number
    BEFORE INSERT ON tts_tasks
    FOR EACH ROW
BEGIN
    -- Generate human-readable task number: TSK-000001, TSK-000002, ...
    IF :NEW.task_number IS NULL THEN
        :NEW.task_number := 'TSK-' || LPAD(tts_task_number_seq.NEXTVAL, 6, '0');
    END IF;
END trg_task_number;
/

-- ============================================================
-- TRIGGER 6: Auto-recalculate actual_hours when daily_log changes
-- ============================================================
PROMPT Creating trigger: trg_daily_log_calc...

CREATE OR REPLACE TRIGGER trg_daily_log_calc
    AFTER INSERT OR UPDATE OR DELETE ON tts_daily_log
    FOR EACH ROW
DECLARE
    v_task_id NUMBER;
    v_total   NUMBER;
BEGIN
    -- Determine which task to recalculate
    -- On DELETE, :NEW is NULL so we use :OLD
    v_task_id := NVL(:NEW.task_id, :OLD.task_id);
    
    -- Sum all daily log entries for this task
    SELECT NVL(SUM(hours_spent), 0)
    INTO   v_total
    FROM   tts_daily_log
    WHERE  task_id = v_task_id;
    
    -- Update the task's actual_hours with the computed total
    UPDATE tts_tasks
    SET    actual_hours = v_total
    WHERE  task_id = v_task_id;
    
END trg_daily_log_calc;
/

-- ============================================================
-- DONE
-- ============================================================
PROMPT ============================================================
PROMPT  TTS Triggers Installation — COMPLETED SUCCESSFULLY
PROMPT  Triggers created: 6
PROMPT    1. trg_users_updated    (Auto timestamp on tts_users)
PROMPT    2. trg_tasks_updated    (Auto timestamp on tts_tasks)
PROMPT    3. trg_systems_updated  (Auto timestamp on tts_systems)
PROMPT    4. trg_depts_updated    (Auto timestamp on tts_departments)
PROMPT    5. trg_task_number      (Auto task number: TSK-XXXXXX)
PROMPT    6. trg_daily_log_calc   (Auto recalc actual_hours)
PROMPT ============================================================

