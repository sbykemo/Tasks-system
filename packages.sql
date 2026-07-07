/*
================================================================================
  Daily Tasks Tracking System (TTS)
  File: packages.sql
  Description: PL/SQL Packages — Complete Specs & Bodies
                Package 1: tts_pkg_security   (Auth, Authorization, Passwords)
                Package 2: tts_pkg_notifications (In-App & Email Notifications)
                Package 3: tts_pkg_tasks       (Task Lifecycle & Workflow)
                Package 4: tts_pkg_admin       (User & Admin Management)
  APEX Version: 24.2.17
  Author: TTS Development Team
  Created: 2026-07-07
================================================================================
  EXECUTION ORDER: Run AFTER schema.sql, seed_data.sql, views.sql, triggers.sql
  PREREQUISITES:
    - EXECUTE on DBMS_CRYPTO
    - EXECUTE on APEX_MAIL (for email notifications)
    - APEX application items: F_USER_ID, F_USER_ROLE, F_FULL_NAME, F_DEPT_ID
================================================================================
*/

SET SERVEROUTPUT ON;
SET DEFINE OFF;

PROMPT ============================================================
PROMPT  TTS Packages Installation — Starting...
PROMPT ============================================================

-- ################################################################
-- ##  PACKAGE 1: tts_pkg_security
-- ##  Authentication, Authorization, Password Management
-- ################################################################

-- ============================================================
-- SPEC: tts_pkg_security
-- ============================================================
PROMPT Creating package spec: tts_pkg_security...

CREATE OR REPLACE PACKAGE tts_pkg_security AS
    /*
    ---------------------------------------------------------------
    tts_pkg_security
    Handles all security-related operations:
      - Password hashing with SHA-256 + salt
      - Custom APEX authentication
      - Post-authentication session setup
      - Authorization checks
      - Password change
    ---------------------------------------------------------------
    */
    
    -- Generate a random 32-byte salt (returned as hex string)
    FUNCTION generate_salt RETURN VARCHAR2;
    
    -- Hash a password using SHA-256 with the given salt
    FUNCTION hash_password(
        p_password IN VARCHAR2,
        p_salt     IN VARCHAR2
    ) RETURN VARCHAR2;
    
    -- Custom APEX Authentication function
    -- Returns TRUE if credentials are valid
    FUNCTION authenticate_user(
        p_username IN VARCHAR2,
        p_password IN VARCHAR2
    ) RETURN BOOLEAN;
    
    -- Post-authentication: set APEX session items (F_USER_ID, F_USER_ROLE, etc.)
    PROCEDURE post_auth(
        p_username IN VARCHAR2
    );
    
    -- Check if a user can edit a specific task
    FUNCTION can_user_edit_task(
        p_user_id IN NUMBER,
        p_task_id IN NUMBER
    ) RETURN BOOLEAN;
    
    -- Check if p_manager_id is the direct manager of p_employee_id
    FUNCTION is_manager_of(
        p_manager_id  IN NUMBER,
        p_employee_id IN NUMBER
    ) RETURN BOOLEAN;
    
    -- Change a user's password (validates old password first)
    PROCEDURE change_password(
        p_user_id      IN NUMBER,
        p_old_password IN VARCHAR2,
        p_new_password IN VARCHAR2
    );

END tts_pkg_security;
/

-- ============================================================
-- BODY: tts_pkg_security
-- ============================================================
PROMPT Creating package body: tts_pkg_security...

