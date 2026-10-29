package com.dataasset.platform.web;

import com.dataasset.platform.config.RequireRole;
import com.dataasset.platform.service.ApiGatewayService;
import com.dataasset.platform.util.Passwords;
import com.dataasset.platform.util.Rows;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;



import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/dataservice")
public class ApiServiceController {


    private final JdbcTemplate jdbc;
    private final ApiGatewayService gateway;

    public ApiServiceController(JdbcTemplate jdbc, ApiGatewayService gateway) {
        this.jdbc = jdbc;
        this.gateway = gateway;
    }

    // ---------------------- API 服务 ----------------------

    @GetMapping("/summary")
    public Map<String, Object> summary() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("apiCount", jdbc.queryForObject("select count(*) from api_service", Long.class));
        out.put("publishedCount", jdbc.queryForObject(
                "select count(*) from api_service where status = 'PUBLISHED'", Long.class));
        out.put("clientCount", jdbc.queryForObject("select count(*) from api_client", Long.class));
        out.put("callTotal", jdbc.queryForObject(
                "select coalesce(sum(call_count),0) from api_service", Long.class));
        out.put("failCount", jdbc.queryForObject(
                "select count(*) from api_call_log where success = false", Long.class));
        out.put("recentLogs", Rows.camel(jdbc.queryForList("""
                select * from api_call_log order by id desc limit 10
                """)));
        return out;
    }

    @GetMapping("/apis")
    public List<Map<String, Object>> apis(@RequestParam(required = false) String q) {
        String sql = """
                select a.id, a.api_code, a.name, a.status, a.sql_text, a.params_json, a.rate_limit,
                       a.owner, a.description, a.call_count, a.asset_id, a.created_at, a.updated_at,
                       ast.name as asset_name
                from api_service a left join asset ast on ast.id = a.asset_id
                where 1 = 1
                """;
        if (q != null && !q.isBlank()) {
            return Rows.camel(jdbc.queryForList(sql + """
                    and (a.name ilike ? or a.api_code ilike ? or a.description ilike ?) order by a.id
                    """, "%" + q + "%", "%" + q + "%", "%" + q + "%"));
        }
        return Rows.camel(jdbc.queryForList(sql + " order by a.id"));
    }

    public record ApiReq(String apiCode, String name, Long assetId, String sqlText, String paramsJson,
                         String status, Integer rateLimit, String owner, String description) {
    }

    @RequireRole({"ADMIN", "STEWARD"})
    @PostMapping("/apis")
    public Map<String, Object> create(@RequestBody ApiReq req) {
        if (req.sqlText() == null || req.sqlText().isBlank()) {
            throw new IllegalArgumentException("查询 SQL 不能为空");
        }
        Long id = jdbc.queryForObject("""
                insert into api_service(api_code, name, asset_id, sql_text, params_json, status,
                                        rate_limit, owner, description)
                values (?,?,?,?,?, coalesce(?, 'DRAFT'), coalesce(?, 60), ?, ?) returning id
                """, Long.class, req.apiCode(), req.name(), req.assetId(), req.sqlText(),
                req.paramsJson(), req.status(), req.rateLimit(), req.owner(), req.description());
        return Map.of("id", id);
    }

    @RequireRole({"ADMIN", "STEWARD"})
    @PutMapping("/apis/{id}")
    public Map<String, Object> update(@PathVariable long id, @RequestBody ApiReq req) {
        jdbc.update("""
                update api_service set name = ?, asset_id = ?, sql_text = ?, params_json = ?,
                       rate_limit = coalesce(?, rate_limit), owner = ?, description = ?, updated_at = now()
                where id = ?
                """, req.name(), req.assetId(), req.sqlText(), req.paramsJson(),
                req.rateLimit(), req.owner(), req.description(), id);
        return Map.of("id", id);
    }

    @RequireRole({"ADMIN", "STEWARD"})
    @PostMapping("/apis/{id}/publish")
    public Map<String, Object> publish(@PathVariable long id,
                                       @RequestParam(defaultValue = "PUBLISHED") String status) {
        jdbc.update("update api_service set status = ?, updated_at = now() where id = ?", status, id);
        return Map.of("id", id, "status", status);
    }

    @RequireRole({"ADMIN", "STEWARD"})
    @DeleteMapping("/apis/{id}")
    public Map<String, Object> delete(@PathVariable long id) {
        jdbc.update("delete from api_service where id = ?", id);
        return Map.of("deleted", id);
    }

    /** 平台内在线调试：走网关同一条链路（含脱敏），不校验 AppKey */
    @PostMapping("/apis/{id}/debug")
    public Map<String, Object> debug(@PathVariable long id, @RequestBody(required = false) Map<String, Object> params) {
        Map<String, Object> api = jdbc.queryForMap("select * from api_service where id = ?", id);
        String code = String.valueOf(api.get("api_code"));
        // 临时以 debug 客户端身份调用
        ApiGatewayService.InvokeResult r = gateway.debugInvoke(code, params);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("code", r.code());
        out.put("message", r.message());
        out.put("data", r.data());
        out.put("meta", r.meta());
        return out;
    }

    // ---------------------- 客户端密钥 ----------------------

    @GetMapping("/clients")
    public List<Map<String, Object>> clients() {
        return Rows.camel(jdbc.queryForList("""
                select c.*, (select count(*) from api_call_log l where l.app_id = c.app_id) as call_count
                from api_client c order by c.id
                """));
    }

    public record ClientReq(String appId, String appName, String contact) {
    }

    @RequireRole({"ADMIN", "STEWARD"})
    @PostMapping("/clients")
    public Map<String, Object> createClient(@RequestBody ClientReq req) {
        String key = "ak-" + Passwords.randomHex(12);
        Long id = jdbc.queryForObject("""
                insert into api_client(app_id, app_key, app_name, contact)
                values (?,?,?,?) returning id
                """, Long.class, req.appId(), key, req.appName(), req.contact());
        return Map.of("id", id, "appKey", key);
    }

    @RequireRole({"ADMIN", "STEWARD"})
    @PostMapping("/clients/{id}/regen-key")
    public Map<String, Object> regenKey(@PathVariable long id) {
        String key = "ak-" + Passwords.randomHex(12);
        jdbc.update("update api_client set app_key = ? where id = ?", key, id);
        return Map.of("id", id, "appKey", key);
    }

    @RequireRole({"ADMIN", "STEWARD"})
    @PutMapping("/clients/{id}")
    public Map<String, Object> updateClient(@PathVariable long id, @RequestBody Map<String, Object> body) {
        jdbc.update("""
                update api_client set status = coalesce(?, status), app_name = coalesce(?, app_name),
                       contact = coalesce(?, contact) where id = ?
                """, (String) body.get("status"), (String) body.get("appName"),
                (String) body.get("contact"), id);
        return Map.of("id", id);
    }

    @RequireRole({"ADMIN", "STEWARD"})
    @DeleteMapping("/clients/{id}")
    public Map<String, Object> deleteClient(@PathVariable long id) {
        jdbc.update("delete from api_client where id = ?", id);
        return Map.of("deleted", id);
    }

    // ---------------------- 调用日志 ----------------------

    @GetMapping("/logs")
    public List<Map<String, Object>> logs(@RequestParam(required = false) String apiCode,
                                          @RequestParam(defaultValue = "50") int limit) {
        if (apiCode != null && !apiCode.isBlank()) {
            return Rows.camel(jdbc.queryForList("""
                    select * from api_call_log where api_code = ? order by id desc limit ?
                    """, apiCode, Math.min(limit, 200)));
        }
        return Rows.camel(jdbc.queryForList(
                "select * from api_call_log order by id desc limit ?", Math.min(limit, 200)));
    }

    /** 已发布 API 的可调用信息（给外部系统对接用） */
    @GetMapping("/apis/{id}/doc")
    public Map<String, Object> doc(@PathVariable long id) {
        Map<String, Object> api = jdbc.queryForMap("select * from api_service where id = ?", id);
        Map<String, Object> out = Rows.camel(api);
        out.put("params", gateway.parseParams(api.get("params_json") == null
                ? null : String.valueOf(api.get("params_json"))));
        return out;
    }
}
