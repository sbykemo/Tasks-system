# 🏗 دليل بناء تطبيق APEX — خطوة بخطوة
## Daily Tasks Tracking System (TTS) | Oracle APEX 24.2.17

> [!IMPORTANT]
> **شرط مسبق:** يجب أن تكون قد شغّلت `install.sql` على قاعدة البيانات قبل البدء.
> تأكد من ظهور رسالة النجاح وأن `test_suite.sql` يعمل بنجاح.

---

# المرحلة 1: إنشاء التطبيق

## الخطوة 1.1: إنشاء تطبيق جديد

1. افتح **APEX Builder** → اضغط **App Builder**
2. اضغط **Create** (زر أزرق أعلى اليمين)
3. اختر **New Application**
4. املأ البيانات التالية:

| الحقل | القيمة |
|---|---|
| Name | `Daily Tasks Tracking System` |
| Application ID | اتركه تلقائي أو اختر رقم مثل `100` |
| Appearance → Theme Style | `Vita – Dark` (أو أي Style تفضله) |
| Pages | احذف كل الصفحات الافتراضية ما عدا `Home` |

5. في قسم **Features** في الأسفل:
   - ✅ Install Progressive Web App
   - ❌ أزل Access Control (سنبنيه يدوياً)
   - ❌ أزل Activity Reporting

6. اضغط **Create Application**

> [!NOTE]
> سجّل رقم الـ Application ID (مثلاً `100`) — ستحتاجه لاحقاً.

---

# المرحلة 2: إعداد Authentication Scheme

## الخطوة 2.1: إنشاء Custom Authentication

1. اذهب إلى **Shared Components** (أيقونة الترس أعلى يمين الصفحة)
2. في قسم **Security** → اضغط **Authentication Schemes**
3. اضغط **Create**
4. اختر **Based on a pre-configured scheme from the gallery** → اضغط **Next**
5. اختر **Custom** → اضغط **Next**
6. املأ البيانات:

| الحقل | القيمة |
|---|---|
| Name | `TTS Custom Authentication` |
| Scheme Type | `Custom` |

7. في قسم **Settings**:

| الحقل | القيمة |
|---|---|
| Authentication Function Name | `tts_pkg_security.authenticate_user` |

8. في قسم **Login Page** → اتركه على الإعدادات الافتراضية

9. اضغط **Create Authentication Scheme**

## الخطوة 2.2: جعله الـ Scheme الفعّال

1. في قائمة الـ Authentication Schemes، ستجد الـ Scheme الجديد
2. إذا لم يكن Current بالفعل: اضغط عليه → اضغط **Make Current Scheme**

## الخطوة 2.3: إنشاء Application Process لتعبئة بيانات الجلسة (Post-Auth)

> [!IMPORTANT]
> هذه خطوة أساسية — بدونها لن تعمل الصلاحيات ولا الـ Application Items.

1. **Shared Components** → قسم **Application Logic** → **Application Processes**
2. اضغط **Create**
3. املأ البيانات:

| الحقل | القيمة |
|---|---|
| Name | `Set User Session Info` |
| Sequence | `10` |
| Process Point | `After Authentication` |
| Type | `PL/SQL Code` |

4. في حقل **PL/SQL Code** — الصق الكود التالي:

```sql
tts_pkg_security.post_auth(:APP_USER);
```

5. في قسم **Condition**:

| الحقل | القيمة |
|---|---|
| Condition Type | `No Condition` |

6. اضغط **Create Process**

> [!NOTE]
> هذا الـ Process يعمل مرة واحدة بعد كل تسجيل دخول ناجح.
> يقوم بملء `F_USER_ID`, `F_USER_ROLE`, `F_FULL_NAME`, `F_DEPT_ID` في الـ Session State.

---

# المرحلة 3: إنشاء Application Items

## الخطوة 3.1: إنشاء الـ Session Items

1. **Shared Components** → قسم **Application Logic** → **Application Items**
2. اضغط **Create** لكل عنصر من العناصر التالية:

### Item 1: F_USER_ID
| الحقل | القيمة |
|---|---|
| Name | `F_USER_ID` |
| Scope | `Application` |
| Session State Protection | `Restricted - May not be set from browser` |

اضغط **Create Application Item**

### Item 2: F_USER_ROLE
| الحقل | القيمة |
|---|---|
| Name | `F_USER_ROLE` |
| Scope | `Application` |
| Session State Protection | `Restricted - May not be set from browser` |

### Item 3: F_FULL_NAME
| الحقل | القيمة |
|---|---|
| Name | `F_FULL_NAME` |
| Scope | `Application` |
| Session State Protection | `Restricted - May not be set from browser` |

### Item 4: F_DEPT_ID
| الحقل | القيمة |
|---|---|
| Name | `F_DEPT_ID` |
| Scope | `Application` |
| Session State Protection | `Restricted - May not be set from browser` |

> [!TIP]
> هذه العناصر يتم ملؤها تلقائياً بعد تسجيل الدخول عبر `tts_pkg_security.post_auth` الذي ضبطناه في الـ Authentication Scheme.

---

# المرحلة 4: إنشاء Authorization Schemes

## الخطوة 4.1: إنشاء صلاحيات الأدوار

1. **Shared Components** → قسم **Security** → **Authorization Schemes**
2. اضغط **Create** لكل Scheme:

### Scheme 1: IS_ADMIN
| الحقل | القيمة |
|---|---|
| Name | `IS_ADMIN` |
| Scheme Type | `PL/SQL Function Returning Boolean` |
| PL/SQL Function Body | (انظر أدناه) |
| Error Message | `Access restricted to Administrators only.` |

```sql
RETURN NVL(:F_USER_ROLE, 'NONE') = 'ADMIN';
```

اضغط **Create Authorization Scheme**

### Scheme 2: IS_MANAGER_OR_ADMIN
| الحقل | القيمة |
|---|---|
| Name | `IS_MANAGER_OR_ADMIN` |
| Scheme Type | `PL/SQL Function Returning Boolean` |
| PL/SQL Function Body | (انظر أدناه) |
| Error Message | `Access restricted to Managers and Administrators.` |

```sql
RETURN NVL(:F_USER_ROLE, 'NONE') IN ('ADMIN', 'MANAGER');
```

### Scheme 3: IS_AUTHENTICATED
| الحقل | القيمة |
|---|---|
| Name | `IS_AUTHENTICATED` |
| Scheme Type | `PL/SQL Function Returning Boolean` |
| PL/SQL Function Body | (انظر أدناه) |
| Error Message | `You must be logged in to access this page.` |

```sql
RETURN :F_USER_ROLE IS NOT NULL;
```

---

# المرحلة 5: إنشاء Lists of Values (LOVs)

## الخطوة 5.1: إنشاء LOVs المشتركة

1. **Shared Components** → قسم **Other Components** → **List of Values**
2. اضغط **Create** لكل LOV:

---

### LOV 1: LOV_SYSTEMS

| الحقل | القيمة |
|---|---|
| Name | `LOV_SYSTEMS` |
| Type | `Dynamic` |

SQL Query:
```sql
SELECT system_name d, system_id r
FROM tts_systems
WHERE is_active = 'Y'
ORDER BY system_name
```

اضغط **Create List of Values**

---

### LOV 2: LOV_USERS_ACTIVE

| الحقل | القيمة |
|---|---|
| Name | `LOV_USERS_ACTIVE` |
| Type | `Dynamic` |

```sql
SELECT full_name || ' (' || username || ')' d, user_id r
FROM tts_users
WHERE is_active = 'Y'
ORDER BY full_name
```

---

### LOV 3: LOV_TEAM_MEMBERS

| الحقل | القيمة |
|---|---|
| Name | `LOV_TEAM_MEMBERS` |
| Type | `Dynamic` |

```sql
SELECT full_name || ' (' || username || ')' d, user_id r
FROM tts_users
WHERE is_active = 'Y'
AND (
    :F_USER_ROLE = 'ADMIN'
    OR (
        :F_USER_ROLE = 'MANAGER'
        AND (manager_id = TO_NUMBER(:F_USER_ID) OR user_id = TO_NUMBER(:F_USER_ID))
    )
    OR (
        :F_USER_ROLE = 'EMPLOYEE'
        AND user_id = TO_NUMBER(:F_USER_ID)
    )
)
ORDER BY full_name
```

