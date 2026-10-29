# 数据中台数仓分层设计（从 ODS 起步 · PostgreSQL）

> 依据思维导图：《主题域.xmind》《业务主题域.xmind》《DIM维度.xmind》
> 数据库：PostgreSQL 17（asset_platform 库），后续可平迁 Doris/其他 MPP
> 落地时间：2026-10-25

## 一、总体分层

```
SRC（业务源系统）          PROD.CIS_Model（模拟 HIS 落地，生产为 InterSystems IRIS）
   │  SeaTunnel 分片并行采集（dam.collect_task 全自动生成）
   ▼
ODS 贴源层                 ods_<库名> schema，如 ods_his_src（元数据同步自动建表+建任务）
   │  清洗 / 标准化 / 码值翻译（warehouse-init-dim-dwd.sql，后续接调度）
   ▼
DIM 维度层  ┐              dim schema（14 个 DIM_* 维度域）
DWD 明细层  ┘              dwd schema（12 个 BIZ_* 业务主题域，FHIR 对齐）
   │  轻度聚合（按日/科室/医生）
   ▼
DWS 汇总层                 dws schema（已建，模型待规划）
   │  面向应用组装
   ▼
ADS 应用层                 ads schema（已建，模型待规划）→ 报表 / 大屏 / 数据服务 API
```

与《主题域.xmind》的对应：DWD+DIM 层沉淀后向上支撑临床数据中心（患者 360 模型集：患者域/科室域…），
运营/科研/影像数据中心在 ADS 层按主题建应用模型。

## 二、分层职责与命名规范

| 层 | schema | 命名规范 | 职责 | 现状 |
|---|---|---|---|---|
| ODS | `ods_<源库名>` | 与源表同名贴源 | 原样落地，全量重刷，不加业务加工 | ✅ 4 表 1760 行 |
| DIM | `dim` | `dim_<业务>` / 通用 `dim_code` | 字典码表，全域统一口径 | ✅ 4 表 217 行 |
| DWD | `dwd` | `dwd_<主题域>` | 清洗、标准化、码值翻译、一表一主题 | ✅ 首批 3 模型 |
| DWS | `dws` | `dws_<粒度>_<主题>` | 轻度聚合 | 骨架已建 |
| ADS | `ads` | `ads_<应用>_<主题>` | 最终结果集 | 骨架已建 |

**ODS 规范列**（建表自动带，采集引擎自动填写）：
- `etl_time`：落库时间（默认 now()）
- `etl_batch`：采集批次号 `任务码-yyyyMMddHHmmss`
- `etl_source`：采集引擎（SeaTunnel / JDBC引擎）

**元数据分层标识**：`dam.metadata_table.layer`（SRC/ODS/DIM/DWD/DWS/ADS），
元数据同步按 schema 前缀自动推导回填。

## 三、DIM 维度层（对应《DIM维度.xmind》14 域）

通用码表 `dim.dim_code`（168 码值）+ 专用维度表，映射关系：

| DIM 域 | 中文名 | 码表 |
|---|---|---|
| DIM-Organization-Personnel | 组织架构与人员 | CT_Loc / CT_Ward / CT_CareProv（34） |
| DIM_Patient_Demographics | 患者与人口学 | CT_Sex / CT_Marital / CT_Nation / CT_IDCardType（22） |
| DIM_Finance_Billing | 财务与收费 | CT_FeeType / CT_InsureType（13） |
| DIM_Laboratory_Imaging | 检验与检查 | CT_LabItem / CT_ExamItem（16） |
| DIM_Orders_Execution | 医嘱与执行 | CT_Frequency（8） |
| DIM_Pharmacy_Management | 药学与药事管理 | CT_Pharmacy / CT_Route（19） |
| DIM_Appointment_Scheduling | 预约挂号与号源 | CT_AppointType（4） |
| DIM_Encounter_ADT | 就诊与入出院管理 | CT_EncounterType（3） |
| DIM_Diagnosis | 诊断 | CT_ICD10（17） |
| DIM_Surgery_Therapy | 手术与治疗 | CT_ICD9CM3（12） |
| DIM_EMR_Documentation | 临床文书与电子病历 | CT_EMRDocType（6） |
| DIM_SupplyChain_Materials | 供应链与物资 | CT_Material（4） |
| DIM_Security_Permissions | 系统权限与安全 | CT_SecLevel（4） |
| DIM_Common_Foundation | 通用基础数据 | CT_Unit（6） |

专用维度表：`dim.dim_department`（科室 20）、`dim.dim_diagnosis_icd10`（17）、`dim.dim_surgery_icd9cm3`（12）。

## 四、DWD 明细层（对应《业务主题域.xmind》，首批 3 模型）

| 模型 | 业务域 | FHIR 资源 | 来源 | 行数 |
|---|---|---|---|---|
| dwd.dwd_patient_master | 主索引与患者管理 | Patient | ODS.PA_PatMas | 80 |
| dwd.dwd_encounter | 诊疗活动管理 | Encounter | ODS.PA_Adm + 患者主索引 | 240 |
| dwd.dwd_clinical_order | 医嘱管理 | ServiceRequest | ODS.OE_Order | 720 |

加工内容：HIS 性别码 M/F → 平台标准码 1/2 并关联性别字典名称；就诊天数计算；频次/途径/就诊类型字典打标；
patid 主键去重；ETL 批次追溯。

**⚠️ 待确认映射**（当前保留原码、翻译列留空，不做臆测）：
- 婚姻状况：HIS 原码 1/2/3/9 vs 平台 CT_Marital 10/20/30/40/90
- 就诊类型：HIS 原码 1/2 vs 平台 CT_EncounterType O(门诊)/E(急诊)/I(住院)

## 五、后续规划

1. DWD 其余 9 个业务主题域（处方/检验/检查/辅助检查/体征/手术麻醉/输血/病历文书）随数据源接入逐步建模
2. ODS→DWD 加工 SQL 接入 PowerJob 调度（采集成功后联动刷新）
3. DWS：按日/科室聚合门急诊量、在院人数、医嘱执行率等
4. ADS：患者 360 全息视图宽表（对应《患者360全息视图.xmind》）→ 数据服务 API

## 六、脚本与代码位置

- 分层骨架（随后端启动自动执行）：`backend/src/main/resources/schema-v4-warehouse.sql`
- DIM/DWD 建模灌数（幂等，手动/调度执行）：`backend/src/main/resources/warehouse-init-dim-dwd.sql`
- ODS 建表自动带 ETL 列：`OdsCollectGenerator.ensureOdsTable`
- 采集写 ETL 批次：`SeaTunnelCollectService` / `HisCollectService.runCrossDb`
- 分层标识自动推导：`DamMetadataSyncService.layerOfSchema`
