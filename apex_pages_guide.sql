/*
================================================================================
  Daily Tasks Tracking System (TTS)
  File: apex_pages_guide.sql
  Description: Complete Page-by-Page Blueprint for Oracle APEX 24.2
               This file contains ALL SQL queries, PL/SQL processes,
               Dynamic Actions, and Validations for every page.
  APEX Version: 24.2.17
  Author: TTS Development Team
  Created: 2026-07-08
================================================================================
  HOW TO USE:
    This is a REFERENCE DOCUMENT. Follow it step by step in APEX Builder.
    Copy/paste the SQL queries and PL/SQL code blocks as you build each page.
================================================================================
*/


-- ################################################################
-- ##  PAGE 0: GLOBAL PAGE
-- ##  Contains: Notification Bell, User Display Name
-- ################################################################

/*
=== REGION 1: Notification Bell (Navigation Bar Entry) ===
Create in: Shared Components > Navigation Bar List > Add Entry

  List Entry Label: &F_FULL_NAME.
  Image/Class: fa-bell
  Badge Value:
*/

-- Badge SQL (use as Navigation Bar Badge):
SELECT tts_pkg_notifications.get_unread_count(TO_NUMBER(:F_USER_ID)) 
FROM DUAL;

/*
  Target: Page 0 (or inline dialog region below)
  Authorization: IS_AUTHENTICATED
  
  Alternatively, add a Region to Page 0:
*/

/*
=== REGION 2: Notification Popup (Optional — Classic Report in Inline Dialog) ===
  Region Type: Classic Report
  Template: Inline Dialog
  Region Name: Notifications
*/

-- Source SQL:
SELECT 
    n.notification_id,
    n.notification_type,
    n.message,
    n.is_read,
    n.task_id,
    t.task_number,
    APEX_UTIL.GET_SINCE(n.created_at) AS time_ago,
    CASE n.notification_type
        WHEN 'TASK_ASSIGNED'     THEN 'fa-user-plus u-color-4'
        WHEN 'STATUS_CHANGED'    THEN 'fa-exchange u-color-5'
        WHEN 'APPROVAL_REQUIRED' THEN 'fa-gavel u-color-15'
        WHEN 'APPROVAL_RESULT'   THEN 'fa-check-circle u-color-1'
        WHEN 'COMMENT_ADDED'     THEN 'fa-comment u-color-9'
        WHEN 'TASK_OVERDUE'      THEN 'fa-warning u-color-6'
        ELSE 'fa-bell'
    END AS icon_class
FROM tts_notifications n
LEFT JOIN tts_tasks t ON t.task_id = n.task_id
WHERE n.user_id = TO_NUMBER(:F_USER_ID)
ORDER BY n.created_at DESC
FETCH FIRST 20 ROWS ONLY;

/*
=== PROCESS: Mark Notifications as Read (On Page Load or Button Click) ===
  Type: PL/SQL Code
  Point: Ajax Callback
  Name: MARK_ALL_READ
*/

-- PL/SQL:
BEGIN
    tts_pkg_notifications.mark_all_read(TO_NUMBER(:F_USER_ID));
END;


-- ################################################################
-- ##  PAGE 2: DASHBOARD (Home Page)
-- ##  Contains: KPI Cards, Charts, Overdue List
-- ################################################################

/*
=== REGION 1: KPI Summary Cards ===
  Region Type: Cards
  Template: Standard
  Layout: 5 columns grid

  Use Static Content regions with PL/SQL to render each card,
  OR use a single SQL query returning all KPIs:
*/

-- KPI Source Query (for Cards Region):
SELECT 
    'Total Tasks' AS kpi_label,
    total_tasks AS kpi_value,
    'fa-tasks' AS kpi_icon,
    'u-color-4' AS kpi_color,
    NULL AS kpi_link
FROM v_dashboard_stats
UNION ALL
SELECT 
    'In Progress',
    in_progress_count,
    'fa-spinner',
    'u-color-5',
    'f?p=&APP_ID.:3:&SESSION.::NO::P3_STATUS:IN_PROGRESS'
FROM v_dashboard_stats
UNION ALL
SELECT 
    'On Hold',
    on_hold_count,
    'fa-pause-circle',
    'u-color-6',
    'f?p=&APP_ID.:3:&SESSION.::NO::P3_STATUS:ON_HOLD'
FROM v_dashboard_stats
UNION ALL
SELECT 
    'Overdue',
    overdue_count,
    'fa-warning',
    'u-color-8',
    NULL
FROM v_dashboard_stats
UNION ALL
SELECT 
    'Pending Approval',
    pending_approval_count,
    'fa-gavel',
    'u-color-15',
    'f?p=&APP_ID.:12:&SESSION.'
FROM v_dashboard_stats;

/*
  Cards Attributes:
    Title Column: KPI_LABEL
    Body Column:  KPI_VALUE (with CSS class tts-kpi-card kpi-value)
    Icon Column:  KPI_ICON
    Card Link:    KPI_LINK (optional)
*/


/*
=== REGION 2: Tasks by Status (Pie Chart) ===
  Region Type: Chart
  Chart Type: Pie
  Name: Tasks by Status
*/

