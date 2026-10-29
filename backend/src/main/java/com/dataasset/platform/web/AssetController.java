package com.dataasset.platform.web;

import com.dataasset.platform.util.Rows;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api")
public class AssetController {

    private final JdbcTemplate jdbc;

    public AssetController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record AssetReq(@NotBlank String name, String assetCode, Long domainId, @NotBlank String assetType,
                           String description, String owner, String department, String securityLevel,
                           String status, String tags) {
    }

    public record DomainReq(@NotBlank String name, String code, Long parentId, String description) {
    }

    // ---------------- 业务域（目录树） ----------------

    @GetMapping("/domains")
    public List<Map<String, Object>> domains() {
        List<Map<String, Object>> flat = Rows.camel(jdbc.queryForList("""
                select d.*, (select count(*) from asset a where a.domain_id = d.id) as asset_count
                from asset_domain d order by d.sort_no, d.id
                """));
        Map<Long, Map<String, Object>> index = new LinkedHashMap<>();
        flat.forEach(d -> {
            d.put("children", new ArrayList<Map<String, Object>>());
            index.put(((Number) d.get("id")).longValue(), d);
        });
        List<Map<String, Object>> roots = new ArrayList<>();
        for (Map<String, Object> d : flat) {
            Object pid = d.get("parentId");
            Map<String, Object> parent = pid == null ? null : index.get(((Number) pid).longValue());
            if (parent == null) {
                roots.add(d);
            } else {
                @SuppressWarnings("unchecked")
                List<Map<String, Object>> children = (List<Map<String, Object>>) parent.get("children");
                children.add(d);
            }
        }
        return roots;
    }

    @PostMapping("/domains")
    public Map<String, Object> createDomain(@Valid @RequestBody DomainReq req) {
        Long id = jdbc.queryForObject("""
                insert into asset_domain(parent_id, code, name, description)
                values (?,?,?,?) returning id
                """, Long.class, req.parentId(), req.code() == null ? "D" + System.currentTimeMillis() : req.code(),
                req.name(), req.description());
        return Map.of("id", id);
    }

    // ---------------- 资产 ----------------

    @GetMapping("/assets")
    public Map<String, Object> list(@RequestParam(required = false) Long domainId,
                                    @RequestParam(required = false) String keyword,
                                    @RequestParam(required = false) String level,
                                    @RequestParam(required = false) String type,
                                    @RequestParam(defaultValue = "1") int page,
                                    @RequestParam(defaultValue = "12") int size) {
        StringBuilder where = new StringBuilder(" where 1 = 1");
        List<Object> args = new ArrayList<>();
        if (domainId != null) {
            where.append("""
                     and (a.domain_id = ? or a.domain_id in (select id from asset_domain where parent_id = ?))
                    """);
            args.add(domainId);
            args.add(domainId);
        }
        if (keyword != null && !keyword.isBlank()) {
            where.append(" and (a.name ilike ? or a.asset_code ilike ? or a.description ilike ? or a.tags ilike ?)");
            for (int i = 0; i < 4; i++) {
                args.add("%" + keyword + "%");
            }
        }
        if (level != null && !level.isBlank()) {
            where.append(" and a.security_level = ?");
            args.add(level);
        }
        if (type != null && !type.isBlank()) {
            where.append(" and a.asset_type = ?");
            args.add(type);
        }
        Long total = jdbc.queryForObject("select count(*) from asset a" + where, Long.class, args.toArray());
        List<Object> pageArgs = new ArrayList<>(args);
        pageArgs.add(size);
        pageArgs.add((Math.max(page, 1) - 1) * size);
        List<Map<String, Object>> items = Rows.camel(jdbc.queryForList("""
                        select a.*, d.name as domain_name,
                               (select count(*) from lineage_edge e where e.source_asset_id = a.id) as downstream_count,
                               (select count(*) from lineage_edge e where e.target_asset_id = a.id) as upstream_count
                        from asset a left join asset_domain d on d.id = a.domain_id
                        """ + where + " order by a.updated_at desc nulls last, a.id desc limit ? offset ?",
                pageArgs.toArray()));
        return Map.of("items", items, "total", total == null ? 0 : total, "page", page, "size", size);
    }

    @GetMapping("/assets/{id}")
    public Map<String, Object> detail(@PathVariable long id) {
        Map<String, Object> asset = Rows.camel(jdbc.queryForMap("""
                select a.*, d.name as domain_name,
                       t.table_name, t.schema_name, t.table_comment, t.row_count, t.column_count,
                       s.name as source_name, s.type as source_type
                from asset a
                left join asset_domain d on d.id = a.domain_id
                left join meta_table t on t.id = a.source_table_id
                left join data_source s on s.id = t.source_id
                where a.id = ?
                """, id));
        asset.put("columns", Rows.camel(jdbc.queryForList("""
                select c.*, sm.conform_status, sm.standard_id, ds.name as standard_name, ds.code as standard_code,
                       sp.level_code, sp.desensitize
                from meta_column c
                left join standard_mapping sm on sm.asset_id = ? and sm.column_name = c.column_name
                left join data_standard ds on ds.id = sm.standard_id
                left join security_policy sp on sp.asset_id = ? and sp.column_name = c.column_name
                where c.table_id = (select source_table_id from asset where id = ?)
                order by c.ordinal
                """, id, id, id)));
        asset.put("qualityRules", Rows.camel(jdbc.queryForList("""
                select r.*, (select q.pass_rate from quality_result q where q.rule_id = r.id
                             order by q.run_at desc limit 1) as last_pass_rate,
                       (select q.status from quality_result q where q.rule_id = r.id
                        order by q.run_at desc limit 1) as last_status
                from quality_rule r where r.asset_id = ? order by r.id
                """, id)));
        asset.put("policies", Rows.camel(jdbc.queryForList("""
                select * from security_policy where asset_id = ? order by column_name nulls first
                """, id)));
        Map<String, Object> lineage = new LinkedHashMap<>();
        lineage.put("upstream", Rows.camel(jdbc.queryForList("""
                select e.*, sa.name as source_name, sa.asset_code as source_code
                from lineage_edge e join asset sa on sa.id = e.source_asset_id
                where e.target_asset_id = ? order by e.id
                """, id)));
        lineage.put("downstream", Rows.camel(jdbc.queryForList("""
                select e.*, ta.name as target_name, ta.asset_code as target_code
                from lineage_edge e join asset ta on ta.id = e.target_asset_id
                where e.source_asset_id = ? order by e.id
                """, id)));
        asset.put("lineage", lineage);
        return asset;
    }

