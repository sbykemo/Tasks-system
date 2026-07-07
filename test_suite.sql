/*
================================================================================
  Daily Tasks Tracking System (TTS)
  File: test_suite.sql
  Description: Automated test suite to validate all database objects and logic
  APEX Version: 24.2.17
  Author: TTS Development Team
  Created: 2026-07-07
================================================================================
  EXECUTION ORDER: Run AFTER all other scripts (schema, seed, views, triggers, packages)
  NOTE: This script creates test data and validates functionality.
        Run in a TEST environment, not production.
================================================================================
*/

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET DEFINE OFF;

PROMPT ============================================================
PROMPT  TTS Test Suite — Starting...
PROMPT ============================================================

DECLARE
    -- Test counters
    v_tests_passed  NUMBER := 0;
    v_tests_failed  NUMBER := 0;
    v_total_tests   NUMBER := 0;
    
    -- Test data variables
    v_dept_id       NUMBER;
    v_manager_id    NUMBER;
    v_emp1_id       NUMBER;
    v_emp2_id       NUMBER;
    v_system_id     NUMBER;
    v_task_id       NUMBER;
    v_task_id2      NUMBER;
    v_task_number   VARCHAR2(20);
    v_count         NUMBER;
    v_status        VARCHAR2(20);
    v_hours         NUMBER;
    v_approval      VARCHAR2(20);
    v_result        BOOLEAN;
    v_hash1         VARCHAR2(256);
    v_hash2         VARCHAR2(256);
    v_salt          VARCHAR2(128);
    
    -- Helper procedure to log test results
    PROCEDURE assert_true(p_test_name IN VARCHAR2, p_condition IN BOOLEAN) IS
    BEGIN
        v_total_tests := v_total_tests + 1;
        IF p_condition THEN
            v_tests_passed := v_tests_passed + 1;
            DBMS_OUTPUT.PUT_LINE('  ✅ PASS: ' || p_test_name);
        ELSE
            v_tests_failed := v_tests_failed + 1;
            DBMS_OUTPUT.PUT_LINE('  ❌ FAIL: ' || p_test_name);
        END IF;
    END;
    
    PROCEDURE assert_equals(p_test_name IN VARCHAR2, p_expected IN VARCHAR2, p_actual IN VARCHAR2) IS
    BEGIN
        v_total_tests := v_total_tests + 1;
        IF NVL(p_expected, '~NULL~') = NVL(p_actual, '~NULL~') THEN
            v_tests_passed := v_tests_passed + 1;
            DBMS_OUTPUT.PUT_LINE('  ✅ PASS: ' || p_test_name);
        ELSE
            v_tests_failed := v_tests_failed + 1;
            DBMS_OUTPUT.PUT_LINE('  ❌ FAIL: ' || p_test_name || 
                                 ' (Expected: ' || NVL(p_expected,'NULL') || 
                                 ', Got: ' || NVL(p_actual,'NULL') || ')');
        END IF;
    END;
    
    PROCEDURE assert_equals_num(p_test_name IN VARCHAR2, p_expected IN NUMBER, p_actual IN NUMBER) IS
    BEGIN
        assert_equals(p_test_name, TO_CHAR(p_expected), TO_CHAR(p_actual));
    END;
    
