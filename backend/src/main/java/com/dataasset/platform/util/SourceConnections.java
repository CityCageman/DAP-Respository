package com.dataasset.platform.util;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Map;

/**
 * 数据源连接工具：按 data_source 行拼 JDBC URL 并建立连接。
 * 支持 PostgreSQL / MySQL（Doris 走 MySQL 协议）/ InterSystems IRIS（db_name 即命名空间）。
 */
public final class SourceConnections {

    private SourceConnections() {
    }

    public static Connection open(Map<String, Object> ds) throws SQLException {
        String type = String.valueOf(ds.get("type")).toUpperCase();
        String host = str(ds.get("host"));
        int port = ds.get("port") == null ? defaultPort(type) : ((Number) ds.get("port")).intValue();
        String db = str(ds.get("db_name"));
        String url = url(type, host, port, db);
        DriverManager.setLoginTimeout(6);
        return DriverManager.getConnection(url, str(ds.get("username")), str(ds.get("password")));
    }

    public static int defaultPort(String type) {
        return switch (type.toUpperCase()) {
            case "MYSQL" -> 3306;
            case "DORIS" -> 9030;
            case "IRIS" -> 1972;
            default -> 5432;
        };
    }

    public static String url(String type, String host, int port, String db) {
        return switch (type.toUpperCase()) {
            // IRIS 的 db_name 即命名空间（Namespace），如 USER、PACS
            case "IRIS" -> "jdbc:IRIS://" + host + ":" + port + "/" + db;
            case "MYSQL", "DORIS" -> "jdbc:mysql://" + host + ":" + port + "/" + db
                    + "?useSSL=false&allowPublicKeyRetrieval=true&connectTimeout=5000";
            default -> "jdbc:postgresql://" + host + ":" + port + "/" + db + "?connectTimeout=5";
        };
    }

    public static String str(Object o) {
        return o == null ? "" : String.valueOf(o);
    }
}
