public with sharing class c23_PermissionStudioObjectPermService {
    private static final Integer PREVIEW_SAMPLE_LIMIT = 25;

    public class ObjectMatrixRow {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean isCustom;
        @AuraEnabled public Boolean permissionsRead;
        @AuraEnabled public Boolean permissionsCreate;
        @AuraEnabled public Boolean permissionsEdit;
        @AuraEnabled public Boolean permissionsDelete;
        @AuraEnabled public Boolean permissionsViewAllFields;
        @AuraEnabled public Boolean permissionsViewAllRecords;
        @AuraEnabled public Boolean permissionsModifyAllRecords;
        @AuraEnabled public Boolean currentPermissionsRead;
        @AuraEnabled public Boolean currentPermissionsCreate;
        @AuraEnabled public Boolean currentPermissionsEdit;
        @AuraEnabled public Boolean currentPermissionsDelete;
        @AuraEnabled public Boolean currentPermissionsViewAllFields;
        @AuraEnabled public Boolean currentPermissionsViewAllRecords;
        @AuraEnabled public Boolean currentPermissionsModifyAllRecords;
    }

    public class DesiredStateRow {
        @AuraEnabled public String apiName;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String sObjectType;
        @AuraEnabled public String objectType;
        @AuraEnabled public String key;
        @AuraEnabled public Boolean permissionsRead;
        @AuraEnabled public Boolean permissionsCreate;
        @AuraEnabled public Boolean permissionsEdit;
        @AuraEnabled public Boolean permissionsDelete;
        @AuraEnabled public Boolean permissionsViewAllFields;
        @AuraEnabled public Boolean permissionsViewAllRecords;
        @AuraEnabled public Boolean permissionsModifyAllRecords;
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

    public class ApplyObjectMatrixJsonRequest {
        @AuraEnabled public String parentPermissionSetId;
        @AuraEnabled public String permissionSetId;
        @AuraEnabled public String desiredStateRowsJson;
        @AuraEnabled public String changeNote;
    }

    private class PermissionState {
        public Boolean readAccess;
        public Boolean createAccess;
        public Boolean editAccess;
        public Boolean deleteAccess;
        public Boolean viewAllFieldsAccess;
        public Boolean viewAllAccess;
        public Boolean modifyAllAccess;

        public PermissionState() {
            readAccess = false;
            createAccess = false;
            editAccess = false;
            deleteAccess = false;
            viewAllFieldsAccess = false;
            viewAllAccess = false;
            modifyAllAccess = false;
        }

        public Boolean sameAs(PermissionState otherState) {
            if (otherState == null) {
                return false;
            }
            return readAccess == otherState.readAccess &&
                createAccess == otherState.createAccess &&
                editAccess == otherState.editAccess &&
                deleteAccess == otherState.deleteAccess &&
                viewAllFieldsAccess == otherState.viewAllFieldsAccess &&
                viewAllAccess == otherState.viewAllAccess &&
                modifyAllAccess == otherState.modifyAllAccess;
        }

        public String toJson() {
            Map<String, Object> valueMap = new Map<String, Object>();
            valueMap.put('read', readAccess);
            valueMap.put('create', createAccess);
            valueMap.put('edit', editAccess);
            valueMap.put('delete', deleteAccess);
            valueMap.put('viewAllFields', viewAllFieldsAccess);
            valueMap.put('viewAll', viewAllAccess);
            valueMap.put('modifyAll', modifyAllAccess);
            return JSON.serialize(valueMap);
        }
    }

    private class ChangeComputationResult {
        public PermissionSet permissionSetRecord;
        public Integer totalRequestedCount = 0;
        public Integer insertCount = 0;
        public Integer updateCount = 0;
        public Integer changedCount = 0;
        public List<ObjectPermissions> toInsert = new List<ObjectPermissions>();
        public List<ObjectPermissions> toUpdate = new List<ObjectPermissions>();
        public List<DiffSampleRow> previewSamples = new List<DiffSampleRow>();
        public List<c23_PermissionStudioLedgerService.LedgerItemPayload> ledgerItems =
            new List<c23_PermissionStudioLedgerService.LedgerItemPayload>();
    }

    @AuraEnabled
    public static List<ObjectMatrixRow> getObjectMatrix(Id parentPermissionSetId) {
        c23_PermissionStudioSecurity.assertAccess();
        PermissionSet permissionSetRecord = c23_PermissionStudioSecurity.validatePermissionSet(
            parentPermissionSetId,
            'ObjectPerm.getObjectMatrix'
        );

        List<c23_SchemaService.SObjectCatalogRow> catalogRows = c23_SchemaService.getSObjectCatalog();
        Set<String> objectApiNames = new Set<String>();
        for (c23_SchemaService.SObjectCatalogRow catalogRow : catalogRows) {
            objectApiNames.add(catalogRow.apiName);
        }

        Map<String, ObjectPermissions> existingPermissionMap = new Map<String, ObjectPermissions>();
        for (ObjectPermissions existingPermission : [
            SELECT Id, SObjectType, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete,
                PermissionsViewAllFields, PermissionsViewAllRecords, PermissionsModifyAllRecords
            FROM ObjectPermissions
            WHERE ParentId = :permissionSetRecord.Id
                AND SObjectType IN :objectApiNames
        ]) {
            existingPermissionMap.put(existingPermission.SObjectType, existingPermission);
        }

        List<ObjectMatrixRow> matrixRows = new List<ObjectMatrixRow>();
        for (c23_SchemaService.SObjectCatalogRow catalogRow : catalogRows) {
            ObjectPermissions existingPermission = existingPermissionMap.get(catalogRow.apiName);
            PermissionState currentState = fromExisting(existingPermission);

            ObjectMatrixRow row = new ObjectMatrixRow();
            row.apiName = catalogRow.apiName;
            row.label = catalogRow.label;
            row.isCustom = catalogRow.isCustom;
            row.permissionsRead = currentState.readAccess;
            row.permissionsCreate = currentState.createAccess;
            row.permissionsEdit = currentState.editAccess;
            row.permissionsDelete = currentState.deleteAccess;
            row.permissionsViewAllFields = currentState.viewAllFieldsAccess;
            row.permissionsViewAllRecords = currentState.viewAllAccess;
            row.permissionsModifyAllRecords = currentState.modifyAllAccess;
            row.currentPermissionsRead = currentState.readAccess;
            row.currentPermissionsCreate = currentState.createAccess;
            row.currentPermissionsEdit = currentState.editAccess;
            row.currentPermissionsDelete = currentState.deleteAccess;
            row.currentPermissionsViewAllFields = currentState.viewAllFieldsAccess;
            row.currentPermissionsViewAllRecords = currentState.viewAllAccess;
            row.currentPermissionsModifyAllRecords = currentState.modifyAllAccess;
            matrixRows.add(row);
        }

        return matrixRows;
    }

    @AuraEnabled
    public static PreviewResponse previewApplyObjectMatrix(Id parentPermissionSetId, List<DesiredStateRow> desiredStateRows) {
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
    public static ApplyResponse applyObjectMatrix(
        Id parentPermissionSetId,
        List<DesiredStateRow> desiredStateRows,
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

        if (!result.toUpdate.isEmpty()) {
            update result.toUpdate;
        }

        c23_PermissionStudioLedgerService.LedgerWriteResult ledgerResult =
            c23_PermissionStudioLedgerService.writeObjectPermissionChangeSafe(
                result.permissionSetRecord.Id,
                result.permissionSetRecord.Label,
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
        response.message = Label.c23_PS_ObjectMatrix_ApplySuccess;
        return response;
    }

    @AuraEnabled
    public static ApplyResponse applyObjectMatrixJson(
        Id parentPermissionSetId,
        String desiredStateRowsJson,
        String changeNote
    ) {
        c23_PermissionStudioSecurity.assertAccess();
        if (parentPermissionSetId == null) {
            throw c23_PermissionStudioSecurity.handled(
                Label.c23_PS_Error_InvalidPermissionSet,
                'ObjectPerm.applyObjectMatrixJson',
                buildInvalidPermissionSetRequestDetails(null, desiredStateRowsJson),
                null
            );
        }
        List<DesiredStateRow> desiredStateRows = parseDesiredStateRowsJson(desiredStateRowsJson);
        return applyObjectMatrix(parentPermissionSetId, desiredStateRows, changeNote);
    }

    @AuraEnabled
    public static ApplyResponse applyObjectMatrixJsonRequest(ApplyObjectMatrixJsonRequest request) {
        c23_PermissionStudioSecurity.assertAccess();
        return applyObjectMatrixJsonRequestInternal(request);
    }

    @AuraEnabled
    public static ApplyResponse applyObjectMatrixJsonEnvelope(String requestJson) {
        c23_PermissionStudioSecurity.assertAccess();
        ApplyObjectMatrixJsonRequest request = parseApplyObjectMatrixJsonRequest(requestJson);
        return applyObjectMatrixJsonRequestInternal(request);
    }

    private static ApplyResponse applyObjectMatrixJsonRequestInternal(ApplyObjectMatrixJsonRequest request) {
        if (request == null) {
            throw c23_PermissionStudioSecurity.handled(
                Label.c23_PS_Error_InvalidDesiredRows,
                'ObjectPerm.applyObjectMatrixJsonRequest',
                null,
                null
            );
        }

        Id parentPermissionSetId = parseId(firstNonBlank(new List<String>{ request.parentPermissionSetId, request.permissionSetId }));
        if (parentPermissionSetId == null) {
            throw c23_PermissionStudioSecurity.handled(
                Label.c23_PS_Error_InvalidPermissionSet,
                'ObjectPerm.applyObjectMatrixJsonRequest',
                buildInvalidPermissionSetRequestDetails(request, request.desiredStateRowsJson),
                null
            );
        }

        return applyObjectMatrixJson(
            parentPermissionSetId,
            request.desiredStateRowsJson,
            request.changeNote
        );
    }

    private static ApplyObjectMatrixJsonRequest parseApplyObjectMatrixJsonRequest(String requestJson) {
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
        ApplyObjectMatrixJsonRequest request = new ApplyObjectMatrixJsonRequest();
        request.parentPermissionSetId = objectToString(valueMap.get('parentPermissionSetId'));
        request.permissionSetId = objectToString(valueMap.get('permissionSetId'));
        request.desiredStateRowsJson = objectToString(valueMap.get('desiredStateRowsJson'));
        request.changeNote = objectToString(valueMap.get('changeNote'));
        return request;
    }

    private static ChangeComputationResult computeChanges(Id parentPermissionSetId, List<DesiredStateRow> desiredStateRows) {
        ChangeComputationResult result = new ChangeComputationResult();
        result.permissionSetRecord = c23_PermissionStudioSecurity.validatePermissionSet(
            parentPermissionSetId,
            'ObjectPerm.computeChanges'
        );

        if (desiredStateRows == null || desiredStateRows.isEmpty()) {
            return result;
        }

        Map<String, Schema.SObjectType> describeByApiName = Schema.getGlobalDescribe();
        Map<String, String> canonicalObjectApiByLower = new Map<String, String>();
        for (String describedApiName : describeByApiName.keySet()) {
            Schema.SObjectType describeType = describeByApiName.get(describedApiName);
            if (describeType == null) {
                continue;
            }

            String canonicalApiName = describeType.getDescribe().getName();
            if (String.isBlank(canonicalApiName)) {
                continue;
            }

            canonicalObjectApiByLower.put(describedApiName.toLowerCase(), canonicalApiName);
            canonicalObjectApiByLower.put(canonicalApiName.toLowerCase(), canonicalApiName);
        }

        Map<String, PermissionState> desiredStateByObject = new Map<String, PermissionState>();
        for (DesiredStateRow desiredStateRow : desiredStateRows) {
            if (desiredStateRow == null) {
                continue;
            }

            String objectApiName = resolveObjectApiName(
                firstNonBlank(
                    new List<String>{
                        desiredStateRow.apiName,
                        desiredStateRow.objectApiName,
                        desiredStateRow.sObjectType,
                        desiredStateRow.objectType,
                        desiredStateRow.key
                    }
                ),
                canonicalObjectApiByLower
            );
            if (!isValidObjectApiName(objectApiName, describeByApiName)) {
                continue;
            }

            desiredStateByObject.put(
                objectApiName,
                normalizeState(
                    desiredStateRow.permissionsRead,
                    desiredStateRow.permissionsCreate,
                    desiredStateRow.permissionsEdit,
                    desiredStateRow.permissionsDelete,
                    desiredStateRow.permissionsViewAllFields,
                    desiredStateRow.permissionsViewAllRecords,
                    desiredStateRow.permissionsModifyAllRecords
                )
            );
        }

        if (desiredStateByObject.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(
                Label.c23_PS_Error_InvalidDesiredRows,
                'ObjectPerm.computeChanges',
                buildInvalidDesiredRowsDetails(result.permissionSetRecord.Id, desiredStateRows, desiredStateByObject),
                result.permissionSetRecord.Id
            );
        }

        result.totalRequestedCount = desiredStateByObject.size();

        Map<String, ObjectPermissions> existingPermissionMap = new Map<String, ObjectPermissions>();
        for (ObjectPermissions existingPermission : [
            SELECT Id, SObjectType, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete,
                PermissionsViewAllFields, PermissionsViewAllRecords, PermissionsModifyAllRecords
            FROM ObjectPermissions
            WHERE ParentId = :result.permissionSetRecord.Id
                AND SObjectType IN :desiredStateByObject.keySet()
        ]) {
            existingPermissionMap.put(existingPermission.SObjectType, existingPermission);
        }

        for (String objectApiName : desiredStateByObject.keySet()) {
            PermissionState desiredState = desiredStateByObject.get(objectApiName);
            ObjectPermissions existingPermission = existingPermissionMap.get(objectApiName);
            PermissionState beforeState = fromExisting(existingPermission);

            if (beforeState.sameAs(desiredState)) {
                continue;
            }

            if (existingPermission == null) {
                ObjectPermissions newPermission = new ObjectPermissions();
                newPermission.ParentId = result.permissionSetRecord.Id;
                newPermission.SObjectType = objectApiName;
                applyState(newPermission, desiredState);
                result.toInsert.add(newPermission);
                result.insertCount++;
            } else {
                applyState(existingPermission, desiredState);
                result.toUpdate.add(existingPermission);
                result.updateCount++;
            }

            result.changedCount++;

            c23_PermissionStudioLedgerService.LedgerItemPayload ledgerItem =
                new c23_PermissionStudioLedgerService.LedgerItemPayload();
            ledgerItem.itemKey = objectApiName;
            ledgerItem.beforeJson = beforeState.toJson();
            ledgerItem.afterJson = desiredState.toJson();
            result.ledgerItems.add(ledgerItem);

            if (result.previewSamples.size() < PREVIEW_SAMPLE_LIMIT) {
                DiffSampleRow sampleRow = new DiffSampleRow();
                sampleRow.key = objectApiName;
                sampleRow.beforeJson = ledgerItem.beforeJson;
                sampleRow.afterJson = ledgerItem.afterJson;
                result.previewSamples.add(sampleRow);
            }
        }

        return result;
    }

    private static List<DesiredStateRow> parseDesiredStateRowsJson(String desiredStateRowsJson) {
        List<DesiredStateRow> rows = new List<DesiredStateRow>();
        if (String.isBlank(desiredStateRowsJson)) {
            return rows;
        }

        Object parsed;
        try {
            parsed = JSON.deserializeUntyped(desiredStateRowsJson);
        } catch (Exception ignored) {
            return rows;
        }

        if (!(parsed instanceof List<Object>)) {
            return rows;
        }

        for (Object rowObject : (List<Object>) parsed) {
            if (!(rowObject instanceof Map<String, Object>)) {
                continue;
            }
            rows.add(buildDesiredStateRowFromMap((Map<String, Object>) rowObject));
        }

        return rows;
    }

    private static DesiredStateRow buildDesiredStateRowFromMap(Map<String, Object> rowMap) {
        DesiredStateRow row = new DesiredStateRow();
        if (rowMap == null) {
            return row;
        }

        row.apiName = objectToString(rowMap.get('apiName'));
        row.objectApiName = objectToString(rowMap.get('objectApiName'));
        row.sObjectType = objectToString(rowMap.get('sObjectType'));
        row.objectType = objectToString(rowMap.get('objectType'));
        row.key = objectToString(rowMap.get('key'));
        row.permissionsRead = objectToBoolean(rowMap.get('permissionsRead'));
        row.permissionsCreate = objectToBoolean(rowMap.get('permissionsCreate'));
        row.permissionsEdit = objectToBoolean(rowMap.get('permissionsEdit'));
        row.permissionsDelete = objectToBoolean(rowMap.get('permissionsDelete'));
        row.permissionsViewAllFields = objectToBoolean(rowMap.get('permissionsViewAllFields'));
        row.permissionsViewAllRecords = objectToBoolean(rowMap.get('permissionsViewAllRecords'));
        row.permissionsModifyAllRecords = objectToBoolean(rowMap.get('permissionsModifyAllRecords'));
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

    private static Boolean isValidObjectApiName(String objectApiName, Map<String, Schema.SObjectType> describeByApiName) {
        if (String.isBlank(objectApiName) || describeByApiName == null || !describeByApiName.containsKey(objectApiName)) {
            return false;
        }

        Schema.DescribeSObjectResult describeResult = describeByApiName.get(objectApiName).getDescribe();
        return !describeResult.isDeprecatedAndHidden() && !describeResult.isCustomSetting();
    }

    private static String buildInvalidDesiredRowsDetails(
        Id permissionSetId,
        List<DesiredStateRow> desiredStateRows,
        Map<String, PermissionState> desiredStateByObject
    ) {
        Map<String, Object> details = new Map<String, Object>();
        details.put('permissionSetId', permissionSetId == null ? null : String.valueOf(permissionSetId));
        details.put('incomingCount', desiredStateRows == null ? 0 : desiredStateRows.size());
        details.put('acceptedCount', desiredStateByObject == null ? 0 : desiredStateByObject.size());
        details.put(
            'acceptedApiSample',
            desiredStateByObject == null ? new List<String>() : collectStringSample(desiredStateByObject.keySet(), 25)
        );

        List<String> incomingSample = new List<String>();
        List<Map<String, Object>> incomingRowSample = new List<Map<String, Object>>();
        if (desiredStateRows != null) {
            for (DesiredStateRow row : desiredStateRows) {
                String apiNameValue = row == null
                    ? null
                    : firstNonBlank(
                        new List<String>{
                            row.apiName,
                            row.objectApiName,
                            row.sObjectType,
                            row.objectType,
                            row.key
                        }
                    );
                if (String.isBlank(apiNameValue)) {
                    if (row != null && incomingRowSample.size() < 10) {
                        incomingRowSample.add(buildIncomingRowDebug(row));
                    }
                    continue;
                }
                incomingSample.add(apiNameValue.trim());
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
        ApplyObjectMatrixJsonRequest request,
        String desiredStateRowsJson
    ) {
        Map<String, Object> details = new Map<String, Object>();
        details.put('parentPermissionSetId', request == null ? null : request.parentPermissionSetId);
        details.put('permissionSetId', request == null ? null : request.permissionSetId);
        details.put('hasDesiredStateRowsJson', !String.isBlank(desiredStateRowsJson));
        details.put('desiredStateRowsJsonLength', String.isBlank(desiredStateRowsJson) ? 0 : desiredStateRowsJson.length());
        return JSON.serialize(details);
    }

    private static String resolveObjectApiName(String incomingApiName, Map<String, String> canonicalObjectApiByLower) {
        if (String.isBlank(incomingApiName)) {
            return null;
        }

        String trimmed = incomingApiName.trim();
        if (String.isBlank(trimmed)) {
            return null;
        }

        if (canonicalObjectApiByLower == null) {
            return trimmed;
        }

        String canonical = canonicalObjectApiByLower.get(trimmed.toLowerCase());
        return String.isBlank(canonical) ? trimmed : canonical;
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

    private static Map<String, Object> buildIncomingRowDebug(DesiredStateRow row) {
        Map<String, Object> debugRow = new Map<String, Object>();
        if (row == null) {
            return debugRow;
        }

        debugRow.put('apiName', row.apiName);
        debugRow.put('objectApiName', row.objectApiName);
        debugRow.put('sObjectType', row.sObjectType);
        debugRow.put('objectType', row.objectType);
        debugRow.put('key', row.key);
        debugRow.put('permissionsRead', row.permissionsRead);
        debugRow.put('permissionsCreate', row.permissionsCreate);
        debugRow.put('permissionsEdit', row.permissionsEdit);
        debugRow.put('permissionsDelete', row.permissionsDelete);
        debugRow.put('permissionsViewAllFields', row.permissionsViewAllFields);
        debugRow.put('permissionsViewAllRecords', row.permissionsViewAllRecords);
        debugRow.put('permissionsModifyAllRecords', row.permissionsModifyAllRecords);
        return debugRow;
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

    private static PermissionState fromExisting(ObjectPermissions existingPermission) {
        PermissionState state = new PermissionState();
        if (existingPermission == null) {
            return state;
        }

        state.readAccess = existingPermission.PermissionsRead;
        state.createAccess = existingPermission.PermissionsCreate;
        state.editAccess = existingPermission.PermissionsEdit;
        state.deleteAccess = existingPermission.PermissionsDelete;
        state.viewAllFieldsAccess = existingPermission.PermissionsViewAllFields;
        state.viewAllAccess = existingPermission.PermissionsViewAllRecords;
        state.modifyAllAccess = existingPermission.PermissionsModifyAllRecords;
        return normalizeState(
            state.readAccess,
            state.createAccess,
            state.editAccess,
            state.deleteAccess,
            state.viewAllFieldsAccess,
            state.viewAllAccess,
            state.modifyAllAccess
        );
    }

    private static void applyState(ObjectPermissions permissionRecord, PermissionState state) {
        permissionRecord.PermissionsRead = state.readAccess;
        permissionRecord.PermissionsCreate = state.createAccess;
        permissionRecord.PermissionsEdit = state.editAccess;
        permissionRecord.PermissionsDelete = state.deleteAccess;
        permissionRecord.PermissionsViewAllFields = state.viewAllFieldsAccess;
        permissionRecord.PermissionsViewAllRecords = state.viewAllAccess;
        permissionRecord.PermissionsModifyAllRecords = state.modifyAllAccess;
    }

    private static PermissionState normalizeState(
        Boolean readAccess,
        Boolean createAccess,
        Boolean editAccess,
        Boolean deleteAccess,
        Boolean viewAllFieldsAccess,
        Boolean viewAllAccess,
        Boolean modifyAllAccess
    ) {
        PermissionState state = new PermissionState();
        state.readAccess = readAccess == true;
        state.createAccess = createAccess == true;
        state.editAccess = editAccess == true;
        state.deleteAccess = deleteAccess == true;
        state.viewAllFieldsAccess = viewAllFieldsAccess == true;
        state.viewAllAccess = viewAllAccess == true;
        state.modifyAllAccess = modifyAllAccess == true;

        if (state.modifyAllAccess) {
            state.readAccess = true;
            state.createAccess = true;
            state.editAccess = true;
            state.deleteAccess = true;
            state.viewAllFieldsAccess = true;
            state.viewAllAccess = true;
        }

        if (state.viewAllFieldsAccess) {
            state.readAccess = true;
        }

        if (state.viewAllAccess) {
            state.readAccess = true;
        }

        if (state.createAccess || state.editAccess || state.deleteAccess) {
            state.readAccess = true;
        }

        if (!state.readAccess) {
            state.createAccess = false;
            state.editAccess = false;
            state.deleteAccess = false;
            state.viewAllFieldsAccess = false;
            state.viewAllAccess = false;
            state.modifyAllAccess = false;
        }

        return state;
    }
}