-- Chart SQL:
SELECT status_display AS label,
       COUNT(*)       AS value,
       CASE status
           WHEN 'CREATED'     THEN '#4285f4'
           WHEN 'IN_PROGRESS' THEN '#fbbc04'
           WHEN 'ON_HOLD'     THEN '#ea4335'
           WHEN 'COMPLETED'   THEN '#34a853'
           WHEN 'CANCELLED'   THEN '#9aa0a6'
       END AS color
FROM v_tasks_full
WHERE (:F_USER_ROLE = 'ADMIN'
       OR assigned_to_id = TO_NUMBER(:F_USER_ID)
       OR (:F_USER_ROLE = 'MANAGER' 
           AND manager_id = TO_NUMBER(:F_USER_ID)))
GROUP BY status, status_display
ORDER BY DECODE(status,'CREATED',1,'IN_PROGRESS',2,'ON_HOLD',3,'COMPLETED',4,'CANCELLED',5);


/*
=== REGION 3: Estimated vs Actual Hours (Bar Chart) ===
  Region Type: Chart
  Chart Type: Bar (Horizontal)
  Name: Estimated vs Actual Hours
  Two Series:
*/

-- Series 1: Estimated Hours
SELECT assigned_to_name AS label,
       SUM(estimated_hours) AS value
FROM v_tasks_full
WHERE (:F_USER_ROLE = 'ADMIN'
       OR assigned_to_id = TO_NUMBER(:F_USER_ID)
       OR (:F_USER_ROLE = 'MANAGER' 
           AND manager_id = TO_NUMBER(:F_USER_ID)))
AND status != 'CANCELLED'
GROUP BY assigned_to_name
ORDER BY assigned_to_name;

-- Series 2: Actual Hours
SELECT assigned_to_name AS label,
       SUM(actual_hours) AS value
FROM v_tasks_full
WHERE (:F_USER_ROLE = 'ADMIN'
       OR assigned_to_id = TO_NUMBER(:F_USER_ID)
       OR (:F_USER_ROLE = 'MANAGER' 
           AND manager_id = TO_NUMBER(:F_USER_ID)))
AND status != 'CANCELLED'
GROUP BY assigned_to_name
ORDER BY assigned_to_name;


/*
=== REGION 4: Overdue Tasks List ===
  Region Type: Classic Report or Cards
  Name: Overdue Tasks
  Template: Alert / Warning styled
*/

-- Source SQL:
SELECT 
    task_number,
    title,
    assigned_to_name,
    system_name,
    due_date,
    days_remaining,
    priority_display,
    CASE priority
        WHEN 'CRITICAL' THEN 'u-danger'
        WHEN 'HIGH'     THEN 'u-warning'
        ELSE ''
    END AS row_class
FROM v_overdue_tasks
WHERE (:F_USER_ROLE = 'ADMIN'
       OR assigned_to_id = TO_NUMBER(:F_USER_ID)
       OR (:F_USER_ROLE = 'MANAGER' 
           AND manager_id = TO_NUMBER(:F_USER_ID)))
ORDER BY due_date ASC
FETCH FIRST 10 ROWS ONLY;


/*
=== REGION 5: Workload by Team Member (Bar Chart — Manager/Admin only) ===
  Region Type: Chart
  Chart Type: Bar
  Authorization: IS_MANAGER_OR_ADMIN
*/

-- Chart SQL:
SELECT 
    full_name AS label,
    in_progress_count AS value
FROM v_user_workload
WHERE (:F_USER_ROLE = 'ADMIN' 
       OR manager_id = TO_NUMBER(:F_USER_ID))
AND total_tasks > 0
ORDER BY in_progress_count DESC;


-- ################################################################
-- ##  PAGE 3: MY TASKS (Interactive Report)
-- ##  Contains: IR with row-level security, Create button
-- ################################################################

/*
=== PAGE ITEM: P3_STATUS (Hidden, used for deep linking from Dashboard) ===
  Type: Hidden
  Used to pre-filter IR when coming from Dashboard KPI cards
*/

/*
=== REGION 1: My Tasks ===
  Region Type: Interactive Report
  Name: My Tasks
*/

-- IR Source SQL:
SELECT 
    task_id,
    task_number,
    title,
    system_name,
    assigned_to_name,
    status,
    status_display,
    priority,
    priority_display,
    start_date,
    due_date,
    estimated_hours,
    actual_hours,
    days_remaining,
    is_overdue,
    approval_status,
    approval_display,
    comments_count,
    attachments_count,
    tags_list,
    completion_pct,
    created_by_name,
    created_at,
    -- CSS class for status badge
    'status-' || LOWER(status) AS status_css,
    -- CSS class for priority badge
    'priority-' || LOWER(priority) AS priority_css,
    -- Link to task details
    APEX_PAGE.GET_URL(
        p_page   => 5,
        p_items  => 'P5_TASK_ID',
        p_values => task_id
    ) AS detail_link
FROM v_tasks_full
WHERE (
    :F_USER_ROLE = 'ADMIN'
    OR assigned_to_id = TO_NUMBER(:F_USER_ID)
    OR created_by_id = TO_NUMBER(:F_USER_ID)
    OR (:F_USER_ROLE = 'MANAGER' 
        AND manager_id = TO_NUMBER(:F_USER_ID))
)
AND (:P3_STATUS IS NULL OR status = :P3_STATUS)
ORDER BY 
    CASE WHEN is_overdue = 'Y' THEN 0 ELSE 1 END,
    DECODE(priority,'CRITICAL',1,'HIGH',2,'MEDIUM',3,'LOW',4),
    due_date ASC;

