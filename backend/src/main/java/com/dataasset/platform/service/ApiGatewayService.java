package com.dataasset.platform.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.DriverManager;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Pattern;

/**
 * 数据服务 API 网关：真实执行注册的查询 SQL，按资产安全策略脱敏，限流 + 调用留痕。
 */
@Service
public class ApiGatewayService {

    private static final Logger log = LoggerFactory.getLogger(ApiGatewayService.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final Pattern ONLY_SELECT =
            Pattern.compile("^\\s*(with|select)\\b.*", Pattern.CASE_INSENSITIVE | Pattern.DOTALL);
    private static final int MAX_ROWS = 100;

    /** 每分钟限流：appId -> (windowStartMinute, count) */
    private record Window(long minute, java.util.concurrent.atomic.AtomicInteger count) {
    }
    private final Map<String, Window> rateWindows = new ConcurrentHashMap<>();

    public record ApiDef(long id, String apiCode, String name, Long assetId, String sqlText,
                         List<ParamDef> params, String status, int rateLimit) {
    }

    public record ParamDef(String name, String type, boolean required, String desc, Object example) {
    }

    public record InvokeResult(int code, String message, List<Map<String, Object>> data,
                               Map<String, Object> meta) {
    }

    private final JdbcTemplate jdbc;
    private final MaskingService maskingService;
    private final MidPlatformClient midPlatformClient;

    public ApiGatewayService(JdbcTemplate jdbc, MaskingService maskingService,
                             MidPlatformClient midPlatformClient) {
        this.jdbc = jdbc;
        this.maskingService = maskingService;
        this.midPlatformClient = midPlatformClient;
    }

    public List<ParamDef> parseParams(String paramsJson) {
        if (paramsJson == null || paramsJson.isBlank() || "null".equalsIgnoreCase(paramsJson.trim())) {
            return List.of();
        }
        try {
            List<ParamDef> list = MAPPER.readValue(paramsJson, new TypeReference<List<ParamDef>>() {
            });
            return list == null ? List.of() : list;
        } catch (Exception e) {
            return List.of();
        }
    }

    /** 网关主入口：校验客户端 -> 校验 API -> 参数校验 -> 真实查询 -> 脱敏 -> 留痕 */
    public InvokeResult invoke(String apiCode, String appId, String appKey, String source,
                               Map<String, Object> params, String clientIp, String callerRole) {
        long t0 = System.currentTimeMillis();
        String finalStatus = "SUCCESS";
        String errMsg = null;
        List<Map<String, Object>> data = List.of();
        List<String> masked = List.of();
        int rowCount = 0;
        Long apiId = null;
        try {
            // 1. 客户端鉴权（平台内调试跳过）
            Map<String, Object> client = null;
            if (!"DEBUG".equals(source)) {
                client = jdbc.queryForList(
                        "select * from api_client where app_id = ? and app_key = ? and status = 'ACTIVE'",
                        appId == null ? "" : appId, appKey == null ? "" : appKey).stream()
                        .findFirst().orElse(null);
                if (client == null) {
                    return new InvokeResult(401, "AppId 或 AppKey 无效，或应用已被停用", data, meta(0, 0, List.of()));
                }
            }

            // 2. API 定义
            Map<String, Object> api = jdbc.queryForList(
                    "select * from api_service where api_code = ?", apiCode).stream()
                    .findFirst().orElse(null);
            if (api == null) {
                return new InvokeResult(404, "API 不存在：" + apiCode, data, meta(0, 0, List.of()));
            }
            apiId = ((Number) api.get("id")).longValue();
            if (!"PUBLISHED".equals(api.get("status"))) {
                return new InvokeResult(403, "API 未发布或已下线", data, meta(0, 0, List.of()));
            }
            int rateLimit = api.get("rate_limit") == null ? 60 : ((Number) api.get("rate_limit")).intValue();

            // 3. 限流
            String rl = checkRateLimit(appId + ":" + apiCode, rateLimit);
            if (rl != null) {
                finalStatus = "RATE_LIMITED";
                return new InvokeResult(429, rl, data, meta(0, 0, List.of()));
            }

            // 4. 参数白名单校验
            List<ParamDef> defs = parseParams(String.valueOf(api.getOrDefault("params_json", "")));
            Map<String, Object> safeParams = validateParams(defs, params == null ? Map.of() : params);

            // 5. 真实查询（API-PATIENT-360 走数据中台的患者360聚合接口，其余按注册 SQL 执行）
            if ("API-PATIENT-360".equals(apiCode)) {
                Map<String, Object> resp = midPlatformClient.patient360(safeParams);
                Object rows = resp == null ? null : resp.get("patients");
                data = rows instanceof List<?> l ? (List<Map<String, Object>>) l : List.of();
                rowCount = data.size();
                // EXTERNAL 场景实际生效的策略列（姓名策略仅平台内 ANALYST 场景）
                masked = List.of("idCard", "registerNo");
            } else {
                String sqlText = String.valueOf(api.get("sql_text"));
                data = executeQuery(apiId, sqlText, safeParams);
                rowCount = data.size();

                // 6. 按资产安全策略脱敏
                Long assetId = api.get("asset_id") == null ? null : ((Number) api.get("asset_id")).longValue();
                if (assetId != null) {
                    MaskingService.MaskResult mr = maskingService.apply(assetId, data);
                    data = mr.rows();
                    masked = mr.maskedColumns();
                }
            }

            jdbc.update("update api_service set call_count = call_count + 1 where id = ?", apiId);
            if (client != null) {
                jdbc.update("update api_client set last_call_at = now() where app_id = ?", appId);
            }
            return new InvokeResult(0, "success", data,
                    meta(System.currentTimeMillis() - t0, rowCount, masked));
        } catch (IllegalArgumentException e) {
            finalStatus = "BAD_REQUEST";
            errMsg = e.getMessage();
            return new InvokeResult(400, e.getMessage(), data, meta(System.currentTimeMillis() - t0, 0, List.of()));
        } catch (Exception e) {
            log.error("网关调用失败 api={} app={}", apiCode, appId, e);
            finalStatus = "ERROR";
            errMsg = e.getMessage();
            return new InvokeResult(500, "执行失败：" + e.getMessage(), data,
                    meta(System.currentTimeMillis() - t0, 0, List.of()));
        } finally {
            long duration = System.currentTimeMillis() - t0;
            try {
                jdbc.update("""
                        insert into api_call_log(api_id, api_code, app_id, params, duration_ms, row_count,
                                                 success, masked_columns, error_msg, client_ip)
                        values (?,?,?,?,?,?,?,?,?,?)
                        """, apiId, apiCode, (appId == null ? source : appId),
                        params == null ? null : params.toString(), (int) duration, rowCount,
                        "SUCCESS".equals(finalStatus), String.join(",", masked), errMsg, clientIp);
            } catch (Exception logEx) {
                log.warn("写网关调用日志失败：{}", logEx.getMessage());
            }
        }
    }

    /** 平台内在线调试：跳过 AppKey 校验，其余链路（参数校验/真实查询/脱敏/留痕）完全一致 */
    public InvokeResult debugInvoke(String apiCode, Map<String, Object> params) {
        return invoke(apiCode, "debug-console", "-", "DEBUG", params, "127.0.0.1", "PLATFORM");
    }

    // ---------------------- 内部步骤 ----------------------

    private Map<String, Object> meta(long durationMs, int rowCount, List<String> masked) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("durationMs", durationMs);
        m.put("rowCount", rowCount);
        m.put("maxRows", MAX_ROWS);
        m.put("maskedColumns", masked);
        return m;
    }

