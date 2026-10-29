-- =====================================================================
-- 代码对照（码值映射）初始化：dam_standard.code_crosswalk
--
-- 定位：标准码表（standard_code_table / standard_code_value）回答"标准是什么"，
--       代码对照回答"源系统的哪个值等于标准里的哪个值"。
-- 归属：治理域。对照规则是"标准落地"的度量基准，也是跨源系统裁决的唯一真相源。
-- 消费：数据中台经 /openapi/standards/codes 只读拉取，落 mid.code_crosswalk 镜像执行。
--
-- 幂等：可重复执行。已存在的对照行会按本文件的目标码值刷新（upsert），
--       因为标准码表换版后 target_value 必须跟着换。
-- 依赖：须先执行 code-standards-alignment.sql（本文件的目标码值全部取自国标/行标）。
-- =====================================================================

CREATE TABLE IF NOT EXISTS dam_standard.code_crosswalk (
    id              bigserial PRIMARY KEY,
    code_table_id   bigint       NOT NULL,
    code_table_code varchar(64)  NOT NULL,
    code_table_name varchar(128),
    source_system   varchar(64)  NOT NULL,
    source_table    varchar(128),
    source_column   varchar(128),
    source_value    varchar(64)  NOT NULL,
    source_name     varchar(128),
    target_value    varchar(64)  NOT NULL,
    target_name     varchar(128),
    priority        integer      NOT NULL DEFAULT 100,
    remark          text,
    status          smallint     NOT NULL DEFAULT 1,
    created_at      timestamp    NOT NULL DEFAULT now(),
    created_by      varchar(64)  NOT NULL DEFAULT 'system',
    updated_at      timestamp    NOT NULL DEFAULT now(),
    updated_by      varchar(64)  NOT NULL DEFAULT 'system',
    deleted_at      timestamp
);

-- 存量表补列（先建表后加定位列的场景）：必须在 COMMENT 之前
ALTER TABLE dam_standard.code_crosswalk ADD COLUMN IF NOT EXISTS source_table  varchar(128);
ALTER TABLE dam_standard.code_crosswalk ADD COLUMN IF NOT EXISTS source_column varchar(128);

COMMENT ON TABLE  dam_standard.code_crosswalk IS '代码对照：源系统码值 → 平台标准码值（治理域持有，中台镜像执行）';
COMMENT ON COLUMN dam_standard.code_crosswalk.source_system IS '来源系统标识，与数据源登记的系统代号一致，如 HIS / LIS / PACS';
COMMENT ON COLUMN dam_standard.code_crosswalk.source_table  IS '源表名（可选）：填写后中台可扫描该列实际出现的码值，自动发现未对照项';
COMMENT ON COLUMN dam_standard.code_crosswalk.source_column IS '源字段名（可选）：与 source_table 配对使用';
COMMENT ON COLUMN dam_standard.code_crosswalk.source_value  IS '源系统实际存储的码值，按字符串比较（HIS 的 M/F、1/2/3/9 等）';
COMMENT ON COLUMN dam_standard.code_crosswalk.target_value  IS '标准码值，必须是 standard_code_value 中该码表下存在的值';
COMMENT ON COLUMN dam_standard.code_crosswalk.priority      IS '同一源码值有多条对照时的取值优先级，数值小者优先';
COMMENT ON COLUMN dam_standard.code_crosswalk.remark        IS '生效依据/待确认说明';

CREATE UNIQUE INDEX IF NOT EXISTS uk_code_crosswalk
    ON dam_standard.code_crosswalk (code_table_id, source_system, source_value)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_code_crosswalk_table
    ON dam_standard.code_crosswalk (code_table_code, source_system)
    WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------
