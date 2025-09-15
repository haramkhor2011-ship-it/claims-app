// src/main/java/com/acme/claims/soap/parse/DownloadFileParser.java
package com.acme.claims.soap.parse;

import com.acme.claims.soap.util.Xmls;
import org.w3c.dom.Document;

public class DownloadFileParser {
    public record Result(int code, String fileName, byte[] fileBytes, String errorMessage) {}

    public Result parse(String soapEnvelope) {
        try {
            Document d = Xmls.parse(soapEnvelope);
            int code = toInt(Xmls.gl(d, "DownloadTransactionFileResult"));
            String name = Xmls.gl(d, "fileName");
            String b64  = Xmls.gl(d, "file");
            byte[] bytes = (b64 == null || b64.isBlank())
                    ? new byte[0]
                    : java.util.Base64.getMimeDecoder().decode(b64);
            String err = Xmls.gl(d, "errorMessage");
            return new Result(code, name, bytes, err);
        } catch (Exception ex) {
            throw new IllegalStateException("Parse download failed: " + ex.getMessage(), ex);
        }
    }
    private static int toInt(String s){ try{ return Integer.parseInt(s==null?"":s.trim()); } catch(Exception e){ return Integer.MIN_VALUE; } }
}
