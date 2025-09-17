package com.acme.claims.mapper;

import com.acme.claims.domain.model.dto.RemittanceHeaderDTO;
import com.acme.claims.domain.model.dto.SubmissionHeaderDTO;
import com.acme.claims.domain.model.entity.IngestionFile;
import java.util.Arrays;
import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2025-09-17T13:40:38+0000",
    comments = "version: 1.5.5.Final, compiler: javac, environment: Java 21.0.7 (Ubuntu)"
)
@Component
public class IngestionFileMapperImpl implements IngestionFileMapper {

    @Override
    public IngestionFile fromSubmissionHeader(SubmissionHeaderDTO header, String fileId, byte[] xmlBytes) {
        if ( header == null && fileId == null && xmlBytes == null ) {
            return null;
        }

        IngestionFile ingestionFile = new IngestionFile();

        if ( header != null ) {
            ingestionFile.setSenderId( header.senderId() );
            ingestionFile.setReceiverId( header.receiverId() );
            ingestionFile.setTransactionDate( header.transactionDate() );
            ingestionFile.setRecordCountDeclared( header.recordCount() );
            ingestionFile.setDispositionFlag( header.dispositionFlag() );
        }
        ingestionFile.setFileId( fileId );
        byte[] xmlBytes1 = xmlBytes;
        if ( xmlBytes1 != null ) {
            ingestionFile.setXmlBytes( Arrays.copyOf( xmlBytes1, xmlBytes1.length ) );
        }
        ingestionFile.setRootType( (short) 1 );
        ingestionFile.setCreatedAt( java.time.OffsetDateTime.now() );
        ingestionFile.setUpdatedAt( java.time.OffsetDateTime.now() );

        return ingestionFile;
    }

    @Override
    public IngestionFile fromRemittanceHeader(RemittanceHeaderDTO header, String fileId, byte[] xmlBytes) {
        if ( header == null && fileId == null && xmlBytes == null ) {
            return null;
        }

        IngestionFile ingestionFile = new IngestionFile();

        if ( header != null ) {
            ingestionFile.setSenderId( header.senderId() );
            ingestionFile.setReceiverId( header.receiverId() );
            ingestionFile.setTransactionDate( header.transactionDate() );
            ingestionFile.setRecordCountDeclared( header.recordCount() );
            ingestionFile.setDispositionFlag( header.dispositionFlag() );
        }
        ingestionFile.setFileId( fileId );
        byte[] xmlBytes1 = xmlBytes;
        if ( xmlBytes1 != null ) {
            ingestionFile.setXmlBytes( Arrays.copyOf( xmlBytes1, xmlBytes1.length ) );
        }
        ingestionFile.setRootType( (short) 2 );
        ingestionFile.setCreatedAt( java.time.OffsetDateTime.now() );
        ingestionFile.setUpdatedAt( java.time.OffsetDateTime.now() );

        return ingestionFile;
    }
}
