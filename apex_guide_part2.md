# 🏗 دليل بناء صفحات APEX — الجزء الثاني
## بناء الصفحات (Pages 2–14)

> [!IMPORTANT]
> تأكد من إكمال الجزء الأول (المرحلة 1–7) قبل البدء هنا.

---

# 📄 Page 2: Dashboard (الصفحة الرئيسية)

## الخطوة 2.1: إنشاء الصفحة

1. **App Builder** → اضغط **Create Page**
2. اختر **Blank Page**
3. املأ البيانات:

| الحقل | القيمة |
|---|---|
| Page Number | `2` |
| Name | `Dashboard` |
| Page Mode | `Normal` |
| Breadcrumb | `- no breadcrumb -` |
| Navigation | `Use existing` |

4. اضغط **Create Page**

## الخطوة 2.2: إنشاء Region — KPI Cards

1. في Page Designer → اسحب **Region** جديد إلى **Body** (أو اضغط + في Content Body)
2. خصائص الـ Region:

| الحقل | القيمة |
|---|---|
| Title | `Task Summary` |
| Type | `Cards` |
| Template | `Standard` |

3. في **Source** → Type: `SQL Query`
4. الصق هذا الـ SQL:

```sql
SELECT 
    'Total Tasks' AS card_title,
    TO_CHAR(total_tasks) AS card_text,
    'fa-tasks' AS card_icon,
    'f?p=&APP_ID.:3:&SESSION.::NO:RIR::' AS card_link
FROM v_dashboard_stats
UNION ALL
SELECT 
    'In Progress',
    TO_CHAR(in_progress_count),
    'fa-spinner fa-anim-spin',
    'f?p=&APP_ID.:3:&SESSION.::NO:RIR:IR_STATUS:IN_PROGRESS'
FROM v_dashboard_stats
UNION ALL
SELECT 
    'On Hold',
    TO_CHAR(on_hold_count),
    'fa-pause-circle',
    'f?p=&APP_ID.:3:&SESSION.::NO:RIR:IR_STATUS:ON_HOLD'
FROM v_dashboard_stats
UNION ALL
SELECT 
    'Overdue',
    TO_CHAR(overdue_count),
    'fa-warning',
    'f?p=&APP_ID.:3:&SESSION.::NO:RIR:IR_IS_OVERDUE:Y'
FROM v_dashboard_stats
UNION ALL
SELECT 
    'Pending Approval',
    TO_CHAR(pending_approval_count),
    'fa-gavel',
    'f?p=&APP_ID.:12:&SESSION.'
FROM v_dashboard_stats
```

5. في **Attributes** → Cards:

| الحقل | القيمة |
|---|---|
| Card → Primary Key | `CARD_TITLE` |
| Title → Column | `CARD_TITLE` |
| Body → Column | `CARD_TEXT` |
| Icon → Column | `CARD_ICON` |
| Card → Link → Target | `CARD_LINK` |

## الخطوة 2.3: إنشاء Region — Tasks by Status (Pie Chart)

1. أضف Region جديد:

| الحقل | القيمة |
|---|---|
| Title | `Tasks by Status` |
| Type | `Chart` |
| Template | `Standard` |

2. في **Attributes**:

| الحقل | القيمة |
|---|---|
| Chart Type | `Pie` |

3. في **Series** (اضغط على Series الموجود أو أنشئ واحد):

| الحقل | القيمة |
|---|---|
| Name | `Status` |
| Source Type | `SQL Query` |

```sql
SELECT status_display AS label,
       COUNT(*) AS value,
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
       OR (:F_USER_ROLE = 'MANAGER' AND manager_id = TO_NUMBER(:F_USER_ID)))
GROUP BY status, status_display
ORDER BY DECODE(status,'CREATED',1,'IN_PROGRESS',2,'ON_HOLD',3,'COMPLETED',4,'CANCELLED',5)
```

| الحقل | القيمة |
|---|---|
| Label → Column | `LABEL` |
| Value → Column | `VALUE` |
| Color → Column | `COLOR` |

## الخطوة 2.4: إنشاء Region — Estimated vs Actual Hours (Bar Chart)

1. أضف Region جديد:

| الحقل | القيمة |
|---|---|
| Title | `Estimated vs Actual Hours` |
| Type | `Chart` |
| Chart Type | `Bar` |

2. أضف **Series 1** (Estimated):

| الحقل | القيمة |
|---|---|
| Name | `Estimated` |
| Color | `#4285f4` |

```sql
SELECT assigned_to_name AS label, SUM(estimated_hours) AS value
FROM v_tasks_full
WHERE (:F_USER_ROLE = 'ADMIN' OR assigned_to_id = TO_NUMBER(:F_USER_ID)
       OR (:F_USER_ROLE = 'MANAGER' AND manager_id = TO_NUMBER(:F_USER_ID)))
AND status != 'CANCELLED'
GROUP BY assigned_to_name ORDER BY 1
```

3. أضف **Series 2** (Actual):

| الحقل | القيمة |
|---|---|
| Name | `Actual` |
| Color | `#34a853` |

```sql
SELECT assigned_to_name AS label, SUM(actual_hours) AS value
FROM v_tasks_full
WHERE (:F_USER_ROLE = 'ADMIN' OR assigned_to_id = TO_NUMBER(:F_USER_ID)
       OR (:F_USER_ROLE = 'MANAGER' AND manager_id = TO_NUMBER(:F_USER_ID)))
AND status != 'CANCELLED'
GROUP BY assigned_to_name ORDER BY 1
```

## الخطوة 2.5: إنشاء Region — Overdue Tasks

1. أضف Region جديد:

| الحقل | القيمة |
|---|---|
| Title | `Overdue Tasks` |
| Type | `Classic Report` |

```sql
SELECT task_number, title, assigned_to_name, system_name, due_date,
       days_remaining, priority_display
FROM v_overdue_tasks
WHERE (:F_USER_ROLE = 'ADMIN' OR assigned_to_id = TO_NUMBER(:F_USER_ID)
       OR (:F_USER_ROLE = 'MANAGER' AND manager_id = TO_NUMBER(:F_USER_ID)))
ORDER BY due_date ASC
FETCH FIRST 10 ROWS ONLY
```

2. اضغط **Save** 💾

---

# 📄 Page 3: My Tasks (Interactive Report)

## الخطوة 3.1: إنشاء الصفحة

1. **Create Page** → **Interactive Report**
2. البيانات:

| الحقل | القيمة |
|---|---|
| Page Number | `3` |
| Name | `My Tasks` |
| Report Source → SQL Query | (انظر أدناه) |

```sql
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
    'status-' || LOWER(status) AS status_css,
    'priority-' || LOWER(priority) AS priority_css
FROM v_tasks_full
WHERE (
    :F_USER_ROLE = 'ADMIN'
    OR assigned_to_id = TO_NUMBER(:F_USER_ID)
    OR created_by_id = TO_NUMBER(:F_USER_ID)
    OR (:F_USER_ROLE = 'MANAGER' AND manager_id = TO_NUMBER(:F_USER_ID))
)
ORDER BY 
    CASE WHEN is_overdue = 'Y' THEN 0 ELSE 1 END,
    DECODE(priority,'CRITICAL',1,'HIGH',2,'MEDIUM',3,'LOW',4),
    due_date ASC
```

3. اضغط **Create Page**

## الخطوة 3.2: تعديل أعمدة الـ IR