/*
  IR Column Formatting:
    STATUS_DISPLAY:   HTML Expression: <span class="#STATUS_CSS#">#STATUS_DISPLAY#</span>
    PRIORITY_DISPLAY: HTML Expression: <span class="#PRIORITY_CSS#">#PRIORITY_DISPLAY#</span>
    TASK_NUMBER:      Link Column -> Page 5, P5_TASK_ID = #TASK_ID#
    IS_OVERDUE:       Hidden (used for conditional formatting)
    
  Row Highlighting:
    CSS Class Column: Use row_class or use JavaScript to highlight overdue rows
*/

/*
=== BUTTON: Create Task ===
  Button Name: CREATE_TASK
  Label: + New Task
  Action: Redirect to Page 4 (Modal Dialog)
  Target: Page 4, Clear Session for Page 4
*/


-- ################################################################
-- ##  PAGE 4: TASK FORM (Modal Dialog)
-- ##  Create / Edit Task
-- ################################################################

/*
=== PAGE PROPERTIES ===
  Page Mode: Modal Dialog
  Dialog Template: Drawer (or Standard Modal)
  Page Item: P4_TASK_ID (Hidden, Primary Key)
*/

/*
=== REGION 1: Task Form ===
  Region Type: Form
  Table: TTS_TASKS
  Primary Key: TASK_ID
*/

/*
=== PAGE ITEMS ===

  P4_TASK_ID        | Hidden              | Primary Key
  P4_TASK_NUMBER     | Display Only        | Auto-generated
  P4_TITLE           | Text Field          | Required, Max 250
  P4_DESCRIPTION     | Rich Text Editor    | Optional
  P4_SYSTEM_ID       | Select List         | LOV: LOV_SYSTEMS, Required
  P4_ASSIGNED_TO     | Select List         | LOV: LOV_TEAM_MEMBERS, Required
  P4_PRIORITY        | Select List         | LOV: LOV_PRIORITY, Default: MEDIUM
  P4_START_DATE      | Date Picker         | Required, Default: SYSDATE
  P4_DUE_DATE        | Date Picker         | Required
  P4_ESTIMATED_HOURS | Number Field        | Required, Min: 0
  P4_STATUS          | Display Only        | Read-only on form
  P4_CREATED_BY      | Hidden              | Default: &F_USER_ID.
  P4_TAGS            | Shuttle or Popup LOV | LOV: LOV_TAGS (multi-select)
*/

/*
=== VALIDATION 1: Due Date >= Start Date ===
  Type: PL/SQL Expression
  Name: Check Due Date
*/
-- :P4_DUE_DATE >= :P4_START_DATE

-- Error Message: Due date must be on or after the start date.

/*
=== VALIDATION 2: Estimated Hours > 0 ===
  Type: PL/SQL Expression
*/
-- TO_NUMBER(:P4_ESTIMATED_HOURS) > 0

-- Error Message: Estimated hours must be greater than zero.

/*
=== PROCESS 1: Create/Update Task ===
  Type: PL/SQL Code
  Point: Processing
  Name: Save Task
  Server-side Condition: Request is contained in 'CREATE,SAVE'
*/

-- PL/SQL:
DECLARE
    v_task_id NUMBER;
BEGIN
    IF :P4_TASK_ID IS NULL THEN
        -- Creating new task
        v_task_id := tts_pkg_tasks.create_task(
            p_title           => :P4_TITLE,
            p_description     => :P4_DESCRIPTION,
            p_system_id       => TO_NUMBER(:P4_SYSTEM_ID),
            p_assigned_to     => TO_NUMBER(:P4_ASSIGNED_TO),
            p_created_by      => TO_NUMBER(:F_USER_ID),
            p_priority        => :P4_PRIORITY,
            p_start_date      => TO_DATE(:P4_START_DATE, 'DD-MON-YYYY'),
            p_due_date        => TO_DATE(:P4_DUE_DATE, 'DD-MON-YYYY'),
            p_estimated_hours => TO_NUMBER(:P4_ESTIMATED_HOURS)
        );
        :P4_TASK_ID := v_task_id;
    ELSE
        -- Updating existing task
        UPDATE tts_tasks
        SET    title           = :P4_TITLE,
               description     = :P4_DESCRIPTION,
               system_id       = TO_NUMBER(:P4_SYSTEM_ID),
               assigned_to     = TO_NUMBER(:P4_ASSIGNED_TO),
               priority        = :P4_PRIORITY,
               start_date      = TO_DATE(:P4_START_DATE, 'DD-MON-YYYY'),
               due_date        = TO_DATE(:P4_DUE_DATE, 'DD-MON-YYYY'),
               estimated_hours = TO_NUMBER(:P4_ESTIMATED_HOURS)
        WHERE  task_id = TO_NUMBER(:P4_TASK_ID);
    END IF;
END;

/*
=== PROCESS 2: Save Tags (After Task Save) ===
  Type: PL/SQL Code
  Point: Processing (after Save Task)
*/

