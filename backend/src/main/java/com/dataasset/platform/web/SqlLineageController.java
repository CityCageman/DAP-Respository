package com.dataasset.platform.web;

import com.dataasset.platform.service.SqlLineageService;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/** SQL 血缘：解析（预览）+ 入库 */
@RestController
@RequestMapping("/api/v2/lineage/sql")
public class SqlLineageController {

    private final SqlLineageService service;

    public SqlLineageController(SqlLineageService service) {
        this.service = service;
    }

    public record ParseReq(String sqlText, String dbType) {
    }

    @PostMapping("/parse")
    public SqlLineageService.ParseResult parse(@RequestBody ParseReq req) {
        if (req.sqlText() == null || req.sqlText().isBlank()) {
            throw new IllegalArgumentException("请粘贴 SQL 脚本");
        }
        return service.parse(req.sqlText(), req.dbType());
    }

    @PostMapping("/save")
    public SqlLineageService.SaveResult save(@RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> edges = (List<Map<String, Object>>) body.get("edges");
        if (edges == null || edges.isEmpty()) {
            throw new IllegalArgumentException("没有可保存的血缘边");
        }
        return service.save(edges);
    }
}
