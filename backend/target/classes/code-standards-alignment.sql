-- =====================================================================
-- 标准码表对齐国标 / 行标
-- 依据：国家卫生健康委《全国医院数据上报管理方案 医疗数据字典（试行）》
--       WS/T 364—2023《卫生健康信息数据元值域代码》
--       GB/T 2261、GB 3304 等基础国家标准
-- 说明：幂等脚本，可重复执行。码值为软删除后重建，保留历史版本。
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. 表结构增强：记录码表的标准出处
-- ---------------------------------------------------------------------
ALTER TABLE dam_standard.standard_code_table ADD COLUMN IF NOT EXISTS standard_source  varchar(16);
ALTER TABLE dam_standard.standard_code_table ADD COLUMN IF NOT EXISTS standard_id      varchar(64);
ALTER TABLE dam_standard.standard_code_table ADD COLUMN IF NOT EXISTS standard_name    varchar(255);
ALTER TABLE dam_standard.standard_code_table ADD COLUMN IF NOT EXISTS standard_version varchar(32);

ALTER TABLE dam_standard.standard_code_value ADD COLUMN IF NOT EXISTS is_extension smallint NOT NULL DEFAULT 0;

COMMENT ON COLUMN dam_standard.standard_code_table.standard_source  IS '标准层级：GB=国家标准 / WS=卫生行业标准 / NHC=卫健委数据字典 / LOCAL=院内扩展';
COMMENT ON COLUMN dam_standard.standard_code_table.standard_id      IS '标准中该码表的编号，如 GB/T 2261.1-2003、CV02.01.101、CT01.00.001';
COMMENT ON COLUMN dam_standard.standard_code_table.standard_name    IS '标准全称';
COMMENT ON COLUMN dam_standard.standard_code_table.standard_version IS '标准版本/发布日期';
COMMENT ON COLUMN dam_standard.standard_code_value.is_extension     IS '1=标准中无此值的院内扩展，0=标准值';

-- ---------------------------------------------------------------------
-- 2. 标注每张码表的标准出处
-- ---------------------------------------------------------------------
UPDATE dam_standard.standard_code_table t SET
    standard_source = v.src, standard_id = v.sid, standard_name = v.sname, standard_version = v.ver
