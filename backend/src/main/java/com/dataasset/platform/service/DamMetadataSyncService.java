package com.dataasset.platform.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * dam 层元数据采集（阶段 C）：把 dam_metadata.metadata_datasource 注册的源库
 * 采集到 dam_metadata.metadata_schema / metadata_table / metadata_column，
 * 并写 dam_metadata.metadata_collection 采集日志。
 * 支持 PostgreSQL（PG 系统目录取注释/行数）与 InterSystems IRIS、MySQL（通用 INFORMATION_SCHEMA）。
 */
@Service
public class DamMetadataSyncService {

    private static final Logger log = LoggerFactory.getLogger(DamMetadataSyncService.class);

    private record TMeta(String schema, String table, String type, String comment, long rows) {
    }

    private final JdbcTemplate jdbc;

    public DamMetadataSyncService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public String syncAll() {
        List<Map<String, Object>> sources = jdbc.queryForList(
                "select * from dam_metadata.metadata_datasource where deleted_at is null");
        if (sources.isEmpty()) {
            return "没有已注册的元数据数据源";
        }
        StringBuilder sb = new StringBuilder();
        for (Map<String, Object> ds : sources) {
            try {
                sb.append(syncSource(ds)).append("；");
            } catch (Exception e) {
                log.warn("数据源 {} 采集失败", ds.get("ds_code"), e);
                sb.append(ds.get("ds_name")).append(" 采集失败(")
                        .append(e.getMessage() == null ? e.toString() : e.getMessage()).append(")").append("；");
            }
        }
        return sb.toString();
    }

    /**
     * 采集中台侧登记的某个源（数据源连接不落本平台，每次从中台 OpenAPI 取）：
     * 1) 按 DS-MID-{id} 幂等登记到 dam_metadata.metadata_datasource；
     * 2) 复用同一个采集实现写入 dam_metadata.metadata_*。
     */
    public String syncFromMidSource(Map<String, Object> mid) {
        String dsCode = "DS-MID-" + mid.get("id");
        String type = String.valueOf(mid.get("type")).toUpperCase();
        String host = String.valueOf(mid.get("host"));
        Object portObj = mid.get("port");
        int port = portObj == null
                ? com.dataasset.platform.util.SourceConnections.defaultPort(type)
                : ((Number) portObj).intValue();
        String db = mid.get("dbName") == null ? "" : String.valueOf(mid.get("dbName"));
        String jdbcUrl = com.dataasset.platform.util.SourceConnections.url(type, host, port, db);
        String driver = switch (type) {
            case "IRIS" -> "com.intersystems.jdbc.IRISDriver";
            case "MYSQL", "DORIS" -> "com.mysql.cj.jdbc.Driver";
            default -> "org.postgresql.Driver";
        };
        List<Long> ids = jdbc.queryForList(
                "select id from dam_metadata.metadata_datasource where ds_code = ? and deleted_at is null",
                Long.class, dsCode);
        long damId;
        if (ids.isEmpty()) {
            damId = jdbc.queryForObject("""
                    insert into dam_metadata.metadata_datasource(ds_name, ds_code, ds_type, ds_adapter, ds_ip, ds_port,
                        jdbc_url, username, password, driver_class, description, created_by)
                    values (?,?,?,?,?,?,?,?,?,?,?, '中台同步')
                    returning id
                    """, Long.class, String.valueOf(mid.get("name")), dsCode, type, "JDBC-" + type,
                    host, String.valueOf(port), jdbcUrl,
                    mid.get("username"), mid.get("password"), driver,
                    "数据中台源 #" + mid.get("id") + "（连接由中台持有）");
        } else {
            damId = ids.get(0);
            jdbc.update("""
                    update dam_metadata.metadata_datasource set ds_name = ?, ds_type = ?, ds_ip = ?, ds_port = ?,
                           jdbc_url = ?, username = ?, password = ?, driver_class = ?,
                           updated_at = now(), updated_by = '中台同步'
                    where id = ?
                    """, String.valueOf(mid.get("name")), type, host, String.valueOf(port), jdbcUrl,
                    mid.get("username"), mid.get("password"), driver, damId);
        }
        Map<String, Object> ds = jdbc.queryForMap(
                "select * from dam_metadata.metadata_datasource where id = ?", damId);
        try {
            return syncSource(ds);
        } catch (SQLException e) {
            throw new IllegalStateException(e.getMessage(), e);
        }
    }

