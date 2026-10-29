package com.dataasset.platform.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 脱敏引擎：按资产上的 security_policy 对真实查询结果的列值做脱敏。
 *
 * 支持 strategy：
 *  - MASK    保留前 1/3，其余 *（姓名类）
 *  - PARTIAL 保留前 3 后 4，中间 *（身份证、手机号类）
 *  - HASH    SHA-256 前 12 位（不可逆化名）
 *  - NULLIFY 直接置空
 */
@Service
public class MaskingService {

    private static final Logger log = LoggerFactory.getLogger(MaskingService.class);

    private final JdbcTemplate jdbc;

    public MaskingService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record MaskResult(List<Map<String, Object>> rows, List<String> maskedColumns) {
    }

    /** 对一组真实查询行按资产策略脱敏 */
    public MaskResult apply(long assetId, List<Map<String, Object>> rows) {
        Map<String, String> strategyByColumn = new LinkedHashMap<>();
        jdbc.queryForList(
                "select column_name, desensitize from security_policy where asset_id = ? and desensitize <> 'NONE'",
                assetId).forEach(p -> strategyByColumn.put(
                String.valueOf(p.get("column_name")).toLowerCase(),
                String.valueOf(p.get("desensitize"))));

        if (strategyByColumn.isEmpty() || rows.isEmpty()) {
            return new MaskResult(rows, List.of());
        }

        List<Map<String, Object>> out = new ArrayList<>(rows.size());
        for (Map<String, Object> row : rows) {
            Map<String, Object> m = new LinkedHashMap<>();
            row.forEach((k, v) -> {
                String strategy = strategyByColumn.get(k.toLowerCase());
                m.put(k, strategy == null ? v : mask(v, strategy));
            });
            out.add(m);
        }
        return new MaskResult(out, new ArrayList<>(strategyByColumn.keySet()));
    }

    /** 单值脱敏 */
    public String mask(Object value, String strategy) {
        if (value == null) {
            return null;
        }
        String s = String.valueOf(value);
        if (s.isEmpty()) {
            return s;
        }
        return switch (strategy) {
            case "PARTIAL" -> partial(s);
            case "MASK" -> maskKeep(s);
            case "HASH" -> com.dataasset.platform.util.Passwords.sha256(s).substring(0, 12);
            case "NULLIFY" -> null;
            default -> s;
        };
    }

    /** 保留前 3 后 4，中間补 *；短串只保留后 4 */
    private static String partial(String s) {
        if (s.length() <= 8) {
            return "*".repeat(Math.max(0, s.length() - 4)) + s.substring(Math.max(0, s.length() - 4));
        }
        return s.substring(0, 3) + "*".repeat(s.length() - 7) + s.substring(s.length() - 4);
    }

    /** 保留前 1/3，其余 * */
    private static String maskKeep(String s) {
        int keep = Math.max(1, s.length() / 3);
        return s.substring(0, keep) + "*".repeat(s.length() - keep);
    }
}