FROM (VALUES
    -- 基础国家标准
    ('CT_Sex',           'GB',     'GB/T 2261.1-2003', '个人基本信息分类与代码 第1部分：人的性别代码',                 '2003'),
    ('CT_Marital',       'GB',     'GB/T 2261.2-2003', '个人基本信息分类与代码 第2部分：婚姻状况代码',                 '2003'),
    ('CT_Nation',        'GB',     'GB 3304-1991',     '中国各民族名称的罗马字母拼写法和代码',                       '1991'),
    ('CT_ICD10',         'GB',     'GB/T 14396-2016',  '疾病分类与代码（对应国家临床版 2.0）',                       '2016'),
    -- 卫生行业标准 WS/T 364
    ('CT_IDCardType',    'WS',     'CV02.01.101',      'WS/T 364.3 卫生健康信息数据元值域代码 第3部分：身份证件类别代码',  '2023'),
    ('CT_Route',         'WS',     'CV06.00.102',      'WS/T 364.12 卫生健康信息数据元值域代码 第12部分：用药途径代码',   '2023'),
    ('CT_Frequency',     'WS',     'CV06.00.228',      'WS/T 364.12 卫生健康信息数据元值域代码 第12部分：药物使用频次代码', '2023'),
    ('CT_InsureType',    'WS',     'CV07.00.003',      'WS/T 364.13 卫生健康信息数据元值域代码 第13部分：医疗费用来源类别代码', '2023'),
    -- 国家卫生健康委数据字典
    ('CT_EncounterType', 'NHC',    'CT01.00.001',      '全国医院数据上报管理方案 医疗数据字典：业务活动类别代码',        '2019'),
    ('CT_FeeType',       'NHC',    'CT07.00.001',      '全国医院数据上报管理方案 医疗数据字典：费用项目类别代码',        '2019'),
    ('CT_Loc',           'NHC',    'CT08.00.002',      '全国医院数据上报管理方案 运营数据字典：科室代码（医疗卫生机构业务科室分类与代码）', '2019'),
    ('CT_OrderType',     'WS',     'CV06.00.229',      'WS/T 364.12 卫生健康信息数据元值域代码 第12部分：医嘱项目类型代码', '2023'),
    -- 手术操作分类与代码为卫健委托管发布的行业分类，非 GB/WS 编号
    ('CT_ICD9CM3',       'NHC',    'ICD-9-CM-3-2017',  '手术操作分类与代码（2017版，对应国家临床版 2.0）',              '2017'),
    -- 标准中无对应码表，属院内扩展
    ('CT_Ward',          'LOCAL',  NULL,               '院内病区编码，标准中无对应码表',                            NULL),
    ('CT_CareProv',      'LOCAL',  NULL,               '院内医护技人员编码，标准中无对应码表',                      NULL),
    ('CT_Pharmacy',      'LOCAL',  NULL,               '院内药品编码，标准中无院内药品字典（国家医保药品编码为支付端编码，非院内字典）', NULL),
    ('CT_LabItem',       'LOCAL',  NULL,               '院内检验项目编码，标准中无院内项目字典',                    NULL),
    ('CT_ExamItem',      'LOCAL',  NULL,               '院内检查项目编码，标准中无院内项目字典',                    NULL),
    ('CT_Material',      'LOCAL',  NULL,               '院内卫生材料编码，标准 CT98.00.017 为材料分类非具体材料',    NULL),
    ('CT_AppointType',   'LOCAL',  NULL,               '院内预约类型，标准中无对应码表',                            NULL),
    ('CT_EMRDocType',    'LOCAL',  NULL,               '院内病历文书类型，标准中无对应码表',                        NULL),
    ('CT_SecLevel',      'LOCAL',  NULL,               '院内数据密级，参照《数据安全法》与卫生健康行业数据分类分级指南，无枚举码表', NULL),
    ('CT_Unit',          'LOCAL',  NULL,               '药用计量单位，符号取自 GB/T 3100 国际单位制，标准中无院内单位码表', NULL)
) AS v(code_table_code, src, sid, sname, ver)
WHERE t.code_table_code = v.code_table_code AND t.deleted_at IS NULL;

-- ---------------------------------------------------------------------
-- 3. 新增「医嘱项目类型」码表（原平台缺失，导致 DWD 医嘱类型无标准可依）
-- ---------------------------------------------------------------------
INSERT INTO dam_standard.standard_code_table
    (code_table_code, code_table_name, code_table_type, description, status,
     standard_source, standard_id, standard_name, standard_version)
SELECT 'CT_OrderType', '医嘱项目类型字典', 'DIM_Orders_Execution',
       '医嘱项目按内容分为药品、检查、检验、手术、处置、材料、嘱托、输血八类', 1,
       'WS', 'CV06.00.229',
       'WS/T 364.12 卫生健康信息数据元值域代码 第12部分：医嘱项目类型代码', '2023'
WHERE NOT EXISTS (
    SELECT 1 FROM dam_standard.standard_code_table
    WHERE code_table_code = 'CT_OrderType' AND deleted_at IS NULL
);

-- ---------------------------------------------------------------------
-- 4. 重建码值：先软删旧版，再按标准全量插入
-- ---------------------------------------------------------------------
UPDATE dam_standard.standard_code_value v
SET deleted_at = now()
FROM dam_standard.standard_code_table t
WHERE v.code_table_id = t.id
  AND v.deleted_at IS NULL
  AND t.deleted_at IS NULL
  AND t.code_table_code IN (
      'CT_Sex', 'CT_Marital', 'CT_Nation', 'CT_IDCardType', 'CT_EncounterType',
      'CT_Route', 'CT_Frequency', 'CT_InsureType', 'CT_FeeType', 'CT_Loc', 'CT_OrderType'
  );

INSERT INTO dam_standard.standard_code_value
    (code_table_id, code_value, code_name, sort_order, status, description, is_extension)