BEGIN

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' TEST GROUP 1: Password Hashing & Security');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    
    -- Test 1.1: Salt generation produces unique values
    v_salt  := tts_pkg_security.generate_salt;
    v_hash1 := tts_pkg_security.generate_salt;
    assert_true('Salt generation returns non-null', v_salt IS NOT NULL);
    assert_true('Salt has correct length (64 hex chars)', LENGTH(v_salt) = 64);
    assert_true('Two salts are unique', v_salt != v_hash1);
    
    -- Test 1.2: Password hashing is deterministic
    v_salt  := tts_pkg_security.generate_salt;
    v_hash1 := tts_pkg_security.hash_password('TestPass123', v_salt);
    v_hash2 := tts_pkg_security.hash_password('TestPass123', v_salt);
    assert_true('Same password + salt = same hash', v_hash1 = v_hash2);
    
    -- Test 1.3: Different passwords produce different hashes
    v_hash2 := tts_pkg_security.hash_password('DifferentPass', v_salt);
    assert_true('Different passwords = different hashes', v_hash1 != v_hash2);
    
    -- Test 1.4: Authentication with default admin user
    v_result := tts_pkg_security.authenticate_user('admin', 'Admin@123');
    assert_true('Admin authentication with correct password', v_result = TRUE);
    
    v_result := tts_pkg_security.authenticate_user('admin', 'WrongPassword');
    assert_true('Admin authentication with wrong password fails', v_result = FALSE);
    
    v_result := tts_pkg_security.authenticate_user('nonexistent', 'Admin@123');
    assert_true('Non-existent user authentication fails', v_result = FALSE);
    
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' TEST GROUP 2: User & Department Management');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    
    -- Test 2.1: Create a test department
    tts_pkg_admin.save_department(
        p_dept_id   => NULL,
        p_dept_name => 'Test Department'
    );
    SELECT dept_id INTO v_dept_id 
    FROM tts_departments WHERE dept_name = 'Test Department';
    assert_true('Department created successfully', v_dept_id IS NOT NULL);
    
    -- Test 2.2: Create a manager user
    tts_pkg_admin.create_user(
        p_username  => 'test_manager',
        p_password  => 'Manager@123',
        p_email     => 'manager@test.local',
        p_full_name => 'Test Manager',
        p_role      => 'MANAGER',
        p_dept_id   => v_dept_id
    );
    SELECT user_id INTO v_manager_id 
    FROM tts_users WHERE username = 'test_manager';
    assert_true('Manager user created', v_manager_id IS NOT NULL);
    
    -- Test 2.3: Create employee users under the manager
    tts_pkg_admin.create_user(
        p_username   => 'test_emp1',
        p_password   => 'Employee@123',
        p_email      => 'emp1@test.local',
        p_full_name  => 'Test Employee 1',
        p_role       => 'EMPLOYEE',
        p_dept_id    => v_dept_id,
        p_manager_id => v_manager_id
    );
    SELECT user_id INTO v_emp1_id 
    FROM tts_users WHERE username = 'test_emp1';
    assert_true('Employee 1 created', v_emp1_id IS NOT NULL);
    
    tts_pkg_admin.create_user(
        p_username   => 'test_emp2',
        p_password   => 'Employee@123',
        p_email      => 'emp2@test.local',
        p_full_name  => 'Test Employee 2',
        p_role       => 'EMPLOYEE',
        p_dept_id    => v_dept_id,
        p_manager_id => v_manager_id
    );
    SELECT user_id INTO v_emp2_id 
    FROM tts_users WHERE username = 'test_emp2';
    assert_true('Employee 2 created', v_emp2_id IS NOT NULL);
    
    -- Test 2.4: Authentication with new users
    v_result := tts_pkg_security.authenticate_user('test_manager', 'Manager@123');
    assert_true('Manager authentication works', v_result = TRUE);
    
    v_result := tts_pkg_security.authenticate_user('test_emp1', 'Employee@123');
    assert_true('Employee authentication works', v_result = TRUE);
    
    -- Test 2.5: Manager relationship
    v_result := tts_pkg_security.is_manager_of(v_manager_id, v_emp1_id);
    assert_true('Manager-Employee relationship verified', v_result = TRUE);
    
    v_result := tts_pkg_security.is_manager_of(v_emp1_id, v_manager_id);
    assert_true('Reverse relationship returns FALSE', v_result = FALSE);
    
    -- Test 2.6: Duplicate username prevention
    BEGIN
        tts_pkg_admin.create_user(
            p_username => 'test_emp1',
            p_password => 'Duplicate@123',
            p_email    => 'dup@test.local',
            p_full_name => 'Duplicate User',
            p_role     => 'EMPLOYEE'
        );
        assert_true('Duplicate username blocked', FALSE); -- Should not reach here
    EXCEPTION
        WHEN OTHERS THEN
            assert_true('Duplicate username blocked', SQLCODE = -20052);
    END;
    
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' TEST GROUP 3: Task Creation & Lifecycle');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    
    -- Get a system for tasks
    SELECT system_id INTO v_system_id 
    FROM tts_systems WHERE system_name = 'ERP System';
    
    -- Test 3.1: Create a task
    v_task_id := tts_pkg_tasks.create_task(
        p_title           => 'Test Task #1 - User Module',
        p_description     => 'Develop the user management module for ERP',
        p_system_id       => v_system_id,
        p_assigned_to     => v_emp1_id,
        p_created_by      => v_manager_id,
        p_priority        => 'HIGH',
        p_start_date      => TRUNC(SYSDATE),
        p_due_date        => TRUNC(SYSDATE) + 7,
        p_estimated_hours => 40
    );
    assert_true('Task created successfully', v_task_id IS NOT NULL);
    
    -- Test 3.2: Auto-generated task number
    SELECT task_number INTO v_task_number 
    FROM tts_tasks WHERE task_id = v_task_id;
    assert_true('Task number auto-generated (TSK-XXXXXX)', v_task_number LIKE 'TSK-%');
    
    -- Test 3.3: Initial status is CREATED
    SELECT status, approval_status INTO v_status, v_approval
    FROM tts_tasks WHERE task_id = v_task_id;
    assert_equals('Initial status is CREATED', 'CREATED', v_status);
    assert_equals('Initial approval is NOT_SUBMITTED', 'NOT_SUBMITTED', v_approval);
    
    -- Test 3.4: History logged on creation
    SELECT COUNT(*) INTO v_count
    FROM tts_task_history 
    WHERE task_id = v_task_id AND change_type = 'CREATED';
    assert_equals_num('Creation logged in history', 1, v_count);
    
    -- Test 3.5: Notification sent to assignee
    SELECT COUNT(*) INTO v_count
    FROM tts_notifications 
    WHERE user_id = v_emp1_id 
    AND task_id = v_task_id 
    AND notification_type = 'TASK_ASSIGNED';
    assert_equals_num('Assignment notification created', 1, v_count);
    
    -- Test 3.6: Invalid date validation
    BEGIN
        v_task_id2 := tts_pkg_tasks.create_task(
            p_title           => 'Invalid Date Task',
            p_system_id       => v_system_id,
            p_assigned_to     => v_emp1_id,
            p_created_by      => v_manager_id,
            p_start_date      => TRUNC(SYSDATE) + 7,
            p_due_date        => TRUNC(SYSDATE),  -- Before start date!
            p_estimated_hours => 10
        );
        assert_true('Invalid date validation', FALSE);
    EXCEPTION
        WHEN OTHERS THEN
            assert_true('Invalid date validation (due < start blocked)', SQLCODE = -20001);
    END;
    
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' TEST GROUP 4: Status Transitions');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    
    -- Test 4.1: CREATED -> IN_PROGRESS (valid)
    tts_pkg_tasks.update_task_status(v_task_id, 'IN_PROGRESS', v_emp1_id);
    SELECT status INTO v_status FROM tts_tasks WHERE task_id = v_task_id;
    assert_equals('CREATED -> IN_PROGRESS', 'IN_PROGRESS', v_status);
    
    -- Test 4.2: IN_PROGRESS -> ON_HOLD (valid)
    tts_pkg_tasks.update_task_status(v_task_id, 'ON_HOLD', v_emp1_id);
    SELECT status INTO v_status FROM tts_tasks WHERE task_id = v_task_id;
    assert_equals('IN_PROGRESS -> ON_HOLD', 'ON_HOLD', v_status);
    
    -- Test 4.3: ON_HOLD -> IN_PROGRESS (valid)
    tts_pkg_tasks.update_task_status(v_task_id, 'IN_PROGRESS', v_emp1_id);
    SELECT status INTO v_status FROM tts_tasks WHERE task_id = v_task_id;
    assert_equals('ON_HOLD -> IN_PROGRESS', 'IN_PROGRESS', v_status);
    
    -- Test 4.4: IN_PROGRESS -> COMPLETED (valid)
    tts_pkg_tasks.update_task_status(v_task_id, 'COMPLETED', v_emp1_id);
    SELECT status INTO v_status FROM tts_tasks WHERE task_id = v_task_id;
    assert_equals('IN_PROGRESS -> COMPLETED', 'COMPLETED', v_status);
    
    -- Test 4.5: Completion date set
    SELECT completion_date INTO v_hours -- reusing variable  
    FROM tts_tasks WHERE task_id = v_task_id;
    assert_true('Completion date set on COMPLETED', v_hours IS NOT NULL);
    
    -- Test 4.6: Invalid transition (COMPLETED -> ON_HOLD)
    BEGIN
        tts_pkg_tasks.update_task_status(v_task_id, 'ON_HOLD', v_emp1_id);
        assert_true('Invalid transition COMPLETED->ON_HOLD blocked', FALSE);
    EXCEPTION
        WHEN OTHERS THEN
            assert_true('Invalid transition COMPLETED->ON_HOLD blocked', SQLCODE = -20004);
    END;
    
    -- Test 4.7: Status change history logged
    SELECT COUNT(*) INTO v_count
    FROM tts_task_history 
    WHERE task_id = v_task_id AND change_type = 'STATUS';
    assert_true('Status changes logged in history (>= 4)', v_count >= 4);
    
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' TEST GROUP 5: Daily Time Logging');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    
    -- Create a second task for time logging tests
    v_task_id2 := tts_pkg_tasks.create_task(
        p_title           => 'Test Task #2 - Report Module',
        p_system_id       => v_system_id,
        p_assigned_to     => v_emp1_id,
        p_created_by      => v_manager_id,
        p_priority        => 'MEDIUM',
        p_start_date      => TRUNC(SYSDATE),
        p_due_date        => TRUNC(SYSDATE) + 14,
        p_estimated_hours => 20
    );
    
    -- Test 5.1: Log hours for day 1
    tts_pkg_tasks.log_daily_hours(
        p_task_id     => v_task_id2,
        p_user_id     => v_emp1_id,
        p_log_date    => TRUNC(SYSDATE),
        p_hours_spent => 6,
        p_notes       => 'Started report module development'
    );
    SELECT actual_hours INTO v_hours FROM tts_tasks WHERE task_id = v_task_id2;
    assert_equals_num('Day 1: 6 hours logged, actual_hours = 6', 6, v_hours);
    
    -- Test 5.2: Log hours for day 2
    tts_pkg_tasks.log_daily_hours(
        p_task_id     => v_task_id2,
        p_user_id     => v_emp1_id,
        p_log_date    => TRUNC(SYSDATE) + 1,
        p_hours_spent => 4.5,
        p_notes       => 'Continued development'
    );
    SELECT actual_hours INTO v_hours FROM tts_tasks WHERE task_id = v_task_id2;
    assert_equals_num('Day 2: 4.5 hours added, actual_hours = 10.5', 10.5, v_hours);
    
    -- Test 5.3: Update hours for day 1 (MERGE update)
    tts_pkg_tasks.log_daily_hours(
        p_task_id     => v_task_id2,
        p_user_id     => v_emp1_id,
        p_log_date    => TRUNC(SYSDATE),
        p_hours_spent => 8  -- Updated from 6 to 8
    );
    SELECT actual_hours INTO v_hours FROM tts_tasks WHERE task_id = v_task_id2;
    assert_equals_num('Day 1 updated to 8h, actual_hours = 12.5', 12.5, v_hours);
    
    -- Test 5.4: Invalid hours
    BEGIN
        tts_pkg_tasks.log_daily_hours(
            p_task_id     => v_task_id2,
            p_user_id     => v_emp1_id,
            p_log_date    => TRUNC(SYSDATE) + 2,
            p_hours_spent => 25  -- Invalid: > 24
        );
        assert_true('Invalid hours (>24) blocked', FALSE);
    EXCEPTION
        WHEN OTHERS THEN
            assert_true('Invalid hours (>24) blocked', SQLCODE = -20030);
    END;
    
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' TEST GROUP 6: Approval Workflow');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    
    -- Test 6.1: Submit for approval (task must be COMPLETED first)
    -- Use the first task which is already COMPLETED
    tts_pkg_tasks.submit_for_approval(v_task_id, v_emp1_id);
    SELECT approval_status INTO v_approval FROM tts_tasks WHERE task_id = v_task_id;
    assert_equals('Task submitted for approval', 'PENDING', v_approval);
    
    -- Test 6.2: Manager notification received
    SELECT COUNT(*) INTO v_count
    FROM tts_notifications 
    WHERE user_id = v_manager_id 
    AND task_id = v_task_id 
    AND notification_type = 'APPROVAL_REQUIRED';
    assert_true('Manager received approval notification', v_count > 0);
    
    -- Test 6.3: Reject the task
    tts_pkg_tasks.process_approval(
        p_task_id    => v_task_id,
        p_decision   => 'REJECTED',
        p_manager_id => v_manager_id,
        p_notes      => 'Please add unit tests before completing'
    );
    SELECT status, approval_status, approval_notes 
    INTO v_status, v_approval, v_task_number -- reusing variable
    FROM tts_tasks WHERE task_id = v_task_id;
    assert_equals('Rejected: status reverted to IN_PROGRESS', 'IN_PROGRESS', v_status);
    assert_equals('Rejected: approval_status = REJECTED', 'REJECTED', v_approval);
    assert_true('Rejection notes saved', v_task_number IS NOT NULL);
    
    -- Test 6.4: Employee notification about rejection
    SELECT COUNT(*) INTO v_count
    FROM tts_notifications 
    WHERE user_id = v_emp1_id 
    AND task_id = v_task_id 
    AND notification_type = 'APPROVAL_RESULT';
    assert_true('Employee received rejection notification', v_count > 0);
    
    -- Test 6.5: Complete again and approve
    tts_pkg_tasks.update_task_status(v_task_id, 'COMPLETED', v_emp1_id);
    tts_pkg_tasks.submit_for_approval(v_task_id, v_emp1_id);
    tts_pkg_tasks.process_approval(
        p_task_id    => v_task_id,
        p_decision   => 'APPROVED',
        p_manager_id => v_manager_id,
        p_notes      => 'Good work!'
    );
    SELECT approval_status INTO v_approval FROM tts_tasks WHERE task_id = v_task_id;
    assert_equals('Task approved successfully', 'APPROVED', v_approval);
    
    -- Test 6.6: Employee cannot approve (role check)
    -- Create another completed task for this test
    DECLARE
        v_temp_task NUMBER;
    BEGIN
        v_temp_task := tts_pkg_tasks.create_task(
            p_title           => 'Approval Role Test',
            p_system_id       => v_system_id,
            p_assigned_to     => v_emp2_id,
            p_created_by      => v_manager_id,
            p_start_date      => TRUNC(SYSDATE),
            p_due_date        => TRUNC(SYSDATE) + 3,
            p_estimated_hours => 5
        );
        tts_pkg_tasks.update_task_status(v_temp_task, 'IN_PROGRESS', v_emp2_id);
        tts_pkg_tasks.update_task_status(v_temp_task, 'COMPLETED', v_emp2_id);
        tts_pkg_tasks.submit_for_approval(v_temp_task, v_emp2_id);
        
        -- Try approval as employee (should fail)
        BEGIN
            tts_pkg_tasks.process_approval(v_temp_task, 'APPROVED', v_emp1_id);
            assert_true('Employee cannot approve tasks', FALSE);
        EXCEPTION
            WHEN OTHERS THEN
                assert_true('Employee cannot approve tasks (role blocked)', SQLCODE = -20022);
        END;
    END;
    
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' TEST GROUP 7: Comments');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    
    -- Test 7.1: Add comment
    tts_pkg_tasks.add_comment(v_task_id, v_emp1_id, 'This task is progressing well.');
    SELECT COUNT(*) INTO v_count FROM tts_comments WHERE task_id = v_task_id;
    assert_equals_num('Comment added', 1, v_count);
    
    -- Test 7.2: Comment notification to other users
    tts_pkg_tasks.add_comment(v_task_id, v_manager_id, 'Great progress! Keep it up.');
    SELECT COUNT(*) INTO v_count
    FROM tts_notifications 
    WHERE user_id = v_emp1_id AND notification_type = 'COMMENT_ADDED';
    assert_true('Comment notification sent to assignee', v_count > 0);
    
    -- Test 7.3: Empty comment blocked
    BEGIN
        tts_pkg_tasks.add_comment(v_task_id, v_emp1_id, '');
        assert_true('Empty comment blocked', FALSE);
    EXCEPTION
        WHEN OTHERS THEN
            assert_true('Empty comment blocked', SQLCODE = -20040);
    END;
    
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' TEST GROUP 8: Task Reassignment');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    
    -- Test 8.1: Reassign task from emp1 to emp2
    tts_pkg_tasks.reassign_task(v_task_id2, v_emp2_id, v_manager_id);
    SELECT assigned_to INTO v_count -- reusing
    FROM tts_tasks WHERE task_id = v_task_id2;
    assert_equals_num('Task reassigned to emp2', v_emp2_id, v_count);
    
    -- Test 8.2: Reassignment logged in history
    SELECT COUNT(*) INTO v_count
    FROM tts_task_history 
    WHERE task_id = v_task_id2 AND change_type = 'ASSIGNMENT';
    assert_true('Reassignment logged in history', v_count > 0);
    
    -- Test 8.3: Notifications sent to both old and new assignee
    SELECT COUNT(*) INTO v_count
    FROM tts_notifications 
    WHERE task_id = v_task_id2 
    AND notification_type = 'TASK_ASSIGNED'
    AND user_id = v_emp2_id;
    assert_true('New assignee notified of reassignment', v_count > 0);
    
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' TEST GROUP 9: Authorization Checks');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    
    -- Test 9.1: Admin can edit any task
    DECLARE
        v_admin_id NUMBER;
    BEGIN
        SELECT user_id INTO v_admin_id FROM tts_users WHERE username = 'admin';
        v_result := tts_pkg_security.can_user_edit_task(v_admin_id, v_task_id);
        assert_true('Admin can edit any task', v_result = TRUE);
    END;
    
    -- Test 9.2: Assigned user can edit their task
    v_result := tts_pkg_security.can_user_edit_task(v_emp1_id, v_task_id);
    assert_true('Assigned user can edit their task', v_result = TRUE);
    
    -- Test 9.3: Manager can edit their team member's task
    v_result := tts_pkg_security.can_user_edit_task(v_manager_id, v_task_id);
    assert_true('Manager can edit team task', v_result = TRUE);
    
    -- Test 9.4: Unrelated employee cannot edit someone else's task
    v_result := tts_pkg_security.can_user_edit_task(v_emp2_id, v_task_id);
    -- emp2 is not assigned_to nor created_by task_id, and is not manager of emp1
    -- BUT emp2 might be assigned to task_id via reassignment... let's check a cleaner case
    -- Actually emp2's manager is v_manager_id, so emp2 is not manager of emp1
    assert_true('Unrelated employee cannot edit task', v_result = FALSE);
    
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' TEST GROUP 10: Notifications');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    
    -- Test 10.1: Unread count
    v_count := tts_pkg_notifications.get_unread_count(v_emp1_id);
    assert_true('Unread count > 0 for emp1', v_count > 0);
    
    -- Test 10.2: Mark all as read
    tts_pkg_notifications.mark_all_read(v_emp1_id);
    v_count := tts_pkg_notifications.get_unread_count(v_emp1_id);
    assert_equals_num('After mark_all_read, unread = 0', 0, v_count);
    
    -- Test 10.3: Mark single as read
    -- Create a new notification first
    tts_pkg_notifications.create_notification(
        p_user_id => v_emp1_id,
        p_task_id => v_task_id,
        p_type    => 'STATUS_CHANGED',
        p_message => 'Test notification'
    );
    v_count := tts_pkg_notifications.get_unread_count(v_emp1_id);
    assert_equals_num('New notification created, unread = 1', 1, v_count);
    
    -- Get the notification ID and mark it as read
    DECLARE
        v_notif_id NUMBER;
    BEGIN
        SELECT MAX(notification_id) INTO v_notif_id
        FROM tts_notifications WHERE user_id = v_emp1_id AND is_read = 'N';
        
        tts_pkg_notifications.mark_as_read(v_notif_id);
        v_count := tts_pkg_notifications.get_unread_count(v_emp1_id);
        assert_equals_num('After mark_as_read, unread = 0', 0, v_count);
    END;
    
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' TEST GROUP 11: Views Validation');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    
    -- Test 11.1: v_tasks_full returns data
    SELECT COUNT(*) INTO v_count FROM v_tasks_full;
    assert_true('v_tasks_full returns data', v_count > 0);
    
    -- Test 11.2: v_user_workload returns data
    SELECT COUNT(*) INTO v_count FROM v_user_workload;
    assert_true('v_user_workload returns data', v_count > 0);
    
    -- Test 11.3: v_dashboard_stats returns single row
    SELECT COUNT(*) INTO v_count FROM v_dashboard_stats;
    assert_equals_num('v_dashboard_stats returns 1 row', 1, v_count);
    
    -- Test 11.4: v_tasks_full computed columns
    DECLARE
        v_overdue_flag VARCHAR2(1);
        v_tags         VARCHAR2(4000);
    BEGIN
        SELECT is_overdue INTO v_overdue_flag
        FROM v_tasks_full WHERE task_id = v_task_id;
        assert_true('v_tasks_full.is_overdue is computed', v_overdue_flag IN ('Y','N'));
    END;
    
    -- Test 11.5: v_dashboard_stats has correct totals
    DECLARE
        v_total NUMBER;
        v_db_total NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_total FROM tts_tasks;
        SELECT total_tasks INTO v_db_total FROM v_dashboard_stats;
        assert_equals_num('v_dashboard_stats.total_tasks matches', v_total, v_db_total);
    END;
    
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' TEST GROUP 12: Password Change');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    
    -- Test 12.1: Change password successfully
    BEGIN
        tts_pkg_security.change_password(v_emp1_id, 'Employee@123', 'NewPass@456');
        v_result := tts_pkg_security.authenticate_user('test_emp1', 'NewPass@456');
        assert_true('Password changed and new password works', v_result = TRUE);
        
        v_result := tts_pkg_security.authenticate_user('test_emp1', 'Employee@123');
        assert_true('Old password no longer works', v_result = FALSE);
    EXCEPTION
        WHEN OTHERS THEN
            assert_true('Password change: ' || SQLERRM, FALSE);
    END;
    
    -- Test 12.2: Wrong old password
    BEGIN
        tts_pkg_security.change_password(v_emp1_id, 'WrongOldPass', 'AnotherNew@789');
        assert_true('Wrong old password blocked', FALSE);
    EXCEPTION
        WHEN OTHERS THEN
            assert_true('Wrong old password blocked', SQLCODE = -20013);
    END;
    
    -- Test 12.3: Short new password
    BEGIN
        tts_pkg_security.change_password(v_emp1_id, 'NewPass@456', 'short');
        assert_true('Short password blocked', FALSE);
    EXCEPTION
        WHEN OTHERS THEN
            assert_true('Short password blocked (min 8 chars)', SQLCODE = -20011);
    END;
    
    
    -- ============================================================
    -- FINAL RESULTS
    -- ============================================================
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('############################################################');
    DBMS_OUTPUT.PUT_LINE('#                   TEST RESULTS SUMMARY                   #');
    DBMS_OUTPUT.PUT_LINE('############################################################');
    DBMS_OUTPUT.PUT_LINE('#  Total Tests:  ' || LPAD(v_total_tests, 3)  || '                                      #');
    DBMS_OUTPUT.PUT_LINE('#  Passed:       ' || LPAD(v_tests_passed, 3) || '  ✅                                   #');
    DBMS_OUTPUT.PUT_LINE('#  Failed:       ' || LPAD(v_tests_failed, 3) || '  ' || 
                         CASE WHEN v_tests_failed = 0 THEN '🎉' ELSE '❌' END || 
                         '                                   #');
    DBMS_OUTPUT.PUT_LINE('#  Pass Rate:    ' || 
                         LPAD(ROUND(v_tests_passed / GREATEST(v_total_tests, 1) * 100, 1), 5) || 
                         '%                                  #');
    DBMS_OUTPUT.PUT_LINE('############################################################');
    
    IF v_tests_failed = 0 THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('  🎉 ALL TESTS PASSED! System is ready for APEX integration.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('  ⚠️  Some tests failed. Please review and fix before proceeding.');
    END IF;
    
END;
/

-- ============================================================
-- CLEANUP: Remove test data (optional — uncomment to run)
-- ============================================================
/*
PROMPT Cleaning up test data...
DELETE FROM tts_notifications WHERE user_id IN (SELECT user_id FROM tts_users WHERE username LIKE 'test_%');
DELETE FROM tts_task_history WHERE task_id IN (SELECT task_id FROM tts_tasks WHERE created_by IN (SELECT user_id FROM tts_users WHERE username LIKE 'test_%'));
DELETE FROM tts_comments WHERE task_id IN (SELECT task_id FROM tts_tasks WHERE created_by IN (SELECT user_id FROM tts_users WHERE username LIKE 'test_%'));
DELETE FROM tts_daily_log WHERE task_id IN (SELECT task_id FROM tts_tasks WHERE created_by IN (SELECT user_id FROM tts_users WHERE username LIKE 'test_%'));
DELETE FROM tts_tasks WHERE created_by IN (SELECT user_id FROM tts_users WHERE username LIKE 'test_%');
DELETE FROM tts_users WHERE username LIKE 'test_%';
DELETE FROM tts_departments WHERE dept_name = 'Test Department';
COMMIT;
PROMPT Test data cleaned up.
*/

PROMPT ============================================================
PROMPT  TTS Test Suite — COMPLETED
PROMPT ============================================================