CREATE OR REPLACE PACKAGE BODY tts_pkg_security AS

    -- --------------------------------------------------------
    -- generate_salt: Creates a random 32-byte hex string
    -- --------------------------------------------------------
    FUNCTION generate_salt RETURN VARCHAR2 IS
    BEGIN
        RETURN RAWTOHEX(DBMS_CRYPTO.RANDOMBYTES(32));
    END generate_salt;
    
    -- --------------------------------------------------------
    -- hash_password: SHA-256 hash of (salt + password)
    -- --------------------------------------------------------
    FUNCTION hash_password(
        p_password IN VARCHAR2,
        p_salt     IN VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        RETURN RAWTOHEX(
            DBMS_CRYPTO.HASH(
                UTL_RAW.CAST_TO_RAW(p_salt || p_password),
                DBMS_CRYPTO.HASH_SH256
            )
        );
    END hash_password;
    
    -- --------------------------------------------------------
    -- authenticate_user: Validate credentials against tts_users
    -- Updates last_login timestamp on success
    -- --------------------------------------------------------
    FUNCTION authenticate_user(
        p_username IN VARCHAR2,
        p_password IN VARCHAR2
    ) RETURN BOOLEAN IS
        v_stored_hash VARCHAR2(256);
        v_stored_salt VARCHAR2(128);
        v_computed    VARCHAR2(256);
        v_user_id     NUMBER;
    BEGIN
        -- Retrieve stored credentials
        BEGIN
            SELECT user_id, password_hash, password_salt
            INTO   v_user_id, v_stored_hash, v_stored_salt
            FROM   tts_users
            WHERE  UPPER(username) = UPPER(p_username)
            AND    is_active = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN FALSE;
        END;
        
        -- Compute hash with stored salt
        v_computed := hash_password(p_password, v_stored_salt);
        
        -- Compare
        IF v_computed = v_stored_hash THEN
            -- Update last login timestamp
            UPDATE tts_users 
            SET    last_login = SYSTIMESTAMP
            WHERE  user_id = v_user_id;
            COMMIT;
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    END authenticate_user;
    
    -- --------------------------------------------------------
    -- post_auth: Set APEX session application items
    -- Called in APEX Authentication Scheme > Post-Authentication
    -- --------------------------------------------------------
    PROCEDURE post_auth(
        p_username IN VARCHAR2
    ) IS
        v_user_id   NUMBER;
        v_role      VARCHAR2(20);
        v_full_name VARCHAR2(150);
        v_dept_id   NUMBER;
    BEGIN
        SELECT user_id, role, full_name, dept_id
        INTO   v_user_id, v_role, v_full_name, v_dept_id
        FROM   tts_users
        WHERE  UPPER(username) = UPPER(p_username)
        AND    is_active = 'Y';
        
        -- Set APEX application-level items for use in all pages
        APEX_UTIL.SET_SESSION_STATE('F_USER_ID',   TO_CHAR(v_user_id));
        APEX_UTIL.SET_SESSION_STATE('F_USER_ROLE',  v_role);
        APEX_UTIL.SET_SESSION_STATE('F_FULL_NAME',  v_full_name);
        APEX_UTIL.SET_SESSION_STATE('F_DEPT_ID',    TO_CHAR(v_dept_id));
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20010, 'User not found during post-authentication: ' || p_username);
    END post_auth;
    
    -- --------------------------------------------------------
    -- can_user_edit_task: Authorization check
    -- Returns TRUE if user is:
    --   1. ADMIN (can edit any task)
    --   2. The task's assigned_to user
    --   3. The task's creator (created_by)
    --   4. The manager of the assigned user
    -- --------------------------------------------------------
    FUNCTION can_user_edit_task(
        p_user_id IN NUMBER,
        p_task_id IN NUMBER
    ) RETURN BOOLEAN IS
        v_role        VARCHAR2(20);
        v_assigned_to NUMBER;
        v_created_by  NUMBER;
        v_count       NUMBER;
    BEGIN
        -- Get user role
        BEGIN
            SELECT role INTO v_role 
            FROM tts_users WHERE user_id = p_user_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN RETURN FALSE;
        END;
        
        -- Admins can edit everything
        IF v_role = 'ADMIN' THEN
            RETURN TRUE;
        END IF;
        
        -- Get task assignment info
        BEGIN
            SELECT assigned_to, created_by
            INTO   v_assigned_to, v_created_by
            FROM   tts_tasks
            WHERE  task_id = p_task_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN RETURN FALSE;
        END;
        
        -- Check if user is assigned to or created the task
        IF p_user_id IN (v_assigned_to, v_created_by) THEN
            RETURN TRUE;
        END IF;
        
        -- Check if user is the manager of the assigned person
        IF is_manager_of(p_user_id, v_assigned_to) THEN
            RETURN TRUE;
        END IF;
        
        RETURN FALSE;
    END can_user_edit_task;
    
    -- --------------------------------------------------------
    -- is_manager_of: Check direct manager relationship
    -- --------------------------------------------------------
    FUNCTION is_manager_of(
        p_manager_id  IN NUMBER,
        p_employee_id IN NUMBER
    ) RETURN BOOLEAN IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO   v_count
        FROM   tts_users
        WHERE  user_id    = p_employee_id
        AND    manager_id = p_manager_id;
        
        RETURN (v_count > 0);
    END is_manager_of;
    
    -- --------------------------------------------------------
    -- change_password: Validate old, set new with fresh salt
    -- --------------------------------------------------------
    PROCEDURE change_password(
        p_user_id      IN NUMBER,
        p_old_password IN VARCHAR2,
        p_new_password IN VARCHAR2
    ) IS
        v_username    VARCHAR2(50);
        v_stored_hash VARCHAR2(256);
        v_stored_salt VARCHAR2(128);
        v_computed    VARCHAR2(256);
        v_new_salt    VARCHAR2(128);
        v_new_hash    VARCHAR2(256);
    BEGIN
        -- Validate new password length
        IF LENGTH(p_new_password) < 8 THEN
            RAISE_APPLICATION_ERROR(-20011, 'New password must be at least 8 characters long.');
        END IF;
        
        -- Retrieve current credentials
        BEGIN
            SELECT username, password_hash, password_salt
            INTO   v_username, v_stored_hash, v_stored_salt
            FROM   tts_users
            WHERE  user_id = p_user_id
            AND    is_active = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20012, 'User not found or inactive.');
        END;
        
        -- Verify old password
        v_computed := hash_password(p_old_password, v_stored_salt);
        IF v_computed != v_stored_hash THEN
            RAISE_APPLICATION_ERROR(-20013, 'Current password is incorrect.');
        END IF;
        
        -- Generate new salt and hash
        v_new_salt := generate_salt;
        v_new_hash := hash_password(p_new_password, v_new_salt);
        
        -- Update password
        UPDATE tts_users
        SET    password_hash = v_new_hash,
               password_salt = v_new_salt
        WHERE  user_id = p_user_id;
        
        COMMIT;
    END change_password;

END tts_pkg_security;
/


-- ################################################################
-- ##  PACKAGE 2: tts_pkg_notifications
-- ##  In-App Notifications & Email Delivery
-- ################################################################

-- ============================================================
-- SPEC: tts_pkg_notifications
-- ============================================================
PROMPT Creating package spec: tts_pkg_notifications...

CREATE OR REPLACE PACKAGE tts_pkg_notifications AS
    /*
    ---------------------------------------------------------------
    tts_pkg_notifications
    Handles notification lifecycle:
      - Create in-app notifications
      - Send email notifications via APEX_MAIL
      - Mark as read (single/all)
      - Get unread count for badge display
    ---------------------------------------------------------------
    */
    
    -- Create an in-app notification (optionally sends email)
    PROCEDURE create_notification(
        p_user_id   IN NUMBER,
        p_task_id   IN NUMBER   DEFAULT NULL,
        p_type      IN VARCHAR2,
        p_message   IN VARCHAR2
    );
    
    -- Send email notification via APEX_MAIL
    PROCEDURE send_email_notification(
        p_user_id  IN NUMBER,
        p_subject  IN VARCHAR2,
        p_body     IN CLOB
    );
    
    -- Mark a single notification as read
    PROCEDURE mark_as_read(
        p_notification_id IN NUMBER
    );
    
    -- Mark ALL notifications as read for a user
    PROCEDURE mark_all_read(
        p_user_id IN NUMBER
    );
    
    -- Get unread notification count (for nav bar badge)
    FUNCTION get_unread_count(
        p_user_id IN NUMBER
    ) RETURN NUMBER;