1. افتح Page 3 في Page Designer
2. اضغط على **Column: STATUS_DISPLAY** → في خصائصه:

| الحقل | القيمة |
|---|---|
| Type | `Plain Text` |
| HTML Expression | `<span class="status-badge #STATUS_CSS#">#STATUS_DISPLAY#</span>` |

3. اضغط على **Column: PRIORITY_DISPLAY**:

| الحقل | القيمة |
|---|---|
| HTML Expression | `<span class="status-badge #PRIORITY_CSS#">#PRIORITY_DISPLAY#</span>` |

4. اجعل هذه الأعمدة **Hidden**: `TASK_ID`, `STATUS`, `PRIORITY`, `STATUS_CSS`, `PRIORITY_CSS`, `IS_OVERDUE`

5. اضغط على **Column: TASK_NUMBER** واجعله رابط:

| الحقل | القيمة |
|---|---|
| Type | `Link` |
| Target → Page | `5` |
| Set Items → Name | `P5_TASK_ID` |
| Set Items → Value | `#TASK_ID#` |

## الخطوة 3.3: إضافة زر إنشاء مهمة جديدة

1. في **Buttons** → أضف زر:

| الحقل | القيمة |
|---|---|
| Button Name | `CREATE_TASK` |
| Label | `+ New Task` |
| Position | `Right of Interactive Report Search Bar` |
| Action | `Redirect to Page in this Application` |
| Target → Page | `4` |
| Clear Cache | `4` |
| CSS Classes | `t-Button--hot` |

## الخطوة 3.4: Dynamic Action — تحديث التقرير بعد إغلاق Modal

1. أضف **Dynamic Action**:

| الحقل | القيمة |
|---|---|
| Name | `Refresh After Dialog Close` |
| Event | `Dialog Closed` |
| Selection Type | `Region` |
| Region | `My Tasks` |

2. True Action:

| الحقل | القيمة |
|---|---|
| Action | `Refresh` |
| Selection Type | `Region` |
| Region | `My Tasks` |

---

# 📄 Page 4: Task Form (Modal Dialog)

## الخطوة 4.1: إنشاء الصفحة

1. **Create Page** → **Form**
2. اختر **Form**
3. البيانات:

| الحقل | القيمة |
|---|---|
| Page Number | `4` |
| Name | `Task Form` |
| Page Mode | `Modal Dialog` |
| Data Source → Table | `TTS_TASKS` |
| Primary Key | `TASK_ID` |

4. اضغط **Create Page**

## الخطوة 4.2: تعديل الحقول (Page Items)

افتح Page 4 في Page Designer وعدّل الحقول:

### P4_TASK_ID → Hidden (لا تغيير)

### P4_TASK_NUMBER → Display Only
| الحقل | القيمة |
|---|---|
| Type | `Display Only` |
| Label | `Task Number` |
| Condition → Type | `Item is NOT NULL` |
| Condition → Item | `P4_TASK_ID` |

### P4_TITLE
| الحقل | القيمة |
|---|---|
| Type | `Text Field` |
| Label | `Title` |
| Value Required | `Yes` |
| Maximum Length | `250` |

### P4_DESCRIPTION
| الحقل | القيمة |
|---|---|
| Type | `Rich Text Editor` |
| Label | `Description` |

### P4_SYSTEM_ID
| الحقل | القيمة |
|---|---|
| Type | `Select List` |
| Label | `System` |
| LOV Type | `Shared Component` |
| LOV | `LOV_SYSTEMS` |
| Value Required | `Yes` |
| Display Null Value | `Yes` |
| Null Display Value | `-- Select System --` |

### P4_ASSIGNED_TO
| الحقل | القيمة |
|---|---|
| Type | `Select List` |
| Label | `Assigned To` |
| LOV | `LOV_TEAM_MEMBERS` |
| Value Required | `Yes` |
| Null Display Value | `-- Select User --` |

### P4_PRIORITY
| الحقل | القيمة |
|---|---|
| Type | `Select List` |
| Label | `Priority` |
| LOV | `LOV_PRIORITY` |
| Default Value | `MEDIUM` |
| Value Required | `Yes` |

### P4_START_DATE
| الحقل | القيمة |
|---|---|
| Type | `Date Picker` |
| Label | `Start Date` |
| Value Required | `Yes` |
| Default → Type | `PL/SQL Expression` |
| Default → Expression | `SYSDATE` |
| Format Mask | `DD-MON-YYYY` |

### P4_DUE_DATE
| الحقل | القيمة |
|---|---|
| Type | `Date Picker` |
| Label | `Due Date` |
| Value Required | `Yes` |
| Format Mask | `DD-MON-YYYY` |

### P4_ESTIMATED_HOURS
| الحقل | القيمة |
|---|---|
| Type | `Number Field` |
| Label | `Estimated Hours` |
| Value Required | `Yes` |

### احذف أو أخفِ هذه الحقول (التي لا نحتاجها في الفورم):
`P4_ACTUAL_HOURS`, `P4_STATUS`, `P4_COMPLETION_DATE`, `P4_APPROVAL_STATUS`, `P4_APPROVED_BY`, `P4_APPROVAL_NOTES`, `P4_CREATED_AT`, `P4_UPDATED_AT`

### P4_CREATED_BY → Hidden
| الحقل | القيمة |
|---|---|
| Type | `Hidden` |
| Default → Type | `Item` |
| Default → Item | `F_USER_ID` |

## الخطوة 4.3: إضافة Validation

1. أضف Validation جديد:

| الحقل | القيمة |
|---|---|
| Name | `Due Date After Start Date` |
| Type | `PL/SQL Expression` |
| PL/SQL Expression | `:P4_DUE_DATE >= :P4_START_DATE` |
| Error Message | `Due date must be on or after the start date.` |
| Associated Item | `P4_DUE_DATE` |

## الخطوة 4.4: تعديل عملية الحفظ (Process)

1. في **Processing** → ابحث عن الـ Process الافتراضي واستبدل المحتوى أو أضف Process جديد:

| الحقل | القيمة |
|---|---|
| Name | `Save Task` |
| Type | `PL/SQL Code` |
| When Button Pressed | `CREATE` أو `SAVE` |

```sql
DECLARE
    v_task_id NUMBER;
BEGIN
    IF :P4_TASK_ID IS NULL THEN
        v_task_id := tts_pkg_tasks.create_task(
            p_title           => :P4_TITLE,
            p_description     => :P4_DESCRIPTION,
            p_system_id       => TO_NUMBER(:P4_SYSTEM_ID),
            p_assigned_to     => TO_NUMBER(:P4_ASSIGNED_TO),
            p_created_by      => TO_NUMBER(:F_USER_ID),
            p_priority        => :P4_PRIORITY,
            p_start_date      => :P4_START_DATE,
            p_due_date        => :P4_DUE_DATE,
            p_estimated_hours => TO_NUMBER(:P4_ESTIMATED_HOURS)
        );
        :P4_TASK_ID := v_task_id;
    ELSE
        UPDATE tts_tasks SET
            title           = :P4_TITLE,
            description     = :P4_DESCRIPTION,
            system_id       = TO_NUMBER(:P4_SYSTEM_ID),
            assigned_to     = TO_NUMBER(:P4_ASSIGNED_TO),
            priority        = :P4_PRIORITY,
            start_date      = :P4_START_DATE,
            due_date        = :P4_DUE_DATE,
            estimated_hours = TO_NUMBER(:P4_ESTIMATED_HOURS)
        WHERE task_id = TO_NUMBER(:P4_TASK_ID);
    END IF;
END;
```

