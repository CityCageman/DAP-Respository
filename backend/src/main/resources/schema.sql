-- ============================================================
-- 数据资产管理平台 表结构
-- 六大模块：元数据 / 资产目录 / 数据血缘 / 数据标准 / 数据质量 / 安全分级
-- 全部使用 IF NOT EXISTS，重复启动安全
-- ============================================================

-- ---------------------- 1. 元数据 ----------------------
CREATE TABLE IF NOT EXISTS data_source (
    id            BIGSERIAL PRIMARY KEY,
    name          VARCHAR(128) NOT NULL,
    type          VARCHAR(32)  NOT NULL,
    host          VARCHAR(128),
    port          INT,
    db_name       VARCHAR(128),
    schema_name   VARCHAR(64),
    username      VARCHAR(64),
    password      VARCHAR(255),
    status        VARCHAR(32) DEFAULT 'CONNECTED',
    last_sync_at  TIMESTAMP,
    table_count   INT DEFAULT 0,
    description   TEXT,
    created_at    TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS meta_table (
    id            BIGSERIAL PRIMARY KEY,
    source_id     BIGINT NOT NULL,
    schema_name   VARCHAR(64),
    table_name    VARCHAR(128) NOT NULL,
    table_comment VARCHAR(512),
    row_count     BIGINT DEFAULT 0,
    column_count  INT DEFAULT 0,
    owner         VARCHAR(64),
    collected_at  TIMESTAMP,
    CONSTRAINT uk_meta_table UNIQUE (source_id, schema_name, table_name)
);

CREATE TABLE IF NOT EXISTS meta_column (
    id             BIGSERIAL PRIMARY KEY,
    table_id       BIGINT NOT NULL,
    ordinal        INT,
    column_name    VARCHAR(128) NOT NULL,
    data_type      VARCHAR(64),
    length         INT,
    nullable       BOOLEAN DEFAULT TRUE,
    primary_key    BOOLEAN DEFAULT FALSE,
    column_comment VARCHAR(512)
);
CREATE INDEX IF NOT EXISTS idx_meta_column_table ON meta_column(table_id);

-- ---------------------- 2. 资产目录 ----------------------
CREATE TABLE IF NOT EXISTS asset_domain (
    id          BIGSERIAL PRIMARY KEY,
    parent_id   BIGINT,
    code        VARCHAR(64) NOT NULL,
    name        VARCHAR(128) NOT NULL,
    description TEXT,
    sort_no     INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS asset (
    id              BIGSERIAL PRIMARY KEY,
    asset_code      VARCHAR(64)  NOT NULL UNIQUE,
    name            VARCHAR(200) NOT NULL,
    domain_id       BIGINT,
    asset_type      VARCHAR(32)  NOT NULL,
    description     TEXT,
    owner           VARCHAR(64),
    department      VARCHAR(64),
    security_level  VARCHAR(8),
    status          VARCHAR(16) DEFAULT 'PUBLISHED',
    source_table_id BIGINT,
    tags            VARCHAR(255),
    view_count      INT DEFAULT 0,
    favorite        BOOLEAN DEFAULT FALSE,
    quality_score   NUMERIC(5,2),
    created_at      TIMESTAMP DEFAULT now(),
    updated_at      TIMESTAMP DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_asset_domain ON asset(domain_id);

-- ---------------------- 3. 数据血缘 ----------------------
CREATE TABLE IF NOT EXISTS lineage_edge (
    id              BIGSERIAL PRIMARY KEY,
    source_asset_id BIGINT NOT NULL,
    source_column   VARCHAR(128),
    target_asset_id BIGINT NOT NULL,
    target_column   VARCHAR(128),
    level           VARCHAR(16) DEFAULT 'TABLE',
    job_name        VARCHAR(128),
    transform_type  VARCHAR(32),
    sql_text        TEXT,
    created_at      TIMESTAMP DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lineage_src ON lineage_edge(source_asset_id);
CREATE INDEX IF NOT EXISTS idx_lineage_tgt ON lineage_edge(target_asset_id);

-- ---------------------- 4. 数据标准 ----------------------
CREATE TABLE IF NOT EXISTS standard_category (
    id          BIGSERIAL PRIMARY KEY,
    parent_id   BIGINT,
    code        VARCHAR(64),
    name        VARCHAR(128) NOT NULL,
    description TEXT
);

CREATE TABLE IF NOT EXISTS data_standard (
    id             BIGSERIAL PRIMARY KEY,
    code           VARCHAR(64) NOT NULL UNIQUE,
    name           VARCHAR(200) NOT NULL,
    category_id    BIGINT,
    std_type       VARCHAR(32),
    rule_content   TEXT,
    example_value  VARCHAR(255),
    status         VARCHAR(16) DEFAULT 'ACTIVE',
    version        VARCHAR(16) DEFAULT 'v1.0',
    owner          VARCHAR(64),
    effective_date DATE,
    created_at     TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS standard_mapping (
    id             BIGSERIAL PRIMARY KEY,
    standard_id    BIGINT NOT NULL,
    asset_id       BIGINT NOT NULL,
    column_name    VARCHAR(128),
    conform_status VARCHAR(16) DEFAULT 'CONFORM',
    checked_at     TIMESTAMP DEFAULT now()
);

-- ---------------------- 5. 数据质量 ----------------------
CREATE TABLE IF NOT EXISTS quality_rule (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    asset_id    BIGINT,
    column_name VARCHAR(128),
    rule_type   VARCHAR(32) NOT NULL,
    rule_expr   VARCHAR(512),
    threshold   NUMERIC(5,2) DEFAULT 100,
    severity    VARCHAR(16) DEFAULT 'MEDIUM',
    enabled     BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS quality_result (
    id          BIGSERIAL PRIMARY KEY,
    rule_id     BIGINT NOT NULL,
    run_at      TIMESTAMP DEFAULT now(),
    total_count BIGINT DEFAULT 0,
    pass_count  BIGINT DEFAULT 0,
    fail_count  BIGINT DEFAULT 0,
    pass_rate   NUMERIC(5,2),
    status      VARCHAR(16),
    detail      TEXT
);
CREATE INDEX IF NOT EXISTS idx_qr_rule ON quality_result(rule_id);
CREATE INDEX IF NOT EXISTS idx_qr_time ON quality_result(run_at);

-- ---------------------- 6. 安全分级 ----------------------
CREATE TABLE IF NOT EXISTS security_level (
    id          BIGSERIAL PRIMARY KEY,
    code        VARCHAR(8) NOT NULL UNIQUE,
    name        VARCHAR(32) NOT NULL,
    description TEXT,
    color       VARCHAR(16),
    sort_no     INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS security_policy (
    id               BIGSERIAL PRIMARY KEY,
    asset_id         BIGINT NOT NULL,
    column_name      VARCHAR(128),
    level_code       VARCHAR(8),
    desensitize      VARCHAR(32) DEFAULT 'NONE',
    authorized_roles VARCHAR(255),
    audit_enabled    BOOLEAN DEFAULT TRUE,
    updated_at       TIMESTAMP DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sp_asset ON security_policy(asset_id);

-- ---------------------- 7. 登录与角色权限 ----------------------
CREATE TABLE IF NOT EXISTS sys_user (
    id            BIGSERIAL PRIMARY KEY,
    username      VARCHAR(64)  NOT NULL UNIQUE,
    password_hash VARCHAR(64)  NOT NULL,
    salt          VARCHAR(32)  NOT NULL,
    display_name  VARCHAR(64),
    role          VARCHAR(32)  NOT NULL DEFAULT 'ANALYST',
    department    VARCHAR(64),
    status        VARCHAR(16)  DEFAULT 'ACTIVE',
    last_login_at TIMESTAMP,
    created_at    TIMESTAMP DEFAULT now()
);

-- ---------------------- 8. 数据服务 API 网关 ----------------------
CREATE TABLE IF NOT EXISTS api_service (
    id          BIGSERIAL PRIMARY KEY,
    api_code    VARCHAR(64)  NOT NULL UNIQUE,
    name        VARCHAR(200) NOT NULL,
    asset_id    BIGINT,
    sql_text    TEXT         NOT NULL,
    params_json TEXT,
    status      VARCHAR(16)  DEFAULT 'DRAFT',
    rate_limit  INT DEFAULT 60,
    owner       VARCHAR(64),
    description TEXT,
    call_count  INT DEFAULT 0,
    created_at  TIMESTAMP DEFAULT now(),
    updated_at  TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS api_client (
    id           BIGSERIAL PRIMARY KEY,
    app_id       VARCHAR(64) NOT NULL UNIQUE,
    app_key      VARCHAR(128) NOT NULL,
    app_name     VARCHAR(128),
    contact      VARCHAR(64),
    status       VARCHAR(16) DEFAULT 'ACTIVE',
    last_call_at TIMESTAMP,
    created_at   TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS api_call_log (
    id             BIGSERIAL PRIMARY KEY,
    api_id         BIGINT,
    api_code       VARCHAR(64),
    app_id         VARCHAR(64),
    params         TEXT,
    duration_ms    INT,
    row_count      INT,
    success        BOOLEAN DEFAULT TRUE,
    masked_columns VARCHAR(255),
    error_msg      TEXT,
    client_ip      VARCHAR(64),
    called_at      TIMESTAMP DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_acl_time ON api_call_log(called_at);

-- ---------------------- 9. 定时调度 ----------------------
CREATE TABLE IF NOT EXISTS sched_job (
    id           BIGSERIAL PRIMARY KEY,
    job_code     VARCHAR(64)  NOT NULL UNIQUE,
    name         VARCHAR(200) NOT NULL,
    job_type     VARCHAR(64)  NOT NULL,
    cron_expr    VARCHAR(64)  NOT NULL,
    enabled      BOOLEAN DEFAULT TRUE,
    description  TEXT,
    last_run_at  TIMESTAMP,
    last_status  VARCHAR(16),
    last_message TEXT,
    run_count    INT DEFAULT 0,
    created_at   TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sched_job_log (
    id          BIGSERIAL PRIMARY KEY,
    job_id      BIGINT NOT NULL,
    started_at  TIMESTAMP DEFAULT now(),
    finished_at TIMESTAMP,
    duration_ms BIGINT,
    status      VARCHAR(16),
    message     TEXT
);
CREATE INDEX IF NOT EXISTS idx_sjl_job ON sched_job_log(job_id);

-- ---------------------- 10. 演示真实数据（脱敏/网关验证用） ----------------------
CREATE TABLE IF NOT EXISTS biz_patient (
    id          BIGSERIAL PRIMARY KEY,
    patient_name VARCHAR(64),
    id_card     VARCHAR(32),
    phone       VARCHAR(20),
    gender      CHAR(1),
    birth_date  DATE,
    address     VARCHAR(255),
    dept_code   VARCHAR(16),
    created_at  TIMESTAMP DEFAULT now()
);
