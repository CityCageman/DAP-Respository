package com.dataasset.platform.web;

import com.dataasset.platform.util.Rows;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/overview")
public class OverviewController {

    private final JdbcTemplate jdbc;

    public OverviewController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
    public Map<String, Object> overview() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("assetCount", jdbc.queryForObject("select count(*) from asset", Long.class));
        out.put("tableCount", jdbc.queryForObject("select count(*) from meta_table", Long.class));
        out.put("columnCount", jdbc.queryForObject("select count(*) from meta_column", Long.class));
        out.put("sourceCount", jdbc.queryForObject("select count(*) from data_source", Long.class));
        out.put("standardCount", jdbc.queryForObject("select count(*) from data_standard where status = 'ACTIVE'", Long.class));
        out.put("ruleCount", jdbc.queryForObject("select count(*) from quality_rule where enabled = true", Long.class));
        out.put("lineageCount", jdbc.queryForObject("select count(*) from lineage_edge", Long.class));
        out.put("domainCount", jdbc.queryForObject("select count(*) from asset_domain", Long.class));

        out.put("avgQuality", jdbc.queryForObject(
                "select coalesce(round(avg(quality_score), 1), 0) from asset where quality_score is not null", Double.class));

        out.put("levelDistribution", Rows.camel(jdbc.queryForList("""
                select l.code, l.name, l.color, count(a.id) as cnt
                from security_level l left join asset a on a.security_level = l.code
                group by l.code, l.name, l.color, l.sort_no order by l.sort_no
                """)));

        out.put("typeDistribution", Rows.camel(jdbc.queryForList("""
                select asset_type, count(*) as cnt from asset group by asset_type order by cnt desc
                """)));

        out.put("domainDistribution", Rows.camel(jdbc.queryForList("""
                select d.name, count(a.id) as cnt
                from asset_domain d left join asset a on a.domain_id = d.id
                where d.parent_id is null
                group by d.name, d.sort_no order by d.sort_no
                """)));

        out.put("qualityTrend", Rows.camel(jdbc.queryForList("""
                select to_char(d.day, 'MM-DD') as day, coalesce(round(avg(q.pass_rate), 1), 0) as pass_rate
                from generate_series(current_date - 6 * interval '1 day', current_date, interval '1 day') as d(day)
                left join quality_result q on q.run_at::date = d.day::date
                group by d.day order by d.day
                """)));

        out.put("recentAssets", Rows.camel(jdbc.queryForList("""
                select a.id, a.name, a.asset_code, a.asset_type, a.security_level, a.owner,
                       a.updated_at, d.name as domain_name
                from asset a left join asset_domain d on d.id = a.domain_id
                order by a.updated_at desc nulls last, a.id desc limit 6
                """)));

        out.put("topAssets", Rows.camel(jdbc.queryForList("""
                select id, name, asset_code, view_count, security_level
                from asset order by view_count desc nulls last limit 5
                """)));

        out.put("pendingIssues", Rows.camel(jdbc.queryForList("""
                select r.name as rule_name, a.name as asset_name, q.pass_rate, q.status, q.run_at
                from quality_result q join quality_rule r on r.id = q.rule_id
                left join asset a on a.id = r.asset_id
                where q.status = 'FAIL'
                  and q.id = (select max(id) from quality_result q2 where q2.rule_id = q.rule_id)
                order by q.pass_rate asc limit 5
                """)));

        return out;
    }
}