    @PostMapping("/assets")
    public Map<String, Object> create(@Valid @RequestBody AssetReq req) {
        String code = req.assetCode();
        if (code == null || code.isBlank()) {
            code = "AST-" + String.format("%04d", jdbc.queryForObject("select count(*) + 1 from asset", Integer.class));
        }
        Long id = jdbc.queryForObject("""
                insert into asset(asset_code, name, domain_id, asset_type, description, owner, department,
                                  security_level, status, tags)
                values (?,?,?,?,?,?,?,?,?,?) returning id
                """, Long.class, code, req.name(), req.domainId(), req.assetType(), req.description(),
                req.owner(), req.department(), req.securityLevel() == null ? "L2" : req.securityLevel(),
                req.status() == null ? "PUBLISHED" : req.status(), req.tags());
        return Map.of("id", id, "assetCode", code);
    }

    @PutMapping("/assets/{id}")
    public Map<String, Object> update(@PathVariable long id, @Valid @RequestBody AssetReq req) {
        jdbc.update("""
                update asset set name = ?, domain_id = ?, asset_type = ?, description = ?, owner = ?,
                       department = ?, security_level = ?, status = ?, tags = ?, updated_at = now()
                where id = ?
                """, req.name(), req.domainId(), req.assetType(), req.description(), req.owner(),
                req.department(), req.securityLevel(), req.status(), req.tags(), id);
        return Map.of("id", id);
    }

    @DeleteMapping("/assets/{id}")
    public Map<String, Object> delete(@PathVariable long id) {
        jdbc.update("delete from lineage_edge where source_asset_id = ? or target_asset_id = ?", id, id);
        jdbc.update("delete from standard_mapping where asset_id = ?", id);
        jdbc.update("delete from quality_rule where asset_id = ?", id);
        jdbc.update("delete from security_policy where asset_id = ?", id);
        jdbc.update("delete from asset where id = ?", id);
        return Map.of("deleted", id);
    }

    @PostMapping("/assets/{id}/favorite")
    public Map<String, Object> favorite(@PathVariable long id) {
        jdbc.update("update asset set favorite = not coalesce(favorite, false) where id = ?", id);
        return Map.of("favorite", jdbc.queryForObject("select favorite from asset where id = ?", Boolean.class, id));
    }

    @PostMapping("/assets/{id}/view")
    public Map<String, Object> view(@PathVariable long id) {
        jdbc.update("update asset set view_count = coalesce(view_count, 0) + 1 where id = ?", id);
        return Map.of("viewCount", jdbc.queryForObject("select view_count from asset where id = ?", Integer.class, id));
    }

    /** 从已采集的元数据表一键登记为资产 */
    @PostMapping("/assets/from-table/{tableId}")
    public Map<String, Object> fromTable(@PathVariable long tableId) {
        Map<String, Object> t = jdbc.queryForMap("select * from meta_table where id = ?", tableId);
        List<Long> exists = jdbc.queryForList("select id from asset where source_table_id = ?", Long.class, tableId);
        if (!exists.isEmpty()) {
            return Map.of("id", exists.get(0), "message", "该表已登记为资产");
        }
        String code = "AST-" + String.format("%04d", jdbc.queryForObject("select count(*) + 1 from asset", Integer.class));
        Long id = jdbc.queryForObject("""
                insert into asset(asset_code, name, domain_id, asset_type, description, owner, department,
                                  security_level, status, source_table_id, tags)
                values (?,?,?,?,?,?,?,?,?,?,?) returning id
                """, Long.class, code,
                String.valueOf(t.get("table_name")),
                1L, "TABLE",
                t.get("table_comment"),
                "数据平台组", "信息中心", "L2", "PUBLISHED", tableId, "系统登记");
        return Map.of("id", id, "assetCode", code, "message", "已登记为资产");
    }

    @GetMapping("/assets/tags")
    public List<String> tags() {
        List<String> tags = new ArrayList<>();
        jdbc.queryForList("select tags from asset where tags is not null and tags <> ''", String.class)
                .forEach(v -> Arrays.stream(v.split("[,，]"))
                        .map(String::trim).filter(s -> !s.isEmpty())
                        .forEach(tags::add));
        return tags.stream().distinct().sorted().toList();
    }
}
