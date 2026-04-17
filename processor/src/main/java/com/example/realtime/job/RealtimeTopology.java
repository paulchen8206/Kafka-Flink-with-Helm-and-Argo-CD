package com.example.realtime.job;

import com.example.realtime.config.RealtimeProperties;
import com.example.realtime.model.CustomerSalesProjection;
import com.example.realtime.model.SalesOrderEvent;
import com.example.realtime.model.SalesOrderLineItemProjection;
import com.example.realtime.model.SalesOrderProjection;
import com.example.realtime.serde.JsonDeserializationSchema;
import com.example.realtime.serde.JsonSerializationSchema;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.serialization.SerializationSchema;
import org.apache.flink.api.common.typeinfo.TypeInformation;
import org.apache.flink.connector.kafka.sink.KafkaRecordSerializationSchema;
import org.apache.flink.connector.kafka.sink.KafkaSink;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.springframework.stereotype.Component;

@Component
public class RealtimeTopology {

    private final RealtimeProperties properties;

    public RealtimeTopology(RealtimeProperties properties) {
        this.properties = properties;
    }

    public void start() throws Exception {
        StreamExecutionEnvironment environment = StreamExecutionEnvironment.getExecutionEnvironment();
        environment.enableCheckpointing(properties.getCheckpointIntervalMs());

        KafkaSource<SalesOrderEvent> rawSalesOrderSource = KafkaSource.<SalesOrderEvent>builder()
                .setBootstrapServers(properties.getKafkaBootstrapServers())
                .setTopics(properties.getRawSalesOrdersTopic())
                .setGroupId(properties.getConsumerGroupId())
                .setStartingOffsets(OffsetsInitializer.latest())
                .setValueOnlyDeserializer(new JsonDeserializationSchema<>(SalesOrderEvent.class))
                .build();

        DataStream<SalesOrderEvent> rawOrders = environment
                .fromSource(rawSalesOrderSource, WatermarkStrategy.noWatermarks(), "raw-sales-orders")
                .uid("raw-sales-orders-source");

        DataStream<SalesOrderProjection> salesOrders = rawOrders
                .map(SalesOrderProjection::fromEvent)
                .returns(TypeInformation.of(SalesOrderProjection.class))
                .name("sales-order-projection");

        DataStream<SalesOrderLineItemProjection> salesOrderLineItems = rawOrders
                .flatMap((SalesOrderEvent event, org.apache.flink.util.Collector<SalesOrderLineItemProjection> collector) -> {
                    for (SalesOrderEvent.LineItem lineItem : event.getLineItems()) {
                        collector.collect(SalesOrderLineItemProjection.fromEvent(event, lineItem));
                    }
                })
                .returns(TypeInformation.of(SalesOrderLineItemProjection.class))
                .name("sales-order-line-item-projection");

        DataStream<CustomerSalesProjection> customerSales = rawOrders
                .map(CustomerSalesProjection::fromOrder)
                .returns(TypeInformation.of(CustomerSalesProjection.class))
                .keyBy(CustomerSalesProjection::getCustomerId)
                .reduce(CustomerSalesProjection::accumulate)
                .name("customer-sales-aggregation");

        salesOrders.sinkTo(buildKafkaSink(properties.getSalesOrderTopic())).name("sales-order-sink");
        salesOrderLineItems.sinkTo(buildKafkaSink(properties.getSalesOrderLineItemTopic())).name("sales-order-line-item-sink");
        customerSales.sinkTo(buildKafkaSink(properties.getCustomerSalesTopic())).name("customer-sales-sink");

        environment.execute("realtime-sales-topology");
    }

    private <T> KafkaSink<T> buildKafkaSink(String topic) {
                SerializationSchema<T> serializationSchema = new JsonSerializationSchema<>();
        return KafkaSink.<T>builder()
                .setBootstrapServers(properties.getKafkaBootstrapServers())
                .setRecordSerializer(KafkaRecordSerializationSchema.<T>builder()
                        .setTopic(topic)
                        .setValueSerializationSchema(serializationSchema)
                        .build())
                .build();
    }
}
