package com.acme.claims.domain.model.dto;

public record AttachmentDTO(
        String fileName,
        String mimeType,
        String base64Data // still base64 in DTO; decode before persisting
) {
    public boolean isEmpty() {
        return base64Data == null || base64Data.isBlank();
    }

    public byte[] decode() {
        return base64Data == null ? null : java.util.Base64.getDecoder().decode(base64Data);
    }

    @Override
    public String toString() {
        return "AttachmentDTO[fileName=%s, mimeType=%s, size=%d]"
                .formatted(fileName, mimeType, base64Data==null?0:base64Data.length());
    }
}