-- PL/SQL:
BEGIN
    -- Clear existing tags
    DELETE FROM tts_task_tags WHERE task_id = TO_NUMBER(:P4_TASK_ID);
    
    -- Insert selected tags (P4_TAGS is colon-separated in APEX)
    IF :P4_TAGS IS NOT NULL THEN
        INSERT INTO tts_task_tags (task_id, tag_id)
        SELECT TO_NUMBER(:P4_TASK_ID), TO_NUMBER(column_value)
        FROM TABLE(APEX_STRING.SPLIT(:P4_TAGS, ':'));
    END IF;
END;

/*
=== PROCESS 3: Close Dialog ===
  Type: Close Dialog
  Point: Processing (after all processes)
*/


-- ################################################################
-- ##  PAGE 5: TASK DETAILS & COLLABORATION HUB
-- ##  Full task view with Comments, Attachments, History
-- ################################################################

/*
=== PAGE ITEM ===
  P5_TASK_ID | Hidden | Primary Key (passed from Page 3 or Kanban)
*/

/*
=== REGION 1: Task Header ===
  Region Type: Static Content (or PL/SQL Dynamic Content)
  Template: Hero
*/

-- Source SQL (Fetch Row):
SELECT 
    t.task_id,
    t.task_number,
    t.title,
    t.description,
    t.system_name,
    t.status,
    t.status_display,
    t.priority,
    t.priority_display,
    t.assigned_to_name,
    t.created_by_name,
    t.start_date,
    t.due_date,
    t.estimated_hours,
    t.actual_hours,
    t.hours_remaining,
    t.completion_pct,
    t.days_remaining,
    t.is_overdue,
    t.approval_status,
    t.approval_display,
    t.approval_notes,
    t.approved_by_name,
    t.comments_count,
    t.attachments_count,
    t.tags_list,
    t.completion_date
FROM v_tasks_full t
WHERE t.task_id = TO_NUMBER(:P5_TASK_ID);


/*
=== REGION 2: Action Buttons Bar ===
  Region Type: Static Content
  Template: Buttons Container
  
  Buttons are conditionally displayed based on task status and user role.
*/

/*
  BTN_START:
    Label: Start Working
    Condition: :P5_STATUS = 'CREATED'
               AND (user is assigned or admin)
    Action: Execute process CHANGE_STATUS with value 'IN_PROGRESS'

  BTN_HOLD:
    Label: Put On Hold
    Condition: :P5_STATUS = 'IN_PROGRESS'
    Action: Execute process CHANGE_STATUS with value 'ON_HOLD'

  BTN_RESUME:
    Label: Resume
    Condition: :P5_STATUS = 'ON_HOLD'
    Action: Execute process CHANGE_STATUS with value 'IN_PROGRESS'

  BTN_COMPLETE:
    Label: Mark Complete
    Condition: :P5_STATUS = 'IN_PROGRESS'
    Action: Execute process CHANGE_STATUS with value 'COMPLETED'

  BTN_SUBMIT_APPROVAL:
    Label: Submit for Approval
    Condition: :P5_STATUS = 'COMPLETED' AND :P5_APPROVAL_STATUS IN ('NOT_SUBMITTED','REJECTED')
    Action: Execute process SUBMIT_APPROVAL

  BTN_APPROVE:
    Label: ✓ Approve
    CSS: t-Button--success
    Condition: :P5_APPROVAL_STATUS = 'PENDING' AND :F_USER_ROLE IN ('ADMIN','MANAGER')
    Action: Execute process APPROVE_TASK

  BTN_REJECT:
    Label: ✗ Reject
    CSS: t-Button--danger
    Condition: :P5_APPROVAL_STATUS = 'PENDING' AND :F_USER_ROLE IN ('ADMIN','MANAGER')
    Action: Execute process REJECT_TASK (with P5_REJECTION_NOTES popup)

  BTN_CANCEL:
    Label: Cancel Task
    CSS: t-Button--warning
    Condition: :P5_STATUS NOT IN ('COMPLETED','CANCELLED')
    Action: Execute process CHANGE_STATUS with value 'CANCELLED'

  BTN_EDIT:
    Label: Edit
    Condition: tts_pkg_security.can_user_edit_task returns TRUE
    Action: Redirect to Page 4 with P4_TASK_ID = :P5_TASK_ID
*/


/*
=== PROCESS: CHANGE_STATUS (Ajax Callback) ===
*/
BEGIN
    tts_pkg_tasks.update_task_status(
        p_task_id    => TO_NUMBER(:P5_TASK_ID),
        p_new_status => APEX_APPLICATION.G_X01,  -- status value passed via JS
        p_user_id    => TO_NUMBER(:F_USER_ID)
    );
    COMMIT;
END;

/*
=== PROCESS: SUBMIT_APPROVAL (Ajax Callback) ===
*/
BEGIN
    tts_pkg_tasks.submit_for_approval(
        p_task_id => TO_NUMBER(:P5_TASK_ID),
        p_user_id => TO_NUMBER(:F_USER_ID)
    );
    COMMIT;
END;

/*
=== PROCESS: APPROVE_TASK (Ajax Callback) ===
*/
BEGIN
    tts_pkg_tasks.process_approval(
        p_task_id    => TO_NUMBER(:P5_TASK_ID),
        p_decision   => 'APPROVED',
        p_manager_id => TO_NUMBER(:F_USER_ID),
        p_notes      => :P5_APPROVAL_NOTES
    );
    COMMIT;
END;