2. أضف **Close Dialog** Process بعد Save Task.

---

# 📄 Page 5: Task Details & Collaboration Hub

## الخطوة 5.1: إنشاء الصفحة

1. **Create Page** → **Blank Page**

| الحقل | القيمة |
|---|---|
| Page Number | `5` |
| Name | `Task Details` |

2. أضف Page Item:

| الحقل | القيمة |
|---|---|
| Name | `P5_TASK_ID` |
| Type | `Hidden` |

## الخطوة 5.2: إضافة Region — Task Header

1. أضف Region:

| الحقل | القيمة |
|---|---|
| Title | `Task Info` |
| Type | `Classic Report` (أو Static Content) |

```sql
SELECT task_number, title, description, system_name,
       status_display, priority_display, assigned_to_name,
       created_by_name, start_date, due_date,
       estimated_hours, actual_hours, hours_remaining,
       completion_pct, days_remaining, is_overdue,
       approval_display, approval_notes, approved_by_name,
       tags_list, completion_date
FROM v_tasks_full
WHERE task_id = TO_NUMBER(:P5_TASK_ID)
```

## الخطوة 5.3: إضافة Region — Action Buttons

1. أضف Region:

| الحقل | القيمة |
|---|---|
| Title | `Actions` |
| Type | `Static Content` |
| Template | `Buttons Container` |

2. أضف الأزرار (كل زر بشرط عرض مختلف):

### زر Start Working
| الحقل | القيمة |
|---|---|
| Name | `BTN_START` |
| Label | `▶ Start Working` |
| CSS Classes | `t-Button--success` |
| Condition → Type | `PL/SQL Expression` |
| Condition → Expression | `(SELECT status FROM tts_tasks WHERE task_id = :P5_TASK_ID) = 'CREATED'` |

### زر Complete
| الحقل | القيمة |
|---|---|
| Name | `BTN_COMPLETE` |
| Label | `✓ Mark Complete` |
| CSS Classes | `t-Button--success` |
| Condition → Expression | `(SELECT status FROM tts_tasks WHERE task_id = :P5_TASK_ID) = 'IN_PROGRESS'` |

### زر Submit for Approval
| الحقل | القيمة |
|---|---|
| Name | `BTN_SUBMIT_APPROVAL` |
| Label | `📤 Submit for Approval` |
| CSS Classes | `t-Button--hot` |
| Condition → Expression | `(SELECT status FROM tts_tasks WHERE task_id = :P5_TASK_ID) = 'COMPLETED' AND (SELECT approval_status FROM tts_tasks WHERE task_id = :P5_TASK_ID) IN ('NOT_SUBMITTED','REJECTED')` |

3. لكل زر أضف **Process**:

#### Process: Change Status (لأزرار Start/Hold/Resume/Complete/Cancel)
```sql
BEGIN
    tts_pkg_tasks.update_task_status(
        p_task_id    => TO_NUMBER(:P5_TASK_ID),
        p_new_status => :REQUEST,  -- button name = status value
        p_user_id    => TO_NUMBER(:F_USER_ID)
    );
    COMMIT;
END;
```

> [!TIP]
> يمكنك ضبط Request Value لكل زر ليكون اسم الحالة المطلوبة (مثل `IN_PROGRESS`, `ON_HOLD`, `COMPLETED`)

#### Process: Submit Approval
```sql
BEGIN
    tts_pkg_tasks.submit_for_approval(
        p_task_id => TO_NUMBER(:P5_TASK_ID),
        p_user_id => TO_NUMBER(:F_USER_ID)
    );
    COMMIT;
END;
```

## الخطوة 5.4: إضافة Region — Comments

1. أضف Region:

| الحقل | القيمة |
|---|---|
| Title | `Comments` |
| Type | `Classic Report` |

```sql
SELECT c.comment_id, c.comment_text, u.full_name AS commenter,
       APEX_UTIL.GET_SINCE(c.created_at) AS time_ago
FROM tts_comments c
JOIN tts_users u ON u.user_id = c.user_id
WHERE c.task_id = TO_NUMBER(:P5_TASK_ID)
ORDER BY c.created_at DESC
```

2. أضف Page Item لكتابة تعليق:

| الحقل | القيمة |
|---|---|
| Name | `P5_NEW_COMMENT` |
| Type | `Textarea` |
| Label | `Add Comment` |
| Rows | `3` |

3. أضف زر:

| الحقل | القيمة |
|---|---|
| Name | `BTN_ADD_COMMENT` |
| Label | `Post Comment` |

4. أضف Process:

```sql
BEGIN
    tts_pkg_tasks.add_comment(
        p_task_id      => TO_NUMBER(:P5_TASK_ID),
        p_user_id      => TO_NUMBER(:F_USER_ID),
        p_comment_text => :P5_NEW_COMMENT
    );
    :P5_NEW_COMMENT := NULL;
    COMMIT;
END;
```

## الخطوة 5.5: إضافة Region — History Timeline

1. أضف Region:

| الحقل | القيمة |
|---|---|
| Title | `History` |
| Type | `Classic Report` |

```sql
SELECT h.change_type, h.old_value, h.new_value,
       u.full_name AS changed_by,
       APEX_UTIL.GET_SINCE(h.changed_at) AS time_ago,
       CASE h.change_type
           WHEN 'CREATED'    THEN 'fa-plus-circle u-color-1'
           WHEN 'STATUS'     THEN 'fa-exchange u-color-5'
           WHEN 'ASSIGNMENT' THEN 'fa-user-plus u-color-4'
           WHEN 'APPROVAL'   THEN 'fa-gavel u-color-15'
           ELSE 'fa-pencil u-color-9'
       END AS icon_class
FROM tts_task_history h
JOIN tts_users u ON u.user_id = h.changed_by
WHERE h.task_id = TO_NUMBER(:P5_TASK_ID)
ORDER BY h.changed_at DESC
```

---

# 📄 Page 6: Kanban Board (لوحة المهام التفاعلية بالسحب والإفلات)

سنقوم ببناء لوحة Kanban تفاعلية ممتازة واحترافية بنسبة 100% باستخدام **أربعة أعمدة متجاورة (Side-by-Side Cards Regions)**، مع تفعيل خاصية السحب والإفلات (Drag & Drop) بينها باستخدام مكتبة jQuery UI المدمجة في APEX.

هذه الطريقة تعطي مظهراً رائعاً وثباتاً ممتازاً وتعمل على جميع إصدارات وإعدادات APEX دون الحاجة لخصائص مخفية.

---

### الخطوة 6.1: إنشاء الصفحة والحاوية الرئيسية
1. **Create Page** → **Blank Page**
   - **Page Number**: `6`
   - **Page Name**: `Kanban Board`
   - **Page Mode**: `Normal`
2. في منطقة **Content Body**، أضف منطقة رئيسية (Parent Region):
   - **Title**: `Kanban Board Container`
   - **Type**: `Static Content`
   - **Template**: `Blank Column` (لإخفاء الحواف والتركيز على الأعمدة)

---

### الخطوة 6.2: إنشاء الأعمدة الأربعة (Sub-Regions)
تحت الـ Parent Region، قم بإنشاء **4 مناطق فرعية (Sub-Regions)** من نوع **Cards** لتكون الأعمدة المتجاورة:

