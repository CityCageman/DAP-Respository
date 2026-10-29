-- =====================================================================
-- 数仓 DIM 维度层 + DWD 明细层初始化（v1，幂等可重跑）
-- 维度域划分依据《DIM维度.xmind》（14 域），DWD 主题域依据《业务主题域.xmind》（12 域）
-- 数据来源：ODS 层（ods_his_src，SeaTunnel 采集）与平台标准码表（dam_standard.standard_code_*）
-- =====================================================================

---------------------------------------------------------------------
-- 0. 存量 ODS 表补 ETL 规范列（新生成的表由 OdsCollectGenerator 自动带）
---------------------------------------------------------------------
ALTER TABLE ods_his_src."PA_PatMas"  ADD COLUMN IF NOT EXISTS etl_time timestamp NOT NULL DEFAULT now();
ALTER TABLE ods_his_src."PA_PatMas"  ADD COLUMN IF NOT EXISTS etl_batch varchar(64);
ALTER TABLE ods_his_src."PA_PatMas"  ADD COLUMN IF NOT EXISTS etl_source varchar(64);
ALTER TABLE ods_his_src."PA_Adm"     ADD COLUMN IF NOT EXISTS etl_time timestamp NOT NULL DEFAULT now();
ALTER TABLE ods_his_src."PA_Adm"     ADD COLUMN IF NOT EXISTS etl_batch varchar(64);
ALTER TABLE ods_his_src."PA_Adm"     ADD COLUMN IF NOT EXISTS etl_source varchar(64);
ALTER TABLE ods_his_src."OE_Order"   ADD COLUMN IF NOT EXISTS etl_time timestamp NOT NULL DEFAULT now();
ALTER TABLE ods_his_src."OE_Order"   ADD COLUMN IF NOT EXISTS etl_batch varchar(64);
ALTER TABLE ods_his_src."OE_Order"   ADD COLUMN IF NOT EXISTS etl_source varchar(64);
ALTER TABLE ods_his_src."OE_OrdExec" ADD COLUMN IF NOT EXISTS etl_time timestamp NOT NULL DEFAULT now();
ALTER TABLE ods_his_src."OE_OrdExec" ADD COLUMN IF NOT EXISTS etl_batch varchar(64);
ALTER TABLE ods_his_src."OE_OrdExec" ADD COLUMN IF NOT EXISTS etl_source varchar(64);

---------------------------------------------------------------------
-- 1. DIM 通用码表：14 个维度域 × 平台 22 张标准码表
---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.dim_code (
    id              bigserial PRIMARY KEY,
    layer_domain    varchar(64)  NOT NULL,
    domain_name     varchar(64)  NOT NULL,
    code_table_code varchar(64)  NOT NULL,
    code_table_name varchar(128),
    code_value      varchar(64)  NOT NULL,
    code_name       varchar(128),
    sort_order      integer,
    etl_time        timestamp    NOT NULL DEFAULT now()
);
COMMENT ON TABLE dim.dim_code IS 'DIM 维度层通用码表：平台标准码表按思维导图 14 个 DIM_* 维度域归类';