-- 基线映射：HIS 模拟源
--
-- 目标码值一律采用标准码表当前的国标/行标值，不保留院内自造码（O/E/I、PO/IV/IM 等
-- 已替换为 CT01.00.001 的 01/02/03 与 CV06.00.102 的 1/403/404）。
-- 标准表中无对应值的（如频次 tid）保留院内原值，并在 standard_code_value 标 is_extension=1。
-- ---------------------------------------------------------------------
WITH m (code_table_code, source_value, source_name, target_value,
        source_table, source_column, remark) AS (
    VALUES
        -- 婚姻状况：源 1/2/3/4/9 → GB/T 2261.2 的 10/20/30/40/90
        ('CT_Marital',       '1', '未婚',   '10', 'PA_PatMas', 'maritalstatus',
         'GB/T 2261.2 基线；源侧未出现 5 婚姻存续期间，故未配 21/22/23'),
        ('CT_Marital',       '2', '已婚',   '20', 'PA_PatMas', 'maritalstatus', 'GB/T 2261.2 基线'),
        ('CT_Marital',       '3', '丧偶',   '30', 'PA_PatMas', 'maritalstatus', 'GB/T 2261.2 基线'),
        ('CT_Marital',       '4', '离婚',   '40', 'PA_PatMas', 'maritalstatus', 'GB/T 2261.2 基线'),
        ('CT_Marital',       '9', '未说明', '90', 'PA_PatMas', 'maritalstatus',
         'GB/T 2261.2 基线；90 = 未说明的婚姻状况'),

        -- 就诊类型：源 1/2/3 → 医疗数据字典 CT01.00.001 的 01 门诊 / 03 住院 / 02 急诊
        ('CT_EncounterType', '1', '门诊',   '01', 'PA_Adm', 'admtype',
         'CT01.00.001 基线；源侧 admtype=1 无出院日期，判为门诊'),
        ('CT_EncounterType', '2', '住院',   '03', 'PA_Adm', 'admtype',
         'CT01.00.001 基线；已用出院日期反证：admtype=2 全部有出院日期'),
        ('CT_EncounterType', '3', '急诊',   '02', 'PA_Adm', 'admtype',
         'CT01.00.001 基线；源侧未出现该值，按语义映射，待院方确认'),

        -- 性别：源 M/F → GB/T 2261.1 的 1 男性 / 2 女性
        ('CT_Sex',           'M', '男',     '1',  'PA_PatMas', 'sex', 'GB/T 2261.1 基线'),
        ('CT_Sex',           'F', '女',     '2',  'PA_PatMas', 'sex', 'GB/T 2261.1 基线'),

        -- 执行频次：源 qd/bid/tid/q8h → CV06.00.228 的 09/01/tid/08
        ('CT_Frequency',     'qd',  '每日一次',   '09',  'OE_Order', 'frequency',
         'CV06.00.228；09 = qd'),
        ('CT_Frequency',     'bid', '每日两次',   '01',  'OE_Order', 'frequency',
         'CV06.00.228；01 = bid'),
        ('CT_Frequency',     'q8h', '每8小时一次', '08',  'OE_Order', 'frequency',
         'CV06.00.228；08 = q8h'),
        ('CT_Frequency',     'tid', '每日三次',   'tid', 'OE_Order', 'frequency',
         '标准表无 tid（CV06.00.228 只有 bid/qid 等），保留院内原值，已标 is_extension=1'),

        -- 给药途径：源 PO/IM/IV → CV06.00.102 的 1/403/404
        ('CT_Route',         'PO', '口服',     '1',   'OE_Order', 'route',
         'CV06.00.102；1 = 口服'),
        ('CT_Route',         'IM', '肌肉注射', '403', 'OE_Order', 'route',
         'CV06.00.102；403 = 肌肉注射'),
        ('CT_Route',         'IV', '静脉注射', '404', 'OE_Order', 'route',
         'CV06.00.102；404 = 静脉注射或静脉滴注（标准未单列静脉注射）'),

        -- 科室：源 DEP01-DEP05 → CT08.00.002 业务科室分类与代码
        ('CT_Loc', 'DEP01', '心血管内科', 'A03.04', 'PA_Adm', 'deptid', 'CT08.00.002；A03.04 心血管内科专业'),
        ('CT_Loc', 'DEP02', '呼吸内科',   'A03.01', 'PA_Adm', 'deptid', 'CT08.00.002；A03.01 呼吸内科专业'),
        ('CT_Loc', 'DEP03', '消化内科',   'A03.02', 'PA_Adm', 'deptid', 'CT08.00.002；A03.02 消化内科专业'),
        ('CT_Loc', 'DEP04', '骨科',       'A04.03', 'PA_Adm', 'deptid', 'CT08.00.002；A04.03 骨科专业'),
        ('CT_Loc', 'DEP05', '妇产科',     'A05',    'PA_Adm', 'deptid', 'CT08.00.002；A05 妇产科')
)
INSERT INTO dam_standard.code_crosswalk (code_table_id, code_table_code, code_table_name,
                                source_system, source_table, source_column,
                                source_value, source_name,
                                target_value, target_name, remark)
