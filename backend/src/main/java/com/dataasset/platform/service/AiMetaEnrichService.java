package com.dataasset.platform.service;

import com.dataasset.platform.config.AiProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * AI 元数据增强：识别表/字段的业务含义，生成中文表描述与字段注释，回写 meta_table / meta_column。
 * 两种模式：仅补空（默认，不覆盖人工/采集到的已有注释）、覆盖模式。
 * 元数据同步成功后若 ai.enrich-on-sync=true 自动触发；也可从页面按数据源手动触发。
 */
@Service
public class AiMetaEnrichService {

    private static final Logger log = LoggerFactory.getLogger(AiMetaEnrichService.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final JdbcTemplate jdbc;
    private final AiChatClient ai;
    private final AiProperties props;

    public AiMetaEnrichService(JdbcTemplate jdbc, AiChatClient ai, AiProperties props) {
        this.jdbc = jdbc;
        this.ai = ai;
        this.props = props;
    }

    public record EnrichResult(int tablesEnriched, int columnsEnriched, int skipped, List<String> warnings) {
    }

    /**
     * @param overwrite true=覆盖已有注释；false=只补空
     * @param limit     最多处理的表数，空则不限制
     */
    public EnrichResult enrich(long sourceId, boolean overwrite, Integer limit) {
        String where = overwrite ? "" : " and coalesce(table_comment, '') = '' ";
        String limitSql = limit != null && limit > 0 ? " limit " + Math.min(limit, 200) : "";
        List<Map<String, Object>> tables = jdbc.queryForList("""
                select id, table_name, coalesce(table_comment, '') as table_comment
                from meta_table where source_id = ?""" + where + " order by id" + limitSql, sourceId);
        if (tables.isEmpty()) {
            return new EnrichResult(0, 0, 0, List.of("没有需要补全的表（注释已齐全）"));
        }

        // 字段：覆盖模式取该表的全部字段，补空模式只取空注释字段
        Map<Long, List<Map<String, Object>>> colsByTable = new HashMap<>();
        if (overwrite) {
            jdbc.queryForList("""
                    select id, table_id, column_name, data_type, coalesce(column_comment, '') as column_comment
                    from meta_column where table_id in (select id from meta_table where source_id = ?)
                    order by table_id, ordinal
                    """, sourceId).forEach(r ->
                    colsByTable.computeIfAbsent(((Number) r.get("table_id")).longValue(), k -> new ArrayList<>()).add(r));
        } else {
            jdbc.queryForList("""
                    select c.id, c.table_id, c.column_name, c.data_type, coalesce(c.column_comment, '') as column_comment
                    from meta_column c join meta_table t on t.id = c.table_id
                    where t.source_id = ? and coalesce(c.column_comment, '') = ''
                    order by c.table_id, c.ordinal
                    """, sourceId).forEach(r ->
                    colsByTable.computeIfAbsent(((Number) r.get("table_id")).longValue(), k -> new ArrayList<>()).add(r));
        }

        int batch = Math.max(props.getMaxTablesPerBatch(), 4);
        int tablesEnriched = 0;
        int columnsEnriched = 0;
        int skipped = 0;
        List<String> warnings = new ArrayList<>();
        List<List<Map<String, Object>>> batches = partition(tables, batch);

        int bi = 0;
        for (List<Map<String, Object>> part : batches) {
            bi++;
            try {
                String raw = ai.chat(SYSTEM_PROMPT, buildPrompt(part, colsByTable, overwrite));
                JsonNode root = MAPPER.readTree(AiChatClient.extractJson(raw));
                for (JsonNode t : root.path("tables")) {
                    long tableId = t.path("tableId").asLong(-1);
                    String comment = abbreviate(t.path("comment").asText(""), 480);
                    if (tableId <= 0 || comment.isBlank()) {
                        skipped++;
                        continue;
                    }
                    jdbc.update("update meta_table set table_comment = ? where id = ?", comment, tableId);
                    tablesEnriched++;
                }
                for (JsonNode c : root.path("columns")) {
                    long colId = c.path("columnId").asLong(-1);
                    String comment = abbreviate(c.path("comment").asText(""), 190);
                    if (colId <= 0 || comment.isBlank()) {
                        continue;
                    }
                    jdbc.update("update meta_column set column_comment = ? where id = ?", comment, colId);
                    columnsEnriched++;
                }
            } catch (Exception e) {
                warnings.add("第 " + bi + "/" + batches.size() + " 批失败：" + e.getMessage());
            }
        }
        if (!batches.isEmpty() && warnings.size() == batches.size()) {
            throw new IllegalStateException("所有批次均失败，请检查 AI 配置：" + warnings.get(0));
        }
        log.info("数据源 {} AI 注释补全完成：{} 表 / {} 字段", sourceId, tablesEnriched, columnsEnriched);
        return new EnrichResult(tablesEnriched, columnsEnriched, skipped, warnings);
    }

    private static final String SYSTEM_PROMPT = """
            你是医院信息系统的数据架构专家，熟悉 HIS/EMR/LIS/PACS/RIS 等医院业务系统。\
            给你数据表的表名、字段名和类型（可能来自 InterSystems IRIS 上的 HIS 库，命名常为英文缩写或拼音），\
            请推断并输出每个表的中文业务描述和每个字段的中文注释（说明业务含义，而不是翻译字面量）。
            规则：
            1. 输出严格 JSON，不要任何解释文字：
            {"tables":[{"tableId":数字,"comment":"不超过50字的中文表描述"}],"columns":[{"columnId":数字,"comment":"不超过30字的中文注释"}]}
            2. tableId/columnId 必须原样使用输入中给的数字。
            3. 注释要专业、具体：如 patient_no 写"患者就诊号（门诊号）"而不是"患者编号"；flag='1' 之类写清业务含义。
            4. 无法判断时给最合理的医学/业务推测，不要输出空串。
            """;

    private String buildPrompt(List<Map<String, Object>> tables,
                               Map<Long, List<Map<String, Object>>> colsByTable, boolean overwrite) {
        StringBuilder sb = new StringBuilder("请为下面的表生成中文描述与字段注释：\n");
        for (Map<String, Object> t : tables) {
            long id = ((Number) t.get("id")).longValue();
            sb.append("## 表 tableId=").append(id)
                    .append(" 表名=").append(t.get("table_name"));
            String old = String.valueOf(t.get("table_comment"));
            if (!old.isBlank()) {
                sb.append(" 现有注释=").append(abbreviate(old, 50));
            }
            sb.append('\n');
            for (Map<String, Object> c : colsByTable.getOrDefault(id, List.of())) {
                sb.append("  - columnId=").append(((Number) c.get("id")).longValue())
                        .append(" 字段=").append(c.get("column_name"))
                        .append(" 类型=").append(c.get("data_type"));
                String cc = String.valueOf(c.get("column_comment"));
                if (!cc.isBlank()) {
                    sb.append(" 现有注释=").append(abbreviate(cc, 30));
                }
                sb.append('\n');
                if (sb.length() > 14000) {
                    sb.append("  ...(已截断)\n");
                    return sb.toString();
                }
            }
        }
        if (overwrite) {
            sb.append("注意：本批为覆盖模式，字段清单可能只包含全部字段，请为所有表输出表注释。\n");
        }
        return sb.toString();
    }

    private static List<List<Map<String, Object>>> partition(List<Map<String, Object>> list, int size) {
        List<List<Map<String, Object>>> out = new ArrayList<>();
        for (int i = 0; i < list.size(); i += size) {
            out.add(list.subList(i, Math.min(i + size, list.size())));
        }
        return out;
    }

    private static String abbreviate(String s, int max) {
        if (s == null) {
            return "";
        }
        String one = s.replaceAll("\\s+", " ").trim();
        return one.length() > max ? one.substring(0, max) + "..." : one;
    }
}
