package com.dataasset.platform.config;

import com.dataasset.platform.service.TokenService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.Arrays;

/**
 * 登录校验 + 角色校验拦截器。
 * 白名单：/api/auth/login、/api/auth/status。
 */
@Component
public class AuthInterceptor implements HandlerInterceptor {

    private static final java.util.Set<String> WHITELIST =
            java.util.Set.of("/api/auth/login", "/api/auth/status");

    private final TokenService tokenService;

    public AuthInterceptor(TokenService tokenService) {
        this.tokenService = tokenService;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
            throws Exception {
        if (HttpMethod.OPTIONS.matches(request.getMethod())) {
            return true;
        }
        if (!(handler instanceof HandlerMethod hm) || WHITELIST.contains(request.getRequestURI())) {
            return true;
        }

        String token = request.getHeader("Authorization");
        if (token != null && token.startsWith("Bearer ")) {
            token = token.substring(7);
        } else {
            token = request.getHeader("X-Auth-Token");
        }
        AuthContext.CurrentUser user = tokenService.validate(token);
        if (user == null) {
            writeJson(response, 401, "未登录或登录已过期，请重新登录");
            return false;
        }
        AuthContext.set(user);

        RequireRole require = hm.getMethodAnnotation(RequireRole.class);
        if (require == null) {
            require = hm.getBeanType().getAnnotation(RequireRole.class);
        }
        if (require != null && require.value().length > 0
                && Arrays.stream(require.value()).noneMatch(r -> r.equals(user.role()))) {
            writeJson(response, 403, "权限不足：该操作需要角色 " + String.join("/", require.value()), user.role());
            return false;
        }
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler,
                                Exception ex) {
        AuthContext.clear();
    }

    private void writeJson(HttpServletResponse response, int status, String message, String... extra)
            throws Exception {
        response.setStatus(status);
        response.setContentType("application/json;charset=UTF-8");
        String role = extra.length > 0 ? extra[0] : "";
        response.getWriter().write("{\"success\":false,\"message\":\"%s\",\"role\":\"%s\"}"
                .formatted(message, role));
    }
}