#### 1. عمود: Created (جديد)
- **Title**: `Created`
- **Type**: `Cards`
- **Static ID**: `col_created` (مهم جداً!)
- **CSS Classes**: `tts-kanban-col`
- **Layout**: Column `1` | Column Span `3` (Start New Row: **On**)
- **SQL Query Source**:
```sql
SELECT task_id, task_number, title, assigned_to_name, priority_display, priority, due_date, days_remaining, 'priority-' || LOWER(priority) AS card_css
FROM v_tasks_full
WHERE status = 'CREATED' AND status != 'CANCELLED'
AND (:F_USER_ROLE = 'ADMIN' OR assigned_to_id = TO_NUMBER(:F_USER_ID) OR created_by_id = TO_NUMBER(:F_USER_ID) OR (:F_USER_ROLE = 'MANAGER' AND manager_id = TO_NUMBER(:F_USER_ID)))
ORDER BY DECODE(priority,'CRITICAL',1,'HIGH',2,'MEDIUM',3,'LOW',4), due_date
```

#### 2. عمود: In Progress (قيد التنفيذ)
- **Title**: `In Progress`
- **Type**: `Cards`
- **Static ID**: `col_in_progress`
- **CSS Classes**: `tts-kanban-col`
- **Layout**: Column `4` | Column Span `3` (Start New Row: **Off**)
- **SQL Query Source**:
```sql
SELECT task_id, task_number, title, assigned_to_name, priority_display, priority, due_date, days_remaining, 'priority-' || LOWER(priority) AS card_css
FROM v_tasks_full
WHERE status = 'IN_PROGRESS' AND status != 'CANCELLED'
AND (:F_USER_ROLE = 'ADMIN' OR assigned_to_id = TO_NUMBER(:F_USER_ID) OR created_by_id = TO_NUMBER(:F_USER_ID) OR (:F_USER_ROLE = 'MANAGER' AND manager_id = TO_NUMBER(:F_USER_ID)))
ORDER BY DECODE(priority,'CRITICAL',1,'HIGH',2,'MEDIUM',3,'LOW',4), due_date
```

#### 3. عمود: On Hold (معلقة)
- **Title**: `On Hold`
- **Type**: `Cards`
- **Static ID**: `col_on_hold`
- **CSS Classes**: `tts-kanban-col`
- **Layout**: Column `7` | Column Span `3` (Start New Row: **Off**)
- **SQL Query Source**:
```sql
SELECT task_id, task_number, title, assigned_to_name, priority_display, priority, due_date, days_remaining, 'priority-' || LOWER(priority) AS card_css
FROM v_tasks_full
WHERE status = 'ON_HOLD' AND status != 'CANCELLED'
AND (:F_USER_ROLE = 'ADMIN' OR assigned_to_id = TO_NUMBER(:F_USER_ID) OR created_by_id = TO_NUMBER(:F_USER_ID) OR (:F_USER_ROLE = 'MANAGER' AND manager_id = TO_NUMBER(:F_USER_ID)))
ORDER BY DECODE(priority,'CRITICAL',1,'HIGH',2,'MEDIUM',3,'LOW',4), due_date
```

#### 4. عمود: Completed (مكتملة)
- **Title**: `Completed`
- **Type**: `Cards`
- **Static ID**: `col_completed`
- **CSS Classes**: `tts-kanban-col`
- **Layout**: Column `10` | Column Span `3` (Start New Row: **Off**)
- **SQL Query Source**:
```sql
SELECT task_id, task_number, title, assigned_to_name, priority_display, priority, due_date, days_remaining, 'priority-' || LOWER(priority) AS card_css
FROM v_tasks_full
WHERE status = 'COMPLETED' AND status != 'CANCELLED'
AND (:F_USER_ROLE = 'ADMIN' OR assigned_to_id = TO_NUMBER(:F_USER_ID) OR created_by_id = TO_NUMBER(:F_USER_ID) OR (:F_USER_ROLE = 'MANAGER' AND manager_id = TO_NUMBER(:F_USER_ID)))
ORDER BY DECODE(priority,'CRITICAL',1,'HIGH',2,'MEDIUM',3,'LOW',4), due_date
```

---

### الخطوة 6.3: ضبط خصائص الكروت لكل عمود
كرر الإعدادات التالية في تبويب **Attributes** لكل منطقة Cards من الأعمدة الأربعة:

1. **Primary Key Column** (قسم Source):
   - اختر: `TASK_ID`
2. **Layout** (قسم Appearance):
   - **Layout**: `Grid`
   - **Grid Columns**: `1` (مهم جداً لتظهر الكروت متراصة رأسياً كقائمة العمود)
3. **Title** (قسم Card):
   - قم بتفعيل **Advanced Formatting** (اجعلها **ON**).
   - في حقل **HTML Expression** الذي يظهر، الصق:
     ```html
     <span class="tts-card-title" data-id="&TASK_ID.">&TITLE.</span>
     ```
4. **Subtitle** (قسم Card):
   - Column: `TASK_NUMBER`
5. **Body** (قسم Card):
   - Column: `ASSIGNED_TO_NAME`
6. **Secondary Body** (قسم Card):
   - قم بتفعيل **Advanced Formatting** (اجعلها **ON**).
   - في حقل **HTML Expression** الذي يظهر، الصق:
     ```html
     <div class="card-meta">
         <span class="status-badge &CARD_CSS.">&PRIORITY_DISPLAY.</span>
         <span class="due-date">Due: &DUE_DATE.</span>
     </div>
     ```
7. **CSS Classes** (قسم Card):
   - الصق: `tts-task-card &CARD_CSS.`

---

### الخطوة 6.4: إعداد الانتقال لصفحة التفاصيل (Card Link)
لجعل الكارت بالكامل قابلاً للنقر ويفتح صفحة تفاصيل المهمة:
1. في القائمة اليسرى (شجرة المكونات)، اذهب لكل عمود Cards، وستجد تحته مجلد فرعي اسمه **Actions**.
2. اضغط بالزر الأيمن على **Actions** واختر **Create Action**.
3. في اللوحة اليمنى للـ Action الجديد:
   - **Type**: اختر **Full Card**.
   - **Target**: اضغط على الرابط، وحدد التوجيه لصفحة `5` مع تمرير الـ `P5_TASK_ID` بقيمة `&TASK_ID.`.

---

### الخطوة 6.5: تفعيل السحب والإفلات التفاعلي (الحل النهائي الخالي من الأخطاء)

لحل مشكلة توقف السحب تماماً بعد التحديث (Refresh) دون الحاجة لتعقيد الـ Dynamic Actions، سنستخدم ميزة الاستماع لانتهاء أي طلب **AJAX** يتم في الصفحة (`ajaxComplete`). هذا الحل هو الأكثر استقراراً وعملية بنسبة 100% لأن تحديث الكروت يعتمد بالكامل على طلبات AJAX:

#### 1. تعريف دالة السحب والإفلات (Global Function):
* افتح **خصائص الصفحة 6** (اضغط على اسم الصفحة "Page 6: Kanban Board" في أعلى شجرة المكونات اليسرى).
* في اللوحة اليمنى، اذهب إلى قسم **JavaScript**.
* في حقل **Function and Global Variable Declaration** (الإعلان عن الدوال المتغيرة العامة)، الصق الكود التالي بالكامل:

```javascript
function initKanbanSortable() {
    var sortableSelector = "#col_created .a-CardView-items, " +
                           "#col_in_progress .a-CardView-items, " +
                           "#col_on_hold .a-CardView-items, " +
                           "#col_completed .a-CardView-items";
    
    // إزالة السحب القديم أولاً لمنع التكرار (تدمير الـ instance القديم)
    try {
        $(sortableSelector).sortable("destroy");
    } catch (e) {}

    // تفعيل السحب والإفلات التفاعلي
    $(sortableSelector).sortable({
        connectWith: sortableSelector,
        placeholder: "ui-state-highlight-placeholder",
        cursor: "move",
        opacity: 0.85,
        appendTo: "body",
        helper: function(e, item) {
            // عمل نسخة من الكارت للحفاظ على عرضه وأبعاده وتجنب اختفائه خلف الأعمدة
            var clone = item.clone();
            clone.css({
                "width": item.width() + "px",
                "z-index": 9999,
                "pointer-events": "none"
            });
            return clone;
        },
        receive: function(event, ui) {
            // 1. الحصول على ID المهمة المسحوبة من الكارت
            var taskId = ui.item.find(".tts-card-title").attr("data-id") || 
                         ui.item.find("[data-task-id]").data("task-id") || 
                         ui.item.attr("data-id");
            
            // 2. تحديد العمود الجديد الذي سقطت فيه المهمة لمعرفة الحالة الجديدة
            var targetColId = ui.item.closest(".tts-kanban-col").attr("id") || 
                              ui.item.closest("[id^=col_]").attr("id");
            
            var newStatus = 'CREATED';
            if (targetColId === 'col_in_progress') newStatus = 'IN_PROGRESS';
            else if (targetColId === 'col_on_hold') newStatus = 'ON_HOLD';
            else if (targetColId === 'col_completed') newStatus = 'COMPLETED';

            // 3. استدعاء Ajax Callback لتحديث قاعدة البيانات
            apex.server.process("KANBAN_STATUS_CHANGE", {
                x01: taskId,
                x02: newStatus
            }, {
                success: function(data) {
                    apex.message.showPageSuccess("Task status updated!");
                    // تحديث الأعمدة الأربعة لإظهار البيانات متناسقة
                    apex.region("col_created").refresh();
                    apex.region("col_in_progress").refresh();
                    apex.region("col_on_hold").refresh();
                    apex.region("col_completed").refresh();
                },
                error: function(jqXHR, textStatus, errorThrown) {
                    apex.message.showErrors([{
                        type: "error",
                        location: "page",
                        message: "Failed to update status: " + jqXHR.responseText
                    }]);
                    // إعادة الكارت لمكانه الأصلي في حالة الفشل
                    apex.region("col_created").refresh();
                    apex.region("col_in_progress").refresh();
                    apex.region("col_on_hold").refresh();
                    apex.region("col_completed").refresh();
                }
            });
        }
    }).disableSelection();
}
```

#### 2. ربط عملية التحديث وإعادة التشغيل التلقائي:
* في نفس شاشة خصائص الصفحة، ابحث عن حقل **Execute when Page Loads** (تشغيل عند تحميل الصفحة).
* الصق الكود التالي بالكامل (والذي يستمع لطلبات AJAX ويعيد تهيئة السحب بعد اكتمالها بـ 250ms):

```javascript
// 1. تشغيل السحب عند تحميل الصفحة لأول مرة تلقائياً
initKanbanSortable();

// 2. الاستماع لأي عملية Refresh (AJAX) وإعادة تشغيل السحب بأمان بعد انتهائها بالكامل
$(document).ajaxComplete(function(event, xhr, settings) {
    if (window.kanbanTimeout) {
        clearTimeout(window.kanbanTimeout);
    }
    
    // انتظار 350 مللي ثانية للتأكد من استقرار الـ DOM بالكامل بعد استلام البيانات
    window.kanbanTimeout = setTimeout(function() {
        initKanbanSortable();
    }, 350);
});
```

* > [!IMPORTANT]
  > إذا كنت قد قمت بإنشاء أي **Dynamic Action** باسم `Re-init Kanban Sortable` في شجرة المكونات اليسرى، يرجى **حذفه بالكامل (Delete)** لمنع تداخل العمليات وتعارضها. كود الـ AJAX أعلاه سيتولى المهمة بالكامل بمفرده!


### الخطوة 4: إنشاء عملية التحديث في الخلفية (Ajax Callback Process)
1. في Page Designer → اذهب إلى الـ **Processing** tab (أيقونة الترس الدائري في اليسار).
2. اضغط بالزر الأيمن على **Ajax Callback** → **Create Ajax Callback Process**.
3. خصائص الـ Process:
   - **Name**: `KANBAN_STATUS_CHANGE`
   - **Type**: `PL/SQL Code`
   - **PL/SQL Code**:
```sql
BEGIN
    -- x01: TASK_ID, x02: NEW_STATUS
    tts_pkg_tasks.update_task_status(
        p_task_id    => TO_NUMBER(APEX_APPLICATION.G_X01),
        p_new_status => APEX_APPLICATION.G_X02,
        p_user_id    => TO_NUMBER(:F_USER_ID)
    );
    
    -- إرجاع استجابة نجاح بصيغة JSON
    APEX_JSON.OPEN_OBJECT;
    APEX_JSON.WRITE('status', 'success');
    APEX_JSON.CLOSE_OBJECT;
EXCEPTION
    WHEN OTHERS THEN
        -- إرجاع رسالة الخطأ لتظهر للمستخدم في المتصفح
        HTP.P(SQLERRM);
END;
```

---