SELECT t.id::int, s.code_value, s.code_name, s.sort_order, 1, s.note, s.ext
FROM (VALUES
    -- ============ GB/T 2261.1-2003 人的性别代码 ============
    ('CT_Sex', '0', '未知的性别',     10, 'GB/T 2261.1 原文', 0),
    ('CT_Sex', '1', '男性',           20, 'GB/T 2261.1 原文', 0),
    ('CT_Sex', '2', '女性',           30, 'GB/T 2261.1 原文', 0),
    ('CT_Sex', '9', '未说明的性别',   40, 'GB/T 2261.1 原文', 0),

    -- ============ GB/T 2261.2-2003 婚姻状况代码 ============
    ('CT_Marital', '10', '未婚',               10, 'GB/T 2261.2 原文', 0),
    ('CT_Marital', '20', '已婚',               20, 'GB/T 2261.2 原文', 0),
    ('CT_Marital', '21', '初婚',               30, 'GB/T 2261.2 原文', 0),
    ('CT_Marital', '22', '再婚',               40, 'GB/T 2261.2 原文', 0),
    ('CT_Marital', '23', '复婚',               50, 'GB/T 2261.2 原文', 0),
    ('CT_Marital', '30', '丧偶',               60, 'GB/T 2261.2 原文', 0),
    ('CT_Marital', '40', '离婚',               70, 'GB/T 2261.2 原文', 0),
    ('CT_Marital', '90', '未说明的婚姻状况',   99, 'GB/T 2261.2 原文', 0),

    -- ============ GB 3304-1991 民族代码 ============
    ('CT_Nation', '01', '汉族',       1, NULL, 0), ('CT_Nation', '02', '蒙古族',     2, NULL, 0),
    ('CT_Nation', '03', '回族',       3, NULL, 0), ('CT_Nation', '04', '藏族',       4, NULL, 0),
    ('CT_Nation', '05', '维吾尔族',   5, NULL, 0), ('CT_Nation', '06', '苗族',       6, NULL, 0),
    ('CT_Nation', '07', '彝族',       7, NULL, 0), ('CT_Nation', '08', '壮族',       8, NULL, 0),
    ('CT_Nation', '09', '布依族',     9, NULL, 0), ('CT_Nation', '10', '朝鲜族',    10, NULL, 0),
    ('CT_Nation', '11', '满族',      11, NULL, 0), ('CT_Nation', '12', '侗族',      12, NULL, 0),
    ('CT_Nation', '13', '瑶族',      13, NULL, 0), ('CT_Nation', '14', '白族',      14, NULL, 0),
    ('CT_Nation', '15', '土家族',    15, NULL, 0), ('CT_Nation', '16', '哈尼族',    16, NULL, 0),
    ('CT_Nation', '17', '哈萨克族',  17, NULL, 0), ('CT_Nation', '18', '傣族',      18, NULL, 0),
    ('CT_Nation', '19', '黎族',      19, NULL, 0), ('CT_Nation', '20', '傈僳族',    20, NULL, 0),
    ('CT_Nation', '21', '佤族',      21, NULL, 0), ('CT_Nation', '22', '畲族',      22, NULL, 0),
    ('CT_Nation', '23', '高山族',    23, NULL, 0), ('CT_Nation', '24', '拉祜族',    24, NULL, 0),
    ('CT_Nation', '25', '水族',      25, NULL, 0), ('CT_Nation', '26', '东乡族',    26, NULL, 0),
    ('CT_Nation', '27', '纳西族',    27, NULL, 0), ('CT_Nation', '28', '景颇族',    28, NULL, 0),
    ('CT_Nation', '29', '柯尔克孜族',29, NULL, 0), ('CT_Nation', '30', '土族',      30, NULL, 0),
    ('CT_Nation', '31', '达斡尔族',  31, NULL, 0), ('CT_Nation', '32', '仫佬族',    32, NULL, 0),
    ('CT_Nation', '33', '羌族',      33, NULL, 0), ('CT_Nation', '34', '布朗族',    34, NULL, 0),
    ('CT_Nation', '35', '撒拉族',    35, NULL, 0), ('CT_Nation', '36', '毛南族',    36, NULL, 0),
    ('CT_Nation', '37', '仡佬族',    37, NULL, 0), ('CT_Nation', '38', '锡伯族',    38, NULL, 0),
    ('CT_Nation', '39', '阿昌族',    39, NULL, 0), ('CT_Nation', '40', '普米族',    40, NULL, 0),
    ('CT_Nation', '41', '塔吉克族',  41, NULL, 0), ('CT_Nation', '42', '怒族',      42, NULL, 0),
    ('CT_Nation', '43', '乌孜别克族',43, NULL, 0), ('CT_Nation', '44', '俄罗斯族',  44, NULL, 0),
    ('CT_Nation', '45', '鄂温克族',  45, NULL, 0), ('CT_Nation', '46', '德昂族',    46, NULL, 0),
    ('CT_Nation', '47', '保安族',    47, NULL, 0), ('CT_Nation', '48', '裕固族',    48, NULL, 0),
    ('CT_Nation', '49', '京族',      49, NULL, 0), ('CT_Nation', '50', '塔塔尔族',  50, NULL, 0),
    ('CT_Nation', '51', '独龙族',    51, NULL, 0), ('CT_Nation', '52', '鄂伦春族',  52, NULL, 0),
    ('CT_Nation', '53', '赫哲族',    53, NULL, 0), ('CT_Nation', '54', '门巴族',    54, NULL, 0),
    ('CT_Nation', '55', '珞巴族',    55, NULL, 0), ('CT_Nation', '56', '基诺族',    56, NULL, 0),
    ('CT_Nation', '97', '其他',      97, 'GB 3304 未定义，按民政/人社口径扩展', 1),
    ('CT_Nation', '98', '外国血统中国籍人士', 98, 'GB 3304 未定义，按民政部 C0009 口径扩展', 1),

    -- ============ WS/T 364.3 CV02.01.101 身份证件类别代码 ============
    ('CT_IDCardType', '01', '居民身份证',                 1, 'CV02.01.101 原文', 0),
    ('CT_IDCardType', '02', '居民户口簿',                 2, 'CV02.01.101 原文', 0),
    ('CT_IDCardType', '03', '护照',                       3, 'CV02.01.101 原文', 0),
    ('CT_IDCardType', '04', '军官证',                     4, 'CV02.01.101 原文', 0),
    ('CT_IDCardType', '05', '驾驶证',                     5, 'CV02.01.101 原文', 0),
    ('CT_IDCardType', '06', '港澳居民来往内地通行证',     6, 'CV02.01.101 原文', 0),
    ('CT_IDCardType', '07', '台湾居民来往大陆通行证',     7, 'CV02.01.101 原文', 0),
    ('CT_IDCardType', '08', '临时居民身份证',             8, 'CV02.01.101 原文', 0),
    ('CT_IDCardType', '09', '武装警察身份证件',           9, 'CV02.01.101 原文', 0),
    ('CT_IDCardType', '10', '中华人民共和国港澳居民居住证', 10, 'CV02.01.101 原文', 0),
    ('CT_IDCardType', '11', '中华人民共和国台湾居民居住证', 11, 'CV02.01.101 原文', 0),
    ('CT_IDCardType', '12', '社会保障卡',                12, 'CV02.01.101 原文', 0),
    ('CT_IDCardType', '99', '其他法定有效证件',          99, 'CV02.01.101 原文', 0),

    -- ============ NHC CT01.00.001 业务活动类别代码（就诊类型） ============
    ('CT_EncounterType', '01', '门诊', 1, 'CT01.00.001 原文', 0),
    ('CT_EncounterType', '02', '急诊', 2, 'CT01.00.001 原文', 0),
    ('CT_EncounterType', '03', '住院', 3, 'CT01.00.001 原文', 0),
    ('CT_EncounterType', '04', '体检', 4, 'CT01.00.001 原文', 0),
    ('CT_EncounterType', '05', '运营', 5, 'CT01.00.001 原文', 0),
    ('CT_EncounterType', '09', '其他', 9, 'CT01.00.001 原文', 0),

    -- ============ WS/T 364.12 CV06.00.102 用药途径代码 ============
    ('CT_Route', '1',   '口服',               10,  '经口吞服药物', 0),
    ('CT_Route', '2',   '直肠用药',           20,  '经肛门塞入或注入直肠', 0),
    ('CT_Route', '3',   '舌下用药',           30,  '置于舌下/颊部', 0),
    ('CT_Route', '4',   '注射用药',           40,  '经表皮注入体内（大类）', 0),
    ('CT_Route', '401', '皮下注射',           41,  '注射于皮下组织', 0),
    ('CT_Route', '402', '皮内注射',           42,  '注射于皮内组织', 0),
    ('CT_Route', '403', '肌肉注射',           43,  '注射于肌肉组织内', 0),
    ('CT_Route', '404', '静脉注射或静脉滴注', 44,  '注入静脉血管内', 0),
    ('CT_Route', '405', '鞘内注射',           45,  '经腰穿注入蛛网膜下腔', 0),
    ('CT_Route', '5',   '吸入用药',           50,  '雾化后经呼吸道吸入', 0),
    ('CT_Route', '6',   '局部用药',           60,  '主要发挥局部作用（大类）', 0),
    ('CT_Route', '601', '椎管内用药',         61,  NULL, 0),
    ('CT_Route', '602', '关节腔内用药',       62,  NULL, 0),
    ('CT_Route', '603', '胸膜腔用药',         63,  NULL, 0),
    ('CT_Route', '604', '腹腔用药',           64,  NULL, 0),
    ('CT_Route', '605', '阴道用药',           65,  NULL, 0),
    ('CT_Route', '606', '气管内用药',         66,  NULL, 0),
    ('CT_Route', '607', '滴眼',               67,  NULL, 0),
    ('CT_Route', '608', '滴鼻',               68,  NULL, 0),
    ('CT_Route', '609', '喷喉',               69,  NULL, 0),
    ('CT_Route', '610', '含化',               70,  NULL, 0),
    ('CT_Route', '611', '敷伤口',             71,  NULL, 0),
    ('CT_Route', '612', '擦皮肤',             72,  NULL, 0),
    ('CT_Route', '699', '其他局部用药途径',   79,  NULL, 0),
    ('CT_Route', '7',   '经皮用药',           80,  '经皮肤吸收进入人体', 0),
    ('CT_Route', '9',   '其他用药途径',       99,  NULL, 0),

    -- ============ WS/T 364.12 CV06.00.228 药物使用频次代码 ============
    -- 标准「值」为 2 位数字，「值含义」为英文缩写，「说明」为中文频次
    ('CT_Frequency', '01', '每日两次',       1, '值含义 bid，2次/天', 0),
    ('CT_Frequency', '02', '每周两次',       2, '值含义 biw，2次/周', 0),
    ('CT_Frequency', '03', '睡前服用',       3, '值含义 Hs', 0),
    ('CT_Frequency', '04', '每12小时一次',   4, '值含义 q12h，1次/12小时', 0),
    ('CT_Frequency', '05', '每小时一次',     5, '值含义 q1h，1次/小时', 0),
    ('CT_Frequency', '06', '每3小时一次',    6, '值含义 q3h，1次/3小时', 0),
    ('CT_Frequency', '07', '每6小时一次',    7, '值含义 q6h，1次/6小时', 0),
    ('CT_Frequency', '08', '每8小时一次',    8, '值含义 q8h，1次/8小时', 0),
    ('CT_Frequency', '09', '每日一次',       9, '值含义 qd，1次/天', 0),
    ('CT_Frequency', '10', '每日四次',      10, '值含义 qid，4次/天', 0),
    ('CT_Frequency', '11', '隔天一次',      11, '值含义 qod', 0),
    ('CT_Frequency', '12', '每周一次',      12, '值含义 qw，1次/周', 0),
    ('CT_Frequency', '13', '立即服用',      13, '值含义 st', 0),
    ('CT_Frequency', '99', '其他',          99, '标准兜底值', 0),
    -- 标准中无「每日三次」「必要时」，作院内扩展保留，不强行归并到 99 以免丢语义
    ('CT_Frequency', 'tid', '每日三次',     21, '标准表无此值，院内扩展；对应常见写法 tid', 1),
    ('CT_Frequency', 'prn', '必要时',       22, '标准表无此值，院内扩展；对应常见写法 prn', 1),

    -- ============ WS/T 364.13 CV07.00.003 医疗费用来源类别代码 ============
    ('CT_InsureType', '01', '城镇职工基本医疗保险', 1, 'CV07.00.003 原文', 0),
    ('CT_InsureType', '02', '城镇居民基本医疗保险', 2, 'CV07.00.003 原文', 0),
    ('CT_InsureType', '03', '新型农村合作医疗',     3, 'CV07.00.003 原文', 0),
    ('CT_InsureType', '04', '贫困救助',             4, 'CV07.00.003 原文', 0),
    ('CT_InsureType', '05', '商业医疗保险',         5, 'CV07.00.003 原文', 0),
    ('CT_InsureType', '06', '全公费',               6, 'CV07.00.003 原文', 0),
    ('CT_InsureType', '07', '全自费',               7, 'CV07.00.003 原文', 0),
    ('CT_InsureType', '08', '基金救助',             8, 'CV07.00.003-2023 新增', 0),
    ('CT_InsureType', '09', '其他社会保险',         9, 'CV07.00.003-2023 新增', 0),
    ('CT_InsureType', '99', '其他',                99, 'CV07.00.003 原文', 0),

    -- ============ NHC CT07.00.001 费用项目类别代码 ============
    ('CT_FeeType', '1',  '药品',         10, '一级类目', 0),
    ('CT_FeeType', '11', '西药费',       11, '隶属 1 药品', 0),
    ('CT_FeeType', '12', '中成药费',     12, '隶属 1 药品', 0),
    ('CT_FeeType', '13', '中草药费',     13, '隶属 1 药品', 0),
    ('CT_FeeType', '2',  '诊疗项目',     20, '一级类目', 0),
    ('CT_FeeType', '21', '床位费',       21, '隶属 2 诊疗项目', 0),
    ('CT_FeeType', '22', '诊疗费',       22, '隶属 2 诊疗项目', 0),
    ('CT_FeeType', '23', '检查费',       23, '隶属 2 诊疗项目', 0),
    ('CT_FeeType', '24', '化验费',       24, '隶属 2 诊疗项目', 0),
    ('CT_FeeType', '25', '治疗费',       25, '隶属 2 诊疗项目', 0),
    ('CT_FeeType', '26', '手术费',       26, '隶属 2 诊疗项目', 0),
    ('CT_FeeType', '27', '护理费',       27, '隶属 2 诊疗项目', 0),
    ('CT_FeeType', '28', '药事服务费',   28, '隶属 2 诊疗项目', 0),
    ('CT_FeeType', '29', '一般诊疗费',   29, '隶属 2 诊疗项目', 0),
    ('CT_FeeType', '3',  '卫生材料',     30, '一级类目', 0),
    ('CT_FeeType', '31', '卫生材料费',   31, '隶属 3 卫生材料', 0),
    ('CT_FeeType', '9',  '其他',         90, '一级类目', 0),
    ('CT_FeeType', '91', '其他收费',     91, '隶属 9 其他', 0),

    -- ============ NHC CT08.00.002 科室代码（医疗卫生机构业务科室分类与代码） ============
    ('CT_Loc', 'A01',     '预防保健科',       1,  '一级科目', 0),
    ('CT_Loc', 'A02',     '全科医疗科',       2,  '一级科目', 0),
    ('CT_Loc', 'A03',     '内科',             3,  '一级科目', 0),
    ('CT_Loc', 'A03.01',  '呼吸内科专业',     31, '隶属 A03 内科', 0),
    ('CT_Loc', 'A03.02',  '消化内科专业',     32, '隶属 A03 内科', 0),
    ('CT_Loc', 'A03.03',  '神经内科专业',     33, '隶属 A03 内科', 0),
    ('CT_Loc', 'A03.04',  '心血管内科专业',   34, '隶属 A03 内科', 0),
    ('CT_Loc', 'A03.05',  '血液内科专业',     35, '隶属 A03 内科', 0),
    ('CT_Loc', 'A03.06',  '肾病学专业',       36, '隶属 A03 内科', 0),
    ('CT_Loc', 'A03.07',  '内分泌专业',       37, '隶属 A03 内科', 0),
    ('CT_Loc', 'A03.08',  '免疫学专业',       38, '隶属 A03 内科', 0),
    ('CT_Loc', 'A03.09',  '变态反应专业',     39, '隶属 A03 内科', 0),
    ('CT_Loc', 'A03.10',  '老年病专业',       40, '隶属 A03 内科', 0),
    ('CT_Loc', 'A03.11',  '其他',             49, '隶属 A03 内科', 0),
    ('CT_Loc', 'A04',     '外科',             50, '一级科目', 0),
    ('CT_Loc', 'A04.01',  '普通外科专业',     51, '隶属 A04 外科', 0),
    ('CT_Loc', 'A04.02',  '神经外科专业',     52, '隶属 A04 外科', 0),
    ('CT_Loc', 'A04.03',  '骨科专业',         53, '隶属 A04 外科', 0),
    ('CT_Loc', 'A04.04',  '泌尿外科专业',     54, '隶属 A04 外科', 0),
    ('CT_Loc', 'A04.05',  '胸外科专业',       55, '隶属 A04 外科', 0),
    ('CT_Loc', 'A04.06',  '心脏大血管外科专业', 56, '隶属 A04 外科', 0),
    ('CT_Loc', 'A04.07',  '烧伤科专业',       57, '隶属 A04 外科', 0),
    ('CT_Loc', 'A04.08',  '整形外科专业',     58, '隶属 A04 外科', 0),
    ('CT_Loc', 'A04.09',  '其他',             59, '隶属 A04 外科', 0),
    ('CT_Loc', 'A05',     '妇产科',           60, '一级科目', 0),
    ('CT_Loc', 'A05.01',  '妇科专业',         61, '隶属 A05 妇产科', 0),
    ('CT_Loc', 'A05.02',  '产科专业',         62, '隶属 A05 妇产科', 0),
    ('CT_Loc', 'A05.03',  '计划生育专业',     63, '隶属 A05 妇产科', 0),
    ('CT_Loc', 'A05.04',  '优生学专业',       64, '隶属 A05 妇产科', 0),
    ('CT_Loc', 'A05.05',  '生殖健康与不孕症专业', 65, '隶属 A05 妇产科', 0),
    ('CT_Loc', 'A05.06',  '其他',             69, '隶属 A05 妇产科', 0),
    ('CT_Loc', 'A06',     '妇女保健科',       70, '一级科目', 0),
    ('CT_Loc', 'A07',     '儿科',             80, '一级科目', 0),
    ('CT_Loc', 'A07.01',  '新生儿专业',       81, '隶属 A07 儿科', 0),
    ('CT_Loc', 'A08',     '小儿外科',         90, '一级科目', 0),
    ('CT_Loc', 'A09',     '儿童保健科',      100, '一级科目', 0),
    ('CT_Loc', 'A10',     '眼科',            110, '一级科目', 0),
    ('CT_Loc', 'A11',     '耳鼻咽喉科',      120, '一级科目', 0),
    ('CT_Loc', 'A12',     '口腔科',          130, '一级科目', 0),
    ('CT_Loc', 'A13',     '皮肤科',          140, '一级科目', 0),
    ('CT_Loc', 'A14',     '医疗美容科',      150, '一级科目', 0),
    ('CT_Loc', 'A15',     '精神科',          160, '一级科目', 0),
    ('CT_Loc', 'A16',     '传染科',          170, '一级科目', 0),
    ('CT_Loc', 'A17',     '结核病科',        180, '一级科目', 0),
    ('CT_Loc', 'A18',     '地方病科',        190, '一级科目', 0),
    ('CT_Loc', 'A19',     '肿瘤科',          200, '一级科目', 0),
    ('CT_Loc', 'A20',     '急诊医学科',      210, '一级科目', 0),
    ('CT_Loc', 'A21',     '康复医学科',      220, '一级科目', 0),
    ('CT_Loc', 'A22',     '运动医学科',      230, '一级科目', 0),
    ('CT_Loc', 'A23',     '职业病科',        240, '一级科目', 0),
    ('CT_Loc', 'A24',     '临终关怀科',      250, '一级科目', 0),
    ('CT_Loc', 'A25',     '特种医学与军事医学科', 260, '一级科目', 0),
    ('CT_Loc', 'A26',     '麻醉科',          270, '一级科目', 0),
    ('CT_Loc', 'A27',     '疼痛科',          280, '一级科目（限二级以上医院）', 0),
    ('CT_Loc', 'A28',     '重症医学科',      290, '一级科目（限二级以上综合医院）', 0),
    ('CT_Loc', 'A30',     '医学检验科',      310, '一级科目（29 号位标准中未使用）', 0),
    ('CT_Loc', 'A31',     '病理科',          320, '一级科目', 0),
    ('CT_Loc', 'A32',     '医学影像科',      330, '一级科目', 0),
    ('CT_Loc', 'A32.01',  'X线诊断专业',     331, '隶属 A32 医学影像科', 0),
    ('CT_Loc', 'A32.02',  'CT诊断专业',      332, '隶属 A32 医学影像科', 0),
    ('CT_Loc', 'A32.03',  '磁共振成像诊断专业', 333, '隶属 A32 医学影像科', 0),
    ('CT_Loc', 'A32.04',  '核医学专业',      334, '隶属 A32 医学影像科', 0),
    ('CT_Loc', 'A32.05',  '超声诊断专业',    335, '隶属 A32 医学影像科', 0),
    ('CT_Loc', 'A32.06',  '心电诊断专业',    336, '隶属 A32 医学影像科', 0),
    ('CT_Loc', 'A32.07',  '脑电及脑血流图诊断专业', 337, '隶属 A32 医学影像科', 0),
    ('CT_Loc', 'A32.08',  '神经肌肉电图专业', 338, '隶属 A32 医学影像科', 0),
    ('CT_Loc', 'A32.09',  '介入放射学专业',  339, '隶属 A32 医学影像科', 0),
    ('CT_Loc', 'A32.10',  '放射治疗专业',    340, '隶属 A32 医学影像科', 0),
    ('CT_Loc', 'A32.11',  '其他',            349, '隶属 A32 医学影像科', 0),
    ('CT_Loc', 'A50',     '中医科',          500, '一级科目', 0),
    ('CT_Loc', 'A51',     '民族医学科',      510, '一级科目', 0),
    ('CT_Loc', 'A52',     '中西医结合科',    520, '一级科目', 0),

    -- ============ WS/T 364.12 CV06.00.229 医嘱项目类型代码 ============
    ('CT_OrderType', '01', '药品类医嘱', 1, 'CV06.00.229 原文', 0),
    ('CT_OrderType', '02', '检查类医嘱', 2, 'CV06.00.229 原文', 0),
    ('CT_OrderType', '03', '检验类医嘱', 3, 'CV06.00.229 原文', 0),
    ('CT_OrderType', '04', '手术类医嘱', 4, 'CV06.00.229 原文', 0),
    ('CT_OrderType', '05', '处置类医嘱', 5, 'CV06.00.229 原文', 0),
    ('CT_OrderType', '06', '材料类医嘱', 6, 'CV06.00.229 原文', 0),
    ('CT_OrderType', '07', '嘱托医嘱',   7, 'CV06.00.229 原文', 0),
    ('CT_OrderType', '08', '输血类医嘱', 8, 'CV06.00.229 原文', 0),
    ('CT_OrderType', '99', '其他医嘱',  99, 'CV06.00.229 原文', 0)
) AS s(code_table_code, code_value, code_name, sort_order, note, ext)
JOIN dam_standard.standard_code_table t
  ON t.code_table_code = s.code_table_code AND t.deleted_at IS NULL;

