// src/main/java/com/acme/claims/soap/parse/ListFilesParser.java
package com.acme.claims.soap.parse;

import com.acme.claims.soap.util.Xmls;
import org.w3c.dom.Document;
import org.w3c.dom.NodeList;

import java.util.ArrayList;
import java.util.List;

public class ListFilesParser {

    public record FileRow(String fileId, String fileName, String senderId, String receiverId,
                          String transactionDate, Integer recordCount, Boolean isDownloaded) {}

    public record Result(int code, String errorMessage, List<FileRow> files) {}

    /**
     * Handles both GetNewTransactions (xmlTransactions) and SearchTransactions (foundTransactions).
     * Will look for either element; 'IsDownloaded' may be present only for Search.
     */
    public Result parse(String soapEnvelope) {
        try {
            Document d = Xmls.parse(soapEnvelope);
            int gCode = toInt(Xmls.gl(d, "GetNewTransactionsResult"));
            int sCode = toInt(Xmls.gl(d, "SearchTransactionsResult"));
            int code = (gCode != Integer.MIN_VALUE) ? gCode : (sCode != Integer.MIN_VALUE ? sCode : Integer.MIN_VALUE);
            String err = Xmls.gl(d, "errorMessage");

            String xml = Xmls.gl(d, "xmlTransaction");
            if (xml == null || xml.isBlank()) xml = Xmls.gl(d, "foundTransactions");

            List<FileRow> rows = new ArrayList<>();
            if (xml != null && !xml.isBlank() && xml.contains("<")) {
                Document li = Xmls.parse(xml);
                NodeList nl = li.getElementsByTagNameNS("*", "File");
                for (int i=0;i<nl.getLength();i++) {
                    var e = nl.item(i).getAttributes();
                    String fileId = e.getNamedItem("FileID").getNodeValue();
                    String fileName = attr(e,"FileName");
                    String sender = attr(e,"SenderID");
                    String receiver = attr(e,"ReceiverID");
                    String txDate = attr(e,"TransactionDate");
                    Integer rc = toIntOrNull(attr(e,"RecordCount"));
                    Boolean isDl = toBoolOrNull(attr(e,"IsDownloaded"));
                    rows.add(new FileRow(fileId, fileName, sender, receiver, txDate, rc, isDl));
                }
            }
            return new Result(code, err, rows);
        } catch (Exception ex) {
            throw new IllegalStateException("Parse list files failed: " + ex.getMessage(), ex);
        }
    }

    private static String attr(org.w3c.dom.NamedNodeMap a, String n) {
        var x = a.getNamedItem(n); return x==null?null:x.getNodeValue();
    }
    private static int toInt(String s){ try{ return Integer.parseInt(s==null?"":s.trim()); } catch(Exception e){ return Integer.MIN_VALUE; } }
    private static Integer toIntOrNull(String s){ try{ return s==null?null:Integer.parseInt(s.trim()); } catch(Exception e){ return null; } }
    private static Boolean toBoolOrNull(String s){ if (s==null) return null; return "true".equalsIgnoreCase(s) || "1".equals(s); }
}