END tts_pkg_notifications;
/

-- ============================================================
-- BODY: tts_pkg_notifications
-- ============================================================
PROMPT Creating package body: tts_pkg_notifications...

CREATE OR REPLACE PACKAGE BODY tts_pkg_notifications AS

    -- --------------------------------------------------------
    -- create_notification: Insert notification + attempt email
    -- --------------------------------------------------------
    PROCEDURE create_notification(
        p_user_id   IN NUMBER,
        p_task_id   IN NUMBER   DEFAULT NULL,
        p_type      IN VARCHAR2,
        p_message   IN VARCHAR2
    ) IS
        v_notif_id NUMBER;
        v_email_ok CHAR(1) := 'N';
        v_task_num VARCHAR2(20);
        v_subject  VARCHAR2(200);
    BEGIN
        -- Insert the in-app notification
        INSERT INTO tts_notifications (
            user_id, task_id, notification_type, message
        ) VALUES (
            p_user_id, p_task_id, p_type, p_message
        ) RETURNING notification_id INTO v_notif_id;
        
        -- Attempt to send email notification
        BEGIN
            -- Build email subject
            IF p_task_id IS NOT NULL THEN
                BEGIN
                    SELECT task_number INTO v_task_num
                    FROM tts_tasks WHERE task_id = p_task_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        v_task_num := 'N/A';
                END;
                v_subject := 'TTS Notification [' || v_task_num || ']: ' || p_type;
            ELSE
                v_subject := 'TTS Notification: ' || p_type;
            END IF;
            
            send_email_notification(
                p_user_id => p_user_id,
                p_subject => v_subject,
                p_body    => p_message
            );
            
            v_email_ok := 'Y';
        EXCEPTION
            WHEN OTHERS THEN
                -- Email failure should not block notification creation
                v_email_ok := 'N';
        END;
        
        -- Update email sent status
        UPDATE tts_notifications
        SET    email_sent = v_email_ok
        WHERE  notification_id = v_notif_id;
        
    END create_notification;
    
    -- --------------------------------------------------------
    -- send_email_notification: Send via APEX_MAIL
    -- --------------------------------------------------------
    PROCEDURE send_email_notification(
        p_user_id  IN NUMBER,
        p_subject  IN VARCHAR2,
        p_body     IN CLOB
    ) IS
        v_email VARCHAR2(100);
    BEGIN
        -- Get user email
        BEGIN
            SELECT email INTO v_email
            FROM   tts_users
            WHERE  user_id = p_user_id
            AND    is_active = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN; -- Silent exit if user not found
        END;
        
        -- Send email via APEX_MAIL
        APEX_MAIL.SEND(
            p_to   => v_email,
            p_from => 'tts-noreply@company.com',
            p_subj => p_subject,
            p_body => p_body
        );
        
        -- Push to mail queue
        APEX_MAIL.PUSH_QUEUE;
        
    END send_email_notification;
    
    -- --------------------------------------------------------
    -- mark_as_read: Single notification
    -- --------------------------------------------------------
    PROCEDURE mark_as_read(
        p_notification_id IN NUMBER
    ) IS
    BEGIN
        UPDATE tts_notifications
        SET    is_read = 'Y'
        WHERE  notification_id = p_notification_id;
    END mark_as_read;
    
    -- --------------------------------------------------------
    -- mark_all_read: All notifications for a user
    -- --------------------------------------------------------
    PROCEDURE mark_all_read(
        p_user_id IN NUMBER
    ) IS
    BEGIN
        UPDATE tts_notifications
        SET    is_read = 'Y'
        WHERE  user_id = p_user_id
        AND    is_read = 'N';
    END mark_all_read;
    
    -- --------------------------------------------------------
    -- get_unread_count: For nav bar badge display
    -- --------------------------------------------------------
    FUNCTION get_unread_count(
        p_user_id IN NUMBER
    ) RETURN NUMBER IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO   v_count
        FROM   tts_notifications
        WHERE  user_id = p_user_id
        AND    is_read = 'N';
        
        RETURN v_count;
    END get_unread_count;

END tts_pkg_notifications;
/


-- ################################################################
-- ##  PACKAGE 3: tts_pkg_tasks
-- ##  Task Lifecycle, Workflow, Comments, Time Logging
-- ################################################################

-- ============================================================
-- SPEC: tts_pkg_tasks
-- ============================================================
PROMPT Creating package spec: tts_pkg_tasks...

