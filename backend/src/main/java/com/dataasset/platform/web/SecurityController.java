package com.dataasset.platform.web;

import com.dataasset.platform.service.MaskingService;
import com.dataasset.platform.util.Rows;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.Statement;
import java.util.*;

@RestController
@RequestMapping("/api/security")
public class SecurityController {

    private final JdbcTemplate jdbc;
    private final MaskingService maskingService;

    public SecurityController(JdbcTemplate jdbc, MaskingService maskingService) {
        this.jdbc = jdbc;
        this.maskingService = maskingService;
    }

    public record PolicyReq(Long assetId, String columnName, String levelCode, String desensitize,
                            String authorizedRoles, Boolean auditEnabled) {
    }

    @GetMapping("/levels")
    public List<Map<String, Object>> levels() {
        return Rows.camel(jdbc.queryForList("""
                select l.*, (select count(*) from asset a where a.security_level = l.code) as asset_count
                from security_level l order by l.sort_no
                """));
    }

    @PutMapping("/levels/{code}")
    public Map<String, Object> updateLevel(@PathVariable String code, @RequestBody Map<String, String> body) {
        jdbc.update("update security_level set name = coalesce(?, name), description = coalesce(?, description) where code = ?",
                body.get("name"), body.get("description"), code);
        return Map.of("code", code);
    }

    @GetMapping("/policies")
    public List<Map<String, Object>> policies(@RequestParam(required = false) Long assetId) {
        StringBuilder sql = new StringBuilder("""
                select p.*, a.name as asset_name, a.asset_code, l.name as level_name, l.color as level_color
                from security_policy p
                left join asset a on a.id = p.asset_id
                left join security_level l on l.code = p.level_code
                where 1 = 1
                """);
        if (assetId == null) {
            return Rows.camel(jdbc.queryForList(sql + " order by p.asset_id, p.column_name nulls first"));
        }
        return Rows.camel(jdbc.queryForList(sql + " and p.asset_id = ? order by p.column_name nulls first", assetId));
    }

    @PostMapping("/policies")
    public Map<String, Object> create(@RequestBody PolicyReq req) {
        Long id = jdbc.queryForObject("""
                insert into security_policy(asset_id, column_name, level_code, desensitize, authorized_roles, audit_enabled)
                values (?,?,?,?,?,?) returning id
                """, Long.class, req.assetId(), req.columnName(), req.levelCode(),
                req.desensitize() == null ? "NONE" : req.desensitize(),
                req.authorizedRoles(), req.auditEnabled() == null || req.auditEnabled());
        return Map.of("id", id);
    }

    @PutMapping("/policies/{id}")
    public Map<String, Object> update(@PathVariable long id, @RequestBody PolicyReq req) {
        jdbc.update("""
                update security_policy set column_name = ?, level_code = ?, desensitize = ?,
                       authorized_roles = ?, audit_enabled = ?, updated_at = now()
                where id = ?
                """, req.columnName(), req.levelCode(), req.desensitize(), req.authorizedRoles(),
                req.auditEnabled() == null || req.auditEnabled(), id);
        return Map.of("id", id);
    }

    @DeleteMapping("/policies/{id}")
    public Map<String, Object> delete(@PathVariable long id) {
        jdbc.update("delete from security_policy where id = ?", id);
        return Map.of("deleted", id);
    }

    /** 脱敏引擎预览：真实查询资产对应表，返回 原始值 vs 脱敏值 对照（仅本机数据源） */
    @GetMapping("/mask-preview")
    public Map<String, Object> maskPreview(@RequestParam Long assetId,
                                           @RequestParam(defaultValue = "5") int limit) {
        Map<String, Object> target;
        try {
            target = jdbc.queryForMap("""
                    select t.table_name, t.schema_name, s.host, s.port, s.db_name, s.type,
                           s.username, s.password, s.name as source_name
                    from asset a join meta_table t on t.id = a.source_table_id
                    join data_source s on s.id = t.source_id
                    where a.id = ?
                    """, assetId);
        } catch (Exception e) {
            throw new IllegalArgumentException("该资产未关联元数据表，无法预览");
        }
        String host = String.valueOf(target.get("host"));
        boolean local = "localhost".equalsIgnoreCase(host) || "127.0.0.1".equals(host) || "::1".equals(host);
        if (!local) {
            throw new IllegalArgumentException("演示环境仅支持本机数据源真实查询（" + target.get("source_name") + " 不可直连）");
        }
        String url = "jdbc:postgresql://%s:%s/%s?connectTimeout=3"
                .formatted(target.get("host"), target.get("port"), target.get("db_name"));

        List<Map<String, Object>> raw = new ArrayList<>();
        String schema = String.valueOf(target.get("schema_name"));
        String qualified = (schema == null || schema.isBlank() || "null".equals(schema) ? "" : "\"" + schema + "\".")
                + "\"" + target.get("table_name") + "\"";
        try (Connection conn = DriverManager.getConnection(url,
                String.valueOf(target.get("username")), String.valueOf(target.get("password")));
             Statement st = conn.createStatement()) {
            st.setMaxRows(Math.min(limit, 20));
            try (ResultSet rs = st.executeQuery("select * from " + qualified)) {
                ResultSetMetaData md = rs.getMetaData();
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    for (int i = 1; i <= md.getColumnCount(); i++) {
                        row.put(md.getColumnLabel(i), rs.getObject(i));
                    }
                    raw.add(row);
                }
            }
        } catch (Exception e) {
            throw new IllegalArgumentException("真实查询失败：" + e.getMessage());
        }

        MaskingService.MaskResult masked = maskingService.apply(assetId, raw);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("raw", raw);
        out.put("masked", masked.rows());
        out.put("maskedColumns", masked.maskedColumns());
        out.put("policies", Rows.camel(jdbc.queryForList("""
                select p.*, l.name as level_name, l.color as level_color
                from security_policy p left join security_level l on l.code = p.level_code
                where p.asset_id = ? order by p.column_name
                """, assetId)));
        return out;
    }

    @GetMapping("/summary")
    public Map<String, Object> summary() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("distribution", Rows.camel(jdbc.queryForList("""
                select l.code, l.name, l.color, count(a.id) as asset_count
                from security_level l left join asset a on a.security_level = l.code
                group by l.code, l.name, l.color, l.sort_no order by l.sort_no
                """)));
        out.put("policyCount", jdbc.queryForObject("select count(*) from security_policy", Long.class));
        out.put("desensitizeCount", jdbc.queryForObject(
                "select count(*) from security_policy where desensitize <> 'NONE'", Long.class));
        out.put("byDesensitize", Rows.camel(jdbc.queryForList("""
                select desensitize, count(*) as cnt from security_policy group by desensitize order by cnt desc
                """)));
        out.put("sensitiveAssets", Rows.camel(jdbc.queryForList("""
                select a.id, a.name, a.asset_code, a.security_level, l.name as level_name, l.color,
                       (select count(*) from security_policy p where p.asset_id = a.id and p.desensitize <> 'NONE') as masked_columns
                from asset a left join security_level l on l.code = a.security_level
                where a.security_level in ('L3', 'L4')
                order by a.security_level desc, a.id
                """)));
        return out;
    }
}
