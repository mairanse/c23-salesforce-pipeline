public with sharing class c23_ProfileMigrationCoordinatorQueueable implements Queueable {
    private Id jobId;
    private Id profileId;
    private String targetMode;
    private Id targetPermissionSetId;
    private String targetPermissionSetName;
    private String targetPermissionSetApiName;
    private String mergeStrategy;
    private String scopeOptionsJson;
    private Boolean assignUsersFromProfile;
    private Boolean switchUsersToBaseProfile;
    private Id baseProfileId;

    public c23_ProfileMigrationCoordinatorQueueable(
        Id jobId,
        Id profileId,
        String targetMode,
        Id targetPermissionSetId,
        String targetPermissionSetName,
        String targetPermissionSetApiName,
        String mergeStrategy,
        String scopeOptionsJson,
        Boolean assignUsersFromProfile,
        Boolean switchUsersToBaseProfile,
        Id baseProfileId
    ) {
        this.jobId = jobId;
        this.profileId = profileId;
        this.targetMode = targetMode;
        this.targetPermissionSetId = targetPermissionSetId;
        this.targetPermissionSetName = targetPermissionSetName;
        this.targetPermissionSetApiName = targetPermissionSetApiName;
        this.mergeStrategy = mergeStrategy;
        this.scopeOptionsJson = scopeOptionsJson;
        this.assignUsersFromProfile = assignUsersFromProfile == true;
        this.switchUsersToBaseProfile = switchUsersToBaseProfile == true;
        this.baseProfileId = baseProfileId;
    }

    public void execute(QueueableContext contextValue) {
        Integer errorCount = 0;
        List<c23_MigrationWarning__c> warnings = new List<c23_MigrationWarning__c>();
        Id resolvedTargetPermissionSetId = targetPermissionSetId;
        String resolvedTargetPermissionSetName = targetPermissionSetName;

        try {
            c23_ProfileMigrationJobService.markRunning(jobId);
            c23_ProfileMigrationPlanService.ScopeOptionsDTO scopeOptions =
                c23_ProfileMigrationPlanService.parseScopeOptions(scopeOptionsJson);

            Profile sourceProfile = loadProfile(profileId);
            PermissionSet sourcePermissionSet = loadSourcePermissionSet(sourceProfile.Id);

            PermissionSet targetPermissionSet;
            if (targetMode == c23_ProfileMigrationPlanService.TARGET_MODE_CREATE) {
                targetPermissionSet = createTargetPermissionSet(targetPermissionSetName, targetPermissionSetApiName, warnings);
            } else {
                targetPermissionSet = loadTargetPermissionSet(targetPermissionSetId);
            }

            resolvedTargetPermissionSetId = targetPermissionSet.Id;
            resolvedTargetPermissionSetName = String.isBlank(targetPermissionSet.Label)
                ? targetPermissionSet.Name
                : targetPermissionSet.Label;

            if (scopeOptions.includeObjectPermissions == true) {
                cloneObjectPermissions(sourcePermissionSet.Id, targetPermissionSet.Id, scopeOptions, warnings);
            }
            if (scopeOptions.includeFieldPermissions == true) {
                cloneFieldPermissions(sourcePermissionSet.Id, targetPermissionSet.Id, scopeOptions, warnings);
            }
            if (scopeOptions.includeSystemPermissions == true) {
                cloneSystemPermissions(sourcePermissionSet.Id, targetPermissionSet.Id, scopeOptions, warnings);
            }
            if (scopeOptions.includeTabVisibility == true) {
                cloneTabSettings(sourcePermissionSet.Id, targetPermissionSet.Id, scopeOptions, warnings);
            }
            if (scopeOptions.includeSetupAccess == true) {
                cloneSetupAccess(sourcePermissionSet.Id, targetPermissionSet.Id, scopeOptions, warnings);
            }

            c23_ProfileMigrationJobService.markFinalizing(jobId);

            if (assignUsersFromProfile == true) {
                c23_ProfileMigrationAssignmentService.AssignmentResultDTO assignResult =
                    c23_ProfileMigrationAssignmentService.assignUsersFromProfile(sourceProfile.Id, targetPermissionSet.Id);
                appendAssignmentWarnings(warnings, c23_ProfileMigrationPlanService.CATEGORY_SETUP, 'assign:' + sourceProfile.Id, assignResult);
            }

            if (switchUsersToBaseProfile == true && baseProfileId != null) {
                c23_ProfileMigrationAssignmentService.AssignmentResultDTO swapResult =
                    c23_ProfileMigrationAssignmentService.swapUsersToBaseProfile(sourceProfile.Id, baseProfileId);
                appendAssignmentWarnings(warnings, c23_ProfileMigrationPlanService.CATEGORY_SETUP, 'swap:' + sourceProfile.Id, swapResult);
            }
        } catch (Exception ex) {
            c23_ErrorLogService.logException(
                'ProfileMigrationCoordinator.execute',
                ex,
                'Migration coordinator execution failed.',
                jobId
            );
            errorCount++;
            warnings.add(buildWarning('SYSTEM', 'job:' + String.valueOf(jobId), ex.getMessage(), 'Error'));
        } finally {
            try {
                if (!warnings.isEmpty()) {
                    for (c23_MigrationWarning__c warningRow : warnings) {
                        warningRow.c23_Job__c = jobId;
                    }
                    c23_ProfileMigrationJobService.appendWarnings(jobId, warnings);
                }

                Integer warningCount = warnings.size();
                if (errorCount > 0) {
                    c23_ProfileMigrationJobService.markFailed(jobId, warningCount, errorCount);
                } else {
                    c23_ProfileMigrationJobService.markCompleted(
                        jobId,
                        resolvedTargetPermissionSetId,
                        resolvedTargetPermissionSetName,
                        warningCount,
                        errorCount
                    );
                }
            } catch (Exception ignored) {
                c23_ErrorLogService.logException(
                    'ProfileMigrationCoordinator.finalize',
                    ignored,
                    'Migration finalization failed after execution.',
                    jobId
                );
                c23_ProfileMigrationJobService.markFailed(jobId, warnings.size(), errorCount + 1);
            }
        }
    }

    private PermissionSet createTargetPermissionSet(
        String requestedLabel,
        String requestedApiName,
        List<c23_MigrationWarning__c> warnings
    ) {
        String safeLabel = String.isBlank(requestedLabel) ? Label.c23_PS_MIG_DefaultTargetName : requestedLabel.trim();
        String safeApiName = sanitizeApiName(requestedApiName);
        if (String.isBlank(safeApiName)) {
            safeApiName = sanitizeApiName(safeLabel);
        }

        List<PermissionSet> existing = [
            SELECT Id, Name
            FROM PermissionSet
            WHERE Name = :safeApiName
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            String suffix = String.valueOf(Datetime.now().getTime());
            safeApiName = (safeApiName + '_' + suffix);
            if (safeApiName.length() > 40) {
                safeApiName = safeApiName.substring(0, 40);
            }
            warnings.add(buildWarning(
                'SYSTEM',
                'target:' + safeApiName,
                Label.c23_PS_MIG_Warn_TargetApiAdjusted,
                'Warn'
            ));
        }

        PermissionSet target = new PermissionSet(
            Name = safeApiName,
            Label = safeLabel
        );
        insert target;
        return target;
    }

    private static String sanitizeApiName(String apiName) {
        String normalized = String.isBlank(apiName) ? '' : apiName.trim();
        normalized = normalized.replaceAll('[^A-Za-z0-9_]', '_');
        normalized = normalized.replaceAll('_+', '_');
        if (String.isBlank(normalized)) {
            return normalized;
        }
        if (!Pattern.matches('^[A-Za-z].*', normalized)) {
            normalized = 'PS_' + normalized;
        }
        return normalized.length() > 40 ? normalized.substring(0, 40) : normalized;
    }

    private static Profile loadProfile(Id sourceProfileId) {
        List<Profile> rows = [
            SELECT Id, Name
            FROM Profile
            WHERE Id = :sourceProfileId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_MIG_Error_InvalidProfile);
        }
        return rows[0];
    }

    private static PermissionSet loadSourcePermissionSet(Id sourceProfileId) {
        List<PermissionSet> rows = [
            SELECT Id, Name, Label
            FROM PermissionSet
            WHERE ProfileId = :sourceProfileId
                AND IsOwnedByProfile = true
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_MIG_Error_InvalidProfileSource);
        }
        return rows[0];
    }

    private static PermissionSet loadTargetPermissionSet(Id permissionSetId) {
        List<PermissionSet> rows = [
            SELECT Id, Name, Label
            FROM PermissionSet
            WHERE Id = :permissionSetId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_MIG_Error_TargetMergeSelection);
        }
        return rows[0];
    }

    private void cloneObjectPermissions(
        Id sourcePermissionSetId,
        Id targetPermissionSetId,
        c23_ProfileMigrationPlanService.ScopeOptionsDTO scopeOptions,
        List<c23_MigrationWarning__c> warnings
    ) {
        Set<String> customObjects = scopeOptions.includeCustomObjectsOnly == true ? getCustomObjectApiNames() : new Set<String>();

        List<ObjectPermissions> sourceRows = [
            SELECT SObjectType,
                PermissionsRead,
                PermissionsCreate,
                PermissionsEdit,
                PermissionsDelete,
                PermissionsViewAllRecords,
                PermissionsModifyAllRecords
            FROM ObjectPermissions
            WHERE ParentId = :sourcePermissionSetId
        ];

        Set<String> objectApiNames = new Set<String>();
        for (ObjectPermissions sourceRow : sourceRows) {
            objectApiNames.add(sourceRow.SObjectType);
        }

        Map<String, ObjectPermissions> targetByObject = new Map<String, ObjectPermissions>();
        if (!objectApiNames.isEmpty()) {
            for (ObjectPermissions targetRow : [
                SELECT Id,
                    SObjectType,
                    PermissionsRead,
                    PermissionsCreate,
                    PermissionsEdit,
                    PermissionsDelete,
                    PermissionsViewAllRecords,
                    PermissionsModifyAllRecords
                FROM ObjectPermissions
                WHERE ParentId = :targetPermissionSetId
                    AND SObjectType IN :objectApiNames
            ]) {
                targetByObject.put(targetRow.SObjectType, targetRow);
            }
        }

        List<ObjectPermissions> toInsert = new List<ObjectPermissions>();
        List<ObjectPermissions> toUpdate = new List<ObjectPermissions>();
        List<String> insertKeys = new List<String>();
        List<String> updateKeys = new List<String>();

        for (ObjectPermissions sourceRow : sourceRows) {
            if (scopeOptions.includeCustomObjectsOnly == true && !customObjects.contains(sourceRow.SObjectType)) {
                continue;
            }

            ObjectPermissions targetRow = targetByObject.get(sourceRow.SObjectType);
            Boolean sourceRead = sourceRow.PermissionsRead == true;
            Boolean sourceCreate = sourceRow.PermissionsCreate == true;
            Boolean sourceEdit = sourceRow.PermissionsEdit == true;
            Boolean sourceDelete = sourceRow.PermissionsDelete == true;
            Boolean sourceViewAll = sourceRow.PermissionsViewAllRecords == true;
            Boolean sourceModifyAll = sourceRow.PermissionsModifyAllRecords == true;

            if (scopeOptions.includeGrantedOnly == true && !hasAnyObjectGrant(sourceRead, sourceCreate, sourceEdit, sourceDelete, sourceViewAll, sourceModifyAll)) {
                continue;
            }

            Boolean targetRead = targetRow == null ? false : targetRow.PermissionsRead == true;
            Boolean targetCreate = targetRow == null ? false : targetRow.PermissionsCreate == true;
            Boolean targetEdit = targetRow == null ? false : targetRow.PermissionsEdit == true;
            Boolean targetDelete = targetRow == null ? false : targetRow.PermissionsDelete == true;
            Boolean targetViewAll = targetRow == null ? false : targetRow.PermissionsViewAllRecords == true;
            Boolean targetModifyAll = targetRow == null ? false : targetRow.PermissionsModifyAllRecords == true;

            Boolean resultRead = mergeBoolean(sourceRead, targetRead);
            Boolean resultCreate = mergeBoolean(sourceCreate, targetCreate);
            Boolean resultEdit = mergeBoolean(sourceEdit, targetEdit);
            Boolean resultDelete = mergeBoolean(sourceDelete, targetDelete);
            Boolean resultViewAll = mergeBoolean(sourceViewAll, targetViewAll);
            Boolean resultModifyAll = mergeBoolean(sourceModifyAll, targetModifyAll);

            if (targetRow == null) {
                if (!hasAnyObjectGrant(resultRead, resultCreate, resultEdit, resultDelete, resultViewAll, resultModifyAll)) {
                    continue;
                }
                ObjectPermissions toCreate = new ObjectPermissions();
                toCreate.ParentId = targetPermissionSetId;
                toCreate.SObjectType = sourceRow.SObjectType;
                applyObjectState(toCreate, resultRead, resultCreate, resultEdit, resultDelete, resultViewAll, resultModifyAll);
                toInsert.add(toCreate);
                insertKeys.add(sourceRow.SObjectType);
                continue;
            }

            if (targetRead == resultRead &&
                targetCreate == resultCreate &&
                targetEdit == resultEdit &&
                targetDelete == resultDelete &&
                targetViewAll == resultViewAll &&
                targetModifyAll == resultModifyAll) {
                continue;
            }

            applyObjectState(targetRow, resultRead, resultCreate, resultEdit, resultDelete, resultViewAll, resultModifyAll);
            toUpdate.add(targetRow);
            updateKeys.add(sourceRow.SObjectType);
        }

        processObjectPermissionDml(toInsert, insertKeys, true, warnings);
        processObjectPermissionDml(toUpdate, updateKeys, false, warnings);
    }

    private void cloneFieldPermissions(
        Id sourcePermissionSetId,
        Id targetPermissionSetId,
        c23_ProfileMigrationPlanService.ScopeOptionsDTO scopeOptions,
        List<c23_MigrationWarning__c> warnings
    ) {
        Set<String> customObjects = scopeOptions.includeCustomObjectsOnly == true ? getCustomObjectApiNames() : new Set<String>();

        List<FieldPermissions> sourceRows = [
            SELECT Field, PermissionsRead, PermissionsEdit
            FROM FieldPermissions
            WHERE ParentId = :sourcePermissionSetId
            LIMIT 50000
        ];

        Set<String> sourceFieldPaths = new Set<String>();
        for (FieldPermissions sourceRow : sourceRows) {
            if (String.isBlank(sourceRow.Field) || !sourceRow.Field.contains('.')) {
                continue;
            }
            String objectApiName = sourceRow.Field.substring(0, sourceRow.Field.indexOf('.'));
            if (scopeOptions.includeCustomObjectsOnly == true && !customObjects.contains(objectApiName)) {
                continue;
            }
            sourceFieldPaths.add(sourceRow.Field);
        }

        Map<String, FieldPermissions> targetByFieldPath = new Map<String, FieldPermissions>();
        if (!sourceFieldPaths.isEmpty()) {
            for (FieldPermissions targetRow : [
                SELECT Id, Field, PermissionsRead, PermissionsEdit
                FROM FieldPermissions
                WHERE ParentId = :targetPermissionSetId
                    AND Field IN :sourceFieldPaths
                LIMIT 50000
            ]) {
                targetByFieldPath.put(targetRow.Field, targetRow);
            }
        }

        List<FieldPermissions> toInsert = new List<FieldPermissions>();
        List<FieldPermissions> toUpdate = new List<FieldPermissions>();
        List<String> insertKeys = new List<String>();
        List<String> updateKeys = new List<String>();

        for (FieldPermissions sourceRow : sourceRows) {
            String fieldPath = sourceRow.Field;
            if (String.isBlank(fieldPath) || !fieldPath.contains('.')) {
                continue;
            }
            String objectApiName = fieldPath.substring(0, fieldPath.indexOf('.'));
            if (scopeOptions.includeCustomObjectsOnly == true && !customObjects.contains(objectApiName)) {
                continue;
            }
            if (!isValidFieldPath(fieldPath)) {
                warnings.add(buildWarning(
                    c23_ProfileMigrationPlanService.CATEGORY_FIELD,
                    fieldPath,
                    Label.c23_PS_MIG_Warn_FieldSkipped,
                    'Warn'
                ));
                continue;
            }

            Boolean sourceRead = sourceRow.PermissionsRead == true;
            Boolean sourceEdit = sourceRow.PermissionsEdit == true;
            if (scopeOptions.includeGrantedOnly == true && !sourceRead && !sourceEdit) {
                continue;
            }

            FieldPermissions targetRow = targetByFieldPath.get(fieldPath);
            Boolean targetRead = targetRow == null ? false : targetRow.PermissionsRead == true;
            Boolean targetEdit = targetRow == null ? false : targetRow.PermissionsEdit == true;

            Boolean resultRead = mergeBoolean(sourceRead, targetRead);
            Boolean resultEdit = mergeBoolean(sourceEdit, targetEdit);
            if (resultEdit) {
                resultRead = true;
            }
            if (!resultRead) {
                resultEdit = false;
            }

            if (targetRow == null) {
                if (!resultRead && !resultEdit) {
                    continue;
                }
                FieldPermissions toCreate = new FieldPermissions();
                toCreate.ParentId = targetPermissionSetId;
                toCreate.SObjectType = objectApiName;
                toCreate.Field = fieldPath;
                toCreate.PermissionsRead = resultRead;
                toCreate.PermissionsEdit = resultEdit;
                toInsert.add(toCreate);
                insertKeys.add(fieldPath);
                continue;
            }

            if (targetRead == resultRead && targetEdit == resultEdit) {
                continue;
            }

            targetRow.PermissionsRead = resultRead;
            targetRow.PermissionsEdit = resultEdit;
            toUpdate.add(targetRow);
            updateKeys.add(fieldPath);
        }

        processFieldPermissionDml(toInsert, insertKeys, true, warnings);
        processFieldPermissionDml(toUpdate, updateKeys, false, warnings);
    }

    private void cloneSystemPermissions(
        Id sourcePermissionSetId,
        Id targetPermissionSetId,
        c23_ProfileMigrationPlanService.ScopeOptionsDTO scopeOptions,
        List<c23_MigrationWarning__c> warnings
    ) {
        List<String> fieldApiNames = c23_ProfileMigrationPlanService.getSystemPermissionFieldApiNames(true);
        if (fieldApiNames.isEmpty()) {
            return;
        }

        PermissionSet source = queryPermissionSetWithFields(sourcePermissionSetId, fieldApiNames);
        PermissionSet target = queryPermissionSetWithFields(targetPermissionSetId, fieldApiNames);
        PermissionSet toUpdate = new PermissionSet(Id = targetPermissionSetId);
        Integer changedCount = 0;

        for (String fieldApiName : fieldApiNames) {
            Boolean sourceEnabled = source != null && (Boolean) source.get(fieldApiName);
            if (scopeOptions.includeGrantedOnly == true && !sourceEnabled) {
                continue;
            }
            Boolean targetEnabled = target != null && (Boolean) target.get(fieldApiName);
            Boolean resultEnabled = mergeBoolean(sourceEnabled, targetEnabled);
            if (resultEnabled == targetEnabled) {
                continue;
            }
            toUpdate.put(fieldApiName, resultEnabled);
            changedCount++;
        }

        if (changedCount > 0) {
            try {
                update toUpdate;
            } catch (Exception ex) {
                c23_ErrorLogService.logException(
                    'ProfileMigrationCoordinator.cloneSystemPermissions',
                    ex,
                    'Failed to update merged system permissions.',
                    targetPermissionSetId
                );
                warnings.add(buildWarning(
                    c23_ProfileMigrationPlanService.CATEGORY_SYSTEM,
                    'system',
                    ex.getMessage(),
                    'Error'
                ));
            }
        }
    }

    private void cloneTabSettings(
        Id sourcePermissionSetId,
        Id targetPermissionSetId,
        c23_ProfileMigrationPlanService.ScopeOptionsDTO scopeOptions,
        List<c23_MigrationWarning__c> warnings
    ) {
        Set<String> customTabNames = new Set<String>();
        if (scopeOptions.includeCustomObjectsOnly == true) {
            List<TabDefinition> customTabRows = [
                SELECT Name
                FROM TabDefinition
                WHERE IsCustom = true
                LIMIT 2000
            ];
            for (TabDefinition tabRow : customTabRows) {
                customTabNames.add(tabRow.Name);
            }
        }

        Map<String, PermissionSetTabSetting> sourceByName = new Map<String, PermissionSetTabSetting>();
        for (PermissionSetTabSetting sourceRow : [
            SELECT Name, Visibility
            FROM PermissionSetTabSetting
            WHERE ParentId = :sourcePermissionSetId
            LIMIT 5000
        ]) {
            sourceByName.put(sourceRow.Name, sourceRow);
        }

        if (sourceByName.isEmpty()) {
            return;
        }

        Map<String, PermissionSetTabSetting> targetByName = new Map<String, PermissionSetTabSetting>();
        for (PermissionSetTabSetting targetRow : [
            SELECT Id, Name, Visibility
            FROM PermissionSetTabSetting
            WHERE ParentId = :targetPermissionSetId
                AND Name IN :sourceByName.keySet()
            LIMIT 5000
        ]) {
            targetByName.put(targetRow.Name, targetRow);
        }

        List<PermissionSetTabSetting> toInsert = new List<PermissionSetTabSetting>();
        List<PermissionSetTabSetting> toUpdate = new List<PermissionSetTabSetting>();
        List<String> insertKeys = new List<String>();
        List<String> updateKeys = new List<String>();

        for (String tabName : sourceByName.keySet()) {
            if (scopeOptions.includeCustomObjectsOnly == true && !customTabNames.contains(tabName)) {
                continue;
            }

            PermissionSetTabSetting sourceRow = sourceByName.get(tabName);
            String sourceVisibility = normalizeVisibility(sourceRow.Visibility);
            if (scopeOptions.includeGrantedOnly == true && sourceVisibility == c23_ProfileMigrationPlanService.TAB_DEFAULT_OFF) {
                continue;
            }

            PermissionSetTabSetting targetRow = targetByName.get(tabName);
            String targetVisibility = targetRow == null
                ? c23_ProfileMigrationPlanService.TAB_DEFAULT_OFF
                : normalizeVisibility(targetRow.Visibility);
            String resultVisibility = mergeVisibility(sourceVisibility, targetVisibility);

            if (targetRow == null) {
                if (resultVisibility == c23_ProfileMigrationPlanService.TAB_DEFAULT_OFF) {
                    continue;
                }
                PermissionSetTabSetting toCreate = new PermissionSetTabSetting();
                toCreate.ParentId = targetPermissionSetId;
                toCreate.Name = tabName;
                toCreate.Visibility = resultVisibility;
                toInsert.add(toCreate);
                insertKeys.add(tabName);
                continue;
            }

            if (targetVisibility == resultVisibility) {
                continue;
            }

            targetRow.Visibility = resultVisibility;
            toUpdate.add(targetRow);
            updateKeys.add(tabName);
        }

        processTabSettingDml(toInsert, insertKeys, true, warnings);
        processTabSettingDml(toUpdate, updateKeys, false, warnings);
    }

    private void cloneSetupAccess(
        Id sourcePermissionSetId,
        Id targetPermissionSetId,
        c23_ProfileMigrationPlanService.ScopeOptionsDTO scopeOptions,
        List<c23_MigrationWarning__c> warnings
    ) {
        Map<String, SetupEntityAccess> sourceByKey = new Map<String, SetupEntityAccess>();
        for (SetupEntityAccess sourceRow : [
            SELECT SetupEntityId, SetupEntityType
            FROM SetupEntityAccess
            WHERE ParentId = :sourcePermissionSetId
                AND SetupEntityType IN :new Set<String>{
                    c23_ProfileMigrationPlanService.SETUP_TYPE_APEX_CLASS,
                    c23_ProfileMigrationPlanService.SETUP_TYPE_CUSTOM_PERMISSION
                }
            LIMIT 50000
        ]) {
            sourceByKey.put(sourceRow.SetupEntityType + ':' + String.valueOf(sourceRow.SetupEntityId), sourceRow);
        }

        if (sourceByKey.isEmpty()) {
            return;
        }

        Map<String, SetupEntityAccess> targetByKey = new Map<String, SetupEntityAccess>();
        for (SetupEntityAccess targetRow : [
            SELECT Id, SetupEntityId, SetupEntityType
            FROM SetupEntityAccess
            WHERE ParentId = :targetPermissionSetId
                AND SetupEntityType IN :new Set<String>{
                    c23_ProfileMigrationPlanService.SETUP_TYPE_APEX_CLASS,
                    c23_ProfileMigrationPlanService.SETUP_TYPE_CUSTOM_PERMISSION
                }
            LIMIT 50000
        ]) {
            targetByKey.put(targetRow.SetupEntityType + ':' + String.valueOf(targetRow.SetupEntityId), targetRow);
        }

        List<SetupEntityAccess> toInsert = new List<SetupEntityAccess>();
        List<String> insertKeys = new List<String>();
        List<SetupEntityAccess> toDelete = new List<SetupEntityAccess>();
        List<String> deleteKeys = new List<String>();

        for (String rowKey : sourceByKey.keySet()) {
            if (!targetByKey.containsKey(rowKey)) {
                SetupEntityAccess sourceRow = sourceByKey.get(rowKey);
                SetupEntityAccess toCreate = new SetupEntityAccess();
                toCreate.ParentId = targetPermissionSetId;
                toCreate.SetupEntityId = sourceRow.SetupEntityId;
                toInsert.add(toCreate);
                insertKeys.add(rowKey);
            }
        }

        if (mergeStrategy == c23_ProfileMigrationPlanService.MERGE_STRATEGY_OVERWRITE && scopeOptions.includeGrantedOnly == false) {
            for (String rowKey : targetByKey.keySet()) {
                if (sourceByKey.containsKey(rowKey)) {
                    continue;
                }
                toDelete.add(targetByKey.get(rowKey));
                deleteKeys.add(rowKey);
            }
        }

        if (!toInsert.isEmpty()) {
            Database.SaveResult[] insertResults = Database.insert(toInsert, false);
            captureDmlErrors(insertResults, insertKeys, c23_ProfileMigrationPlanService.CATEGORY_SETUP, warnings);
        }
        if (!toDelete.isEmpty()) {
            Database.DeleteResult[] deleteResults = Database.delete(toDelete, false);
            captureDeleteErrors(deleteResults, deleteKeys, c23_ProfileMigrationPlanService.CATEGORY_SETUP, warnings);
        }
    }

    private void processObjectPermissionDml(
        List<ObjectPermissions> rows,
        List<String> keys,
        Boolean isInsert,
        List<c23_MigrationWarning__c> warnings
    ) {
        if (rows.isEmpty()) {
            return;
        }
        if (isInsert == true) {
            Database.SaveResult[] results = Database.insert(rows, false);
            captureDmlErrors(results, keys, c23_ProfileMigrationPlanService.CATEGORY_OBJECT, warnings);
        } else {
            Database.SaveResult[] results = Database.update(rows, false);
            captureDmlErrors(results, keys, c23_ProfileMigrationPlanService.CATEGORY_OBJECT, warnings);
        }
    }

    private void processFieldPermissionDml(
        List<FieldPermissions> rows,
        List<String> keys,
        Boolean isInsert,
        List<c23_MigrationWarning__c> warnings
    ) {
        if (rows.isEmpty()) {
            return;
        }
        if (isInsert == true) {
            Database.SaveResult[] results = Database.insert(rows, false);
            captureDmlErrors(results, keys, c23_ProfileMigrationPlanService.CATEGORY_FIELD, warnings);
        } else {
            Database.SaveResult[] results = Database.update(rows, false);
            captureDmlErrors(results, keys, c23_ProfileMigrationPlanService.CATEGORY_FIELD, warnings);
        }
    }

    private void processTabSettingDml(
        List<PermissionSetTabSetting> rows,
        List<String> keys,
        Boolean isInsert,
        List<c23_MigrationWarning__c> warnings
    ) {
        if (rows.isEmpty()) {
            return;
        }
        if (isInsert == true) {
            Database.SaveResult[] results = Database.insert(rows, false);
            captureDmlErrors(results, keys, c23_ProfileMigrationPlanService.CATEGORY_TAB, warnings);
        } else {
            Database.SaveResult[] results = Database.update(rows, false);
            captureDmlErrors(results, keys, c23_ProfileMigrationPlanService.CATEGORY_TAB, warnings);
        }
    }

    private static void captureDmlErrors(
        Database.SaveResult[] results,
        List<String> keys,
        String category,
        List<c23_MigrationWarning__c> warnings
    ) {
        if (results == null) {
            return;
        }
        for (Integer index = 0; index < results.size(); index++) {
            if (results[index].isSuccess()) {
                continue;
            }
            String keyValue = index < keys.size() ? keys[index] : category + ':' + String.valueOf(index);
            warnings.add(buildWarning(category, keyValue, extractErrors(results[index].getErrors()), 'Error'));
        }
    }

    private static void captureDeleteErrors(
        Database.DeleteResult[] results,
        List<String> keys,
        String category,
        List<c23_MigrationWarning__c> warnings
    ) {
        if (results == null) {
            return;
        }
        for (Integer index = 0; index < results.size(); index++) {
            if (results[index].isSuccess()) {
                continue;
            }
            String keyValue = index < keys.size() ? keys[index] : category + ':' + String.valueOf(index);
            warnings.add(buildWarning(category, keyValue, extractErrors(results[index].getErrors()), 'Error'));
        }
    }

    private static void appendAssignmentWarnings(
        List<c23_MigrationWarning__c> warnings,
        String category,
        String keyPrefix,
        c23_ProfileMigrationAssignmentService.AssignmentResultDTO result
    ) {
        if (result == null || result.messages == null || result.messages.isEmpty()) {
            return;
        }
        for (String message : result.messages) {
            warnings.add(buildWarning(category, keyPrefix, message, 'Warn'));
        }
    }

    private static c23_MigrationWarning__c buildWarning(String category, String keyValue, String message, String severity) {
        c23_MigrationWarning__c row = new c23_MigrationWarning__c();
        row.c23_Category__c = category;
        row.c23_PermissionKey__c = keyValue;
        row.c23_Message__c = message;
        row.c23_Severity__c = severity;
        return row;
    }

    private static String extractErrors(Database.Error[] errors) {
        if (errors == null || errors.isEmpty()) {
            return Label.c23_PS_General_Error;
        }
        List<String> messages = new List<String>();
        for (Database.Error errorRow : errors) {
            messages.add(errorRow.getMessage());
        }
        return String.join(messages, '; ');
    }

    private Boolean hasAnyObjectGrant(Boolean readValue, Boolean createValue, Boolean editValue, Boolean deleteValue, Boolean viewAllValue, Boolean modifyAllValue) {
        return readValue || createValue || editValue || deleteValue || viewAllValue || modifyAllValue;
    }

    private void applyObjectState(
        ObjectPermissions row,
        Boolean readValue,
        Boolean createValue,
        Boolean editValue,
        Boolean deleteValue,
        Boolean viewAllValue,
        Boolean modifyAllValue
    ) {
        Boolean safeRead = readValue == true;
        Boolean safeCreate = createValue == true;
        Boolean safeEdit = editValue == true;
        Boolean safeDelete = deleteValue == true;
        Boolean safeViewAll = viewAllValue == true;
        Boolean safeModifyAll = modifyAllValue == true;

        if (safeModifyAll) {
            safeRead = true;
            safeCreate = true;
            safeEdit = true;
            safeDelete = true;
            safeViewAll = true;
        }
        if (safeViewAll) {
            safeRead = true;
        }
        if (safeCreate || safeEdit || safeDelete) {
            safeRead = true;
        }
        if (!safeRead) {
            safeCreate = false;
            safeEdit = false;
            safeDelete = false;
            safeViewAll = false;
            safeModifyAll = false;
        }

        row.PermissionsRead = safeRead;
        row.PermissionsCreate = safeCreate;
        row.PermissionsEdit = safeEdit;
        row.PermissionsDelete = safeDelete;
        row.PermissionsViewAllRecords = safeViewAll;
        row.PermissionsModifyAllRecords = safeModifyAll;
    }

    private Boolean mergeBoolean(Boolean sourceValue, Boolean targetValue) {
        Boolean sourceGranted = sourceValue == true;
        Boolean targetGranted = targetValue == true;
        if (targetMode == c23_ProfileMigrationPlanService.TARGET_MODE_CREATE) {
            return sourceGranted;
        }
        if (mergeStrategy == c23_ProfileMigrationPlanService.MERGE_STRATEGY_OVERWRITE) {
            return sourceGranted;
        }
        return sourceGranted || targetGranted;
    }

    private String mergeVisibility(String sourceVisibility, String targetVisibility) {
        if (targetMode == c23_ProfileMigrationPlanService.TARGET_MODE_CREATE) {
            return sourceVisibility;
        }
        if (mergeStrategy == c23_ProfileMigrationPlanService.MERGE_STRATEGY_OVERWRITE) {
            return sourceVisibility;
        }
        if (sourceVisibility == c23_ProfileMigrationPlanService.TAB_DEFAULT_OFF) {
            return targetVisibility;
        }
        return sourceVisibility;
    }

    private static String normalizeVisibility(String value) {
        if (value == 'DefaultOn' || value == 'DefaultOff' || value == 'Hidden') {
            return value;
        }
        return c23_ProfileMigrationPlanService.TAB_DEFAULT_OFF;
    }

    private static Set<String> getCustomObjectApiNames() {
        Set<String> names = new Set<String>();
        for (c23_SchemaService.SObjectCatalogRow row : c23_SchemaService.getSObjectCatalog()) {
            if (row.isCustom == true) {
                names.add(row.apiName);
            }
        }
        return names;
    }

    private static Boolean isValidFieldPath(String fieldPath) {
        if (String.isBlank(fieldPath) || !fieldPath.contains('.')) {
            return false;
        }
        Integer splitIndex = fieldPath.indexOf('.');
        String objectApiName = fieldPath.substring(0, splitIndex);
        String fieldApiName = fieldPath.substring(splitIndex + 1);
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
        if (objectType == null) {
            return false;
        }
        Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
        return fieldMap.containsKey(fieldApiName);
    }

    private static PermissionSet queryPermissionSetWithFields(Id permissionSetId, List<String> fieldApiNames) {
        List<String> safeNames = fieldApiNames == null ? new List<String>() : new List<String>(fieldApiNames);
        safeNames.sort();
        String soql = 'SELECT Id';
        if (!safeNames.isEmpty()) {
            soql += ',' + String.join(safeNames, ',');
        }
        soql += ' FROM PermissionSet WHERE Id = :permissionSetId LIMIT 1';
        List<SObject> rows = Database.query(soql);
        return rows.isEmpty() ? null : (PermissionSet) rows[0];
    }
}