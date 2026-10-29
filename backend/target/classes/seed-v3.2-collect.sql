-- ============================================================
-- seed-v3.2-collect.sql  HIS→数据中台 采集链路（2026-10-25）
-- 1) PROD.CIS_Model：HIS 贴源区（模拟 IRIS HIS 落地到本地 PG，
--    真实环境替换为 IRIS 数据源 JDBC 直采，适配已就绪）
-- 2) dam_metadata.collect_task / dam_metadata.collect_task_log：采集任务与运行记录
-- 3) 4 条采集任务 + PowerJob 全量采集调度任务
-- 幂等：可重复执行
-- ============================================================
SET client_encoding = 'UTF8';

-- ---------------- 1. HIS 贴源区 ----------------
CREATE SCHEMA IF NOT EXISTS "PROD";
CREATE SCHEMA IF NOT EXISTS "PROD.CIS_Model";

CREATE TABLE IF NOT EXISTS "PROD.CIS_Model"."PA_PatMas" (
    PatID        varchar(32) PRIMARY KEY,
    Name         varchar(64),
    Sex          varchar(8),
    DateOfBirth  date,
    IDNo         varchar(32),
    MaritalStatus varchar(8),
    Occupation   varchar(64),
    RegDate      timestamp
);
CREATE TABLE IF NOT EXISTS "PROD.CIS_Model"."PA_Adm" (
    AdmID       varchar(32) PRIMARY KEY,
    PatID       varchar(32),
    AdmType     varchar(8),
    DeptID      varchar(16),
    DeptName    varchar(64),
    DoctorID    varchar(32),
    DoctorName  varchar(64),
    AdmDate     timestamp,
    DischDate   timestamp,
    AdmStatus   varchar(8),
    TotalCost   numeric(12,2)
);
CREATE TABLE IF NOT EXISTS "PROD.CIS_Model"."OE_Order" (
    OrdID      varchar(32) PRIMARY KEY,
    AdmID      varchar(32),
    PatID      varchar(32),
    OrdType    varchar(8),
    ArcimCode  varchar(32),
    ArcimDesc  varchar(200),
    Spec       varchar(100),
    Dosage     varchar(100),
    Frequency  varchar(32),
    Route      varchar(32),
    DoctorName varchar(64),
    OrdDate    timestamp,
    OrdStatus  varchar(16)
);
CREATE TABLE IF NOT EXISTS "PROD.CIS_Model"."OE_OrdExec" (
    ExecID     varchar(32) PRIMARY KEY,
    OrdID      varchar(32),
    ExecDate   timestamp,
    NurseID    varchar(64),
    DeptID     varchar(16),
    ExecStatus varchar(8),
    Note       varchar(200)
);

-- 演示数据（存在则不重复灌）
INSERT INTO "PROD.CIS_Model"."PA_PatMas"
SELECT 'HIS' || lpad(g::text, 6, '0'),
       '患者' || g,
       (ARRAY['M','F'])[1 + (g % 2)],
       date '1952-03-01' + ((g * 791) % 24000),
       '110101' || lpad(((g * 917) % 999999999)::text, 9, '0'),
       (ARRAY['1','2','3','9'])[1 + (g % 4)],
       (ARRAY['工人','农民','教师','职员','退休','学生'])[1 + (g % 6)],
       now() - ((g % 90) || ' days')::interval
FROM generate_series(1, 80) g
WHERE NOT EXISTS (SELECT 1 FROM "PROD.CIS_Model"."PA_PatMas" WHERE PatID = 'HIS000001');

INSERT INTO "PROD.CIS_Model"."PA_Adm"
SELECT        'A' || lpad(g::text, 6, '0'),
       'HIS' || lpad((1 + (g % 80))::text, 6, '0'),
       CASE WHEN g % 4 = 0 THEN '2' ELSE '1' END,
       (ARRAY['DEP01','DEP02','DEP03','DEP04','DEP05'])[1 + (g % 5)],
       (ARRAY['心血管内科','呼吸内科','消化内科','骨科','妇产科'])[1 + (g % 5)],
       'D' || lpad((1 + (g % 20))::text, 3, '0'),
       '医师' || (1 + (g % 20)),
       now() - ((g % 60) || ' days')::interval,
       CASE WHEN g % 4 = 0 THEN now() - (((g % 60) - 3) || ' days')::interval END,
       CASE WHEN g % 4 = 0 THEN 'CLOSED' ELSE 'OPEN' END,
       round(((g * 137) % 8000 + 120)::numeric, 2)
