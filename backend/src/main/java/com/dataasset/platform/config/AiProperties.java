package com.dataasset.platform.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * AI 智能体配置（OpenAI 兼容接口）：血缘推断、元数据中文注释补全。
 * 支持 DeepSeek / 通义 / Kimi / one-api / vLLM / Ollama /v1 等任意 OpenAI 兼容端点。
 */
@Component
@ConfigurationProperties(prefix = "ai")
public class AiProperties {

    private boolean enabled;
    private String baseUrl = "https://api.deepseek.com/v1";
    private String apiKey;
    private String model = "deepseek-chat";
    private double temperature = 0.2;
    private int timeoutSeconds = 120;
    private int maxTablesPerBatch = 12;
    private boolean enrichOnSync = true;

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }
    public String getBaseUrl() { return baseUrl; }
    public void setBaseUrl(String baseUrl) { this.baseUrl = baseUrl; }
    public String getApiKey() { return apiKey; }
    public void setApiKey(String apiKey) { this.apiKey = apiKey; }
    public String getModel() { return model; }
    public void setModel(String model) { this.model = model; }
    public double getTemperature() { return temperature; }
    public void setTemperature(double temperature) { this.temperature = temperature; }
    public int getTimeoutSeconds() { return timeoutSeconds; }
    public void setTimeoutSeconds(int timeoutSeconds) { this.timeoutSeconds = timeoutSeconds; }
    public int getMaxTablesPerBatch() { return maxTablesPerBatch; }
    public void setMaxTablesPerBatch(int maxTablesPerBatch) { this.maxTablesPerBatch = maxTablesPerBatch; }
    public boolean isEnrichOnSync() { return enrichOnSync; }
    public void setEnrichOnSync(boolean enrichOnSync) { this.enrichOnSync = enrichOnSync; }
}