CREATE OR REPLACE PACKAGE tts_pkg_tasks AS
    /*
    ---------------------------------------------------------------
    tts_pkg_tasks
    Core task management operations:
      - Task CRUD with auto-numbering
      - Status transitions with validation rules
      - Reassignment with audit trail
      - Approval workflow (submit, approve, reject)
      - Daily time logging
      - Comments
      - History/audit logging
    ---------------------------------------------------------------
    */
    
    -- Create a new task, returns the generated task_id
    FUNCTION create_task(
        p_title           IN VARCHAR2,
        p_description     IN CLOB     DEFAULT NULL,
        p_system_id       IN NUMBER,
        p_assigned_to     IN NUMBER,
        p_created_by      IN NUMBER,
        p_priority        IN VARCHAR2 DEFAULT 'MEDIUM',
        p_start_date      IN DATE,
        p_due_date        IN DATE,
        p_estimated_hours IN NUMBER
    ) RETURN NUMBER;
    
    -- Update task status with transition validation
    PROCEDURE update_task_status(
        p_task_id    IN NUMBER,
        p_new_status IN VARCHAR2,
        p_user_id    IN NUMBER
    );
    
    -- Reassign task to a different user
    PROCEDURE reassign_task(
        p_task_id         IN NUMBER,
        p_new_assigned_to IN NUMBER,
        p_changed_by      IN NUMBER
    );
    
    -- Submit completed task for manager approval
    PROCEDURE submit_for_approval(
        p_task_id IN NUMBER,
        p_user_id IN NUMBER
    );
    
    -- Manager approves or rejects a task
    PROCEDURE process_approval(
        p_task_id    IN NUMBER,
        p_decision   IN VARCHAR2,
        p_manager_id IN NUMBER,
        p_notes      IN VARCHAR2 DEFAULT NULL
    );
    
    -- Log daily hours worked on a task
    PROCEDURE log_daily_hours(
        p_task_id     IN NUMBER,
        p_user_id     IN NUMBER,
        p_log_date    IN DATE,
        p_hours_spent IN NUMBER,
        p_notes       IN VARCHAR2 DEFAULT NULL
    );
    
    -- Recalculate actual_hours from daily_log entries
    PROCEDURE recalc_actual_hours(
        p_task_id IN NUMBER
    );
    
    -- Add a comment to a task
    PROCEDURE add_comment(
        p_task_id      IN NUMBER,
        p_user_id      IN NUMBER,
        p_comment_text IN CLOB
    );
    
    -- Write an entry to the audit trail
    PROCEDURE log_history(
        p_task_id     IN NUMBER,
        p_changed_by  IN NUMBER,
        p_change_type IN VARCHAR2,
        p_old_value   IN VARCHAR2,
        p_new_value   IN VARCHAR2
    );

END tts_pkg_tasks;
/

-- ============================================================
-- BODY: tts_pkg_tasks
-- ============================================================
PROMPT Creating package body: tts_pkg_tasks...

