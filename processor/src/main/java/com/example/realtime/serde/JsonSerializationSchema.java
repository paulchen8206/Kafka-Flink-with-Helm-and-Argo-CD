package com.example.realtime.serde;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.flink.api.common.serialization.SerializationSchema;

public class JsonSerializationSchema<T> implements SerializationSchema<T> {

    private transient ObjectMapper objectMapper;

    @Override
    public byte[] serialize(T element) {
        try {
            if (objectMapper == null) {
                objectMapper = new ObjectMapper();
            }
            return objectMapper.writeValueAsBytes(element);
        } catch (JsonProcessingException exception) {
            throw new IllegalArgumentException("Unable to serialize record", exception);
        }
    }
}
