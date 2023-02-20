package com.have.config;

import com.github.benmanes.caffeine.cache.*;
import lombok.extern.slf4j.Slf4j;
import org.checkerframework.checker.nullness.qual.NonNull;
import org.checkerframework.checker.nullness.qual.Nullable;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.concurrent.TimeUnit;

/**
 * @author Chen haoyu
 * @description
 * @date 2023/2/20
 */
@Configuration
@Slf4j
public class CaffeineConfiguration {

    @Bean
    public Cache<String, String> caffeine() {
        return Caffeine.newBuilder().maximumSize(6000).expireAfterAccess(10, TimeUnit.MINUTES)
                .expireAfterWrite(10, TimeUnit.MINUTES).removalListener(new RemovalListener<String, String>() {
                    @Override
                    public void onRemoval(@Nullable String key, @Nullable String value,
                                          @NonNull RemovalCause cause) {
                        if (value != null) {
                            log.info("user profile has removed. uid {}, value {}", key, value);
                        }
                    }
                }).build();
    }

}