/*
=== PROCESS: REJECT_TASK (Ajax Callback) ===
*/
BEGIN
    tts_pkg_tasks.process_approval(
        p_task_id    => TO_NUMBER(:P5_TASK_ID),
        p_decision   => 'REJECTED',
        p_manager_id => TO_NUMBER(:F_USER_ID),
        p_notes      => :P5_REJECTION_NOTES
    );
    COMMIT;
END;


/*
=== REGION 3: Time Tracking Summary ===
  Region Type: Static Content
  Shows: Estimated / Actual / Remaining hours with progress bar
  
  Use PL/SQL Dynamic Content or HTML with substitutions
*/


/*
=== REGION 4: Tab Container (Comments / Attachments / History) ===
  Use: Region Display Selector or Tabs Container
*/

/*
=== SUB-REGION 4A: Comments ===
  Region Type: Classic Report
  Parent: Tab Container
*/

-- Comments SQL:
SELECT 
    c.comment_id,
    c.comment_text,
    u.full_name AS commenter_name,
    u.role AS commenter_role,
    APEX_UTIL.GET_SINCE(c.created_at) AS time_ago,
    c.created_at,
    CASE WHEN c.user_id = TO_NUMBER(:F_USER_ID) THEN 'Y' ELSE 'N' END AS is_mine
FROM tts_comments c
JOIN tts_users u ON u.user_id = c.user_id
WHERE c.task_id = TO_NUMBER(:P5_TASK_ID)
ORDER BY c.created_at DESC;

/*
=== PAGE ITEM: P5_NEW_COMMENT (Textarea) ===
  Placeholder: Write a comment...
  
=== BUTTON: BTN_ADD_COMMENT ===
  Action: Submit (trigger process below)
*/

/*
=== PROCESS: Add Comment ===
  Type: PL/SQL Code
  When Button Pressed: BTN_ADD_COMMENT
*/
BEGIN
    tts_pkg_tasks.add_comment(
        p_task_id      => TO_NUMBER(:P5_TASK_ID),
        p_user_id      => TO_NUMBER(:F_USER_ID),
        p_comment_text => :P5_NEW_COMMENT
    );
    -- Clear the comment box
    :P5_NEW_COMMENT := NULL;
    COMMIT;
END;


/*
=== SUB-REGION 4B: Attachments ===
  Region Type: Classic Report + File Browse item
  Parent: Tab Container
*/

-- Attachments List SQL:
SELECT 
    a.attachment_id,
    a.file_name,
    a.file_mimetype,
    DBMS_LOB.GETLENGTH(a.file_blob) AS file_size,
    u.full_name AS uploaded_by_name,
    APEX_UTIL.GET_SINCE(a.uploaded_at) AS time_ago,
    -- Download link
    APEX_PAGE.GET_URL(
        p_page   => 5,
        p_request => 'APPLICATION_PROCESS=DOWNLOAD_FILE',
        p_items  => 'P5_ATTACHMENT_ID',
        p_values => a.attachment_id
    ) AS download_url
FROM tts_attachments a
JOIN tts_users u ON u.user_id = a.uploaded_by
WHERE a.task_id = TO_NUMBER(:P5_TASK_ID)
ORDER BY a.uploaded_at DESC;

/*
=== PAGE ITEMS for Upload ===
  P5_UPLOAD_FILE | File Browse | Storage: BLOB Column
  
=== PROCESS: Upload Attachment ===
  Type: PL/SQL Code
  When Button Pressed: BTN_UPLOAD
*/
BEGIN
    INSERT INTO tts_attachments (
        task_id, file_name, file_mimetype, file_blob, file_charset, uploaded_by
    )
    SELECT 
        TO_NUMBER(:P5_TASK_ID),
        filename,
        mime_type,
        blob_content,
        character_set,
        TO_NUMBER(:F_USER_ID)
    FROM apex_application_temp_files
    WHERE name = :P5_UPLOAD_FILE;
    
    -- Clean up temp file
    DELETE FROM apex_application_temp_files WHERE name = :P5_UPLOAD_FILE;
    COMMIT;
END;

/*
=== PROCESS: Download Attachment (Application Process) ===
  Name: DOWNLOAD_FILE
  Type: PL/SQL Code
  Point: Ajax Callback
*/
DECLARE
    v_blob     BLOB;
    v_filename VARCHAR2(255);
    v_mimetype VARCHAR2(100);
BEGIN
    SELECT file_blob, file_name, file_mimetype
    INTO   v_blob, v_filename, v_mimetype
    FROM   tts_attachments
    WHERE  attachment_id = TO_NUMBER(:P5_ATTACHMENT_ID);
    
    SYS.HTP.INIT;
    OWA_UTIL.MIME_HEADER(v_mimetype, FALSE);
    SYS.HTP.P('Content-Disposition: attachment; filename="' || v_filename || '"');
    SYS.HTP.P('Content-Length: ' || DBMS_LOB.GETLENGTH(v_blob));
    OWA_UTIL.HTTP_HEADER_CLOSE;
    WPG_DOCLOAD.DOWNLOAD_FILE(v_blob);
    APEX_APPLICATION.STOP_APEX_ENGINE;
END;


/*
=== SUB-REGION 4C: Activity History (Timeline) ===
  Region Type: Classic Report
  Parent: Tab Container
  Template: Timeline (if available) or standard list
*/