## 🎨 تنسيق الـ CSS المخصص لـ Kanban Board (أضفه في Page CSS Inline)
```css
/* ==========================================
   TTS Premium Kanban Board Styles
   ========================================== */

/* 1. تنسيق الحاوية الرئيسية والأعمدة */
.tts-kanban-col {
    background: #f8fafc !important; /* لون رمادي مزرق خفيف وجذاب */
    border: 1px solid #e2e8f0 !important;
    border-radius: 12px !important;
    padding: 16px !important;
    min-height: 650px !important;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.02) !important;
    transition: background-color 0.2s ease;
}

/* تمييز العمود النشط أثناء سحب كارت فوقه */
.ui-sortable-hover {
    background-color: #edf2f7 !important;
}

/* 2. تنسيق عناوين الأعمدة بشكل احترافي */
.tts-kanban-col .t-Region-header {
    border-bottom: 2px solid #e2e8f0 !important;
    margin-bottom: 16px !important;
    padding-bottom: 8px !important;
    background: transparent !important;
}

.tts-kanban-col .t-Region-title {
    font-size: 16px !important;
    font-weight: 700 !important;
    letter-spacing: 0.5px !important;
    display: flex !important;
    align-items: center !important;
    gap: 8px !important;
}

/* ألوان مخصصة لكل حالة في العناوين مع حدود سفلية ملونة */
#col_created { border-top: 4px solid #3b82f6 !important; }
#col_created .t-Region-title { color: #1e3a8a !important; }

#col_in_progress { border-top: 4px solid #eab308 !important; }
#col_in_progress .t-Region-title { color: #713f12 !important; }

#col_on_hold { border-top: 4px solid #ef4444 !important; }
#col_on_hold .t-Region-title { color: #7f1d1d !important; }

#col_completed { border-top: 4px solid #10b981 !important; }
#col_completed .t-Region-title { color: #064e3b !important; }

/* 3. التنسيق الفاخر والمدمج للكروت الفردية */
.tts-task-card.a-CardView {
    background: #ffffff !important;
    border: 1px solid #e2e8f0 !important;
    border-radius: 10px !important;
    padding: 12px !important;
    margin-bottom: 12px !important;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.04), 0 2px 4px -1px rgba(0, 0, 0, 0.02) !important;
    transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1) !important;
    cursor: grab !important;
    position: relative !important;
    overflow: hidden !important;
    min-height: 0 !important; /* إلغاء الارتفاع الزائد */
    display: block !important; /* جعل العناصر تتراص عمودياً بشكل طبيعي */
}

.tts-task-card .a-CardView-header,
.tts-task-card .a-CardView-body {
    margin: 0 !important;
    padding: 0 !important;
    display: block !important;
}

.tts-task-card:hover {
    transform: translateY(-4px) !important;
    box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05) !important;
    border-color: #cbd5e1 !important;
}

.tts-task-card:active {
    cursor: grabbing !important;
}

/* تأثير السحب الطافي للكارت الجاري سحبه */
.ui-sortable-helper {
    transform: rotate(2deg) scale(1.02) !important;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.15), 0 10px 10px -5px rgba(0, 0, 0, 0.04) !important;
    opacity: 0.95 !important;
    cursor: grabbing !important;
}

/* 4. تنسيق أشرطة الأولويات على جانب الكارت */
.tts-task-card::before {
    content: '' !important;
    position: absolute !important;
    left: 0 !important;
    top: 0 !important;
    bottom: 0 !important;
    width: 6px !important;
    background-color: #cbd5e1 !important; /* اللون الافتراضي */
    z-index: 10 !important;
}
.tts-task-card.priority-critical::before { background-color: #b91c1c !important; }
.tts-task-card.priority-high::before { background-color: #ef4444 !important; }
.tts-task-card.priority-medium::before { background-color: #f59e0b !important; }
.tts-task-card.priority-low::before { background-color: #10b981 !important; }

/* 5. تنسيق المحتوى الداخلي للكارت */
/* كود المهمة (Task Number) كحبة دواء رمادية */
.tts-task-card .a-CardView-subTitle {
    background: #f1f5f9 !important;
    color: #475569 !important;
    padding: 2px 8px !important;
    border-radius: 20px !important;
    font-size: 11px !important;
    font-weight: 700 !important;
    display: inline-block !important;
    margin-bottom: 8px !important;
    margin-top: 4px !important;
    border: 1px solid #e2e8f0 !important;
}

/* عنوان المهمة الأساسي */
.tts-task-card .tts-card-title {
    font-size: 14px !important;
    font-weight: 700 !important;
    color: #0f172a !important;
    line-height: 1.4 !important;
    margin-bottom: 6px !important;
    display: block !important;
}

/* اسم الموظف */
.tts-task-card .a-CardView-mainContent {
    font-size: 12px !important;
    color: #64748b !important;
    display: flex !important;
    align-items: center !important;
    gap: 6px !important;
    margin-bottom: 8px !important;
}

.tts-task-card .a-CardView-mainContent::before {
    content: '👤 ' !important; /* رمز تعبيري بديل لعدم تحميل الفونت */
    font-size: 12px !important;
}

/* 6. شارات الأولوية وتاريخ الاستحقاق في الأسفل */
.tts-task-card .card-meta {
    display: flex !important;
    justify-content: space-between !important;
    align-items: center !important;
    border-top: 1px solid #f1f5f9 !important;
    padding-top: 8px !important;
    margin-top: 8px !important;
    flex-wrap: nowrap !important;
}

/* شارات الأولوية الملونة بنعومة */
.tts-task-card .status-badge {
    padding: 2px 8px !important;
    border-radius: 4px !important;
    font-size: 11px !important;
    font-weight: 700 !important;
    text-transform: uppercase !important;
    letter-spacing: 0.3px !important;
    white-space: nowrap !important; /* منع التفاف الكلمات نهائياً */
}
.tts-task-card .status-badge.priority-critical { background: #fee2e2 !important; color: #991b1b !important; }
.tts-task-card .status-badge.priority-high { background: #fee2e2 !important; color: #c2410c !important; }
.tts-task-card .status-badge.priority-medium { background: #fef3c7 !important; color: #92400e !important; }
.tts-task-card .status-badge.priority-low { background: #d1fae5 !important; color: #065f46 !important; }

/* تاريخ الاستحقاق */
.tts-task-card .due-date {
    font-size: 11px !important;
    color: #64748b !important;
    font-weight: 600 !important;
    display: flex !important;
    align-items: center !important;
    gap: 4px !important;
    white-space: nowrap !important;
}

.tts-task-card .due-date::before {
    content: '📅 ' !important; /* رمز تعبيري بديل للساعة */
    font-size: 11px !important;
}

/* 7. تنسيق المساحة الفارغة الذكية عند سحب كارت (Placeholder) */
.ui-state-highlight-placeholder {
    border: 2px dashed #3b82f6 !important;
    background-color: rgba(59, 130, 246, 0.03) !important;
    border-radius: 10px !important;
    height: 90px !important;
    margin-bottom: 12px !important;
    visibility: visible !important;
    position: relative !important;
}

.ui-state-highlight-placeholder::after {
    content: 'Drop Here';
    position: absolute;
    left: 50%;
    top: 50%;
    transform: translate(-50%, -50%);
    color: #3b82f6;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 1px;
}

/* منع إخفاء القائمة عند خلو العمود من المهام للسماح بالإفلات */
.tts-kanban-col .a-TMV-w-scroll {
    display: block !important;
}
.tts-kanban-col .a-CardView-items {
    min-height: 500px !important;
    display: block !important;
}
.tts-kanban-col .a-GV-noDataMsg {
    display: none !important; /* إخفاء رسالة 'No data found' الافتراضية لمنع تداخلها */
}
```

---

---

# 📄 Pages 7, 13, 14: Admin Interactive Grids

هذه صفحات متشابهة — كلها Interactive Grid على جداول مباشرة.

## Page 7: Systems Management

1. **Create Page** → **Interactive Grid**

| الحقل | القيمة |
|---|---|
| Page Number | `7` |
| Name | `Systems Management` |
| Table | `TTS_SYSTEMS` |
| Editable | `Yes` |
| Authorization | `IS_ADMIN` |

## Page 13: Departments

1. **Create Page** → **Interactive Grid**

| الحقل | القيمة |
|---|---|
| Page Number | `13` |
| Name | `Departments` |
| Table | `TTS_DEPARTMENTS` |
| Editable | `Yes` |
| Authorization | `IS_ADMIN` |

2. عمود `DEPT_HEAD_ID` → اجعله **Select List** مع LOV: `LOV_USERS_ACTIVE`

## Page 14: Lookups Management

1. **Create Page** → **Interactive Grid**

| الحقل | القيمة |
|---|---|
| Page Number | `14` |
| Name | `Lookups Management` |
| Table | `TTS_LOOKUPS` |
| Editable | `Yes` |
| Authorization | `IS_ADMIN` |

---

# 📄 Page 8: Users Management

هذه الصفحة مقسمة إلى جزئين رئيسيين: 
1. **صفحة عرض وإدارة المستخدمين (Page 8):** عبارة عن تقرير تفاعلي (Interactive Report).
2. **صفحة نموذج إضافة وتعديل مستخدم (Page 15):** عبارة عن نموذج منبثق (Modal Dialog) يتم استدعاؤه عند الإضافة أو التعديل.

