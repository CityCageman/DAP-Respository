-- =============================================================
-- v3.1 补充种子（阶段 B）：模型事实/维度 + 患者360 网关 API 注册
-- 幂等：先 DELETE 再 INSERT
-- =============================================================

-- ---------- 1. 模型事实/维度（目录树第四层"模型"） ----------
DELETE FROM dam_model.model_fact;
DELETE FROM dam_model.model_dimension;

INSERT INTO dam_model.model_fact (domain_id, fact_code, fact_name, source_table_id, granularity, description, created_by) VALUES
((select id from dam_model.model_domain where domain_code='MD-P360'), 'F_ENCOUNTER', '就诊事实', (select id from dam_metadata.metadata_table where table_name='biz_encounter' and datasource_id=(select id from dam_metadata.metadata_datasource where ds_code='DS-LOCAL-DEMO')), '一次就诊一行', '门诊/急诊/住院就诊事件主表', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-P360'), 'F_DIAGNOSIS', '诊断事实', (select id from dam_metadata.metadata_table where table_name='biz_diagnosis' and datasource_id=(select id from dam_metadata.metadata_datasource where ds_code='DS-LOCAL-DEMO')), '一次就诊一条诊断', '标准化 ICD-10 诊断记录', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-P360'), 'F_ORDER', '医嘱事实', (select id from dam_metadata.metadata_table where table_name='biz_clinical_order' and datasource_id=(select id from dam_metadata.metadata_datasource where ds_code='DS-LOCAL-DEMO')), '一条医嘱一行', '长期/临时医嘱', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-P360'), 'F_PRESCRIPTION', '处方事实', (select id from dam_metadata.metadata_table where table_name='biz_prescription' and datasource_id=(select id from dam_metadata.metadata_datasource where ds_code='DS-LOCAL-DEMO')), '一张处方一行', '门诊处方单', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-P360'), 'F_LAB', '检验事实', (select id from dam_metadata.metadata_table where table_name='biz_lab_report' and datasource_id=(select id from dam_metadata.metadata_datasource where ds_code='DS-LOCAL-DEMO')), '一份报告一行', '检验报告与结果子项', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-P360'), 'F_SURGERY', '手术事实', (select id from dam_metadata.metadata_table where table_name='biz_surgery_anesthesia' and datasource_id=(select id from dam_metadata.metadata_datasource where ds_code='DS-LOCAL-DEMO')), '一台手术一行', '手术麻醉记录（ICD-9-CM-3）', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-P360'), 'F_VITAL', '体征事实', (select id from dam_metadata.metadata_table where table_name='biz_vital_signs' and datasource_id=(select id from dam_metadata.metadata_datasource where ds_code='DS-LOCAL-DEMO')), '一次测量一行', '住院体温单体征数据', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-IMG'), 'F_IMAGING', '影像检查事实', (select id from dam_metadata.metadata_table where table_name='biz_imaging_exam' and datasource_id=(select id from dam_metadata.metadata_datasource where ds_code='DS-LOCAL-DEMO')), '一次检查一行', 'CT/MRI/DR/超声/内镜图文报告', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-DOC'), 'F_EMR_DOC', '病历文书事实', (select id from dam_metadata.metadata_table where table_name='biz_emr_document' and datasource_id=(select id from dam_metadata.metadata_datasource where ds_code='DS-LOCAL-DEMO')), '一份文书一行', '归档电子病历文书', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-OP'), 'F_COST', '费用事实', (select id from dam_metadata.metadata_table where table_name='biz_encounter' and datasource_id=(select id from dam_metadata.metadata_datasource where ds_code='DS-LOCAL-DEMO')), '一次就诊一行', '就诊总费用（运营域）', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-RES'), 'F_RES_VITAL', '科研体征子集', (select id from dam_metadata.metadata_table where table_name='biz_vital_signs' and datasource_id=(select id from dam_metadata.metadata_datasource where ds_code='DS-LOCAL-DEMO')), '一次测量一行', '脱敏后科研用体征数据集', 'seeder');

INSERT INTO dam_model.model_dimension (domain_id, dimension_code, dimension_name, source_table_id, description, created_by) VALUES
((select id from dam_model.model_domain where domain_code='MD-P360'), 'D_PATIENT', '患者基本信息维', (select id from dam_metadata.metadata_table where table_name='biz_patient_master' and datasource_id=(select id from dam_metadata.metadata_datasource where ds_code='DS-LOCAL-DEMO')), 'EMPI 主索引维度', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-P360'), 'D_DEPT', '科室维', NULL, '三甲医院科室字典', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-P360'), 'D_DOCTOR', '医护维', NULL, '医生/护士字典', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-MDM'), 'D_ICD10', 'ICD-10 诊断字典', NULL, '国际疾病分类第 10 版', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-MDM'), 'D_ICD9', 'ICD-9-CM-3 手术字典', NULL, '手术操作分类第 9 版修订 3', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-MDM'), 'D_ORG_MDM', '科室主数据', NULL, '全院统一科室主数据', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-MDM'), 'D_DEMOGRAPHY', '患者人口学字典', (select id from dam_metadata.metadata_table where table_name='biz_patient_master' and datasource_id=(select id from dam_metadata.metadata_datasource where ds_code='DS-LOCAL-DEMO')), '性别/民族/婚姻/证件类型', 'seeder'),
((select id from dam_model.model_domain where domain_code='MD-IMG'), 'D_EXAM_TYPE', '检查类型维', NULL, 'CT/MRI/DR/超声/内镜', 'seeder');

-- ---------- 2. 患者360 聚合 API（网关旗舰演示） ----------
DELETE FROM dam_service.api_service WHERE api_code = 'API-PATIENT-360';
DELETE FROM api_service WHERE api_code = 'API-PATIENT-360';

INSERT INTO dam_service.api_service (api_code, name, sql_text, params_json, approval_status, approved_by, approved_at, rate_limit, quota_day, owner, description, created_by) VALUES
('API-PATIENT-360', '患者360全息视图（聚合）', 'select 1', '[{"name":"patientId","type":"string","required":true,"desc":"患者主索引号","example":"EMPI000001"}]', 'APPROVED', 'admin', '2026-10-24 02:00:00', 30, 10000, 'admin', '一次返回患者信息+过敏+就诊时间轴（诊断/医嘱/处方/检验/检查/手术/体征/输血/病历），身份证/姓名按安全策略脱敏', 'seeder');

INSERT INTO api_service (api_code, name, asset_id, sql_text, params_json, status, rate_limit, owner, description, call_count, created_at, updated_at) VALUES
('API-PATIENT-360', '患者360全息视图（聚合）', NULL, 'select 1', '[{"name":"patientId","type":"string","required":true,"desc":"患者主索引号","example":"EMPI000001"}]', 'PUBLISHED', 30, 'admin', '网关聚合接口：患者全息视图，服务端聚合 hospital_demo.biz_* 十余张业务表', 0, now(), now());