-- History SQL:
SELECT 
    h.history_id,
    h.change_type,
    h.old_value,
    h.new_value,
    u.full_name AS changed_by_name,
    APEX_UTIL.GET_SINCE(h.changed_at) AS time_ago,
    h.changed_at,
    CASE h.change_type
        WHEN 'CREATED'    THEN 'fa-plus-circle u-color-1'
        WHEN 'STATUS'     THEN 'fa-exchange u-color-5'
        WHEN 'ASSIGNMENT' THEN 'fa-user-plus u-color-4'
        WHEN 'PRIORITY'   THEN 'fa-flag u-color-6'
        WHEN 'APPROVAL'   THEN 'fa-gavel u-color-15'
        ELSE 'fa-pencil u-color-9'
    END AS icon_class,
    CASE h.change_type
        WHEN 'CREATED'    THEN 'Task created'
        WHEN 'STATUS'     THEN 'Status changed from ' || h.old_value || ' to ' || h.new_value
        WHEN 'ASSIGNMENT' THEN 'Reassigned from ' || h.old_value || ' to ' || h.new_value
        WHEN 'APPROVAL'   THEN 'Approval: ' || h.new_value
        ELSE h.change_type || ': ' || h.new_value
    END AS description
FROM tts_task_history h
JOIN tts_users u ON u.user_id = h.changed_by
WHERE h.task_id = TO_NUMBER(:P5_TASK_ID)
ORDER BY h.changed_at DESC;


-- ################################################################
-- ##  PAGE 6: KANBAN BOARD
-- ##  Drag-and-drop task management
-- ################################################################

/*
=== REGION 1: Kanban Board ===
  Region Type: Cards
  
  In APEX 24.2, you can configure Cards as a Kanban board.
  
  Alternative: Use the "Content Row" template with status columns
  as separate regions side by side.
  
  For a true Kanban, use APEX Cards with:
    - Card Column: STATUS
    - Card Title: TITLE
    - Card Body: assigned_to_name + priority badge
    - Drag/Drop: Enabled via Dynamic Actions
*/

-- Kanban Source SQL:
SELECT 
    task_id,
    task_number,
    title,
    status,
    status_display,
    priority,
    priority_display,
    assigned_to_name,
    due_date,
    days_remaining,
    is_overdue,
    comments_count,
    attachments_count,
    'priority-' || LOWER(priority) AS card_css,
    CASE 
        WHEN is_overdue = 'Y' THEN 'overdue-text' 
        ELSE '' 
    END AS due_css
FROM v_tasks_full
WHERE (
    :F_USER_ROLE = 'ADMIN'
    OR assigned_to_id = TO_NUMBER(:F_USER_ID)
    OR created_by_id = TO_NUMBER(:F_USER_ID)
    OR (:F_USER_ROLE = 'MANAGER' 
        AND manager_id = TO_NUMBER(:F_USER_ID))
)
AND status != 'CANCELLED'
ORDER BY 
    DECODE(priority,'CRITICAL',1,'HIGH',2,'MEDIUM',3,'LOW',4),
    due_date;

/*
=== DYNAMIC ACTION: Kanban Card Drop (Status Change) ===
  Event: Cards Region [Status Change] (or custom jQuery drag event)
  Action: Execute Server-side Code (Ajax)
  
  Pass the task_id and new_status via apex.server.process:
*/

-- JavaScript for Dynamic Action:
/*
apex.server.process("KANBAN_STATUS_CHANGE", {
    x01: taskId,
    x02: newStatus
}, {
    success: function(data) {
        apex.region("kanban_board").refresh();
        apex.message.showPageSuccess("Task status updated!");
    },
    error: function(jqXHR, textStatus, errorThrown) {
        apex.message.showErrors([{
            type: "error",
            location: "page",
            message: jqXHR.responseText || "Error updating status"
        }]);
    }
});
*/

/*
=== PROCESS: KANBAN_STATUS_CHANGE (Ajax Callback) ===
*/
BEGIN
    tts_pkg_tasks.update_task_status(
        p_task_id    => TO_NUMBER(APEX_APPLICATION.G_X01),
        p_new_status => APEX_APPLICATION.G_X02,
        p_user_id    => TO_NUMBER(:F_USER_ID)
    );
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        APEX_JSON.OPEN_OBJECT;
        APEX_JSON.WRITE('error', SQLERRM);
        APEX_JSON.CLOSE_OBJECT;
        HTP.P(APEX_JSON.GET_CLOB_OUTPUT);
END;


-- ################################################################
-- ##  PAGE 7: SYSTEMS MANAGEMENT (Admin Only)
-- ################################################################

/*
=== PAGE PROPERTIES ===
  Authorization: IS_ADMIN

=== REGION 1: Systems ===
  Region Type: Interactive Grid
  Table: TTS_SYSTEMS
  Editable: Yes
  Columns: system_id (PK, Hidden), system_name, description, is_active
  LOV for is_active: LOV_YES_NO
*/


-- ################################################################
-- ##  PAGE 8: USERS MANAGEMENT (Admin Only)
-- ################################################################

/*
=== PAGE PROPERTIES ===
  Authorization: IS_ADMIN

=== REGION 1: Users ===
  Region Type: Interactive Report
  Source: v_user_workload or direct table query
*/

-- Users IR SQL:
SELECT 
    u.user_id,
    u.username,
    u.email,
    u.full_name,
    u.role,
    d.dept_name,
    m.full_name AS manager_name,
    u.is_active,
    u.last_login,
    u.created_at