---

## الخطوة 8.1: إعداد صفحة التقرير التفاعلي (Page 8)

1. **أنشئ صفحة جديدة** من نوع **Interactive Report**:
   * **Page Number**: `8`
   * **Name**: `Users Management`
   * **Authorization**: `IS_ADMIN` (حماية الصفحة للمدير فقط)
   * **SQL Query Source**:
```sql
SELECT u.user_id, u.username, u.email, u.full_name,
       u.role, d.dept_name, m.full_name AS manager_name,
       u.is_active, u.last_login, u.created_at
FROM tts_users u
LEFT JOIN tts_departments d ON d.dept_id = u.dept_id
LEFT JOIN tts_users m ON m.user_id = u.manager_id
ORDER BY u.full_name
```

2. **إنشاء زر الإضافة (Add User):**
   * في شجرة المكونات اليسرى، اضغط بالزر الأيمن على منطقة الـ Breadcrumb أو Region Header واختر **Create Button**.
   * **Button Name**: `ADD_USER`
   * **Label**: `Add User`
   * **Button Position**: `Right of Title` (أو Hot)
   * **Action**: اختر **Redirect to Page in this Application**.
   * **Target**: اضغط على الرابط واضبطه كالتالي:
     * **Page**: `15` (صفحة النموذج المنبثق التي سننشئها بالخطوة التالية)
     * **Clear Cache**: اكتب `15`

---

## الخطوة 8.2: إنشاء صفحة النموذج المنبثق (Page 15: User Form)

سنقوم بإنشاء صفحة منفصلة من نوع **Modal Dialog** لتعمل كـ Form منبثق لإضافة أو تعديل المستخدم:

1. اضغط على **Create Page** في شريط الأدوات العلوي.
2. اختر **Blank Page** (صفحة فارغة):
   * **Page Number**: `15`
   * **Name**: `User Form`
   * **Page Mode**: اختر **Modal Dialog** (صفحة حوارية منبثقة)
   * **Authorization**: `IS_ADMIN`
3. في صفحة `15` الجديدة، اضغط بالزر الأيمن على **Content Body** واختر **Create Region**:
   * **Title**: `User Details`
   * **Type**: `Form`
   * **Source -> Table Name**: `TTS_USERS`
   * **Source -> Primary Key Column**: `USER_ID`

4. **إنشاء الحقول داخل ريجين الـ Form (Page Items):**
   قم بإنشاء الحقول التالية تحت ريجين `User Details`:

   * **P15_USER_ID** (معرف المستخدم):
     * **Type**: `Hidden`
   * **P15_USERNAME** (اسم المستخدم):
     * **Type**: `Text Field`
     * **Value Required**: `True`
     * **Read Only -> Type**: اختر `Item is NOT NULL` -> وحدد Item: `P15_USER_ID` (هذا يمنع تعديل اسم المستخدم بعد إنشائه).
   * **P15_PASSWORD** (كلمة المرور):
     * **Type**: `Password`
     * **Value Required**: `True` (مطلوب فقط عند الإنشاء)
     * **Server-side Condition -> Type**: اختر `Item is NULL` -> وحدد Item: `P15_USER_ID` (هذا يجعل حقل كلمة المرور يظهر فقط عند إضافة مستخدم جديد، ويختفي تماماً عند تعديل بيانات مستخدم موجود).
   * **P15_EMAIL** (البريد الإلكتروني):
     * **Type**: `Text Field`
     * **Value Required**: `True`
   * **P15_FULL_NAME** (الاسم بالكامل):
     * **Type**: `Text Field`
     * **Value Required**: `True`
   * **P15_ROLE** (الصلاحية):
     * **Type**: `Select List`
     * **List of Values -> Type**: `Shared Component`
     * **List of Values**: `LOV_USER_ROLES` (أو LOV ثابتة بقيم: ADMIN, MANAGER, EMPLOYEE)
     * **Value Required**: `True`
   * **P15_DEPT_ID** (القسم):
     * **Type**: `Select List`
     * **List of Values -> Type**: `Shared Component`
     * **List of Values**: `LOV_DEPARTMENTS`
   * **P15_MANAGER_ID** (المدير المباشر):
     * **Type**: `Select List`
     * **List of Values -> Type**: `Shared Component`
     * **List of Values**: `LOV_USERS_ACTIVE`
   * **P15_IS_ACTIVE** (حالة الحساب نشط أم لا):
     * **Type**: `Switch` (أو Select List بقيم Y و N)
     * **Server-side Condition -> Type**: اختر `Item is NOT NULL` -> وحدد Item: `P15_USER_ID` (يظهر فقط عند التعديل).

5. **إنشاء الأزرار (Buttons) في الصفحة 15:**
   * زر **CANCEL** (إلغاء):
     * **Position**: `Close`
     * **Action**: `Redirect to Page/URL` (أو سلوك إغلاق النافذة)
   * زر **SUBMIT** (حفظ / إنشاء):
     * **Button Name**: `SAVE` (أو CREATE)
     * **Label**: `Save`
     * **Position**: `Change` (أو Region Positions)
     * **Action**: `Submit Page`

---

## الخطوة 8.3: إعداد عمليات الحفظ والإغلاق (Processing Page 15)

اذهب إلى تبويب المعالجة **Processing** (أيقونة الترس في القائمة اليسرى لصفحة 15):

1. **إنشاء عملية حفظ البيانات (Process User):**
   * اضغط بالزر الأيمن على **Processing** واختر **Create Process**.
   * **Name**: `Process_User`
   * **Type**: `PL/SQL Code`
   * **PL/SQL Code**:
```sql
BEGIN
    IF :P15_USER_ID IS NULL THEN
        -- 1. إنشاء مستخدم جديد وتشفير كلمة مروره عبر الباكج المخصصة
        tts_pkg_admin.create_user(
            p_username   => :P15_USERNAME,
            p_password   => :P15_PASSWORD,
            p_email      => :P15_EMAIL,
            p_full_name  => :P15_FULL_NAME,
            p_role       => :P15_ROLE,
            p_dept_id    => TO_NUMBER(:P15_DEPT_ID),
            p_manager_id => TO_NUMBER(:P15_MANAGER_ID)
        );
    ELSE
        -- 2. تحديث بيانات مستخدم موجود بالفعل
        UPDATE tts_users
        SET    email      = :P15_EMAIL,
               full_name  = :P15_FULL_NAME,
               role       = :P15_ROLE,
               dept_id    = TO_NUMBER(:P15_DEPT_ID),
               manager_id = TO_NUMBER(:P15_MANAGER_ID),
               is_active  = :P15_IS_ACTIVE
        WHERE  user_id    = TO_NUMBER(:P15_USER_ID);
        
        COMMIT;
    END IF;
END;
```

2. **إنشاء عملية إغلاق النموذج المنبثق (Close Dialog):**
   * اضغط بالزر الأيمن على **Processing** → **Create Process**.
   * **Name**: `Close_Dialog`
   * **Type**: اختر **Close Dialog** (هذه العملية مدمجة في APEX وتقوم بإغلاق الـ Modal وتحديث بيانات الصفحة الأب تلقائياً).
   * **Execution Sequence**: تأكد أن ترتيبها **بعد** عملية الـ `Process_User`.

---

