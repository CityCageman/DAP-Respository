package com.dataasset.platform.web;

import com.dataasset.platform.util.Rows;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.*;

/**
 * 标准码表与代码对照的下发接口：供数据中台只读拉取。
 *
 * 为什么方向是"治理下发、中台拉取"：
 * 码表与对照规则是治理资产（标准定义 + 跨源系统裁决），单一真相源必须在治理侧；
 * 中台只在加工时消费，落本地镜像 mid.code_crosswalk，保证治理不可达时采集与加工仍可运行。
 *
 * 认证：请求头 X-OpenAPI-Token，值等于 openapi.mid-token，不走登录态。
 */
@RestController
@RequestMapping("/openapi/standards")
public class StandardsOpenApiController {

    private final JdbcTemplate jdbc;

    @Value("${openapi.mid-token}")
    private String midToken;

    public StandardsOpenApiController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private void check(String given) {
        if (given == null || !given.equals(midToken)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "OpenAPI token 无效");
        }
    }

    /**
     * 一次性下发码表 + 码值 + 代码对照。
     * sourceSystem 为空时返回全部源系统的对照；中台按需传自己的系统代号可减小报文。
     */
    @GetMapping("/codes")
    public Map<String, Object> codes(@RequestHeader(name = "X-OpenAPI-Token", required = false) String token,
                                     @RequestParam(required = false) String sourceSystem) {
        check(token);

        List<Map<String, Object>> tables = Rows.camel(jdbc.queryForList("""
                select id, code_table_code, code_table_name, code_table_type, description,
                       standard_source, standard_id, standard_name, standard_version
                from dam_standard.standard_code_table
                where deleted_at is null and status = 1
                order by code_table_code
                """));

        List<Map<String, Object>> values = Rows.camel(jdbc.queryForList("""
                select code_table_id, code_value, code_name, sort_order, description, is_extension
                from dam_standard.standard_code_value
                where deleted_at is null and status = 1
                order by code_table_id, sort_order nulls last, code_value
                """));

        StringBuilder cwSql = new StringBuilder("""
                select code_table_id, code_table_code, code_table_name,
                       source_system, source_table, source_column,
                       source_value, source_name,
                       target_value, target_name, priority
                from dam_standard.code_crosswalk
                where deleted_at is null and status = 1
                """);
        List<Object> cwArgs = new ArrayList<>();
        if (sourceSystem != null && !sourceSystem.isBlank()) {
            cwSql.append(" and source_system = ?");
            cwArgs.add(sourceSystem);
        }
        cwSql.append(" order by code_table_id, source_system, priority, source_value");
        List<Map<String, Object>> crosswalk = Rows.camel(jdbc.queryForList(cwSql.toString(), cwArgs.toArray()));

        Map<String, List<Map<String, Object>>> valByTable = new HashMap<>();
        for (Map<String, Object> v : values) {
            String key = keyOf(v.get("codeTableId"));
            v.remove("codeTableId");
            valByTable.computeIfAbsent(key, k -> new ArrayList<>()).add(v);
        }
        Map<String, List<Map<String, Object>>> cwByTable = new HashMap<>();
        for (Map<String, Object> c : crosswalk) {
            String key = keyOf(c.get("codeTableId"));
            c.remove("codeTableId");
            cwByTable.computeIfAbsent(key, k -> new ArrayList<>()).add(c);
        }

        List<Map<String, Object>> out = new ArrayList<>(tables.size());
        for (Map<String, Object> t : tables) {
            String key = keyOf(t.get("id"));
            Map<String, Object> one = new LinkedHashMap<>(t);
            one.remove("id");
            one.put("values", valByTable.getOrDefault(key, List.of()));
            one.put("crosswalk", cwByTable.getOrDefault(key, List.of()));
            out.add(one);
        }

        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("codeTableCount", tables.size());
        stats.put("codeValueCount", values.size());
        stats.put("crosswalkCount", crosswalk.size());
        // 国标覆盖：多少张码表有 GB/WS/NHC 级依据，多少条码值是标准里没有的院内扩展
        long standardTables = tables.stream()
                .filter(t -> t.get("standardSource") != null
                        && !"LOCAL".equals(String.valueOf(t.get("standardSource"))))
                .count();
        long extensionValues = values.stream()
                .filter(v -> v.get("isExtension") != null && ((Number) v.get("isExtension")).intValue() == 1)
                .count();
        stats.put("standardTableCount", standardTables);
        stats.put("localExtensionValueCount", extensionValues);

        Map<String, Object> resp = new LinkedHashMap<>();
        resp.put("generatedAt", LocalDateTime.now().toString());
        resp.put("sourceSystem", sourceSystem == null ? "*" : sourceSystem);
        resp.put("stats", stats);
        resp.put("codeTables", out);
        return resp;
    }

    /** 只要对照清单（扁平），便于中台增量刷新 */
    @GetMapping("/crosswalk")
    public List<Map<String, Object>> crosswalk(@RequestHeader(name = "X-OpenAPI-Token", required = false) String token,
                                               @RequestParam(required = false) String sourceSystem) {
        check(token);
        StringBuilder sql = new StringBuilder("""
                select code_table_code, code_table_name, source_system,
                       source_table, source_column,
                       source_value, source_name, target_value, target_name, priority
                from dam_standard.code_crosswalk
                where deleted_at is null and status = 1
                """);
        List<Object> args = new ArrayList<>();
        if (sourceSystem != null && !sourceSystem.isBlank()) {
            sql.append(" and source_system = ?");
            args.add(sourceSystem);
        }
        sql.append(" order by code_table_code, source_system, priority, source_value");
        return Rows.camel(jdbc.queryForList(sql.toString(), args.toArray()));
    }

    /** 探活 */
    @GetMapping
    public Map<String, Object> root(@RequestHeader(name = "X-OpenAPI-Token", required = false) String token) {
        check(token);
        return Map.of("service", "data-asset-platform /openapi/standards",
                "endpoints", List.of("GET /openapi/standards/codes", "GET /openapi/standards/crosswalk"));
    }

    /** code_table_id 在 standard_code_value 是 integer、在 standard_code_table 是 bigint，统一取字符串键 */
    private static String keyOf(Object id) {
        return id == null ? "" : String.valueOf(id);
    }
}
