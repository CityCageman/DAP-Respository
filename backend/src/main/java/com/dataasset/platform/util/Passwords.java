package com.dataasset.platform.util;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.HexFormat;

/**
 * 密码哈希工具：SHA-256(salt + password)。
 */
public final class Passwords {

    private static final SecureRandom RANDOM = new SecureRandom();

    private Passwords() {
    }

    public static String sha256(String text) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(md.digest(text.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    public static String randomSalt() {
        return randomHex(8);
    }

    /** 生成 n 字节的十六进制随机串（用于盐值 / API Key） */
    public static String randomHex(int bytes) {
        byte[] buf = new byte[bytes];
        RANDOM.nextBytes(buf);
        return HexFormat.of().formatHex(buf);
    }

    public static boolean matches(String rawPassword, String salt, String storedHash) {
        return sha256(salt + rawPassword).equalsIgnoreCase(storedHash);
    }
}
