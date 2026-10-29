package com.dataasset.platform.service;

import com.dataasset.platform.config.AiProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;
import java.util.Map;

/**
 * AI 客户端：调用 OpenAI 兼容的 /chat/completions 接口。
 * 任意兼容端点可用：DeepSeek、通义、Kimi、one-api 网关、vLLM、Ollama(/v1) 等。
 */
@Service
public class AiChatClient {

    private static final Logger log = LoggerFactory.getLogger(AiChatClient.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final AiProperties props;
    private final HttpClient http;

    public AiChatClient(AiProperties props) {
        this.props = props;
        this.http = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
    }

    public boolean isAvailable() {
        return props.isEnabled() && notBlank(props.getBaseUrl()) && notBlank(props.getApiKey())
                && !String.valueOf(props.getApiKey()).contains("please-fill");
    }

    /** 单轮对话，返回模型文本输出；未启用或调用失败抛 IllegalStateException */
    public String chat(String systemPrompt, String userPrompt) {
        if (!isAvailable()) {
            throw new IllegalStateException("AI 未启用：请在 application.yml 的 ai 段配置 base-url / api-key / model 后将 ai.enabled 设为 true");
        }
        String url = props.getBaseUrl().replaceAll("/+$", "") + "/chat/completions";
        Map<String, Object> body = Map.of(
                "model", props.getModel(),
                "temperature", props.getTemperature(),
                "messages", List.of(
                        Map.of("role", "system", "content", systemPrompt),
                        Map.of("role", "user", "content", userPrompt)
                ));
        try {
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(props.getTimeoutSeconds()))
                    .header("Content-Type", "application/json")
                    .header("Authorization", "Bearer " + props.getApiKey())
                    .POST(HttpRequest.BodyPublishers.ofString(MAPPER.writeValueAsString(body)))
                    .build();
            HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString());
            if (resp.statusCode() != 200) {
                throw new IllegalStateException("AI 接口返回 " + resp.statusCode() + "：" + abbreviate(resp.body()));
            }
            JsonNode content = MAPPER.readTree(resp.body()).path("choices").path(0).path("message").path("content");
            if (content.isMissingNode() || content.asText().isBlank()) {
                throw new IllegalStateException("AI 返回内容为空");
            }
            return content.asText();
        } catch (IllegalStateException e) {
            throw e;
        } catch (Exception e) {
            log.error("AI 调用失败：{}", e.getMessage());
            throw new IllegalStateException("AI 调用失败：" + e.getMessage());
        }
    }

    /**
     * 从模型输出中提取 JSON：兼容 ```json 代码块包裹、前后废话文本。
     * 取第一个 '[' 或 '{' 到最后一个 ']' 或 '}' 之间的内容。
     */
    public static String extractJson(String text) {
        if (text == null) {
            return null;
        }
        String t = text.trim();
        int startArr = t.indexOf('[');
        int startObj = t.indexOf('{');
        int start;
        char close;
        if (startArr >= 0 && (startObj < 0 || startArr < startObj)) {
            start = startArr;
            close = ']';
        } else {
            start = startObj;
            close = '}';
        }
        if (start < 0) {
            throw new IllegalStateException("AI 输出中未找到 JSON：" + abbreviate(t));
        }
        int end = t.lastIndexOf(close);
        if (end <= start) {
            throw new IllegalStateException("AI 输出 JSON 不完整：" + abbreviate(t));
        }
        return t.substring(start, end + 1);
    }

    private static boolean notBlank(String s) {
        return s != null && !s.isBlank();
    }

    private static String abbreviate(String s) {
        if (s == null) return "";
        return s.length() > 300 ? s.substring(0, 300) + "..." : s;
    }
}
