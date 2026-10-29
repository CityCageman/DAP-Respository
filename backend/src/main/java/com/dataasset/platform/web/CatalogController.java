package com.dataasset.platform.web;

import com.dataasset.platform.config.RequireRole;
import com.dataasset.platform.service.CatalogService;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 数据目录（阶段 B）：四层目录树 + 域/模型 CRUD。
 */
@RestController
@RequestMapping("/api/v2/catalog")
public class CatalogController {

    private final CatalogService catalog;

    public CatalogController(CatalogService catalog) {
        this.catalog = catalog;
    }

    /** 目录树：数据中心 → 业务域 → 模型（事实/维度） */
    @GetMapping("/domain-tree")
    public List<Map<String, Object>> domainTree() {
        return catalog.domainTree();
    }

    /** 主题/资产分类树 */
    @GetMapping("/category-tree")
    public List<Map<String, Object>> categoryTree() {
        return catalog.categoryTree();
    }

    @GetMapping("/categories/{id}/assets")
    public List<Map<String, Object>> assets(@PathVariable long id) {
        return catalog.assetsByCategory(id);
    }

    // ---------- 域 ----------

    @RequireRole({"ADMIN", "STEWARD"})
    @PostMapping("/domains")
    public Map<String, Object> createDomain(@RequestBody Map<String, Object> body) {
        return catalog.createDomain(body);
    }

    @RequireRole({"ADMIN", "STEWARD"})
    @PutMapping("/domains/{id}")
    public Map<String, Object> updateDomain(@PathVariable long id, @RequestBody Map<String, Object> body) {
        catalog.updateDomain(id, body);
        return Map.of("id", id);
    }

    @RequireRole({"ADMIN", "STEWARD"})
    @DeleteMapping("/domains/{id}")
    public Map<String, Object> deleteDomain(@PathVariable long id) {
        catalog.deleteDomain(id);
        return Map.of("id", id, "deleted", true);
    }

    // ---------- 事实模型 ----------

    @RequireRole({"ADMIN", "STEWARD"})
    @PostMapping("/facts")
    public Map<String, Object> createFact(@RequestBody Map<String, Object> body) {
        return catalog.createFact(body);
    }

    @RequireRole({"ADMIN", "STEWARD"})
    @PutMapping("/facts/{id}")
    public Map<String, Object> updateFact(@PathVariable long id, @RequestBody Map<String, Object> body) {
        catalog.updateFact(id, body);
        return Map.of("id", id);
    }

    @RequireRole({"ADMIN", "STEWARD"})
    @DeleteMapping("/facts/{id}")
    public Map<String, Object> deleteFact(@PathVariable long id) {
        catalog.deleteFact(id);
        return Map.of("id", id, "deleted", true);
    }

    // ---------- 维度模型 ----------

    @RequireRole({"ADMIN", "STEWARD"})
    @PostMapping("/dimensions")
    public Map<String, Object> createDimension(@RequestBody Map<String, Object> body) {
        return catalog.createDimension(body);
    }

    @RequireRole({"ADMIN", "STEWARD"})
    @PutMapping("/dimensions/{id}")
    public Map<String, Object> updateDimension(@PathVariable long id, @RequestBody Map<String, Object> body) {
        catalog.updateDimension(id, body);
        return Map.of("id", id);
    }

    @RequireRole({"ADMIN", "STEWARD"})
    @DeleteMapping("/dimensions/{id}")
    public Map<String, Object> deleteDimension(@PathVariable long id) {
        catalog.deleteDimension(id);
        return Map.of("id", id, "deleted", true);
    }
}