    /** 简单滑动分钟窗限流 */
    private String checkRateLimit(String key, int limitPerMinute) {
        long minute = System.currentTimeMillis() / 60000L;
        Window w = rateWindows.compute(key, (k, old) ->
                old == null || old.minute() != minute ? new Window(minute, new java.util.concurrent.atomic.AtomicInteger()) : old);
        return w.count().incrementAndGet() > limitPerMinute
                ? "调用超过限流阈值（" + limitPerMinute + " 次/分钟），请稍后重试" : null;
    }

    private Map<String, Object> validateParams(List<ParamDef> defs, Map<String, Object> input) {
        Map<String, Object> out = new HashMap<>();
        for (ParamDef def : defs) {
            Object v = input.get(def.name());
            if (v == null || String.valueOf(v).isEmpty()) {
                if (def.required()) {
                    throw new IllegalArgumentException("缺少必填参数：" + def.name());
                }
                continue;
            }
            if ("number".equalsIgnoreCase(def.type())) {
                try {
                    out.put(def.name(), v instanceof Number n ? n : Double.parseDouble(String.valueOf(v)));
                } catch (NumberFormatException e) {
                    throw new IllegalArgumentException("参数 " + def.name() + " 必须是数字");
                }
            } else {
                out.put(def.name(), String.valueOf(v));
            }
        }
        // 未声明的一律丢弃（防注入面）
        return out;
    }

    /** 真实连到资产对应的数据源执行 SQL（仅本机数据源可执行） */
    private List<Map<String, Object>> executeQuery(long apiId, String sqlText, Map<String, Object> params)
            throws Exception {
        String trimmed = sqlText.trim().replaceAll(";\\s*$", "");
        if (!ONLY_SELECT.matcher(trimmed).matches() || trimmed.contains(";")) {
            throw new IllegalArgumentException("只允许执行单条 SELECT 查询");
        }
        Map<String, Object> target = jdbc.queryForMap("""
                select s.* from api_service api
                join asset a on a.id = api.asset_id
                join meta_table t on t.id = a.source_table_id
                join data_source s on s.id = t.source_id
                where api.id = ?
                """, apiId);
        String host = String.valueOf(target.get("host"));
        boolean local = "localhost".equalsIgnoreCase(host) || "127.0.0.1".equals(host) || "::1".equals(host);
        if (!local) {
            throw new IllegalArgumentException("演示环境仅允许本机数据源真实执行，"
                    + target.get("name") + " 不可直连");
        }
        String url = "jdbc:postgresql://%s:%s/%s?connectTimeout=3"
                .formatted(target.get("host"), target.get("port"), target.get("db_name"));
        String wrapped = "select * from (" + trimmed + ") gateway_view limit " + MAX_ROWS;

        try (Connection conn = DriverManager.getConnection(url,
                String.valueOf(target.get("username")), String.valueOf(target.get("password")))) {
            NamedParameterJdbcTemplate np = new NamedParameterJdbcTemplate(
                    new org.springframework.jdbc.datasource.SingleConnectionDataSource(conn, true));
            return np.queryForList(wrapped, params);
        }
    }
}
