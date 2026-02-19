public with sharing class c23_ProfileMigrationJobService {
    public class JobStartDTO {
        @AuraEnabled public Id jobId;
        @AuraEnabled public String status;
        @AuraEnabled public Id asyncApexJobId;
        @AuraEnabled public Id targetPermissionSetId;
        @AuraEnabled public String targetPermissionSetName;
    }

    public class JobStatusDTO {
        @AuraEnabled public Id jobId;
        @AuraEnabled public String status;
        @AuraEnabled public Id targetPermissionSetId;
        @AuraEnabled public String targetPermissionSetName;
        @AuraEnabled public Integer warningCount;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public Datetime startedAt;
        @AuraEnabled public Datetime endedAt;
    }

    public class WarningDTO {
        @AuraEnabled public String category;
        @AuraEnabled public String permissionKey;
        @AuraEnabled public String message;
        @AuraEnabled public String severity;
    }

    @AuraEnabled
    public static JobStartDTO start(
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
        c23_PermissionStudioSecurity.assertAccess();

        String safeTargetMode = normalizeTargetMode(targetMode);
        String safeMergeStrategy = normalizeMergeStrategy(mergeStrategy);
        c23_ProfileMigrationPlanService.ScopeOptionsDTO scopeOptions = c23_ProfileMigrationPlanService.parseScopeOptions(scopeOptionsJson);

        if (safeTargetMode == c23_ProfileMigrationPlanService.TARGET_MODE_CREATE && String.isBlank(targetPermissionSetName)) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_MIG_Error_TargetName);
        }
        if (safeTargetMode == c23_ProfileMigrationPlanService.TARGET_MODE_MERGE && targetPermissionSetId == null) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_MIG_Error_TargetMergeSelection);
        }

        c23_MigrationJob__c jobRow = new c23_MigrationJob__c();
        jobRow.c23_SourceProfileId__c = profileId == null ? null : String.valueOf(profileId);
        jobRow.c23_TargetPermissionSetId__c = targetPermissionSetId == null ? null : String.valueOf(targetPermissionSetId);
        jobRow.c23_TargetPermissionSetName__c = targetPermissionSetName;
        jobRow.c23_Status__c = 'Queued';
        jobRow.c23_ScopeJson__c = scopeOptionsJson;
        jobRow.c23_StartedByUserId__c = UserInfo.getUserId();
        jobRow.c23_StartedAt__c = System.now();
        jobRow.c23_PlanJson__c = JSON.serialize(new Map<String, Object>{
            'targetMode' => safeTargetMode,
            'mergeStrategy' => safeMergeStrategy,
            'targetPermissionSetId' => targetPermissionSetId,
            'targetPermissionSetName' => targetPermissionSetName,
            'targetPermissionSetApiName' => targetPermissionSetApiName,
            'scopeOptions' => scopeOptions,
            'assignUsersFromProfile' => assignUsersFromProfile == true,
            'switchUsersToBaseProfile' => switchUsersToBaseProfile == true,
            'baseProfileId' => baseProfileId
        });
        c23_MigrationJob__c sanitizedJobRow = sanitizeJobForCreate(jobRow);
        insert sanitizedJobRow;
        jobRow = sanitizedJobRow;

        Id asyncApexJobId = System.enqueueJob(
            new c23_ProfileMigrationCoordinatorQueueable(
                jobRow.Id,
                profileId,
                safeTargetMode,
                targetPermissionSetId,
                targetPermissionSetName,
                targetPermissionSetApiName,
                safeMergeStrategy,
                scopeOptionsJson,
                assignUsersFromProfile == true,
                switchUsersToBaseProfile == true,
                baseProfileId
            )
        );

        JobStartDTO response = new JobStartDTO();
        response.jobId = jobRow.Id;
        response.status = 'Queued';
        response.asyncApexJobId = asyncApexJobId;
        response.targetPermissionSetId = targetPermissionSetId;
        response.targetPermissionSetName = targetPermissionSetName;
        return response;
    }

    @AuraEnabled(cacheable=true)
    public static JobStatusDTO getStatus(Id jobId) {
        c23_PermissionStudioSecurity.assertAccess();
        c23_MigrationJob__c jobRow = loadJob(jobId);
        return toStatusDto(jobRow);
    }

    @AuraEnabled(cacheable=true)
    public static List<WarningDTO> getWarnings(Id jobId) {
        c23_PermissionStudioSecurity.assertAccess();
        c23_MigrationJob__c jobRow = loadJob(jobId);

        List<WarningDTO> rows = new List<WarningDTO>();
        for (c23_MigrationWarning__c warningRow : [
            SELECT c23_Category__c, c23_PermissionKey__c, c23_Message__c, c23_Severity__c
            FROM c23_MigrationWarning__c
            WHERE c23_Job__c = :jobRow.Id
            ORDER BY CreatedDate ASC
            LIMIT 5000
        ]) {
            WarningDTO dto = new WarningDTO();
            dto.category = warningRow.c23_Category__c;
            dto.permissionKey = warningRow.c23_PermissionKey__c;
            dto.message = warningRow.c23_Message__c;
            dto.severity = warningRow.c23_Severity__c;
            rows.add(dto);
        }
        return rows;
    }

    public static void markRunning(Id jobId) {
        updateJobStatus(jobId, 'Running', null, null, null, null);
    }

    public static void markFinalizing(Id jobId) {
        updateJobStatus(jobId, 'Finalizing', null, null, null, null);
    }

    public static void markCompleted(Id jobId, Id targetPermissionSetId, String targetPermissionSetName, Integer warningCount, Integer errorCount) {
        updateJobStatus(jobId, warningCount > 0 ? 'CompletedWithWarnings' : 'Completed', targetPermissionSetId, targetPermissionSetName, warningCount, errorCount);
    }

    public static void markFailed(Id jobId, Integer warningCount, Integer errorCount) {
        updateJobStatus(jobId, 'Failed', null, null, warningCount, errorCount);
    }

    public static void appendWarnings(Id jobId, List<c23_MigrationWarning__c> warningsToInsert) {
        if (warningsToInsert == null || warningsToInsert.isEmpty()) {
            return;
        }
        insert sanitizeWarningsForCreate(warningsToInsert);
    }

    private static void updateJobStatus(
        Id jobId,
        String statusValue,
        Id targetPermissionSetId,
        String targetPermissionSetName,
        Integer warningCount,
        Integer errorCount
    ) {
        if (jobId == null) {
            return;
        }

        c23_MigrationJob__c updateRow = new c23_MigrationJob__c(
            Id = jobId,
            c23_Status__c = statusValue
        );

        if (targetPermissionSetId != null) {
            updateRow.c23_TargetPermissionSetId__c = String.valueOf(targetPermissionSetId);
        }
        if (!String.isBlank(targetPermissionSetName)) {
            updateRow.c23_TargetPermissionSetName__c = targetPermissionSetName;
        }
        if (warningCount != null) {
            updateRow.c23_WarningsCount__c = warningCount;
        }
        if (errorCount != null) {
            updateRow.c23_ErrorsCount__c = errorCount;
        }
        if (statusValue == 'Completed' || statusValue == 'CompletedWithWarnings' || statusValue == 'Failed') {
            updateRow.c23_EndedAt__c = System.now();
        }

        update sanitizeJobForUpdate(updateRow);
    }

    private static c23_MigrationJob__c loadJob(Id jobId) {
        if (jobId == null) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_MIG_Error_InvalidJob);
        }
        List<c23_MigrationJob__c> rows = [
            SELECT Id,
                c23_Status__c,
                c23_TargetPermissionSetId__c,
                c23_TargetPermissionSetName__c,
                c23_WarningsCount__c,
                c23_ErrorsCount__c,
                c23_StartedAt__c,
                c23_EndedAt__c
            FROM c23_MigrationJob__c
            WHERE Id = :jobId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_MIG_Error_InvalidJob);
        }
        return rows[0];
    }

    private static JobStatusDTO toStatusDto(c23_MigrationJob__c row) {
        JobStatusDTO dto = new JobStatusDTO();
        dto.jobId = row.Id;
        dto.status = row.c23_Status__c;
        dto.targetPermissionSetId = String.isBlank(row.c23_TargetPermissionSetId__c) ? null : (Id) row.c23_TargetPermissionSetId__c;
        dto.targetPermissionSetName = row.c23_TargetPermissionSetName__c;
        dto.warningCount = row.c23_WarningsCount__c == null ? 0 : row.c23_WarningsCount__c.intValue();
        dto.errorCount = row.c23_ErrorsCount__c == null ? 0 : row.c23_ErrorsCount__c.intValue();
        dto.startedAt = row.c23_StartedAt__c;
        dto.endedAt = row.c23_EndedAt__c;
        return dto;
    }

    private static String normalizeTargetMode(String targetMode) {
        if (targetMode == c23_ProfileMigrationPlanService.TARGET_MODE_CREATE || targetMode == c23_ProfileMigrationPlanService.TARGET_MODE_MERGE) {
            return targetMode;
        }
        return c23_ProfileMigrationPlanService.TARGET_MODE_CREATE;
    }

    private static String normalizeMergeStrategy(String mergeStrategy) {
        if (mergeStrategy == c23_ProfileMigrationPlanService.MERGE_STRATEGY_UNION || mergeStrategy == c23_ProfileMigrationPlanService.MERGE_STRATEGY_OVERWRITE) {
            return mergeStrategy;
        }
        return c23_ProfileMigrationPlanService.MERGE_STRATEGY_UNION;
    }

    private static c23_MigrationJob__c sanitizeJobForCreate(c23_MigrationJob__c row) {
        SObjectAccessDecision decision = Security.stripInaccessible(
            System.AccessType.CREATABLE,
            new List<SObject>{ row }
        );
        assertNoStrippedFields(decision);
        return (c23_MigrationJob__c) decision.getRecords()[0];
    }

    private static c23_MigrationJob__c sanitizeJobForUpdate(c23_MigrationJob__c row) {
        SObjectAccessDecision decision = Security.stripInaccessible(
            System.AccessType.UPDATABLE,
            new List<SObject>{ row }
        );
        assertNoStrippedFields(decision);
        return (c23_MigrationJob__c) decision.getRecords()[0];
    }

    private static List<c23_MigrationWarning__c> sanitizeWarningsForCreate(List<c23_MigrationWarning__c> rows) {
        SObjectAccessDecision decision = Security.stripInaccessible(
            System.AccessType.CREATABLE,
            rows
        );
        assertNoStrippedFields(decision);
        List<c23_MigrationWarning__c> response = new List<c23_MigrationWarning__c>();
        for (SObject row : decision.getRecords()) {
            response.add((c23_MigrationWarning__c) row);
        }
        return response;
    }

    private static void assertNoStrippedFields(SObjectAccessDecision decision) {
        Map<String, Set<String>> removedFields = decision == null ? null : decision.getRemovedFields();
        if (removedFields != null && !removedFields.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_General_AccessDenied);
        }
    }
}