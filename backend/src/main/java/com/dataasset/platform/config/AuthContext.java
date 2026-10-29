package com.dataasset.platform.config;

/**
 * 当前请求的登录用户上下文（由 AuthInterceptor 填充，请求结束后清理）。
 */
public final class AuthContext {

    public record CurrentUser(long userId, String username, String displayName, String role, String department) {
        public boolean isAdmin() {
            return "ADMIN".equals(role);
        }
    }

    private static final ThreadLocal<CurrentUser> HOLDER = new ThreadLocal<>();

    private AuthContext() {
    }

    public static void set(CurrentUser user) {
        HOLDER.set(user);
    }

    public static CurrentUser get() {
        return HOLDER.get();
    }

    public static void clear() {
        HOLDER.remove();
    }
}