    public String syncSource(Map<String, Object> ds) throws SQLException {
        String type = String.valueOf(ds.get("ds_type")).toUpperCase();
        DriverManager.setLoginTimeout(8);
        // InterSystems 驱动只认大写前缀 jdbc:IRIS，归一化用户手填的小写形式
        String url = String.valueOf(ds.get("jdbc_url"));
        if (url.regionMatches(true, 0, "jdbc:iris:", 0, 10) && !url.startsWith("jdbc:IRIS:")) {
            ds.put("jdbc_url", "jdbc:IRIS:" + url.substring(10));
        }
        if (type.contains("POSTGRES") || type.contains("PG")) {
            return syncPg(ds);
        }
        if (type.contains("IRIS")) {
            return syncGeneric(ds, "IRIS");
        }
        if (type.contains("MYSQL") || type.contains("DORIS")) {
            return syncGeneric(ds, "MYSQL");
        }
        return ds.get("ds_name") + "：暂不支持 " + type + " 方言，已跳过";
    }

    /** 通用 INFORMATION_SCHEMA 采集（IRIS / MySQL），无注释与行数时置空/0 */
    private String syncGeneric(Map<String, Object> ds, String dialect) throws SQLException {
        boolean isIris = "IRIS".equals(dialect);
        long dsId = ((Number) ds.get("id")).longValue();
        long t0 = System.currentTimeMillis();
        int tableTotal = 0;
        int columnTotal = 0;
        try (Connection conn = DriverManager.getConnection(
                String.valueOf(ds.get("jdbc_url")),
                String.valueOf(ds.get("username")),
                String.valueOf(ds.get("password")))) {
            conn.setReadOnly(true);

            // 1. 表（含 schema 归集）
            List<TMeta> tables = new ArrayList<>();
            String tablesSql = isIris ? """
                    select TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE from INFORMATION_SCHEMA."TABLES"
                    where TABLE_TYPE = 'BASE TABLE' order by TABLE_SCHEMA, TABLE_NAME
                    """ : """
                    select table_schema, table_name, table_type, coalesce(table_rows, 0)
                    from information_schema.tables
                    where table_type = 'BASE TABLE'
                      and table_schema not in ('mysql', 'information_schema', 'performance_schema', 'sys')
                    order by table_schema, table_name
                    """;
            try (PreparedStatement ps = conn.prepareStatement(tablesSql);
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String schema = rs.getString(1);
                    if (isIris ? isIrisSystemSchema(schema) : isMysqlSystemSchema(schema)) {
                        continue;
                    }
                    tables.add(new TMeta(schema, rs.getString(2), "BASE TABLE", "",
                            isIris ? 0L : rs.getLong(3 + 1)));
                }
            }

            // 2. schema 注册（从表清单归集）
            Map<String, Long> schemaIds = new LinkedHashMap<>();
            for (TMeta t : tables) {
                if (schemaIds.containsKey(t.schema())) {
                    continue;
                }
                List<Long> exist = jdbc.queryForList(
                        "select id from dam_metadata.metadata_schema where datasource_id = ? and schema_name = ? and deleted_at is null",
                        Long.class, dsId, t.schema());
                Long id = exist.isEmpty()
                        ? jdbc.queryForObject("""
                                insert into dam_metadata.metadata_schema(datasource_id, schema_name, schema_type, schema_owner)
                                values (?,?, 'BASE', ?) returning id
                                """, Long.class, dsId, t.schema(), "未知")
                        : exist.get(0);
                schemaIds.put(t.schema(), id);
            }

            // 3. 字段
            Map<String, List<Map<String, Object>>> columnsByTable = new HashMap<>();
            String columnsSql = isIris ? """
                    select TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH,
                           (IS_NULLABLE = 'YES'), ORDINAL_POSITION
                    from INFORMATION_SCHEMA.COLUMNS order by TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION
                    """ : """
                    select table_schema, table_name, column_name, data_type, character_maximum_length,
                           (is_nullable = 'YES'), ordinal_position
                    from information_schema.columns
                    where table_schema not in ('mysql', 'information_schema', 'performance_schema', 'sys')
                    order by table_schema, table_name, ordinal_position
                    """;
            try (PreparedStatement ps = conn.prepareStatement(columnsSql);
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String schema = rs.getString(1);
                    if (isIris ? isIrisSystemSchema(schema) : isMysqlSystemSchema(schema)) {
                        continue;
                    }
                    Map<String, Object> c = new LinkedHashMap<>();
                    c.put("schema", schema);
                    c.put("table", rs.getString(2));
                    c.put("name", rs.getString(3));
                    c.put("type", rs.getString(4));
                    c.put("length", (Integer) rs.getObject(5));
                    c.put("nullable", rs.getBoolean(6));
                    c.put("ordinal", rs.getInt(7));
                    columnsByTable.computeIfAbsent(schema + "." + rs.getString(2),
                            k -> new ArrayList<>()).add(c);
                }
            }

