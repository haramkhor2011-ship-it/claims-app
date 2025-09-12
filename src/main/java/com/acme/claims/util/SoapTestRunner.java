package com.acme.claims.util;

import org.springframework.boot.CommandLineRunner;

//@Component
//@Slf4j
//@Profile("local")
public class SoapTestRunner implements CommandLineRunner {
    @Override
    public void run(String... args) throws Exception {

    }
//    private final IngestSearchedTransactionSoapClient ingestSearchedTransactionSoapClient;
//    private final FileDownloadCoordinator downloadCoord;
//    private final ClaimSubmissionPersisterInsertOnly claimSubmissionPersister;
//    private final RemittancePersisterInsertOnly remittancePersister;
//
//    public SoapTestRunner(IngestSearchedTransactionSoapClient ingestSearchedTransactionSoapClient,
//                          FileDownloadCoordinator downloadCoord, ClaimSubmissionPersisterInsertOnly claimSubmissionPersister, RemittancePersisterInsertOnly remittancePersister) {
//        this.ingestSearchedTransactionSoapClient = ingestSearchedTransactionSoapClient;
//        this.downloadCoord = downloadCoord;
//        this.claimSubmissionPersister = claimSubmissionPersister;
//        this.remittancePersister = remittancePersister;
//    }
//
//    @Override
//    public void run(String... args) throws Exception {
//        try {
//            System.out.println("🚀 Sending SOAP request...");
//            //String response = client.searchTransactionsRaw();
//            // below makes SOAP call to fetch response which will have fileid, filename etc..
//            String response = ingestSearchedTransactionSoapClient.callSearchTransactions();
//            // now we are parsing that response to get fileid, filename
//            SearchTransactionsParser.ParseResult parsed = SearchTransactionsParser.parseFileIds(response);
//
//            System.out.println("Found " + parsed.fileIds.size() + " file IDs.");
//
//            System.out.println("✅ SOAP Response:\n" + response);
//            // parsed record has a map of fileid with their name
//            Map<String, String> fileIdsWithName = parsed.getFileIds();
//            System.out.println("🔎 FileIDs found: " + fileIdsWithName.size());
//            if (fileIdsWithName.isEmpty()) return;
//
//            // 3) Async fan-out: download each file
//            // you need to go into this method call to see that we are downloading each file via fileid in async manner
//            // the downloaded file is parsed and stored, and return along with file id <fileid, payload(parsed)
//            Map<String, String> fileIdToXml = downloadCoord.fetchAll(fileIdsWithName);
//            System.out.println("✅ Downloads done. Map size = " + fileIdToXml.size());
//            int successfulDownloads = getSuccessCount(fileIdToXml);
//            int failedDownloads = fileIdToXml.size() - successfulDownloads;
//            // for successful download mark as true
//            log.info(STR."Success: \{successfulDownloads}, Failed: \{failedDownloads}");
//            fileIdToXml = getSuccessXmls(fileIdToXml);
//            // now we have successful response i.e. fileId for which we got success and parsed response
//            // now we need to convert each parsed xml into respective dto using respective mapper, then we are calling persist
//            fileIdToXml.forEach((fid, payload) -> {
//                if (payload.startsWith("ERROR:")) {
//                    // skip, or record a light row later when we enable file-tracking
//                    return;
//                }
//                try {
//                    Document doc = XmlUtil.parse(payload);
//                    String root = doc.getDocumentElement().getNodeName();
//                    if("Claim.Submission".equalsIgnoreCase(root)) {
//                        ClaimSubmissionDto claimSubmissionDto = XmlToClaimSubmissionDtoMapper.toDto(XmlUtil.parse(payload));
//                        claimSubmissionPersister.persist(getIngestionFileEntity(claimSubmissionDto, fid, fileIdsWithName, payload), claimSubmissionDto);
//                    } else if ("Remittance.Advice".equalsIgnoreCase(root)) {
//                        RemittanceAdviceDto remittanceAdviceDto = XmlToRemittanceDtoMapper.toDto(doc);
//                        remittancePersister.persist(getIngestionFileEntity(remittanceAdviceDto, fid, fileIdsWithName, payload), remittanceAdviceDto);
//                    }
//                    //ingestSearchedTransactionSoapClient.setTrueForSuccessfulDownloads(fid);
//                } catch (Exception e) {
//                    // log error; we can move to a DLQ/retry later
//                    log.error("Exception : {}", e.getMessage());
//                    System.err.println("Persist failed for " + fid + ": " + e.getMessage());
//                }
//            });
//
//            // 4) (Optional) Print a couple for sanity
////            fileIdToXml.entrySet().stream().limit(2).forEach(e -> {
////                System.out.println("— FileID: " + e.getKey());
////                System.out.println("  Payload (first 400 chars): " + e.getValue().substring(0, Math.min(400, e.getValue().length())));
////            });
//            summarizeResults(fileIdToXml);
//        } catch (Exception e) {
//            System.err.println("❌ SOAP call failed: " + e.getMessage());
//            e.printStackTrace();
//        }
//    }
//
//    private IngestionFileEntity getIngestionFileEntity(RemittanceAdviceDto remittanceAdviceDto, String fid, Map<String, String> fileIdsWithName, String payload) {
//        if(remittanceAdviceDto != null){
//            return IngestionFileEntity.builder()
//                    .fileId(fid)
//                    .fileName(fileIdsWithName.get(fid))
//                    .downloadMarked((short) 0)
//                    .xmlBytes(payload.getBytes())
//                    .senderId(remittanceAdviceDto.getSenderId())
//                    .transactionDate(remittanceAdviceDto.getTransactionDate())
//                    .receiverId(remittanceAdviceDto.getReceiverId())
//                    .recordCountHint(remittanceAdviceDto.getRecordCount())
//                    .build();
//        }
//        return  null;
//    }
//
//    private IngestionFileEntity getIngestionFileEntity(ClaimSubmissionDto claimSubmissionDto, String fid, Map<String, String> fileIdsWithName, String payload) {
//        if(claimSubmissionDto != null) {
//            return IngestionFileEntity.builder()
//                    .fileId(fid)
//                    .fileName(fileIdsWithName.get(fid))
//                    .downloadMarked((short) 0)
//                    .xmlBytes(payload.getBytes())
//                    .senderId(claimSubmissionDto.getSenderId())
//                    .transactionDate(claimSubmissionDto.getTransactionDate())
//                    .receiverId(claimSubmissionDto.getReceiverId())
//                    .recordCountHint(claimSubmissionDto.getRecordCount())
//                    .build();
//        }
//        return null;
//    }
//
//    private Map<String, String> getSuccessXmls(Map<String, String> fileIdToXml) {
//        if (CollectionUtils.isEmpty(fileIdToXml)) {
//            return Collections.emptyMap();
//        }
//
//        return fileIdToXml.entrySet()
//                .stream()
//                .filter(e -> {
//                    String v = e.getValue();
//                    return v != null && !v.startsWith("ERROR"); // keep only non-ERROR
//                })
//                .collect(Collectors.toMap(
//                        Map.Entry::getKey,
//                        Map.Entry::getValue,
//                        (a, b) -> a,
//                        LinkedHashMap::new
//                ));
//    }
//
//
//    private int getSuccessCount(Map<String, String> fileIdToXml) {
//        if (!CollectionUtils.isEmpty(fileIdToXml.values())) {
//            long errorCount = fileIdToXml.values().stream()
//                    .filter(v -> v != null && v.startsWith("ERROR:"))
//                    .count();
//            return Math.toIntExact(fileIdToXml.size() - errorCount);
//        }
//        return 0;
//    }
//
//    public void summarizeResults(Map<String, String> fileIdToResponse) {
//        long errorCount = fileIdToResponse.values().stream()
//                .filter(v -> v != null && v.startsWith("ERROR:"))
//                .count();
//
//        long successCount = fileIdToResponse.size() - errorCount;
//
//        System.out.println("📊 Download summary:");
//        System.out.println("   ✅ Success: " + successCount);
//        System.out.println("   ❌ Failed : " + errorCount);
//    }

}
