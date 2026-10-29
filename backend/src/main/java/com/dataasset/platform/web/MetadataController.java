package com.dataasset.platform.web;

import com.dataasset.platform.util.Rows;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/metadata")
public class MetadataController {

    private final JdbcTemplate jdbc;

    public MetadataController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/tables")
    public List<Map<String, Object>> tables(@RequestParam(required = false) Long sourceId,
                                            @RequestParam(required = false) String keyword) {
        StringBuilder sql = new StringBuilder("""
                select t.id, t.source_id, s.name as source_name, s.type as source_type,
                       t.schema_name, t.table_name, t.table_comment, t.row_count, t.column_count,
                       t.owner, t.collected_at,
                       (select count(*) from asset a where a.source_table_id = t.id) as asset_count
                from meta_table t join data_source s on s.id = t.source_id
                where 1 = 1
                """);
        List<Object> args = new ArrayList<>();
        if (sourceId != null) {
            sql.append(" and t.source_id = ?");
            args.add(sourceId);
        }
        if (keyword != null && !keyword.isBlank()) {
            sql.append(" and (t.table_name ilike ? or t.table_comment ilike ?)");
            args.add("%" + keyword + "%");
            args.add("%" + keyword + "%");
        }
        sql.append(" order by t.source_id, t.table_name");
        return Rows.camel(jdbc.queryForList(sql.toString(), args.toArray()));
    }

    @GetMapping("/tables/{id}")
    public Map<String, Object> detail(@PathVariable long id) {
        Map<String, Object> table = Rows.camel(jdbc.queryForMap("""
                select t.*, s.name as source_name, s.type as source_type, s.host, s.db_name
                from meta_table t join data_source s on s.id = t.source_id where t.id = ?
                """, id));
        List<Map<String, Object>> columns = Rows.camel(jdbc.queryForList("""
                select * from meta_column where table_id = ? order by ordinal
                """, id));
        table.put("columns", columns);
        return table;
    }

    @GetMapping("/stats")
    public Map<String, Object> stats() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("sourceCount", jdbc.queryForObject("select count(*) from data_source", Long.class));
        out.put("tableCount", jdbc.queryForObject("select count(*) from meta_table", Long.class));
        out.put("columnCount", jdbc.queryForObject("select count(*) from meta_column", Long.class));
        out.put("bySource", Rows.camel(jdbc.queryForList("""
                select s.id, s.name, s.type, count(t.id) as table_count, coalesce(sum(t.row_count), 0) as row_total
                from data_source s left join meta_table t on t.source_id = s.id
                group by s.id, s.name, s.type order by s.id
                """)));
        return out;
    }

    public record CommentReq(String comment) {
    }

    /** 编辑表中文描述（人工修正优先级最高，AI 补全只填空不会覆盖人工注释） */
    @PutMapping("/tables/{id}/comment")
    public Map<String, Object> updateTableComment(@PathVariable long id, @RequestBody CommentReq req) {
        int n = jdbc.update("update meta_table set table_comment = ? where id = ?",
                req.comment() == null ? "" : req.comment().trim(), id);
        if (n == 0) {
            throw new IllegalArgumentException("表不存在: " + id);
        }
        return Map.of("updated", id);
    }

    /** 编辑字段中文注释 */
    @PutMapping("/columns/{id}/comment")
    public Map<String, Object> updateColumnComment(@PathVariable long id, @RequestBody CommentReq req) {
        int n = jdbc.update("update meta_column set column_comment = ? where id = ?",
                req.comment() == null ? "" : req.comment().trim(), id);
        if (n == 0) {
            throw new IllegalArgumentException("字段不存在: " + id);
        }
        return Map.of("updated", id);
    }
}
