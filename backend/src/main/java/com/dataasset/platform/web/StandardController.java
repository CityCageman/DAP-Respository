package com.dataasset.platform.web;

import com.dataasset.platform.util.Rows;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.util.*;

@RestController
@RequestMapping("/api/standards")
public class StandardController {

    private final JdbcTemplate jdbc;

    public StandardController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record StandardReq(@NotBlank String name, String code, Long categoryId, String stdType,
                              String ruleContent, String exampleValue, String status, String version,
                              String owner, LocalDate effectiveDate) {
    }

    public record MappingReq(Long standardId, Long assetId, String columnName) {
    }

    @GetMapping
    public List<Map<String, Object>> list(@RequestParam(required = false) String keyword,
                                          @RequestParam(required = false) String type,
                                          @RequestParam(required = false) String status) {
        StringBuilder sql = new StringBuilder("""
                select s.*, c.name as category_name,
                       (select count(*) from standard_mapping m where m.standard_id = s.id) as mapping_count,
                       (select count(*) from standard_mapping m where m.standard_id = s.id and m.conform_status = 'CONFORM') as conform_count
                from data_standard s left join standard_category c on c.id = s.category_id
                where 1 = 1
                """);
        List<Object> args = new ArrayList<>();
        if (keyword != null && !keyword.isBlank()) {
            sql.append(" and (s.name ilike ? or s.code ilike ? or s.rule_content ilike ?)");
            for (int i = 0; i < 3; i++) {
                args.add("%" + keyword + "%");
            }
        }
        if (type != null && !type.isBlank()) {
            sql.append(" and s.std_type = ?");
            args.add(type);
        }
        if (status != null && !status.isBlank()) {
            sql.append(" and s.status = ?");
            args.add(status);
        }
        sql.append(" order by s.id desc");
        return Rows.camel(jdbc.queryForList(sql.toString(), args.toArray()));
    }

    @GetMapping("/categories")
    public List<Map<String, Object>> categories() {
        return Rows.camel(jdbc.queryForList("select * from standard_category order by id"));
    }

    @PostMapping
    public Map<String, Object> create(@Valid @RequestBody StandardReq req) {
        String code = req.code() == null || req.code().isBlank()
                ? "STD-" + String.format("%03d", jdbc.queryForObject("select count(*) + 1 from data_standard", Integer.class))
                : req.code();
        Long id = jdbc.queryForObject("""
                insert into data_standard(code, name, category_id, std_type, rule_content, example_value,
                                          status, version, owner, effective_date)
                values (?,?,?,?,?,?,?,?,?,?) returning id
                """, Long.class, code, req.name(), req.categoryId(), req.stdType(), req.ruleContent(),
                req.exampleValue(), req.status() == null ? "ACTIVE" : req.status(),
                req.version() == null ? "v1.0" : req.version(), req.owner(), req.effectiveDate());
        return Map.of("id", id, "code", code);
    }

    @PutMapping("/{id}")
    public Map<String, Object> update(@PathVariable long id, @Valid @RequestBody StandardReq req) {
        jdbc.update("""
                update data_standard set name = ?, category_id = ?, std_type = ?, rule_content = ?,
                       example_value = ?, status = ?, version = ?, owner = ?, effective_date = ?
                where id = ?
                """, req.name(), req.categoryId(), req.stdType(), req.ruleContent(), req.exampleValue(),
                req.status(), req.version(), req.owner(), req.effectiveDate(), id);
        return Map.of("id", id);
    }

    @DeleteMapping("/{id}")
    public Map<String, Object> delete(@PathVariable long id) {
        jdbc.update("delete from standard_mapping where standard_id = ?", id);
        jdbc.update("delete from data_standard where id = ?", id);
        return Map.of("deleted", id);
    }

    @GetMapping("/{id}/mappings")
    public List<Map<String, Object>> mappings(@PathVariable long id) {
        return Rows.camel(jdbc.queryForList("""
                select m.*, a.name as asset_name, a.asset_code
                from standard_mapping m join asset a on a.id = m.asset_id
                where m.standard_id = ?
                """, id));
    }

    @PostMapping("/mappings")
    public Map<String, Object> bind(@RequestBody MappingReq req) {
        Long id = jdbc.queryForObject("""
                insert into standard_mapping(standard_id, asset_id, column_name, conform_status)
                values (?,?,?, 'UNMAPPED') returning id
                """, Long.class, req.standardId(), req.assetId(), req.columnName());
        return Map.of("id", id);
    }

    @DeleteMapping("/mappings/{id}")
    public Map<String, Object> unbind(@PathVariable long id) {
        jdbc.update("delete from standard_mapping where id = ?", id);
        return Map.of("deleted", id);
    }

