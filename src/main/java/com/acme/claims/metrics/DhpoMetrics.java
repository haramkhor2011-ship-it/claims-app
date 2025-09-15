package com.acme.claims.metrics;

import io.micrometer.core.instrument.*;
import org.springframework.stereotype.Component;
import java.util.concurrent.TimeUnit;

@Component
public class DhpoMetrics {
    private final MeterRegistry reg;
    public DhpoMetrics(MeterRegistry reg){ this.reg = reg; }

    public void recordDownload(String facility, String mode, long bytes, long latencyMs){
        Tags t = Tags.of("facility", nv(facility), "mode", nv(mode));
        reg.counter("dhpo.download.count", t).increment();
        DistributionSummary.builder("dhpo.download.size.bytes").baseUnit("bytes").tags(t).register(reg).record(bytes);
        Timer.builder("dhpo.download.latency").tags(t).register(reg).record(latencyMs, TimeUnit.MILLISECONDS);
    }

    public void recordIngestion(String source, String mode, boolean ok, long durMs){
        Tags t = Tags.of("source", nv(source), "mode", nv(mode), "result", ok ? "ok" : "fail");
        reg.counter("ingestion.process.count", t).increment();
        Timer.builder("ingestion.process.duration").tags(t).register(reg).record(durMs, TimeUnit.MILLISECONDS);
    }

    public void recordAck(String facility, String fileId, boolean ok, String dhpoCode){
        Tags t = Tags.of("facility", nv(facility), "code", nv(dhpoCode), "result", ok ? "ok" : "fail");
        reg.counter("dhpo.ack.count", t).increment();
    }

    private static String nv(String s){ return (s==null||s.isBlank()) ? "unknown" : s; }
}
