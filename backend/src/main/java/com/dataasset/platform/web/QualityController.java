package com.dataasset.platform.web;

import com.dataasset.platform.service.QualityService;
import com.dataasset.platform.util.Rows;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.*;

@RestController
@RequestMapping("/api/quality")
public class QualityController {

    private final JdbcTemplate jdbc;
    private final QualityService qualityService;

    public QualityController(JdbcTemplate jdbc, QualityService qualityService) {
        this.jdbc = jdbc;
        this.qualityService = qualityService;
    }

    public record RuleReq(@NotBlank String name, Long assetId, String columnName, @NotBlank String ruleType,
                          String ruleExpr, BigDecimal threshold, String severity, Boolean enabled) {
    }

    @GetMapping("/rules")
    public List<Map<String, Object>> rules(@RequestParam(required = false) Long assetId) {
        StringBuilder sql = new StringBuilder("""
                select r.*, a.name as asset_name, a.asset_code, a.security_level,
                       q.pass_rate as last_pass_rate, q.status as last_status, q.run_at as last_run_at
                from quality_rule r
                left join asset a on a.id = r.asset_id
                left join quality_result q on q.id = (select max(id) from quality_result where rule_id = r.id)
                where 1 = 1
                """);
        List<Object> args = new ArrayList<>();
        if (assetId != null) {
            sql.append(" and r.asset_id = ?");
            args.add(assetId);
        }
        sql.append(" order by r.id desc");
        return Rows.camel(jdbc.queryForList(sql.toString(), args.toArray()));
    }

    @PostMapping("/rules")
    public Map<String, Object> create(@Valid @RequestBody RuleReq req) {
        Long id = jdbc.queryForObject("""
                insert into quality_rule(name, asset_id, column_name, rule_type, rule_expr, threshold, severity, enabled)
                values (?,?,?,?,?,?,?,?) returning id
                """, Long.class, req.name(), req.assetId(), req.columnName(), req.ruleType(), req.ruleExpr(),
                req.threshold() == null ? new BigDecimal("95") : req.threshold(),
                req.severity() == null ? "MEDIUM" : req.severity(),
                req.enabled() == null || req.enabled());
        return Map.of("id", id);
    }

    @PutMapping("/rules/{id}")
    public Map<String, Object> update(@PathVariable long id, @Valid @RequestBody RuleReq req) {
        jdbc.update("""
                update quality_rule set name = ?, asset_id = ?, column_name = ?, rule_type = ?, rule_expr = ?,
                       threshold = ?, severity = ?, enabled = ? where id = ?
                """, req.name(), req.assetId(), req.columnName(), req.ruleType(), req.ruleExpr(),
                req.threshold(), req.severity(), req.enabled() == null || req.enabled(), id);
        return Map.of("id", id);
    }

    @DeleteMapping("/rules/{id}")
    public Map<String, Object> delete(@PathVariable long id) {
        jdbc.update("delete from quality_result where rule_id = ?", id);
        jdbc.update("delete from quality_rule where id = ?", id);
        return Map.of("deleted", id);
    }

    @PostMapping("/rules/{id}/run")
    public QualityService.RunResult run(@PathVariable long id) {
        return qualityService.run(id);
    }

    @PostMapping("/run-all")
    public Map<String, Object> runAll() {
        long start = System.currentTimeMillis();
        qualityService.runAll();
        return Map.of("message", "全部规则执行完成",
                "costMs", System.currentTimeMillis() - start,
                "ruleCount", jdbc.queryForObject("select count(*) from quality_rule where enabled = true", Long.class));
    }

    @GetMapping("/results")
    public List<Map<String, Object>> results(@RequestParam(required = false) Long ruleId,
                                             @RequestParam(defaultValue = "50") int limit) {
        String sql = """
                select q.*, r.name as rule_name, r.rule_type, a.name as asset_name
                from quality_result q join quality_rule r on r.id = q.rule_id
                left join asset a on a.id = r.asset_id
                where 1 = 1
                """;
        if (ruleId != null) {
            return Rows.camel(jdbc.queryForList(sql + " and q.rule_id = ? order by q.run_at desc limit ?",
                    ruleId, limit));
        }
        return Rows.camel(jdbc.queryForList(sql + " order by q.run_at desc limit ?", limit));
    }

    @GetMapping("/summary")
    public Map<String, Object> summary() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("ruleCount", jdbc.queryForObject("select count(*) from quality_rule", Long.class));
        out.put("enabledCount", jdbc.queryForObject("select count(*) from quality_rule where enabled = true", Long.class));
        out.put("todayRunCount", jdbc.queryForObject(
                "select count(*) from quality_result where run_at >= current_date", Long.class));
        Map<String, Object> avg = jdbc.queryForMap("""
                select coalesce(round(avg(pass_rate), 1), 0) as avg_rate
                from quality_result where run_at >= current_date
                """);
        out.put("todayPassRate", avg.get("avg_rate"));
        // 未通过规则 = 最新一次执行结果为 FAIL 的启用规则数
        out.put("todayFailCount", jdbc.queryForObject("""
                select count(*) from quality_rule r
                where r.enabled = true
                  and exists (select 1 from quality_result q
                              where q.rule_id = r.id and q.status = 'FAIL'
                                and q.id = (select max(id) from quality_result q2 where q2.rule_id = r.id))
                """, Long.class));
        out.put("worstRules", Rows.camel(jdbc.queryForList("""
                select r.id, r.name, a.name as asset_name, q.pass_rate, q.status, q.run_at
                from quality_result q join quality_rule r on r.id = q.rule_id
                left join asset a on a.id = r.asset_id
                where q.id = (select max(id) from quality_result q2 where q2.rule_id = q.rule_id)
                order by q.pass_rate asc limit 5
                """)));
        return out;
    }

    @GetMapping("/trend")
    public List<Map<String, Object>> trend(@RequestParam(defaultValue = "7") int days) {
        return Rows.camel(jdbc.queryForList("""
                select to_char(d.day, 'MM-DD') as day, d.day as date,
                       coalesce(round(avg(q.pass_rate), 1), null) as pass_rate,
                       count(q.id) as run_count
                from generate_series(current_date - (? - 1) * interval '1 day', current_date, interval '1 day') as d(day)
                left join quality_result q on q.run_at::date = d.day::date
                group by d.day order by d.day
                """, days));
    }
}