    /** 符合性概览：受检字段里符合 / 偏差 / 未映射各多少 */
    @GetMapping("/conformance")
    public Map<String, Object> conformance() {
        Map<String, Object> out = new LinkedHashMap<>();
        List<Map<String, Object>> rows = Rows.camel(jdbc.queryForList("""
                select conform_status, count(*) as cnt from standard_mapping group by conform_status
                """));
        long conform = 0, deviate = 0, unmapped = 0;
        for (Map<String, Object> r : rows) {
            long c = ((Number) r.get("cnt")).longValue();
            switch (String.valueOf(r.get("conformStatus"))) {
                case "CONFORM" -> conform += c;
                case "DEVIATE" -> deviate += c;
                default -> unmapped += c;
            }
        }
        long total = conform + deviate + unmapped;
        out.put("conform", conform);
        out.put("deviate", deviate);
        out.put("unmapped", unmapped);
        out.put("total", total);
        out.put("conformRate", total == 0 ? 0 : Math.round(conform * 1000.0 / total) / 10.0);
        out.put("byStandard", Rows.camel(jdbc.queryForList("""
                select s.id, s.code, s.name,
                       count(m.id) as mapped,
                       count(*) filter (where m.conform_status = 'CONFORM') as conform,
                       count(*) filter (where m.conform_status = 'DEVIATE') as deviate
                from data_standard s left join standard_mapping m on m.standard_id = s.id
                group by s.id, s.code, s.name order by mapped desc
                """)));
        return out;
    }

    // =================================================================
    // 标准码表（代码集）与代码对照
    // 码表回答"标准是什么"，代码对照回答"源系统的哪个值等于标准里的哪个值"。
    // 对照规则归治理域持有，中台经 /openapi/standards/codes 只读拉取后镜像执行。
    // =================================================================

    /** 码表清单：带标准出处、码值数、对照条数、已被覆盖的标准码值数 */
    @GetMapping("/code-tables")
    public List<Map<String, Object>> codeTables(@RequestParam(required = false) String keyword) {
        StringBuilder sql = new StringBuilder("""
                select t.id, t.code_table_code, t.code_table_name, t.code_table_type,
                       t.description, t.status,
                       t.standard_source, t.standard_id, t.standard_name, t.standard_version,
                       (select count(*) from dam_standard.standard_code_value v
                         where v.code_table_id = t.id and v.deleted_at is null) as value_count,
                       (select count(*) from dam_standard.standard_code_value v
                         where v.code_table_id = t.id and v.deleted_at is null
                           and v.is_extension = 1) as extension_value_count,
                       (select count(*) from dam_standard.code_crosswalk c
                         where c.code_table_id = t.id and c.deleted_at is null) as crosswalk_count,
                       (select count(distinct c.source_system) from dam_standard.code_crosswalk c
                         where c.code_table_id = t.id and c.deleted_at is null) as source_count,
                       (select count(distinct v.code_value) from dam_standard.standard_code_value v
                         where v.code_table_id = t.id and v.deleted_at is null
                           and exists (select 1 from dam_standard.code_crosswalk c2
                                        where c2.code_table_id = t.id and c2.deleted_at is null
                                          and c2.target_value = v.code_value)) as covered_value_count
                from dam_standard.standard_code_table t
                where t.deleted_at is null
                """);
        List<Object> args = new ArrayList<>();
        if (keyword != null && !keyword.isBlank()) {
            sql.append(" and (t.code_table_code ilike ? or t.code_table_name ilike ?"
                    + " or t.standard_id ilike ?)");
            for (int i = 0; i < 3; i++) {
                args.add("%" + keyword + "%");
            }
        }
        sql.append(" order by case t.standard_source when 'GB' then 1 when 'WS' then 2"
                + " when 'NHC' then 3 else 9 end, t.code_table_code");
        return Rows.camel(jdbc.queryForList(sql.toString(), args.toArray()));
    }

    /** 某张码表下的标准码值 */
    @GetMapping("/code-tables/{id}/values")
    public List<Map<String, Object>> codeValues(@PathVariable long id) {
        return Rows.camel(jdbc.queryForList("""
                select v.id, v.code_value, v.code_name, v.parent_code_id, v.description,
                       v.sort_order, v.status, v.is_extension
                from dam_standard.standard_code_value v
                where v.code_table_id = ? and v.deleted_at is null
                order by v.sort_order nulls last, v.code_value
                """, id));
    }

    /** 代码对照清单 */
    @GetMapping("/crosswalk")
    public List<Map<String, Object>> crosswalk(@RequestParam(required = false) Long codeTableId,
                                               @RequestParam(required = false) String sourceSystem,
                                               @RequestParam(required = false) String keyword) {
        StringBuilder sql = new StringBuilder("""
                select c.id, c.code_table_id, c.code_table_code, c.code_table_name,
                       c.source_system, c.source_table, c.source_column,
                       c.source_value, c.source_name,
                       c.target_value, c.target_name, c.priority, c.remark, c.status, c.updated_at
                from dam_standard.code_crosswalk c
                where c.deleted_at is null
                """);
        List<Object> args = new ArrayList<>();
        if (codeTableId != null) {
            sql.append(" and c.code_table_id = ?");
            args.add(codeTableId);
        }
        if (sourceSystem != null && !sourceSystem.isBlank()) {
            sql.append(" and c.source_system = ?");
            args.add(sourceSystem);
        }
        if (keyword != null && !keyword.isBlank()) {
            sql.append(" and (c.code_table_code ilike ? or c.code_table_name ilike ?"
                    + " or c.source_value ilike ? or c.source_name ilike ?)");
            for (int i = 0; i < 4; i++) {
                args.add("%" + keyword + "%");
            }
        }
        sql.append(" order by c.code_table_code, c.source_system, c.priority, c.source_value");
        return Rows.camel(jdbc.queryForList(sql.toString(), args.toArray()));
    }

