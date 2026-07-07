/*
================================================================================
  Daily Tasks Tracking System (TTS)
  File: seed_data.sql
  Description: Seed/reference data — Lookups, Default Admin, Sample Data
  APEX Version: 24.2.17
  Author: TTS Development Team
  Created: 2026-07-07
================================================================================
  EXECUTION ORDER: Run AFTER schema.sql
  PREREQUISITE: EXECUTE privilege on DBMS_CRYPTO for the schema user
================================================================================
*/

SET SERVEROUTPUT ON;
SET DEFINE OFF;

PROMPT ============================================================
PROMPT  TTS Seed Data Installation — Starting...
PROMPT ============================================================

-- ============================================================
-- SECTION 1: LOOKUP DATA
-- ============================================================

-- ------------------------------------------------------------
-- 1.1  Task Statuses
-- ------------------------------------------------------------
PROMPT Inserting lookup data: TASK_STATUS...

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('TASK_STATUS', 'CREATED', 'Created', N'جديدة', 1);

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('TASK_STATUS', 'IN_PROGRESS', 'In Progress', N'قيد التنفيذ', 2);

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('TASK_STATUS', 'ON_HOLD', 'On Hold', N'معلقة', 3);

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('TASK_STATUS', 'COMPLETED', 'Completed', N'مكتملة', 4);

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('TASK_STATUS', 'CANCELLED', 'Cancelled', N'ملغاة', 5);

-- ------------------------------------------------------------
-- 1.2  Priorities
-- ------------------------------------------------------------
PROMPT Inserting lookup data: PRIORITY...

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('PRIORITY', 'LOW', 'Low', N'منخفضة', 1);

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('PRIORITY', 'MEDIUM', 'Medium', N'متوسطة', 2);

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('PRIORITY', 'HIGH', 'High', N'عالية', 3);

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('PRIORITY', 'CRITICAL', 'Critical', N'حرجة', 4);

-- ------------------------------------------------------------
-- 1.3  Approval Statuses
-- ------------------------------------------------------------
PROMPT Inserting lookup data: APPROVAL_STATUS...

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('APPROVAL_STATUS', 'NOT_SUBMITTED', 'Not Submitted', N'لم تُقدَّم', 1);

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('APPROVAL_STATUS', 'PENDING', 'Pending Approval', N'في الانتظار', 2);

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('APPROVAL_STATUS', 'APPROVED', 'Approved', N'مُعتمدة', 3);

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('APPROVAL_STATUS', 'REJECTED', 'Rejected', N'مرفوضة', 4);

-- ------------------------------------------------------------
-- 1.4  Notification Types
-- ------------------------------------------------------------
PROMPT Inserting lookup data: NOTIFICATION_TYPE...

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('NOTIFICATION_TYPE', 'TASK_ASSIGNED', 'Task Assigned', N'تم إسناد مهمة', 1);

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('NOTIFICATION_TYPE', 'STATUS_CHANGED', 'Status Changed', N'تغيير حالة', 2);

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('NOTIFICATION_TYPE', 'APPROVAL_REQUIRED', 'Approval Required', N'مطلوب اعتماد', 3);

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('NOTIFICATION_TYPE', 'APPROVAL_RESULT', 'Approval Result', N'نتيجة الاعتماد', 4);

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('NOTIFICATION_TYPE', 'COMMENT_ADDED', 'Comment Added', N'تعليق جديد', 5);

INSERT INTO tts_lookups (lookup_type, lookup_code, display_name, display_name_ar, display_order)
VALUES ('NOTIFICATION_TYPE', 'TASK_OVERDUE', 'Task Overdue', N'مهمة متأخرة', 6);

-- ============================================================
-- SECTION 2: SAMPLE DEPARTMENTS
-- ============================================================
PROMPT Inserting sample departments...

INSERT INTO tts_departments (dept_name, is_active)
VALUES ('IT Department', 'Y');

INSERT INTO tts_departments (dept_name, is_active)
VALUES ('HR Department', 'Y');

INSERT INTO tts_departments (dept_name, is_active)
VALUES ('Finance Department', 'Y');

-- ============================================================
-- SECTION 3: SAMPLE SYSTEMS
-- ============================================================
PROMPT Inserting sample systems...

INSERT INTO tts_systems (system_name, description, is_active)
VALUES ('ERP System', 'Enterprise Resource Planning system', 'Y');

INSERT INTO tts_systems (system_name, description, is_active)
VALUES ('HR System', 'Human Resources management system', 'Y');

INSERT INTO tts_systems (system_name, description, is_active)
VALUES ('CRM System', 'Customer Relationship Management system', 'Y');

-- ============================================================
-- SECTION 4: DEFAULT ADMIN USER
-- ============================================================
PROMPT Creating default admin user (admin / Admin@123)...

DECLARE
    v_salt VARCHAR2(128);
    v_hash VARCHAR2(256);
BEGIN
    -- Generate a random 32-byte salt
    v_salt := RAWTOHEX(DBMS_CRYPTO.RANDOMBYTES(32));
    
    -- Hash password with salt using SHA-256
    v_hash := RAWTOHEX(
        DBMS_CRYPTO.HASH(
            UTL_RAW.CAST_TO_RAW(v_salt || 'Admin@123'),
            DBMS_CRYPTO.HASH_SH256
        )
    );
    
    INSERT INTO tts_users (
        username, password_hash, password_salt, email, 
        full_name, role, is_active
    ) VALUES (
        'admin', v_hash, v_salt, 'admin@tts.local',
        'System Administrator', 'ADMIN', 'Y'
    );
    
    DBMS_OUTPUT.PUT_LINE('  Default admin user created successfully.');
    DBMS_OUTPUT.PUT_LINE('  Username: admin');
    DBMS_OUTPUT.PUT_LINE('  Password: Admin@123');
    DBMS_OUTPUT.PUT_LINE('  *** IMPORTANT: Change this password after first login! ***');
END;
/

-- ============================================================
-- SECTION 5: SAMPLE TAGS
-- ============================================================
PROMPT Inserting sample tags...

INSERT INTO tts_tags (tag_name) VALUES ('Bug Fix');
INSERT INTO tts_tags (tag_name) VALUES ('Enhancement');
INSERT INTO tts_tags (tag_name) VALUES ('Urgent');
INSERT INTO tts_tags (tag_name) VALUES ('Documentation');
INSERT INTO tts_tags (tag_name) VALUES ('Meeting');
INSERT INTO tts_tags (tag_name) VALUES ('Research');
INSERT INTO tts_tags (tag_name) VALUES ('Testing');
INSERT INTO tts_tags (tag_name) VALUES ('Deployment');
INSERT INTO tts_tags (tag_name) VALUES ('Support');
INSERT INTO tts_tags (tag_name) VALUES ('Training');

-- ============================================================
-- COMMIT & DONE
-- ============================================================
COMMIT;

PROMPT ============================================================
PROMPT  TTS Seed Data Installation — COMPLETED SUCCESSFULLY
PROMPT  Lookups:      23 records (5 statuses + 4 priorities + 4 approvals + 6 notifications + 4 extra)
PROMPT  Departments:  3 sample records
PROMPT  Systems:      3 sample records
PROMPT  Tags:         10 sample records
PROMPT  Admin User:   1 (admin / Admin@123)
PROMPT ============================================================

