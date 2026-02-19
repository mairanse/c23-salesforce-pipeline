public with sharing class c23_PermissionStudioLedgerService {
    @TestVisible
    private static Integer fallbackMaxItems = 200;

    public class LedgerItemPayload {
        @AuraEnabled public String itemKey;
        @AuraEnabled public String beforeJson;
        @AuraEnabled public String afterJson;
    }

    public class LedgerWriteResult {
        @AuraEnabled public Id headerId;
        @AuraEnabled public Integer totalItemCount;
        @AuraEnabled public Integer storedItemCount;
        @AuraEnabled public Integer maxItemCount;
        @AuraEnabled public Boolean isTruncated;
    }

    private class LedgerWriteQueueable implements Queueable {
        private String targetType;
        private Id targetId;
        private String targetName;
        private String sectionName;
        private String changeNote;
        private Integer totalRequestedCount;
        private Integer insertCount;
        private Integer updateCount;
        private List<LedgerItemPayload> ledgerItems;

        LedgerWriteQueueable(
            String targetType,
            Id targetId,
            String targetName,
            String sectionName,
            String changeNote,
            Integer totalRequestedCount,
            Integer insertCount,
            Integer updateCount,
            List<LedgerItemPayload> ledgerItems
        ) {
            this.targetType = targetType;
            this.targetId = targetId;
            this.targetName = targetName;
            this.sectionName = sectionName;
            this.changeNote = changeNote;
            this.totalRequestedCount = totalRequestedCount;
            this.insertCount = insertCount;
            this.updateCount = updateCount;
            this.ledgerItems = ledgerItems == null ? new List<LedgerItemPayload>() : ledgerItems;
        }

        public void execute(QueueableContext contextValue) {
            try {
                writeChange(
                    targetType,
                    targetId,
                    targetName,
                    sectionName,
                    changeNote,
                    totalRequestedCount,
                    insertCount,
                    updateCount,
                    ledgerItems
                );
            } catch (Exception ignored) {
                c23_ErrorLogService.logWarning(
                    'LedgerService.LedgerWriteQueueable.execute',
                    ignored.getMessage(),
                    'Queueable ledger write failed.',
                    targetId
                );
            }
        }
    }

    public static LedgerWriteResult writeObjectPermissionChange(
        Id permissionSetId,
        String permissionSetName,
        String changeNote,
        Integer totalRequestedCount,
        Integer insertCount,
        Integer updateCount,
        List<LedgerItemPayload> ledgerItems
    ) {
        return writeChange(
            'PermissionSet',
            permissionSetId,
            permissionSetName,
            Label.c23_PS_ObjectMatrix_Title,
            changeNote,
            totalRequestedCount,
            insertCount,
            updateCount,
            ledgerItems
        );
    }

    public static LedgerWriteResult writeObjectPermissionChangeSafe(
        Id permissionSetId,
        String permissionSetName,
        String changeNote,
        Integer totalRequestedCount,
        Integer insertCount,
        Integer updateCount,
        List<LedgerItemPayload> ledgerItems
    ) {
        return writeChangeSafe(
            'PermissionSet',
            permissionSetId,
            permissionSetName,
            Label.c23_PS_ObjectMatrix_Title,
            changeNote,
            totalRequestedCount,
            insertCount,
            updateCount,
            ledgerItems
        );
    }

    public static LedgerWriteResult writeChangeSafe(
        String targetType,
        Id targetId,
        String targetName,
        String sectionName,
        String changeNote,
        Integer totalRequestedCount,
        Integer insertCount,
        Integer updateCount,
        List<LedgerItemPayload> ledgerItems
    ) {
        try {
            return writeChange(
                targetType,
                targetId,
                targetName,
                sectionName,
                changeNote,
                totalRequestedCount,
                insertCount,
                updateCount,
                ledgerItems
            );
        } catch (DmlException ex) {
            if (!isMixedDmlException(ex)) {
                throw ex;
            }

            enqueueWriteChange(
                targetType,
                targetId,
                targetName,
                sectionName,
                changeNote,
                totalRequestedCount,
                insertCount,
                updateCount,
                ledgerItems
            );
            return buildQueuedWriteResult(ledgerItems);
        }
    }

    public static LedgerWriteResult writeChange(
        String targetType,
        Id targetId,
        String targetName,
        String sectionName,
        String changeNote,
        Integer totalRequestedCount,
        Integer insertCount,
        Integer updateCount,
        List<LedgerItemPayload> ledgerItems
    ) {
        c23_PermissionStudioSecurity.assertAccess();

        List<LedgerItemPayload> safeItems = ledgerItems == null ? new List<LedgerItemPayload>() : ledgerItems;
        Integer maxItems = resolveMaxItems();
        Integer changedCount = safeItems.size();
        Integer storedCount = Math.min(changedCount, maxItems);
        Boolean isTruncated = changedCount > maxItems;

        c23_PermissionStudioChange__c header = new c23_PermissionStudioChange__c();
        header.c23_TargetType__c = clipText(targetType, 80);
        header.c23_TargetId__c = targetId == null ? null : String.valueOf(targetId);
        header.c23_TargetName__c = targetName;
        header.c23_Section__c = clipText(sectionName, 80);
        header.c23_ChangeNote__c = clipText(changeNote, 32000);
        header.c23_ChangedCount__c = changedCount;
        header.c23_InsertCount__c = insertCount == null ? 0 : insertCount;
        header.c23_UpdateCount__c = updateCount == null ? 0 : updateCount;
        header.c23_TotalRequestedCount__c = totalRequestedCount == null ? 0 : totalRequestedCount;
        header.c23_IsTruncated__c = isTruncated;
        header.c23_TruncatedAt__c = isTruncated ? maxItems : null;
        header = sanitizeHeaderForCreate(header);
        insert header;

        List<c23_PermissionStudioChangeItem__c> itemsToInsert = new List<c23_PermissionStudioChangeItem__c>();
        for (Integer index = 0; index < storedCount; index++) {
            LedgerItemPayload payload = safeItems[index];
            c23_PermissionStudioChangeItem__c itemRecord = new c23_PermissionStudioChangeItem__c();
            itemRecord.c23_Change__c = header.Id;
            itemRecord.c23_ItemKey__c = clipText(payload.itemKey, 255);
            itemRecord.c23_BeforeJson__c = clipText(payload.beforeJson, 32000);
            itemRecord.c23_AfterJson__c = clipText(payload.afterJson, 32000);
            itemsToInsert.add(itemRecord);
        }

        if (!itemsToInsert.isEmpty()) {
            itemsToInsert = sanitizeItemsForCreate(itemsToInsert);
            insert itemsToInsert;
        }

        LedgerWriteResult result = new LedgerWriteResult();
        result.headerId = header.Id;
        result.totalItemCount = changedCount;
        result.storedItemCount = storedCount;
        result.maxItemCount = maxItems;
        result.isTruncated = isTruncated;
        return result;
    }

    private static void enqueueWriteChange(
        String targetType,
        Id targetId,
        String targetName,
        String sectionName,
        String changeNote,
        Integer totalRequestedCount,
        Integer insertCount,
        Integer updateCount,
        List<LedgerItemPayload> ledgerItems
    ) {
        System.enqueueJob(
            new LedgerWriteQueueable(
                targetType,
                targetId,
                targetName,
                sectionName,
                changeNote,
                totalRequestedCount,
                insertCount,
                updateCount,
                ledgerItems
            )
        );
    }

    private static LedgerWriteResult buildQueuedWriteResult(List<LedgerItemPayload> ledgerItems) {
        Integer totalItems = ledgerItems == null ? 0 : ledgerItems.size();
        Integer maxItems = resolveMaxItems();

        LedgerWriteResult result = new LedgerWriteResult();
        result.headerId = null;
        result.totalItemCount = totalItems;
        result.storedItemCount = Math.min(totalItems, maxItems);
        result.maxItemCount = maxItems;
        result.isTruncated = totalItems > maxItems;
        return result;
    }

    private static Boolean isMixedDmlException(DmlException ex) {
        if (ex == null) {
            return false;
        }
        String messageText = ex.getMessage();
        return messageText != null && messageText.contains('MIXED_DML_OPERATION');
    }

    private static Integer resolveMaxItems() {
        Integer resolved = fallbackMaxItems;

        try {
            String configuredValue = Label.c23_PS_Ledger_MaxItems;
            if (!String.isBlank(configuredValue)) {
                Integer parsed = Integer.valueOf(configuredValue.trim());
                if (parsed > 0) {
                    resolved = parsed;
                }
            }
        } catch (Exception ignored) {
            c23_ErrorLogService.logWarning(
                'LedgerService.resolveMaxItems',
                ignored.getMessage(),
                'Invalid c23_PS_Ledger_MaxItems label value.',
                null
            );
        }

        return resolved;
    }

    private static String clipText(String value, Integer maxLength) {
        if (value == null) {
            return null;
        }
        if (maxLength == null || maxLength <= 0 || value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }

    private static c23_PermissionStudioChange__c sanitizeHeaderForCreate(c23_PermissionStudioChange__c headerRecord) {
        SObjectAccessDecision decision = Security.stripInaccessible(
            System.AccessType.CREATABLE,
            new List<SObject>{ headerRecord }
        );
        assertNoStrippedFields(decision);
        return (c23_PermissionStudioChange__c) decision.getRecords()[0];
    }

    private static List<c23_PermissionStudioChangeItem__c> sanitizeItemsForCreate(
        List<c23_PermissionStudioChangeItem__c> itemRecords
    ) {
        SObjectAccessDecision decision = Security.stripInaccessible(
            System.AccessType.CREATABLE,
            itemRecords
        );
        assertNoStrippedFields(decision);

        List<c23_PermissionStudioChangeItem__c> sanitized = new List<c23_PermissionStudioChangeItem__c>();
        for (SObject recordItem : decision.getRecords()) {
            sanitized.add((c23_PermissionStudioChangeItem__c) recordItem);
        }
        return sanitized;
    }

    private static void assertNoStrippedFields(SObjectAccessDecision decision) {
        Map<String, Set<String>> removedFields = decision == null ? null : decision.getRemovedFields();
        if (removedFields != null && !removedFields.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_General_AccessDenied);
        }
    }
}