FROM tts_users u
LEFT JOIN tts_departments d ON d.dept_id = u.dept_id
LEFT JOIN tts_users m ON m.user_id = u.manager_id
ORDER BY u.full_name;

/*
=== BUTTON: BTN_ADD_USER ===
  Action: Redirect to Page 8a (Modal) or use inline form

=== MODAL / INLINE FORM ITEMS ===
  P8_USER_ID      | Hidden
  P8_USERNAME      | Text Field     | Required
  P8_PASSWORD      | Password       | Required (only on create)
  P8_EMAIL         | Text Field     | Required
  P8_FULL_NAME     | Text Field     | Required
  P8_ROLE          | Select List    | LOV: LOV_USER_ROLES
  P8_DEPT_ID       | Select List    | LOV: LOV_DEPARTMENTS
  P8_MANAGER_ID    | Select List    | LOV: LOV_USERS_ACTIVE
  P8_IS_ACTIVE     | Switch         | Y/N

=== PROCESS: Create User ===
*/
BEGIN
    tts_pkg_admin.create_user(
        p_username   => :P8_USERNAME,
        p_password   => :P8_PASSWORD,
        p_email      => :P8_EMAIL,
        p_full_name  => :P8_FULL_NAME,
        p_role       => :P8_ROLE,
        p_dept_id    => TO_NUMBER(:P8_DEPT_ID),
        p_manager_id => TO_NUMBER(:P8_MANAGER_ID)
    );
    COMMIT;
END;


-- ################################################################
-- ##  PAGE 9: MY PROFILE (Modal Dialog)
-- ################################################################

/*
=== PAGE PROPERTIES ===
  Page Mode: Modal Dialog
  Authorization: IS_AUTHENTICATED

=== PAGE ITEMS ===
  P9_FULL_NAME     | Text Field   | Pre-populated, Editable
  P9_EMAIL         | Text Field   | Pre-populated, Editable
  P9_OLD_PASSWORD  | Password     |
  P9_NEW_PASSWORD  | Password     |
  P9_CONFIRM_PASS  | Password     |

=== FETCH PROCESS (Before Header) ===
*/
SELECT full_name, email
INTO :P9_FULL_NAME, :P9_EMAIL
FROM tts_users
WHERE user_id = TO_NUMBER(:F_USER_ID);

/*
=== VALIDATION: Confirm Password Match ===
*/
-- :P9_NEW_PASSWORD = :P9_CONFIRM_PASS
-- Error Message: New password and confirmation do not match.

/*
=== PROCESS: Update Profile ===
*/
BEGIN
    UPDATE tts_users
    SET    full_name = :P9_FULL_NAME,
           email     = :P9_EMAIL
    WHERE  user_id = TO_NUMBER(:F_USER_ID);
    
    -- Update session state
    APEX_UTIL.SET_SESSION_STATE('F_FULL_NAME', :P9_FULL_NAME);
    COMMIT;
END;

/*
=== PROCESS: Change Password (conditional — only if filled) ===
  Server-side Condition: P9_OLD_PASSWORD IS NOT NULL
*/
BEGIN
    tts_pkg_security.change_password(
        p_user_id      => TO_NUMBER(:F_USER_ID),
        p_old_password => :P9_OLD_PASSWORD,
        p_new_password => :P9_NEW_PASSWORD
    );
    COMMIT;
END;


-- ################################################################
-- ##  PAGE 10: TEAM OVERVIEW (Manager/Admin)
-- ################################################################

/*
=== PAGE PROPERTIES ===
  Authorization: IS_MANAGER_OR_ADMIN

=== REGION 1: Team Workload Summary ===
  Region Type: Cards
*/

-- Team Cards SQL:
SELECT 
    user_id,
    full_name,
    username,
    dept_name,
    total_tasks,
    in_progress_count,
    completed_count,
    overdue_count,
    total_estimated_hours,
    total_actual_hours,
    CASE 
        WHEN overdue_count > 0 THEN 'u-color-8'
        WHEN in_progress_count > 5 THEN 'u-color-6'
        ELSE 'u-color-1'
    END AS card_color
FROM v_user_workload
WHERE (:F_USER_ROLE = 'ADMIN' OR manager_id = TO_NUMBER(:F_USER_ID))
AND total_tasks > 0
ORDER BY overdue_count DESC, in_progress_count DESC;

/*
=== REGION 2: Team Tasks Detail ===
  Region Type: Interactive Report
  Source: v_manager_team_tasks
*/

-- IR SQL:
SELECT *
FROM v_tasks_full
WHERE (:F_USER_ROLE = 'ADMIN' OR manager_id = TO_NUMBER(:F_USER_ID))
ORDER BY 
    CASE WHEN is_overdue = 'Y' THEN 0 ELSE 1 END,
    due_date;


-- ################################################################
-- ##  PAGE 11: DAILY TIME LOG
-- ################################################################

/*
=== PAGE PROPERTIES ===
  Authorization: IS_AUTHENTICATED

=== REGION 1: Daily Time Log ===
  Region Type: Interactive Grid
  Editable: Yes
*/

-- IG Source SQL:
SELECT 
    dl.log_id,
    dl.task_id,
    t.task_number,
    t.title AS task_title,
    dl.log_date,
    dl.hours_spent,
    dl.notes,
    dl.created_at
