package com.dataasset.platform.web;

import com.dataasset.platform.config.AuthContext;
import com.dataasset.platform.config.RequireRole;
import com.dataasset.platform.service.TokenService;
import com.dataasset.platform.util.Passwords;
import com.dataasset.platform.util.Rows;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final JdbcTemplate jdbc;
    private final TokenService tokenService;

    public AuthController(JdbcTemplate jdbc, TokenService tokenService) {
        this.jdbc = jdbc;
        this.tokenService = tokenService;
    }

    @PostMapping("/login")
    public Map<String, Object> login(@RequestBody Map<String, String> body) {
        String username = body.getOrDefault("username", "").trim();
        String password = body.getOrDefault("password", "");
        if (username.isEmpty() || password.isEmpty()) {
            throw new IllegalArgumentException("请输入用户名和密码");
        }
        List<Map<String, Object>> rows = jdbc.queryForList(
                "select * from sys_user where username = ? and status = 'ACTIVE'", username);
        if (rows.isEmpty()) {
            throw new IllegalArgumentException("用户不存在或已被禁用");
        }
        Map<String, Object> u = rows.getFirst();
        if (!Passwords.matches(password, String.valueOf(u.get("salt")), String.valueOf(u.get("password_hash")))) {
            throw new IllegalArgumentException("用户名或密码错误");
        }
        jdbc.update("update sys_user set last_login_at = now() where id = ?", u.get("id"));

        AuthContext.CurrentUser user = new AuthContext.CurrentUser(
                ((Number) u.get("id")).longValue(),
                String.valueOf(u.get("username")),
                String.valueOf(u.get("display_name")),
                String.valueOf(u.get("role")),
                u.get("department") == null ? "" : String.valueOf(u.get("department")));
        String token = tokenService.issue(user);

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("token", token);
        out.put("user", Rows.camel(Map.of(
                "id", user.userId(), "username", user.username(),
                "displayName", user.displayName(), "role", user.role(),
                "department", user.department())));
        out.put("permissions", permissions(user.role()));
        return out;
    }

    @GetMapping("/me")
    public Map<String, Object> me() {
        AuthContext.CurrentUser user = AuthContext.get();
        return Map.of("user", Rows.camel(Map.of(
                "id", user.userId(), "username", user.username(),
                "displayName", user.displayName(), "role", user.role(),
                "department", user.department())), "permissions", permissions(user.role()));
    }

    @PostMapping("/logout")
    public Map<String, Object> logout(@RequestHeader(value = "Authorization", required = false) String auth) {
        if (auth != null && auth.startsWith("Bearer ")) {
            tokenService.revoke(auth.substring(7));
        }
        return Map.of("success", true);
    }

    /** 前端启动时探测后端是否在线（免登录） */
    @GetMapping("/status")
    public Map<String, Object> status() {
        return Map.of("online", true);
    }

    // ---------------------- 用户管理（仅 ADMIN） ----------------------

    @RequireRole("ADMIN")
    @GetMapping("/users")
    public List<Map<String, Object>> users() {
        return Rows.camel(jdbc.queryForList("""
                select id, username, display_name, role, department, status, last_login_at, created_at
                from sys_user order by id
                """));
    }

    public record UserReq(String username, String password, String displayName, String role,
                          String department, String status) {
    }

    @RequireRole("ADMIN")
    @PostMapping("/users")
    public Map<String, Object> createUser(@RequestBody UserReq req) {
        String salt = Passwords.randomSalt();
        String pwd = req.password() == null || req.password().isBlank() ? "123456" : req.password();
        Long id = jdbc.queryForObject("""
                insert into sys_user(username, password_hash, salt, display_name, role, department, status)
                values (?,?,?,?,?,?, coalesce(?, 'ACTIVE')) returning id
                """, Long.class, req.username(), Passwords.sha256(salt + pwd), salt,
                req.displayName(), req.role(), req.department(), req.status());
        return Map.of("id", id);
    }

    @RequireRole("ADMIN")
    @PutMapping("/users/{id}")
    public Map<String, Object> updateUser(@PathVariable long id, @RequestBody UserReq req) {
        jdbc.update("""
                update sys_user set display_name = coalesce(?, display_name), role = coalesce(?, role),
                       department = coalesce(?, department), status = coalesce(?, status)
                where id = ?
                """, req.displayName(), req.role(), req.department(), req.status(), id);
        if (req.password() != null && !req.password().isBlank()) {
            String salt = Passwords.randomSalt();
            jdbc.update("update sys_user set password_hash = ?, salt = ? where id = ?",
                    Passwords.sha256(salt + req.password()), salt, id);
        }
        return Map.of("id", id);
    }

    @RequireRole("ADMIN")
    @DeleteMapping("/users/{id}")
    public Map<String, Object> deleteUser(@PathVariable long id) {
        AuthContext.CurrentUser me = AuthContext.get();
        if (me.userId() == id) {
            throw new IllegalArgumentException("不能删除自己当前登录的账号");
        }
        jdbc.update("delete from sys_user where id = ?", id);
        return Map.of("deleted", id);
    }

    /** 各角色可访问的菜单编码 */
    /** 各角色可访问的菜单编码（数据资产管理平台：治理域） */
    private static List<String> permissions(String role) {
        return switch (role) {
            case "ADMIN" -> List.of("dashboard", "assets", "catalog", "metadata", "lineage", "standards",
                    "quality", "security", "dataservice", "users");
            case "STEWARD" -> List.of("dashboard", "assets", "catalog", "metadata", "lineage", "standards",
                    "quality", "security", "dataservice");
            default -> List.of("dashboard", "assets", "catalog", "metadata", "lineage", "standards", "quality");
        };
    }
}
