package com.dataasset.platform.util;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 查询结果的行处理工具。
 * 统一把 PostgreSQL 的 snake_case 列名转成前端友好的 camelCase。
 */
public final class Rows {

    private Rows() {
    }

    public static List<Map<String, Object>> camel(List<Map<String, Object>> rows) {
        List<Map<String, Object>> out = new ArrayList<>(rows.size());
        for (Map<String, Object> row : rows) {
            Map<String, Object> m = new LinkedHashMap<>();
            row.forEach((k, v) -> m.put(toCamel(k), v));
            out.add(m);
        }
        return out;
    }

    public static Map<String, Object> camel(Map<String, Object> row) {
        Map<String, Object> m = new LinkedHashMap<>();
        row.forEach((k, v) -> m.put(toCamel(k), v));
        return m;
    }

    public static String toCamel(String name) {
        String lower = name.toLowerCase();
        StringBuilder sb = new StringBuilder(lower.length());
        boolean upper = false;
        for (char c : lower.toCharArray()) {
            if (c == '_') {
                upper = true;
            } else if (upper) {
                sb.append(Character.toUpperCase(c));
                upper = false;
            } else {
                sb.append(c);
            }
        }
        return sb.toString();
    }
}
