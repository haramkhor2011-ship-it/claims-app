// src/main/java/com/acme/claims/soap/parse/SetDownloadedParser.java
package com.acme.claims.soap.parse;

import com.acme.claims.soap.util.Xmls;
import org.w3c.dom.Document;

public class SetDownloadedParser {
    public record Result(int code, String errorMessage) {}
    public Result parse(String soapEnvelope) {
        try {
            Document d = Xmls.parse(soapEnvelope);
            int code = toInt(Xmls.gl(d, "SetTransactionDownloadedResult"));
            String err = Xmls.gl(d, "errorMessage");
            return new Result(code, err);
        } catch (Exception ex) {
            throw new IllegalStateException("Parse set-downloaded failed: " + ex.getMessage(), ex);
        }
    }
    private static int toInt(String s){ try{ return Integer.parseInt(s==null?"":s.trim()); } catch(Exception e){ return Integer.MIN_VALUE; } }
}
