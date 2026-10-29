package com.dataasset.platform.service;

import com.alibaba.druid.DbType;
import com.alibaba.druid.sql.SQLUtils;
import com.alibaba.druid.sql.ast.SQLStatement;
import com.alibaba.druid.sql.visitor.SchemaStatVisitor;
import com.alibaba.druid.stat.TableStat;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * SQL 血缘解析（确定性，不依赖 AI）：基于 Alibaba Druid SQL 解析器。
 * 解析 INSERT-SELECT / CREATE TABLE AS / UPDATE / MERGE 等语句，
 * 产出 源表→目标表 表级血缘与使用的字段清单，并映射到 dam_metadata.metadata_table 的 id 后入 dam_metadata.metadata_lineage。
 */
@Service
public class SqlLineageService {

    private final JdbcTemplate jdbc;

    public SqlLineageService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** 解析出的一条血缘边 */
    public record SqlEdge(String sourceName, String targetName, Long sourceTableId, Long targetTableId,
                          String relationType, List<String> columns, boolean resolvable,
                          String statement) {
    }

    public record ParseResult(int statementCount, List<SqlEdge> edges, List<String> unmapped,
                              List<String> warnings) {
    }

    private static final Map<String, DbType> DIALECTS = Map.of(
            "POSTGRESQL", DbType.postgresql,
            "MYSQL", DbType.mysql,
            "ORACLE", DbType.oracle,
            "SQLSERVER", DbType.sqlserver);

    public ParseResult parse(String sqlText, String dbType) {
        DbType dialect = DIALECTS.getOrDefault(
                dbType == null ? "POSTGRESQL" : dbType.toUpperCase(), DbType.postgresql);
        List<SQLStatement> statements;
        try {
            statements = SQLUtils.parseStatements(sqlText, dialect);
        } catch (Exception e) {
            throw new IllegalArgumentException("SQL 解析失败：" + e.getMessage());
        }

        // dam_metadata.metadata_table 全量名称映射：schema.table / table → id
        Map<String, Long> bySchemaTable = new HashMap<>();
        Map<String, Long> byTable = new HashMap<>();
        jdbc.queryForList("""
                select t.id, t.table_name, s.schema_name
                from dam_metadata.metadata_table t join dam_metadata.metadata_schema s on s.id = t.schema_id
                where t.status = 1
                """).forEach(r -> {
            long id = ((Number) r.get("id")).longValue();
            String table = String.valueOf(r.get("table_name"));
            String schema = String.valueOf(r.get("schema_name"));
            byTable.put(norm(table), id);
            bySchemaTable.put(norm(schema + "." + table), id);
        });

        List<SqlEdge> edges = new ArrayList<>();
        Set<String> unmapped = new LinkedHashSet<>();
        List<String> warnings = new ArrayList<>();

        for (SQLStatement stmt : statements) {
            SchemaStatVisitor visitor = new SchemaStatVisitor(dialect);
            stmt.accept(visitor);

            // AST 直接识别写入目标（比 visitor 统计更可靠，兼容 PG UPDATE...FROM）
            String astTarget = extractTarget(stmt);

            // 按操作类型归类本语句涉及的表
            Set<String> targets = new LinkedHashSet<>();
            Set<String> sources = new LinkedHashSet<>();
            String rel = null;
            for (Map.Entry<TableStat.Name, TableStat> en : visitor.getTables().entrySet()) {
                String name = norm(en.getKey().getName());
                TableStat st = en.getValue();
                if (nz(st.getInsertCount()) > 0 || nz(st.getCreateCount()) > 0 || nz(st.getUpdateCount()) > 0
                        || nz(st.getMergeCount()) > 0) {
                    targets.add(name);
                }
                if (nz(st.getSelectCount()) > 0) {
                    sources.add(name);
                }
            }
            if (astTarget != null) {
                targets.add(astTarget);
                // PG 方言下 UPDATE...FROM 的 from 表会被 visitor 记成 update 目标，纠正为源表
                if (stmt instanceof com.alibaba.druid.sql.ast.statement.SQLUpdateStatement) {
                    rel = "SQL_UPDATE";
                    targets.remove(astTarget);
                    targets.add(astTarget);
                    List<String> misplaced = targets.stream().filter(t -> !t.equals(astTarget)).toList();
                    misplaced.forEach(targets::remove);
                    sources.addAll(misplaced);
                }
            }
            // 关系类型取最具体的一种
            boolean hasInsert = visitor.getTables().values().stream().anyMatch(
                    st -> nz(st.getInsertCount()) > 0 || nz(st.getMergeCount()) > 0);
            boolean hasCreate = visitor.getTables().values().stream().anyMatch(st -> nz(st.getCreateCount()) > 0);
            boolean hasUpdate = visitor.getTables().values().stream().anyMatch(st -> nz(st.getUpdateCount()) > 0);
            if (rel == null) {
                if (hasInsert) {
                    rel = "SQL_INSERT";
                } else if (hasCreate) {
                    rel = "SQL_CTAS";
                } else if (hasUpdate) {
                    rel = "SQL_UPDATE";
                }
            }

            // 字段清单（带表归属的按表归组，未限定的汇总）
            List<String> cols = new ArrayList<>();
            visitor.getColumns().forEach(c -> {
                String col = c.getTable() == null ? c.getName() : c.getTable() + "." + c.getName();
                if (!cols.contains(col)) {
                    cols.add(col);
                }
            });

            if (targets.isEmpty()) {
                if (!sources.isEmpty()) {
                    warnings.add("纯查询语句（无写入目标），已解析读取表：" + String.join(", ", sources));
                }
                continue;
            }
            for (String t : targets) {
                if (rel == null) {
                    rel = "SQL_WRITE";
                }
                if (sources.isEmpty()) {
                    // 纯写入（如 delete / insert values），只有目标，不产生边，但报告
                    warnings.add("目标表 " + t + " 无上游查询（非 INSERT-SELECT/CTAS），不生成血缘边");
                    continue;
                }
                for (String s : sources) {
                    if (s.equals(t)) {
                        continue;
                    }
                    Long sId = resolve(s, bySchemaTable, byTable);
                    Long tId = resolve(t, bySchemaTable, byTable);
                    if (sId == null) {
                        unmapped.add(s);
                    }
                    if (tId == null) {
                        unmapped.add(t);
                    }
                    edges.add(new SqlEdge(s, t, sId, tId, rel,
                            cols.size() > 40 ? cols.subList(0, 40) : cols,
                            sId != null && tId != null,
                            abbreviate(stmt.toString(), 600)));
                }
            }
        }
        return new ParseResult(statements.size(), edges, new ArrayList<>(unmapped), warnings);
    }

