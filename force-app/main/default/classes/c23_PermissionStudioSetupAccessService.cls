public with sharing class c23_PermissionStudioSetupAccessService {
    private static final Integer PREVIEW_SAMPLE_LIMIT = 25;
    private static final String TYPE_APEX_CLASS = 'ApexClass';
    private static final String TYPE_CUSTOM_PERMISSION = 'CustomPermission';

    public class SetupAccessRow implements Comparable {
        @AuraEnabled public String rowKey;
        @AuraEnabled public String setupEntityType;
        @AuraEnabled public Id setupEntityId;
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean enabled;
        @AuraEnabled public Boolean currentEnabled;

        public Integer compareTo(Object otherObject) {
            SetupAccessRow otherValue = (SetupAccessRow) otherObject;
            String thisSort = (setupEntityType + '|' + (label == null ? '' : label) + '|' + apiName).toLowerCase();
            String otherSort = (otherValue.setupEntityType + '|' + (otherValue.label == null ? '' : otherValue.label) + '|' + otherValue.apiName).toLowerCase();
            if (thisSort == otherSort) {
                return 0;
            }
            return thisSort < otherSort ? -1 : 1;
        }
    }

    public class DesiredSetupAccessRow {
        @AuraEnabled public String setupEntityType;
        @AuraEnabled public Id setupEntityId;
        @AuraEnabled public Boolean enabled;
    }

    public class DiffSampleRow {
        @AuraEnabled public String key;
        @AuraEnabled public String beforeJson;
        @AuraEnabled public String afterJson;
    }

    public class PreviewResponse {
        @AuraEnabled public Integer changedCount;
        @AuraEnabled public Integer insertCount;
        @AuraEnabled public Integer updateCount;
        @AuraEnabled public Integer totalRequestedCount;
        @AuraEnabled public Boolean hasChanges;
        @AuraEnabled public List<DiffSampleRow> sampleRows;
    }

    public class ApplyResponse {
        @AuraEnabled public Integer changedCount;
        @AuraEnabled public Integer insertCount;
        @AuraEnabled public Integer updateCount;
        @AuraEnabled public Integer totalRequestedCount;
        @AuraEnabled public Id ledgerId;
        @AuraEnabled public Boolean ledgerTruncated;
        @AuraEnabled public Integer ledgerStoredItemCount;
        @AuraEnabled public Integer ledgerTotalItemCount;
        @AuraEnabled public String message;
    }

    private class CatalogEntry {
        public String setupEntityType;
        public Id setupEntityId;
        public String apiName;
        public String label;
    }

    private class ChangeComputationResult {
        public PermissionSet permissionSetRecord;
        public Integer totalRequestedCount = 0;
        public Integer insertCount = 0;
        public Integer updateCount = 0;
        public Integer changedCount = 0;
        public List<SetupEntityAccess> toInsert = new List<SetupEntityAccess>();
        public List<SetupEntityAccess> toDelete = new List<SetupEntityAccess>();
        public List<DiffSampleRow> previewSamples = new List<DiffSampleRow>();
        public List<c23_PermissionStudioLedgerService.LedgerItemPayload> ledgerItems =
            new List<c23_PermissionStudioLedgerService.LedgerItemPayload>();
    }

    @AuraEnabled
    public static List<SetupAccessRow> getSetupAccessMatrix(Id parentPermissionSetId) {
        c23_PermissionStudioSecurity.assertAccess();
        PermissionSet permissionSetRecord = c23_PermissionStudioSecurity.validatePermissionSet(
            parentPermissionSetId,
            'SetupAccess.getSetupAccessMatrix'
        );

        Map<String, CatalogEntry> catalogByKey = buildCatalogByKey();
        if (catalogByKey.isEmpty()) {
            return new List<SetupAccessRow>();
        }

        Set<Id> entityIds = new Set<Id>();
        for (CatalogEntry entry : catalogByKey.values()) {
            entityIds.add(entry.setupEntityId);
        }

        Map<Id, SetupEntityAccess> existingByEntityId = new Map<Id, SetupEntityAccess>();
        for (SetupEntityAccess existing : [
            SELECT Id, SetupEntityId, SetupEntityType
            FROM SetupEntityAccess
            WHERE ParentId = :permissionSetRecord.Id
                AND SetupEntityId IN :entityIds
                AND SetupEntityType IN :new Set<String>{ TYPE_APEX_CLASS, TYPE_CUSTOM_PERMISSION }
        ]) {
            existingByEntityId.put(existing.SetupEntityId, existing);
        }

        List<SetupAccessRow> rows = new List<SetupAccessRow>();
        for (String catalogKey : catalogByKey.keySet()) {
            CatalogEntry entry = catalogByKey.get(catalogKey);
            Boolean currentEnabled = existingByEntityId.containsKey(entry.setupEntityId);

            SetupAccessRow row = new SetupAccessRow();
            row.rowKey = catalogKey;
            row.setupEntityType = entry.setupEntityType;
            row.setupEntityId = entry.setupEntityId;
            row.apiName = entry.apiName;
            row.label = entry.label;
            row.enabled = currentEnabled;
            row.currentEnabled = currentEnabled;
            rows.add(row);
        }

        rows.sort();
        return rows;
    }

    @AuraEnabled
    public static PreviewResponse previewApplySetupAccess(
        Id parentPermissionSetId,
        List<DesiredSetupAccessRow> desiredStateRows
    ) {
        c23_PermissionStudioSecurity.assertAccess();
        ChangeComputationResult result = computeChanges(parentPermissionSetId, desiredStateRows);

        PreviewResponse response = new PreviewResponse();
        response.changedCount = result.changedCount;
        response.insertCount = result.insertCount;
        response.updateCount = result.updateCount;
        response.totalRequestedCount = result.totalRequestedCount;
        response.hasChanges = result.changedCount > 0;
        response.sampleRows = result.previewSamples;
        return response;
    }

    @AuraEnabled
    public static ApplyResponse applySetupAccess(
        Id parentPermissionSetId,
        List<DesiredSetupAccessRow> desiredStateRows,
        String changeNote
    ) {
        c23_PermissionStudioSecurity.assertAccess();
        ChangeComputationResult result;
        try {
            result = computeChanges(parentPermissionSetId, desiredStateRows);
        } catch (AuraHandledException ex) {
            if (ex.getMessage() == Label.c23_PS_Error_NoDesiredRows) {
                return buildNoChangeResponse(0);
            }
            throw ex;
        }

        if (result.changedCount == 0) {
            return buildNoChangeResponse(result.totalRequestedCount);
        }

        if (!result.toInsert.isEmpty()) {
            insert result.toInsert;
        }

        if (!result.toDelete.isEmpty()) {
            delete result.toDelete;
        }

        c23_PermissionStudioLedgerService.LedgerWriteResult ledgerResult =
            c23_PermissionStudioLedgerService.writeChangeSafe(
                'PermissionSet',
                result.permissionSetRecord.Id,
                result.permissionSetRecord.Label,
                Label.c23_PS_Setup_Title,
                changeNote,
                result.totalRequestedCount,
                result.insertCount,
                result.updateCount,
                result.ledgerItems
            );

        ApplyResponse response = new ApplyResponse();
        response.changedCount = result.changedCount;
        response.insertCount = result.insertCount;
        response.updateCount = result.updateCount;
        response.totalRequestedCount = result.totalRequestedCount;
        response.ledgerId = ledgerResult.headerId;
        response.ledgerTruncated = ledgerResult.isTruncated;
        response.ledgerStoredItemCount = ledgerResult.storedItemCount;
        response.ledgerTotalItemCount = ledgerResult.totalItemCount;
        response.message = Label.c23_PS_Setup_ApplySuccess;
        return response;
    }

    private static ChangeComputationResult computeChanges(
        Id parentPermissionSetId,
        List<DesiredSetupAccessRow> desiredStateRows
    ) {
        ChangeComputationResult result = new ChangeComputationResult();
        result.permissionSetRecord = c23_PermissionStudioSecurity.validatePermissionSet(
            parentPermissionSetId,
            'SetupAccess.computeChanges'
        );

        if (desiredStateRows == null || desiredStateRows.isEmpty()) {
            return result;
        }

        Map<String, CatalogEntry> catalogByKey = buildCatalogByKey();
        if (catalogByKey.isEmpty()) {
            return result;
        }

        Map<String, DesiredSetupAccessRow> desiredByKey = new Map<String, DesiredSetupAccessRow>();
        for (DesiredSetupAccessRow desiredRow : desiredStateRows) {
            if (desiredRow == null || desiredRow.setupEntityId == null || String.isBlank(desiredRow.setupEntityType)) {
                continue;
            }

            String entityType = normalizeType(desiredRow.setupEntityType);
            if (entityType == null) {
                continue;
            }

            String rowKey = toCatalogKey(entityType, desiredRow.setupEntityId);
            if (!catalogByKey.containsKey(rowKey)) {
                continue;
            }

            DesiredSetupAccessRow safeRow = new DesiredSetupAccessRow();
            safeRow.setupEntityType = entityType;
            safeRow.setupEntityId = desiredRow.setupEntityId;
            safeRow.enabled = desiredRow.enabled == true;
            desiredByKey.put(rowKey, safeRow);
        }

        if (desiredByKey.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(
                Label.c23_PS_Error_InvalidDesiredRows,
                'SetupAccess.computeChanges',
                buildInvalidDesiredRowsDetails(result.permissionSetRecord.Id, desiredStateRows, catalogByKey, desiredByKey),
                result.permissionSetRecord.Id
            );
        }

        result.totalRequestedCount = desiredByKey.size();

        Set<Id> desiredEntityIds = new Set<Id>();
        for (DesiredSetupAccessRow desiredRow : desiredByKey.values()) {
            desiredEntityIds.add(desiredRow.setupEntityId);
        }

        Map<Id, SetupEntityAccess> existingByEntityId = new Map<Id, SetupEntityAccess>();
        for (SetupEntityAccess existing : [
            SELECT Id, SetupEntityId, SetupEntityType
            FROM SetupEntityAccess
            WHERE ParentId = :result.permissionSetRecord.Id
                AND SetupEntityId IN :desiredEntityIds
                AND SetupEntityType IN :new Set<String>{ TYPE_APEX_CLASS, TYPE_CUSTOM_PERMISSION }
        ]) {
            existingByEntityId.put(existing.SetupEntityId, existing);
        }

        for (String rowKey : desiredByKey.keySet()) {
            DesiredSetupAccessRow desiredRow = desiredByKey.get(rowKey);
            SetupEntityAccess existing = existingByEntityId.get(desiredRow.setupEntityId);
            Boolean beforeEnabled = existing != null;
            Boolean afterEnabled = desiredRow.enabled == true;

            if (beforeEnabled == afterEnabled) {
                continue;
            }

            if (afterEnabled) {
                SetupEntityAccess toCreate = new SetupEntityAccess();
                toCreate.ParentId = result.permissionSetRecord.Id;
                toCreate.SetupEntityId = desiredRow.setupEntityId;
                result.toInsert.add(toCreate);
                result.insertCount++;
            } else if (existing != null) {
                result.toDelete.add(existing);
                result.updateCount++;
            }

            result.changedCount++;

            c23_PermissionStudioLedgerService.LedgerItemPayload ledgerItem =
                new c23_PermissionStudioLedgerService.LedgerItemPayload();
            ledgerItem.itemKey = rowKey;
            ledgerItem.beforeJson = toEnabledJson(beforeEnabled);
            ledgerItem.afterJson = toEnabledJson(afterEnabled);
            result.ledgerItems.add(ledgerItem);

            if (result.previewSamples.size() < PREVIEW_SAMPLE_LIMIT) {
                DiffSampleRow sample = new DiffSampleRow();
                sample.key = rowKey;
                sample.beforeJson = ledgerItem.beforeJson;
                sample.afterJson = ledgerItem.afterJson;
                result.previewSamples.add(sample);
            }
        }

        return result;
    }

    private static ApplyResponse buildNoChangeResponse(Integer totalRequestedCount) {
        ApplyResponse response = new ApplyResponse();
        response.changedCount = 0;
        response.insertCount = 0;
        response.updateCount = 0;
        response.totalRequestedCount = totalRequestedCount == null ? 0 : totalRequestedCount;
        response.ledgerId = null;
        response.ledgerTruncated = false;
        response.ledgerStoredItemCount = 0;
        response.ledgerTotalItemCount = 0;
        response.message = Label.c23_PS_General_NoPendingChanges;
        return response;
    }

    private static String buildInvalidDesiredRowsDetails(
        Id permissionSetId,
        List<DesiredSetupAccessRow> desiredStateRows,
        Map<String, CatalogEntry> catalogByKey,
        Map<String, DesiredSetupAccessRow> desiredByKey
    ) {
        Map<String, Object> details = new Map<String, Object>();
        details.put('permissionSetId', permissionSetId == null ? null : String.valueOf(permissionSetId));
        details.put('incomingCount', desiredStateRows == null ? 0 : desiredStateRows.size());
        details.put('catalogCount', catalogByKey == null ? 0 : catalogByKey.size());
        details.put('acceptedCount', desiredByKey == null ? 0 : desiredByKey.size());

        List<String> incomingSample = new List<String>();
        if (desiredStateRows != null) {
            for (DesiredSetupAccessRow row : desiredStateRows) {
                if (row == null || row.setupEntityId == null || String.isBlank(row.setupEntityType)) {
                    continue;
                }
                incomingSample.add(row.setupEntityType + ':' + String.valueOf(row.setupEntityId));
                if (incomingSample.size() >= 25) {
                    break;
                }
            }
        }
        details.put('incomingKeySample', incomingSample);

        return JSON.serialize(details);
    }

    private static Map<String, CatalogEntry> buildCatalogByKey() {
        Map<String, CatalogEntry> response = new Map<String, CatalogEntry>();

        for (ApexClass classRecord : [
            SELECT Id, Name
            FROM ApexClass
            ORDER BY Name
            LIMIT 5000
        ]) {
            CatalogEntry entry = new CatalogEntry();
            entry.setupEntityType = TYPE_APEX_CLASS;
            entry.setupEntityId = classRecord.Id;
            entry.apiName = classRecord.Name;
            entry.label = classRecord.Name;
            response.put(toCatalogKey(entry.setupEntityType, entry.setupEntityId), entry);
        }

        for (CustomPermission permissionRecord : [
            SELECT Id, DeveloperName, MasterLabel
            FROM CustomPermission
            ORDER BY MasterLabel, DeveloperName
            LIMIT 5000
        ]) {
            CatalogEntry entry = new CatalogEntry();
            entry.setupEntityType = TYPE_CUSTOM_PERMISSION;
            entry.setupEntityId = permissionRecord.Id;
            entry.apiName = permissionRecord.DeveloperName;
            entry.label = permissionRecord.MasterLabel;
            response.put(toCatalogKey(entry.setupEntityType, entry.setupEntityId), entry);
        }

        return response;
    }

    private static String normalizeType(String setupEntityType) {
        if (setupEntityType == TYPE_APEX_CLASS || setupEntityType == TYPE_CUSTOM_PERMISSION) {
            return setupEntityType;
        }
        return null;
    }

    private static String toCatalogKey(String setupEntityType, Id setupEntityId) {
        return setupEntityType + ':' + String.valueOf(setupEntityId);
    }

    private static String toEnabledJson(Boolean enabledValue) {
        Map<String, Object> valueMap = new Map<String, Object>();
        valueMap.put('enabled', enabledValue == true);
        return JSON.serialize(valueMap);
    }
}