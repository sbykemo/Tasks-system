# Daily Tasks Tracking System (TTS)
### Oracle APEX 24.2.17 | Full-Stack Application

A comprehensive Daily Tasks Tracking System built on **Oracle APEX 24.2.17** that enables employees to log daily work, managers to supervise and approve tasks, and administrators to manage the entire lifecycle.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🔐 **Custom Authentication** | Secure SHA-256 + Salt password hashing with role-based access |
| 👥 **3 User Roles** | Employee, Manager, Admin — each with specific permissions |
| 📋 **Task Lifecycle** | Created → In Progress → On Hold → Completed → Approved/Rejected |
| ✅ **Approval Workflow** | Manager approval required for task completion |
| 📊 **Dashboard** | KPI cards, charts (status breakdown, est vs actual hours, workload) |
| 📌 **Kanban Board** | Drag-and-drop task management by status |
| ⏱ **Daily Time Log** | Track hours per task per day with auto-calculation |
| 💬 **Comments** | Task discussion threads with notifications |
| 📎 **Attachments** | Upload files/images stored as BLOBs |
| 🔔 **Notifications** | In-app + email notifications for assignments, status changes, approvals |
| 📝 **Audit Trail** | Complete history of all task changes |
| 🏷 **Tags** | Flexible tagging system for categorization |

---

## 🗄 Database Objects

| Object Type | Count | Details |
|---|---|---|
| Tables | 12 | Users, Departments, Systems, Tasks, Daily Log, Comments, Attachments, History, Notifications, Tags, Task Tags, Lookups |
| Views | 5 | Tasks Full, User Workload, Overdue Tasks, Dashboard Stats, Manager Team |
| PL/SQL Packages | 4 | Security, Notifications, Tasks, Admin |
| Triggers | 6 | Auto timestamps, task numbering, hours recalculation |
| Indexes | 17 | Performance indexes on all query columns |

---

## 🚀 Installation

### Prerequisites
```sql
-- Grant required privileges to your schema user
GRANT EXECUTE ON DBMS_CRYPTO TO your_schema_user;
```

### Quick Install
```sql
-- Connect to your Oracle database as the schema user
-- Navigate to the scripts directory, then run:
SQL> @install.sql
```

### Step-by-Step Install
```sql
SQL> @schema.sql          -- Step 1: Tables, Sequences, Indexes
SQL> @seed_data.sql       -- Step 2: Lookup values, Default Admin
SQL> @views.sql           -- Step 3: Database Views
SQL> @triggers.sql        -- Step 4: Triggers
SQL> @packages.sql        -- Step 5: PL/SQL Packages
SQL> @test_suite.sql      -- Step 6: Validate installation
```

### Default Admin Login
| Field | Value |
|---|---|
| Username | `admin` |
| Password | `Admin@123` |

> ⚠️ **Change the default admin password immediately after first login!**

---

## 📁 File Structure

```
Tasks-system/
├── install.sql                  # Master installation script
├── schema.sql                   # Tables, Sequences, Indexes, Constraints
├── seed_data.sql                # Lookup data, Sample data, Default Admin
├── views.sql                    # 5 Database Views
├── triggers.sql                 # 6 Database Triggers
├── packages.sql                 # 4 PL/SQL Packages (Spec + Body)
├── test_suite.sql               # Automated Test Suite (45+ tests)
├── apex_shared_components.sql   # APEX LOVs, Auth, Authorization, CSS
├── apex_pages_guide.sql         # Page-by-page APEX build guide
└── README.md                    # This file
```

---

## 🏗 APEX Application Setup

After installing the database backend:

1. **Create Application** → Name: `Daily Tasks Tracking System`, Alias: `TTS`
2. **Authentication** → Custom PL/SQL: `tts_pkg_security.authenticate_user`
3. **Post-Auth Process** → `tts_pkg_security.post_auth(:APP_USER)`
4. **Application Items** → `F_USER_ID`, `F_USER_ROLE`, `F_FULL_NAME`, `F_DEPT_ID`
5. **Build Pages** → Follow `apex_pages_guide.sql` for all 15 pages

See `apex_shared_components.sql` for LOV queries, CSS, and navigation menu setup.

---

## 📄 APEX Pages

| Page | Title | Access |
|---|---|---|
| 0 | Global Page (Notification Bell) | All |
| 1 | Login | Public |
| 2 | Dashboard | All |
| 3 | My Tasks | All |
| 4 | Task Form (Modal) | All |
| 5 | Task Details & Collaboration | All |
| 6 | Kanban Board | All |
| 7 | Systems Management | Admin |
| 8 | Users Management | Admin |
| 9 | My Profile | All |
| 10 | Team Overview | Manager/Admin |
| 11 | Daily Time Log | All |
| 12 | Pending Approvals | Manager/Admin |
| 13 | Departments | Admin |
| 14 | Lookups Management | Admin |

---

## 🧪 Testing

Run the automated test suite:
```sql
SQL> @test_suite.sql
```

The test suite validates:
- Password hashing & authentication
- User & department management
- Task creation & lifecycle
- Status transition rules
- Daily time logging
- Approval workflow
- Comments & notifications
- Authorization checks
- Database views
- Password change functionality

---

## 📋 License

This project is open source and available for use in your organization.

---

## 👨‍💻 Author

Built with Oracle APEX 24.2.17 expertise.