## الخطوة 8.4: ربط رابط التعديل (Edit Link) في الصفحة 8

لكي يفتح التقرير التفاعلي في صفحة 8 نافذة التعديل (صفحة 15) عند الضغط على مستخدم معين:

1. ارجع إلى **Page 8: Users Management**.
2. في شجرة المكونات اليسرى، اختر منطقة التقرير التفاعلي **Users Management**.
3. في اللوحة اليمنى، اذهب إلى تبويب **Attributes** (بجوار تبويب Region).
4. انزل لقسم **Link Column** واضبط الخصائص كالتالي:
   * **Link Column**: اختر **Link to Custom Target**.
   * **Link Icon**: اختر أيقونة التعديل القياسية (مثلاً `fa-pencil` أو `pencil-square`).
   * **Target**: اضغط على الرابط واضبطه كالتالي:
     * **Page**: `15`
     * **Set Items**:
       * Item Name: `P15_USER_ID`
       * Value: `#USER_ID#` (هذا يمرر الـ ID الخاص بالمستخدم المختار إلى النافذة المنبثقة)
     * **Clear Cache**: `15`
5. اضغط **Save** وشغل الصفحة 8.

الآن، عند الضغط على زر **Add User** ستفتح نافذة منبثقة نظيفة لإدخال بيانات مستخدم جديد بكلمة مرور. وعند الضغط على أيقونة التعديل بجوار أي مستخدم، ستفتح نفس النافذة محملة ببياناته لتعديلها مع إخفاء حقل كلمة المرور وإظهار حقل تفعيل الحساب!

---

---

# 📄 Page 9: My Profile (Modal)

## الخطوة 9.1: إنشاء الصفحة

1. **Create Page** → **Blank Page**

| الحقل | القيمة |
|---|---|
| Page Number | `9` |
| Name | `My Profile` |
| Page Mode | `Modal Dialog` |

2. أضف حقول: `P9_FULL_NAME`, `P9_EMAIL`, `P9_OLD_PASSWORD`, `P9_NEW_PASSWORD`, `P9_CONFIRM_PASS`

3. Before Header Process (لجلب البيانات):

```sql
BEGIN
    SELECT full_name, email
    INTO :P9_FULL_NAME, :P9_EMAIL
    FROM tts_users
    WHERE user_id = TO_NUMBER(:F_USER_ID);
END;
```

4. Validation: تأكد أن `P9_NEW_PASSWORD = P9_CONFIRM_PASS`

5. Process — Update Profile:

```sql
BEGIN
    UPDATE tts_users SET full_name = :P9_FULL_NAME, email = :P9_EMAIL
    WHERE user_id = TO_NUMBER(:F_USER_ID);
    APEX_UTIL.SET_SESSION_STATE('F_FULL_NAME', :P9_FULL_NAME);
    COMMIT;
END;
```

6. Process — Change Password (شرط: `P9_OLD_PASSWORD IS NOT NULL`):

```sql
BEGIN
    tts_pkg_security.change_password(
        p_user_id      => TO_NUMBER(:F_USER_ID),
        p_old_password => :P9_OLD_PASSWORD,
        p_new_password => :P9_NEW_PASSWORD
    );
    COMMIT;
END;
```

---

# 📄 Page 10: Team Overview (Manager/Admin)

1. **Create Page** → **Blank Page**

| الحقل | القيمة |
|---|---|
| Page Number | `10` |
| Name | `Team Overview` |
| Authorization | `IS_MANAGER_OR_ADMIN` |

2. أضف Region — Cards (Team Workload):

```sql
SELECT full_name, username, dept_name, total_tasks,
       in_progress_count, completed_count, overdue_count,
       total_estimated_hours, total_actual_hours
FROM v_user_workload
WHERE (:F_USER_ROLE = 'ADMIN' OR manager_id = TO_NUMBER(:F_USER_ID))
AND total_tasks > 0
ORDER BY overdue_count DESC
```

3. أضف Region — IR (Team Tasks):

```sql
SELECT * FROM v_tasks_full
WHERE (:F_USER_ROLE = 'ADMIN' OR manager_id = TO_NUMBER(:F_USER_ID))
ORDER BY CASE WHEN is_overdue = 'Y' THEN 0 ELSE 1 END, due_date
```

---

# 📄 Page 11: Daily Time Log (Interactive Grid)

1. **Create Page** → **Interactive Grid**

| الحقل | القيمة |
|---|---|
| Page Number | `11` |
| Name | `Daily Time Log` |

```sql
SELECT dl.log_id, dl.task_id,
       t.task_number, t.title AS task_title,
       dl.log_date, dl.hours_spent, dl.notes
FROM tts_daily_log dl
JOIN tts_tasks t ON t.task_id = dl.task_id
WHERE dl.user_id = TO_NUMBER(:F_USER_ID)
ORDER BY dl.log_date DESC
```

2. عمود `TASK_ID` → **Select List** مع LOV:

```sql
SELECT task_number || ' - ' || title d, task_id r
FROM tts_tasks
WHERE assigned_to = TO_NUMBER(:F_USER_ID)
AND status IN ('CREATED', 'IN_PROGRESS', 'ON_HOLD')
ORDER BY task_number
```

3. عمود `LOG_DATE` → Date Picker، Default: `SYSDATE`
4. عمود `HOURS_SPENT` → Number Field

> [!NOTE]
> الـ Trigger `trg_daily_log_calc` سيحسب `actual_hours` تلقائياً عند الحفظ.

---

# 📄 Page 12: Pending Approvals (Manager/Admin)

1. **Create Page** → **Interactive Report**

| الحقل | القيمة |
|---|---|
| Page Number | `12` |
| Name | `Pending Approvals` |
| Authorization | `IS_MANAGER_OR_ADMIN` |

```sql
SELECT task_id, task_number, title, system_name,
       assigned_to_name, priority_display, due_date,
       estimated_hours, actual_hours, completion_date, completion_pct
FROM v_tasks_full
WHERE approval_status = 'PENDING'
AND (:F_USER_ROLE = 'ADMIN' OR manager_id = TO_NUMBER(:F_USER_ID))
ORDER BY completion_date ASC
```

2. أضف أزرار Approve و Reject على كل صف (Link Column أو Row Action).

3. Process — Quick Approve (Ajax Callback):

```sql
BEGIN
    tts_pkg_tasks.process_approval(
        p_task_id    => TO_NUMBER(APEX_APPLICATION.G_X01),
        p_decision   => 'APPROVED',
        p_manager_id => TO_NUMBER(:F_USER_ID),
        p_notes      => 'Approved'
    );
    COMMIT;
END;
```

---

# ✅ الآن التطبيق كامل!

## اضبط الصفحة الرئيسية:
1. **Shared Components** → **Application Definition**
2. **Home Page** → `2` (Dashboard)

## جرّب التطبيق:
1. سجّل دخول بـ `admin` / `Admin@123`
2. أنشئ قسم ← أنشئ مدير ← أنشئ موظفين
3. أنشئ مهام ← تتبع الحالة ← سجّل ساعات ← اطلب اعتماد
4. سجّل دخول كمدير ← تابع الفريق ← اعتمد المهام

> [!TIP]
> ارجع لملف [apex_pages_guide.sql](file:///c:/Users/develop4/Documents/Tasks%20system/apex_pages_guide.sql) للاطلاع على تفاصيل إضافية مثل Dynamic Actions والـ Ajax Callbacks.
