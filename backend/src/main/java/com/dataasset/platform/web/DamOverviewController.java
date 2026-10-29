package com.dataasset.platform.web;

import com.dataasset.platform.service.MidPlatformClient;
import com.dataasset.platform.util.Rows;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 三期总览（dam 资产域指标）：供 Dashboard 与元数据管理页展示 dam 层数据。
 * 生产侧（患者/就诊/采集任务/分层表）指标来自数据中台 OpenAPI，中台不可用时降级为 0。
 */
@RestController
@RequestMapping("/api/v2/overview")
public class DamOverviewController {

    private static final Logger log = LoggerFactory.getLogger(DamOverviewController.class);

    private final JdbcTemplate jdbc;
    private final MidPlatformClient mid;

    public DamOverviewController(JdbcTemplate jdbc, MidPlatformClient mid) {
        this.jdbc = jdbc;
        this.mid = mid;
    }

    private static long num(Object o) {
        return o instanceof Number n ? n.longValue() : 0L;
    }

    @GetMapping
    public Map<String, Object> overview() {
        Map<String, Object> out = new LinkedHashMap<>();

        // ---------- 目录与模型 ----------
        out.put("domainCount", count("dam_model.model_domain"));
        out.put("factCount", count("dam_model.model_fact"));
        out.put("dimensionCount", count("dam_model.model_dimension"));
        out.put("categoryCount", count("dam_asset.asset_category"));
        out.put("damAssetCount", count("dam_asset.asset_info"));

        // ---------- 数据中台侧指标（跨项目取，中台不可用时降级为 0） ----------
        Map<String, Object> midStats = Map.of();
        try {
            midStats = mid.stats();
        } catch (Exception e) {
            log.warn("数据中台不可达，总览中的生产侧指标降级为 0：{}", e.getMessage());
        }
        out.put("patientCount", num(midStats.get("patientCount")));
        out.put("encounterCount", num(midStats.get("encounterCount")));
        out.put("bizTableCount", num(midStats.get("layerTables") instanceof Map<?, ?> m ? m.get("ods") : null));

        // ---------- 元数据（dam 层采集结果） ----------
        out.put("damTableCount", count("dam_metadata.metadata_table"));
        out.put("damColumnCount", count("dam_metadata.metadata_column"));
        out.put("damSchemaCount", count("dam_metadata.metadata_schema"));
        out.put("codeTableCount", count("dam_standard.standard_code_table"));
        out.put("codeValueCount", count("dam_standard.standard_code_value"));
        out.put("crosswalkCount", count("dam_standard.code_crosswalk"));
        // 国标覆盖：有 GB/WS/NHC 级依据的码表数，以及标准中缺失、按院内扩展保留的码值数
        out.put("standardTableCount", jdbc.queryForObject(
                "select count(*) from dam_standard.standard_code_table"
                + " where deleted_at is null and standard_source in ('GB','WS','NHC')", Long.class));
        out.put("localTableCount", jdbc.queryForObject(
                "select count(*) from dam_standard.standard_code_table"
                + " where deleted_at is null and standard_source = 'LOCAL'", Long.class));
        out.put("localExtensionValueCount", jdbc.queryForObject(
                "select count(*) from dam_standard.standard_code_value"
                + " where deleted_at is null and is_extension = 1", Long.class));

        // ---------- 治理 ----------
        out.put("lineageEdgeCount", count("dam_metadata.metadata_lineage"));
        out.put("maskingPolicyCount", count("dam_security.security_masking_policy"));
        out.put("sensitiveRuleCount", count("dam_security.security_sensitive_rule"));
        out.put("qualityRuleCount", count("dam_metadata.metadata_quality_rule"));
        out.put("apiServiceCount", count("dam_service.api_service"));

        // ---------- 调度（数据中台的采集任务） ----------
        out.put("schedJobCount", num(midStats.get("collectTaskCount")));
        out.put("schedEnabledCount", num(midStats.get("collectEnabledCount")));
        out.put("schedRunCount", num(midStats.get("collectRunCount")));
        out.put("schedFailCount", num(midStats.get("collectFailCount")));

        // ---------- 各 schema 明细（元数据页用） ----------
        out.put("schemas", Rows.camel(jdbc.queryForList("""
                select s.id, s.schema_name, s.schema_comment,
                       (select count(*) from dam_metadata.metadata_table t
                         where t.schema_id = s.id and t.deleted_at is null) as table_count,
                       (select count(*) from dam_metadata.metadata_column c
                         join dam_metadata.metadata_table t2 on t2.id = c.table_id
                         where t2.schema_id = s.id and c.deleted_at is null) as column_count,
                       coalesce((select sum(t3.row_count::bigint) from dam_metadata.metadata_table t3
                         where t3.schema_id = s.id and t3.deleted_at is null), 0) as row_count
                from dam_metadata.metadata_schema s
                where s.deleted_at is null
                order by s.schema_name
                """)));

        // ---------- 最近采集记录 ----------
        out.put("recentCollections", Rows.camel(jdbc.queryForList("""
                select c.id, c.job_name, c.job_type, c.start_time, c.end_time,
                       c.total_tables, c.total_columns, c.success_count, c.fail_count, c.status,
                       d.ds_name
                from dam_metadata.metadata_collection c
                join dam_metadata.metadata_datasource d on d.id = c.datasource_id
                where c.deleted_at is null
                order by c.id desc limit 8
                """)));

        return out;
    }

    private long count(String table) {
        return jdbc.queryForObject(
                "select count(*) from " + table + " where deleted_at is null", Long.class);
    }
}