FROM tts_daily_log dl
JOIN tts_tasks t ON t.task_id = dl.task_id
WHERE dl.user_id = TO_NUMBER(:F_USER_ID)
ORDER BY dl.log_date DESC, t.task_number;

/*
  IG Columns:
    LOG_ID:       Hidden (PK)
    TASK_ID:      Select List, LOV = active tasks for this user
    TASK_NUMBER:  Display Only
    TASK_TITLE:   Display Only
    LOG_DATE:     Date Picker, Default: SYSDATE
    HOURS_SPENT:  Number (Min: 0.25, Max: 24, Step: 0.25)
    NOTES:        Textarea
    
  For task selection LOV:
*/

-- LOV for user's active tasks:
SELECT task_number || ' - ' || title d, task_id r
FROM tts_tasks
WHERE assigned_to = TO_NUMBER(:F_USER_ID)
AND status IN ('CREATED', 'IN_PROGRESS', 'ON_HOLD')
ORDER BY task_number;

/*
  Note: The trigger trg_daily_log_calc will automatically
  recalculate actual_hours on the parent task when rows
  are inserted/updated/deleted in this grid.
*/


-- ################################################################
-- ##  PAGE 12: PENDING APPROVALS (Manager/Admin)
-- ################################################################

/*
=== PAGE PROPERTIES ===
  Authorization: IS_MANAGER_OR_ADMIN

=== REGION 1: Pending Approvals ===
  Region Type: Interactive Report
*/

-- IR SQL:
SELECT 
    t.task_id,
    t.task_number,
    t.title,
    t.system_name,
    t.assigned_to_name,
    t.priority_display,
    t.due_date,
    t.estimated_hours,
    t.actual_hours,
    t.completion_date,
    t.completion_pct,
    t.tags_list,
    APEX_PAGE.GET_URL(
        p_page   => 5,
        p_items  => 'P5_TASK_ID',
        p_values => t.task_id
    ) AS detail_link
FROM v_tasks_full t
WHERE t.approval_status = 'PENDING'
AND (
    :F_USER_ROLE = 'ADMIN'
    OR t.manager_id = TO_NUMBER(:F_USER_ID)
)
ORDER BY t.completion_date ASC;

/*
=== ROW ACTION BUTTONS ===
  Approve: Calls APPROVE_TASK process
  Reject:  Opens mini-form for rejection notes, then calls REJECT_TASK
  View:    Links to Page 5
*/

/*
=== PROCESS: QUICK_APPROVE (Ajax Callback) ===
*/
BEGIN
    tts_pkg_tasks.process_approval(
        p_task_id    => TO_NUMBER(APEX_APPLICATION.G_X01),
        p_decision   => 'APPROVED',
        p_manager_id => TO_NUMBER(:F_USER_ID),
        p_notes      => 'Approved'
    );
    COMMIT;
END;

/*
=== PROCESS: QUICK_REJECT (Ajax Callback) ===
*/
BEGIN
    tts_pkg_tasks.process_approval(
        p_task_id    => TO_NUMBER(APEX_APPLICATION.G_X01),
        p_decision   => 'REJECTED',
        p_manager_id => TO_NUMBER(:F_USER_ID),
        p_notes      => APEX_APPLICATION.G_X02  -- rejection notes
    );
    COMMIT;
END;


-- ################################################################
-- ##  PAGE 13: DEPARTMENTS (Admin Only)
-- ################################################################

/*
=== PAGE PROPERTIES ===
  Authorization: IS_ADMIN

=== REGION 1: Departments ===
  Region Type: Interactive Grid
  Table: TTS_DEPARTMENTS
  Editable: Yes
  Columns:
    dept_id    (PK, Hidden)
    dept_name  (Text, Required)
    dept_head_id (Select List, LOV: LOV_USERS_ACTIVE)
    is_active  (Switch, Y/N)
*/


-- ################################################################
-- ##  PAGE 14: LOOKUPS MANAGEMENT (Admin Only)
-- ################################################################

/*
=== PAGE PROPERTIES ===
  Authorization: IS_ADMIN

=== REGION 1: Lookups ===
  Region Type: Interactive Grid
  Table: TTS_LOOKUPS
  Editable: Yes
  Columns:
    lookup_id      (PK, Hidden)
    lookup_type    (Text, Required)
    lookup_code    (Text, Required)
    display_name   (Text, Required)
    display_name_ar (Text)
    display_order  (Number)
    is_active      (Switch, Y/N)
*/


-- ################################################################
-- ##  SUMMARY — DYNAMIC ACTIONS REFERENCE
-- ################################################################

/*
  Page 3:  DA: After Dialog Close (Page 4) -> Refresh IR
  Page 5:  DA: Button Click -> Ajax for status changes
           DA: After comment submit -> Refresh comments region
           DA: After upload -> Refresh attachments region
  Page 6:  DA: Card Drag -> Ajax KANBAN_STATUS_CHANGE
  Page 11: DA: IG Save -> Success message
  Page 12: DA: Approve/Reject buttons -> Ajax + Refresh IR
*/


PROMPT ============================================================
PROMPT  TTS APEX Pages Guide — COMPLETE
PROMPT  Use this file as reference when building pages in APEX Builder
PROMPT ============================================================

