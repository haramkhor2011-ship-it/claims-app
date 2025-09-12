/*
 * SSOT NOTICE — Ingestion Properties (Config)
 * Roots: Claim.Submission, Remittance.Advice
 * Purpose: Strongly-typed configuration for ingestion. Single I/O switch (stageToDisk).
 * NOTE: Not a @Component (to avoid duplicate beans). It is registered via @EnableConfigurationProperties.
 */
package com.acme.claims.ingestion.config;

import org.springframework.boot.context.properties.ConfigurationProperties;


@ConfigurationProperties(prefix = "claims.ingestion")
public class IngestionProperties {

    // Mode/profile hint (informational) // inline doc
    private String mode = "localfs";

    // Single switch: if true → stage/archive files on disk; false → purely in memory // inline doc
    private boolean stageToDisk = false;

    private Poll poll = new Poll();
    private Queue queue = new Queue();
    private Concurrency concurrency = new Concurrency();
    private Batch batch = new Batch();
    private Tx tx = new Tx();
    private Ack ack = new Ack();
    private HashSensitive hashSensitive = new HashSensitive();
    private LocalFs localfs = new LocalFs();
    private Soap soap = new Soap();

    /* ===== nested groups ===== */

    public static class Poll {
        private long fixedDelayMs = 2000L;
        public long getFixedDelayMs() { return fixedDelayMs; }
        public void setFixedDelayMs(long v) { this.fixedDelayMs = v; }
    }
    public static class Queue {
        private int capacity = 256;
        public int getCapacity() { return capacity; }
        public void setCapacity(int v) { this.capacity = v; }
    }
    public static class Concurrency {
        private int parserWorkers = 8;
        public int getParserWorkers() { return parserWorkers; }
        public void setParserWorkers(int v) { this.parserWorkers = v; }
    }
    public static class Batch {
        private int size = 1000;
        private int maxTxnSeconds = 5;
        public int getSize() { return size; }
        public void setSize(int v) { this.size = v; }
        public int getMaxTxnSeconds() { return maxTxnSeconds; }
        public void setMaxTxnSeconds(int v) { this.maxTxnSeconds = v; }
    }
    public static class Tx {
        private boolean perFile = true;
        private boolean perChunk = false;
        public boolean isPerFile() { return perFile; }
        public void setPerFile(boolean v) { this.perFile = v; }
        public boolean isPerChunk() { return perChunk; }
        public void setPerChunk(boolean v) { this.perChunk = v; }
    }
    public static class Ack {
        private boolean enabled = false;
        public boolean isEnabled() { return enabled; }
        public void setEnabled(boolean v) { this.enabled = v; }
    }
    public static class HashSensitive {
        private boolean enabled = true;
        public boolean isEnabled() { return enabled; }
        public void setEnabled(boolean v) { this.enabled = v; }
    }
    public static class LocalFs {
        private String readyDir = "./data/ready";
        private String archiveOkDir = "./data/archive/ok";
        private String archiveFailDir = "./data/archive/fail";
        public String getReadyDir() { return readyDir; }
        public void setReadyDir(String v) { this.readyDir = v; }
        public String getArchiveOkDir() { return archiveOkDir; }
        public void setArchiveOkDir(String v) { this.archiveOkDir = v; }
        public String getArchiveFailDir() { return archiveFailDir; }
        public void setArchiveFailDir(String v) { this.archiveFailDir = v; }
    }
    public static class Soap {
        private String endpoint;
        private String username;
        private String password;
        public String getEndpoint() { return endpoint; }
        public void setEndpoint(String v) { this.endpoint = v; }
        public String getUsername() { return username; }
        public void setUsername(String v) { this.username = v; }
        public String getPassword() { return password; }
        public void setPassword(String v) { this.password = v; }
    }

    /* ===== top-level getters/setters ===== */
    public String getMode() { return mode; }
    public void setMode(String mode) { this.mode = mode; }
    public boolean isStageToDisk() { return stageToDisk; }
    public void setStageToDisk(boolean stageToDisk) { this.stageToDisk = stageToDisk; }
    public Poll getPoll() { return poll; }
    public void setPoll(Poll poll) { this.poll = poll; }
    public Queue getQueue() { return queue; }
    public void setQueue(Queue queue) { this.queue = queue; }
    public Concurrency getConcurrency() { return concurrency; }
    public void setConcurrency(Concurrency concurrency) { this.concurrency = concurrency; }
    public Batch getBatch() { return batch; }
    public void setBatch(Batch batch) { this.batch = batch; }
    public Tx getTx() { return tx; }
    public void setTx(Tx tx) { this.tx = tx; }
    public Ack getAck() { return ack; }
    public void setAck(Ack ack) { this.ack = ack; }
    public HashSensitive getHashSensitive() { return hashSensitive; }
    public void setHashSensitive(HashSensitive hashSensitive) { this.hashSensitive = hashSensitive; }
    public LocalFs getLocalfs() { return localfs; }
    public void setLocalfs(LocalFs localfs) { this.localfs = localfs; }
    public Soap getSoap() { return soap; }
    public void setSoap(Soap soap) { this.soap = soap; }
}
