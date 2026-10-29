-- =============================================================
-- 数据资产管理平台 融合版 v2.0 建表脚本（幂等）
-- 平台库按模块拆分为 9 个 schema：
--   dam_sys / dam_metadata / dam_asset / dam_model / dam_security /
--   dam_standard / dam_ticket / dam_service / dam_sched
-- 演示业务库 hospital_demo 独立 schema。
-- 规范：小写蛇形 / int2 status / 审计六件套 / 软删除（deleted_at）
-- =============================================================
-- 删除旧版单一 dam schema（历史遗留，表已迁至对应模块 schema）
DROP SCHEMA IF EXISTS dam CASCADE;
CREATE SCHEMA IF NOT EXISTS dam_sys;
CREATE SCHEMA IF NOT EXISTS dam_metadata;
CREATE SCHEMA IF NOT EXISTS dam_asset;
CREATE SCHEMA IF NOT EXISTS dam_model;
CREATE SCHEMA IF NOT EXISTS dam_security;
CREATE SCHEMA IF NOT EXISTS dam_standard;
CREATE SCHEMA IF NOT EXISTS dam_ticket;
CREATE SCHEMA IF NOT EXISTS dam_service;
CREATE SCHEMA IF NOT EXISTS dam_sched;
CREATE SCHEMA IF NOT EXISTS hospital_demo;