TRUNCATE dim.dim_code;
INSERT INTO dim.dim_code(layer_domain, domain_name, code_table_code, code_table_name, code_value, code_name, sort_order)
SELECT
    CASE t.code_table_code
        WHEN 'CT_Loc' THEN 'DIM-Organization-Personnel'
        WHEN 'CT_Ward' THEN 'DIM-Organization-Personnel'
        WHEN 'CT_CareProv' THEN 'DIM-Organization-Personnel'
        WHEN 'CT_Sex' THEN 'DIM_Patient_Demographics'
        WHEN 'CT_Marital' THEN 'DIM_Patient_Demographics'
        WHEN 'CT_Nation' THEN 'DIM_Patient_Demographics'
        WHEN 'CT_IDCardType' THEN 'DIM_Patient_Demographics'
        WHEN 'CT_FeeType' THEN 'DIM_Finance_Billing'
        WHEN 'CT_InsureType' THEN 'DIM_Finance_Billing'
        WHEN 'CT_LabItem' THEN 'DIM_Laboratory_Imaging'
        WHEN 'CT_ExamItem' THEN 'DIM_Laboratory_Imaging'
        WHEN 'CT_Frequency' THEN 'DIM_Orders_Execution'
        WHEN 'CT_Pharmacy' THEN 'DIM_Pharmacy_Management'
        WHEN 'CT_Route' THEN 'DIM_Pharmacy_Management'
        WHEN 'CT_AppointType' THEN 'DIM_Appointment_Scheduling'
        WHEN 'CT_EncounterType' THEN 'DIM_Encounter_ADT'
        WHEN 'CT_ICD10' THEN 'DIM_Diagnosis'
        WHEN 'CT_ICD9CM3' THEN 'DIM_Surgery_Therapy'
        WHEN 'CT_EMRDocType' THEN 'DIM_EMR_Documentation'
        WHEN 'CT_Material' THEN 'DIM_SupplyChain_Materials'
        WHEN 'CT_SecLevel' THEN 'DIM_Security_Permissions'
        WHEN 'CT_Unit' THEN 'DIM_Common_Foundation'
        ELSE 'DIM_Common_Foundation'
    END,
    CASE t.code_table_code
        WHEN 'CT_Loc' THEN '组织架构与人员'
        WHEN 'CT_Ward' THEN '组织架构与人员'
        WHEN 'CT_CareProv' THEN '组织架构与人员'
        WHEN 'CT_Sex' THEN '患者与人口学'
        WHEN 'CT_Marital' THEN '患者与人口学'
        WHEN 'CT_Nation' THEN '患者与人口学'
        WHEN 'CT_IDCardType' THEN '患者与人口学'
        WHEN 'CT_FeeType' THEN '财务与收费'
        WHEN 'CT_InsureType' THEN '财务与收费'
        WHEN 'CT_LabItem' THEN '检验与检查'
        WHEN 'CT_ExamItem' THEN '检验与检查'
        WHEN 'CT_Frequency' THEN '医嘱与执行'
        WHEN 'CT_Pharmacy' THEN '药学与药事管理'
        WHEN 'CT_Route' THEN '药学与药事管理'
        WHEN 'CT_AppointType' THEN '预约挂号与号源'
        WHEN 'CT_EncounterType' THEN '就诊与入出院管理'
        WHEN 'CT_ICD10' THEN '诊断'
        WHEN 'CT_ICD9CM3' THEN '手术与治疗'
        WHEN 'CT_EMRDocType' THEN '临床文书与电子病历'
        WHEN 'CT_Material' THEN '供应链与物资'
        WHEN 'CT_SecLevel' THEN '系统权限与安全'
        WHEN 'CT_Unit' THEN '通用基础数据'
        ELSE '通用基础数据'
    END,
    t.code_table_code, t.code_table_name, v.code_value, v.code_name, v.sort_order
FROM dam_standard.standard_code_value v
JOIN dam_standard.standard_code_table t ON t.id = v.code_table_id
WHERE v.deleted_at IS NULL AND t.deleted_at IS NULL;

