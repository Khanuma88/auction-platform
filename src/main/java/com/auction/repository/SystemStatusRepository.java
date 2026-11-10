package com.auction.repository;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
public class SystemStatusRepository {

    private final JdbcClient jdbc;

    public SystemStatusRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public String databaseVersion() {
        return jdbc.sql("SELECT version()").query(String.class).single();
    }

    public int appliedMigrations() {
        return jdbc.sql("SELECT count(*) FROM flyway_schema_history WHERE success = TRUE")
                .query(Integer.class).single();
    }

    public int categoryCount() {
        return jdbc.sql("SELECT count(*) FROM category").query(Integer.class).single();
    }
}