            // 4. 主键（best-effort，IRIS 老版本缺约束视图则跳过）
            Map<String, List<String>> pks = new HashMap<>();
            try (PreparedStatement ps = conn.prepareStatement(isIris ? """
                    select tc.TABLE_SCHEMA, tc.TABLE_NAME, kcu.COLUMN_NAME
                    from INFORMATION_SCHEMA."TABLE_CONSTRAINTS" tc
                    join INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
                      on tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME and tc.TABLE_SCHEMA = kcu.TABLE_SCHEMA
                    where tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
                    """ : """
                    select tc.table_schema, tc.table_name, kcu.column_name
                    from information_schema.table_constraints tc
                    join information_schema.key_column_usage kcu
                      on tc.constraint_name = kcu.constraint_name and tc.constraint_schema = kcu.constraint_schema
                    where tc.constraint_type = 'PRIMARY KEY'
                    """);
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    pks.computeIfAbsent(rs.getString(1) + "." + rs.getString(2), k -> new ArrayList<>())
                            .add(rs.getString(3));
                }
            }

            for (TMeta t : tables) {
                List<Map<String, Object>> cols = columnsByTable.getOrDefault(t.schema() + "." + t.table(), List.of());
                Long tableId = upsertTable(dsId, schemaIds.get(t.schema()), t, cols.size());
                jdbc.update("delete from dam_metadata.metadata_column where table_id = ?", tableId);
                for (Map<String, Object> c : cols) {
                    boolean pk = pks.getOrDefault(t.schema() + "." + t.table(), List.of())
                            .contains(String.valueOf(c.get("name")));
                    jdbc.update("""
                            insert into dam_metadata.metadata_column(datasource_id, schema_id, table_id, column_name, column_type,
                                                            column_length, is_nullable, is_primary_key, column_comment, ordinal_position)
                            values (?,?,?,?,?,?,?,?,?,?)
                            """, dsId, schemaIds.get(t.schema()), tableId, c.get("name"), c.get("type"),
                            c.get("length"), c.get("nullable"), pk, "", c.get("ordinal"));
                    columnTotal++;
                }
                tableTotal++;
            }

            writeCollectionLog(dsId, schemaIds, tableTotal, columnTotal);
        }
        jdbc.update("""
                update dam_metadata.metadata_datasource set updated_at = now(), updated_by = '平台' where id = ?
                """, dsId);
        return ds.get("ds_name") + "（" + dialect + "）：" + tableTotal + " 表 / " + columnTotal + " 字段（"
                + (System.currentTimeMillis() - t0) + "ms）";
    }

    private static boolean isIrisSystemSchema(String schema) {
        String s = schema == null ? "" : schema.trim();
        return s.isEmpty() || s.startsWith("%") || s.equalsIgnoreCase("INFORMATION_SCHEMA")
                || s.equalsIgnoreCase("SYS") || s.equalsIgnoreCase("INFORMATION");
    }

    private static boolean isMysqlSystemSchema(String schema) {
        String s = schema == null ? "" : schema.trim().toLowerCase();
        return s.isEmpty() || s.equals("mysql") || s.equals("information_schema")
                || s.equals("performance_schema") || s.equals("sys");
    }

    /** PG 方言采集（系统目录带注释与行数估算） */
    private String syncPg(Map<String, Object> ds) throws SQLException {
        long dsId = ((Number) ds.get("id")).longValue();
        long t0 = System.currentTimeMillis();
        int tableTotal = 0;
        int columnTotal = 0;
        try (Connection conn = DriverManager.getConnection(
                String.valueOf(ds.get("jdbc_url")),
                String.valueOf(ds.get("username")),
                String.valueOf(ds.get("password")))) {
            conn.setReadOnly(true);

            // 1. schema 注册
            Map<String, Long> schemaIds = new LinkedHashMap<>();
            try (PreparedStatement ps = conn.prepareStatement("""
                    select nspname, pg_get_userbyid(nspowner) as owner
                    from pg_namespace where nspname not like 'pg\\_%' and nspname <> 'information_schema'
                    """);
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String name = rs.getString(1);
                    List<Long> exist = jdbc.queryForList(
                            "select id from dam_metadata.metadata_schema where datasource_id = ? and schema_name = ? and deleted_at is null",
                            Long.class, dsId, name);
                    Long id = exist.isEmpty()
                            ? jdbc.queryForObject("""
                                    insert into dam_metadata.metadata_schema(datasource_id, schema_name, schema_type, schema_owner)
                                    values (?,?, 'BASE', ?) returning id
                                    """, Long.class, dsId, name, rs.getString(2))
                            : exist.get(0);
                    schemaIds.put(name, id);
                }
            }

            // 2. 表注册（含行数估算与注释）
            List<TMeta> tables = new ArrayList<>();
            try (PreparedStatement ps = conn.prepareStatement("""
                    select t.table_schema, t.table_name, t.table_type,
                           coalesce(obj_description(format('%I.%I', t.table_schema, t.table_name)::regclass), ''),
                           coalesce((select n_live_tup from pg_stat_user_tables st
                             where st.schemaname = t.table_schema and st.relname = t.table_name), 0)
                    from information_schema.tables t
                    where t.table_type = 'BASE TABLE'
                      and t.table_schema not in ('pg_catalog', 'information_schema')
                    order by 1, 2
                    """);
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    tables.add(new TMeta(rs.getString(1), rs.getString(2), rs.getString(3),
                            rs.getString(4), rs.getLong(5)));
                }
            }
            Map<String, List<Map<String, Object>>> columnsByTable = new HashMap<>();
            try (PreparedStatement ps = conn.prepareStatement("""
                    select c.table_schema, c.table_name, c.column_name, c.data_type,
                           c.character_maximum_length, (c.is_nullable = 'YES'), c.ordinal_position,
                           coalesce(col_description(format('%I.%I', c.table_schema, c.table_name)::regclass,
                                                    c.ordinal_position), '')
                    from information_schema.columns c
                    where c.table_schema not in ('pg_catalog', 'information_schema')
                    order by c.table_schema, c.table_name, c.ordinal_position
                    """);
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> c = new LinkedHashMap<>();
                    c.put("schema", rs.getString(1));
                    c.put("table", rs.getString(2));
                    c.put("name", rs.getString(3));
                    c.put("type", rs.getString(4));
                    c.put("length", (Integer) rs.getObject(5));
                    c.put("nullable", rs.getBoolean(6));
                    c.put("ordinal", rs.getInt(7));
                    c.put("comment", rs.getString(8));
                    columnsByTable.computeIfAbsent(rs.getString(1) + "." + rs.getString(2),
                            k -> new ArrayList<>()).add(c);
                }
            }
            // 主键
            Map<String, List<String>> pks = new HashMap<>();
            try (PreparedStatement ps = conn.prepareStatement("""
                    select tc.table_schema, tc.table_name, kcu.column_name
                    from information_schema.table_constraints tc
                    join information_schema.key_column_usage kcu
                      on tc.constraint_name = kcu.constraint_name and tc.constraint_schema = kcu.constraint_schema
                    where tc.constraint_type = 'PRIMARY KEY'
                    """);
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    pks.computeIfAbsent(rs.getString(1) + "." + rs.getString(2), k -> new ArrayList<>())
                            .add(rs.getString(3));
                }
            }

            for (TMeta t : tables) {
                List<Map<String, Object>> cols = columnsByTable.getOrDefault(t.schema() + "." + t.table(), List.of());
                Long tableId = upsertTable(dsId, schemaIds.get(t.schema()), t, cols.size());
                jdbc.update("delete from dam_metadata.metadata_column where table_id = ?", tableId);
                for (Map<String, Object> c : cols) {
                    boolean pk = pks.getOrDefault(t.schema() + "." + t.table(), List.of())
                            .contains(String.valueOf(c.get("name")));
                    jdbc.update("""
                            insert into dam_metadata.metadata_column(datasource_id, schema_id, table_id, column_name, column_type,
                                                            column_length, is_nullable, is_primary_key, column_comment, ordinal_position)
                            values (?,?,?,?,?,?,?,?,?,?)
                            """, dsId, schemaIds.get(t.schema()), tableId, c.get("name"), c.get("type"),
                            c.get("length"), c.get("nullable"), pk, c.get("comment"), c.get("ordinal"));
                    columnTotal++;
                }
                tableTotal++;
            }

            // 3. 采集日志
            writeCollectionLog(dsId, schemaIds, tableTotal, columnTotal);
        }
        jdbc.update("""
                update dam_metadata.metadata_datasource set updated_at = now(), updated_by = '平台' where id = ?
                """, dsId);
        return ds.get("ds_name") + "：" + tableTotal + " 表 / " + columnTotal + " 字段（"
                + (System.currentTimeMillis() - t0) + "ms）";
    }

    /** 采集日志（schema_id 非空约束：取任一已注册 schema） */
    private void writeCollectionLog(long dsId, Map<String, Long> schemaIds, int tableTotal, int columnTotal) {
        Long logSchemaId = schemaIds.isEmpty() ? 0L : schemaIds.values().iterator().next();
        jdbc.update("""
                insert into dam_metadata.metadata_collection(datasource_id, schema_id, job_name, job_type,
                                                    start_time, end_time, total_tables, total_columns,
                                                    success_count, fail_count, status, created_by)
                values (?, ?, 'dam 元数据全量采集', 'METADATA_SYNC', now(), now(), ?, ?, ?, 0, 1, '平台')
                """, dsId, logSchemaId, tableTotal, columnTotal, tableTotal);
    }

    private Long upsertTable(long dsId, Long schemaId, TMeta t, int columnCount) {
        String layer = layerOfSchema(schemaId);
        List<Long> ids = jdbc.queryForList(
                "select id from dam_metadata.metadata_table where datasource_id = ? and table_name = ? and deleted_at is null",
                Long.class, dsId, t.table());
        if (ids.isEmpty()) {
            return jdbc.queryForObject("""
                    insert into dam_metadata.metadata_table(datasource_id, schema_id, table_name, table_comment, table_type,
                                                   row_count, table_size, created_time, last_modified, last_sync_time, layer)
                    values (?,?,?,?,?,?,?,?,?,?,?)
                    returning id
                    """, Long.class, dsId, schemaId, t.table(), t.comment(), t.type(),
                    String.valueOf(t.rows()), "-", java.sql.Timestamp.from(java.time.Instant.now()),
                    java.sql.Timestamp.from(java.time.Instant.now()),
                    java.sql.Timestamp.from(java.time.Instant.now()), layer);
        }
        long id = ids.get(0);
        jdbc.update("""
                update dam_metadata.metadata_table set table_comment = ?, row_count = ?, last_sync_time = now(),
                       layer = ?, updated_at = now(), updated_by = '平台'
                where id = ?
                """, t.comment(), String.valueOf(t.rows()), layer, id);
        return id;
    }

    /** 数仓分层：按 schema 名前缀推导（ods_%→ODS，dim→DIM，dwd→DWD，dws→DWS，ads→ADS，其余 SRC） */
    private String layerOfSchema(Long schemaId) {
        if (schemaId == null) {
            return "SRC";
        }
        try {
            String name = jdbc.queryForObject(
                    "select schema_name from dam_metadata.metadata_schema where id = ?", String.class, schemaId);
            String n = name == null ? "" : name.toLowerCase();
            if (n.startsWith("ods_")) {
                return "ODS";
            }
            return switch (n) {
                case "dim" -> "DIM";
                case "dwd" -> "DWD";
                case "dws" -> "DWS";
                case "ads" -> "ADS";
                default -> "SRC";
            };
        } catch (Exception e) {
            return "SRC";
        }
    }
}
