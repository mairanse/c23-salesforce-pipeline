public with sharing class c23_PermissionStudioSystemPermService {
    private static final Integer PREVIEW_SAMPLE_LIMIT = 25;
    private static final String SYSTEM_PERMISSION_PREFIX = 'permissions';

    public class SystemPermRow implements Comparable {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean enabled;
        @AuraEnabled public Boolean currentEnabled;

        public Integer compareTo(Object otherObject) {
            SystemPermRow otherValue = (SystemPermRow) otherObject;
            String thisSort = ((label == null ? '' : label) + '|' + apiName).toLowerCase();
            String otherSort = ((otherValue.label == null ? '' : otherValue.label) + '|' + otherValue.apiName).toLowerCase();
            if (thisSort == otherSort) {
                return 0;
            }
            return thisSort < otherSort ? -1 : 1;
        }
    }

    public class DesiredSystemPermRow {
        @AuraEnabled public String apiName;
        @AuraEnabled public String key;
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

    public class ApplySystemPermJsonRequest {
        @AuraEnabled public String parentPermissionSetId;
        @AuraEnabled public String permissionSetId;
        @AuraEnabled public String desiredStateRowsJson;
        @AuraEnabled public String changeNote;
    }

    private class SystemFieldDefinition implements Comparable {
        public String apiName;
        public String label;

        public Integer compareTo(Object otherObject) {
            SystemFieldDefinition otherValue = (SystemFieldDefinition) otherObject;
            String thisSort = ((label == null ? '' : label) + '|' + apiName).toLowerCase();
            String otherSort = ((otherValue.label == null ? '' : otherValue.label) + '|' + otherValue.apiName).toLowerCase();
            if (thisSort == otherSort) {
                return 0;
            }
            return thisSort < otherSort ? -1 : 1;
        }
    }

    private class ChangeComputationResult {
        public PermissionSet permissionSetRecord;
        public Integer totalRequestedCount = 0;
        public Integer insertCount = 0;
        public Integer updateCount = 0;
        public Integer changedCount = 0;
        public Map<String, Boolean> changedValuesByField = new Map<String, Boolean>();
        public List<DiffSampleRow> previewSamples = new List<DiffSampleRow>();
        public List<c23_PermissionStudioLedgerService.LedgerItemPayload> ledgerItems =
            new List<c23_PermissionStudioLedgerService.LedgerItemPayload>();
    }

    @AuraEnabled
    public static List<SystemPermRow> getSystemPermissionMatrix(Id parentPermissionSetId) {
        c23_PermissionStudioSecurity.assertAccess();
        PermissionSet permissionSetRecord = c23_PermissionStudioSecurity.validatePermissionSet(
            parentPermissionSetId,
            'SystemPerm.getSystemPermissionMatrix'
        );

        List<SystemFieldDefinition> fieldDefinitions = getSystemFieldDefinitions(true);
        if (fieldDefinitions.isEmpty()) {
            return new List<SystemPermRow>();
        }

        PermissionSet queriedRecord = queryPermissionSetWithFields(permissionSetRecord.Id, extractApiNames(fieldDefinitions));
        List<SystemPermRow> rows = new List<SystemPermRow>();
        for (SystemFieldDefinition definition : fieldDefinitions) {
            Boolean currentValue = asBoolean(queriedRecord.get(definition.apiName));
            SystemPermRow row = new SystemPermRow();
            row.apiName = definition.apiName;
            row.label = definition.label;
            row.enabled = currentValue;
            row.currentEnabled = currentValue;
            rows.add(row);
        }

        rows.sort();
        return rows;
    }

    @AuraEnabled
    public static PreviewResponse previewApplySystemPermissions(
        Id parentPermissionSetId,
        List<DesiredSystemPermRow> desiredStateRows
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
    public static ApplyResponse applySystemPermissions(
        Id parentPermissionSetId,
        List<DesiredSystemPermRow> desiredStateRows,
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

        if (!result.changedValuesByField.isEmpty()) {
            PermissionSet toUpdate = new PermissionSet(Id = result.permissionSetRecord.Id);
            for (String fieldApiName : result.changedValuesByField.keySet()) {
                toUpdate.put(fieldApiName, result.changedValuesByField.get(fieldApiName));
            }
            update toUpdate;
        }

        c23_PermissionStudioLedgerService.LedgerWriteResult ledgerResult =
            c23_PermissionStudioLedgerService.writeChangeSafe(
                'PermissionSet',
                result.permissionSetRecord.Id,
                result.permissionSetRecord.Label,
                Label.c23_PS_System_Title,
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
        response.message = Label.c23_PS_System_ApplySuccess;
        return response;
    }

    @AuraEnabled
    public static ApplyResponse applySystemPermissionsJson(
        Id parentPermissionSetId,
        String desiredStateRowsJson,
        String changeNote
    ) {
        c23_PermissionStudioSecurity.assertAccess();
        if (parentPermissionSetId == null) {
            throw c23_PermissionStudioSecurity.handled(
                Label.c23_PS_Error_InvalidPermissionSet,
                'SystemPerm.applySystemPermissionsJson',
                buildInvalidPermissionSetRequestDetails(null, desiredStateRowsJson),
                null
            );
        }

        List<DesiredSystemPermRow> desiredStateRows = parseDesiredStateRowsJson(desiredStateRowsJson);
        return applySystemPermissions(parentPermissionSetId, desiredStateRows, changeNote);
    }

    @AuraEnabled
    public static ApplyResponse applySystemPermissionsJsonRequest(ApplySystemPermJsonRequest request) {
        c23_PermissionStudioSecurity.assertAccess();
        return applySystemPermissionsJsonRequestInternal(request);
    }

    @AuraEnabled
    public static ApplyResponse applySystemPermissionsJsonEnvelope(String requestJson) {
        c23_PermissionStudioSecurity.assertAccess();
        ApplySystemPermJsonRequest request = parseApplySystemPermJsonRequest(requestJson);
        return applySystemPermissionsJsonRequestInternal(request);
    }

    private static ApplyResponse applySystemPermissionsJsonRequestInternal(ApplySystemPermJsonRequest request) {
        if (request == null) {
            throw c23_PermissionStudioSecurity.handled(
                Label.c23_PS_Error_InvalidDesiredRows,
                'SystemPerm.applySystemPermissionsJsonRequest',
                null,
                null
            );
        }

        Id parentPermissionSetId = parseId(firstNonBlank(new List<String>{ request.parentPermissionSetId, request.permissionSetId }));
        if (parentPermissionSetId == null) {
            throw c23_PermissionStudioSecurity.handled(
                Label.c23_PS_Error_InvalidPermissionSet,
                'SystemPerm.applySystemPermissionsJsonRequest',
                buildInvalidPermissionSetRequestDetails(request, request.desiredStateRowsJson),
                null
            );
        }

        return applySystemPermissionsJson(
            parentPermissionSetId,
            request.desiredStateRowsJson,
            request.changeNote
        );
    }

    private static ApplySystemPermJsonRequest parseApplySystemPermJsonRequest(String requestJson) {
        if (String.isBlank(requestJson)) {
            return null;
        }

        Object parsed;
        try {
            parsed = JSON.deserializeUntyped(requestJson);
        } catch (Exception ignored) {
            return null;
        }

        if (!(parsed instanceof Map<String, Object>)) {
            return null;
        }

        Map<String, Object> valueMap = (Map<String, Object>) parsed;
        ApplySystemPermJsonRequest request = new ApplySystemPermJsonRequest();
        request.parentPermissionSetId = objectToString(valueMap.get('parentPermissionSetId'));
        request.permissionSetId = objectToString(valueMap.get('permissionSetId'));
        request.desiredStateRowsJson = objectToString(valueMap.get('desiredStateRowsJson'));
        request.changeNote = objectToString(valueMap.get('changeNote'));
        return request;
    }

    private static ChangeComputationResult computeChanges(
        Id parentPermissionSetId,
        List<DesiredSystemPermRow> desiredStateRows
    ) {
        ChangeComputationResult result = new ChangeComputationResult();
        result.permissionSetRecord = c23_PermissionStudioSecurity.validatePermissionSet(
            parentPermissionSetId,
            'SystemPerm.computeChanges'
        );

        if (desiredStateRows == null || desiredStateRows.isEmpty()) {
            return result;
        }

        List<SystemFieldDefinition> validFieldDefinitions = getSystemFieldDefinitions(true);
        Map<String, SystemFieldDefinition> validFieldsByApi = new Map<String, SystemFieldDefinition>();
        Map<String, String> canonicalFieldByLower = new Map<String, String>();
        for (SystemFieldDefinition definition : validFieldDefinitions) {
            validFieldsByApi.put(definition.apiName, definition);
            canonicalFieldByLower.put(definition.apiName.toLowerCase(), definition.apiName);
        }

        Map<String, Boolean> desiredByField = new Map<String, Boolean>();
        for (DesiredSystemPermRow desiredRow : desiredStateRows) {
            if (desiredRow == null) {
                continue;
            }

            String incomingFieldApiName = firstNonBlank(
                new List<String>{
                    desiredRow.apiName,
                    desiredRow.key
                }
            );
            if (String.isBlank(incomingFieldApiName)) {
                continue;
            }

            incomingFieldApiName = incomingFieldApiName.trim();
            String fieldApiName = canonicalFieldByLower.get(incomingFieldApiName.toLowerCase());
            if (String.isBlank(fieldApiName) || !validFieldsByApi.containsKey(fieldApiName)) {
                continue;
            }

            desiredByField.put(fieldApiName, desiredRow.enabled == true);
        }

        if (desiredByField.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(
                Label.c23_PS_Error_InvalidDesiredRows,
                'SystemPerm.computeChanges',
                buildInvalidDesiredRowsDetails(result.permissionSetRecord.Id, desiredStateRows, validFieldsByApi, desiredByField),
                result.permissionSetRecord.Id
            );
        }

        result.totalRequestedCount = desiredByField.size();

        PermissionSet currentRecord = queryPermissionSetWithFields(result.permissionSetRecord.Id, new List<String>(desiredByField.keySet()));
        for (String fieldApiName : desiredByField.keySet()) {
            Boolean beforeValue = asBoolean(currentRecord.get(fieldApiName));
            Boolean afterValue = desiredByField.get(fieldApiName);
            if (beforeValue == afterValue) {
                continue;
            }

            result.changedValuesByField.put(fieldApiName, afterValue);
            result.changedCount++;
            result.updateCount++;

            c23_PermissionStudioLedgerService.LedgerItemPayload ledgerItem =
                new c23_PermissionStudioLedgerService.LedgerItemPayload();
            ledgerItem.itemKey = fieldApiName;
            ledgerItem.beforeJson = toEnabledJson(beforeValue);
            ledgerItem.afterJson = toEnabledJson(afterValue);
            result.ledgerItems.add(ledgerItem);

            if (result.previewSamples.size() < PREVIEW_SAMPLE_LIMIT) {
                DiffSampleRow sample = new DiffSampleRow();
                sample.key = fieldApiName;
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
        List<DesiredSystemPermRow> desiredStateRows,
        Map<String, SystemFieldDefinition> validFieldsByApi,
        Map<String, Boolean> desiredByField
    ) {
        Map<String, Object> details = new Map<String, Object>();
        details.put('permissionSetId', permissionSetId == null ? null : String.valueOf(permissionSetId));
        details.put('incomingCount', desiredStateRows == null ? 0 : desiredStateRows.size());
        details.put('validFieldCount', validFieldsByApi == null ? 0 : validFieldsByApi.size());
        details.put('acceptedCount', desiredByField == null ? 0 : desiredByField.size());
        details.put(
            'acceptedApiSample',
            desiredByField == null ? new List<String>() : collectStringSample(desiredByField.keySet(), 25)
        );

        List<String> incomingSample = new List<String>();
        List<Map<String, Object>> incomingRowSample = new List<Map<String, Object>>();
        if (desiredStateRows != null) {
            for (DesiredSystemPermRow row : desiredStateRows) {
                String incomingFieldApiName = row == null
                    ? null
                    : firstNonBlank(
                        new List<String>{
                            row.apiName,
                            row.key
                        }
                    );
                if (String.isBlank(incomingFieldApiName)) {
                    if (row != null && incomingRowSample.size() < 10) {
                        incomingRowSample.add(buildIncomingRowDebug(row));
                    }
                    continue;
                }
                incomingSample.add(incomingFieldApiName.trim());
                if (incomingRowSample.size() < 10) {
                    incomingRowSample.add(buildIncomingRowDebug(row));
                }
                if (incomingSample.size() >= 25) {
                    break;
                }
            }
        }
        details.put('incomingApiSample', incomingSample);
        details.put('incomingRowSample', incomingRowSample);

        return JSON.serialize(details);
    }

    private static String buildInvalidPermissionSetRequestDetails(
        ApplySystemPermJsonRequest request,
        String desiredStateRowsJson
    ) {
        Map<String, Object> details = new Map<String, Object>();
        details.put('parentPermissionSetId', request == null ? null : request.parentPermissionSetId);
        details.put('permissionSetId', request == null ? null : request.permissionSetId);
        details.put('hasDesiredStateRowsJson', !String.isBlank(desiredStateRowsJson));
        details.put('desiredStateRowsJsonLength', String.isBlank(desiredStateRowsJson) ? 0 : desiredStateRowsJson.length());
        return JSON.serialize(details);
    }

    private static List<DesiredSystemPermRow> parseDesiredStateRowsJson(String desiredStateRowsJson) {
        if (String.isBlank(desiredStateRowsJson)) {
            return new List<DesiredSystemPermRow>();
        }

        Object parsed;
        try {
            parsed = JSON.deserializeUntyped(desiredStateRowsJson);
        } catch (Exception ignored) {
            return new List<DesiredSystemPermRow>();
        }

        if (!(parsed instanceof List<Object>)) {
            return new List<DesiredSystemPermRow>();
        }

        List<DesiredSystemPermRow> rows = new List<DesiredSystemPermRow>();
        for (Object rowObject : (List<Object>) parsed) {
            if (!(rowObject instanceof Map<String, Object>)) {
                continue;
            }
            rows.add(parseDesiredSystemPermRow((Map<String, Object>) rowObject));
        }
        return rows;
    }

    private static DesiredSystemPermRow parseDesiredSystemPermRow(Map<String, Object> rowMap) {
        DesiredSystemPermRow row = new DesiredSystemPermRow();
        if (rowMap == null) {
            return row;
        }

        row.apiName = firstNonBlank(
            new List<String>{
                objectToString(rowMap.get('apiName')),
                objectToString(rowMap.get('key'))
            }
        );
        row.key = objectToString(rowMap.get('key'));
        row.enabled = objectToBoolean(rowMap.get('enabled'));
        return row;
    }

    private static String objectToString(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof String) {
            return (String) value;
        }
        return String.valueOf(value);
    }

    private static Boolean objectToBoolean(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Boolean) {
            return (Boolean) value;
        }
        if (value instanceof String) {
            String normalized = ((String) value).trim().toLowerCase();
            if (normalized == 'true') {
                return true;
            }
            if (normalized == 'false') {
                return false;
            }
        }
        return null;
    }

    private static Id parseId(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return (Id) value.trim();
        } catch (Exception ignored) {
            return null;
        }
    }

    private static String firstNonBlank(List<String> values) {
        if (values == null || values.isEmpty()) {
            return null;
        }

        for (String valueItem : values) {
            if (!String.isBlank(valueItem)) {
                return valueItem;
            }
        }

        return null;
    }

    private static List<String> collectStringSample(Set<String> values, Integer maxCount) {
        List<String> sample = new List<String>();
        if (values == null || values.isEmpty() || maxCount == null || maxCount <= 0) {
            return sample;
        }

        for (String valueItem : values) {
            sample.add(valueItem);
            if (sample.size() >= maxCount) {
                break;
            }
        }
        return sample;
    }

    private static Map<String, Object> buildIncomingRowDebug(DesiredSystemPermRow row) {
        Map<String, Object> debugRow = new Map<String, Object>();
        if (row == null) {
            return debugRow;
        }

        debugRow.put('apiName', row.apiName);
        debugRow.put('key', row.key);
        debugRow.put('enabled', row.enabled);
        return debugRow;
    }

    private static List<SystemFieldDefinition> getSystemFieldDefinitions(Boolean onlyUpdateable) {
        List<SystemFieldDefinition> definitions = new List<SystemFieldDefinition>();
        Map<String, Schema.SObjectField> allFields = PermissionSet.SObjectType.getDescribe().fields.getMap();

        for (String fieldApiName : allFields.keySet()) {
            if (String.isBlank(fieldApiName) || !fieldApiName.toLowerCase().startsWith(SYSTEM_PERMISSION_PREFIX)) {
                continue;
            }

            Schema.DescribeFieldResult fieldDescribe = allFields.get(fieldApiName).getDescribe();
            if (fieldDescribe.getType() != Schema.DisplayType.Boolean) {
                continue;
            }

            if (onlyUpdateable && !fieldDescribe.isUpdateable()) {
                continue;
            }

            SystemFieldDefinition definition = new SystemFieldDefinition();
            definition.apiName = fieldApiName;
            definition.label = fieldDescribe.getLabel();
            definitions.add(definition);
        }

        definitions.sort();
        return definitions;
    }

    private static PermissionSet queryPermissionSetWithFields(Id permissionSetId, List<String> fieldApiNames) {
        if (permissionSetId == null) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_Error_InvalidPermissionSet);
        }

        List<String> safeFieldApiNames = fieldApiNames == null ? new List<String>() : fieldApiNames;
        safeFieldApiNames.sort();

        String soql = 'SELECT Id';
        if (!safeFieldApiNames.isEmpty()) {
            soql += ',' + String.join(safeFieldApiNames, ',');
        }
        soql += ' FROM PermissionSet WHERE Id = :permissionSetId LIMIT 1';

        List<SObject> queriedRecords = Database.query(soql);
        if (queriedRecords.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_Error_InvalidPermissionSet);
        }

        return (PermissionSet) queriedRecords[0];
    }

    private static List<String> extractApiNames(List<SystemFieldDefinition> fieldDefinitions) {
        List<String> apiNames = new List<String>();
        for (SystemFieldDefinition definition : fieldDefinitions) {
            apiNames.add(definition.apiName);
        }
        return apiNames;
    }

    private static Boolean asBoolean(Object value) {
        return value != null && (Boolean) value;
    }

    private static String toEnabledJson(Boolean enabledValue) {
        Map<String, Object> valueMap = new Map<String, Object>();
        valueMap.put('enabled', enabledValue == true);
        return JSON.serialize(valueMap);
    }
}