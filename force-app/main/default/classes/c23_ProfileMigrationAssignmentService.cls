public with sharing class c23_ProfileMigrationAssignmentService {
    public class AssignmentResultDTO {
        @AuraEnabled public Integer changedCount;
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public List<String> messages;
    }

    public static AssignmentResultDTO assignUsersFromProfile(Id profileId, Id permissionSetId) {
        c23_PermissionStudioSecurity.assertAccess();
        if (profileId == null || permissionSetId == null) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_MIG_Error_InvalidAssignmentInput);
        }

        Set<Id> userIds = new Set<Id>();
        for (User userRecord : [
            SELECT Id
            FROM User
            WHERE IsActive = true
                AND ProfileId = :profileId
            LIMIT 50000
        ]) {
            userIds.add(userRecord.Id);
        }

        Map<Id, PermissionSetAssignment> existingByUserId = new Map<Id, PermissionSetAssignment>();
        if (!userIds.isEmpty()) {
            for (PermissionSetAssignment assignmentRow : [
                SELECT Id, AssigneeId
                FROM PermissionSetAssignment
                WHERE PermissionSetId = :permissionSetId
                    AND AssigneeId IN :userIds
            ]) {
                existingByUserId.put(assignmentRow.AssigneeId, assignmentRow);
            }
        }

        List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();
        for (Id userId : userIds) {
            if (existingByUserId.containsKey(userId)) {
                continue;
            }
            toInsert.add(new PermissionSetAssignment(
                AssigneeId = userId,
                PermissionSetId = permissionSetId
            ));
        }

        AssignmentResultDTO response = new AssignmentResultDTO();
        response.messages = new List<String>();
        response.changedCount = toInsert.size();
        response.successCount = 0;
        response.errorCount = 0;

        if (!toInsert.isEmpty()) {
            Database.SaveResult[] insertResults = Database.insert(toInsert, false);
            for (Database.SaveResult saveResult : insertResults) {
                if (saveResult.isSuccess()) {
                    response.successCount++;
                    continue;
                }
                response.errorCount++;
                response.messages.add(extractErrors(saveResult.getErrors()));
            }
        }

        return response;
    }

    public static AssignmentResultDTO swapUsersToBaseProfile(Id sourceProfileId, Id baseProfileId) {
        c23_PermissionStudioSecurity.assertAccess();
        if (sourceProfileId == null || baseProfileId == null || sourceProfileId == baseProfileId) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_MIG_Error_InvalidAssignmentInput);
        }

        List<User> toUpdate = new List<User>();
        for (User userRecord : [
            SELECT Id, ProfileId
            FROM User
            WHERE IsActive = true
                AND ProfileId = :sourceProfileId
            LIMIT 50000
        ]) {
            if (userRecord.ProfileId == baseProfileId) {
                continue;
            }
            toUpdate.add(new User(
                Id = userRecord.Id,
                ProfileId = baseProfileId
            ));
        }

        AssignmentResultDTO response = new AssignmentResultDTO();
        response.messages = new List<String>();
        response.changedCount = toUpdate.size();
        response.successCount = 0;
        response.errorCount = 0;

        if (!toUpdate.isEmpty()) {
            List<User> sanitized = sanitizeUsersForUpdate(toUpdate);
            Database.SaveResult[] updateResults = Database.update(sanitized, false);
            for (Database.SaveResult saveResult : updateResults) {
                if (saveResult.isSuccess()) {
                    response.successCount++;
                    continue;
                }
                response.errorCount++;
                response.messages.add(extractErrors(saveResult.getErrors()));
            }
        }

        return response;
    }

    private static List<User> sanitizeUsersForUpdate(List<User> usersToUpdate) {
        SObjectAccessDecision decision = Security.stripInaccessible(
            System.AccessType.UPDATABLE,
            usersToUpdate
        );
        assertNoStrippedFields(decision);

        List<User> sanitized = new List<User>();
        for (SObject row : decision.getRecords()) {
            sanitized.add((User) row);
        }
        return sanitized;
    }

    private static void assertNoStrippedFields(SObjectAccessDecision decision) {
        Map<String, Set<String>> removedFields = decision == null ? null : decision.getRemovedFields();
        if (removedFields != null && !removedFields.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_General_AccessDenied);
        }
    }

    private static String extractErrors(Database.Error[] errors) {
        if (errors == null || errors.isEmpty()) {
            return Label.c23_PS_General_Error;
        }
        List<String> messages = new List<String>();
        for (Database.Error row : errors) {
            messages.add(row.getMessage());
        }
        return String.join(messages, '; ');
    }
}