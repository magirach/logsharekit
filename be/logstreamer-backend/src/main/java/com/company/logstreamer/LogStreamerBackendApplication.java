package com.company.logstreamer;

import com.company.logstreamer.push.config.ApnsProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.scheduling.annotation.EnableScheduling;

@EnableScheduling
@SpringBootApplication
@EnableConfigurationProperties(ApnsProperties.class)
public class LogStreamerBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(LogStreamerBackendApplication.class, args);
    }
}
