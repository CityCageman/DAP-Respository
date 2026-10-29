package com.dataasset.platform.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;

/**
 * 数据中台 OpenAPI 客户端（8081）。
 * 两个项目物理分离后，数据源连接统一由中台持有，本平台只做元数据采集与治理，
 * 需要连接信息时经此客户端拉取（不落本地、不维护连接串）。
 */
@Component
public class MidPlatformClient {

    private final RestClient rest;

    public MidPlatformClient(@Value("${mid.platform.base-url}") String baseUrl,
                             @Value("${mid.platform.token}") String token) {
        this.rest = RestClient.builder()
                .baseUrl(baseUrl)
                .defaultHeader("X-OpenAPI-Token", token)
                .build();
    }

    /** 中台数据源清单（含连接信息） */
    public List<Map<String, Object>> sources() {
        return rest.get().uri("/openapi/sources").retrieve()
                .body(new ParameterizedTypeReference<List<Map<String, Object>>>() {
                });
    }

    /** 单个数据源 */
    public Map<String, Object> source(long id) {
        return rest.get().uri("/openapi/sources/{id}", id).retrieve()
                .body(new ParameterizedTypeReference<Map<String, Object>>() {
                });
    }

    /** 中台数仓分层概况 */
    public List<Map<String, Object>> layers() {
        return rest.get().uri("/openapi/layers").retrieve()
                .body(new ParameterizedTypeReference<List<Map<String, Object>>>() {
                });
    }

    /** 中台运行指标（患者/就诊/采集任务/分层表数） */
    public Map<String, Object> stats() {
        return rest.get().uri("/openapi/stats").retrieve()
                .body(new ParameterizedTypeReference<Map<String, Object>>() {
                });
    }

    /** 中台患者360（数据服务网关对外发布用，场景固定 EXTERNAL） */
    @SuppressWarnings("unchecked")
    public Map<String, Object> patient360(Map<String, Object> params) {
        return rest.post().uri("/openapi/patient360")
                .body(params).retrieve()
                .body(new ParameterizedTypeReference<Map<String, Object>>() {
                });
    }

    public Map<String, Object> post(String path, Object body) {
        return rest.post().uri(path).body(body == null ? Map.of() : body).retrieve()
                .body(new ParameterizedTypeReference<Map<String, Object>>() {
                });
    }
}