---

### LOV 4: LOV_TASK_STATUS

| الحقل | القيمة |
|---|---|
| Name | `LOV_TASK_STATUS` |
| Type | `Dynamic` |

```sql
SELECT display_name d, lookup_code r
FROM tts_lookups
WHERE lookup_type = 'TASK_STATUS'
AND is_active = 'Y'
ORDER BY display_order
```

---

### LOV 5: LOV_PRIORITY

| الحقل | القيمة |
|---|---|
| Name | `LOV_PRIORITY` |
| Type | `Dynamic` |

```sql
SELECT display_name d, lookup_code r
FROM tts_lookups
WHERE lookup_type = 'PRIORITY'
AND is_active = 'Y'
ORDER BY display_order
```

---

### LOV 6: LOV_APPROVAL_STATUS

| الحقل | القيمة |
|---|---|
| Name | `LOV_APPROVAL_STATUS` |
| Type | `Dynamic` |

```sql
SELECT display_name d, lookup_code r
FROM tts_lookups
WHERE lookup_type = 'APPROVAL_STATUS'
AND is_active = 'Y'
ORDER BY display_order
```

---

### LOV 7: LOV_DEPARTMENTS

| الحقل | القيمة |
|---|---|
| Name | `LOV_DEPARTMENTS` |
| Type | `Dynamic` |

```sql
SELECT dept_name d, dept_id r
FROM tts_departments
WHERE is_active = 'Y'
ORDER BY dept_name
```

---

### LOV 8: LOV_TAGS

| الحقل | القيمة |
|---|---|
| Name | `LOV_TAGS` |
| Type | `Dynamic` |

```sql
SELECT tag_name d, tag_id r
FROM tts_tags
ORDER BY tag_name
```

---

### LOV 9: LOV_USER_ROLES (Static)

| الحقل | القيمة |
|---|---|
| Name | `LOV_USER_ROLES` |
| Type | `Static` |

Static Values:

| Display Value | Return Value |
|---|---|
| `Administrator` | `ADMIN` |
| `Manager` | `MANAGER` |
| `Employee` | `EMPLOYEE` |

---

# المرحلة 6: إعداد Navigation Menu

## الخطوة 6.1: تعديل قائمة التنقل

1. **Shared Components** → قسم **Navigation** → **Navigation Menu**
2. اضغط على **Desktop Navigation Menu** (القائمة الافتراضية)
3. احذف أي عناصر افتراضية موجودة (مثل Home)
4. أضف العناصر التالية بالترتيب — لكل عنصر اضغط **Create Entry**:

### Entry 1: Dashboard
| الحقل | القيمة |
|---|---|
| Sequence | `10` |
| Image/Class | `fa-home` |
| List Entry Label | `Dashboard` |
| Target → Page | `2` |
| Authorization Scheme | `IS_AUTHENTICATED` |

### Entry 2: My Tasks
| الحقل | القيمة |
|---|---|
| Sequence | `20` |
| Image/Class | `fa-tasks` |
| List Entry Label | `My Tasks` |
| Target → Page | `3` |
| Authorization Scheme | `IS_AUTHENTICATED` |

### Entry 3: Kanban Board
| الحقل | القيمة |
|---|---|
| Sequence | `30` |
| Image/Class | `fa-columns` |
| List Entry Label | `Kanban Board` |
| Target → Page | `6` |
| Authorization Scheme | `IS_AUTHENTICATED` |

### Entry 4: Daily Time Log
| الحقل | القيمة |
|---|---|
| Sequence | `40` |
| Image/Class | `fa-clock-o` |
| List Entry Label | `Daily Time Log` |
| Target → Page | `11` |
| Authorization Scheme | `IS_AUTHENTICATED` |