CREATE OR REPLACE PACKAGE BODY tts_pkg_tasks AS

    -- --------------------------------------------------------
    -- create_task: Insert new task, notify assignee, log history
    -- task_number is auto-generated by trg_task_number trigger
    -- --------------------------------------------------------
    FUNCTION create_task(
        p_title           IN VARCHAR2,
        p_description     IN CLOB     DEFAULT NULL,
        p_system_id       IN NUMBER,
        p_assigned_to     IN NUMBER,
        p_created_by      IN NUMBER,
        p_priority        IN VARCHAR2 DEFAULT 'MEDIUM',
        p_start_date      IN DATE,
        p_due_date        IN DATE,
        p_estimated_hours IN NUMBER
    ) RETURN NUMBER IS
        v_task_id     NUMBER;
        v_task_number VARCHAR2(20);
        v_creator_name VARCHAR2(150);
    BEGIN
        -- Validate dates
        IF p_due_date < p_start_date THEN
            RAISE_APPLICATION_ERROR(-20001, 'Due date cannot be before start date.');
        END IF;
        
        -- Validate estimated hours
        IF NVL(p_estimated_hours, 0) < 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Estimated hours cannot be negative.');
        END IF;
        
        -- Insert the task (task_number auto-generated by trigger)
        INSERT INTO tts_tasks (
            task_number, title, description, system_id, 
            assigned_to, created_by, priority,
            start_date, due_date, estimated_hours,
            status, approval_status
        ) VALUES (
            NULL, -- trigger will generate
            p_title, p_description, p_system_id,
            p_assigned_to, p_created_by, p_priority,
            p_start_date, p_due_date, p_estimated_hours,
            'CREATED', 'NOT_SUBMITTED'
        ) RETURNING task_id, task_number INTO v_task_id, v_task_number;
        
        -- Log creation in history
        log_history(
            p_task_id     => v_task_id,
            p_changed_by  => p_created_by,
            p_change_type => 'CREATED',
            p_old_value   => NULL,
            p_new_value   => 'Task ' || v_task_number || ' created'
        );
        
        -- Notify the assigned user (if different from creator)
        IF p_assigned_to != p_created_by THEN
            BEGIN
                SELECT full_name INTO v_creator_name
                FROM tts_users WHERE user_id = p_created_by;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN v_creator_name := 'Unknown';
            END;
            
            tts_pkg_notifications.create_notification(
                p_user_id => p_assigned_to,
                p_task_id => v_task_id,
                p_type    => 'TASK_ASSIGNED',
                p_message => 'New task assigned to you: ' || p_title || ' by ' || v_creator_name
            );
        END IF;
        
        RETURN v_task_id;
        
    END create_task;
    
    -- --------------------------------------------------------
    -- update_task_status: Validates transition rules
    --
    -- Valid transitions:
    --   CREATED     -> IN_PROGRESS, CANCELLED
    --   IN_PROGRESS -> ON_HOLD, COMPLETED, CANCELLED
    --   ON_HOLD     -> IN_PROGRESS, CANCELLED
    --   COMPLETED   -> IN_PROGRESS (only if approval rejected)
    --   CANCELLED   -> (no transitions allowed)
    -- --------------------------------------------------------
    PROCEDURE update_task_status(
        p_task_id    IN NUMBER,
        p_new_status IN VARCHAR2,
        p_user_id    IN NUMBER
    ) IS
        v_old_status      VARCHAR2(20);
        v_approval_status VARCHAR2(20);
        v_is_valid        BOOLEAN := FALSE;
        v_assigned_to     NUMBER;
    BEGIN
        -- Get current task state
        BEGIN
            SELECT status, approval_status, assigned_to
            INTO   v_old_status, v_approval_status, v_assigned_to
            FROM   tts_tasks
            WHERE  task_id = p_task_id
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003, 'Task not found: ' || p_task_id);
        END;
        
        -- No change needed
        IF v_old_status = p_new_status THEN
            RETURN;
        END IF;
        
        -- Validate transition rules
        CASE v_old_status
            WHEN 'CREATED' THEN
                v_is_valid := p_new_status IN ('IN_PROGRESS', 'CANCELLED');
                
            WHEN 'IN_PROGRESS' THEN
                v_is_valid := p_new_status IN ('ON_HOLD', 'COMPLETED', 'CANCELLED');
                
            WHEN 'ON_HOLD' THEN
                v_is_valid := p_new_status IN ('IN_PROGRESS', 'CANCELLED');
                
            WHEN 'COMPLETED' THEN
                -- Can only go back to IN_PROGRESS if approval was rejected
                v_is_valid := (p_new_status = 'IN_PROGRESS' AND v_approval_status = 'REJECTED');
                
            WHEN 'CANCELLED' THEN
                v_is_valid := FALSE; -- No transitions from CANCELLED
                
            ELSE
                v_is_valid := FALSE;
        END CASE;
        
        IF NOT v_is_valid THEN
            RAISE_APPLICATION_ERROR(-20004, 
                'Invalid status transition from ' || v_old_status || ' to ' || p_new_status);
        END IF;
        
        -- Perform the update
        UPDATE tts_tasks
        SET    status = p_new_status,
               completion_date = CASE 
                   WHEN p_new_status = 'COMPLETED' THEN SYSDATE 
                   ELSE NULL 
               END
        WHERE  task_id = p_task_id;
        
        -- Log history
        log_history(
            p_task_id     => p_task_id,
            p_changed_by  => p_user_id,
            p_change_type => 'STATUS',
            p_old_value   => v_old_status,
            p_new_value   => p_new_status
        );
        
        -- Notify assigned user of status change (if changed by someone else)
        IF p_user_id != v_assigned_to THEN
            tts_pkg_notifications.create_notification(
                p_user_id => v_assigned_to,
                p_task_id => p_task_id,
                p_type    => 'STATUS_CHANGED',
                p_message => 'Task status changed from ' || v_old_status || ' to ' || p_new_status
            );
        END IF;
        
    END update_task_status;
    
    -- --------------------------------------------------------
    -- reassign_task: Move task to different user with audit
    -- --------------------------------------------------------
    PROCEDURE reassign_task(
        p_task_id         IN NUMBER,
        p_new_assigned_to IN NUMBER,
        p_changed_by      IN NUMBER
    ) IS
        v_old_assigned_to NUMBER;
        v_old_name        VARCHAR2(150);
        v_new_name        VARCHAR2(150);
        v_title           VARCHAR2(250);
    BEGIN
        -- Get current assignment
        BEGIN
            SELECT assigned_to, title
            INTO   v_old_assigned_to, v_title
            FROM   tts_tasks
            WHERE  task_id = p_task_id
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20005, 'Task not found: ' || p_task_id);
        END;
        
        -- No change needed
        IF v_old_assigned_to = p_new_assigned_to THEN
            RETURN;
        END IF;
        
        -- Get user names for audit trail
        BEGIN
            SELECT full_name INTO v_old_name 
            FROM tts_users WHERE user_id = v_old_assigned_to;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN v_old_name := 'Unknown (ID: ' || v_old_assigned_to || ')';
        END;
        
        BEGIN
            SELECT full_name INTO v_new_name 
            FROM tts_users WHERE user_id = p_new_assigned_to;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20006, 'New assignee not found: ' || p_new_assigned_to);
        END;
        
        -- Update assignment
        UPDATE tts_tasks
        SET    assigned_to = p_new_assigned_to
        WHERE  task_id = p_task_id;
        
        -- Log history
        log_history(
            p_task_id     => p_task_id,
            p_changed_by  => p_changed_by,
            p_change_type => 'ASSIGNMENT',
            p_old_value   => v_old_name,
            p_new_value   => v_new_name
        );
        
        -- Notify the new assignee
        tts_pkg_notifications.create_notification(
            p_user_id => p_new_assigned_to,
            p_task_id => p_task_id,
            p_type    => 'TASK_ASSIGNED',
            p_message => 'Task "' || v_title || '" has been reassigned to you.'
        );
        
        -- Notify the old assignee
        tts_pkg_notifications.create_notification(
            p_user_id => v_old_assigned_to,
            p_task_id => p_task_id,
            p_type    => 'TASK_ASSIGNED',
            p_message => 'Task "' || v_title || '" has been reassigned from you to ' || v_new_name || '.'
        );
        
    END reassign_task;
    
    -- --------------------------------------------------------
    -- submit_for_approval: Employee requests manager approval
    -- Task must be in COMPLETED status
    -- --------------------------------------------------------
    PROCEDURE submit_for_approval(
        p_task_id IN NUMBER,
        p_user_id IN NUMBER
    ) IS
        v_status      VARCHAR2(20);
        v_assigned_to NUMBER;
        v_manager_id  NUMBER;
        v_title       VARCHAR2(250);
        v_user_name   VARCHAR2(150);
    BEGIN
        -- Get task info
        BEGIN
            SELECT status, assigned_to, title
            INTO   v_status, v_assigned_to, v_title
            FROM   tts_tasks
            WHERE  task_id = p_task_id
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20007, 'Task not found: ' || p_task_id);
        END;
        
        -- Validate: only COMPLETED tasks can be submitted for approval
        IF v_status != 'COMPLETED' THEN
            RAISE_APPLICATION_ERROR(-20008, 
                'Task must be in COMPLETED status to submit for approval. Current status: ' || v_status);
        END IF;
        
        -- Find the manager of the assigned user
        BEGIN
            SELECT manager_id INTO v_manager_id
            FROM   tts_users
            WHERE  user_id = v_assigned_to;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20009, 'Assigned user not found.');
        END;
        
        IF v_manager_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20010, 'No manager assigned to this user. Cannot submit for approval.');
        END IF;
        
        -- Update approval status
        UPDATE tts_tasks
        SET    approval_status = 'PENDING'
        WHERE  task_id = p_task_id;
        
        -- Log history
        log_history(
            p_task_id     => p_task_id,
            p_changed_by  => p_user_id,
            p_change_type => 'APPROVAL',
            p_old_value   => 'NOT_SUBMITTED',
            p_new_value   => 'PENDING'
        );
        
        -- Get submitter name for notification
        BEGIN
            SELECT full_name INTO v_user_name
            FROM tts_users WHERE user_id = p_user_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN v_user_name := 'Unknown';
        END;
        
        -- Notify the manager
        tts_pkg_notifications.create_notification(
            p_user_id => v_manager_id,
            p_task_id => p_task_id,
            p_type    => 'APPROVAL_REQUIRED',
            p_message => v_user_name || ' has submitted task "' || v_title || '" for your approval.'
        );
        
    END submit_for_approval;
    
    -- --------------------------------------------------------
    -- process_approval: Manager approves or rejects
    -- On rejection, task status reverts to IN_PROGRESS
    -- --------------------------------------------------------
    PROCEDURE process_approval(
        p_task_id    IN NUMBER,
        p_decision   IN VARCHAR2,
        p_manager_id IN NUMBER,
        p_notes      IN VARCHAR2 DEFAULT NULL
    ) IS
        v_approval_status VARCHAR2(20);
        v_assigned_to     NUMBER;
        v_title           VARCHAR2(250);
        v_manager_role    VARCHAR2(20);
        v_manager_name    VARCHAR2(150);
    BEGIN
        -- Validate decision
        IF p_decision NOT IN ('APPROVED', 'REJECTED') THEN
            RAISE_APPLICATION_ERROR(-20020, 'Invalid decision. Must be APPROVED or REJECTED.');
        END IF;
        
        -- Verify manager has appropriate role
        BEGIN
            SELECT role, full_name INTO v_manager_role, v_manager_name
            FROM tts_users WHERE user_id = p_manager_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20021, 'Approver user not found.');
        END;
        
        IF v_manager_role NOT IN ('ADMIN', 'MANAGER') THEN
            RAISE_APPLICATION_ERROR(-20022, 'Only managers and admins can approve/reject tasks.');
        END IF;
        
        -- Get task info
        BEGIN
            SELECT approval_status, assigned_to, title
            INTO   v_approval_status, v_assigned_to, v_title
            FROM   tts_tasks
            WHERE  task_id = p_task_id
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20023, 'Task not found: ' || p_task_id);
        END;
        
        -- Validate: only PENDING tasks can be processed
        IF v_approval_status != 'PENDING' THEN
            RAISE_APPLICATION_ERROR(-20024, 
                'Task is not pending approval. Current approval status: ' || v_approval_status);
        END IF;
        
        -- Verify manager is authorized (is admin OR is manager of assignee)
        IF v_manager_role != 'ADMIN' THEN
            IF NOT tts_pkg_security.is_manager_of(p_manager_id, v_assigned_to) THEN
                RAISE_APPLICATION_ERROR(-20025, 'You are not the manager of the assigned user.');
            END IF;
        END IF;
        
        -- Process the decision
        IF p_decision = 'APPROVED' THEN
            UPDATE tts_tasks
            SET    approval_status = 'APPROVED',
                   approved_by     = p_manager_id,
                   approval_notes  = p_notes
            WHERE  task_id = p_task_id;
        ELSE -- REJECTED
            UPDATE tts_tasks
            SET    approval_status = 'REJECTED',
                   approved_by     = p_manager_id,
                   approval_notes  = p_notes,
                   status          = 'IN_PROGRESS', -- Revert to in progress
                   completion_date = NULL
            WHERE  task_id = p_task_id;
        END IF;
        
        -- Log history
        log_history(
            p_task_id     => p_task_id,
            p_changed_by  => p_manager_id,
            p_change_type => 'APPROVAL',
            p_old_value   => 'PENDING',
            p_new_value   => p_decision || CASE WHEN p_notes IS NOT NULL THEN ' - ' || p_notes ELSE '' END
        );
        
        -- Notify the task assignee
        tts_pkg_notifications.create_notification(
            p_user_id => v_assigned_to,
            p_task_id => p_task_id,
            p_type    => 'APPROVAL_RESULT',
            p_message => 'Your task "' || v_title || '" has been ' || LOWER(p_decision) || 
                         ' by ' || v_manager_name || 
                         CASE WHEN p_notes IS NOT NULL THEN '. Notes: ' || p_notes ELSE '' END
        );
        
    END process_approval;
    
    -- --------------------------------------------------------
    -- log_daily_hours: MERGE into tts_daily_log
    -- If entry exists for same task/user/date, update it
    -- --------------------------------------------------------
    PROCEDURE log_daily_hours(
        p_task_id     IN NUMBER,
        p_user_id     IN NUMBER,
        p_log_date    IN DATE,
        p_hours_spent IN NUMBER,
        p_notes       IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        -- Validate hours
        IF p_hours_spent <= 0 OR p_hours_spent > 24 THEN
            RAISE_APPLICATION_ERROR(-20030, 'Hours must be between 0 and 24.');
        END IF;
        
        -- Validate task exists
        DECLARE
            v_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_count FROM tts_tasks WHERE task_id = p_task_id;
            IF v_count = 0 THEN
                RAISE_APPLICATION_ERROR(-20031, 'Task not found: ' || p_task_id);
            END IF;
        END;
        
        -- MERGE: Insert or update daily log entry
        MERGE INTO tts_daily_log dl
        USING (
            SELECT p_task_id AS task_id, 
                   p_user_id AS user_id, 
                   TRUNC(p_log_date) AS log_date 
            FROM DUAL
        ) src
        ON (dl.task_id = src.task_id 
            AND dl.user_id = src.user_id 
            AND dl.log_date = src.log_date)
        WHEN MATCHED THEN
            UPDATE SET 
                dl.hours_spent = p_hours_spent,
                dl.notes       = NVL(p_notes, dl.notes)
        WHEN NOT MATCHED THEN
            INSERT (task_id, user_id, log_date, hours_spent, notes)
            VALUES (p_task_id, p_user_id, TRUNC(p_log_date), p_hours_spent, p_notes);
        
        -- Note: trg_daily_log_calc trigger will auto-recalculate actual_hours
        
    END log_daily_hours;
    
    -- --------------------------------------------------------
    -- recalc_actual_hours: Sum daily_log into task actual_hours
    -- Called by trigger trg_daily_log_calc, but can also be
    -- called manually for corrections
    -- --------------------------------------------------------
    PROCEDURE recalc_actual_hours(
        p_task_id IN NUMBER
    ) IS
        v_total NUMBER;
    BEGIN
        SELECT NVL(SUM(hours_spent), 0)
        INTO   v_total
        FROM   tts_daily_log
        WHERE  task_id = p_task_id;
        
        UPDATE tts_tasks
        SET    actual_hours = v_total
        WHERE  task_id = p_task_id;
    END recalc_actual_hours;
    
    -- --------------------------------------------------------
    -- add_comment: Insert comment and notify relevant users
    -- --------------------------------------------------------
    PROCEDURE add_comment(
        p_task_id      IN NUMBER,
        p_user_id      IN NUMBER,
        p_comment_text IN CLOB
    ) IS
        v_assigned_to  NUMBER;
        v_created_by   NUMBER;
        v_title        VARCHAR2(250);
        v_commenter    VARCHAR2(150);
    BEGIN
        -- Validate
        IF p_comment_text IS NULL OR LENGTH(TRIM(p_comment_text)) = 0 THEN
            RAISE_APPLICATION_ERROR(-20040, 'Comment text cannot be empty.');
        END IF;
        
        -- Get task info
        BEGIN
            SELECT assigned_to, created_by, title
            INTO   v_assigned_to, v_created_by, v_title
            FROM   tts_tasks
            WHERE  task_id = p_task_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20041, 'Task not found: ' || p_task_id);
        END;
        
        -- Insert comment
        INSERT INTO tts_comments (task_id, user_id, comment_text)
        VALUES (p_task_id, p_user_id, p_comment_text);
        
        -- Get commenter name
        BEGIN
            SELECT full_name INTO v_commenter
            FROM tts_users WHERE user_id = p_user_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN v_commenter := 'Unknown';
        END;
        
        -- Notify assigned user (if commenter is different)
        IF p_user_id != v_assigned_to THEN
            tts_pkg_notifications.create_notification(
                p_user_id => v_assigned_to,
                p_task_id => p_task_id,
                p_type    => 'COMMENT_ADDED',
                p_message => v_commenter || ' commented on task "' || v_title || '"'
            );
        END IF;
        
        -- Notify creator (if different from both commenter and assignee)
        IF p_user_id != v_created_by AND v_created_by != v_assigned_to THEN
            tts_pkg_notifications.create_notification(
                p_user_id => v_created_by,
                p_task_id => p_task_id,
                p_type    => 'COMMENT_ADDED',
                p_message => v_commenter || ' commented on task "' || v_title || '"'
            );
        END IF;
        
    END add_comment;
    
    -- --------------------------------------------------------
    -- log_history: Simple audit trail insert
    -- --------------------------------------------------------
    PROCEDURE log_history(
        p_task_id     IN NUMBER,
        p_changed_by  IN NUMBER,
        p_change_type IN VARCHAR2,
        p_old_value   IN VARCHAR2,
        p_new_value   IN VARCHAR2
    ) IS
    BEGIN
        INSERT INTO tts_task_history (
            task_id, changed_by, change_type, old_value, new_value
        ) VALUES (
            p_task_id, p_changed_by, p_change_type, p_old_value, p_new_value
        );
    END log_history;

