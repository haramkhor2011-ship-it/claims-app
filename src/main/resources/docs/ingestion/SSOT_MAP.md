| XSD Path               | DTO Field                  | Table.Column                           | Notes        |
| ---------------------- | -------------------------- | -------------------------------------- | ------------ |
| Header/SenderID        | HeaderDto.senderId         | ingestion\_file.sender\_id             | required     |
| Claim/ID               | ClaimSubmissionClaimDto.id | claim\_key.claim\_id                   | unique key   |
| Claim/Encounter/Start  | EncounterDto.start         | encounter.start\_at                    | utc          |
| Activity/PaymentAmount | ActivityDto.paymentAmount  | remittance\_activity.payment\_amount   | nullable     |
| Resubmission/Type      | ResubmissionDto.type       | claim\_resubmission.resubmission\_type | when present |
