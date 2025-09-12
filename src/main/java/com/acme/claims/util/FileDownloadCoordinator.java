package com.acme.claims.util;

/**
 * Coordinates downloading of claim/remittance XML files in parallel.
 *
 * - Launches async downloads for each fileId using FileFetchService.
 * - Limits concurrent in-flight requests via a Semaphore (default 200).
 * - Waits for all downloads to finish.
 * - Returns a Map<fileId, xmlOrError>.
 *
 * Guarantees:
 *   • For every input fileId, there will be exactly one output entry.
 *   • Even if a download fails, the map contains fileId → "ERROR: ..." entry.
 */
//@Service
//@RequiredArgsConstructor
public class FileDownloadCoordinator {
//
//    private final FileFetchService fetchService;
//    private final Semaphore bulkhead = new Semaphore(200); // at most 200 inflight
//
//    /**
//     * Downloads all files by fileId, in parallel, with bulkhead limit.
//     *
//     * @param fileIdsWithName Map<fileId, fileName> from SearchTransactionsParser
//     * @return Map<fileId, xmlOrError>
//     */
//    public Map<String, String> fetchAll(Map<String, String> fileIdsWithName) {
//        if (fileIdsWithName == null || fileIdsWithName.isEmpty()) {
//            return Collections.emptyMap();
//        }
//
//        // Maintain the order of fileIds so we can recover keys if futures fail
//        List<String> order = new ArrayList<>(fileIdsWithName.keySet());
//
//        // Launch async calls
//        List<CompletableFuture<Map.Entry<String, String>>> futures = new ArrayList<>();
//        for (String fileId : order) {
//            try {
//                bulkhead.acquire();
//                futures.add(fetchService.fetchFile(fileId)
//                        .whenComplete((r, t) -> bulkhead.release()));
//            } catch (InterruptedException e) {
//                Thread.currentThread().interrupt();
//                futures.add(CompletableFuture.completedFuture(
//                        Map.entry(fileId, "ERROR: <interrupted/>")));
//            }
//        }
//
//        // Wait for all
//        CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();
//
//        // Collect results
//        Map<String, String> out = new LinkedHashMap<>();
//        for (int i = 0; i < futures.size(); i++) {
//            String fileId = order.get(i); // fallback key if future fails
//            CompletableFuture<Map.Entry<String, String>> f = futures.get(i);
//            try {
//                Map.Entry<String, String> e = f.get(); // already completed
//                out.put(e.getKey(), e.getValue());
//            } catch (Exception ex) {
//                out.put(fileId, "ERROR: <error>" + ex.getMessage() + "</error>");
//            }
//        }
//        return out;
//    }
}