---------------------------------------------------------------------
-- 2. DIM 专用维度表（高频 JOIN 的核心字典）
---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.dim_department (
    dept_code  varchar(64) PRIMARY KEY,
    dept_name  varchar(128) NOT NULL,
    dept_type  varchar(32),
    etl_time   timestamp NOT NULL DEFAULT now()
);
COMMENT ON TABLE dim.dim_department IS 'DIM 科室维度（来源：平台标准码表 CT_Loc，域：组织架构与人员）';
TRUNCATE dim.dim_department;
INSERT INTO dim.dim_department(dept_code, dept_name, dept_type)
SELECT v.code_value, v.code_name, t.code_table_type
FROM dam_standard.standard_code_value v
JOIN dam_standard.standard_code_table t ON t.id = v.code_table_id
WHERE t.code_table_code = 'CT_Loc' AND v.deleted_at IS NULL AND t.deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS dim.dim_diagnosis_icd10 (
    icd_code  varchar(32) PRIMARY KEY,
    icd_name  varchar(256) NOT NULL,
    etl_time  timestamp NOT NULL DEFAULT now()
);
COMMENT ON TABLE dim.dim_diagnosis_icd10 IS 'DIM 诊断维度 ICD-10（来源：CT_ICD10，域：诊断）';
TRUNCATE dim.dim_diagnosis_icd10;
INSERT INTO dim.dim_diagnosis_icd10(icd_code, icd_name)
SELECT v.code_value, v.code_name
FROM dam_standard.standard_code_value v
JOIN dam_standard.standard_code_table t ON t.id = v.code_table_id
WHERE t.code_table_code = 'CT_ICD10' AND v.deleted_at IS NULL AND t.deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS dim.dim_surgery_icd9cm3 (
    surg_code varchar(32) PRIMARY KEY,
    surg_name varchar(256) NOT NULL,
    etl_time  timestamp NOT NULL DEFAULT now()
);
COMMENT ON TABLE dim.dim_surgery_icd9cm3 IS 'DIM 手术操作维度 ICD-9-CM-3（来源：CT_ICD9CM3，域：手术与治疗）';
TRUNCATE dim.dim_surgery_icd9cm3;
INSERT INTO dim.dim_surgery_icd9cm3(surg_code, surg_name)
SELECT v.code_value, v.code_name
FROM dam_standard.standard_code_value v
JOIN dam_standard.standard_code_table t ON t.id = v.code_table_id
WHERE t.code_table_code = 'CT_ICD9CM3' AND v.deleted_at IS NULL AND t.deleted_at IS NULL;

---------------------------------------------------------------------
-- 3. DWD 明细层（首批 3 个主题域模型，ODS 清洗 + DIM 打标）
---------------------------------------------------------------------

-- 3.1 患者主索引（BIZ_Patient_Master，FHIR: Patient）
CREATE TABLE IF NOT EXISTS dwd.dwd_patient_master (
    patid         varchar(64) PRIMARY KEY,
    pat_name      varchar(128),
    sex_code      varchar(16),          -- 标准码（CT_Sex：1男/2女/0未知/9未说明）
    sex_name      varchar(32),
    birth_date    date,
    id_no         varchar(64),
    marital_code  varchar(16),          -- 源系统原码（HIS 1/2/3/9，与 CT_Marital 10/20/... 的映射待院方确认）
    marital_name  varchar(32),
    occupation    varchar(64),
    reg_date      timestamp,
    src_system    varchar(32)  NOT NULL DEFAULT 'HIS',
    etl_time      timestamp    NOT NULL DEFAULT now(),
    etl_batch     varchar(64)
);
COMMENT ON TABLE dwd.dwd_patient_master IS 'DWD 患者主索引（域：主索引与患者管理，来源 ODS.PA_PatMas 清洗）';

TRUNCATE dwd.dwd_patient_master;
INSERT INTO dwd.dwd_patient_master(patid, pat_name, sex_code, sex_name, birth_date, id_no,
                                   marital_code, marital_name, occupation, reg_date, etl_batch)
SELECT p.patid,
       p.name,
       CASE p.sex WHEN 'M' THEN '1' WHEN 'F' THEN '2' ELSE '0' END,
       sx.code_name,
       p.dateofbirth,
       p.idno,
       p.maritalstatus,
       mt.code_name,
       p.occupation,
       p.regdate,
       'DWD-' || to_char(now(), 'YYYYMMDDHH24MISS')
FROM ods_his_src."PA_PatMas" p
LEFT JOIN dim.dim_code sx  ON sx.code_table_code = 'CT_Sex'     AND sx.code_value = CASE p.sex WHEN 'M' THEN '1' WHEN 'F' THEN '2' ELSE '0' END
LEFT JOIN dim.dim_code mt  ON mt.code_table_code = 'CT_Marital' AND mt.code_value = p.maritalstatus;