END tts_pkg_tasks;
/


-- ################################################################
-- ##  PACKAGE 4: tts_pkg_admin
-- ##  User Management, Department & System Administration
-- ################################################################

-- ============================================================
-- SPEC: tts_pkg_admin
-- ============================================================
PROMPT Creating package spec: tts_pkg_admin...

CREATE OR REPLACE PACKAGE tts_pkg_admin AS
    /*
    ---------------------------------------------------------------
    tts_pkg_admin
    Administrative operations:
      - User registration with secure password hashing
      - User activation/deactivation
      - Department management (CRUD)
      - System management (CRUD)
    ---------------------------------------------------------------
    */
    
    -- Register a new user with hashed password
    PROCEDURE create_user(
        p_username   IN VARCHAR2,
        p_password   IN VARCHAR2,
        p_email      IN VARCHAR2,
        p_full_name  IN VARCHAR2,
        p_role       IN VARCHAR2,
        p_dept_id    IN NUMBER   DEFAULT NULL,
        p_manager_id IN NUMBER   DEFAULT NULL
    );
    
    -- Activate or deactivate a user
    PROCEDURE toggle_user_status(
        p_user_id   IN NUMBER,
        p_is_active IN CHAR
    );
    
    -- Create or update a department
    PROCEDURE save_department(
        p_dept_id      IN NUMBER   DEFAULT NULL,
        p_dept_name    IN VARCHAR2,
        p_dept_head_id IN NUMBER   DEFAULT NULL
    );
    
    -- Create or update a system
    PROCEDURE save_system(
        p_system_id   IN NUMBER   DEFAULT NULL,
        p_system_name IN VARCHAR2,
        p_description IN VARCHAR2 DEFAULT NULL
    );