-- ---------- dam_system 系统模块 ----------
CREATE TABLE IF NOT EXISTS dam_sys.sys_role (
    id             bigserial PRIMARY KEY,
    role_code      varchar(30) NOT NULL,
    role_name      varchar(100) NOT NULL,
    description    varchar(500),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_sys.sys_role IS '角色表—— 角色定义，RBAC 主体之一';
CREATE TABLE IF NOT EXISTS dam_sys.sys_user (
    id             bigserial PRIMARY KEY,
    username       varchar(50) NOT NULL,
    password       varchar(255) NOT NULL,
    real_name      varchar(100),
    email          varchar(100),
    phone          varchar(20),
    department     varchar(100) NOT NULL,
    avatar         varchar(255),
    last_login_at  timestamp NOT NULL,
    last_login_ip  varchar(20) NOT NULL,
    password_hash  varchar(64) NOT NULL,
    salt           varchar(32) NOT NULL,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_sys.sys_user IS '用户表—— 平台用户（融合现平台密码哈希/盐/最后登录字段）';
CREATE TABLE IF NOT EXISTS dam_sys.sys_user_role (
    id             bigserial PRIMARY KEY,
    user_id        bigint NOT NULL,
    role_id        bigint NOT NULL,
    default_role   varchar(2) NOT NULL DEFAULT 'Y',
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_sys.sys_user_role IS '用户角色关联表—— 用户-角色多对多关联';
CREATE TABLE IF NOT EXISTS dam_sys.sys_permission (
    id             bigserial PRIMARY KEY,
    permission_code varchar(50) NOT NULL,
    permission_name varchar(100) NOT NULL,
    parent_id      bigint,
    type           varchar(20) NOT NULL,
    path           varchar(200) NOT NULL,
    icon           varchar(100),
    sort_order     integer,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_sys.sys_permission IS '权限表—— 权限点（接口级）定义';
CREATE TABLE IF NOT EXISTS dam_sys.sys_role_permission (
    id             bigserial PRIMARY KEY,
    role_id        bigint NOT NULL,
    permission_id  bigint NOT NULL,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_sys.sys_role_permission IS '角色权限关联表—— 角色-权限关联';
CREATE TABLE IF NOT EXISTS dam_sys.sys_config (
    id             bigserial PRIMARY KEY,
    config_type    varchar(50) NOT NULL,
    config_code    varchar(50) NOT NULL,
    config_name    varchar(100) NOT NULL,
    config_value   text,
    description    varchar(500),
    sort_order     integer DEFAULT 0,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_sys.sys_config IS '系统配置表—— 系统参数配置（含数据源密码加密密钥等）';
CREATE TABLE IF NOT EXISTS dam_sys.sys_menu (
    id             bigserial PRIMARY KEY,
    menu_name      varchar(50) NOT NULL,
    menu_type      varchar(10) NOT NULL,
    parent_id      bigint,
    tree_level     integer DEFAULT 1,
    path           varchar(200),
    component      varchar(200),
    redirect       varchar(200),
    icon           varchar(50),
    sort_order     integer DEFAULT 0,
    visible        smallint NOT NULL DEFAULT 1,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_sys.sys_menu IS '系统菜单表—— 前端菜单树（配合角色控制可见性）';
CREATE TABLE IF NOT EXISTS dam_sys.sys_role_menu (
    id             bigserial PRIMARY KEY,
    role_id        bigint NOT NULL,
    menu_id        bigint NOT NULL,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_sys.sys_role_menu IS '角色菜单关联表—— 角色-菜单关联';
CREATE TABLE IF NOT EXISTS dam_sys.sys_dict_type (
    id             bigserial PRIMARY KEY,
    dict_type_code varchar(100),
    dict_type_name varchar(200),
    remark         varchar(500),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_sys.sys_dict_type IS '通用字典类型表—— 系统级字典类型（状态/枚举类，业务码表勿放此处）';
CREATE TABLE IF NOT EXISTS dam_sys.sys_dict_data (
    id             bigserial PRIMARY KEY,
    dict_type_id   integer,
    dict_label     varchar(100),
    dict_value     varchar(200),
    dict_extra     varchar(500),
    sort_order     integer,
    is_default     boolean,
    remarks        varchar(500),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_sys.sys_dict_data IS '字典数据表—— 系统级字典数据';
CREATE TABLE IF NOT EXISTS dam_sys.sys_audit_log (
    id             bigserial PRIMARY KEY,
    trace_id       varchar(50) NOT NULL,
    session_id     varchar(64) NOT NULL,
    operator_id    varchar(64) NOT NULL,
    operator_ip    varchar(45) NOT NULL,
    user_agent     text,
    module         varchar(50) NOT NULL,
    operation      varchar(100),
    operation_type varchar(30),
    target_type    varchar(30),
    target_id      varchar(100),
    target_name    varchar(200),
    request_method varchar(10),
    request_url    varchar(500),
    request_params jsonb,
    response_status integer,
    response_body  text,
    duration_ms    integer,
    is_success     boolean,
    error_message  text,
    risk_level     varchar(20),
    operation_time timestamp NOT NULL,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status         smallint NOT NULL DEFAULT 1,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_sys.sys_audit_log IS '系统操作审计表—— 系统操作审计（登录/增删改/授权等全量留痕）';

-- ---------- dam_metadata 元数据管理 ----------
CREATE TABLE IF NOT EXISTS dam_metadata.metadata_category (
    id             bigserial PRIMARY KEY,
    category_name  varchar(50) NOT NULL,
    category_code  varchar(50) NOT NULL,
    category_type  varchar(20) NOT NULL,
    parent_id      bigint,
    tree_level     integer NOT NULL,
    full_path      varchar(500),
    icon           varchar(500),
    description    varchar(500),
    sort_order     integer DEFAULT 0,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.metadata_category IS '元数据分类表—— 元数据分类树（技术/业务/管理三大类，支持多级）';
CREATE TABLE IF NOT EXISTS dam_metadata.metadata_datasource (
    id             bigserial PRIMARY KEY,
    ds_name        varchar(100) NOT NULL,
    ds_code        varchar(100) NOT NULL,
    ds_type        varchar(50) NOT NULL,
    ds_adapter     varchar(100) NOT NULL,
    ds_ip          varchar(20),
    ds_port        varchar(10),
    jdbc_url       varchar(200) NOT NULL,
    username       varchar(100) NOT NULL,
    password       varchar(100) NOT NULL,
    driver_class   varchar(200) NOT NULL,
    connection_props varchar(200),
    description    varchar(200),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.metadata_datasource IS '数据源表—— 数据源登记（连接信息，密码加密存储）';
CREATE TABLE IF NOT EXISTS dam_metadata.metadata_schema (
    id             bigserial PRIMARY KEY,
    datasource_id  bigint NOT NULL,
    schema_name    varchar(50),
    schema_comment varchar(500),
    schema_type    varchar(50),
    schema_owner   varchar(100),
    environment    varchar(50),
    location       varchar(500),
    properties     varchar(200),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.metadata_schema IS '技术元数据-模式—— 技术元数据-Schema 层（环境标识 PROD/TEST/DEV、物理存储路径）';
CREATE TABLE IF NOT EXISTS dam_metadata.metadata_table (
    id             bigserial PRIMARY KEY,
    datasource_id  bigint NOT NULL,
    schema_id      bigint NOT NULL,
    table_name     varchar(100) NOT NULL,
    table_comment  varchar(500),
    table_type     varchar(50) NOT NULL,
    row_count      varchar(100),
    table_size     varchar(100),
    created_time   timestamp NOT NULL,
    last_modified  timestamp NOT NULL,
    last_sync_time timestamp NOT NULL,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.metadata_table IS '技术元数据-表—— 技术元数据-表级（行数/大小/DDL 时间/同步时间）';
CREATE TABLE IF NOT EXISTS dam_metadata.metadata_column (
    id             bigserial PRIMARY KEY,
    datasource_id  bigint NOT NULL,
    schema_id      bigint NOT NULL,
    table_id       bigint NOT NULL,
    column_name    varchar(100) NOT NULL,
    column_type    varchar(100) NOT NULL,
    column_length  integer,
    is_nullable    boolean NOT NULL DEFAULT TRUE,
    is_primary_key boolean,
    is_foreign_key boolean,
    default_value  varchar(100),
    column_comment varchar(200),
    ordinal_position integer,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.metadata_column IS '技术元数据-字段—— 技术元数据-字段级（类型/主外键/默认值/序位）';
CREATE TABLE IF NOT EXISTS dam_metadata.metadata_business (
    id             bigserial PRIMARY KEY,
    business_code  varchar(50) NOT NULL,
    business_name  varchar(200) NOT NULL,
    business_definition text,
    business_owner_id bigint,
    data_domain_id bigint,
    business_domain_id bigint,
    business_process varchar(100),
    data_steward_id bigint,
    criticality_level varchar(50),
    data_quality_rules_id bigint,
    tags           text[],
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.metadata_business IS '业务元数据表—— 业务元数据（业务定义/口径/负责人/数据管家/标签）';
CREATE TABLE IF NOT EXISTS dam_metadata.metadata_business_table_rel (
    id             bigserial PRIMARY KEY,
    business_id    bigint NOT NULL,
    table_id       bigint NOT NULL,
    mapping_type_id varchar(200) NOT NULL,
    mapping_comment text NOT NULL,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.metadata_business_table_rel IS '业务-表关联映射表—— 业务实体与技术表的映射关系';
CREATE TABLE IF NOT EXISTS dam_metadata.metadata_management (
    id             bigserial PRIMARY KEY,
    table_id       bigint NOT NULL,
    governance_status_id varchar(30) NOT NULL,
    lifecycle_status_id varchar(20),
    retention_days bigint,
    source_system_id bigint NOT NULL,
    etl_workflow   varchar(200),
    last_accessed_at timestamp,
    daily_query_avg bigint,
    security_classification varchar(20),
    data_verification_status varchar(20),
    registration_batch_id varchar(50),
    last_ddl_time  timestamp,
    audit_remark   text,
    extend_props   jsonb,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.metadata_management IS '管理元数据表—— 管理元数据（治理状态/生命周期/保留策略/安全分级/使用热度 15 维）';
CREATE TABLE IF NOT EXISTS dam_metadata.source_system (
    id             bigserial PRIMARY KEY,
    system_code    varchar(100) NOT NULL,
    system_name    varchar(200) NOT NULL,
    description    varchar(500),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.source_system IS '来源系统表—— 来源系统登记（HIS/EMR/LIS/IRIS…）';
CREATE TABLE IF NOT EXISTS dam_metadata.metadata_collection (
    id             bigserial PRIMARY KEY,
    datasource_id  integer NOT NULL,
    schema_id      bigint NOT NULL,
    job_name       varchar(200),
    job_type       varchar(100) NOT NULL,
    start_time     timestamp,
    end_time       timestamp,
    total_tables   integer,
    total_columns  integer,
    success_count  integer,
    fail_count     integer,
    error_message  varchar(500),
    detail_log     jsonb,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.metadata_collection IS '元数据采集记录表—— 元数据采集任务记录（起止/总量/成败/错误/明细 JSONB）';
CREATE TABLE IF NOT EXISTS dam_metadata.metadata_version (
    id             bigserial PRIMARY KEY,
    datasource_id  integer NOT NULL,
    schema_id      integer NOT NULL,
    table_id       integer NOT NULL,
    version_number varchar(50) NOT NULL,
    change_type    varchar(100) NOT NULL,
    change_summary text NOT NULL,
    snapshot_data  jsonb NOT NULL,
    diff_summary   jsonb,
    changed_by     varchar(100) NOT NULL,
    changed_at     timestamp NOT NULL,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.metadata_version IS '元数据版本表—— 元数据版本快照（JSONB 快照 + diff 摘要，支撑变更对比与通知）';
CREATE TABLE IF NOT EXISTS dam_metadata.metadata_lineage (
    id             bigserial PRIMARY KEY,
    source_type    varchar(50) NOT NULL,
    source_id      integer NOT NULL,
    target_type    varchar(50) NOT NULL,
    target_id      integer NOT NULL,
    relation_type  varchar(50) NOT NULL,
    transform_rule text NOT NULL,
    dependency_level integer NOT NULL,
    source_system  varchar(50) NOT NULL,
    collection_id  integer NOT NULL,
    discovered_by  varchar(100),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.metadata_lineage IS '数据血缘关系表—— 血缘关系（通用节点对：source/target 的 type+id，兼容表级/字段级/模型级）';
CREATE TABLE IF NOT EXISTS dam_metadata.metadata_quality_rule (
    id             bigserial PRIMARY KEY,
    rule_code      varchar(50) NOT NULL,
    rule_type      varchar(100) NOT NULL,
    rule_level     varchar(50) NOT NULL,
    target_table_id integer NOT NULL,
    target_column  varchar(100),
    rule_expression text,
    expect_value   varchar(200),
    severity       varchar(50),
    is_scheduled   boolean,
    cron_expression varchar(100),
    description    varchar(500),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.metadata_quality_rule IS '质量规则表—— 质量规则（类型/级别/表达式/期望值/严重度，含 cron 定时字段——定时执行由 PowerJob 驱动）';
CREATE TABLE IF NOT EXISTS dam_metadata.metadata_quality_check_result (
    id             bigserial PRIMARY KEY,
    rule_id        integer,
    check_time     timestamp,
    total_count    integer,
    pass_count     integer,
    fail_count     integer,
    pass_rate      decimal(5,2),
    result_status  varchar(50),
    fail_samples   jsonb,
    error_detail   text,
    executed_by    varchar(100),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.metadata_quality_check_result IS '质量检测结果表—— 质量检测结果（通过率/失败样例 JSONB/错误详情）';
CREATE TABLE IF NOT EXISTS dam_metadata.metadata_lifecycle_policy (
    id             bigserial PRIMARY KEY,
    policy_code    varchar(50),
    policy_name    varchar(100),
    target_type    varchar(50),
    target_id      integer,
    hot_days       integer,
    cold_days      integer,
    archive_days   integer,
    purge_days     integer,
    cold_storage_location varchar(500),
    archive_storage_location varchar(500),
    archive_format varchar(50),
    auto_execute   boolean,
    last_execute_time timestamp,
    description    varchar(500),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.metadata_lifecycle_policy IS '生命周期策略表—— 生命周期策略（热/冷/归档/清理四段天数+存储位置+格式）';
CREATE TABLE IF NOT EXISTS dam_metadata.metadata_destruction_record (
    id             bigserial PRIMARY KEY,
    destruction_no varchar(50),
    target_type    varchar(50),
    target_id      integer,
    target_name    varchar(100),
    destruction_reason text,
    destruction_scope varchar(100),
    filter_condition text,
    affected_rows  integer,
    destruction_method varchar(50),
    requester_id   varchar(50),
    approver_id    varchar(50),
    executor_id    varchar(50),
    requested_at   timestamp,
    approved_at    timestamp,
    executed_at    timestamp,
    remark         varchar(500),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_metadata.metadata_destruction_record IS '数据销毁记录表—— 数据销毁记录（申请-审批-执行三段留痕）';

-- ---------- dam_asset 资产目录 ----------
CREATE TABLE IF NOT EXISTS dam_asset.asset_category (
    id             bigserial PRIMARY KEY,
    category_code  varchar(50) NOT NULL,
    category_name  varchar(100) NOT NULL,
    parent_id      bigint,
    tree_level     bigint NOT NULL,
    category_path  varchar(500) NOT NULL,
    description    varchar(500),
    sort_order     bigint NOT NULL,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_asset.asset_category IS '资产分类表—— 资产分类树（业务/技术/主题三维分类）';
CREATE TABLE IF NOT EXISTS dam_asset.asset_info (
    id             bigserial PRIMARY KEY,
    asset_code     varchar(100) NOT NULL,
    asset_name     varchar(200) NOT NULL,
    asset_type_id  integer NOT NULL,
    category_id    integer NOT NULL,
    description    text,
    business_owner_id integer,
    tech_owner_id  integer,
    data_owner_id  integer,
    source_system_id integer,
    data_source_id integer,
    source_metadata_type varchar(50),
    source_metadata_id integer,
    storage_location varchar(500),
    row_count      bigint,
    storage_size   bigint,
    quality_score  decimal(5,2),
    popularity     integer,
    published_status smallint,
    published_at   timestamp,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_asset.asset_info IS '资产基本信息表—— 资产主表（业务描述/技术属性/负责人/安全等级/质量分）';
CREATE TABLE IF NOT EXISTS dam_asset.asset_tag (
    id             bigserial PRIMARY KEY,
    tag_code       varchar(100) NOT NULL,
    tag_name       varchar(200) NOT NULL,
    tag_color      varchar(20) NOT NULL,
    tag_scope      varchar(20) NOT NULL,
    tag_type       varchar(20) NOT NULL,
    description    varchar(200),
    usage_count    integer,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_asset.asset_tag IS '标签定义表—— 标签定义';
CREATE TABLE IF NOT EXISTS dam_asset.asset_tag_rel (
    id             bigserial PRIMARY KEY,
    asset_id       integer NOT NULL,
    tag_id         integer NOT NULL,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_asset.asset_tag_rel IS '资产标签关联表—— 资产-标签关联';
CREATE TABLE IF NOT EXISTS dam_asset.asset_favorite (
    id             bigserial PRIMARY KEY,
    asset_id       integer NOT NULL,
    user_id        integer NOT NULL,
    folder_name    varchar(200) NOT NULL,
    favorite_time  timestamp NOT NULL,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_asset.asset_favorite IS '资产收藏表—— 资产收藏';
CREATE TABLE IF NOT EXISTS dam_asset.asset_rating (
    id             bigserial PRIMARY KEY,
    asset_id       bigint NOT NULL,
    rating_score   integer NOT NULL,
    rating_comment text NOT NULL,
    rating_dimension varchar(50) NOT NULL,
    user_id        varchar(64) NOT NULL,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_asset.asset_rating IS '资产评价表—— 资产评价（评分/评论）';
CREATE TABLE IF NOT EXISTS dam_asset.asset_usage_log (
    id             bigserial PRIMARY KEY,
    asset_id       integer NOT NULL,
    user_id        varchar(50) NOT NULL,
    action_type    varchar(50) NOT NULL,
    action_detail  jsonb NOT NULL,
    ip_address     varchar(50) NOT NULL,
    user_agent     text,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_asset.asset_usage_log IS '资产使用日志表—— 资产使用日志（浏览/收藏/调用，支撑活跃度分析）';

-- ---------- dam_model 模型管理 ----------
CREATE TABLE IF NOT EXISTS dam_model.model_domain (
    id             bigserial PRIMARY KEY,
    domain_code    varchar(100) NOT NULL,
    domain_name    varchar(200) NOT NULL,
    parent_id      integer,
    description    text,
    sort_order     integer NOT NULL,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_model.model_domain IS '模型主题域表—— 模型主题域（数据中心→业务域两级树）';
CREATE TABLE IF NOT EXISTS dam_model.model_fact (
    id             bigserial PRIMARY KEY,
    domain_id      integer NOT NULL,
    fact_code      varchar(100) NOT NULL,
    fact_name      varchar(200) NOT NULL,
    source_table_id integer,
    granularity    varchar(100),
    description    text,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_model.model_fact IS '事实表—— 事实模型（挂主题域）';
CREATE TABLE IF NOT EXISTS dam_model.model_dimension (
    id             bigserial PRIMARY KEY,
    domain_id      integer NOT NULL,
    dimension_code varchar(100) NOT NULL,
    dimension_name varchar(200) NOT NULL,
    dimension_type_id integer,
    source_table_id integer,
    description    text,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_model.model_dimension IS '维度表—— 维度模型（挂主题域）';
CREATE TABLE IF NOT EXISTS dam_model.model_column_mapping (
    id             bigserial PRIMARY KEY,
    model_id       integer,
    model_type     varchar(50),
    source_table_id integer,
    source_column_id integer,
    target_column_name varchar(100),
    target_column_type varchar(50),
    is_primary_key integer,
    is_foreign_key integer,
    ref_dimension_id integer,
    transform_rule varchar(500),
    sort_order     integer,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_model.model_column_mapping IS '模型字段映射表—— 模型字段映射（模型字段↔技术元数据字段）';

-- ---------- dam_security_management 安全管控 ----------
CREATE TABLE IF NOT EXISTS dam_security.security_sensitive_rule (
    id             bigserial PRIMARY KEY,
    rule_code      varchar(100),
    rule_name      varchar(200),
    sensitivity_level varchar(20),
    rule_type      varchar(50),
    rule_pattern   varchar(200),
    dictionary_id  integer,
    description    text,
    priority       varchar(20),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_security.security_sensitive_rule IS '敏感数据规则表—— 敏感数据识别规则（正则/关键字/字典，身份证/手机号/银行卡等）';
CREATE TABLE IF NOT EXISTS dam_security.security_sensitive_discovery (
    id             bigserial PRIMARY KEY,
    column_id      integer NOT NULL,
    rule_id        integer NOT NULL,
    sensitivity_level_id integer NOT NULL,
    confidence     decimal(5,2),
    discovery_time timestamp,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_security.security_sensitive_discovery IS '敏感数据发现结果表—— 敏感数据发现结果（扫描批次/命中列/置信度）';
CREATE TABLE IF NOT EXISTS dam_security.security_access_application (
    id             bigserial PRIMARY KEY,
    application_no varchar(30) NOT NULL,
    applicant_id   varchar(64) NOT NULL,
    asset_id       integer NOT NULL,
    access_type    varchar(50) NOT NULL,
    access_reason  text NOT NULL,
    validity_days  varchar(50) NOT NULL,
    approver_id    varchar(64) NOT NULL,
    approve_comment text,
    approved_at    timestamp,
    effective_from timestamp NOT NULL,
    effective_to   timestamp,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_security.security_access_application IS '数据访问申请表—— 数据访问申请（申请-审批流，RBAC+ABAC 的 ABAC 入口）';
CREATE TABLE IF NOT EXISTS dam_security.security_masking_policy (
    id             bigserial PRIMARY KEY,
    policy_code    varchar(50) NOT NULL,
    policy_name    varchar(100) NOT NULL,
    target_type    varchar(50) NOT NULL,
    target_id      bigint NOT NULL,
    target_column  varchar(100),
    masking_type   varchar(50) NOT NULL,
    masking_config jsonb NOT NULL,
    priority       integer NOT NULL,
    apply_scenario varchar(50) NOT NULL,
    description    varchar(500),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_security.security_masking_policy IS '脱敏策略表—— 脱敏策略（目标通用化：表/字段/资产/API 皆可挂；算法 MASK/PARTIAL/HASH/NULLIFY）';
CREATE TABLE IF NOT EXISTS dam_security.security_data_permission (
    id             bigserial PRIMARY KEY,
    permission_code varchar(50) NOT NULL,
    permission_name varchar(100) NOT NULL,
    resource_type  varchar(50) NOT NULL,
    resource_id    bigint NOT NULL,
    subject_type   varchar(50) NOT NULL,
    subject_id     varchar(100) NOT NULL,
    action_type    varchar(100) NOT NULL,
    filter_condition text,
    column_mask    text[],
    priority       integer NOT NULL,
    effective_from timestamp NOT NULL,
    effective_to   timestamp,
    description    varchar(500),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_security.security_data_permission IS 'ABAC 数据权限表—— ABAC 数据权限（行级/列级规则）';
CREATE TABLE IF NOT EXISTS dam_security.security_data_audit_log (
    id             bigserial PRIMARY KEY,
    trace_id       varchar(50) NOT NULL,
    session_id     varchar(64) NOT NULL,
    operator_id    varchar(50) NOT NULL,
    operator_ip    varchar(50) NOT NULL,
    asset_id       bigint NOT NULL,
    asset_name     varchar(200),
    table_id       bigint,
    table_name     varchar(200),
    operation_type varchar(50) NOT NULL,
    sql_content    text,
    filter_condition text,
    affected_rows  bigint,
    data_size      bigint,
    sensitivity_level varchar(50),
    masking_applied boolean,
    permission_code varchar(50),
    access_reason  varchar(200),
    is_approved    boolean,
    risk_level     varchar(20),
    operation_time timestamp NOT NULL,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status         smallint NOT NULL DEFAULT 1,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_security.security_data_audit_log IS '数据操作审计表—— 数据操作审计（访问/导出/脱敏命中）';

-- ---------- dam_standard 数据标准 ----------
CREATE TABLE IF NOT EXISTS dam_standard.standard_category (
    id             bigserial PRIMARY KEY,
    parent_id      bigint,
    code           varchar(64),
    name           varchar(128) NOT NULL,
    description    text,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_standard.standard_category IS '标准分类表—— 标准分类（规则型标准树，融合自现平台）';
CREATE TABLE IF NOT EXISTS dam_standard.data_standard (
    id             bigserial PRIMARY KEY,
    code           varchar(64) NOT NULL,
    name           varchar(200) NOT NULL,
    category_id    bigint,
    std_type       varchar(32),
    rule_content   text,
    example_value  varchar(255),
    version        varchar(16) NOT NULL DEFAULT 'v1.0',
    owner          varchar(100),
    effective_date date,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp,
    CONSTRAINT uq_data_standard_code UNIQUE (code)
);
COMMENT ON TABLE dam_standard.data_standard IS '数据标准库表—— 数据标准库（命名/编码/类型/枚举/度量规则标准，融合自现平台）';
CREATE TABLE IF NOT EXISTS dam_standard.standard_code_table (
    id             bigserial PRIMARY KEY,
    code_table_code varchar(100) NOT NULL,
    code_table_name varchar(100),
    code_table_type varchar(100) NOT NULL,
    description    text,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_standard.standard_code_table IS '标准码表—— 标准码表（DIM 14 类医疗字典的码表形态）';
CREATE TABLE IF NOT EXISTS dam_standard.standard_code_value (
    id             bigserial PRIMARY KEY,
    code_table_id  integer,
    code_value     varchar(200),
    code_name      varchar(100),
    parent_code_id integer,
    sort_order     integer,
    description    text,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_standard.standard_code_value IS '标准码值表—— 标准码值（含 ICD-10/ICD-9-CM-3/科室/药品等）';
CREATE TABLE IF NOT EXISTS dam_standard.standard_mapping (
    id             bigserial PRIMARY KEY,
    source_system_id integer NOT NULL,
    source_table_id integer NOT NULL,
    source_column  varchar(200) NOT NULL,
    source_value   varchar(200) NOT NULL,
    standard_code_table_id integer NOT NULL,
    standard_code_value varchar(200) NOT NULL,
    mapping_rule   text NOT NULL,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_standard.standard_mapping IS '标准映射表—— 标准落标映射（标准↔资产字段）';
CREATE TABLE IF NOT EXISTS dam_standard.standard_deviation_report (
    id             bigserial PRIMARY KEY,
    report_no      varchar(50) NOT NULL,
    check_type     varchar(30) NOT NULL,
    table_id       bigint NOT NULL,
    column_name    varchar(200),
    standard_code_table_id bigint NOT NULL,
    expected_value varchar(200) NOT NULL,
    actual_value   varchar(200) NOT NULL,
    deviation_description text,
    severity       varchar(20) NOT NULL,
    fix_suggestion text,
    fixed_by       varchar(100),
    fixed_at       timestamp,
    check_time     timestamp,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_standard.standard_deviation_report IS '标准偏差报告表—— 标准偏差报告（不符合项/整改跟踪）';

-- ---------- dam_ticket_center 工单中心 ----------
CREATE TABLE IF NOT EXISTS dam_ticket.ticket_order (
    id             bigserial PRIMARY KEY,
    ticket_no      varchar(50) NOT NULL,
    ticket_type    varchar(50) NOT NULL,
    title          varchar(100) NOT NULL,
    description    text,
    priority       varchar(100) NOT NULL,
    applicant_id   integer NOT NULL,
    assignee_id    integer,
    related_asset_id integer,
    related_application_id integer,
    expected_complete_time timestamp,
    actual_complete_time timestamp,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_ticket.ticket_order IS '工单主表—— 工单主表（数据申请/质量问题/变更申请）';
CREATE TABLE IF NOT EXISTS dam_ticket.ticket_flow_log (
    id             bigserial PRIMARY KEY,
    ticket_id      integer NOT NULL,
    from_status    varchar(50) NOT NULL,
    to_status      varchar(50) NOT NULL,
    operator_id    integer NOT NULL,
    operation_type varchar(50) NOT NULL,
    comment        varchar(500),
    attachments    jsonb,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_ticket.ticket_flow_log IS '工单状态流转记录表—— 工单状态流转记录';
CREATE TABLE IF NOT EXISTS dam_ticket.ticket_comment (
    id             bigserial PRIMARY KEY,
    ticket_id      bigint NOT NULL,
    parent_comment_id bigint,
    content        text NOT NULL,
    attachments    jsonb,
    mentioned_users text[],
    is_internal    boolean,
    commenter_id   varchar(100) NOT NULL,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_ticket.ticket_comment IS '工单评论表—— 工单评论';
CREATE TABLE IF NOT EXISTS dam_asset.asset_statistics (
    id             bigserial PRIMARY KEY,
    asset_id       integer NOT NULL,
    stat_date      timestamp NOT NULL,
    view_count     integer NOT NULL,
    query_count    integer NOT NULL,
    download_count integer NOT NULL,
    export_count   integer NOT NULL,
    unique_users   integer NOT NULL,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_asset.asset_statistics IS '资产使用统计表—— 资产使用统计（汇总 asset_usage_log）';

-- ---------- dam_data_service 数据服务网关 ----------
CREATE TABLE IF NOT EXISTS dam_service.api_service (
    id             bigserial PRIMARY KEY,
    api_code       varchar(64) NOT NULL,
    name           varchar(200) NOT NULL,
    asset_id       bigint,
    sql_text       text NOT NULL,
    params_json    text,
    approval_status varchar(20) NOT NULL DEFAULT 'PENDING',
    approved_by    varchar(100),
    approved_at    timestamp,
    rate_limit     integer NOT NULL DEFAULT 60,
    quota_day      integer NOT NULL DEFAULT 10000,
    owner          varchar(64),
    description    text,
    call_count     bigint NOT NULL DEFAULT 0,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp,
    CONSTRAINT uq_api_service_api_code UNIQUE (api_code)
);
COMMENT ON TABLE dam_service.api_service IS '网关 API 定义表—— 网关 API 定义（保留并完善：新增审批流/日配额）';
CREATE TABLE IF NOT EXISTS dam_service.api_client (
    id             bigserial PRIMARY KEY,
    app_id         varchar(64) NOT NULL,
    app_key        varchar(128) NOT NULL,
    app_name       varchar(128),
    contact        varchar(64),
    quota_day      integer NOT NULL DEFAULT 50000,
    last_call_at   timestamp,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp,
    CONSTRAINT uq_api_client_app_id UNIQUE (app_id)
);
COMMENT ON TABLE dam_service.api_client IS '网关接入应用与密钥表—— 网关接入应用与密钥（保留并完善：应用级配额）';
CREATE TABLE IF NOT EXISTS dam_service.api_call_log (
    id             bigserial PRIMARY KEY,
    api_id         bigint,
    api_code       varchar(64),
    app_id         varchar(64),
    params         text,
    duration_ms    integer,
    row_count      integer,
    success        boolean NOT NULL DEFAULT TRUE,
    masked_columns varchar(255),
    error_msg      text,
    client_ip      varchar(64),
    called_at      timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统'
);
COMMENT ON TABLE dam_service.api_call_log IS '网关调用日志表—— 网关调用全量留痕（含脱敏字段记录；日志表不做软删）';

-- ---------- dam_scheduler 调度配置 ----------
CREATE TABLE IF NOT EXISTS dam_sched.sched_job (
    id             bigserial PRIMARY KEY,
    job_code       varchar(64) NOT NULL,
    name           varchar(200) NOT NULL,
    job_type       varchar(64) NOT NULL,
    schedule_type  varchar(20) NOT NULL DEFAULT 'CRON',
    cron_expr      varchar(64),
    fixed_rate_ms  bigint,
    powerjob_job_id bigint,
    enabled        boolean NOT NULL DEFAULT TRUE,
    last_run_at    timestamp,
    last_status    varchar(16),
    last_message   text,
    run_count      bigint NOT NULL DEFAULT 0,
    description    text,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp,
    CONSTRAINT uq_sched_job_job_code UNIQUE (job_code)
);
COMMENT ON TABLE dam_sched.sched_job IS '调度任务定义表—— 调度任务配置层（新增 schedule_type/powerjob_job_id，执行触发由 PowerJob 承担）';
CREATE TABLE IF NOT EXISTS dam_sched.sched_job_log (
    id             bigserial PRIMARY KEY,
    job_id         bigint NOT NULL,
    started_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at    timestamp,
    duration_ms    bigint,
    exec_status    varchar(16),
    message        text,
    powerjob_instance_id bigint,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE dam_sched.sched_job_log IS '调度执行日志表—— 调度执行日志（新增 powerjob_instance_id 与 PowerJob 双端对账）';

-- ---------- hospital_demo 演示业务域 ----------
CREATE TABLE IF NOT EXISTS hospital_demo.biz_patient_master (
    id             bigserial PRIMARY KEY,
    patient_id     varchar(32) NOT NULL,
    register_no    varchar(32),
    patient_name   varchar(64) NOT NULL,
    gender_code    varchar(8),
    birth_date     date,
    id_card_type   varchar(8),
    id_card        varchar(32),
    marital_status varchar(8),
    nationality    varchar(32),
    nation         varchar(16),
    occupation     varchar(64),
    merge_flag     smallint NOT NULL DEFAULT 0,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp,
    CONSTRAINT uq_biz_patient_master_patient_id UNIQUE (patient_id)
);
COMMENT ON TABLE hospital_demo.biz_patient_master IS '患者主索引 EMPI 表—— 患者主索引 EMPI（BIZ_Patient_Master / FHIR Patient）';
CREATE TABLE IF NOT EXISTS hospital_demo.biz_patient_allergy (
    id             bigserial PRIMARY KEY,
    patient_id     varchar(32) NOT NULL,
    allergy_type   varchar(16),
    allergen       varchar(200),
    reaction       varchar(200),
    severity       varchar(8),
    onset_date     date,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE hospital_demo.biz_patient_allergy IS '患者过敏信息表—— 患者过敏信息';
CREATE TABLE IF NOT EXISTS hospital_demo.biz_encounter (
    id             bigserial PRIMARY KEY,
    encounter_no   varchar(32) NOT NULL,
    patient_id     varchar(32) NOT NULL,
    encounter_type varchar(8) NOT NULL,
    dept_code      varchar(16),
    dept_name      varchar(64),
    doctor_code    varchar(32),
    doctor_name    varchar(64),
    admit_time     timestamp,
    discharge_time timestamp,
    encounter_status varchar(8) NOT NULL DEFAULT 'OPEN',
    total_cost     numeric(12,2),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp,
    CONSTRAINT uq_biz_encounter_encounter_no UNIQUE (encounter_no)
);
COMMENT ON TABLE hospital_demo.biz_encounter IS '就诊事件表—— 就诊事件（门诊/急诊/住院，FHIR Encounter）';
CREATE TABLE IF NOT EXISTS hospital_demo.biz_encounter_transfer (
    id             bigserial PRIMARY KEY,
    encounter_no   varchar(32) NOT NULL,
    from_dept      varchar(16),
    to_dept        varchar(16),
    from_bed       varchar(16),
    to_bed         varchar(16),
    transfer_time  timestamp NOT NULL,
    reason         varchar(200),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE hospital_demo.biz_encounter_transfer IS '转科换床记录表—— 转科换床记录';
CREATE TABLE IF NOT EXISTS hospital_demo.biz_diagnosis (
    id             bigserial PRIMARY KEY,
    encounter_no   varchar(32) NOT NULL,
    patient_id     varchar(32) NOT NULL,
    diagnosis_icd  varchar(20) NOT NULL,
    diagnosis_name varchar(200) NOT NULL,
    diagnosis_class varchar(8),
    diagnosis_type varchar(16),
    is_primary     boolean NOT NULL DEFAULT FALSE,
    doctor_code    varchar(32),
    diagnosis_time timestamp,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE hospital_demo.biz_diagnosis IS '诊断记录表—— 诊断记录（FHIR Condition）';
CREATE TABLE IF NOT EXISTS hospital_demo.biz_clinical_order (
    id             bigserial PRIMARY KEY,
    order_no       varchar(32) NOT NULL,
    encounter_no   varchar(32) NOT NULL,
    patient_id     varchar(32) NOT NULL,
    order_type     varchar(8) NOT NULL,
    order_item_code varchar(32),
    order_item_name varchar(200) NOT NULL,
    spec           varchar(100),
    dosage         varchar(100),
    frequency      varchar(32),
    route          varchar(32),
    order_doctor   varchar(64),
    order_time     timestamp,
    order_status   varchar(8) NOT NULL DEFAULT 'ACTIVE',
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp,
    CONSTRAINT uq_biz_clinical_order_order_no UNIQUE (order_no)
);
COMMENT ON TABLE hospital_demo.biz_clinical_order IS '医嘱信息表—— 医嘱（长期/临时，FHIR ServiceRequest）';
CREATE TABLE IF NOT EXISTS hospital_demo.biz_order_exec (
    id             bigserial PRIMARY KEY,
    order_no       varchar(32) NOT NULL,
    exec_time      timestamp NOT NULL,
    exec_nurse     varchar(64),
    exec_dept      varchar(16),
    exec_status    varchar(8) NOT NULL DEFAULT 'DONE',
    exec_note      varchar(200),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE hospital_demo.biz_order_exec IS '医嘱执行记录表—— 医嘱执行记录';
CREATE TABLE IF NOT EXISTS hospital_demo.biz_prescription (
    id             bigserial PRIMARY KEY,
    prescription_no varchar(32) NOT NULL,
    encounter_no   varchar(32) NOT NULL,
    patient_id     varchar(32) NOT NULL,
    prescription_type varchar(8) NOT NULL,
    doctor_code    varchar(32),
    dept_code      varchar(16),
    total_amount   numeric(10,2),
    prescribe_time timestamp,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp,
    CONSTRAINT uq_biz_prescription_prescription_no UNIQUE (prescription_no)
);
COMMENT ON TABLE hospital_demo.biz_prescription IS '处方单表—— 处方单（中西药，FHIR MedicationRequest）';
CREATE TABLE IF NOT EXISTS hospital_demo.biz_prescription_item (
    id             bigserial PRIMARY KEY,
    prescription_no varchar(32) NOT NULL,
    item_seq       smallint NOT NULL DEFAULT 1,
    drug_code      varchar(32) NOT NULL,
    drug_name      varchar(200) NOT NULL,
    spec           varchar(100),
    dosage         varchar(100),
    quantity       numeric(10,2),
    unit           varchar(16),
    usage_note     varchar(200),
    days           smallint,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE hospital_demo.biz_prescription_item IS '处方明细表—— 处方明细';
CREATE TABLE IF NOT EXISTS hospital_demo.biz_lab_report (
    id             bigserial PRIMARY KEY,
    report_no      varchar(32) NOT NULL,
    encounter_no   varchar(32) NOT NULL,
    patient_id     varchar(32) NOT NULL,
    lab_item_code  varchar(32),
    lab_item_name  varchar(200) NOT NULL,
    specimen       varchar(64),
    apply_doctor   varchar(64),
    report_doctor  varchar(64),
    apply_time     timestamp,
    report_time    timestamp,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp,
    CONSTRAINT uq_biz_lab_report_report_no UNIQUE (report_no)
);
COMMENT ON TABLE hospital_demo.biz_lab_report IS '检验报告表—— 检验报告（FHIR DiagnosticReport）';
CREATE TABLE IF NOT EXISTS hospital_demo.biz_lab_result (
    id             bigserial PRIMARY KEY,
    report_no      varchar(32) NOT NULL,
    item_code      varchar(32) NOT NULL,
    item_name      varchar(200) NOT NULL,
    result_value   varchar(100),
    result_value_num numeric(18,4),
    unit           varchar(32),
    ref_range      varchar(64),
    abnormal_flag  varchar(8),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE hospital_demo.biz_lab_result IS '检验结果表—— 检验结果子项（FHIR Observation）';
CREATE TABLE IF NOT EXISTS hospital_demo.biz_imaging_exam (
    id             bigserial PRIMARY KEY,
    exam_no        varchar(32) NOT NULL,
    encounter_no   varchar(32) NOT NULL,
    patient_id     varchar(32) NOT NULL,
    exam_type      varchar(16) NOT NULL,
    body_part      varchar(64),
    finding        text,
    conclusion     text,
    apply_doctor   varchar(64),
    report_doctor  varchar(64),
    report_time    timestamp,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp,
    CONSTRAINT uq_biz_imaging_exam_exam_no UNIQUE (exam_no)
);
COMMENT ON TABLE hospital_demo.biz_imaging_exam IS '影像检查表—— 影像/超声/内镜检查（FHIR ImagingStudy）';
CREATE TABLE IF NOT EXISTS hospital_demo.biz_aux_exam (
    id             bigserial PRIMARY KEY,
    exam_no        varchar(32) NOT NULL,
    encounter_no   varchar(32) NOT NULL,
    patient_id     varchar(32) NOT NULL,
    exam_type      varchar(16) NOT NULL,
    exam_date      date,
    finding        text,
    conclusion     text,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp,
    CONSTRAINT uq_biz_aux_exam_exam_no UNIQUE (exam_no)
);
COMMENT ON TABLE hospital_demo.biz_aux_exam IS '辅助检查表—— 辅助检查（心电/脑电/肺功能）';
CREATE TABLE IF NOT EXISTS hospital_demo.biz_vital_signs (
    id             bigserial PRIMARY KEY,
    encounter_no   varchar(32) NOT NULL,
    patient_id     varchar(32) NOT NULL,
    measure_time   timestamp NOT NULL,
    temperature    numeric(4,1),
    pulse          smallint,
    respiration    smallint,
    sbp            smallint,
    dbp            smallint,
    spo2           smallint,
    pain_score     smallint,
    intake_ml      numeric(10,2),
    output_ml      numeric(10,2),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE hospital_demo.biz_vital_signs IS '生命体征表—— 生命体征（体温单，FHIR Observation-VitalSigns）';
CREATE TABLE IF NOT EXISTS hospital_demo.biz_surgery_anesthesia (
    id             bigserial PRIMARY KEY,
    surgery_no     varchar(32) NOT NULL,
    encounter_no   varchar(32) NOT NULL,
    patient_id     varchar(32) NOT NULL,
    surgery_icd    varchar(20) NOT NULL,
    surgery_name   varchar(200) NOT NULL,
    incision_level varchar(8),
    anesthesia_type varchar(32),
    surgeon_code   varchar(32),
    surgeon_name   varchar(64),
    surgery_start  timestamp,
    surgery_end    timestamp,
    surgery_status varchar(8) NOT NULL DEFAULT 'PLANNED',
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp,
    CONSTRAINT uq_biz_surgery_anesthesia_surgery_no UNIQUE (surgery_no)
);
COMMENT ON TABLE hospital_demo.biz_surgery_anesthesia IS '手术麻醉表—— 手术与麻醉（FHIR Procedure）';
CREATE TABLE IF NOT EXISTS hospital_demo.biz_transfusion (
    id             bigserial PRIMARY KEY,
    transfusion_no varchar(32) NOT NULL,
    encounter_no   varchar(32) NOT NULL,
    patient_id     varchar(32) NOT NULL,
    blood_type     varchar(8),
    blood_product  varchar(32),
    cross_match_time timestamp,
    transfuse_time timestamp,
    volume_ml      integer,
    reaction       varchar(200),
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp,
    CONSTRAINT uq_biz_transfusion_transfusion_no UNIQUE (transfusion_no)
);
COMMENT ON TABLE hospital_demo.biz_transfusion IS '输血记录表—— 输血记录';
CREATE TABLE IF NOT EXISTS hospital_demo.biz_emr_document (
    id             bigserial PRIMARY KEY,
    encounter_no   varchar(32) NOT NULL,
    patient_id     varchar(32) NOT NULL,
    doc_type       varchar(32) NOT NULL,
    doc_title      varchar(200),
    doc_content    text,
    author_code    varchar(32),
    author_name    varchar(64),
    archive_time   timestamp,
    status         smallint NOT NULL DEFAULT 1,
    created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     varchar(100) NOT NULL DEFAULT '系统',
    updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by     varchar(100) NOT NULL DEFAULT '系统',
    deleted_at     timestamp
);
COMMENT ON TABLE hospital_demo.biz_emr_document IS '电子病历文书表—— 电子病历文书（FHIR Composition）';

COMMENT ON COLUMN dam_sys.sys_role.role_code IS '角色编码';
COMMENT ON COLUMN dam_sys.sys_role.role_name IS '角色名称';
COMMENT ON COLUMN dam_sys.sys_role.description IS '角色描述';
COMMENT ON COLUMN dam_sys.sys_role.status IS '状态';
COMMENT ON COLUMN dam_sys.sys_role.created_at IS '创建时间';
COMMENT ON COLUMN dam_sys.sys_role.created_by IS '创建人';
COMMENT ON COLUMN dam_sys.sys_role.updated_at IS '更新时间';
COMMENT ON COLUMN dam_sys.sys_role.updated_by IS '更新人';
COMMENT ON COLUMN dam_sys.sys_role.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_sys.sys_user.username IS '用户名';
COMMENT ON COLUMN dam_sys.sys_user.password IS '密码(BCrypt加密)';
COMMENT ON COLUMN dam_sys.sys_user.real_name IS '真实姓名';
COMMENT ON COLUMN dam_sys.sys_user.email IS '邮箱';
COMMENT ON COLUMN dam_sys.sys_user.phone IS '手机号';
COMMENT ON COLUMN dam_sys.sys_user.department IS '所属科室/部门';
COMMENT ON COLUMN dam_sys.sys_user.avatar IS '头像';
COMMENT ON COLUMN dam_sys.sys_user.last_login_at IS '最后登录时间';
COMMENT ON COLUMN dam_sys.sys_user.last_login_ip IS '最后登录IP';
COMMENT ON COLUMN dam_sys.sys_user.password_hash IS '密码哈希（SHA-256 + 盐，融合自现平台）';
COMMENT ON COLUMN dam_sys.sys_user.salt IS '密码盐值（融合自现平台）';
COMMENT ON COLUMN dam_sys.sys_user.status IS '状态';
COMMENT ON COLUMN dam_sys.sys_user.created_at IS '创建时间';
COMMENT ON COLUMN dam_sys.sys_user.created_by IS '创建人';
COMMENT ON COLUMN dam_sys.sys_user.updated_at IS '更新时间';
COMMENT ON COLUMN dam_sys.sys_user.updated_by IS '更新人';
COMMENT ON COLUMN dam_sys.sys_user.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_sys.sys_user_role.user_id IS '用户ID';
COMMENT ON COLUMN dam_sys.sys_user_role.role_id IS '角色ID';
COMMENT ON COLUMN dam_sys.sys_user_role.default_role IS '是否默认角色';
COMMENT ON COLUMN dam_sys.sys_user_role.status IS '状态';
COMMENT ON COLUMN dam_sys.sys_user_role.created_at IS '创建时间';
COMMENT ON COLUMN dam_sys.sys_user_role.created_by IS '创建人';
COMMENT ON COLUMN dam_sys.sys_user_role.updated_at IS '更新时间';
COMMENT ON COLUMN dam_sys.sys_user_role.updated_by IS '更新人';
COMMENT ON COLUMN dam_sys.sys_user_role.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_sys.sys_permission.permission_code IS '权限编码';
COMMENT ON COLUMN dam_sys.sys_permission.permission_name IS '权限名称';
COMMENT ON COLUMN dam_sys.sys_permission.parent_id IS '父权限ID';
COMMENT ON COLUMN dam_sys.sys_permission.type IS '类型: menu/button/api';
COMMENT ON COLUMN dam_sys.sys_permission.path IS '路由路径';
COMMENT ON COLUMN dam_sys.sys_permission.icon IS '图标';
COMMENT ON COLUMN dam_sys.sys_permission.sort_order IS '排序序号';
COMMENT ON COLUMN dam_sys.sys_permission.status IS '状态';
COMMENT ON COLUMN dam_sys.sys_permission.created_at IS '创建时间';
COMMENT ON COLUMN dam_sys.sys_permission.created_by IS '创建人';
COMMENT ON COLUMN dam_sys.sys_permission.updated_at IS '更新时间';
COMMENT ON COLUMN dam_sys.sys_permission.updated_by IS '更新人';
COMMENT ON COLUMN dam_sys.sys_permission.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_sys.sys_role_permission.role_id IS '角色ID';
COMMENT ON COLUMN dam_sys.sys_role_permission.permission_id IS '权限ID';
COMMENT ON COLUMN dam_sys.sys_role_permission.status IS '状态';
COMMENT ON COLUMN dam_sys.sys_role_permission.created_at IS '创建时间';
COMMENT ON COLUMN dam_sys.sys_role_permission.created_by IS '创建人';
COMMENT ON COLUMN dam_sys.sys_role_permission.updated_at IS '更新时间';
COMMENT ON COLUMN dam_sys.sys_role_permission.updated_by IS '更新人';
COMMENT ON COLUMN dam_sys.sys_role_permission.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_sys.sys_config.config_type IS '配置分组：SYSTEM/NOTIFY/SECURITY/JOB';
COMMENT ON COLUMN dam_sys.sys_config.config_code IS '配置键';
COMMENT ON COLUMN dam_sys.sys_config.config_name IS '配置名称';
COMMENT ON COLUMN dam_sys.sys_config.config_value IS '配置值';
COMMENT ON COLUMN dam_sys.sys_config.description IS '配置说明';
COMMENT ON COLUMN dam_sys.sys_config.sort_order IS '排序序号';
COMMENT ON COLUMN dam_sys.sys_config.status IS '状态';
COMMENT ON COLUMN dam_sys.sys_config.created_at IS '创建时间';
COMMENT ON COLUMN dam_sys.sys_config.created_by IS '创建人';
COMMENT ON COLUMN dam_sys.sys_config.updated_at IS '更新时间';
COMMENT ON COLUMN dam_sys.sys_config.updated_by IS '更新人';
COMMENT ON COLUMN dam_sys.sys_config.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_sys.sys_menu.menu_name IS '菜单名称';
COMMENT ON COLUMN dam_sys.sys_menu.menu_type IS '类型M-目录，C-菜单，F-按钮';
COMMENT ON COLUMN dam_sys.sys_menu.parent_id IS '父菜单ID';
COMMENT ON COLUMN dam_sys.sys_menu.tree_level IS '树层级（根为1）';
COMMENT ON COLUMN dam_sys.sys_menu.path IS '路由地址';
COMMENT ON COLUMN dam_sys.sys_menu.component IS '组件路径';
COMMENT ON COLUMN dam_sys.sys_menu.redirect IS '重定向地址';
COMMENT ON COLUMN dam_sys.sys_menu.icon IS '图标名称';
COMMENT ON COLUMN dam_sys.sys_menu.sort_order IS '排序序号';
COMMENT ON COLUMN dam_sys.sys_menu.visible IS '0不显示1显示';
COMMENT ON COLUMN dam_sys.sys_menu.status IS '状态';
COMMENT ON COLUMN dam_sys.sys_menu.created_at IS '创建时间';
COMMENT ON COLUMN dam_sys.sys_menu.created_by IS '创建人';
COMMENT ON COLUMN dam_sys.sys_menu.updated_at IS '更新时间';
COMMENT ON COLUMN dam_sys.sys_menu.updated_by IS '更新人';
COMMENT ON COLUMN dam_sys.sys_menu.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_sys.sys_role_menu.role_id IS '角色ID';
COMMENT ON COLUMN dam_sys.sys_role_menu.menu_id IS '菜单ID';
COMMENT ON COLUMN dam_sys.sys_role_menu.status IS '状态';
COMMENT ON COLUMN dam_sys.sys_role_menu.created_at IS '创建时间';
COMMENT ON COLUMN dam_sys.sys_role_menu.created_by IS '创建人';
COMMENT ON COLUMN dam_sys.sys_role_menu.updated_at IS '更新时间';
COMMENT ON COLUMN dam_sys.sys_role_menu.updated_by IS '更新人';
COMMENT ON COLUMN dam_sys.sys_role_menu.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_sys.sys_dict_type.dict_type_code IS '字典类型编码';
COMMENT ON COLUMN dam_sys.sys_dict_type.dict_type_name IS '字典类型名称';
COMMENT ON COLUMN dam_sys.sys_dict_type.remark IS '备注';
COMMENT ON COLUMN dam_sys.sys_dict_type.status IS '状态';
COMMENT ON COLUMN dam_sys.sys_dict_type.created_at IS '创建时间';
COMMENT ON COLUMN dam_sys.sys_dict_type.created_by IS '创建人';
COMMENT ON COLUMN dam_sys.sys_dict_type.updated_at IS '更新时间';
COMMENT ON COLUMN dam_sys.sys_dict_type.updated_by IS '更新人';
COMMENT ON COLUMN dam_sys.sys_dict_type.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_sys.sys_dict_data.dict_type_id IS '字典类型ID';
COMMENT ON COLUMN dam_sys.sys_dict_data.dict_label IS '字典标签（界面展示名称，如：男、女）';
COMMENT ON COLUMN dam_sys.sys_dict_data.dict_value IS '字典值（代码存储值，如：M、F）';
COMMENT ON COLUMN dam_sys.sys_dict_data.dict_extra IS '扩展值（如样式类名、颜色值等UI辅助信息）';
COMMENT ON COLUMN dam_sys.sys_dict_data.sort_order IS '同级排序序号';
COMMENT ON COLUMN dam_sys.sys_dict_data.is_default IS '是否默认值';
COMMENT ON COLUMN dam_sys.sys_dict_data.remarks IS '备注';
COMMENT ON COLUMN dam_sys.sys_dict_data.status IS '状态';
COMMENT ON COLUMN dam_sys.sys_dict_data.created_at IS '创建时间';
COMMENT ON COLUMN dam_sys.sys_dict_data.created_by IS '创建人';
COMMENT ON COLUMN dam_sys.sys_dict_data.updated_at IS '更新时间';
COMMENT ON COLUMN dam_sys.sys_dict_data.updated_by IS '更新人';
COMMENT ON COLUMN dam_sys.sys_dict_data.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_sys.sys_audit_log.trace_id IS '链路追踪ID';
COMMENT ON COLUMN dam_sys.sys_audit_log.session_id IS '会话ID';
COMMENT ON COLUMN dam_sys.sys_audit_log.operator_id IS '操作人ID';
COMMENT ON COLUMN dam_sys.sys_audit_log.operator_ip IS '操作人IP地址';
COMMENT ON COLUMN dam_sys.sys_audit_log.user_agent IS '客户端UA';
COMMENT ON COLUMN dam_sys.sys_audit_log.module IS '操作模块';
COMMENT ON COLUMN dam_sys.sys_audit_log.operation IS '操作描述';
COMMENT ON COLUMN dam_sys.sys_audit_log.operation_type IS '操作类型';
COMMENT ON COLUMN dam_sys.sys_audit_log.target_type IS '目标类型';
COMMENT ON COLUMN dam_sys.sys_audit_log.target_id IS '目标ID';
COMMENT ON COLUMN dam_sys.sys_audit_log.target_name IS '目标名称';
COMMENT ON COLUMN dam_sys.sys_audit_log.request_method IS '请求方法';
COMMENT ON COLUMN dam_sys.sys_audit_log.request_url IS '请求URL';
COMMENT ON COLUMN dam_sys.sys_audit_log.request_params IS '请求参数';
COMMENT ON COLUMN dam_sys.sys_audit_log.response_status IS 'HTTP响应状态码';
COMMENT ON COLUMN dam_sys.sys_audit_log.response_body IS '响应体摘要';
COMMENT ON COLUMN dam_sys.sys_audit_log.duration_ms IS '响应耗时（毫秒）';
COMMENT ON COLUMN dam_sys.sys_audit_log.is_success IS '是否操作成功';
COMMENT ON COLUMN dam_sys.sys_audit_log.error_message IS '异常堆栈摘要';
COMMENT ON COLUMN dam_sys.sys_audit_log.risk_level IS '风险等级';
COMMENT ON COLUMN dam_sys.sys_audit_log.operation_time IS '操作时间';
COMMENT ON COLUMN dam_sys.sys_audit_log.created_at IS '创建时间';
COMMENT ON COLUMN dam_sys.sys_audit_log.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN dam_sys.sys_audit_log.created_by IS '创建人';
COMMENT ON COLUMN dam_sys.sys_audit_log.updated_at IS '更新时间';
COMMENT ON COLUMN dam_sys.sys_audit_log.updated_by IS '更新人';
COMMENT ON COLUMN dam_sys.sys_audit_log.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_sys_audit_log_target_type ON dam_sys.sys_audit_log(target_type);
CREATE INDEX IF NOT EXISTS idx_sys_audit_log_target_id ON dam_sys.sys_audit_log(target_id);
COMMENT ON COLUMN dam_metadata.metadata_category.category_name IS '分类名称（如：技术元数据、业务元数据、管理元数据）';
COMMENT ON COLUMN dam_metadata.metadata_category.category_code IS '分类编码（如：TECHNICAL、BUSINESS、MANAGEMENT），程序枚举引用';
COMMENT ON COLUMN dam_metadata.metadata_category.category_type IS '分类层级类型：ROOT-根分类（一级）、SUB-子分类（二级及以下）';
COMMENT ON COLUMN dam_metadata.metadata_category.parent_id IS '父分类ID（根分类的parent_id为NULL）';
COMMENT ON COLUMN dam_metadata.metadata_category.tree_level IS '树层级（根为1，子类依次递增）';
COMMENT ON COLUMN dam_metadata.metadata_category.full_path IS '分类全路径（如：/技术元数据/数据库表），便于前端面包屑展示';
COMMENT ON COLUMN dam_metadata.metadata_category.icon IS '图标名称（前端展示用）';
COMMENT ON COLUMN dam_metadata.metadata_category.description IS '分类描述说明';
COMMENT ON COLUMN dam_metadata.metadata_category.sort_order IS '同级排序序号';
COMMENT ON COLUMN dam_metadata.metadata_category.status IS '状态';
COMMENT ON COLUMN dam_metadata.metadata_category.created_at IS '创建时间';
COMMENT ON COLUMN dam_metadata.metadata_category.created_by IS '创建人';
COMMENT ON COLUMN dam_metadata.metadata_category.updated_at IS '更新时间';
COMMENT ON COLUMN dam_metadata.metadata_category.updated_by IS '更新人';
COMMENT ON COLUMN dam_metadata.metadata_category.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_metadata.metadata_datasource.ds_name IS '数据源名称';
COMMENT ON COLUMN dam_metadata.metadata_datasource.ds_code IS '数据源代码';
COMMENT ON COLUMN dam_metadata.metadata_datasource.ds_type IS '数据源类型';
COMMENT ON COLUMN dam_metadata.metadata_datasource.ds_adapter IS '数据源适配器';
COMMENT ON COLUMN dam_metadata.metadata_datasource.ds_ip IS '数据源IP';
COMMENT ON COLUMN dam_metadata.metadata_datasource.ds_port IS '数据源端口';
COMMENT ON COLUMN dam_metadata.metadata_datasource.jdbc_url IS 'Jdbc连接url';
COMMENT ON COLUMN dam_metadata.metadata_datasource.username IS '用户名';
COMMENT ON COLUMN dam_metadata.metadata_datasource.password IS '密码（加密存储，AES-256，密钥走 sys_config）';
COMMENT ON COLUMN dam_metadata.metadata_datasource.driver_class IS '驱动类';
COMMENT ON COLUMN dam_metadata.metadata_datasource.connection_props IS '额外连接参数';
COMMENT ON COLUMN dam_metadata.metadata_datasource.description IS '描述';
COMMENT ON COLUMN dam_metadata.metadata_datasource.status IS '状态';
COMMENT ON COLUMN dam_metadata.metadata_datasource.created_at IS '创建时间';
COMMENT ON COLUMN dam_metadata.metadata_datasource.created_by IS '创建人';
COMMENT ON COLUMN dam_metadata.metadata_datasource.updated_at IS '更新时间';
COMMENT ON COLUMN dam_metadata.metadata_datasource.updated_by IS '更新人';
COMMENT ON COLUMN dam_metadata.metadata_datasource.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_metadata.metadata_schema.datasource_id IS '所属数据源ID';
COMMENT ON COLUMN dam_metadata.metadata_schema.schema_name IS 'Schema名称';
COMMENT ON COLUMN dam_metadata.metadata_schema.schema_comment IS 'Schema注释';
COMMENT ON COLUMN dam_metadata.metadata_schema.schema_type IS 'Schema类型（如：DATABASE、CATALOG、VIRTUAL）';
COMMENT ON COLUMN dam_metadata.metadata_schema.schema_owner IS 'Schema负责人ID';
COMMENT ON COLUMN dam_metadata.metadata_schema.environment IS '环境标识：PROD-生产、TEST-测试、DEV-开发';
COMMENT ON COLUMN dam_metadata.metadata_schema.location IS '物理存储路径（如HDFS路径、S3路径）';
COMMENT ON COLUMN dam_metadata.metadata_schema.properties IS '扩展属性（JSON格式，如字符集、排序规则等）';
COMMENT ON COLUMN dam_metadata.metadata_schema.status IS '状态';
COMMENT ON COLUMN dam_metadata.metadata_schema.created_at IS '创建时间';
COMMENT ON COLUMN dam_metadata.metadata_schema.created_by IS '创建人';
COMMENT ON COLUMN dam_metadata.metadata_schema.updated_at IS '更新时间';
COMMENT ON COLUMN dam_metadata.metadata_schema.updated_by IS '更新人';
COMMENT ON COLUMN dam_metadata.metadata_schema.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_metadata_schema_datasource_id ON dam_metadata.metadata_schema(datasource_id);
COMMENT ON COLUMN dam_metadata.metadata_table.datasource_id IS '所属数据源ID';
COMMENT ON COLUMN dam_metadata.metadata_table.schema_id IS 'Schema ID（关联 metadata_schema.id，类型统一）';
COMMENT ON COLUMN dam_metadata.metadata_table.table_name IS '表名';
COMMENT ON COLUMN dam_metadata.metadata_table.table_comment IS '表注释';
COMMENT ON COLUMN dam_metadata.metadata_table.table_type IS '表类型：TABLE/VIEW';
COMMENT ON COLUMN dam_metadata.metadata_table.row_count IS '行数';
COMMENT ON COLUMN dam_metadata.metadata_table.table_size IS '表大小（字节）';
COMMENT ON COLUMN dam_metadata.metadata_table.created_time IS '表创建时间';
COMMENT ON COLUMN dam_metadata.metadata_table.last_modified IS '最后修改时间';
COMMENT ON COLUMN dam_metadata.metadata_table.last_sync_time IS '最后同步时间';
COMMENT ON COLUMN dam_metadata.metadata_table.status IS '状态';
COMMENT ON COLUMN dam_metadata.metadata_table.created_at IS '创建时间';
COMMENT ON COLUMN dam_metadata.metadata_table.created_by IS '创建人';
COMMENT ON COLUMN dam_metadata.metadata_table.updated_at IS '更新时间';
COMMENT ON COLUMN dam_metadata.metadata_table.updated_by IS '更新人';
COMMENT ON COLUMN dam_metadata.metadata_table.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_metadata_table_datasource_id ON dam_metadata.metadata_table(datasource_id);
CREATE INDEX IF NOT EXISTS idx_metadata_table_schema_id ON dam_metadata.metadata_table(schema_id);
COMMENT ON COLUMN dam_metadata.metadata_column.datasource_id IS '所属数据源ID';
COMMENT ON COLUMN dam_metadata.metadata_column.schema_id IS 'Schema ID（关联 metadata_schema.id，类型统一 int8）';
COMMENT ON COLUMN dam_metadata.metadata_column.table_id IS '所属表ID';
COMMENT ON COLUMN dam_metadata.metadata_column.column_name IS '字段名（非空约束补齐）';
COMMENT ON COLUMN dam_metadata.metadata_column.column_type IS '字段类型';
COMMENT ON COLUMN dam_metadata.metadata_column.column_length IS '字段长度';
COMMENT ON COLUMN dam_metadata.metadata_column.is_nullable IS '是否可空';
COMMENT ON COLUMN dam_metadata.metadata_column.is_primary_key IS '是否主键';
COMMENT ON COLUMN dam_metadata.metadata_column.is_foreign_key IS '是否外键';
COMMENT ON COLUMN dam_metadata.metadata_column.default_value IS '默认值';
COMMENT ON COLUMN dam_metadata.metadata_column.column_comment IS '字段注释';
COMMENT ON COLUMN dam_metadata.metadata_column.ordinal_position IS '字段顺序';
COMMENT ON COLUMN dam_metadata.metadata_column.status IS '状态';
COMMENT ON COLUMN dam_metadata.metadata_column.created_at IS '创建时间';
COMMENT ON COLUMN dam_metadata.metadata_column.created_by IS '创建人';
COMMENT ON COLUMN dam_metadata.metadata_column.updated_at IS '更新时间';
COMMENT ON COLUMN dam_metadata.metadata_column.updated_by IS '更新人';
COMMENT ON COLUMN dam_metadata.metadata_column.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_metadata_column_datasource_id ON dam_metadata.metadata_column(datasource_id);
CREATE INDEX IF NOT EXISTS idx_metadata_column_schema_id ON dam_metadata.metadata_column(schema_id);
CREATE INDEX IF NOT EXISTS idx_metadata_column_table_id ON dam_metadata.metadata_column(table_id);
COMMENT ON COLUMN dam_metadata.metadata_business.business_code IS '业务代码';
COMMENT ON COLUMN dam_metadata.metadata_business.business_name IS '业务名称';
COMMENT ON COLUMN dam_metadata.metadata_business.business_definition IS '业务定义/描述';
COMMENT ON COLUMN dam_metadata.metadata_business.business_owner_id IS '业务负责人';
COMMENT ON COLUMN dam_metadata.metadata_business.data_domain_id IS '数据域';
COMMENT ON COLUMN dam_metadata.metadata_business.business_domain_id IS '业务域';
COMMENT ON COLUMN dam_metadata.metadata_business.business_process IS '业务流程';
COMMENT ON COLUMN dam_metadata.metadata_business.data_steward_id IS '数据管家ID';
COMMENT ON COLUMN dam_metadata.metadata_business.criticality_level IS '业务重要性';
COMMENT ON COLUMN dam_metadata.metadata_business.data_quality_rules_id IS '数据质量规则ID';
COMMENT ON COLUMN dam_metadata.metadata_business.tags IS '标签数组';
COMMENT ON COLUMN dam_metadata.metadata_business.status IS '状态';
COMMENT ON COLUMN dam_metadata.metadata_business.created_at IS '创建时间';
COMMENT ON COLUMN dam_metadata.metadata_business.created_by IS '创建人';
COMMENT ON COLUMN dam_metadata.metadata_business.updated_at IS '更新时间';
COMMENT ON COLUMN dam_metadata.metadata_business.updated_by IS '更新人';
COMMENT ON COLUMN dam_metadata.metadata_business.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_metadata.metadata_business_table_rel.business_id IS '业务实体ID';
COMMENT ON COLUMN dam_metadata.metadata_business_table_rel.table_id IS '技术元数据表ID';
COMMENT ON COLUMN dam_metadata.metadata_business_table_rel.mapping_type_id IS '映射类型ID';
COMMENT ON COLUMN dam_metadata.metadata_business_table_rel.mapping_comment IS '映射说明';
COMMENT ON COLUMN dam_metadata.metadata_business_table_rel.status IS '状态';
COMMENT ON COLUMN dam_metadata.metadata_business_table_rel.created_at IS '创建时间';
COMMENT ON COLUMN dam_metadata.metadata_business_table_rel.created_by IS '创建人';
COMMENT ON COLUMN dam_metadata.metadata_business_table_rel.updated_at IS '更新时间';
COMMENT ON COLUMN dam_metadata.metadata_business_table_rel.updated_by IS '更新人';
COMMENT ON COLUMN dam_metadata.metadata_business_table_rel.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_metadata_business_table_rel_table_id ON dam_metadata.metadata_business_table_rel(table_id);
COMMENT ON COLUMN dam_metadata.metadata_management.table_id IS '关联技术元数据表ID';
COMMENT ON COLUMN dam_metadata.metadata_management.governance_status_id IS '治理状态id';
COMMENT ON COLUMN dam_metadata.metadata_management.lifecycle_status_id IS '生命周期状态id';
COMMENT ON COLUMN dam_metadata.metadata_management.retention_days IS '数据保留天数';
COMMENT ON COLUMN dam_metadata.metadata_management.source_system_id IS '数据来源系统id';
COMMENT ON COLUMN dam_metadata.metadata_management.etl_workflow IS 'ETL/数据集成工作流名称';
COMMENT ON COLUMN dam_metadata.metadata_management.last_accessed_at IS '最后被访问/查询的时间';
COMMENT ON COLUMN dam_metadata.metadata_management.daily_query_avg IS '日均查询次数';
COMMENT ON COLUMN dam_metadata.metadata_management.security_classification IS '安全分级id';
COMMENT ON COLUMN dam_metadata.metadata_management.data_verification_status IS '数据验证状态id';
COMMENT ON COLUMN dam_metadata.metadata_management.registration_batch_id IS '注册批次ID';
COMMENT ON COLUMN dam_metadata.metadata_management.last_ddl_time IS '表结构变更时间';
COMMENT ON COLUMN dam_metadata.metadata_management.audit_remark IS '审计备注';
COMMENT ON COLUMN dam_metadata.metadata_management.extend_props IS '扩展属性';
COMMENT ON COLUMN dam_metadata.metadata_management.status IS '状态';
COMMENT ON COLUMN dam_metadata.metadata_management.created_at IS '创建时间';
COMMENT ON COLUMN dam_metadata.metadata_management.created_by IS '创建人';
COMMENT ON COLUMN dam_metadata.metadata_management.updated_at IS '更新时间';
COMMENT ON COLUMN dam_metadata.metadata_management.updated_by IS '更新人';
COMMENT ON COLUMN dam_metadata.metadata_management.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_metadata_management_table_id ON dam_metadata.metadata_management(table_id);
COMMENT ON COLUMN dam_metadata.source_system.system_code IS '系统代码';
COMMENT ON COLUMN dam_metadata.source_system.system_name IS '系统名称';
COMMENT ON COLUMN dam_metadata.source_system.description IS '描述';
COMMENT ON COLUMN dam_metadata.source_system.status IS '状态';
COMMENT ON COLUMN dam_metadata.source_system.created_at IS '创建时间';
COMMENT ON COLUMN dam_metadata.source_system.created_by IS '创建人';
COMMENT ON COLUMN dam_metadata.source_system.updated_at IS '更新时间';
COMMENT ON COLUMN dam_metadata.source_system.updated_by IS '更新人';
COMMENT ON COLUMN dam_metadata.source_system.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_metadata.metadata_collection.datasource_id IS '数据源ID';
COMMENT ON COLUMN dam_metadata.metadata_collection.schema_id IS 'Schema ID（关联 metadata_schema.id，类型统一）';
COMMENT ON COLUMN dam_metadata.metadata_collection.job_name IS '任务名称';
COMMENT ON COLUMN dam_metadata.metadata_collection.job_type IS '任务类型';
COMMENT ON COLUMN dam_metadata.metadata_collection.start_time IS '开始时间';
COMMENT ON COLUMN dam_metadata.metadata_collection.end_time IS '结束时间';
COMMENT ON COLUMN dam_metadata.metadata_collection.total_tables IS '采集总表数';
COMMENT ON COLUMN dam_metadata.metadata_collection.total_columns IS '采集总字段数';
COMMENT ON COLUMN dam_metadata.metadata_collection.success_count IS '成功数量';
COMMENT ON COLUMN dam_metadata.metadata_collection.fail_count IS '失败数量';
COMMENT ON COLUMN dam_metadata.metadata_collection.error_message IS '错误日志';
COMMENT ON COLUMN dam_metadata.metadata_collection.detail_log IS '详细日志';
COMMENT ON COLUMN dam_metadata.metadata_collection.status IS '状态';
COMMENT ON COLUMN dam_metadata.metadata_collection.created_at IS '创建时间';
COMMENT ON COLUMN dam_metadata.metadata_collection.created_by IS '创建人';
COMMENT ON COLUMN dam_metadata.metadata_collection.updated_at IS '更新时间';
COMMENT ON COLUMN dam_metadata.metadata_collection.updated_by IS '更新人';
COMMENT ON COLUMN dam_metadata.metadata_collection.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_metadata_collection_datasource_id ON dam_metadata.metadata_collection(datasource_id);
CREATE INDEX IF NOT EXISTS idx_metadata_collection_schema_id ON dam_metadata.metadata_collection(schema_id);
COMMENT ON COLUMN dam_metadata.metadata_version.datasource_id IS '数据源ID';
COMMENT ON COLUMN dam_metadata.metadata_version.schema_id IS 'schemaID';
COMMENT ON COLUMN dam_metadata.metadata_version.table_id IS '表ID';
COMMENT ON COLUMN dam_metadata.metadata_version.version_number IS '版本号';
COMMENT ON COLUMN dam_metadata.metadata_version.change_type IS '变更类型';
COMMENT ON COLUMN dam_metadata.metadata_version.change_summary IS '变更摘要';
COMMENT ON COLUMN dam_metadata.metadata_version.snapshot_data IS '版本快照';
COMMENT ON COLUMN dam_metadata.metadata_version.diff_summary IS '差异摘要';
COMMENT ON COLUMN dam_metadata.metadata_version.changed_by IS '变更人';
COMMENT ON COLUMN dam_metadata.metadata_version.changed_at IS '变更时间';
COMMENT ON COLUMN dam_metadata.metadata_version.status IS '状态';
COMMENT ON COLUMN dam_metadata.metadata_version.created_at IS '创建时间';
COMMENT ON COLUMN dam_metadata.metadata_version.created_by IS '创建人';
COMMENT ON COLUMN dam_metadata.metadata_version.updated_at IS '更新时间';
COMMENT ON COLUMN dam_metadata.metadata_version.updated_by IS '更新人';
COMMENT ON COLUMN dam_metadata.metadata_version.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_metadata_version_datasource_id ON dam_metadata.metadata_version(datasource_id);
CREATE INDEX IF NOT EXISTS idx_metadata_version_schema_id ON dam_metadata.metadata_version(schema_id);
CREATE INDEX IF NOT EXISTS idx_metadata_version_table_id ON dam_metadata.metadata_version(table_id);
COMMENT ON COLUMN dam_metadata.metadata_lineage.source_type IS '源节点类型';
COMMENT ON COLUMN dam_metadata.metadata_lineage.source_id IS '源节点ID';
COMMENT ON COLUMN dam_metadata.metadata_lineage.target_type IS '目标节点类型';
COMMENT ON COLUMN dam_metadata.metadata_lineage.target_id IS '目标节点ID';
COMMENT ON COLUMN dam_metadata.metadata_lineage.relation_type IS '关系类型';
COMMENT ON COLUMN dam_metadata.metadata_lineage.transform_rule IS '转换规则';
COMMENT ON COLUMN dam_metadata.metadata_lineage.dependency_level IS '依赖层级';
COMMENT ON COLUMN dam_metadata.metadata_lineage.source_system IS '来源系统标识';
COMMENT ON COLUMN dam_metadata.metadata_lineage.collection_id IS '关联采集记录ID';
COMMENT ON COLUMN dam_metadata.metadata_lineage.discovered_by IS '发现方式';
COMMENT ON COLUMN dam_metadata.metadata_lineage.status IS '状态';
COMMENT ON COLUMN dam_metadata.metadata_lineage.created_at IS '创建时间';
COMMENT ON COLUMN dam_metadata.metadata_lineage.created_by IS '创建人';
COMMENT ON COLUMN dam_metadata.metadata_lineage.updated_at IS '更新时间';
COMMENT ON COLUMN dam_metadata.metadata_lineage.updated_by IS '更新人';
COMMENT ON COLUMN dam_metadata.metadata_lineage.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_metadata_lineage_source_type ON dam_metadata.metadata_lineage(source_type);
CREATE INDEX IF NOT EXISTS idx_metadata_lineage_source_id ON dam_metadata.metadata_lineage(source_id);
CREATE INDEX IF NOT EXISTS idx_metadata_lineage_target_type ON dam_metadata.metadata_lineage(target_type);
CREATE INDEX IF NOT EXISTS idx_metadata_lineage_target_id ON dam_metadata.metadata_lineage(target_id);
CREATE INDEX IF NOT EXISTS idx_metadata_lineage_collection_id ON dam_metadata.metadata_lineage(collection_id);
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.rule_code IS '规则编码';
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.rule_type IS '规则名称';
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.rule_level IS '级别';
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.target_table_id IS '目标表ID';
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.target_column IS '目标字段名（空为全表）';
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.rule_expression IS '规则表达式或自定义SQL';
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.expect_value IS '期望值（如 > 0.95）';
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.severity IS '严重程度';
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.is_scheduled IS '是否定时执行';
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.cron_expression IS '定时表达式';
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.description IS '规则描述';
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.status IS '状态';
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.created_at IS '创建时间';
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.created_by IS '创建人';
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.updated_at IS '更新时间';
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.updated_by IS '更新人';
COMMENT ON COLUMN dam_metadata.metadata_quality_rule.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_metadata.metadata_quality_check_result.rule_id IS '规则ID';
COMMENT ON COLUMN dam_metadata.metadata_quality_check_result.check_time IS '检测时间';
COMMENT ON COLUMN dam_metadata.metadata_quality_check_result.total_count IS '总记录数';
COMMENT ON COLUMN dam_metadata.metadata_quality_check_result.pass_count IS '通过记录数';
COMMENT ON COLUMN dam_metadata.metadata_quality_check_result.fail_count IS '不通过记录数';
COMMENT ON COLUMN dam_metadata.metadata_quality_check_result.pass_rate IS '通过率';
COMMENT ON COLUMN dam_metadata.metadata_quality_check_result.result_status IS '结果状态';
COMMENT ON COLUMN dam_metadata.metadata_quality_check_result.fail_samples IS '失败样例';
COMMENT ON COLUMN dam_metadata.metadata_quality_check_result.error_detail IS '错误详情';
COMMENT ON COLUMN dam_metadata.metadata_quality_check_result.executed_by IS '执行人';
COMMENT ON COLUMN dam_metadata.metadata_quality_check_result.status IS '状态';
COMMENT ON COLUMN dam_metadata.metadata_quality_check_result.created_at IS '创建时间';
COMMENT ON COLUMN dam_metadata.metadata_quality_check_result.created_by IS '创建人';
COMMENT ON COLUMN dam_metadata.metadata_quality_check_result.updated_at IS '更新时间';
COMMENT ON COLUMN dam_metadata.metadata_quality_check_result.updated_by IS '更新人';
COMMENT ON COLUMN dam_metadata.metadata_quality_check_result.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.policy_code IS '策略代码';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.policy_name IS '策略名';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.target_type IS '目标类型';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.target_id IS '目标ID';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.hot_days IS '热数据保留天数';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.cold_days IS '冷数据保留天数';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.archive_days IS '归档触发天数';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.purge_days IS '清理触发天数';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.cold_storage_location IS '冷存储路径';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.archive_storage_location IS '归档存储路径';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.archive_format IS '归档格式';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.auto_execute IS '是否自动执行';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.last_execute_time IS '最后执行时间';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.description IS '策略描述';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.status IS '状态';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.created_at IS '创建时间';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.created_by IS '创建人';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.updated_at IS '更新时间';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.updated_by IS '更新人';
COMMENT ON COLUMN dam_metadata.metadata_lifecycle_policy.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_metadata_lifecycle_policy_target_type ON dam_metadata.metadata_lifecycle_policy(target_type);
CREATE INDEX IF NOT EXISTS idx_metadata_lifecycle_policy_target_id ON dam_metadata.metadata_lifecycle_policy(target_id);
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.destruction_no IS '销毁单号';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.target_type IS '目标类型';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.target_id IS '目标ID';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.target_name IS '目标名称';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.destruction_reason IS '销毁理由';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.destruction_scope IS '范围';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.filter_condition IS '筛选条件';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.affected_rows IS '影响行数';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.destruction_method IS '销毁方法';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.requester_id IS '申请人ID';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.approver_id IS '审批人ID';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.executor_id IS '执行人ID';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.requested_at IS '申请时间';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.approved_at IS '审批时间';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.executed_at IS '执行时间';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.remark IS '备注';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.status IS '状态';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.created_at IS '创建时间';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.created_by IS '创建人';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.updated_at IS '更新时间';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.updated_by IS '更新人';
COMMENT ON COLUMN dam_metadata.metadata_destruction_record.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_metadata_destruction_record_target_type ON dam_metadata.metadata_destruction_record(target_type);
CREATE INDEX IF NOT EXISTS idx_metadata_destruction_record_target_id ON dam_metadata.metadata_destruction_record(target_id);
COMMENT ON COLUMN dam_asset.asset_category.category_code IS '分类编码';
COMMENT ON COLUMN dam_asset.asset_category.category_name IS '分类名称';
COMMENT ON COLUMN dam_asset.asset_category.parent_id IS '父分类ID';
COMMENT ON COLUMN dam_asset.asset_category.tree_level IS '树层级';
COMMENT ON COLUMN dam_asset.asset_category.category_path IS '分类全路径';
COMMENT ON COLUMN dam_asset.asset_category.description IS '分类描述';
COMMENT ON COLUMN dam_asset.asset_category.sort_order IS '排序序号';
COMMENT ON COLUMN dam_asset.asset_category.status IS '状态';
COMMENT ON COLUMN dam_asset.asset_category.created_at IS '创建时间';
COMMENT ON COLUMN dam_asset.asset_category.created_by IS '创建人';
COMMENT ON COLUMN dam_asset.asset_category.updated_at IS '更新时间';
COMMENT ON COLUMN dam_asset.asset_category.updated_by IS '更新人';
COMMENT ON COLUMN dam_asset.asset_category.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_asset.asset_info.asset_code IS '资产编码';
COMMENT ON COLUMN dam_asset.asset_info.asset_name IS '资产名称';
COMMENT ON COLUMN dam_asset.asset_info.asset_type_id IS '资产类型ID';
COMMENT ON COLUMN dam_asset.asset_info.category_id IS '所属分类ID';
COMMENT ON COLUMN dam_asset.asset_info.description IS '资产描述';
COMMENT ON COLUMN dam_asset.asset_info.business_owner_id IS '业务负责人ID';
COMMENT ON COLUMN dam_asset.asset_info.tech_owner_id IS '技术负责人ID';
COMMENT ON COLUMN dam_asset.asset_info.data_owner_id IS '数据负责人ID';
COMMENT ON COLUMN dam_asset.asset_info.source_system_id IS '来源系统ID';
COMMENT ON COLUMN dam_asset.asset_info.data_source_id IS '数据源ID';
COMMENT ON COLUMN dam_asset.asset_info.source_metadata_type IS '元数据实体类型';
COMMENT ON COLUMN dam_asset.asset_info.source_metadata_id IS '元数据实体ID';
COMMENT ON COLUMN dam_asset.asset_info.storage_location IS '存储位置';
COMMENT ON COLUMN dam_asset.asset_info.row_count IS '数据行数';
COMMENT ON COLUMN dam_asset.asset_info.storage_size IS '存储大小（字节）';
COMMENT ON COLUMN dam_asset.asset_info.quality_score IS '质量评分';
COMMENT ON COLUMN dam_asset.asset_info.popularity IS '热度（访问次数）';
COMMENT ON COLUMN dam_asset.asset_info.published_status IS '发布状态';
COMMENT ON COLUMN dam_asset.asset_info.published_at IS '发布时间';
COMMENT ON COLUMN dam_asset.asset_info.status IS '状态';
COMMENT ON COLUMN dam_asset.asset_info.created_at IS '创建时间';
COMMENT ON COLUMN dam_asset.asset_info.created_by IS '创建人';
COMMENT ON COLUMN dam_asset.asset_info.updated_at IS '更新时间';
COMMENT ON COLUMN dam_asset.asset_info.updated_by IS '更新人';
COMMENT ON COLUMN dam_asset.asset_info.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_asset_info_category_id ON dam_asset.asset_info(category_id);
COMMENT ON COLUMN dam_asset.asset_tag.tag_code IS '标签代码';
COMMENT ON COLUMN dam_asset.asset_tag.tag_name IS '标签名称';
COMMENT ON COLUMN dam_asset.asset_tag.tag_color IS '标签颜色';
COMMENT ON COLUMN dam_asset.asset_tag.tag_scope IS '标签范围';
COMMENT ON COLUMN dam_asset.asset_tag.tag_type IS '标签类型';
COMMENT ON COLUMN dam_asset.asset_tag.description IS '描述';
COMMENT ON COLUMN dam_asset.asset_tag.usage_count IS '引用次数';
COMMENT ON COLUMN dam_asset.asset_tag.status IS '状态';
COMMENT ON COLUMN dam_asset.asset_tag.created_at IS '创建时间';
COMMENT ON COLUMN dam_asset.asset_tag.created_by IS '创建人';
COMMENT ON COLUMN dam_asset.asset_tag.updated_at IS '更新时间';
COMMENT ON COLUMN dam_asset.asset_tag.updated_by IS '更新人';
COMMENT ON COLUMN dam_asset.asset_tag.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_asset.asset_tag_rel.asset_id IS '资产ID';
COMMENT ON COLUMN dam_asset.asset_tag_rel.tag_id IS '标签ID';
COMMENT ON COLUMN dam_asset.asset_tag_rel.status IS '状态';
COMMENT ON COLUMN dam_asset.asset_tag_rel.created_at IS '创建时间';
COMMENT ON COLUMN dam_asset.asset_tag_rel.created_by IS '创建人';
COMMENT ON COLUMN dam_asset.asset_tag_rel.updated_at IS '更新时间';
COMMENT ON COLUMN dam_asset.asset_tag_rel.updated_by IS '更新人';
COMMENT ON COLUMN dam_asset.asset_tag_rel.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_asset_tag_rel_asset_id ON dam_asset.asset_tag_rel(asset_id);
COMMENT ON COLUMN dam_asset.asset_favorite.asset_id IS '资产ID';
COMMENT ON COLUMN dam_asset.asset_favorite.user_id IS '用户ID';
COMMENT ON COLUMN dam_asset.asset_favorite.folder_name IS '收藏夹名称';
COMMENT ON COLUMN dam_asset.asset_favorite.favorite_time IS '收藏时间';
COMMENT ON COLUMN dam_asset.asset_favorite.status IS '状态';
COMMENT ON COLUMN dam_asset.asset_favorite.created_at IS '创建时间';
COMMENT ON COLUMN dam_asset.asset_favorite.created_by IS '创建人';
COMMENT ON COLUMN dam_asset.asset_favorite.updated_at IS '更新时间';
COMMENT ON COLUMN dam_asset.asset_favorite.updated_by IS '更新人';
COMMENT ON COLUMN dam_asset.asset_favorite.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_asset_favorite_asset_id ON dam_asset.asset_favorite(asset_id);
COMMENT ON COLUMN dam_asset.asset_rating.asset_id IS '资产ID';
COMMENT ON COLUMN dam_asset.asset_rating.rating_score IS '资产评分（1~5）';
COMMENT ON COLUMN dam_asset.asset_rating.rating_comment IS '评价内容';
COMMENT ON COLUMN dam_asset.asset_rating.rating_dimension IS '评价维度';
COMMENT ON COLUMN dam_asset.asset_rating.user_id IS '评价人ID';
COMMENT ON COLUMN dam_asset.asset_rating.status IS '状态';
COMMENT ON COLUMN dam_asset.asset_rating.created_at IS '创建时间';
COMMENT ON COLUMN dam_asset.asset_rating.created_by IS '创建人';
COMMENT ON COLUMN dam_asset.asset_rating.updated_at IS '更新时间';
COMMENT ON COLUMN dam_asset.asset_rating.updated_by IS '更新人';
COMMENT ON COLUMN dam_asset.asset_rating.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_asset_rating_asset_id ON dam_asset.asset_rating(asset_id);
COMMENT ON COLUMN dam_asset.asset_usage_log.asset_id IS '资产ID';
COMMENT ON COLUMN dam_asset.asset_usage_log.user_id IS '用户ID';
COMMENT ON COLUMN dam_asset.asset_usage_log.action_type IS '操作类型';
COMMENT ON COLUMN dam_asset.asset_usage_log.action_detail IS '操作详情';
COMMENT ON COLUMN dam_asset.asset_usage_log.ip_address IS 'IP';
COMMENT ON COLUMN dam_asset.asset_usage_log.user_agent IS '用户代理';
COMMENT ON COLUMN dam_asset.asset_usage_log.status IS '状态';
COMMENT ON COLUMN dam_asset.asset_usage_log.created_at IS '创建时间';
COMMENT ON COLUMN dam_asset.asset_usage_log.created_by IS '创建人';
COMMENT ON COLUMN dam_asset.asset_usage_log.updated_at IS '更新时间';
COMMENT ON COLUMN dam_asset.asset_usage_log.updated_by IS '更新人';
COMMENT ON COLUMN dam_asset.asset_usage_log.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_asset_usage_log_asset_id ON dam_asset.asset_usage_log(asset_id);
COMMENT ON COLUMN dam_model.model_domain.domain_code IS '主题域代码';
COMMENT ON COLUMN dam_model.model_domain.domain_name IS '主题域名称';
COMMENT ON COLUMN dam_model.model_domain.parent_id IS '父主题域ID';
COMMENT ON COLUMN dam_model.model_domain.description IS '描述';
COMMENT ON COLUMN dam_model.model_domain.sort_order IS '排序序号';
COMMENT ON COLUMN dam_model.model_domain.status IS '状态';
COMMENT ON COLUMN dam_model.model_domain.created_at IS '创建时间';
COMMENT ON COLUMN dam_model.model_domain.created_by IS '创建人';
COMMENT ON COLUMN dam_model.model_domain.updated_at IS '更新时间';
COMMENT ON COLUMN dam_model.model_domain.updated_by IS '更新人';
COMMENT ON COLUMN dam_model.model_domain.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_model.model_fact.domain_id IS '所属主题域ID';
COMMENT ON COLUMN dam_model.model_fact.fact_code IS '事实代码';
COMMENT ON COLUMN dam_model.model_fact.fact_name IS '事实名称';
COMMENT ON COLUMN dam_model.model_fact.source_table_id IS '源表ID';
COMMENT ON COLUMN dam_model.model_fact.granularity IS '粒度描述';
COMMENT ON COLUMN dam_model.model_fact.description IS '描述';
COMMENT ON COLUMN dam_model.model_fact.status IS '状态';
COMMENT ON COLUMN dam_model.model_fact.created_at IS '创建时间';
COMMENT ON COLUMN dam_model.model_fact.created_by IS '创建人';
COMMENT ON COLUMN dam_model.model_fact.updated_at IS '更新时间';
COMMENT ON COLUMN dam_model.model_fact.updated_by IS '更新人';
COMMENT ON COLUMN dam_model.model_fact.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_model.model_dimension.domain_id IS '所属主题域ID';
COMMENT ON COLUMN dam_model.model_dimension.dimension_code IS '维度代码';
COMMENT ON COLUMN dam_model.model_dimension.dimension_name IS '维度名称';
COMMENT ON COLUMN dam_model.model_dimension.dimension_type_id IS '维度类型ID';
COMMENT ON COLUMN dam_model.model_dimension.source_table_id IS '源表ID';
COMMENT ON COLUMN dam_model.model_dimension.description IS '描述';
COMMENT ON COLUMN dam_model.model_dimension.status IS '状态';
COMMENT ON COLUMN dam_model.model_dimension.created_at IS '创建时间';
COMMENT ON COLUMN dam_model.model_dimension.created_by IS '创建人';
COMMENT ON COLUMN dam_model.model_dimension.updated_at IS '更新时间';
COMMENT ON COLUMN dam_model.model_dimension.updated_by IS '更新人';
COMMENT ON COLUMN dam_model.model_dimension.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_model.model_column_mapping.model_id IS '模型ID';
COMMENT ON COLUMN dam_model.model_column_mapping.model_type IS '模型类型：事实、维度';
COMMENT ON COLUMN dam_model.model_column_mapping.source_table_id IS '源表ID';
COMMENT ON COLUMN dam_model.model_column_mapping.source_column_id IS '源字段ID';
COMMENT ON COLUMN dam_model.model_column_mapping.target_column_name IS '目标字段';
COMMENT ON COLUMN dam_model.model_column_mapping.target_column_type IS '目标字段类型';
COMMENT ON COLUMN dam_model.model_column_mapping.is_primary_key IS '是否主键';
COMMENT ON COLUMN dam_model.model_column_mapping.is_foreign_key IS '是否外键';
COMMENT ON COLUMN dam_model.model_column_mapping.ref_dimension_id IS '引用维度ID';
COMMENT ON COLUMN dam_model.model_column_mapping.transform_rule IS '转换规则';
COMMENT ON COLUMN dam_model.model_column_mapping.sort_order IS '排序序号';
COMMENT ON COLUMN dam_model.model_column_mapping.status IS '状态';
COMMENT ON COLUMN dam_model.model_column_mapping.created_at IS '创建时间';
COMMENT ON COLUMN dam_model.model_column_mapping.created_by IS '创建人';
COMMENT ON COLUMN dam_model.model_column_mapping.updated_at IS '更新时间';
COMMENT ON COLUMN dam_model.model_column_mapping.updated_by IS '更新人';
COMMENT ON COLUMN dam_model.model_column_mapping.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_security.security_sensitive_rule.rule_code IS '规则代码';
COMMENT ON COLUMN dam_security.security_sensitive_rule.rule_name IS '规则名称';
COMMENT ON COLUMN dam_security.security_sensitive_rule.sensitivity_level IS '敏感登记';
COMMENT ON COLUMN dam_security.security_sensitive_rule.rule_type IS '规则类型';
COMMENT ON COLUMN dam_security.security_sensitive_rule.rule_pattern IS '匹配模式';
COMMENT ON COLUMN dam_security.security_sensitive_rule.dictionary_id IS '关联词典ID';
COMMENT ON COLUMN dam_security.security_sensitive_rule.description IS '描述';
COMMENT ON COLUMN dam_security.security_sensitive_rule.priority IS '优先级';
COMMENT ON COLUMN dam_security.security_sensitive_rule.status IS '状态';
COMMENT ON COLUMN dam_security.security_sensitive_rule.created_at IS '创建时间';
COMMENT ON COLUMN dam_security.security_sensitive_rule.created_by IS '创建人';
COMMENT ON COLUMN dam_security.security_sensitive_rule.updated_at IS '更新时间';
COMMENT ON COLUMN dam_security.security_sensitive_rule.updated_by IS '更新人';
COMMENT ON COLUMN dam_security.security_sensitive_rule.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_security_sensitive_rule_dictionary_id ON dam_security.security_sensitive_rule(dictionary_id);
COMMENT ON COLUMN dam_security.security_sensitive_discovery.column_id IS '字段ID';
COMMENT ON COLUMN dam_security.security_sensitive_discovery.rule_id IS '规则ID';
COMMENT ON COLUMN dam_security.security_sensitive_discovery.sensitivity_level_id IS '敏感等级ID';
COMMENT ON COLUMN dam_security.security_sensitive_discovery.confidence IS '置信度（1~100）';
COMMENT ON COLUMN dam_security.security_sensitive_discovery.discovery_time IS '发现时间';
COMMENT ON COLUMN dam_security.security_sensitive_discovery.status IS '状态';
COMMENT ON COLUMN dam_security.security_sensitive_discovery.created_at IS '创建时间';
COMMENT ON COLUMN dam_security.security_sensitive_discovery.created_by IS '创建人';
COMMENT ON COLUMN dam_security.security_sensitive_discovery.updated_at IS '更新时间';
COMMENT ON COLUMN dam_security.security_sensitive_discovery.updated_by IS '更新人';
COMMENT ON COLUMN dam_security.security_sensitive_discovery.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_security.security_access_application.application_no IS '申请单号';
COMMENT ON COLUMN dam_security.security_access_application.applicant_id IS '申请人ID';
COMMENT ON COLUMN dam_security.security_access_application.asset_id IS '资产ID';
COMMENT ON COLUMN dam_security.security_access_application.access_type IS '访问类型';
COMMENT ON COLUMN dam_security.security_access_application.access_reason IS '申请理由';
COMMENT ON COLUMN dam_security.security_access_application.validity_days IS '有效期';
COMMENT ON COLUMN dam_security.security_access_application.approver_id IS '审批人ID';
COMMENT ON COLUMN dam_security.security_access_application.approve_comment IS '审批意见';
COMMENT ON COLUMN dam_security.security_access_application.approved_at IS '审批时间';
COMMENT ON COLUMN dam_security.security_access_application.effective_from IS '生效时间';
COMMENT ON COLUMN dam_security.security_access_application.effective_to IS '失效时间';
COMMENT ON COLUMN dam_security.security_access_application.status IS '状态';
COMMENT ON COLUMN dam_security.security_access_application.created_at IS '创建时间';
COMMENT ON COLUMN dam_security.security_access_application.created_by IS '创建人';
COMMENT ON COLUMN dam_security.security_access_application.updated_at IS '更新时间';
COMMENT ON COLUMN dam_security.security_access_application.updated_by IS '更新人';
COMMENT ON COLUMN dam_security.security_access_application.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_security_access_application_asset_id ON dam_security.security_access_application(asset_id);
COMMENT ON COLUMN dam_security.security_masking_policy.policy_code IS '策略编码';
COMMENT ON COLUMN dam_security.security_masking_policy.policy_name IS '策略名称';
COMMENT ON COLUMN dam_security.security_masking_policy.target_type IS '目标类型';
COMMENT ON COLUMN dam_security.security_masking_policy.target_id IS '目标ID';
COMMENT ON COLUMN dam_security.security_masking_policy.target_column IS '目标字段名';
COMMENT ON COLUMN dam_security.security_masking_policy.masking_type IS '脱敏类型';
COMMENT ON COLUMN dam_security.security_masking_policy.masking_config IS '脱敏配置';
COMMENT ON COLUMN dam_security.security_masking_policy.priority IS '优先级';
COMMENT ON COLUMN dam_security.security_masking_policy.apply_scenario IS '应用场景';
COMMENT ON COLUMN dam_security.security_masking_policy.description IS '策略描述';
COMMENT ON COLUMN dam_security.security_masking_policy.status IS '状态';
COMMENT ON COLUMN dam_security.security_masking_policy.created_at IS '创建时间';
COMMENT ON COLUMN dam_security.security_masking_policy.created_by IS '创建人';
COMMENT ON COLUMN dam_security.security_masking_policy.updated_at IS '更新时间';
COMMENT ON COLUMN dam_security.security_masking_policy.updated_by IS '更新人';
COMMENT ON COLUMN dam_security.security_masking_policy.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_security_masking_policy_target_type ON dam_security.security_masking_policy(target_type);
CREATE INDEX IF NOT EXISTS idx_security_masking_policy_target_id ON dam_security.security_masking_policy(target_id);
COMMENT ON COLUMN dam_security.security_data_permission.permission_code IS '权限编码';
COMMENT ON COLUMN dam_security.security_data_permission.permission_name IS '权限名称';
COMMENT ON COLUMN dam_security.security_data_permission.resource_type IS '资源类型';
COMMENT ON COLUMN dam_security.security_data_permission.resource_id IS '资源ID';
COMMENT ON COLUMN dam_security.security_data_permission.subject_type IS '主体类型';
COMMENT ON COLUMN dam_security.security_data_permission.subject_id IS '主体ID';
COMMENT ON COLUMN dam_security.security_data_permission.action_type IS '操作类型';
COMMENT ON COLUMN dam_security.security_data_permission.filter_condition IS '行级过滤条件';
COMMENT ON COLUMN dam_security.security_data_permission.column_mask IS '列级掩码';
COMMENT ON COLUMN dam_security.security_data_permission.priority IS '优先级';
COMMENT ON COLUMN dam_security.security_data_permission.effective_from IS '生效时间';
COMMENT ON COLUMN dam_security.security_data_permission.effective_to IS '失效时间';
COMMENT ON COLUMN dam_security.security_data_permission.description IS '描述';
COMMENT ON COLUMN dam_security.security_data_permission.status IS '状态';
COMMENT ON COLUMN dam_security.security_data_permission.created_at IS '创建时间';
COMMENT ON COLUMN dam_security.security_data_permission.created_by IS '创建人';
COMMENT ON COLUMN dam_security.security_data_permission.updated_at IS '更新时间';
COMMENT ON COLUMN dam_security.security_data_permission.updated_by IS '更新人';
COMMENT ON COLUMN dam_security.security_data_permission.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_security.security_data_audit_log.trace_id IS '链路追踪ID';
COMMENT ON COLUMN dam_security.security_data_audit_log.session_id IS '会话ID';
COMMENT ON COLUMN dam_security.security_data_audit_log.operator_id IS '操作人ID';
COMMENT ON COLUMN dam_security.security_data_audit_log.operator_ip IS '操作人IP地址';
COMMENT ON COLUMN dam_security.security_data_audit_log.asset_id IS '资产ID';
COMMENT ON COLUMN dam_security.security_data_audit_log.asset_name IS '资产名称';
COMMENT ON COLUMN dam_security.security_data_audit_log.table_id IS '表ID';
COMMENT ON COLUMN dam_security.security_data_audit_log.table_name IS '表名';
COMMENT ON COLUMN dam_security.security_data_audit_log.operation_type IS '操作类型';
COMMENT ON COLUMN dam_security.security_data_audit_log.sql_content IS '执行的SQL语句';
COMMENT ON COLUMN dam_security.security_data_audit_log.filter_condition IS '过滤/查询条件';
COMMENT ON COLUMN dam_security.security_data_audit_log.affected_rows IS '影响/返回行数';
COMMENT ON COLUMN dam_security.security_data_audit_log.data_size IS '返回数据量大小（字节）';
COMMENT ON COLUMN dam_security.security_data_audit_log.sensitivity_level IS '最高敏感等级';
COMMENT ON COLUMN dam_security.security_data_audit_log.masking_applied IS '是否应用了脱敏策略';
COMMENT ON COLUMN dam_security.security_data_audit_log.permission_code IS '使用的权限标识';
COMMENT ON COLUMN dam_security.security_data_audit_log.access_reason IS '访问原因';
COMMENT ON COLUMN dam_security.security_data_audit_log.is_approved IS '是否为授权访问';
COMMENT ON COLUMN dam_security.security_data_audit_log.risk_level IS '风险等级';
COMMENT ON COLUMN dam_security.security_data_audit_log.operation_time IS '操作时间';
COMMENT ON COLUMN dam_security.security_data_audit_log.created_at IS '创建时间';
COMMENT ON COLUMN dam_security.security_data_audit_log.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN dam_security.security_data_audit_log.created_by IS '创建人';
COMMENT ON COLUMN dam_security.security_data_audit_log.updated_at IS '更新时间';
COMMENT ON COLUMN dam_security.security_data_audit_log.updated_by IS '更新人';
COMMENT ON COLUMN dam_security.security_data_audit_log.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_security_data_audit_log_asset_id ON dam_security.security_data_audit_log(asset_id);
CREATE INDEX IF NOT EXISTS idx_security_data_audit_log_table_id ON dam_security.security_data_audit_log(table_id);
COMMENT ON COLUMN dam_standard.standard_category.parent_id IS '父分类ID';
COMMENT ON COLUMN dam_standard.standard_category.code IS '分类编码';
COMMENT ON COLUMN dam_standard.standard_category.name IS '分类名称';
COMMENT ON COLUMN dam_standard.standard_category.description IS '分类描述';
COMMENT ON COLUMN dam_standard.standard_category.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN dam_standard.standard_category.created_at IS '创建时间';
COMMENT ON COLUMN dam_standard.standard_category.created_by IS '创建人';
COMMENT ON COLUMN dam_standard.standard_category.updated_at IS '更新时间';
COMMENT ON COLUMN dam_standard.standard_category.updated_by IS '更新人';
COMMENT ON COLUMN dam_standard.standard_category.deleted_at IS '软删除时间（非空=已删除）';
COMMENT ON COLUMN dam_standard.data_standard.code IS '标准编码（唯一）';
COMMENT ON COLUMN dam_standard.data_standard.name IS '标准名称';
COMMENT ON COLUMN dam_standard.data_standard.category_id IS '标准分类ID（关联 standard_category）';
COMMENT ON COLUMN dam_standard.data_standard.std_type IS '标准类型：NAMING命名/CODE编码/TYPE类型/ENUM枚举/METRIC度量';
COMMENT ON COLUMN dam_standard.data_standard.rule_content IS '标准规则内容';
COMMENT ON COLUMN dam_standard.data_standard.example_value IS '示例值';
COMMENT ON COLUMN dam_standard.data_standard.version IS '标准版本';
COMMENT ON COLUMN dam_standard.data_standard.owner IS '标准负责人';
COMMENT ON COLUMN dam_standard.data_standard.effective_date IS '生效日期';
COMMENT ON COLUMN dam_standard.data_standard.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN dam_standard.data_standard.created_at IS '创建时间';
COMMENT ON COLUMN dam_standard.data_standard.created_by IS '创建人';
COMMENT ON COLUMN dam_standard.data_standard.updated_at IS '更新时间';
COMMENT ON COLUMN dam_standard.data_standard.updated_by IS '更新人';
COMMENT ON COLUMN dam_standard.data_standard.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_data_standard_category_id ON dam_standard.data_standard(category_id);
COMMENT ON COLUMN dam_standard.standard_code_table.code_table_code IS '码表代码';
COMMENT ON COLUMN dam_standard.standard_code_table.code_table_name IS '码表名称';
COMMENT ON COLUMN dam_standard.standard_code_table.code_table_type IS '码表类型';
COMMENT ON COLUMN dam_standard.standard_code_table.description IS '描述';
COMMENT ON COLUMN dam_standard.standard_code_table.status IS '状态';
COMMENT ON COLUMN dam_standard.standard_code_table.created_at IS '创建时间';
COMMENT ON COLUMN dam_standard.standard_code_table.created_by IS '创建人';
COMMENT ON COLUMN dam_standard.standard_code_table.updated_at IS '更新时间';
COMMENT ON COLUMN dam_standard.standard_code_table.updated_by IS '更新人';
COMMENT ON COLUMN dam_standard.standard_code_table.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_standard.standard_code_value.code_table_id IS '所属码表ID';
COMMENT ON COLUMN dam_standard.standard_code_value.code_value IS '码值';
COMMENT ON COLUMN dam_standard.standard_code_value.code_name IS '码值名称';
COMMENT ON COLUMN dam_standard.standard_code_value.parent_code_id IS '父码值ID';
COMMENT ON COLUMN dam_standard.standard_code_value.sort_order IS '排序序号';
COMMENT ON COLUMN dam_standard.standard_code_value.description IS '描述';
COMMENT ON COLUMN dam_standard.standard_code_value.status IS '状态';
COMMENT ON COLUMN dam_standard.standard_code_value.created_at IS '创建时间';
COMMENT ON COLUMN dam_standard.standard_code_value.created_by IS '创建人';
COMMENT ON COLUMN dam_standard.standard_code_value.updated_at IS '更新时间';
COMMENT ON COLUMN dam_standard.standard_code_value.updated_by IS '更新人';
COMMENT ON COLUMN dam_standard.standard_code_value.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_standard_code_value_code_table_id ON dam_standard.standard_code_value(code_table_id);
COMMENT ON COLUMN dam_standard.standard_mapping.source_system_id IS '源系统ID';
COMMENT ON COLUMN dam_standard.standard_mapping.source_table_id IS '源表ID';
COMMENT ON COLUMN dam_standard.standard_mapping.source_column IS '源字段';
COMMENT ON COLUMN dam_standard.standard_mapping.source_value IS '源码值';
COMMENT ON COLUMN dam_standard.standard_mapping.standard_code_table_id IS '标准码表ID';
COMMENT ON COLUMN dam_standard.standard_mapping.standard_code_value IS '标准码值';
COMMENT ON COLUMN dam_standard.standard_mapping.mapping_rule IS '映射规则';
COMMENT ON COLUMN dam_standard.standard_mapping.status IS '状态';
COMMENT ON COLUMN dam_standard.standard_mapping.created_at IS '创建时间';
COMMENT ON COLUMN dam_standard.standard_mapping.created_by IS '创建人';
COMMENT ON COLUMN dam_standard.standard_mapping.updated_at IS '更新时间';
COMMENT ON COLUMN dam_standard.standard_mapping.updated_by IS '更新人';
COMMENT ON COLUMN dam_standard.standard_mapping.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_standard.standard_deviation_report.report_no IS '报告编号';
COMMENT ON COLUMN dam_standard.standard_deviation_report.check_type IS '检查类型';
COMMENT ON COLUMN dam_standard.standard_deviation_report.table_id IS '关联表ID';
COMMENT ON COLUMN dam_standard.standard_deviation_report.column_name IS '偏差字段名';
COMMENT ON COLUMN dam_standard.standard_deviation_report.standard_code_table_id IS '关联标准码表ID';
COMMENT ON COLUMN dam_standard.standard_deviation_report.expected_value IS '期望值';
COMMENT ON COLUMN dam_standard.standard_deviation_report.actual_value IS '实际值';
COMMENT ON COLUMN dam_standard.standard_deviation_report.deviation_description IS '偏差描述';
COMMENT ON COLUMN dam_standard.standard_deviation_report.severity IS '严重程度';
COMMENT ON COLUMN dam_standard.standard_deviation_report.fix_suggestion IS '修复建议';
COMMENT ON COLUMN dam_standard.standard_deviation_report.fixed_by IS '修复人ID';
COMMENT ON COLUMN dam_standard.standard_deviation_report.fixed_at IS '修复时间';
COMMENT ON COLUMN dam_standard.standard_deviation_report.check_time IS '检查时间';
COMMENT ON COLUMN dam_standard.standard_deviation_report.status IS '状态';
COMMENT ON COLUMN dam_standard.standard_deviation_report.created_at IS '创建时间';
COMMENT ON COLUMN dam_standard.standard_deviation_report.created_by IS '创建人';
COMMENT ON COLUMN dam_standard.standard_deviation_report.updated_at IS '更新时间';
COMMENT ON COLUMN dam_standard.standard_deviation_report.updated_by IS '更新人';
COMMENT ON COLUMN dam_standard.standard_deviation_report.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_standard_deviation_report_report_no ON dam_standard.standard_deviation_report(report_no);
CREATE INDEX IF NOT EXISTS idx_standard_deviation_report_table_id ON dam_standard.standard_deviation_report(table_id);
CREATE INDEX IF NOT EXISTS idx_standard_deviation_report_standard_code_table_id ON dam_standard.standard_deviation_report(standard_code_table_id);
COMMENT ON COLUMN dam_ticket.ticket_order.ticket_no IS '工单编号';
COMMENT ON COLUMN dam_ticket.ticket_order.ticket_type IS '工单类型';
COMMENT ON COLUMN dam_ticket.ticket_order.title IS '工单标题';
COMMENT ON COLUMN dam_ticket.ticket_order.description IS '描述';
COMMENT ON COLUMN dam_ticket.ticket_order.priority IS '优先级';
COMMENT ON COLUMN dam_ticket.ticket_order.applicant_id IS '申请人ID';
COMMENT ON COLUMN dam_ticket.ticket_order.assignee_id IS '处理人ID';
COMMENT ON COLUMN dam_ticket.ticket_order.related_asset_id IS '关联资产ID';
COMMENT ON COLUMN dam_ticket.ticket_order.related_application_id IS '关联申请单ID';
COMMENT ON COLUMN dam_ticket.ticket_order.expected_complete_time IS '期望完成时间';
COMMENT ON COLUMN dam_ticket.ticket_order.actual_complete_time IS '实际完成时间';
COMMENT ON COLUMN dam_ticket.ticket_order.status IS '状态';
COMMENT ON COLUMN dam_ticket.ticket_order.created_at IS '创建时间';
COMMENT ON COLUMN dam_ticket.ticket_order.created_by IS '创建人';
COMMENT ON COLUMN dam_ticket.ticket_order.updated_at IS '更新时间';
COMMENT ON COLUMN dam_ticket.ticket_order.updated_by IS '更新人';
COMMENT ON COLUMN dam_ticket.ticket_order.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_ticket_order_related_asset_id ON dam_ticket.ticket_order(related_asset_id);
CREATE INDEX IF NOT EXISTS idx_ticket_order_related_application_id ON dam_ticket.ticket_order(related_application_id);
COMMENT ON COLUMN dam_ticket.ticket_flow_log.ticket_id IS '工单ID';
COMMENT ON COLUMN dam_ticket.ticket_flow_log.from_status IS '变更前状态';
COMMENT ON COLUMN dam_ticket.ticket_flow_log.to_status IS '变更后状态';
COMMENT ON COLUMN dam_ticket.ticket_flow_log.operator_id IS '操作人ID';
COMMENT ON COLUMN dam_ticket.ticket_flow_log.operation_type IS '操作类型';
COMMENT ON COLUMN dam_ticket.ticket_flow_log.comment IS '备注';
COMMENT ON COLUMN dam_ticket.ticket_flow_log.attachments IS '附件';
COMMENT ON COLUMN dam_ticket.ticket_flow_log.status IS '状态';
COMMENT ON COLUMN dam_ticket.ticket_flow_log.created_at IS '创建时间';
COMMENT ON COLUMN dam_ticket.ticket_flow_log.created_by IS '创建人';
COMMENT ON COLUMN dam_ticket.ticket_flow_log.updated_at IS '更新时间';
COMMENT ON COLUMN dam_ticket.ticket_flow_log.updated_by IS '更新人';
COMMENT ON COLUMN dam_ticket.ticket_flow_log.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_ticket.ticket_comment.ticket_id IS '工单ID';
COMMENT ON COLUMN dam_ticket.ticket_comment.parent_comment_id IS '父评论ID';
COMMENT ON COLUMN dam_ticket.ticket_comment.content IS '评论内容';
COMMENT ON COLUMN dam_ticket.ticket_comment.attachments IS '附件列表';
COMMENT ON COLUMN dam_ticket.ticket_comment.mentioned_users IS '@提及的用户ID列表';
COMMENT ON COLUMN dam_ticket.ticket_comment.is_internal IS '是否内部评论';
COMMENT ON COLUMN dam_ticket.ticket_comment.commenter_id IS '评论人ID';
COMMENT ON COLUMN dam_ticket.ticket_comment.status IS '状态';
COMMENT ON COLUMN dam_ticket.ticket_comment.created_at IS '创建时间';
COMMENT ON COLUMN dam_ticket.ticket_comment.created_by IS '创建人';
COMMENT ON COLUMN dam_ticket.ticket_comment.updated_at IS '更新时间';
COMMENT ON COLUMN dam_ticket.ticket_comment.updated_by IS '更新人';
COMMENT ON COLUMN dam_ticket.ticket_comment.deleted_at IS '删除时间';
COMMENT ON COLUMN dam_asset.asset_statistics.asset_id IS '资产ID';
COMMENT ON COLUMN dam_asset.asset_statistics.stat_date IS '统计时间';
COMMENT ON COLUMN dam_asset.asset_statistics.view_count IS '浏览次数';
COMMENT ON COLUMN dam_asset.asset_statistics.query_count IS '查询次数';
COMMENT ON COLUMN dam_asset.asset_statistics.download_count IS '下载次数';
COMMENT ON COLUMN dam_asset.asset_statistics.export_count IS '导出次数';
COMMENT ON COLUMN dam_asset.asset_statistics.unique_users IS '独立用户数';
COMMENT ON COLUMN dam_asset.asset_statistics.status IS '状态';
COMMENT ON COLUMN dam_asset.asset_statistics.created_at IS '创建时间';
COMMENT ON COLUMN dam_asset.asset_statistics.created_by IS '创建人';
COMMENT ON COLUMN dam_asset.asset_statistics.updated_at IS '更新时间';
COMMENT ON COLUMN dam_asset.asset_statistics.updated_by IS '更新人';
COMMENT ON COLUMN dam_asset.asset_statistics.deleted_at IS '删除时间';
CREATE INDEX IF NOT EXISTS idx_asset_statistics_asset_id ON dam_asset.asset_statistics(asset_id);
COMMENT ON COLUMN dam_service.api_service.api_code IS 'API编码（唯一，URL 路径参数）';
COMMENT ON COLUMN dam_service.api_service.name IS 'API名称';
COMMENT ON COLUMN dam_service.api_service.asset_id IS '关联资产ID（asset_info.id）';
COMMENT ON COLUMN dam_service.api_service.sql_text IS '查询 SQL（网关仅允许单条 SELECT，参数化执行）';
COMMENT ON COLUMN dam_service.api_service.params_json IS '参数白名单定义（JSON 数组：name/type/required/desc/example）';
COMMENT ON COLUMN dam_service.api_service.approval_status IS '发布审批状态：PENDING/APPROVED/REJECTED（完善项）';
COMMENT ON COLUMN dam_service.api_service.approved_by IS '审批人（完善项）';
COMMENT ON COLUMN dam_service.api_service.approved_at IS '审批时间（完善项）';
COMMENT ON COLUMN dam_service.api_service.rate_limit IS '每分钟调用上限（完善项：超限返回 429）';
COMMENT ON COLUMN dam_service.api_service.quota_day IS '单日调用配额（完善项）';
COMMENT ON COLUMN dam_service.api_service.owner IS 'API 负责人';
COMMENT ON COLUMN dam_service.api_service.description IS '接口说明';
COMMENT ON COLUMN dam_service.api_service.call_count IS '累计调用次数';
COMMENT ON COLUMN dam_service.api_service.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN dam_service.api_service.created_at IS '创建时间';
COMMENT ON COLUMN dam_service.api_service.created_by IS '创建人';
COMMENT ON COLUMN dam_service.api_service.updated_at IS '更新时间';
COMMENT ON COLUMN dam_service.api_service.updated_by IS '更新人';
COMMENT ON COLUMN dam_service.api_service.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_api_service_asset_id ON dam_service.api_service(asset_id);
COMMENT ON COLUMN dam_service.api_client.app_id IS '应用标识（唯一，网关请求头 X-App-Id）';
COMMENT ON COLUMN dam_service.api_client.app_key IS '应用密钥（网关请求头 X-App-Key，可轮换）';
COMMENT ON COLUMN dam_service.api_client.app_name IS '应用名称';
COMMENT ON COLUMN dam_service.api_client.contact IS '联系人';
COMMENT ON COLUMN dam_service.api_client.quota_day IS '应用级日配额（完善项）';
COMMENT ON COLUMN dam_service.api_client.last_call_at IS '最后调用时间';
COMMENT ON COLUMN dam_service.api_client.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN dam_service.api_client.created_at IS '创建时间';
COMMENT ON COLUMN dam_service.api_client.created_by IS '创建人';
COMMENT ON COLUMN dam_service.api_client.updated_at IS '更新时间';
COMMENT ON COLUMN dam_service.api_client.updated_by IS '更新人';
COMMENT ON COLUMN dam_service.api_client.deleted_at IS '软删除时间（非空=已删除）';
COMMENT ON COLUMN dam_service.api_call_log.api_id IS 'API ID';
COMMENT ON COLUMN dam_service.api_call_log.api_code IS 'API 编码';
COMMENT ON COLUMN dam_service.api_call_log.app_id IS '调用方应用标识';
COMMENT ON COLUMN dam_service.api_call_log.params IS '入参快照';
COMMENT ON COLUMN dam_service.api_call_log.duration_ms IS '耗时（毫秒）';
COMMENT ON COLUMN dam_service.api_call_log.row_count IS '返回行数';
COMMENT ON COLUMN dam_service.api_call_log.success IS '是否成功';
COMMENT ON COLUMN dam_service.api_call_log.masked_columns IS '本次被脱敏的字段清单';
COMMENT ON COLUMN dam_service.api_call_log.error_msg IS '错误信息';
COMMENT ON COLUMN dam_service.api_call_log.client_ip IS '调用方 IP';
COMMENT ON COLUMN dam_service.api_call_log.called_at IS '调用时间';
COMMENT ON COLUMN dam_service.api_call_log.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN dam_service.api_call_log.created_at IS '创建时间';
COMMENT ON COLUMN dam_service.api_call_log.created_by IS '创建人';
COMMENT ON COLUMN dam_service.api_call_log.updated_at IS '更新时间';
COMMENT ON COLUMN dam_service.api_call_log.updated_by IS '更新人';
CREATE INDEX IF NOT EXISTS idx_api_call_log_called_at ON dam_service.api_call_log(called_at);
COMMENT ON COLUMN dam_sched.sched_job.job_code IS '任务编码（唯一）';
COMMENT ON COLUMN dam_sched.sched_job.name IS '任务名称';
COMMENT ON COLUMN dam_sched.sched_job.job_type IS '任务类型：QUALITY_CHECK/METADATA_SYNC/LOG_CLEAN/CUSTOM';
COMMENT ON COLUMN dam_sched.sched_job.schedule_type IS '调度类型：CRON/FIXED_RATE/API（新增）';
COMMENT ON COLUMN dam_sched.sched_job.cron_expr IS 'CRON 表达式（schedule_type=CRON 时必填）';
COMMENT ON COLUMN dam_sched.sched_job.fixed_rate_ms IS '固定频率毫秒数（schedule_type=FIXED_RATE 时使用，新增）';
COMMENT ON COLUMN dam_sched.sched_job.powerjob_job_id IS 'PowerJob 侧任务ID（触发内核对接，新增）';
COMMENT ON COLUMN dam_sched.sched_job.enabled IS '是否启用';
COMMENT ON COLUMN dam_sched.sched_job.last_run_at IS '最近执行时间';
COMMENT ON COLUMN dam_sched.sched_job.last_status IS '最近执行状态';
COMMENT ON COLUMN dam_sched.sched_job.last_message IS '最近执行消息';
COMMENT ON COLUMN dam_sched.sched_job.run_count IS '累计执行次数';
COMMENT ON COLUMN dam_sched.sched_job.description IS '任务说明';
COMMENT ON COLUMN dam_sched.sched_job.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN dam_sched.sched_job.created_at IS '创建时间';
COMMENT ON COLUMN dam_sched.sched_job.created_by IS '创建人';
COMMENT ON COLUMN dam_sched.sched_job.updated_at IS '更新时间';
COMMENT ON COLUMN dam_sched.sched_job.updated_by IS '更新人';
COMMENT ON COLUMN dam_sched.sched_job.deleted_at IS '软删除时间（非空=已删除）';
COMMENT ON COLUMN dam_sched.sched_job_log.job_id IS '任务ID（关联 sched_job.id）';
COMMENT ON COLUMN dam_sched.sched_job_log.started_at IS '开始时间';
COMMENT ON COLUMN dam_sched.sched_job_log.finished_at IS '结束时间';
COMMENT ON COLUMN dam_sched.sched_job_log.duration_ms IS '耗时（毫秒）';
COMMENT ON COLUMN dam_sched.sched_job_log.exec_status IS '执行状态：SUCCESS/FAILED/RUNNING（更名避免与审计 status 撞名）';
COMMENT ON COLUMN dam_sched.sched_job_log.message IS '执行消息/错误';
COMMENT ON COLUMN dam_sched.sched_job_log.powerjob_instance_id IS 'PowerJob 任务实例ID（新增，双端对账）';
COMMENT ON COLUMN dam_sched.sched_job_log.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN dam_sched.sched_job_log.created_at IS '创建时间';
COMMENT ON COLUMN dam_sched.sched_job_log.created_by IS '创建人';
COMMENT ON COLUMN dam_sched.sched_job_log.updated_at IS '更新时间';
COMMENT ON COLUMN dam_sched.sched_job_log.updated_by IS '更新人';
COMMENT ON COLUMN dam_sched.sched_job_log.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_sched_job_log_job_id ON dam_sched.sched_job_log(job_id);
CREATE INDEX IF NOT EXISTS idx_sched_job_log_started_at ON dam_sched.sched_job_log(started_at);
COMMENT ON COLUMN hospital_demo.biz_patient_master.patient_id IS '患者主索引 EMPI（唯一）';
COMMENT ON COLUMN hospital_demo.biz_patient_master.register_no IS '登记号';
COMMENT ON COLUMN hospital_demo.biz_patient_master.patient_name IS '姓名';
COMMENT ON COLUMN hospital_demo.biz_patient_master.gender_code IS '性别（码表 CT_Sex）';
COMMENT ON COLUMN hospital_demo.biz_patient_master.birth_date IS '出生日期';
COMMENT ON COLUMN hospital_demo.biz_patient_master.id_card_type IS '证件类型（码表）';
COMMENT ON COLUMN hospital_demo.biz_patient_master.id_card IS '证件号（脱敏列）';
COMMENT ON COLUMN hospital_demo.biz_patient_master.marital_status IS '婚姻状况（码表 CT_Marital）';
COMMENT ON COLUMN hospital_demo.biz_patient_master.nationality IS '国籍';
COMMENT ON COLUMN hospital_demo.biz_patient_master.nation IS '民族（码表 CT_Nation）';
COMMENT ON COLUMN hospital_demo.biz_patient_master.occupation IS '职业';
COMMENT ON COLUMN hospital_demo.biz_patient_master.merge_flag IS 'EMPI 状态：0-正常 1-已合并 2-已拆分';
COMMENT ON COLUMN hospital_demo.biz_patient_master.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_patient_master.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_patient_master.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_patient_master.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_patient_master.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_patient_master.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_patient_master_patient_id ON hospital_demo.biz_patient_master(patient_id);
COMMENT ON COLUMN hospital_demo.biz_patient_allergy.patient_id IS '患者 EMPI';
COMMENT ON COLUMN hospital_demo.biz_patient_allergy.allergy_type IS '过敏类型：药物/食物/环境';
COMMENT ON COLUMN hospital_demo.biz_patient_allergy.allergen IS '过敏原';
COMMENT ON COLUMN hospital_demo.biz_patient_allergy.reaction IS '过敏反应表现';
COMMENT ON COLUMN hospital_demo.biz_patient_allergy.severity IS '严重程度：轻/中/重';
COMMENT ON COLUMN hospital_demo.biz_patient_allergy.onset_date IS '发现日期';
COMMENT ON COLUMN hospital_demo.biz_patient_allergy.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_patient_allergy.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_patient_allergy.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_patient_allergy.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_patient_allergy.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_patient_allergy.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_patient_allergy_patient_id ON hospital_demo.biz_patient_allergy(patient_id);
COMMENT ON COLUMN hospital_demo.biz_encounter.encounter_no IS '就诊号（唯一）';
COMMENT ON COLUMN hospital_demo.biz_encounter.patient_id IS '患者 EMPI';
COMMENT ON COLUMN hospital_demo.biz_encounter.encounter_type IS '就诊类型：门诊/急诊/住院';
COMMENT ON COLUMN hospital_demo.biz_encounter.dept_code IS '科室编码（码表 CT_Loc）';
COMMENT ON COLUMN hospital_demo.biz_encounter.dept_name IS '科室名称';
COMMENT ON COLUMN hospital_demo.biz_encounter.doctor_code IS '医生编码（CT_CareProv）';
COMMENT ON COLUMN hospital_demo.biz_encounter.doctor_name IS '医生姓名';
COMMENT ON COLUMN hospital_demo.biz_encounter.admit_time IS '就诊/入院时间';
COMMENT ON COLUMN hospital_demo.biz_encounter.discharge_time IS '出院时间（住院）';
COMMENT ON COLUMN hospital_demo.biz_encounter.encounter_status IS '状态：OPEN/CLOSED';
COMMENT ON COLUMN hospital_demo.biz_encounter.total_cost IS '总费用';
COMMENT ON COLUMN hospital_demo.biz_encounter.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_encounter.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_encounter.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_encounter.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_encounter.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_encounter.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_encounter_encounter_no ON hospital_demo.biz_encounter(encounter_no);
CREATE INDEX IF NOT EXISTS idx_biz_encounter_patient_id ON hospital_demo.biz_encounter(patient_id);
COMMENT ON COLUMN hospital_demo.biz_encounter_transfer.encounter_no IS '就诊号';
COMMENT ON COLUMN hospital_demo.biz_encounter_transfer.from_dept IS '转出科室';
COMMENT ON COLUMN hospital_demo.biz_encounter_transfer.to_dept IS '转入科室';
COMMENT ON COLUMN hospital_demo.biz_encounter_transfer.from_bed IS '原床位';
COMMENT ON COLUMN hospital_demo.biz_encounter_transfer.to_bed IS '新床位';
COMMENT ON COLUMN hospital_demo.biz_encounter_transfer.transfer_time IS '转科/换床时间';
COMMENT ON COLUMN hospital_demo.biz_encounter_transfer.reason IS '转科原因';
COMMENT ON COLUMN hospital_demo.biz_encounter_transfer.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_encounter_transfer.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_encounter_transfer.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_encounter_transfer.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_encounter_transfer.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_encounter_transfer.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_encounter_transfer_encounter_no ON hospital_demo.biz_encounter_transfer(encounter_no);
COMMENT ON COLUMN hospital_demo.biz_diagnosis.encounter_no IS '就诊号';
COMMENT ON COLUMN hospital_demo.biz_diagnosis.patient_id IS '患者 EMPI';
COMMENT ON COLUMN hospital_demo.biz_diagnosis.diagnosis_icd IS '诊断 ICD 编码（ICD-10 / 中医病证）';
COMMENT ON COLUMN hospital_demo.biz_diagnosis.diagnosis_name IS '诊断名称';
COMMENT ON COLUMN hospital_demo.biz_diagnosis.diagnosis_class IS '分类：西医/中医';
COMMENT ON COLUMN hospital_demo.biz_diagnosis.diagnosis_type IS '类型：入院/术前/出院诊断';
COMMENT ON COLUMN hospital_demo.biz_diagnosis.is_primary IS '是否主要诊断';
COMMENT ON COLUMN hospital_demo.biz_diagnosis.doctor_code IS '诊断医生';
COMMENT ON COLUMN hospital_demo.biz_diagnosis.diagnosis_time IS '诊断时间';
COMMENT ON COLUMN hospital_demo.biz_diagnosis.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_diagnosis.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_diagnosis.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_diagnosis.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_diagnosis.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_diagnosis.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_diagnosis_encounter_no ON hospital_demo.biz_diagnosis(encounter_no);
CREATE INDEX IF NOT EXISTS idx_biz_diagnosis_patient_id ON hospital_demo.biz_diagnosis(patient_id);
COMMENT ON COLUMN hospital_demo.biz_clinical_order.order_no IS '医嘱号（唯一）';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.encounter_no IS '就诊号';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.patient_id IS '患者 EMPI';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.order_type IS '医嘱类型：长期/临时';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.order_item_code IS '医嘱项目编码';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.order_item_name IS '医嘱项目名称';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.spec IS '规格';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.dosage IS '单次用量';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.frequency IS '执行频次';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.route IS '给药途径';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.order_doctor IS '开立医生';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.order_time IS '开立时间';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.order_status IS '状态：ACTIVE/STOPPED/DONE';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_clinical_order.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_clinical_order_order_no ON hospital_demo.biz_clinical_order(order_no);
CREATE INDEX IF NOT EXISTS idx_biz_clinical_order_encounter_no ON hospital_demo.biz_clinical_order(encounter_no);
CREATE INDEX IF NOT EXISTS idx_biz_clinical_order_patient_id ON hospital_demo.biz_clinical_order(patient_id);
COMMENT ON COLUMN hospital_demo.biz_order_exec.order_no IS '医嘱号';
COMMENT ON COLUMN hospital_demo.biz_order_exec.exec_time IS '执行时间';
COMMENT ON COLUMN hospital_demo.biz_order_exec.exec_nurse IS '执行护士';
COMMENT ON COLUMN hospital_demo.biz_order_exec.exec_dept IS '执行科室';
COMMENT ON COLUMN hospital_demo.biz_order_exec.exec_status IS '执行状态';
COMMENT ON COLUMN hospital_demo.biz_order_exec.exec_note IS '执行备注';
COMMENT ON COLUMN hospital_demo.biz_order_exec.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_order_exec.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_order_exec.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_order_exec.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_order_exec.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_order_exec.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_order_exec_order_no ON hospital_demo.biz_order_exec(order_no);
COMMENT ON COLUMN hospital_demo.biz_prescription.prescription_no IS '处方号（唯一）';
COMMENT ON COLUMN hospital_demo.biz_prescription.encounter_no IS '就诊号';
COMMENT ON COLUMN hospital_demo.biz_prescription.patient_id IS '患者 EMPI';
COMMENT ON COLUMN hospital_demo.biz_prescription.prescription_type IS '处方类型：中药/西药';
COMMENT ON COLUMN hospital_demo.biz_prescription.doctor_code IS '处方医生';
COMMENT ON COLUMN hospital_demo.biz_prescription.dept_code IS '开方科室';
COMMENT ON COLUMN hospital_demo.biz_prescription.total_amount IS '处方总金额';
COMMENT ON COLUMN hospital_demo.biz_prescription.prescribe_time IS '开方时间';
COMMENT ON COLUMN hospital_demo.biz_prescription.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_prescription.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_prescription.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_prescription.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_prescription.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_prescription.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_prescription_prescription_no ON hospital_demo.biz_prescription(prescription_no);
CREATE INDEX IF NOT EXISTS idx_biz_prescription_encounter_no ON hospital_demo.biz_prescription(encounter_no);
CREATE INDEX IF NOT EXISTS idx_biz_prescription_patient_id ON hospital_demo.biz_prescription(patient_id);
COMMENT ON COLUMN hospital_demo.biz_prescription_item.prescription_no IS '处方号';
COMMENT ON COLUMN hospital_demo.biz_prescription_item.item_seq IS '明细序号';
COMMENT ON COLUMN hospital_demo.biz_prescription_item.drug_code IS '药品编码（DIM_Pharmacy 字典）';
COMMENT ON COLUMN hospital_demo.biz_prescription_item.drug_name IS '药品名称';
COMMENT ON COLUMN hospital_demo.biz_prescription_item.spec IS '规格';
COMMENT ON COLUMN hospital_demo.biz_prescription_item.dosage IS '单次用量';
COMMENT ON COLUMN hospital_demo.biz_prescription_item.quantity IS '数量';
COMMENT ON COLUMN hospital_demo.biz_prescription_item.unit IS '单位';
COMMENT ON COLUMN hospital_demo.biz_prescription_item.usage_note IS '用法说明';
COMMENT ON COLUMN hospital_demo.biz_prescription_item.days IS '用药天数';
COMMENT ON COLUMN hospital_demo.biz_prescription_item.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_prescription_item.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_prescription_item.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_prescription_item.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_prescription_item.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_prescription_item.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_prescription_item_prescription_no ON hospital_demo.biz_prescription_item(prescription_no);
COMMENT ON COLUMN hospital_demo.biz_lab_report.report_no IS '检验报告号（唯一）';
COMMENT ON COLUMN hospital_demo.biz_lab_report.encounter_no IS '就诊号';
COMMENT ON COLUMN hospital_demo.biz_lab_report.patient_id IS '患者 EMPI';
COMMENT ON COLUMN hospital_demo.biz_lab_report.lab_item_code IS '检验申请项目编码';
COMMENT ON COLUMN hospital_demo.biz_lab_report.lab_item_name IS '检验项目名称';
COMMENT ON COLUMN hospital_demo.biz_lab_report.specimen IS '标本类型：血/尿/便等';
COMMENT ON COLUMN hospital_demo.biz_lab_report.apply_doctor IS '申请医生';
COMMENT ON COLUMN hospital_demo.biz_lab_report.report_doctor IS '报告医生';
COMMENT ON COLUMN hospital_demo.biz_lab_report.apply_time IS '申请时间';
COMMENT ON COLUMN hospital_demo.biz_lab_report.report_time IS '报告时间';
COMMENT ON COLUMN hospital_demo.biz_lab_report.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_lab_report.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_lab_report.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_lab_report.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_lab_report.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_lab_report.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_lab_report_report_no ON hospital_demo.biz_lab_report(report_no);
CREATE INDEX IF NOT EXISTS idx_biz_lab_report_encounter_no ON hospital_demo.biz_lab_report(encounter_no);
CREATE INDEX IF NOT EXISTS idx_biz_lab_report_patient_id ON hospital_demo.biz_lab_report(patient_id);
COMMENT ON COLUMN hospital_demo.biz_lab_result.report_no IS '检验报告号';
COMMENT ON COLUMN hospital_demo.biz_lab_result.item_code IS '子项编码';
COMMENT ON COLUMN hospital_demo.biz_lab_result.item_name IS '子项名称';
COMMENT ON COLUMN hospital_demo.biz_lab_result.result_value IS '定性结果';
COMMENT ON COLUMN hospital_demo.biz_lab_result.result_value_num IS '定量结果';
COMMENT ON COLUMN hospital_demo.biz_lab_result.unit IS '单位';
COMMENT ON COLUMN hospital_demo.biz_lab_result.ref_range IS '参考范围';
COMMENT ON COLUMN hospital_demo.biz_lab_result.abnormal_flag IS '异常标志：H/L/正常';
COMMENT ON COLUMN hospital_demo.biz_lab_result.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_lab_result.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_lab_result.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_lab_result.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_lab_result.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_lab_result.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_lab_result_report_no ON hospital_demo.biz_lab_result(report_no);
COMMENT ON COLUMN hospital_demo.biz_imaging_exam.exam_no IS '检查号（唯一）';
COMMENT ON COLUMN hospital_demo.biz_imaging_exam.encounter_no IS '就诊号';
COMMENT ON COLUMN hospital_demo.biz_imaging_exam.patient_id IS '患者 EMPI';
COMMENT ON COLUMN hospital_demo.biz_imaging_exam.exam_type IS '检查类型：CT/MRI/X线/超声/内镜';
COMMENT ON COLUMN hospital_demo.biz_imaging_exam.body_part IS '检查部位';
COMMENT ON COLUMN hospital_demo.biz_imaging_exam.finding IS '影像所见';
COMMENT ON COLUMN hospital_demo.biz_imaging_exam.conclusion IS '影像结论';
COMMENT ON COLUMN hospital_demo.biz_imaging_exam.apply_doctor IS '申请医生';
COMMENT ON COLUMN hospital_demo.biz_imaging_exam.report_doctor IS '报告医生';
COMMENT ON COLUMN hospital_demo.biz_imaging_exam.report_time IS '报告时间';
COMMENT ON COLUMN hospital_demo.biz_imaging_exam.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_imaging_exam.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_imaging_exam.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_imaging_exam.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_imaging_exam.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_imaging_exam.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_imaging_exam_encounter_no ON hospital_demo.biz_imaging_exam(encounter_no);
CREATE INDEX IF NOT EXISTS idx_biz_imaging_exam_patient_id ON hospital_demo.biz_imaging_exam(patient_id);
COMMENT ON COLUMN hospital_demo.biz_aux_exam.exam_no IS '检查号（唯一）';
COMMENT ON COLUMN hospital_demo.biz_aux_exam.encounter_no IS '就诊号';
COMMENT ON COLUMN hospital_demo.biz_aux_exam.patient_id IS '患者 EMPI';
COMMENT ON COLUMN hospital_demo.biz_aux_exam.exam_type IS '类型：心电/脑电/肺功能/动态血压';
COMMENT ON COLUMN hospital_demo.biz_aux_exam.exam_date IS '检查日期';
COMMENT ON COLUMN hospital_demo.biz_aux_exam.finding IS '检查所见';
COMMENT ON COLUMN hospital_demo.biz_aux_exam.conclusion IS '检查结论';
COMMENT ON COLUMN hospital_demo.biz_aux_exam.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_aux_exam.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_aux_exam.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_aux_exam.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_aux_exam.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_aux_exam.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_aux_exam_encounter_no ON hospital_demo.biz_aux_exam(encounter_no);
CREATE INDEX IF NOT EXISTS idx_biz_aux_exam_patient_id ON hospital_demo.biz_aux_exam(patient_id);
COMMENT ON COLUMN hospital_demo.biz_vital_signs.encounter_no IS '就诊号';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.patient_id IS '患者 EMPI';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.measure_time IS '测量时间';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.temperature IS '体温（℃）';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.pulse IS '脉搏（次/分）';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.respiration IS '呼吸（次/分）';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.sbp IS '收缩压（mmHg）';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.dbp IS '舒张压（mmHg）';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.spo2 IS '血氧饱和度（%）';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.pain_score IS '疼痛评分';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.intake_ml IS '入量（ml）';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.output_ml IS '出量（ml）';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_vital_signs.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_vital_signs_encounter_no ON hospital_demo.biz_vital_signs(encounter_no);
CREATE INDEX IF NOT EXISTS idx_biz_vital_signs_patient_id ON hospital_demo.biz_vital_signs(patient_id);
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.surgery_no IS '手术号（唯一）';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.encounter_no IS '就诊号';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.patient_id IS '患者 EMPI';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.surgery_icd IS '手术编码（ICD-9-CM-3）';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.surgery_name IS '手术名称';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.incision_level IS '切口愈合等级';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.anesthesia_type IS '麻醉方式';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.surgeon_code IS '主刀医生编码';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.surgeon_name IS '主刀医生姓名';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.surgery_start IS '手术开始时间';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.surgery_end IS '手术结束时间';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.surgery_status IS '状态：PLANNED/DONE/CANCELLED';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_surgery_anesthesia.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_surgery_anesthesia_encounter_no ON hospital_demo.biz_surgery_anesthesia(encounter_no);
CREATE INDEX IF NOT EXISTS idx_biz_surgery_anesthesia_patient_id ON hospital_demo.biz_surgery_anesthesia(patient_id);
COMMENT ON COLUMN hospital_demo.biz_transfusion.transfusion_no IS '输血单号（唯一）';
COMMENT ON COLUMN hospital_demo.biz_transfusion.encounter_no IS '就诊号';
COMMENT ON COLUMN hospital_demo.biz_transfusion.patient_id IS '患者 EMPI';
COMMENT ON COLUMN hospital_demo.biz_transfusion.blood_type IS '血型（ABO/Rh）';
COMMENT ON COLUMN hospital_demo.biz_transfusion.blood_product IS '血液成分：红细胞/血浆/血小板等';
COMMENT ON COLUMN hospital_demo.biz_transfusion.cross_match_time IS '交叉配血时间';
COMMENT ON COLUMN hospital_demo.biz_transfusion.transfuse_time IS '输血执行时间';
COMMENT ON COLUMN hospital_demo.biz_transfusion.volume_ml IS '输注量（ml）';
COMMENT ON COLUMN hospital_demo.biz_transfusion.reaction IS '输血不良反应记录';
COMMENT ON COLUMN hospital_demo.biz_transfusion.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_transfusion.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_transfusion.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_transfusion.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_transfusion.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_transfusion.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_transfusion_encounter_no ON hospital_demo.biz_transfusion(encounter_no);
CREATE INDEX IF NOT EXISTS idx_biz_transfusion_patient_id ON hospital_demo.biz_transfusion(patient_id);
COMMENT ON COLUMN hospital_demo.biz_emr_document.encounter_no IS '就诊号';
COMMENT ON COLUMN hospital_demo.biz_emr_document.patient_id IS '患者 EMPI';
COMMENT ON COLUMN hospital_demo.biz_emr_document.doc_type IS '文书类型：入院记录/病程记录/出院小结等';
COMMENT ON COLUMN hospital_demo.biz_emr_document.doc_title IS '文书标题';
COMMENT ON COLUMN hospital_demo.biz_emr_document.doc_content IS '文书内容（结构化归档）';
COMMENT ON COLUMN hospital_demo.biz_emr_document.author_code IS '书写医生编码';
COMMENT ON COLUMN hospital_demo.biz_emr_document.author_name IS '书写医生姓名';
COMMENT ON COLUMN hospital_demo.biz_emr_document.archive_time IS '归档时间';
COMMENT ON COLUMN hospital_demo.biz_emr_document.status IS '状态：1-正常 0-停用';
COMMENT ON COLUMN hospital_demo.biz_emr_document.created_at IS '创建时间';
COMMENT ON COLUMN hospital_demo.biz_emr_document.created_by IS '创建人';
COMMENT ON COLUMN hospital_demo.biz_emr_document.updated_at IS '更新时间';
COMMENT ON COLUMN hospital_demo.biz_emr_document.updated_by IS '更新人';
COMMENT ON COLUMN hospital_demo.biz_emr_document.deleted_at IS '软删除时间（非空=已删除）';
CREATE INDEX IF NOT EXISTS idx_biz_emr_document_encounter_no ON hospital_demo.biz_emr_document(encounter_no);
CREATE INDEX IF NOT EXISTS idx_biz_emr_document_patient_id ON hospital_demo.biz_emr_document(patient_id);