    /** 对照表里已出现的源系统 */
    @GetMapping("/crosswalk/sources")
    public List<String> crosswalkSources() {
        return jdbc.queryForList("""
                select distinct source_system from dam_standard.code_crosswalk
                where deleted_at is null order by 1
                """, String.class);
    }

    public record CrosswalkReq(Long codeTableId, @NotBlank String sourceSystem,
                               String sourceTable, String sourceColumn, @NotBlank String sourceValue,
                               String sourceName, @NotBlank String targetValue, Integer priority,
                               String remark, Integer status) {
    }

    @PostMapping("/crosswalk")
    public Map<String, Object> createCrosswalk(@Valid @RequestBody CrosswalkReq req) {
        Map<String, Object> t = requireCodeTable(req.codeTableId());
        requireTargetValue(req.codeTableId(), req.targetValue());
        Long id = jdbc.queryForObject("""
                insert into dam_standard.code_crosswalk(code_table_id, code_table_code, code_table_name,
                                               source_system, source_table, source_column,
                                               source_value, source_name,
                                               target_value, target_name, priority, remark, status)
                values (?,?,?,?,?,?,?,?,?,?,?,?,?) returning id
                """, Long.class, req.codeTableId(), t.get("codeTableCode"), t.get("codeTableName"),
                req.sourceSystem(), req.sourceTable(), req.sourceColumn(),
                req.sourceValue(), req.sourceName(),
                req.targetValue(), standardName(req.codeTableId(), req.targetValue()),
                req.priority() == null ? 100 : req.priority(), req.remark(),
                req.status() == null ? 1 : req.status());
        return Map.of("id", id);
    }

    @PutMapping("/crosswalk/{id}")
    public Map<String, Object> updateCrosswalk(@PathVariable long id, @Valid @RequestBody CrosswalkReq req) {
        Map<String, Object> t = requireCodeTable(req.codeTableId());
        requireTargetValue(req.codeTableId(), req.targetValue());
        jdbc.update("""
                update dam_standard.code_crosswalk
                   set code_table_id = ?, code_table_code = ?, code_table_name = ?,
                       source_system = ?, source_table = ?, source_column = ?,
                       source_value = ?, source_name = ?,
                       target_value = ?, target_name = ?, priority = ?, remark = ?, status = ?,
                       updated_at = now()
                 where id = ?
                """, req.codeTableId(), t.get("codeTableCode"), t.get("codeTableName"),
                req.sourceSystem(), req.sourceTable(), req.sourceColumn(),
                req.sourceValue(), req.sourceName(),
                req.targetValue(), standardName(req.codeTableId(), req.targetValue()),
                req.priority() == null ? 100 : req.priority(), req.remark(),
                req.status() == null ? 1 : req.status(), id);
        return Map.of("id", id);
    }

    /** 逻辑删除：保留痕迹，同时释放唯一键约束以便重新配置 */
    @DeleteMapping("/crosswalk/{id}")
    public Map<String, Object> deleteCrosswalk(@PathVariable long id) {
        jdbc.update("update dam_standard.code_crosswalk set deleted_at = now(), status = 0 where id = ?", id);
        return Map.of("deleted", id);
    }

    private Map<String, Object> requireCodeTable(Long codeTableId) {
        if (codeTableId == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "codeTableId 不能为空");
        }
        List<Map<String, Object>> rows = Rows.camel(jdbc.queryForList("""
                select id, code_table_code, code_table_name
                from dam_standard.standard_code_table where id = ? and deleted_at is null
                """, codeTableId));
        if (rows.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "标准码表不存在：" + codeTableId);
        }
        return rows.get(0);
    }

    private void requireTargetValue(Long codeTableId, String targetValue) {
        Integer n = jdbc.queryForObject("""
                select count(*) from dam_standard.standard_code_value
                where code_table_id = ? and code_value = ? and deleted_at is null
                """, Integer.class, codeTableId, targetValue);
        if (n == null || n == 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "目标码值 " + targetValue + " 不在该码表的标准码值中，请先在码表里补该码值");
        }
    }

    private String standardName(Long codeTableId, String targetValue) {
        List<String> n = jdbc.queryForList("""
                select code_name from dam_standard.standard_code_value
                where code_table_id = ? and code_value = ? and deleted_at is null
                """, String.class, codeTableId, targetValue);
        return n.isEmpty() ? null : n.get(0);
    }
}
