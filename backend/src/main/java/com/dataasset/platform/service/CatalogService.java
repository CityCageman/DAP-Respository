package com.dataasset.platform.service;

import com.dataasset.platform.util.Rows;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 数据目录四层结构：数据中心 → 业务域 → 主题 → 模型（事实/维度）。
 * 域/模型层用 dam_model.model_domain / model_fact / model_dimension，
 * 主题/资产层用 dam_asset.asset_category / asset_info。
 * 所有查询统一过滤软删除（deleted_at is null）。
 */
@Service
public class CatalogService {

    private final JdbcTemplate jdbc;

    public CatalogService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // ---------------- 目录树 ----------------

    /** 域 + 模型树（数据中心/业务域/模型三级） */
    public List<Map<String, Object>> domainTree() {
        List<Map<String, Object>> domains = Rows.camel(jdbc.queryForList("""
                select id, domain_code, domain_name, parent_id, description, sort_order
                from dam_model.model_domain where deleted_at is null
                order by coalesce(parent_id, id), sort_order, id
                """));
        List<Map<String, Object>> facts = Rows.camel(jdbc.queryForList("""
                select f.id, f.domain_id, f.fact_code, f.fact_name, f.source_table_id,
                       f.granularity, f.description, t.table_name as source_table_name,
                       t.table_comment as source_table_comment
                from dam_model.model_fact f
                left join dam_metadata.metadata_table t on t.id = f.source_table_id
                where f.deleted_at is null
                order by f.domain_id, f.fact_code
                """));
        List<Map<String, Object>> dims = Rows.camel(jdbc.queryForList("""
                select d.id, d.domain_id, d.dimension_code, d.dimension_name, d.source_table_id,
                       d.description, t.table_name as source_table_name,
                       t.table_comment as source_table_comment
                from dam_model.model_dimension d
                left join dam_metadata.metadata_table t on t.id = d.source_table_id
                where d.deleted_at is null
                order by d.domain_id, d.dimension_code
                """));

        // 组装：先建所有域节点，再挂父子
        Map<Long, Map<String, Object>> nodeById = new LinkedHashMap<>();
        for (Map<String, Object> d : domains) {
            Map<String, Object> node = new LinkedHashMap<>(d);
            node.put("type", "DOMAIN");
            node.put("children", new ArrayList<Map<String, Object>>());
            nodeById.put(((Number) d.get("id")).longValue(), node);
        }
        // 模型挂到域节点
        for (Map<String, Object> f : facts) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", f.get("id"));
            m.put("code", f.get("factCode"));
            m.put("name", f.get("factName"));
            m.put("type", "FACT");
            m.put("domainId", f.get("domainId"));
            m.put("granularity", f.get("granularity"));
            m.put("description", f.get("description"));
            m.put("sourceTableId", f.get("sourceTableId"));
            m.put("sourceTableName", f.get("sourceTableName"));
            m.put("sourceTableComment", f.get("sourceTableComment"));
            attach(nodeById, ((Number) f.get("domainId")).longValue(), m);
        }
        for (Map<String, Object> d : dims) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", d.get("id"));
            m.put("code", d.get("dimensionCode"));
            m.put("name", d.get("dimensionName"));
            m.put("type", "DIMENSION");
            m.put("domainId", d.get("domainId"));
            m.put("description", d.get("description"));
            m.put("sourceTableId", d.get("sourceTableId"));
            m.put("sourceTableName", d.get("sourceTableName"));
            m.put("sourceTableComment", d.get("sourceTableComment"));
            attach(nodeById, ((Number) d.get("domainId")).longValue(), m);
        }
        // 父子连接
        List<Map<String, Object>> roots = new ArrayList<>();
        for (Map<String, Object> d : domains) {
            long id = ((Number) d.get("id")).longValue();
            Object parentObj = d.get("parentId");
            if (parentObj != null && nodeById.containsKey(((Number) parentObj).longValue())) {
                attach(nodeById, ((Number) parentObj).longValue(), nodeById.get(id));
            } else {
                roots.add(nodeById.get(id));
            }
        }
        return roots;
    }

    @SuppressWarnings("unchecked")
    private void attach(Map<Long, Map<String, Object>> nodes, long domainId, Map<String, Object> child) {
        Map<String, Object> parent = nodes.get(domainId);
        if (parent != null) {
            ((List<Map<String, Object>>) parent.get("children")).add(child);
        }
    }

    /** 主题/资产分类树（asset_category），带资产计数 */
    public List<Map<String, Object>> categoryTree() {
        List<Map<String, Object>> cats = Rows.camel(jdbc.queryForList("""
                select c.id, c.category_code, c.category_name, c.parent_id, c.tree_level,
                       c.category_path, c.description, c.sort_order,
                       (select count(*) from dam_asset.asset_info a
                         where a.category_id = c.id and a.deleted_at is null) as asset_count
                from dam_asset.asset_category c
                where c.deleted_at is null
                order by c.tree_level, c.sort_order, c.id
                """));
        Map<Long, Map<String, Object>> byId = new LinkedHashMap<>();
        for (Map<String, Object> c : cats) {
            Map<String, Object> node = new LinkedHashMap<>(c);
            node.put("children", new ArrayList<Map<String, Object>>());
            byId.put(((Number) c.get("id")).longValue(), node);
        }
        List<Map<String, Object>> roots = new ArrayList<>();
        for (Map<String, Object> c : cats) {
            Object parentObj = c.get("parentId");
            if (parentObj != null && byId.containsKey(((Number) parentObj).longValue())) {
                long pid = ((Number) parentObj).longValue();
                Map<String, Object> parent = byId.get(pid);
                ((List<Map<String, Object>>) parent.get("children")).add(byId.get(((Number) c.get("id")).longValue()));
            } else {
                roots.add(byId.get(((Number) c.get("id")).longValue()));
            }
        }
        return roots;
    }

    /** 某分类下的资产列表 */
    public List<Map<String, Object>> assetsByCategory(long categoryId) {
        return Rows.camel(jdbc.queryForList("""
                select a.id, a.asset_code, a.asset_name, a.description, a.quality_score,
                       a.published_status, a.published_at, a.storage_location,
                       c.category_name, mt.table_name, ds.ds_name
                from dam_asset.asset_info a
                left join dam_asset.asset_category c on c.id = a.category_id
                left join dam_metadata.metadata_table mt on mt.id = a.source_metadata_id
                left join dam_metadata.metadata_datasource ds on ds.id = a.data_source_id
                where a.category_id = ? and a.deleted_at is null
                order by a.asset_code
                """, categoryId));
    }

    // ---------------- 域 CRUD ----------------

    public Map<String, Object> createDomain(Map<String, Object> body) {
        String code = req(body, "domainCode");
        String name = req(body, "domainName");
        Long parentId = body.get("parentId") == null ? null : ((Number) body.get("parentId")).longValue();
        int sortOrder = body.get("sortOrder") == null ? 0 : ((Number) body.get("sortOrder")).intValue();
        String description = str(body.get("description"));
        if (count("dam_model.model_domain", "domain_code", code) > 0) {
            throw new IllegalArgumentException("域编码已存在：" + code);
        }
        long id = jdbc.queryForObject("""
                insert into dam_model.model_domain(domain_code, domain_name, parent_id, description, sort_order)
                values (?,?,?,?,?) returning id
                """, Long.class, code, name, parentId, description, sortOrder);
        return Map.of("id", id);
    }

    public void updateDomain(long id, Map<String, Object> body) {
        Map<String, Object> row = mustExist("dam_model.model_domain", id, "域");
        jdbc.update("""
                update dam_model.model_domain set domain_name = ?, description = ?, sort_order = ?, updated_by = '平台', updated_at = now()
                where id = ?
                """, body.get("domainName") != null ? body.get("domainName") : row.get("domain_name"),
                body.get("description") != null ? body.get("description") : row.get("description"),
                body.get("sortOrder") != null ? ((Number) body.get("sortOrder")).intValue() : ((Number) row.get("sort_order")).intValue(),
                id);
    }

    public void deleteDomain(long id) {
        mustExist("dam_model.model_domain", id, "域");
        int children = jdbc.queryForObject(
                "select count(*) from dam_model.model_domain where parent_id = ? and deleted_at is null", Integer.class, id);
        if (children > 0) {
            throw new IllegalStateException("存在 " + children + " 个下级域，请先删除下级域");
        }
        int models = jdbc.queryForObject("""
                select (select count(*) from dam_model.model_fact where domain_id = ? and deleted_at is null)
                     + (select count(*) from dam_model.model_dimension where domain_id = ? and deleted_at is null)
                """, Integer.class, id, id);
        if (models > 0) {
            throw new IllegalStateException("域下还有 " + models + " 个模型，请先删除模型");
        }
        jdbc.update("update dam_model.model_domain set deleted_at = now(), updated_by = '平台' where id = ?", id);
    }

    // ---------------- 模型 CRUD ----------------

    public Map<String, Object> createFact(Map<String, Object> body) {
        long domainId = ((Number) body.get("domainId")).longValue();
        mustExist("dam_model.model_domain", domainId, "域");
        String code = req(body, "factCode");
        String name = req(body, "factName");
        if (jdbc.queryForObject(
                "select count(*) from dam_model.model_fact where fact_code = ? and deleted_at is null", Integer.class, code) > 0) {
            throw new IllegalArgumentException("事实编码已存在：" + code);
        }
        long id = jdbc.queryForObject("""
                insert into dam_model.model_fact(domain_id, fact_code, fact_name, source_table_id, granularity, description)
                values (?,?,?,?,?,?) returning id
                """, Long.class, domainId, code, name,
                body.get("sourceTableId") == null ? null : ((Number) body.get("sourceTableId")).longValue(),
                str(body.get("granularity")), str(body.get("description")));
        return Map.of("id", id);
    }

    public void updateFact(long id, Map<String, Object> body) {
        Map<String, Object> row = mustExist("dam_model.model_fact", id, "事实模型");
        jdbc.update("""
                update dam_model.model_fact set fact_name = ?, granularity = ?, description = ?,
                       source_table_id = ?, updated_by = '平台', updated_at = now()
                where id = ?
                """, body.get("factName") != null ? body.get("factName") : row.get("fact_name"),
                body.get("granularity") != null ? body.get("granularity") : row.get("granularity"),
                body.get("description") != null ? body.get("description") : row.get("description"),
                body.get("sourceTableId") != null ? ((Number) body.get("sourceTableId")).longValue() : row.get("source_table_id"),
                id);
    }

    public void deleteFact(long id) {
        mustExist("dam_model.model_fact", id, "事实模型");
        jdbc.update("update dam_model.model_fact set deleted_at = now(), updated_by = '平台' where id = ?", id);
    }

    public Map<String, Object> createDimension(Map<String, Object> body) {
        long domainId = ((Number) body.get("domainId")).longValue();
        mustExist("dam_model.model_domain", domainId, "域");
        String code = req(body, "dimensionCode");
        String name = req(body, "dimensionName");
        if (jdbc.queryForObject(
                "select count(*) from dam_model.model_dimension where dimension_code = ? and deleted_at is null",
                Integer.class, code) > 0) {
            throw new IllegalArgumentException("维度编码已存在：" + code);
        }
        long id = jdbc.queryForObject("""
                insert into dam_model.model_dimension(domain_id, dimension_code, dimension_name, source_table_id, description)
                values (?,?,?,?,?) returning id
                """, Long.class, domainId, code, name,
                body.get("sourceTableId") == null ? null : ((Number) body.get("sourceTableId")).longValue(),
                str(body.get("description")));
        return Map.of("id", id);
    }

    public void updateDimension(long id, Map<String, Object> body) {
        Map<String, Object> row = mustExist("dam_model.model_dimension", id, "维度模型");
        jdbc.update("""
                update dam_model.model_dimension set dimension_name = ?, description = ?, source_table_id = ?,
                       updated_by = '平台', updated_at = now()
                where id = ?
                """, body.get("dimensionName") != null ? body.get("dimensionName") : row.get("dimension_name"),
                body.get("description") != null ? body.get("description") : row.get("description"),
                body.get("sourceTableId") != null ? ((Number) body.get("sourceTableId")).longValue() : row.get("source_table_id"),
                id);
    }

    public void deleteDimension(long id) {
        mustExist("dam_model.model_dimension", id, "维度模型");
        jdbc.update("update dam_model.model_dimension set deleted_at = now(), updated_by = '平台' where id = ?", id);
    }

    // ---------------- 工具 ----------------

    private Map<String, Object> mustExist(String table, long id, String label) {
        Map<String, Object> row;
        try {
            row = jdbc.queryForMap("select * from " + table + " where id = ? and deleted_at is null", id);
        } catch (Exception e) {
            throw new IllegalArgumentException(label + "不存在或已删除：id=" + id);
        }
        return row;
    }

    private int count(String table, String col, String val) {
        return jdbc.queryForObject(
                "select count(*) from " + table + " where " + col + " = ? and deleted_at is null",
                Integer.class, val);
    }

    private static String req(Map<String, Object> body, String key) {
        Object v = body.get(key);
        if (v == null || String.valueOf(v).isBlank()) {
            throw new IllegalArgumentException("缺少必填字段：" + key);
        }
        return String.valueOf(v).trim();
    }

    private static String str(Object o) {
        return o == null ? null : String.valueOf(o);
    }
}
