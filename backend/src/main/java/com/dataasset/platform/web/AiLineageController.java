package com.dataasset.platform.web;

import com.dataasset.platform.service.AiLineageService;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/** AI 血缘推断：LLM 根据元数据语义推断表级血缘 */
@RestController
@RequestMapping("/api/v2/lineage/ai")
public class AiLineageController {

    private final AiLineageService service;

    public AiLineageController(AiLineageService service) {
        this.service = service;
    }

    public record InferReq(String schemaName, List<Long> tableIds, Integer limit, boolean save) {
    }

    @PostMapping("/infer")
    public AiLineageService.InferResult infer(@RequestBody InferReq req) {
        return service.infer(req.schemaName(), req.tableIds(), req.limit(), req.save());
    }
}