FROM generate_series(1, 240) g
WHERE NOT EXISTS (SELECT 1 FROM "PROD.CIS_Model"."PA_Adm" WHERE AdmID = 'A000001');

INSERT INTO "PROD.CIS_Model"."OE_Order"
SELECT 'O' || lpad(g::text, 6, '0'),
       'A' || lpad((1 + (g % 240))::text, 6, '0'),
       'HIS' || lpad((1 + (g % 80))::text, 6, '0'),
       (ARRAY['1','2','3','4'])[1 + (g % 4)],
       'ARC' || lpad((1 + (g % 60))::text, 4, '0'),
       (ARRAY['0.9%氯化钠注射液','阿莫西林胶囊','血常规检验','胸部CT平扫','心电图检查','腹部彩超'])[1 + (g % 6)],
       (ARRAY['250ml:2.25g','0.25g*24粒','','','',''])[1 + (g % 6)],
       (ARRAY['250ml','','','','',''])[1 + (g % 6)],
       (ARRAY['qd','bid','tid','q8h'])[1 + (g % 4)],
       (ARRAY['IV','PO','IM'])[1 + (g % 3)],
       '医师' || (1 + (g % 20)),
       now() - ((g % 55) || ' days')::interval,
       CASE WHEN g % 7 = 0 THEN 'CANCELLED' ELSE 'ACTIVE' END
FROM generate_series(1, 720) g
WHERE NOT EXISTS (SELECT 1 FROM "PROD.CIS_Model"."OE_Order" WHERE OrdID = 'O000001');

INSERT INTO "PROD.CIS_Model"."OE_OrdExec"
SELECT 'E' || lpad(g::text, 6, '0'),
       'O' || lpad(g::text, 6, '0'),
       now() - ((g % 55) || ' days')::interval + interval '2 hours',
       '护士' || (1 + (g % 15)),
       (ARRAY['DEP01','DEP02','DEP03','DEP04','DEP05'])[1 + (g % 5)],
       CASE WHEN g % 11 = 0 THEN 'SKIP' ELSE 'DONE' END,
       NULL
FROM generate_series(1, 720) g
WHERE NOT EXISTS (SELECT 1 FROM "PROD.CIS_Model"."OE_OrdExec" WHERE ExecID = 'E000001');

-- biz_order_exec 的 order_no 允许多次执行记录且现有演示数据有重号，该任务用 DELETE_INSERT 模式幂等（见 collect_task.load_mode）
-- HIS 采集写入的目标列若窄于源值会溢出：CANCELLED 9 字符 > 原列 varchar(8)
ALTER TABLE hospital_demo.biz_clinical_order ALTER COLUMN order_status TYPE varchar(16);

