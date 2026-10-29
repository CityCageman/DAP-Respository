package com.dataasset.platform.web;

import com.dataasset.platform.service.AiMetaEnrichService;
import com.dataasset.platform.service.DamMetadataSyncService;
import com.dataasset.platform.service.MidPlatformClient;
import com.dataasset.platform.util.Rows;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 数据源（治理平台视角）：连接配置由数据中台持有，本控制器是"元数据采集入口"——
 * 列出中台可采集的源、拉取库表结构写入 dam_metadata.metadata_*，不再自己保存连接串。
 * 新建/修改/删除会转发到中台，保证连接只有一份。
 */
@RestController
@RequestMapping("/api/datasources")
public class DataSourceController {

    private final JdbcTemplate jdbc;
    private final MidPlatformClient mid;
    private final DamMetadataSyncService damSync;
    private final AiMetaEnrichService aiEnrichService;

    public DataSourceController(JdbcTemplate jdbc, MidPlatformClient mid,
                                DamMetadataSyncService damSync, AiMetaEnrichService aiEnrichService) {
        this.jdbc = jdbc;
        this.mid = mid;
        this.damSync = damSync;
        this.aiEnrichService = aiEnrichService;
    }

    public record DataSourceReq(@NotBlank String name, @NotBlank String type, String host, Integer port,
                                String dbName, String schemaName, String username, String password,
                                String description) {
    }

    /** 中台源清单 + 本地已采集情况（tableCount 为本地元数据表数） */
    @GetMapping
    public List<Map<String, Object>> list() {
        List<Map<String, Object>> out = new ArrayList<>();
        List<Map<String, Object>> local = jdbc.queryForList(
                "select id, ds_code from dam_metadata.metadata_datasource where deleted_at is null");
        Map<String, Long> localByCode = new LinkedHashMap<>();
        for (Map<String, Object> r : local) {
            localByCode.put(String.valueOf(r.get("ds_code")), ((Number) r.get("id")).longValue());
        }
        for (Map<String, Object> s : mid.sources()) {
            Map<String, Object> row = new LinkedHashMap<>(s);
            String code = "DS-MID-" + s.get("id");
            Long localId = localByCode.get(code);
            row.put("localDsId", localId);
            row.put("synced", localId != null);
            if (localId != null) {
                row.put("tableCount", jdbc.queryForObject(
                        "select count(*) from dam_metadata.metadata_table where datasource_id = ? and deleted_at is null",
                        Long.class, localId));
                row.put("lastSyncAt", jdbc.queryForObject(
                        "select max(last_sync_time) from dam_metadata.metadata_table where datasource_id = ? and deleted_at is null",
                        java.sql.Timestamp.class, localId));
            } else {
                row.put("tableCount", 0);
            }
            // 密码不回传前端
            row.remove("password");
            out.add(row);
        }
        return out;
    }

    /** 新建数据源 → 转发到中台 */
    @PostMapping
    public Map<String, Object> create(@Valid @RequestBody DataSourceReq req) {
        return mid.post("/openapi/sources/create", req);
    }

    /** 修改 → 转发到中台 */
    @PutMapping("/{id}")
    public Map<String, Object> update(@PathVariable long id, @Valid @RequestBody DataSourceReq req) {
        return mid.post("/openapi/sources/" + id + "/update", req);
    }

    /** 删除 → 转发到中台（中台会一并停用其采集任务） */
    @DeleteMapping("/{id}")
    public Map<String, Object> delete(@PathVariable long id) {
        return mid.post("/openapi/sources/" + id + "/delete", null);
    }

    /** 元数据采集：从中台取连接信息 → 登记本地 → 拉取库表结构进 dam_metadata.metadata_* */
    @PostMapping("/{id}/sync")
    public Map<String, Object> sync(@PathVariable long id) {
        Map<String, Object> src = mid.source(id);
        String msg = damSync.syncFromMidSource(src);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("message", msg);
        out.put("source", src.get("name"));
        return out;
    }

    /** 连接测试 → 转发到中台 */
    @PostMapping("/{id}/test")
    public Map<String, Object> test(@PathVariable long id) {
        return mid.post("/openapi/sources/" + id + "/test", null);
    }

    /** AI 补全中文表描述与字段注释（overwrite=false 仅补空 / true 覆盖） */
    @PostMapping("/{id}/ai-enrich")
    public Map<String, Object> aiEnrich(@PathVariable long id,
                                        @RequestBody(required = false) Map<String, Object> body) {
        Long localId = jdbc.queryForObject("""
                select id from dam_metadata.metadata_datasource where ds_code = ? and deleted_at is null
                """, Long.class, "DS-MID-" + id);
        boolean overwrite = body != null && Boolean.parseBoolean(String.valueOf(body.get("overwrite")));
        AiMetaEnrichService.EnrichResult r = aiEnrichService.enrich(localId, overwrite, null);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("tablesEnriched", r.tablesEnriched());
        out.put("columnsEnriched", r.columnsEnriched());
        out.put("skipped", r.skipped());
        out.put("warnings", r.warnings());
        return out;
    }
}