-- 3.2 就诊事件（BIZ_Encounter_Visit，FHIR: Encounter）
CREATE TABLE IF NOT EXISTS dwd.dwd_encounter (
    admid           varchar(64) PRIMARY KEY,
    patid           varchar(64) NOT NULL,
    pat_name        varchar(128),
    encounter_type  varchar(16),
    encounter_name  varchar(32),
    dept_code       varchar(64),
    dept_name       varchar(128),
    doctor_id       varchar(64),
    doctor_name     varchar(128),
    adm_date        timestamp,
    disch_date      timestamp,
    stay_days       integer,
    encounter_status varchar(32),
    total_cost      numeric(18,2),
    etl_time        timestamp NOT NULL DEFAULT now(),
    etl_batch       varchar(64)
);
COMMENT ON TABLE dwd.dwd_encounter IS 'DWD 就诊事件（域：诊疗活动管理，来源 ODS.PA_Adm 清洗 + 科室/就诊类型维度打标）';

TRUNCATE dwd.dwd_encounter;
INSERT INTO dwd.dwd_encounter(admid, patid, pat_name, encounter_type, encounter_name,
                              dept_code, dept_name, doctor_id, doctor_name,
                              adm_date, disch_date, stay_days, encounter_status, total_cost, etl_batch)
SELECT a.admid,
       a.patid,
       pm.pat_name,
       a.admtype,
       et.code_name,
       a.deptid,
       a.deptname,
       a.doctorid,
       a.doctorname,
       a.admdate,
       a.dischdate,
       CASE WHEN a.admdate IS NOT NULL AND a.dischdate IS NOT NULL
            THEN (a.dischdate::date - a.admdate::date) END,
       a.admstatus,
       a.totalcost,
       'DWD-' || to_char(now(), 'YYYYMMDDHH24MISS')
FROM ods_his_src."PA_Adm" a
LEFT JOIN dwd.dwd_patient_master pm ON pm.patid = a.patid
LEFT JOIN dim.dim_code et ON et.code_table_code = 'CT_EncounterType' AND et.code_value = a.admtype;

-- 3.3 临床医嘱（BIZ_Clinical_Order，FHIR: ServiceRequest）
CREATE TABLE IF NOT EXISTS dwd.dwd_clinical_order (
    ordid          varchar(64) PRIMARY KEY,
    admid          varchar(64),
    patid          varchar(64),
    order_type     varchar(16),
    order_type_name varchar(32),
    item_code      varchar(64),
    item_name      varchar(256),
    spec           varchar(128),
    dosage         varchar(64),
    frequency      varchar(32),
    frequency_name varchar(64),
    route          varchar(32),
    route_name     varchar(64),
    doctor_name    varchar(128),
    order_date     timestamp,
    order_status   varchar(16),
    etl_time       timestamp NOT NULL DEFAULT now(),
    etl_batch      varchar(64)
);
COMMENT ON TABLE dwd.dwd_clinical_order IS 'DWD 临床医嘱（域：医嘱管理，来源 ODS.OE_Order 清洗 + 频次/途径维度打标）';

TRUNCATE dwd.dwd_clinical_order;
INSERT INTO dwd.dwd_clinical_order(ordid, admid, patid, order_type, order_type_name,
                                   item_code, item_name, spec, dosage,
                                   frequency, frequency_name, route, route_name,
                                   doctor_name, order_date, order_status, etl_batch)
SELECT o.ordid,
       o.admid,
       o.patid,
       o.ordtype,
       ot.code_name,
       o.arcimcode,
       o.arcimdesc,
       o.spec,
       o.dosage,
       o.frequency,
       fq.code_name,
       o.route,
       rt.code_name,
       o.doctorname,
       o.orddate,
       o.ordstatus,
       'DWD-' || to_char(now(), 'YYYYMMDDHH24MISS')
FROM ods_his_src."OE_Order" o
LEFT JOIN dim.dim_code ot ON ot.code_table_code = 'CT_EncounterType' AND ot.code_value = o.ordtype
LEFT JOIN dim.dim_code fq ON fq.code_table_code = 'CT_Frequency'     AND fq.code_value = o.frequency
LEFT JOIN dim.dim_code rt ON rt.code_table_code = 'CT_Route'         AND rt.code_value = o.route;
