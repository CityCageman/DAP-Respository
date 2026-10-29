-- =====================================================================
-- 数仓分层体系（v4，2026-10-25）：按《主题域》《业务主题域》《DIM维度》思维导图落地
-- 分层：SRC(业务源) → ODS(贴源) → DIM(维度) → DWD(明细) → DWS(汇总) → ADS(应用)
-- 本文件只做骨架（schema / 分层标识列），幂等可重复执行
-- =====================================================================

-- 维度层：字典与码表（对应《DIM维度.xmind》14 个 DIM_* 域）
CREATE SCHEMA IF NOT EXISTS dim;
COMMENT ON SCHEMA dim IS 'DIM 维度层：医院字典与码表（组织/人口学/诊断/手术/药学等 14 个维度域）';

-- 明细层：业务主题域明细宽表（对应《业务主题域.xmind》12 个 BIZ_* 域，FHIR 对齐）
CREATE SCHEMA IF NOT EXISTS dwd;
COMMENT ON SCHEMA dwd IS 'DWD 明细层：按业务主题域组织的清洗明细（患者/就诊/诊断/医嘱/处方/检验/检查/体征/手术等）';

-- 汇总层：轻度聚合（按日/科室/病区等粒度）
CREATE SCHEMA IF NOT EXISTS dws;
COMMENT ON SCHEMA dws IS 'DWS 汇总层：轻度聚合指标（按日/科室/医生等粒度）';

-- 应用层：面向报表/大屏/API 的最终结果集
CREATE SCHEMA IF NOT EXISTS ads;
COMMENT ON SCHEMA ads IS 'ADS 应用层：面向报表、大屏与数据服务的最终结果集';

-- 贴源层说明：ODS 按源建 schema（ods_<库名>，如 ods_his_src），由元数据同步自动生成，这里只写注释锚点
COMMENT ON SCHEMA "PROD.CIS_Model" IS 'SRC 业务贴源区（模拟 HIS 落地结构，生产为 InterSystems IRIS）';

-- 元数据表加分层标识（按 schema 前缀自动推导：ods_% → ODS，dim → DIM，dwd → DWD，dws → DWS，ads → ADS，其余 SRC）
ALTER TABLE dam_metadata.metadata_table ADD COLUMN IF NOT EXISTS layer varchar(16);
COMMENT ON COLUMN dam_metadata.metadata_table.layer IS '数仓分层：SRC/ODS/DIM/DWD/DWS/ADS';