### Entry 5: Team Overview
| الحقل | القيمة |
|---|---|
| Sequence | `50` |
| Image/Class | `fa-users` |
| List Entry Label | `Team Overview` |
| Target → Page | `10` |
| Authorization Scheme | `IS_MANAGER_OR_ADMIN` |

### Entry 6: Pending Approvals
| الحقل | القيمة |
|---|---|
| Sequence | `60` |
| Image/Class | `fa-check-square-o` |
| List Entry Label | `Pending Approvals` |
| Target → Page | `12` |
| Authorization Scheme | `IS_MANAGER_OR_ADMIN` |

### Entry 7: Administration (Parent — قائمة فرعية)
| الحقل | القيمة |
|---|---|
| Sequence | `70` |
| Image/Class | `fa-gear` |
| List Entry Label | `Administration` |
| Target → URL | `#` |
| Authorization Scheme | `IS_ADMIN` |

### Entry 7.1: Users Management (Sub-item تحت Administration)
| الحقل | القيمة |
|---|---|
| Sequence | `71` |
| Parent List Entry | `Administration` |
| Image/Class | `fa-user` |
| List Entry Label | `Users Management` |
| Target → Page | `8` |
| Authorization Scheme | `IS_ADMIN` |

### Entry 7.2: Departments (Sub-item)
| الحقل | القيمة |
|---|---|
| Sequence | `72` |
| Parent List Entry | `Administration` |
| Image/Class | `fa-building` |
| List Entry Label | `Departments` |
| Target → Page | `13` |
| Authorization Scheme | `IS_ADMIN` |

### Entry 7.3: Systems Management (Sub-item)
| الحقل | القيمة |
|---|---|
| Sequence | `73` |
| Parent List Entry | `Administration` |
| Image/Class | `fa-server` |
| List Entry Label | `Systems Management` |
| Target → Page | `7` |
| Authorization Scheme | `IS_ADMIN` |

### Entry 7.4: Lookups Management (Sub-item)
| الحقل | القيمة |
|---|---|
| Sequence | `74` |
| Parent List Entry | `Administration` |
| Image/Class | `fa-list` |
| List Entry Label | `Lookups Management` |
| Target → Page | `14` |
| Authorization Scheme | `IS_ADMIN` |

### Entry 8: My Profile
| الحقل | القيمة |
|---|---|
| Sequence | `80` |
| Image/Class | `fa-user-circle` |
| List Entry Label | `My Profile` |
| Target → Page | `9` |
| Authorization Scheme | `IS_AUTHENTICATED` |

---

# المرحلة 7: إضافة Custom CSS

## الخطوة 7.1: إضافة الـ Theme CSS

1. **Shared Components** → قسم **User Interface** → **User Interface Attributes**
2. في تبويب **CSS** → حقل **Inline CSS**
3. انسخ والصق الكود التالي بالكامل:

```css
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
.priority-low       { background: #e8f5e9; color: #2e7d32; }
.priority-medium    { background: #fff3e0; color: #ef6c00; }
.priority-high      { background: #fce4ec; color: #c62828; }
.priority-critical  { background: #c62828; color: #ffffff; }
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
.overdue-row { background-color: #fff5f5 !important; }
.overdue-text { color: var(--tts-danger); font-weight: 600; }
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
```

4. اضغط **Apply Changes**

---

# ✅ نقطة فحص — الأساسات جاهزة!

في هذه المرحلة، يجب أن يكون لديك:
- ✅ تطبيق APEX جديد
- ✅ Authentication Scheme مخصص
- ✅ 4 Application Items
- ✅ 3 Authorization Schemes
- ✅ 9 LOVs مشتركة
- ✅ Navigation Menu كامل (12 عنصر)
- ✅ Custom CSS Theme

**جرّب الآن:** شغّل التطبيق وسجّل الدخول بـ `admin` / `Admin@123`

> [!WARNING]
> ستظهر أخطاء لأن الصفحات لم تُنشأ بعد. هذا طبيعي.
> الخطوة التالية: بناء الصفحات واحدة تلو الأخرى.

---

> **تابع في الجزء التالي:** بناء صفحة الـ Dashboard (Page 2)
