package com.dataasset.platform.service;

import com.dataasset.platform.config.AuthContext.CurrentUser;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 登录令牌管理（内存版，重启即失效，演示够用）。
 * 生产环境应替换为 Redis + JWT。
 */
@Service
public class TokenService {

    private static final long TTL_MS = 12 * 3600 * 1000L;

    private record Session(CurrentUser user, long expiresAt) {
    }

    private final Map<String, Session> sessions = new ConcurrentHashMap<>();

    public String issue(CurrentUser user) {
        String token = java.util.UUID.randomUUID().toString().replace("-", "");
        sessions.put(token, new Session(user, System.currentTimeMillis() + TTL_MS));
        return token;
    }

    /** 校验 token，过期或不存在返回 null */
    public CurrentUser validate(String token) {
        if (token == null || token.isBlank()) {
            return null;
        }
        Session s = sessions.get(token);
        if (s == null) {
            return null;
        }
        if (System.currentTimeMillis() > s.expiresAt()) {
            sessions.remove(token);
            return null;
        }
        return s.user();
    }

    public void revoke(String token) {
        if (token != null) {
            sessions.remove(token);
        }
    }
}