    /** 把解析出的边写入 dam_metadata.metadata_lineage（默认 discovered_by='SQL解析'，按 表对+关系类型+来源 去重） */
    public record SaveResult(int saved, int skipped) {
    }

    public SaveResult save(List<Map<String, Object>> edges) {
        int saved = 0;
        int skipped = 0;
        for (Map<String, Object> e : edges) {
            Long sId = toLong(e.get("sourceTableId"));
            Long tId = toLong(e.get("targetTableId"));
            if (sId == null || tId == null) {
                skipped++;
                continue;
            }
            String rel = String.valueOf(e.getOrDefault("relationType", "SQL"));
            boolean fromAi = "AI_INFER".equalsIgnoreCase(rel) || "AI".equalsIgnoreCase(String.valueOf(e.get("discoveredBy")));
            String discoveredBy = fromAi ? "AI" : "SQL解析";
            String rule = transformRule(e);
            int exists = jdbc.queryForObject("""
                    select count(*) from dam_metadata.metadata_lineage
                    where source_type = 'TABLE' and target_type = 'TABLE'
                      and source_id = ? and target_id = ? and relation_type = ?
                      and discovered_by = ? and deleted_at is null
                    """, Integer.class, sId, tId, rel, discoveredBy);
            if (exists > 0) {
                skipped++;
                continue;
            }
            jdbc.update("""
                    insert into dam_metadata.metadata_lineage(source_type, source_id, target_type, target_id,
                        relation_type, transform_rule, dependency_level, source_system, collection_id,
                        discovered_by, created_by, updated_by)
                    values ('TABLE', ?, 'TABLE', ?, ?, ?, 1, ?, 0, ?, ?, ?)
                    """, sId, tId, rel, rule,
                    fromAi ? "AI" : "SQL_PARSE", discoveredBy, discoveredBy, discoveredBy);
            saved++;
        }
        return new SaveResult(saved, skipped);
    }

    /** 从 AST 识别写入目标表名（INSERT / CTAS / UPDATE / MERGE），没有则返回 null */
    private static String extractTarget(SQLStatement stmt) {
        try {
            if (stmt instanceof com.alibaba.druid.sql.ast.statement.SQLInsertStatement ins
                    && ins.getTableName() != null) {
                return norm(ins.getTableName().toString());
            }
            if (stmt instanceof com.alibaba.druid.sql.ast.statement.SQLCreateTableStatement ct
                    && ct.getName() != null) {
                return norm(ct.getName().toString());
            }
            if (stmt instanceof com.alibaba.druid.sql.ast.statement.SQLUpdateStatement up
                    && up.getTableName() != null) {
                return norm(up.getTableName().toString());
            }
            if (stmt instanceof com.alibaba.druid.sql.ast.statement.SQLMergeStatement mg
                    && mg.getInto() != null) {
                return norm(mg.getInto().toString());
            }
        } catch (Exception ignore) {
            // 解析异常时回退到 visitor 统计
        }
        return null;
    }

    private String transformRule(Map<String, Object> e) {
        StringBuilder sb = new StringBuilder();
        Object cols = e.get("columns");
        if (cols instanceof List<?> list && !list.isEmpty()) {
            sb.append("字段: ").append(String.join(", ", list.stream().map(String::valueOf).limit(20).toList()));
        }
        Object sql = e.get("statement");
        if (sql != null && !String.valueOf(sql).isBlank()) {
            if (sb.length() > 0) {
                sb.append(" | ");
            }
            sb.append("SQL: ").append(abbreviate(String.valueOf(sql), 380 - sb.length()));
        }
        if (sb.isEmpty()) {
            sb.append("SQL 解析");
        }
        return sb.toString();
    }

    private static Long resolve(String name, Map<String, Long> bySchemaTable, Map<String, Long> byTable) {
        Long hit = bySchemaTable.get(name);
        if (hit == null) {
            int dot = name.indexOf('.');
            hit = byTable.get(dot >= 0 ? name.substring(dot + 1) : name);
        }
        return hit;
    }

    /** 去引号、小写、去掉 schema 前缀里的动态 schema 占位等 */
    private static String norm(String raw) {
        String s = raw == null ? "" : raw.replace("`", "").replace("\"", "").trim().toLowerCase();
        return s;
    }

    private static long nz(Integer v) {
        return v == null ? 0 : v;
    }

    private static Long toLong(Object o) {
        if (o == null) {
            return null;
        }
        if (o instanceof Number n) {
            return n.longValue();
        }
        try {
            return Long.parseLong(String.valueOf(o));
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    private static String abbreviate(String s, int max) {
        if (s == null) {
            return "";
        }
        String one = s.replaceAll("\\s+", " ").trim();
        return one.length() > max ? one.substring(0, max) + "..." : one;
    }
}
