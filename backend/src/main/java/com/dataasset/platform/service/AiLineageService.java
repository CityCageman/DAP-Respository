package com.dataasset.platform.service;

import com.dataasset.platform.config.AiProperties;
import com.dataasset.platform.service.AiChatClient;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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
 * AI 血缘推断：把 dam 层元数据表/字段（含中文注释）分批喂给 LLM，
 * 由模型推断表级血缘（含字段映射、置信度、理由），人工或自动入库到 dam_metadata.metadata_lineage。
 * 典型场景：IRIS HIS 源表 → ODS/DWD 层表的加工血缘；同名/同义字段（empi、patient_id 等）关联。
 */
@Service
public class AiLineageService {

    private static final Logger log = LoggerFactory.getLogger(AiLineageService.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final JdbcTemplate jdbc;
    private final AiChatClient ai;
    private final AiProperties props;

    public AiLineageService(JdbcTemplate jdbc, AiChatClient ai, AiProperties props) {
        this.jdbc = jdbc;
        this.ai = ai;
        this.props = props;
    }

    public record AiEdge(String source, String target, Long sourceTableId, Long targetTableId,
                         String columnMapping, String reason, double confidence, boolean saved) {
    }

    public record InferResult(int tableCount, int batchCount, List<AiEdge> edges,
                              List<String> unmapped, List<String> warnings, String model) {
    }

    /**
     * @param schemaName 可选，限定某个 schema（如 iris / hospital_demo / ods）
     * @param tableIds   可选，直接指定参与推断的表
     * @param limit      最多参与推断的表数（默认 36 = 3 批）
     * @param save       推断结果是否直接入库
     */
    public InferResult infer(String schemaName, List<Long> tableIds, Integer limit, boolean save) {
        int maxTables = limit == null || limit <= 0 ? props.getMaxTablesPerBatch() * 3 : Math.min(limit, 120);

        StringBuilder where = new StringBuilder(" where t.status = 1 ");
        List<Object> args = new ArrayList<>();
        if (schemaName != null && !schemaName.isBlank()) {
            where.append(" and s.schema_name = ? ");
            args.add(schemaName);
        }
        if (tableIds != null && !tableIds.isEmpty()) {
            String in = joinIds(tableIds);
            where.append(" and t.id in (").append(in).append(") ");
        }
        List<Map<String, Object>> tables = Rows_x(jdbc, """
                select t.id, t.table_name, s.schema_name, t.table_comment
                from dam_metadata.metadata_table t join dam_metadata.metadata_schema s on s.id = t.schema_id
                """ + where + " order by t.id limit " + maxTables, args);

        if (tables.isEmpty()) {
            throw new IllegalArgumentException("没有找到可参与推断的元数据表");
        }

        // 批量取字段
        Map<Long, List<Map<String, Object>>> colsByTable = new HashMap<>();
        String idList = joinIds(tables.stream().map(t -> ((Number) t.get("id")).longValue()).toList());
        jdbc.queryForList("""
                select table_id, column_name, column_type, column_comment
                from dam_metadata.metadata_column where table_id in (%s) order by table_id, ordinal_position
                """.formatted(idList)).forEach(r ->
                colsByTable.computeIfAbsent(((Number) r.get("table_id")).longValue(), k -> new ArrayList<>()).add(r));

        Map<String, Long> idByKey = new LinkedHashMap<>();
        Map<Long, String> keyById = new LinkedHashMap<>();
        for (Map<String, Object> t : tables) {
            String key = (t.get("schema_name") + "." + t.get("table_name")).toLowerCase();
            idByKey.put(key, ((Number) t.get("id")).longValue());
            keyById.put(((Number) t.get("id")).longValue(), key);
        }

        int batch = Math.max(props.getMaxTablesPerBatch(), 4);
        List<AiEdge> edges = new ArrayList<>();
        Set<String> unmapped = new LinkedHashSet<>();
        List<String> warnings = new ArrayList<>();
        List<List<Map<String, Object>>> batches = partition(new ArrayList<>(tables), batch);

        int bi = 0;
        for (List<Map<String, Object>> part : batches) {
            bi++;
            String userPrompt = buildPrompt(part, colsByTable);
            String raw;
            try {
                raw = ai.chat(SYSTEM_PROMPT, userPrompt);
            } catch (IllegalStateException e) {
                warnings.add("第 " + bi + "/" + batches.size() + " 批失败：" + e.getMessage());
                continue;
            }
            try {
                JsonNode root = MAPPER.readTree(AiChatClient.extractJson(raw));
                for (JsonNode e : root.path("edges")) {
                    String src = e.path("source").asText("").trim().toLowerCase();
                    String tgt = e.path("target").asText("").trim().toLowerCase();
                    Long sId = idByKey.get(src);
                    Long tId = idByKey.get(tgt);
                    if (sId == null) {
                        unmapped.add(src);
                    }
                    if (tId == null) {
                        unmapped.add(tgt);
                    }
                    if (sId == null || tId == null || sId.equals(tId)) {
                        continue;
                    }
                    double conf = e.path("confidence").asDouble(0.5);
                    String mapping = abbreviate(e.path("columnMapping").asText(""), 300);
                    String reason = abbreviate(e.path("reason").asText(""), 300);
                    boolean saved = false;
                    if (save) {
                        saved = insertEdge(sId, tId, mapping, reason, conf);
                    }
                    edges.add(new AiEdge(keyById.get(sId), keyById.get(tId), sId, tId, mapping, reason, conf, saved));
                }
            } catch (Exception e) {
                warnings.add("第 " + bi + " 批输出解析失败：" + e.getMessage());
            }
        }
        if (!batches.isEmpty() && warnings.size() == batches.size()) {
            throw new IllegalStateException("所有批次均失败，请检查 AI 配置：" + warnings.get(0));
        }
        return new InferResult(tables.size(), batches.size(), edges, new ArrayList<>(unmapped), warnings, props.getModel());
    }

    private static final String SYSTEM_PROMPT = """
            你是医院数据平台的元数据与数据血缘专家。给你一批数据表（含 schema、表名、字段、类型、中文注释），\
            请根据表名字段名语义、中文注释、主键/外键线索（如 empi、patient_id、visit_id、编码字典）推断表之间的血缘关系：\
            哪张表是上游源表，哪张表是下游加工产物（例如 HIS 源表 → ODS 贴源层 → DWD 明细层 → DM 汇总层）。
            规则：
            1. 只允许输出给出的表，禁止编造不存在的表名；表名必须带 schema 前缀，与输入完全一致。
            2. 输出严格的 JSON，不要任何解释文字：{"edges":[{"source":"schema.table","target":"schema.table","columnMapping":"src_col -> tgt_col; src_col2 -> tgt_col2","reason":"一句话中文理由","confidence":0.0-1.0}]}
            3. 没有可信血缘就输出 {"edges":[]}；宁缺毋滥，confidence 低于 0.5 的不要输出。
            """;

    private String buildPrompt(List<Map<String, Object>> tables, Map<Long, List<Map<String, Object>>> colsByTable) {
        StringBuilder sb = new StringBuilder("表清单（共 ").append(tables.size()).append(" 张）：\n");
        for (Map<String, Object> t : tables) {
            long id = ((Number) t.get("id")).longValue();
            sb.append("## ").append(t.get("schema_name")).append('.').append(t.get("table_name"));
            String comment = t.get("table_comment") == null ? "" : String.valueOf(t.get("table_comment"));
            if (!comment.isBlank()) {
                sb.append("（").append(abbreviate(comment, 60)).append("）");
            }
            sb.append('\n');
            List<Map<String, Object>> cols = colsByTable.getOrDefault(id, List.of());
            for (Map<String, Object> c : cols) {
                sb.append("  - ").append(c.get("column_name")).append(' ').append(c.get("column_type"));
                String cc = c.get("column_comment") == null ? "" : String.valueOf(c.get("column_comment"));
                if (!cc.isBlank()) {
                    sb.append(" -- ").append(abbreviate(cc, 40));
                }
                sb.append('\n');
                if (sb.length() > 12000) {
                    sb.append("  ...(字段过多已截断)\n");
                    return sb.toString();
                }
            }
        }
        return sb.toString();
    }

    /** 入库，表对+AI 去重 */
    private boolean insertEdge(long sId, long tId, String mapping, String reason, double conf) {
        int exists = jdbc.queryForObject("""
                select count(*) from dam_metadata.metadata_lineage
                where source_type = 'TABLE' and target_type = 'TABLE'
                  and source_id = ? and target_id = ? and relation_type = 'AI_INFER'
                  and discovered_by = 'AI' and deleted_at is null
                """, Integer.class, sId, tId);
        if (exists > 0) {
            return false;
        }
        String rule = abbreviate("字段映射: " + mapping + " | 依据: " + reason, 480);
        jdbc.update("""
                insert into dam_metadata.metadata_lineage(source_type, source_id, target_type, target_id,
                    relation_type, transform_rule, dependency_level, source_system, collection_id,
                    discovered_by, created_by, updated_by)
                values ('TABLE', ?, 'TABLE', ?, 'AI_INFER', ?, 1, 'AI', 0, 'AI', 'AI推断', 'AI推断')
                """, sId, tId, rule);
        return true;
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> Rows_x(JdbcTemplate jdbc, String sql, List<Object> args) {
        return jdbc.queryForList(sql, args.toArray());
    }

    private static List<List<Map<String, Object>>> partition(List<Map<String, Object>> list, int size) {
        List<List<Map<String, Object>>> out = new ArrayList<>();
        for (int i = 0; i < list.size(); i += size) {
            out.add(list.subList(i, Math.min(i + size, list.size())));
        }
        return out;
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

    private static String abbreviate(String s, int max) {
        if (s == null) {
            return "";
        }
        String one = s.replaceAll("\\s+", " ").trim();
        return one.length() > max ? one.substring(0, max) + "..." : one;
    }
}
