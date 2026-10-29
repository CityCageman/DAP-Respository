package com.dataasset.platform.web;

import com.dataasset.platform.util.Rows;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 数据血缘（阶段 B）：dam_metadata.metadata_lineage 通用节点对查询。
 * 返回力导向图所需 nodes/edges；节点类型 TABLE / CODE_TABLE / MODEL_FACT / MODEL_DIMENSION。
 */
@RestController
@RequestMapping("/api/v2/lineage")
public class LineageV2Controller {

    private final JdbcTemplate jdbc;

    public LineageV2Controller(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * 血缘图。
     * @param tableId 可选，以某元数据表为中心展开
     * @param depth   展开层数（默认 2，无 tableId 时忽略）
     * @param direction 可选 UP/DOWN/BOTH（默认 BOTH）
     */
    @GetMapping("/graph")
    public Map<String, Object> graph(@RequestParam(required = false) Long tableId,
                                     @RequestParam(defaultValue = "2") int depth,
                                     @RequestParam(defaultValue = "BOTH") String direction) {
        List<Map<String, Object>> allEdges = Rows.camel(jdbc.queryForList("""
                select id, source_type, source_id, target_type, target_id, relation_type,
                       transform_rule, dependency_level, source_system, discovered_by
                from dam_metadata.metadata_lineage
                where deleted_at is null
                order by id
                """));

        List<Map<String, Object>> selected = new ArrayList<>();
        if (tableId == null) {
            selected = allEdges;
        } else {
            // BFS 沿边双向（或指定方向）展开 depth 层
            boolean up = !"DOWN".equalsIgnoreCase(direction);
            boolean down = !"UP".equalsIgnoreCase(direction);
            Set<String> visited = new LinkedHashSet<>();
            visited.add("TABLE:" + tableId);
            for (int level = 0; level < Math.max(depth, 1); level++) {
                Set<String> next = new LinkedHashSet<>();
                List<Map<String, Object>> levelEdges = new ArrayList<>();
                for (Map<String, Object> e : allEdges) {
                    String s = nodeKey(String.valueOf(e.get("sourceType")), e.get("sourceId"));
                    String t = nodeKey(String.valueOf(e.get("targetType")), e.get("targetId"));
                    boolean sIn = visited.contains(s);
                    boolean tIn = visited.contains(t);
                    if (sIn == tIn) {
                        continue; // 两端都在或都不在，本层不扩展
                    }
                    if (sIn && down && !visited.contains(t)) {
                        next.add(t);
                        levelEdges.add(e);
                    } else if (tIn && up && !visited.contains(s)) {
                        next.add(s);
                        levelEdges.add(e);
                    }
                }
                selected.addAll(levelEdges);
                visited.addAll(next);
            }
        }

        // 解析节点标签
        Map<String, Map<String, Object>> nodes = new LinkedHashMap<>();
        Map<String, List<Long>> tableIds = new HashMap<>();
        for (Map<String, Object> e : selected) {
            collectNode(nodes, tableIds, String.valueOf(e.get("sourceType")), e.get("sourceId"));
            collectNode(nodes, tableIds, String.valueOf(e.get("targetType")), e.get("targetId"));
        }
        if (!tableIds.isEmpty()) {
            tableIds.forEach((type, ids) -> resolveLabels(nodes, type, ids));
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("nodes", new ArrayList<>(nodes.values()));
        List<Map<String, Object>> edges = new ArrayList<>(selected.size());
        for (Map<String, Object> e : selected) {
            Map<String, Object> edge = new LinkedHashMap<>();
            edge.put("source", nodeKey(String.valueOf(e.get("sourceType")), e.get("sourceId")));
            edge.put("target", nodeKey(String.valueOf(e.get("targetType")), e.get("targetId")));
            edge.put("relationType", e.get("relationType"));
            edge.put("transformRule", e.get("transformRule"));
            edge.put("dependencyLevel", e.get("dependencyLevel"));
            edge.put("sourceSystem", e.get("sourceSystem"));
            edges.add(edge);
        }
        out.put("edges", edges);
        return out;
    }

    private static String nodeKey(String type, Object id) {
        return type + ":" + id;
    }

    private void collectNode(Map<String, Map<String, Object>> nodes, Map<String, List<Long>> tableIds,
                             String type, Object id) {
        String key = nodeKey(type, id);
        nodes.computeIfAbsent(key, k -> {
            Map<String, Object> n = new LinkedHashMap<>();
            n.put("key", k);
            n.put("type", type);
            n.put("id", ((Number) id).longValue());
            n.put("name", String.valueOf(id));
            return n;
        });
        tableIds.computeIfAbsent(type, k -> new ArrayList<>()).add(((Number) id).longValue());
    }

    /** 按节点类型批量解析名称 */
    private void resolveLabels(Map<String, Map<String, Object>> nodes, String type, List<Long> ids) {
        String in = joinIds(ids);
        List<Map<String, Object>> rows;
        switch (type) {
            case "TABLE" -> rows = jdbc.queryForList("""
                    select t.id, t.table_name, t.table_comment, d.ds_name
                    from dam_metadata.metadata_table t join dam_metadata.metadata_datasource d on d.id = t.datasource_id
                    where t.id in (%s)
                    """.formatted(in));
            case "CODE_TABLE" -> rows = jdbc.queryForList("""
                    select id, code_table_code, code_table_name from dam_standard.standard_code_table
                    where id in (%s)
                    """.formatted(in));
            case "MODEL_FACT" -> rows = jdbc.queryForList(
                    "select id, fact_code, fact_name from dam_model.model_fact where id in (%s)".formatted(in));
            case "MODEL_DIMENSION" -> rows = jdbc.queryForList(
                    "select id, dimension_code, dimension_name from dam_model.model_dimension where id in (%s)".formatted(in));
            default -> {
                return;
            }
        }
        for (Map<String, Object> r : rows) {
            String key = nodeKey(type, r.get("id"));
            Map<String, Object> node = nodes.get(key);
            if (node == null) {
                continue;
            }
            String name = switch (type) {
                case "TABLE" -> String.valueOf(r.get("table_name"));
                case "CODE_TABLE" -> String.valueOf(r.get("code_table_name"));
                case "MODEL_FACT" -> String.valueOf(r.get("fact_name"));
                case "MODEL_DIMENSION" -> String.valueOf(r.get("dimension_name"));
                default -> String.valueOf(r.get("id"));
            };
            node.put("name", name);
            if (r.containsKey("table_comment") && r.get("table_comment") != null) {
                node.put("comment", r.get("table_comment"));
            }
            if (r.containsKey("ds_name") && r.get("ds_name") != null) {
                node.put("datasource", r.get("ds_name"));
            }
        }
    }

    private static String joinIds(List<Long> ids) {
        Set<Long> uniq = new LinkedHashSet<>(ids);
        StringBuilder sb = new StringBuilder();
        for (Long id : uniq) {
            if (sb.length() > 0) {
                sb.append(',');
            }
            sb.append(id);
        }
        return sb.length() == 0 ? "-1" : sb.toString();
    }
}