END tts_pkg_admin;
/

-- ============================================================
-- BODY: tts_pkg_admin
-- ============================================================
PROMPT Creating package body: tts_pkg_admin...

CREATE OR REPLACE PACKAGE BODY tts_pkg_admin AS

    -- --------------------------------------------------------
    -- create_user: Register with hashed password + salt
    -- --------------------------------------------------------
    PROCEDURE create_user(
        p_username   IN VARCHAR2,
        p_password   IN VARCHAR2,
        p_email      IN VARCHAR2,
        p_full_name  IN VARCHAR2,
        p_role       IN VARCHAR2,
        p_dept_id    IN NUMBER   DEFAULT NULL,
        p_manager_id IN NUMBER   DEFAULT NULL
    ) IS
        v_salt VARCHAR2(128);
        v_hash VARCHAR2(256);
        v_count NUMBER;
    BEGIN
        -- Validate role
        IF p_role NOT IN ('ADMIN', 'MANAGER', 'EMPLOYEE') THEN
            RAISE_APPLICATION_ERROR(-20050, 'Invalid role. Must be ADMIN, MANAGER, or EMPLOYEE.');
        END IF;
        
        -- Validate password length
        IF LENGTH(p_password) < 8 THEN
            RAISE_APPLICATION_ERROR(-20051, 'Password must be at least 8 characters long.');
        END IF;
        
        -- Check username uniqueness
        SELECT COUNT(*) INTO v_count
        FROM tts_users WHERE UPPER(username) = UPPER(p_username);
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20052, 'Username already exists: ' || p_username);
        END IF;
        
        -- Check email uniqueness
        SELECT COUNT(*) INTO v_count
        FROM tts_users WHERE UPPER(email) = UPPER(p_email);
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20053, 'Email already exists: ' || p_email);
        END IF;
        
        -- Generate salt and hash password
        v_salt := tts_pkg_security.generate_salt;
        v_hash := tts_pkg_security.hash_password(p_password, v_salt);
        
        -- Insert user
        INSERT INTO tts_users (
            username, password_hash, password_salt,
            email, full_name, role,
            dept_id, manager_id, is_active
        ) VALUES (
            p_username, v_hash, v_salt,
            p_email, p_full_name, p_role,
            p_dept_id, p_manager_id, 'Y'
        );
        
        COMMIT;
    END create_user;
    
    -- --------------------------------------------------------
    -- toggle_user_status: Activate or deactivate
    -- --------------------------------------------------------
    PROCEDURE toggle_user_status(
        p_user_id   IN NUMBER,
        p_is_active IN CHAR
    ) IS
    BEGIN
        IF p_is_active NOT IN ('Y', 'N') THEN
            RAISE_APPLICATION_ERROR(-20054, 'is_active must be Y or N.');
        END IF;
        
        UPDATE tts_users
        SET    is_active = p_is_active
        WHERE  user_id = p_user_id;
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20055, 'User not found: ' || p_user_id);
        END IF;
        
        COMMIT;
    END toggle_user_status;
    
    -- --------------------------------------------------------
    -- save_department: Insert if new, Update if existing
    -- --------------------------------------------------------
    PROCEDURE save_department(
        p_dept_id      IN NUMBER   DEFAULT NULL,
        p_dept_name    IN VARCHAR2,
        p_dept_head_id IN NUMBER   DEFAULT NULL
    ) IS
    BEGIN
        IF p_dept_id IS NULL THEN
            -- Create new department
            INSERT INTO tts_departments (dept_name, dept_head_id, is_active)
            VALUES (p_dept_name, p_dept_head_id, 'Y');
        ELSE
            -- Update existing department
            UPDATE tts_departments
            SET    dept_name    = p_dept_name,
                   dept_head_id = p_dept_head_id
            WHERE  dept_id = p_dept_id;
            
            IF SQL%ROWCOUNT = 0 THEN
                RAISE_APPLICATION_ERROR(-20056, 'Department not found: ' || p_dept_id);
            END IF;
        END IF;
        
        COMMIT;
    END save_department;
    
    -- --------------------------------------------------------
    -- save_system: Insert if new, Update if existing
    -- --------------------------------------------------------
    PROCEDURE save_system(
        p_system_id   IN NUMBER   DEFAULT NULL,
        p_system_name IN VARCHAR2,
        p_description IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        IF p_system_id IS NULL THEN
            -- Create new system
            INSERT INTO tts_systems (system_name, description, is_active)
            VALUES (p_system_name, p_description, 'Y');
        ELSE
            -- Update existing system
            UPDATE tts_systems
            SET    system_name = p_system_name,
                   description = p_description
            WHERE  system_id = p_system_id;
            
            IF SQL%ROWCOUNT = 0 THEN
                RAISE_APPLICATION_ERROR(-20057, 'System not found: ' || p_system_id);
            END IF;
        END IF;
        
        COMMIT;
    END save_system;

END tts_pkg_admin;
/


-- ============================================================
-- DONE
-- ============================================================
PROMPT ============================================================
PROMPT  TTS Packages Installation — COMPLETED SUCCESSFULLY
PROMPT  Packages created: 4 (Spec + Body each)
PROMPT    1. tts_pkg_security       (Auth, Authorization, Passwords)
PROMPT    2. tts_pkg_notifications  (In-App & Email Notifications)
PROMPT    3. tts_pkg_tasks          (Task Lifecycle & Workflow)
PROMPT    4. tts_pkg_admin          (User & Admin Management)
PROMPT ============================================================

