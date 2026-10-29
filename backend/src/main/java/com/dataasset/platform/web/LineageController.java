package com.dataasset.platform.web;

import com.dataasset.platform.util.Rows;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/lineage")
public class LineageController {

    private final JdbcTemplate jdbc;

    public LineageController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record EdgeReq(@NotNull Long sourceAssetId, Long targetAssetId, String sourceColumn,
                          String targetColumn, String level, String jobName, String transformType,
                          String sqlText) {
    }

    /**
     * 以某个资产为中心，向上游/下游各扩散 depth 层，返回节点与边。
     */
    @GetMapping("/graph")
    public Map<String, Object> graph(@RequestParam long assetId, @RequestParam(defaultValue = "2") int depth) {
        Set<Long> nodeIds = new LinkedHashSet<>();
        nodeIds.add(assetId);
        Set<Long> frontier = new LinkedHashSet<>(nodeIds);
        List<Map<String, Object>> edges = new ArrayList<>();
        Set<Long> edgeIds = new HashSet<>();

        for (int d = 0; d < depth && !frontier.isEmpty(); d++) {
            List<Object> args = new ArrayList<>(frontier);
            String in = String.join(",", Collections.nCopies(frontier.size(), "?"));
            List<Map<String, Object>> found = jdbc.queryForList("""
                    select * from lineage_edge
                    where source_asset_id in (%s) or target_asset_id in (%s)
                    """.formatted(in, in), concat(args, args).toArray());
            Set<Long> next = new LinkedHashSet<>();
            for (Map<String, Object> e : found) {
                long sid = ((Number) e.get("source_asset_id")).longValue();
                long tid = ((Number) e.get("target_asset_id")).longValue();
                if (edgeIds.add(((Number) e.get("id")).longValue())) {
                    edges.add(e);
                }
                for (long x : new long[]{sid, tid}) {
                    if (nodeIds.add(x)) {
                        next.add(x);
                    }
                }
            }
            frontier = next;
        }

        List<Map<String, Object>> nodes = nodeIds.isEmpty() ? List.of()
                : Rows.camel(jdbc.queryForList("""
                select a.id, a.asset_code, a.name, a.asset_type, a.security_level, d.name as domain_name
                from asset a left join asset_domain d on d.id = a.domain_id
                where a.id in (%s)
                """.formatted(String.join(",", Collections.nCopies(nodeIds.size(), "?"))), nodeIds.toArray()));

        return Map.of(
                "nodes", nodes,
                "edges", Rows.camel(edges),
                "centerId", assetId
        );
    }

    @GetMapping("/edges")
    public List<Map<String, Object>> edges(@RequestParam(required = false) Long assetId) {
        String sql = """
                select e.*, sa.name as source_name, sa.asset_code as source_code,
                       ta.name as target_name, ta.asset_code as target_code
                from lineage_edge e
                join asset sa on sa.id = e.source_asset_id
                join asset ta on ta.id = e.target_asset_id
                """;
        if (assetId == null) {
            return Rows.camel(jdbc.queryForList(sql + " order by e.id"));
        }
        return Rows.camel(jdbc.queryForList(sql + " where e.source_asset_id = ? or e.target_asset_id = ? order by e.id",
                assetId, assetId));
    }

    @PostMapping("/edges")
    public Map<String, Object> create(@Valid @RequestBody EdgeReq req) {
        Long id = jdbc.queryForObject("""
                insert into lineage_edge(source_asset_id, source_column, target_asset_id, target_column,
                                         level, job_name, transform_type, sql_text)
                values (?,?,?,?,?,?,?,?) returning id
                """, Long.class, req.sourceAssetId(), req.sourceColumn(), req.targetAssetId(), req.targetColumn(),
                req.level() == null ? "TABLE" : req.level(), req.jobName(), req.transformType(), req.sqlText());
        return Map.of("id", id);
    }

    @DeleteMapping("/edges/{id}")
    public Map<String, Object> delete(@PathVariable long id) {
        jdbc.update("delete from lineage_edge where id = ?", id);
        return Map.of("deleted", id);
    }

    /** 字段级血缘：某资产某个字段的上下游 */
    @GetMapping("/columns")
    public Map<String, Object> columnLineage(@RequestParam long assetId, @RequestParam String column) {
        List<Map<String, Object>> up = Rows.camel(jdbc.queryForList("""
                select e.*, sa.name as source_name, sa.asset_code as source_code
                from lineage_edge e join asset sa on sa.id = e.source_asset_id
                where e.target_asset_id = ? and (e.target_column = ? or e.target_column is null)
                """, assetId, column));
        List<Map<String, Object>> down = Rows.camel(jdbc.queryForList("""
                select e.*, ta.name as target_name, ta.asset_code as target_code
                from lineage_edge e join asset ta on ta.id = e.target_asset_id
                where e.source_asset_id = ? and (e.source_column = ? or e.source_column is null)
                """, assetId, column));
        return Map.of("upstream", up, "downstream", down);
    }

    private static List<Object> concat(List<Object> a, List<Object> b) {
        List<Object> out = new ArrayList<>(a);
        out.addAll(b);
        return out;
    }
}
