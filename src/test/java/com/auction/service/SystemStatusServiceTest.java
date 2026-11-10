package com.auction.service;

import com.auction.repository.SystemStatusRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SystemStatusServiceTest {

    @Mock
    private SystemStatusRepository repository;

    @InjectMocks
    private SystemStatusService service;

    @Test
    void currentStatusCombinesRepositoryValues() {
        when(repository.databaseVersion()).thenReturn("PostgreSQL 17.0");
        when(repository.appliedMigrations()).thenReturn(2);
        when(repository.categoryCount()).thenReturn(10);

        var status = service.currentStatus();

        assertThat(status.databaseVersion()).isEqualTo("PostgreSQL 17.0");
        assertThat(status.appliedMigrations()).isEqualTo(2);
        assertThat(status.categoryCount()).isEqualTo(10);
    }
}
