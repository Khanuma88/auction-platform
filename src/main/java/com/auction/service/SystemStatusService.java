package com.auction.service;

import com.auction.repository.SystemStatusRepository;
import org.springframework.stereotype.Service;

@Service
public class SystemStatusService {

    private final SystemStatusRepository repository;

    public SystemStatusService(SystemStatusRepository repository) {
        this.repository = repository;
    }

    public SystemStatus currentStatus() {
        return new SystemStatus(
                repository.databaseVersion(),
                repository.appliedMigrations(),
                repository.categoryCount());
    }

    public record SystemStatus(String databaseVersion, int appliedMigrations, int categoryCount) {
    }
}