SELECT t.id, t.code_table_code, t.code_table_name,
       'HIS', m.source_table, m.source_column,
       m.source_value, m.source_name,
       m.target_value, sv.code_name,
       m.remark
FROM m
JOIN dam_standard.standard_code_table t
  ON t.code_table_code = m.code_table_code AND t.deleted_at IS NULL
LEFT JOIN dam_standard.standard_code_value sv
  ON sv.code_table_id = t.id AND sv.code_value = m.target_value AND sv.deleted_at IS NULL
ON CONFLICT (code_table_id, source_system, source_value) WHERE deleted_at IS NULL
DO UPDATE SET
    target_value = EXCLUDED.target_value,
    target_name  = EXCLUDED.target_name,
    source_table = COALESCE(EXCLUDED.source_table, dam_standard.code_crosswalk.source_table),
    source_column= COALESCE(EXCLUDED.source_column, dam_standard.code_crosswalk.source_column),
    source_name  = EXCLUDED.source_name,
    remark       = EXCLUDED.remark,
    updated_at   = now();

-- 存量行补齐源表/源字段定位（早期版本插入时未带这两列）
UPDATE dam_standard.code_crosswalk SET source_table = 'PA_PatMas', source_column = 'sex'
 WHERE code_table_code = 'CT_Sex' AND source_table IS NULL;
UPDATE dam_standard.code_crosswalk SET source_table = 'PA_PatMas', source_column = 'maritalstatus'
 WHERE code_table_code = 'CT_Marital' AND source_table IS NULL;
UPDATE dam_standard.code_crosswalk SET source_table = 'PA_Adm', source_column = 'admtype'
 WHERE code_table_code = 'CT_EncounterType' AND source_table IS NULL;
UPDATE dam_standard.code_crosswalk SET source_table = 'OE_Order', source_column = 'frequency'
 WHERE code_table_code = 'CT_Frequency' AND source_table IS NULL;
UPDATE dam_standard.code_crosswalk SET source_table = 'OE_Order', source_column = 'route'
 WHERE code_table_code = 'CT_Route' AND source_table IS NULL;
UPDATE dam_standard.code_crosswalk SET source_table = 'PA_Adm', source_column = 'deptid'
 WHERE code_table_code = 'CT_Loc' AND source_table IS NULL;

-- ---------------------------------------------------------------------
-- 校验：任何 target_value 在标准码表中不存在，都会在这里暴露为 dangling
-- ---------------------------------------------------------------------
DO $$
DECLARE
    bad integer;
    dangling text;
BEGIN
    SELECT count(*) INTO bad
    FROM dam_standard.code_crosswalk c
    LEFT JOIN dam_standard.standard_code_value v
           ON v.code_table_id = c.code_table_id
          AND v.code_value = c.target_value
          AND v.deleted_at IS NULL
    WHERE c.deleted_at IS NULL AND v.id IS NULL;

    IF bad > 0 THEN
        SELECT string_agg(code_table_code || ':' || source_value || '->' || target_value, ', ')
          INTO dangling
          FROM dam_standard.code_crosswalk c
         WHERE c.deleted_at IS NULL
           AND NOT EXISTS (
               SELECT 1 FROM dam_standard.standard_code_value v
                WHERE v.code_table_id = c.code_table_id
                  AND v.code_value = c.target_value
                  AND v.deleted_at IS NULL
           );
        RAISE EXCEPTION '代码对照有 % 条指向了标准码表中不存在的码值：%', bad, dangling;
    END IF;

    RAISE NOTICE '代码对照校验通过：% 条有效，全部指向标准码表中存在的值',
        (SELECT count(*) FROM dam_standard.code_crosswalk WHERE deleted_at IS NULL);
END $$;
