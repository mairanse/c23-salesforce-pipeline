public with sharing class c23_PermissionStudioFieldPermService {
    private static final Integer PREVIEW_SAMPLE_LIMIT = 25;

    public class FieldObjectOption implements Comparable {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;

        public Integer compareTo(Object otherObject) {
            FieldObjectOption otherValue = (FieldObjectOption) otherObject;
            String thisSort = ((label == null ? '' : label) + '|' + apiName).toLowerCase();
            String otherSort = ((otherValue.label == null ? '' : otherValue.label) + '|' + otherValue.apiName).toLowerCase();
            if (thisSort == otherSort) {
                return 0;
            }
            return thisSort < otherSort ? -1 : 1;
        }
    }

    public class FieldMatrixRow implements Comparable {
        @AuraEnabled public String fieldPath;
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String label;
        @AuraEnabled public String dataType;
        @AuraEnabled public Boolean isRequired;
        @AuraEnabled public Boolean isCustom;
        @AuraEnabled public Boolean permissionsRead;
        @AuraEnabled public Boolean permissionsEdit;
        @AuraEnabled public Boolean currentPermissionsRead;
        @AuraEnabled public Boolean currentPermissionsEdit;

        public Integer compareTo(Object otherObject) {
            FieldMatrixRow otherValue = (FieldMatrixRow) otherObject;
            String thisSort = ((label == null ? '' : label) + '|' + fieldPath).toLowerCase();
            String otherSort = ((otherValue.label == null ? '' : otherValue.label) + '|' + otherValue.fieldPath).toLowerCase();
            if (thisSort == otherSort) {
                return 0;
            }
            return thisSort < otherSort ? -1 : 1;
        }
    }

    public class DesiredFieldStateRow {
        @AuraEnabled public String fieldPath;
        @AuraEnabled public String field;
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String apiName;
        @AuraEnabled public String key;
        @AuraEnabled public Boolean permissionsRead;
        @AuraEnabled public Boolean permissionsEdit;
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

    public class ApplyFieldMatrixJsonRequest {
        @AuraEnabled public String parentPermissionSetId;
        @AuraEnabled public String permissionSetId;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String desiredStateRowsJson;
        @AuraEnabled public String changeNote;
    }

    private class FieldCatalogRow {
        public String fieldPath;
        public String fieldApiName;
        public String label;
        public String dataType;
        public Boolean isRequired;
        public Boolean isCustom;
    }

    private class PermissionState {
        public Boolean readAccess;
        public Boolean editAccess;

        public PermissionState() {
            readAccess = false;
            editAccess = false;
        }

        public Boolean sameAs(PermissionState otherState) {
            if (otherState == null) {
                return false;
            }
            return readAccess == otherState.readAccess && editAccess == otherState.editAccess;
        }

        public String toJson() {
            Map<String, Object> valueMap = new Map<String, Object>();
            valueMap.put('read', readAccess);
            valueMap.put('edit', editAccess);
            return JSON.serialize(valueMap);
        }
    }

    private class ChangeComputationResult {
        public PermissionSet permissionSetRecord;
        public String objectApiName;
        public Integer totalRequestedCount = 0;
        public Integer insertCount = 0;
        public Integer updateCount = 0;
        public Integer changedCount = 0;
        public List<FieldPermissions> toInsert = new List<FieldPermissions>();
        public List<FieldPermissions> toUpdate = new List<FieldPermissions>();
        public List<DiffSampleRow> previewSamples = new List<DiffSampleRow>();
        public List<c23_PermissionStudioLedgerService.LedgerItemPayload> ledgerItems =
            new List<c23_PermissionStudioLedgerService.LedgerItemPayload>();
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldObjectOption> getFieldObjectOptions() {
        c23_PermissionStudioSecurity.assertAccess();

        List<FieldObjectOption> options = new List<FieldObjectOption>();
        for (c23_SchemaService.SObjectCatalogRow objectRow : c23_SchemaService.getSObjectCatalog()) {
            FieldObjectOption option = new FieldObjectOption();
            option.apiName = objectRow.apiName;
            option.label = objectRow.label;
            options.add(option);
        }
        options.sort();
        return options;
    }

    @AuraEnabled
    public static List<FieldMatrixRow> getFieldMatrix(Id parentPermissionSetId, String objectApiName) {
        c23_PermissionStudioSecurity.assertAccess();
        PermissionSet permissionSetRecord = c23_PermissionStudioSecurity.validatePermissionSet(
            parentPermissionSetId,
            'FieldPerm.getFieldMatrix'
        );
        String safeObjectApiName = validateObjectApiName(objectApiName);

        Map<String, FieldCatalogRow> fieldCatalogByPath = buildFieldCatalogByPath(safeObjectApiName);
        if (fieldCatalogByPath.isEmpty()) {
            return new List<FieldMatrixRow>();
        }

        Map<String, FieldPermissions> existingByField = new Map<String, FieldPermissions>();
        for (FieldPermissions existing : [
            SELECT Id, Field, PermissionsRead, PermissionsEdit
            FROM FieldPermissions
            WHERE ParentId = :permissionSetRecord.Id
                AND SObjectType = :safeObjectApiName
                AND Field IN :fieldCatalogByPath.keySet()
        ]) {
            existingByField.put(existing.Field, existing);
        }

        List<FieldMatrixRow> responseRows = new List<FieldMatrixRow>();
        for (String fieldPath : fieldCatalogByPath.keySet()) {
            FieldCatalogRow catalogRow = fieldCatalogByPath.get(fieldPath);
            FieldPermissions existing = existingByField.get(fieldPath);
            PermissionState state = fromExisting(existing);

            FieldMatrixRow row = new FieldMatrixRow();
            row.fieldPath = catalogRow.fieldPath;
            row.fieldApiName = catalogRow.fieldApiName;
            row.label = catalogRow.label;
            row.dataType = catalogRow.dataType;
            row.isRequired = catalogRow.isRequired;
            row.isCustom = catalogRow.isCustom;
            row.permissionsRead = state.readAccess;
            row.permissionsEdit = state.editAccess;
            row.currentPermissionsRead = state.readAccess;
            row.currentPermissionsEdit = state.editAccess;
            responseRows.add(row);
        }

        responseRows.sort();
        return responseRows;
    }

    @AuraEnabled
    public static PreviewResponse previewApplyFieldMatrix(
        Id parentPermissionSetId,
        String objectApiName,
        List<DesiredFieldStateRow> desiredStateRows
    ) {
        c23_PermissionStudioSecurity.assertAccess();
        ChangeComputationResult result = computeChanges(parentPermissionSetId, objectApiName, desiredStateRows);

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
    public static ApplyResponse applyFieldMatrix(
        Id parentPermissionSetId,
        String objectApiName,
        List<DesiredFieldStateRow> desiredStateRows,
        String changeNote
    ) {
        c23_PermissionStudioSecurity.assertAccess();
        ChangeComputationResult result;
        try {
            result = computeChanges(parentPermissionSetId, objectApiName, desiredStateRows);
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

        if (!result.toUpdate.isEmpty()) {
            update result.toUpdate;
        }

        c23_PermissionStudioLedgerService.LedgerWriteResult ledgerResult =
            c23_PermissionStudioLedgerService.writeChangeSafe(
                'PermissionSet',
                result.permissionSetRecord.Id,
                result.permissionSetRecord.Label,
                Label.c23_PS_Field_Title,
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
        response.message = Label.c23_PS_Field_ApplySuccess;
        return response;
    }

    @AuraEnabled
    public static ApplyResponse applyFieldMatrixJson(
        Id parentPermissionSetId,
        String objectApiName,
        String desiredStateRowsJson,
        String changeNote
    ) {
        c23_PermissionStudioSecurity.assertAccess();
        if (parentPermissionSetId == null) {
            throw c23_PermissionStudioSecurity.handled(
                Label.c23_PS_Error_InvalidPermissionSet,
                'FieldPerm.applyFieldMatrixJson',
                buildInvalidPermissionSetRequestDetails(null, desiredStateRowsJson),
                null
            );
        }

        List<DesiredFieldStateRow> desiredStateRows = parseDesiredStateRowsJson(desiredStateRowsJson);
        return applyFieldMatrix(parentPermissionSetId, objectApiName, desiredStateRows, changeNote);
    }

    @AuraEnabled
    public static ApplyResponse applyFieldMatrixJsonRequest(ApplyFieldMatrixJsonRequest request) {
        c23_PermissionStudioSecurity.assertAccess();
        return applyFieldMatrixJsonRequestInternal(request);
    }

    @AuraEnabled
    public static ApplyResponse applyFieldMatrixJsonEnvelope(String requestJson) {
        c23_PermissionStudioSecurity.assertAccess();
        ApplyFieldMatrixJsonRequest request = parseApplyFieldMatrixJsonRequest(requestJson);
        return applyFieldMatrixJsonRequestInternal(request);
    }

    private static ApplyResponse applyFieldMatrixJsonRequestInternal(ApplyFieldMatrixJsonRequest request) {
        if (request == null) {
            throw c23_PermissionStudioSecurity.handled(
                Label.c23_PS_Error_InvalidDesiredRows,
                'FieldPerm.applyFieldMatrixJsonRequest',
                null,
                null
            );
        }

        Id parentPermissionSetId = parseId(firstNonBlank(new List<String>{ request.parentPermissionSetId, request.permissionSetId }));
        if (parentPermissionSetId == null) {
            throw c23_PermissionStudioSecurity.handled(
                Label.c23_PS_Error_InvalidPermissionSet,
                'FieldPerm.applyFieldMatrixJsonRequest',
                buildInvalidPermissionSetRequestDetails(request, request.desiredStateRowsJson),
                null
            );
        }

        return applyFieldMatrixJson(
            parentPermissionSetId,
            request.objectApiName,
            request.desiredStateRowsJson,
            request.changeNote
        );
    }

    private static ApplyFieldMatrixJsonRequest parseApplyFieldMatrixJsonRequest(String requestJson) {
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
        ApplyFieldMatrixJsonRequest request = new ApplyFieldMatrixJsonRequest();
        request.parentPermissionSetId = objectToString(valueMap.get('parentPermissionSetId'));
        request.permissionSetId = objectToString(valueMap.get('permissionSetId'));
        request.objectApiName = objectToString(valueMap.get('objectApiName'));
        request.desiredStateRowsJson = objectToString(valueMap.get('desiredStateRowsJson'));
        request.changeNote = objectToString(valueMap.get('changeNote'));
        return request;
    }

    private static ChangeComputationResult computeChanges(
        Id parentPermissionSetId,
        String objectApiName,
        List<DesiredFieldStateRow> desiredStateRows
    ) {
        ChangeComputationResult result = new ChangeComputationResult();
        result.permissionSetRecord = c23_PermissionStudioSecurity.validatePermissionSet(
            parentPermissionSetId,
            'FieldPerm.computeChanges'
        );
        result.objectApiName = validateObjectApiName(objectApiName);

        if (desiredStateRows == null || desiredStateRows.isEmpty()) {
            return result;
        }

        Map<String, FieldCatalogRow> catalogByPath = buildFieldCatalogByPath(result.objectApiName);
        if (catalogByPath.isEmpty()) {
            return result;
        }

        Map<String, String> canonicalFieldByLower = new Map<String, String>();
        for (String catalogFieldPath : catalogByPath.keySet()) {
            canonicalFieldByLower.put(catalogFieldPath.toLowerCase(), catalogFieldPath);
        }

        Map<String, PermissionState> desiredByPath = new Map<String, PermissionState>();
        for (DesiredFieldStateRow desiredRow : desiredStateRows) {
            if (desiredRow == null) {
                continue;
            }

            String incomingFieldPath = firstNonBlank(
                new List<String>{
                    desiredRow.fieldPath,
                    desiredRow.field,
                    desiredRow.fieldApiName,
                    desiredRow.apiName,
                    desiredRow.key
                }
            );
            String fieldPath = resolveFieldPath(
                incomingFieldPath,
                result.objectApiName,
                catalogByPath,
                canonicalFieldByLower
            );
            if (String.isBlank(fieldPath)) {
                continue;
            }

            desiredByPath.put(
                fieldPath,
                normalizeState(desiredRow.permissionsRead, desiredRow.permissionsEdit)
            );
        }

        if (desiredByPath.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(
                Label.c23_PS_Error_InvalidDesiredRows,
                'FieldPerm.computeChanges',
                buildInvalidDesiredRowsDetails(result.permissionSetRecord.Id, result.objectApiName, desiredStateRows, catalogByPath, desiredByPath),
                result.permissionSetRecord.Id
            );
        }

        result.totalRequestedCount = desiredByPath.size();

        Map<String, FieldPermissions> existingByPath = new Map<String, FieldPermissions>();
        for (FieldPermissions existing : [
            SELECT Id, Field, PermissionsRead, PermissionsEdit
            FROM FieldPermissions
            WHERE ParentId = :result.permissionSetRecord.Id
                AND SObjectType = :result.objectApiName
                AND Field IN :desiredByPath.keySet()
        ]) {
            existingByPath.put(existing.Field, existing);
        }

        for (String fieldPath : desiredByPath.keySet()) {
            PermissionState desiredState = desiredByPath.get(fieldPath);
            FieldPermissions existing = existingByPath.get(fieldPath);
            PermissionState beforeState = fromExisting(existing);

            if (beforeState.sameAs(desiredState)) {
                continue;
            }

            if (existing == null) {
                FieldPermissions toCreate = new FieldPermissions();
                toCreate.ParentId = result.permissionSetRecord.Id;
                toCreate.SObjectType = result.objectApiName;
                toCreate.Field = fieldPath;
                applyState(toCreate, desiredState);
                result.toInsert.add(toCreate);
                result.insertCount++;
            } else {
                applyState(existing, desiredState);
                result.toUpdate.add(existing);
                result.updateCount++;
            }

            result.changedCount++;

            c23_PermissionStudioLedgerService.LedgerItemPayload ledgerItem =
                new c23_PermissionStudioLedgerService.LedgerItemPayload();
            ledgerItem.itemKey = fieldPath;
            ledgerItem.beforeJson = beforeState.toJson();
            ledgerItem.afterJson = desiredState.toJson();
            result.ledgerItems.add(ledgerItem);

            if (result.previewSamples.size() < PREVIEW_SAMPLE_LIMIT) {
                DiffSampleRow sample = new DiffSampleRow();
                sample.key = fieldPath;
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
        String objectApiName,
        List<DesiredFieldStateRow> desiredStateRows,
        Map<String, FieldCatalogRow> catalogByPath,
        Map<String, PermissionState> desiredByPath
    ) {
        Map<String, Object> details = new Map<String, Object>();
        details.put('permissionSetId', permissionSetId == null ? null : String.valueOf(permissionSetId));
        details.put('objectApiName', objectApiName);
        details.put('incomingCount', desiredStateRows == null ? 0 : desiredStateRows.size());
        details.put('catalogCount', catalogByPath == null ? 0 : catalogByPath.size());
        details.put('acceptedCount', desiredByPath == null ? 0 : desiredByPath.size());
        details.put(
            'acceptedFieldSample',
            desiredByPath == null ? new List<String>() : collectStringSample(desiredByPath.keySet(), 25)
        );

        List<String> incomingSample = new List<String>();
        List<Map<String, Object>> incomingRowSample = new List<Map<String, Object>>();
        Map<String, String> canonicalFieldByLower = new Map<String, String>();
        if (catalogByPath != null) {
            for (String catalogFieldPath : catalogByPath.keySet()) {
                canonicalFieldByLower.put(catalogFieldPath.toLowerCase(), catalogFieldPath);
            }
        }
        if (desiredStateRows != null) {
            for (DesiredFieldStateRow row : desiredStateRows) {
                if (row == null) {
                    continue;
                }

                String incomingFieldPath = firstNonBlank(
                    new List<String>{ row.fieldPath, row.field, row.fieldApiName, row.apiName, row.key }
                );
                if (String.isBlank(incomingFieldPath)) {
                    if (incomingRowSample.size() < 10) {
                        incomingRowSample.add(buildIncomingRowDebug(row));
                    }
                    continue;
                }

                String resolvedFieldPath = resolveFieldPath(
                    incomingFieldPath,
                    objectApiName,
                    catalogByPath,
                    canonicalFieldByLower
                );
                incomingSample.add(String.isBlank(resolvedFieldPath) ? incomingFieldPath.trim() : resolvedFieldPath);
                if (incomingRowSample.size() < 10) {
                    incomingRowSample.add(buildIncomingRowDebug(row));
                }
                if (incomingSample.size() >= 25) {
                    break;
                }
            }
        }
        details.put('incomingFieldSample', incomingSample);
        details.put('incomingRowSample', incomingRowSample);

        return JSON.serialize(details);
    }

    private static String buildInvalidPermissionSetRequestDetails(
        ApplyFieldMatrixJsonRequest request,
        String desiredStateRowsJson
    ) {
        Map<String, Object> details = new Map<String, Object>();
        details.put('parentPermissionSetId', request == null ? null : request.parentPermissionSetId);
        details.put('permissionSetId', request == null ? null : request.permissionSetId);
        details.put('objectApiName', request == null ? null : request.objectApiName);
        details.put('hasDesiredStateRowsJson', !String.isBlank(desiredStateRowsJson));
        details.put('desiredStateRowsJsonLength', String.isBlank(desiredStateRowsJson) ? 0 : desiredStateRowsJson.length());
        return JSON.serialize(details);
    }

    private static List<DesiredFieldStateRow> parseDesiredStateRowsJson(String desiredStateRowsJson) {
        if (String.isBlank(desiredStateRowsJson)) {
            return new List<DesiredFieldStateRow>();
        }

        Object parsed;
        try {
            parsed = JSON.deserializeUntyped(desiredStateRowsJson);
        } catch (Exception ignored) {
            return new List<DesiredFieldStateRow>();
        }

        if (!(parsed instanceof List<Object>)) {
            return new List<DesiredFieldStateRow>();
        }

        List<DesiredFieldStateRow> rows = new List<DesiredFieldStateRow>();
        for (Object rowObject : (List<Object>) parsed) {
            if (!(rowObject instanceof Map<String, Object>)) {
                continue;
            }
            rows.add(parseDesiredFieldStateRow((Map<String, Object>) rowObject));
        }

        return rows;
    }

    private static DesiredFieldStateRow parseDesiredFieldStateRow(Map<String, Object> rowMap) {
        DesiredFieldStateRow row = new DesiredFieldStateRow();
        if (rowMap == null) {
            return row;
        }

        row.fieldPath = objectToString(rowMap.get('fieldPath'));
        row.field = objectToString(rowMap.get('field'));
        row.fieldApiName = objectToString(rowMap.get('fieldApiName'));
        row.apiName = objectToString(rowMap.get('apiName'));
        row.key = objectToString(rowMap.get('key'));
        row.permissionsRead = objectToBoolean(rowMap.get('permissionsRead'));
        row.permissionsEdit = objectToBoolean(rowMap.get('permissionsEdit'));
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

    private static Map<String, Object> buildIncomingRowDebug(DesiredFieldStateRow row) {
        Map<String, Object> debugRow = new Map<String, Object>();
        if (row == null) {
            return debugRow;
        }

        debugRow.put('fieldPath', row.fieldPath);
        debugRow.put('field', row.field);
        debugRow.put('fieldApiName', row.fieldApiName);
        debugRow.put('apiName', row.apiName);
        debugRow.put('key', row.key);
        debugRow.put('permissionsRead', row.permissionsRead);
        debugRow.put('permissionsEdit', row.permissionsEdit);
        return debugRow;
    }

    private static String resolveFieldPath(
        String incomingFieldPath,
        String objectApiName,
        Map<String, FieldCatalogRow> catalogByPath,
        Map<String, String> canonicalFieldByLower
    ) {
        if (String.isBlank(incomingFieldPath) || catalogByPath == null || catalogByPath.isEmpty()) {
            return null;
        }

        String trimmed = incomingFieldPath.trim();
        if (String.isBlank(trimmed)) {
            return null;
        }

        if (catalogByPath.containsKey(trimmed)) {
            return trimmed;
        }

        String canonical = canonicalFieldByLower == null ? null : canonicalFieldByLower.get(trimmed.toLowerCase());
        if (!String.isBlank(canonical)) {
            return canonical;
        }

        if (!String.isBlank(objectApiName) && !trimmed.contains('.')) {
            String candidate = objectApiName + '.' + trimmed;
            if (catalogByPath.containsKey(candidate)) {
                return candidate;
            }

            String canonicalCandidate = canonicalFieldByLower == null ? null : canonicalFieldByLower.get(candidate.toLowerCase());
            if (!String.isBlank(canonicalCandidate)) {
                return canonicalCandidate;
            }
        }

        return null;
    }

    private static String validateObjectApiName(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_Field_Error_NoObjectSelected);
        }

        String normalized = objectApiName.trim();
        Set<String> validObjects = new Set<String>();
        for (c23_SchemaService.SObjectCatalogRow objectRow : c23_SchemaService.getSObjectCatalog()) {
            validObjects.add(objectRow.apiName);
        }

        if (!validObjects.contains(normalized)) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_Field_Error_NoObjectSelected);
        }

        return normalized;
    }

    private static Map<String, FieldCatalogRow> buildFieldCatalogByPath(String objectApiName) {
        Map<String, FieldCatalogRow> response = new Map<String, FieldCatalogRow>();

        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
        if (objectType == null) {
            return response;
        }

        Map<String, Schema.SObjectField> describeFields = objectType.getDescribe().fields.getMap();
        Set<String> fieldPaths = new Set<String>();
        for (AggregateResult aggregateResult : [
            SELECT Field fieldPath
            FROM FieldPermissions
            WHERE SObjectType = :objectApiName
            GROUP BY Field
        ]) {
            String fieldPath = (String) aggregateResult.get('fieldPath');
            if (!String.isBlank(fieldPath) && fieldPath.startsWith(objectApiName + '.')) {
                fieldPaths.add(fieldPath);
            }
        }

        if (fieldPaths.isEmpty()) {
            for (String fieldApiName : describeFields.keySet()) {
                fieldPaths.add(objectApiName + '.' + fieldApiName);
            }
        }

        Integer splitIndex = objectApiName.length() + 1;
        for (String fieldPath : fieldPaths) {
            if (String.isBlank(fieldPath) || fieldPath.length() <= splitIndex) {
                continue;
            }

            String fieldApiName = fieldPath.substring(splitIndex);
            if (!describeFields.containsKey(fieldApiName)) {
                continue;
            }

            Schema.DescribeFieldResult fieldDescribe = describeFields.get(fieldApiName).getDescribe();
            if (fieldDescribe.isDeprecatedAndHidden()) {
                continue;
            }

            FieldCatalogRow row = new FieldCatalogRow();
            row.fieldPath = fieldPath;
            row.fieldApiName = fieldApiName;
            row.label = fieldDescribe.getLabel();
            row.dataType = toDisplayTypeLabel(fieldDescribe.getType());
            row.isRequired = fieldDescribe.isCreateable() && !fieldDescribe.isNillable() && !fieldDescribe.isDefaultedOnCreate();
            row.isCustom = fieldDescribe.isCustom();
            response.put(fieldPath, row);
        }

        return response;
    }

    private static PermissionState fromExisting(FieldPermissions existing) {
        PermissionState state = new PermissionState();
        if (existing == null) {
            return state;
        }

        state.readAccess = existing.PermissionsRead;
        state.editAccess = existing.PermissionsEdit;
        return normalizeState(state.readAccess, state.editAccess);
    }

    private static void applyState(FieldPermissions recordValue, PermissionState state) {
        recordValue.PermissionsRead = state.readAccess;
        recordValue.PermissionsEdit = state.editAccess;
    }

    private static PermissionState normalizeState(Boolean readAccess, Boolean editAccess) {
        PermissionState state = new PermissionState();
        state.readAccess = readAccess == true;
        state.editAccess = editAccess == true;

        if (state.editAccess) {
            state.readAccess = true;
        }

        if (!state.readAccess) {
            state.editAccess = false;
        }

        return state;
    }

    private static String toDisplayTypeLabel(Schema.DisplayType displayType) {
        if (displayType == null) {
            return '';
        }

        String rawValue = String.valueOf(displayType);
        if (String.isBlank(rawValue)) {
            return '';
        }

        List<String> titleWords = new List<String>();
        for (String rawPart : rawValue.toLowerCase().split('_')) {
            if (String.isBlank(rawPart)) {
                continue;
            }

            titleWords.add(rawPart.substring(0, 1).toUpperCase() + rawPart.substring(1));
        }

        return String.join(titleWords, ' ');
    }
}