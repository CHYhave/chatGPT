package com.have;

import io.github.asleepyfish.annotation.EnableChatGPT;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * @author Chen haoyu
 * @description
 * @date 2023/2/17
 */
@SpringBootApplication
@EnableChatGPT
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