-- ---------------- 2. 采集任务表 ----------------
CREATE TABLE IF NOT EXISTS dam_metadata.collect_task (
    id             bigserial PRIMARY KEY,
    task_code      varchar(64) NOT NULL UNIQUE,
    task_name      varchar(200) NOT NULL,
    source_schema  varchar(64) NOT NULL,
    source_table   varchar(64) NOT NULL,
    target_schema  varchar(64) NOT NULL,
    target_table   varchar(64) NOT NULL,
    column_mapping jsonb NOT NULL,          -- [{"src":"PatID","tgt":"patient_id"},...]
    uk_column      varchar(64),             -- 目标唯一键（UPSERT 用）
    load_mode      varchar(20) NOT NULL DEFAULT 'UPSERT',  -- UPSERT / FULL_TRUNCATE
    where_clause   text,
    enabled        boolean NOT NULL DEFAULT true,
    last_run_at    timestamp,
    last_rows      bigint,
    total_rows     bigint NOT NULL DEFAULT 0,
    last_status    varchar(16),
    last_message   text,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.collect_task IS 'HIS→数据中台采集任务表—— 源表到目标表的抽取映射与运行统计';

-- 跨库任务：源数据源 id（data_source）。非空 = 从该源 JDBC 抽数（IRIS 等）；空 = 同库 INSERT..SELECT
ALTER TABLE dam_metadata.collect_task ADD COLUMN IF NOT EXISTS source_ds_id bigint;
COMMENT ON COLUMN dam_metadata.collect_task.source_ds_id IS '源数据源 id（data_source.id），非空表示跨库 JDBC 抽数任务';

CREATE TABLE IF NOT EXISTS dam_metadata.collect_task_log (
    id          bigserial PRIMARY KEY,
    task_id     bigint NOT NULL,
    started_at  timestamp NOT NULL,
    finished_at timestamp NOT NULL,
    duration_ms bigint,
    rows_loaded bigint,
    exec_status varchar(16) NOT NULL,
    message     text,
    trigger_by  varchar(20) NOT NULL DEFAULT 'MANUAL',  -- MANUAL / POWERJOB
    created_at  timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE dam_metadata.collect_task_log IS '采集任务运行记录—— 每次执行的行数/耗时/状态';

INSERT INTO dam_metadata.collect_task (task_code, task_name, source_schema, source_table,
                              target_schema, target_table, column_mapping, uk_column, load_mode, where_clause)
VALUES
('HIS-PAT-MASTER', 'HIS患者主索引→中台患者主表', 'PROD.CIS_Model', 'PA_PatMas',
 'hospital_demo', 'biz_patient_master',
 '[{"src":"PatID","tgt":"patient_id"},{"src":"Name","tgt":"patient_name"},{"src":"Sex","tgt":"gender_code"},{"src":"DateOfBirth","tgt":"birth_date"},{"src":"IDNo","tgt":"id_card"},{"src":"MaritalStatus","tgt":"marital_status"},{"src":"Occupation","tgt":"occupation"}]'::jsonb,
 'patient_id', 'UPSERT', NULL),
('HIS-ENCOUNTER', 'HIS就诊登记→中台就诊表', 'PROD.CIS_Model', 'PA_Adm',
 'hospital_demo', 'biz_encounter',
 '[{"src":"AdmID","tgt":"encounter_no"},{"src":"PatID","tgt":"patient_id"},{"src":"AdmType","tgt":"encounter_type"},{"src":"DeptID","tgt":"dept_code"},{"src":"DeptName","tgt":"dept_name"},{"src":"DoctorID","tgt":"doctor_code"},{"src":"DoctorName","tgt":"doctor_name"},{"src":"AdmDate","tgt":"admit_time"},{"src":"DischDate","tgt":"discharge_time"},{"src":"AdmStatus","tgt":"encounter_status"},{"src":"TotalCost","tgt":"total_cost"}]'::jsonb,
 'encounter_no', 'UPSERT', NULL),
('HIS-ORDER', 'HIS医嘱→中台医嘱表', 'PROD.CIS_Model', 'OE_Order',
 'hospital_demo', 'biz_clinical_order',
 '[{"src":"OrdID","tgt":"order_no"},{"src":"AdmID","tgt":"encounter_no"},{"src":"PatID","tgt":"patient_id"},{"src":"OrdType","tgt":"order_type"},{"src":"ArcimCode","tgt":"order_item_code"},{"src":"ArcimDesc","tgt":"order_item_name"},{"src":"Spec","tgt":"spec"},{"src":"Dosage","tgt":"dosage"},{"src":"Frequency","tgt":"frequency"},{"src":"Route","tgt":"route"},{"src":"DoctorName","tgt":"order_doctor"},{"src":"OrdDate","tgt":"order_time"},{"src":"OrdStatus","tgt":"order_status"}]'::jsonb,
 'order_no', 'UPSERT', NULL),
('HIS-ORDER-EXEC', 'HIS医嘱执行→中台执行记录', 'PROD.CIS_Model', 'OE_OrdExec',
 'hospital_demo', 'biz_order_exec',
 '[{"src":"OrdID","tgt":"order_no"},{"src":"ExecDate","tgt":"exec_time"},{"src":"NurseID","tgt":"exec_nurse"},{"src":"DeptID","tgt":"exec_dept"},{"src":"ExecStatus","tgt":"exec_status"},{"src":"Note","tgt":"exec_note"}]'::jsonb,
 'order_no', 'DELETE_INSERT', NULL)
ON CONFLICT (task_code) DO NOTHING;

-- ---------------- 3. PowerJob 全量采集调度任务 ----------------
INSERT INTO dam_sched.sched_job (job_code, name, job_type, schedule_type, cron_expr, description)
VALUES ('COLLECT-HIS-ALL', 'HIS 数据采集（全量）', 'HIS_COLLECT_ALL', 'CRON', '0 0 1 * * ?',
        '每日凌晨 1 点执行全部启用的 HIS→中台采集任务')
ON CONFLICT (job_code) DO NOTHING;
