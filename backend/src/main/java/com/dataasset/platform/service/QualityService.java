package com.dataasset.platform.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Random;

/**
 * 质量规则执行。
 * 能连上数据源就真实跑 SQL 统计，连不上（演示数据源）就按规则生成一份稳定的模拟结果，
 * 并在 detail 里标明 dataMode = REAL / SIMULATED，不假装是真实结果。
 */
@Service
public class QualityService {

    private static final Logger log = LoggerFactory.getLogger(QualityService.class);

    private final JdbcTemplate jdbc;

    public QualityService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record RunResult(long resultId, String status, double passRate, String detail) {
    }

    public RunResult run(long ruleId) {
        Map<String, Object> rule = jdbc.queryForMap("select * from quality_rule where id = ?", ruleId);
        String ruleType = String.valueOf(rule.get("rule_type"));
        String column = rule.get("column_name") == null ? null : String.valueOf(rule.get("column_name"));
        long assetId = rule.get("asset_id") == null ? 0L : ((Number) rule.get("asset_id")).longValue();

        long total = 0, pass = 0;
        String dataMode = "SIMULATED";

        Map<String, Object> target = null;
        try {
            target = jdbc.queryForMap("""
                    select t.table_name, t.schema_name, s.host, s.port, s.db_name, s.type, s.username, s.password
                    from asset a join meta_table t on t.id = a.source_table_id
                    join data_source s on s.id = t.source_id
                    where a.id = ?
                    """, assetId);
        } catch (Exception ignored) {
            // 资产没有关联元数据表，走模拟
        }

        if (target != null && column != null && isLocal(target)) {
            try (Connection conn = open(target)) {
                String qualified = quote(target) + ".";
                String tbl = qualified + target.get("table_name");
                if ("NOT_NULL".equals(ruleType)) {
                    total = count(conn, "select count(*) from " + tbl);
                    long fail = count(conn, "select count(*) from " + tbl + " where " + q(column) + " is null");
                    pass = total - fail;
                    dataMode = "REAL";
                } else if ("UNIQUE".equals(ruleType)) {
                    total = count(conn, "select count(*) from " + tbl);
                    long distinct = count(conn, "select count(distinct " + q(column) + ") from " + tbl);
                    pass = distinct;
                    dataMode = "REAL";
                }
            } catch (Exception e) {
                log.warn("规则 {} 真实执行失败，降级为模拟结果：{}", ruleId, e.getMessage());
            }
        }

        if ("SIMULATED".equals(dataMode)) {
            // 按 ruleId + 当天日期生成稳定结果：约 85% 通过，失败时低于阈值 2~10 个百分点
            Random random = new Random(ruleId * 1000L + LocalDate.now().toEpochDay());
            total = 2000 + random.nextInt(8000);
            double simThreshold = ((BigDecimal) rule.get("threshold")).doubleValue();
            double simRate;
            if (random.nextDouble() < 0.85) {
                simRate = Math.min(100.0, simThreshold + random.nextDouble() * 2.5);
            } else {
                simRate = Math.max(0, simThreshold - 2 - random.nextDouble() * 8);
            }
            pass = Math.round(total * simRate / 100.0);
        }

        long fail = total - pass;
        double rate = total == 0 ? 100.0 : Math.round(pass * 10000.0 / total) / 100.0;
        double threshold = ((BigDecimal) rule.get("threshold")).doubleValue();
        String status = rate >= threshold ? "PASS" : "FAIL";
        String detail = "dataMode=%s; ruleType=%s; threshold=%s%%; 总量 %d，通过 %d，异常 %d"
                .formatted(dataMode, ruleType, trim(threshold), total, pass, fail);

        Long resultId = jdbc.queryForObject("""
                insert into quality_result(rule_id, total_count, pass_count, fail_count, pass_rate, status, detail)
                values (?,?,?,?,?,?,?) returning id
                """, Long.class, ruleId, total, pass, fail, rate, status, detail);

        // 资产的综合质量分 = 其所有规则最近一次通过率的平均
        jdbc.update("""
                update asset set quality_score = (
                    select round(avg(latest.pass_rate), 1) from (
                        select q.pass_rate from quality_result q
                        join quality_rule r on r.id = q.rule_id
                        where r.asset_id = asset.id
                          and q.id = (select max(q2.id) from quality_result q2 where q2.rule_id = q.rule_id)
                    ) latest
                ) where id = ?
                """, assetId);

        return new RunResult(resultId, status, rate, detail);
    }

    public void runAll() {
        List<Long> ids = jdbc.queryForList("select id from quality_rule where enabled = true", Long.class);
        for (Long id : ids) {
            try {
                run(id);
            } catch (Exception e) {
                log.error("规则 {} 执行失败", id, e);
            }
        }
    }

    /** 只有本机数据源才尝试真实执行，演示用的 HIS/EMR/LIS 是虚构地址，直接走模拟，避免等连接超时 */
    private static boolean isLocal(Map<String, Object> t) {
        String host = String.valueOf(t.get("host"));
        return "localhost".equalsIgnoreCase(host) || "127.0.0.1".equals(host) || "::1".equals(host);
    }

    private Connection open(Map<String, Object> t) throws Exception {        String type = String.valueOf(t.get("type"));
        String url;
        if ("IRIS".equalsIgnoreCase(type)) {
            url = "jdbc:IRIS://%s:%s/%s".formatted(t.get("host"), t.get("port"), t.get("db_name"));
        } else if ("MYSQL".equalsIgnoreCase(type)) {
            url = "jdbc:mysql://%s:%s/%s?useSSL=false&connectTimeout=3000".formatted(t.get("host"), t.get("port"), t.get("db_name"));
        } else {
            url = "jdbc:postgresql://%s:%s/%s?connectTimeout=3".formatted(t.get("host"), t.get("port"), t.get("db_name"));
        }
        DriverManager.setLoginTimeout(4);
        return DriverManager.getConnection(url, String.valueOf(t.get("username")), String.valueOf(t.get("password")));
    }

    private static String quote(Map<String, Object> t) {
        boolean mysql = "MYSQL".equalsIgnoreCase(String.valueOf(t.get("type")));
        return mysql ? "`" + t.get("db_name") + "`" : "\"" + t.get("schema_name") + "\"";
    }

    private static String q(String column) {
        return "\"" + column.replace("\"", "") + "\"";
    }

    private static long count(Connection conn, String sql) throws Exception {
        try (PreparedStatement ps = conn.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {
            return rs.next() ? rs.getLong(1) : 0;
        }
    }

    private static String trim(double v) {
        return v == Math.floor(v) ? String.valueOf((long) v) : String.valueOf(v);
    }

    /** 供 Seeder 使用：写入一条历史结果，不触发真实执行 */
    public void insertHistory(long ruleId, java.time.LocalDateTime runAt, long total, long pass, String detail) {
        long fail = total - pass;
        double rate = BigDecimal.valueOf(pass * 100.0 / total).setScale(2, RoundingMode.HALF_UP).doubleValue();
        jdbc.update("""
                insert into quality_result(rule_id, run_at, total_count, pass_count, fail_count, pass_rate, status, detail)
                values (?,?,?,?,?,?,?,?)
                """, ruleId, runAt, total, pass, fail, rate, rate >= 95 ? "PASS" : "FAIL", detail);
    }
}