-- ---------------------------------------------------------------------
-- 5. 校验：码表与码值数量
-- ---------------------------------------------------------------------
DO $$
DECLARE
    r record;
    total_tables int;
    total_values int;
    gb_tables int;
BEGIN
    SELECT count(*) FILTER (WHERE standard_source IN ('GB','WS','NHC')),
           count(*)
      INTO gb_tables, total_tables
      FROM dam_standard.standard_code_table WHERE deleted_at IS NULL;

    SELECT count(*) INTO total_values
      FROM dam_standard.standard_code_value v
      JOIN dam_standard.standard_code_table t ON t.id = v.code_table_id AND t.deleted_at IS NULL
     WHERE v.deleted_at IS NULL;

    RAISE NOTICE '标准码表：共 % 张，其中有国标/行标 % 张；有效码值 % 条',
        total_tables, gb_tables, total_values;

    FOR r IN
        SELECT t.code_table_code, t.standard_source, count(v.id) AS n
          FROM dam_standard.standard_code_table t
          LEFT JOIN dam_standard.standard_code_value v
                 ON v.code_table_id = t.id AND v.deleted_at IS NULL
         WHERE t.deleted_at IS NULL
         GROUP BY t.code_table_code, t.standard_source
         ORDER BY t.standard_source, t.code_table_code
    LOOP
        RAISE NOTICE '  % [%] % 条', rpad(r.code_table_code, 18), r.standard_source, r.n;
    END LOOP;
END $$;
