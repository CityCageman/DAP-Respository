package com.dataasset.platform.web;

import com.dataasset.platform.service.ApiGatewayService;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 对外数据服务网关：POST /openapi/v1/{apiCode}，鉴权头 X-App-Id / X-App-Key。
 */
@RestController
@RequestMapping("/openapi/v1")
public class OpenApiController {

    private final ApiGatewayService gateway;

    public OpenApiController(ApiGatewayService gateway) {
        this.gateway = gateway;
    }

    @PostMapping("/{apiCode}")
    public Map<String, Object> call(@PathVariable String apiCode,
                                    @RequestHeader(value = "X-App-Id", required = false) String appId,
                                    @RequestHeader(value = "X-App-Key", required = false) String appKey,
                                    jakarta.servlet.http.HttpServletRequest request,
                                    @RequestBody(required = false) Map<String, Object> params) {
        String ip = request.getRemoteAddr();
        ApiGatewayService.InvokeResult r = gateway.invoke(apiCode, appId, appKey, "OPEN",
                params, ip, "EXTERNAL");
        Map<String, Object> out = new java.util.LinkedHashMap<>();
        out.put("code", r.code());
        out.put("message", r.message());
        out.put("data", r.data());
        out.put("meta", r.meta());
        return out;
    }

    @GetMapping("/{apiCode}")
    public Map<String, Object> callGet(@PathVariable String apiCode,
                                       @RequestHeader(value = "X-App-Id", required = false) String appId,
                                       @RequestHeader(value = "X-App-Key", required = false) String appKey,
                                       jakarta.servlet.http.HttpServletRequest request,
                                       @RequestParam Map<String, Object> params) {
        String ip = request.getRemoteAddr();
        ApiGatewayService.InvokeResult r = gateway.invoke(apiCode, appId, appKey, "OPEN",
                params, ip, "EXTERNAL");
        Map<String, Object> out = new java.util.LinkedHashMap<>();
        out.put("code", r.code());
        out.put("message", r.message());
        out.put("data", r.data());
        out.put("meta", r.meta());
        return out;
    }

    /** 网关探测（供前端展示连通性） */
    @GetMapping
    public List<String> root() {
        return List.of("数据服务网关。调用方式：POST /openapi/v1/{apiCode}，请求头 X-App-Id / X-App-Key");
    }
}
