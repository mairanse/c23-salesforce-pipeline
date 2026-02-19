public with sharing class c23_PermissionStudioAssignmentService {
    private static final String TARGET_PERMISSION_SET = 'PermissionSet';
    private static final String TARGET_PERMISSION_SET_GROUP = 'PermissionSetGroup';
    private static final String TARGET_PROFILE = 'Profile';
    private static final Integer MAX_QUERY_LIMIT = 200;

    public class AssignmentUserRow implements Comparable {
        @AuraEnabled public Id userId;
        @AuraEnabled public String name;
        @AuraEnabled public String username;
        @AuraEnabled public String profileName;

        public Integer compareTo(Object otherObject) {
            AssignmentUserRow otherValue = (AssignmentUserRow) otherObject;
            String thisSort = ((name == null ? '' : name) + '|' + (username == null ? '' : username)).toLowerCase();
            String otherSort = ((otherValue.name == null ? '' : otherValue.name) + '|' + (otherValue.username == null ? '' : otherValue.username)).toLowerCase();
            if (thisSort == otherSort) {
                return 0;
            }
            return thisSort < otherSort ? -1 : 1;
        }
    }

    public class UserLookupRow implements Comparable {
        @AuraEnabled public Id userId;
        @AuraEnabled public String name;
        @AuraEnabled public String username;
        @AuraEnabled public String profileName;

        public Integer compareTo(Object otherObject) {
            UserLookupRow otherValue = (UserLookupRow) otherObject;
            String thisSort = ((name == null ? '' : name) + '|' + (username == null ? '' : username)).toLowerCase();
            String otherSort = ((otherValue.name == null ? '' : otherValue.name) + '|' + (otherValue.username == null ? '' : otherValue.username)).toLowerCase();
            if (thisSort == otherSort) {
                return 0;
            }
            return thisSort < otherSort ? -1 : 1;
        }
    }

    public class AssignmentSnapshotResponse {
        @AuraEnabled public String targetType;
        @AuraEnabled public Id targetId;
        @AuraEnabled public String targetName;
        @AuraEnabled public Boolean supportsRemoval;
        @AuraEnabled public String removalHint;
        @AuraEnabled public List<AssignmentUserRow> assignedUsers;
    }

    public class ApplyAssignmentsResponse {
        @AuraEnabled public Integer changedCount;
        @AuraEnabled public Integer insertCount;
        @AuraEnabled public Integer updateCount;
        @AuraEnabled public Integer totalRequestedCount;
        @AuraEnabled public Boolean removalSkipped;
        @AuraEnabled public Id ledgerId;
        @AuraEnabled public Boolean ledgerTruncated;
        @AuraEnabled public Integer ledgerStoredItemCount;
        @AuraEnabled public Integer ledgerTotalItemCount;
        @AuraEnabled public String message;
    }

    private class TargetContext {
        public String targetType;
        public Id targetId;
        public String targetName;
        public Boolean supportsRemoval;
    }

    @AuraEnabled
    public static AssignmentSnapshotResponse getAssignmentSnapshot(String targetType, Id targetId) {
        c23_PermissionStudioSecurity.assertAccess();
        TargetContext contextValue = validateTarget(targetType, targetId);

        AssignmentSnapshotResponse response = new AssignmentSnapshotResponse();
        response.targetType = contextValue.targetType;
        response.targetId = contextValue.targetId;
        response.targetName = contextValue.targetName;
        response.supportsRemoval = contextValue.supportsRemoval;
        response.removalHint = contextValue.supportsRemoval ? null : Label.c23_PS_Assignments_ProfileRemoveHint;
        response.assignedUsers = queryAssignedUsers(contextValue);
        return response;
    }

    @AuraEnabled(cacheable=true)
    public static List<UserLookupRow> searchAssignableUsers(String searchKey, Integer maxResults) {
        c23_PermissionStudioSecurity.assertAccess();

        String normalizedSearch = String.isBlank(searchKey) ? null : searchKey.trim();
        if (String.isBlank(normalizedSearch)) {
            return new List<UserLookupRow>();
        }

        Integer safeLimit = maxResults == null ? MAX_QUERY_LIMIT : maxResults;
        if (safeLimit <= 0) {
            safeLimit = MAX_QUERY_LIMIT;
        }
        safeLimit = Math.min(safeLimit, MAX_QUERY_LIMIT);

        String wildcard = '%' + normalizedSearch + '%';
        List<UserLookupRow> rows = new List<UserLookupRow>();
        for (User userRecord : [
            SELECT Id, Name, Username, Profile.Name
            FROM User
            WHERE IsActive = true
                AND (Name LIKE :wildcard OR Username LIKE :wildcard)
            ORDER BY Name, Username
            LIMIT :safeLimit
        ]) {
            rows.add(toLookupRow(userRecord));
        }
        rows.sort();
        return rows;
    }

    @AuraEnabled
    public static ApplyAssignmentsResponse applyAssignments(
        String targetType,
        Id targetId,
        List<Id> assignUserIds,
        List<Id> unassignUserIds,
        String changeNote
    ) {
        c23_PermissionStudioSecurity.assertAccess();
        TargetContext contextValue = validateTarget(targetType, targetId);

        Set<Id> assignIds = sanitizeUserIds(assignUserIds);
        Set<Id> unassignIds = sanitizeUserIds(unassignUserIds);
        for (Id assignId : assignIds) {
            if (unassignIds.contains(assignId)) {
                unassignIds.remove(assignId);
            }
        }

        Integer totalRequestedCount = assignIds.size() + unassignIds.size();
        if (totalRequestedCount == 0) {
            return buildNoChangeResponse();
        }

        if (contextValue.targetType == TARGET_PROFILE) {
            return applyProfileAssignments(contextValue, assignIds, unassignIds, changeNote);
        }

        return applyPermissionSetAssignments(contextValue, assignIds, unassignIds, changeNote);
    }

    private static ApplyAssignmentsResponse applyPermissionSetAssignments(
        TargetContext contextValue,
        Set<Id> assignIds,
        Set<Id> unassignIds,
        String changeNote
    ) {
        Set<Id> candidateIds = new Set<Id>();
        candidateIds.addAll(assignIds);
        candidateIds.addAll(unassignIds);

        Map<Id, User> usersById = queryUsersById(candidateIds);
        Map<Id, PermissionSetAssignment> existingByAssigneeId = queryExistingAssignments(contextValue, candidateIds);

        List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();
        List<PermissionSetAssignment> toDelete = new List<PermissionSetAssignment>();
        List<c23_PermissionStudioLedgerService.LedgerItemPayload> ledgerItems =
            new List<c23_PermissionStudioLedgerService.LedgerItemPayload>();

        for (Id userId : assignIds) {
            if (!usersById.containsKey(userId) || existingByAssigneeId.containsKey(userId)) {
                continue;
            }

            PermissionSetAssignment assignmentRecord = new PermissionSetAssignment();
            assignmentRecord.AssigneeId = userId;
            if (contextValue.targetType == TARGET_PERMISSION_SET) {
                assignmentRecord.PermissionSetId = contextValue.targetId;
            } else {
                assignmentRecord.PermissionSetGroupId = contextValue.targetId;
            }
            toInsert.add(assignmentRecord);

            c23_PermissionStudioLedgerService.LedgerItemPayload addedItem =
                new c23_PermissionStudioLedgerService.LedgerItemPayload();
            addedItem.itemKey = toUserLedgerKey(usersById.get(userId));
            addedItem.beforeJson = toAssignmentJson(false);
            addedItem.afterJson = toAssignmentJson(true);
            ledgerItems.add(addedItem);
        }

        for (Id userId : unassignIds) {
            if (!existingByAssigneeId.containsKey(userId)) {
                continue;
            }

            PermissionSetAssignment assignmentRecord = existingByAssigneeId.get(userId);
            toDelete.add(assignmentRecord);

            User userRecord = usersById.get(userId);
            c23_PermissionStudioLedgerService.LedgerItemPayload removedItem =
                new c23_PermissionStudioLedgerService.LedgerItemPayload();
            removedItem.itemKey = userRecord == null ? String.valueOf(userId) : toUserLedgerKey(userRecord);
            removedItem.beforeJson = toAssignmentJson(true);
            removedItem.afterJson = toAssignmentJson(false);
            ledgerItems.add(removedItem);
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }

        Integer insertCount = toInsert.size();
        Integer updateCount = toDelete.size();
        Integer changedCount = insertCount + updateCount;

        c23_PermissionStudioLedgerService.LedgerWriteResult ledgerResult =
            c23_PermissionStudioLedgerService.writeChangeSafe(
                contextValue.targetType,
                contextValue.targetId,
                contextValue.targetName,
                Label.c23_PS_Assignments_Title,
                changeNote,
                assignIds.size() + unassignIds.size(),
                insertCount,
                updateCount,
                ledgerItems
            );

        ApplyAssignmentsResponse response = new ApplyAssignmentsResponse();
        response.changedCount = changedCount;
        response.insertCount = insertCount;
        response.updateCount = updateCount;
        response.totalRequestedCount = assignIds.size() + unassignIds.size();
        response.removalSkipped = false;
        response.ledgerId = ledgerResult.headerId;
        response.ledgerTruncated = ledgerResult.isTruncated;
        response.ledgerStoredItemCount = ledgerResult.storedItemCount;
        response.ledgerTotalItemCount = ledgerResult.totalItemCount;
        response.message = Label.c23_PS_Assignments_ApplySuccess;
        return response;
    }

    private static ApplyAssignmentsResponse buildNoChangeResponse() {
        ApplyAssignmentsResponse response = new ApplyAssignmentsResponse();
        response.changedCount = 0;
        response.insertCount = 0;
        response.updateCount = 0;
        response.totalRequestedCount = 0;
        response.removalSkipped = false;
        response.ledgerId = null;
        response.ledgerTruncated = false;
        response.ledgerStoredItemCount = 0;
        response.ledgerTotalItemCount = 0;
        response.message = Label.c23_PS_General_NoPendingChanges;
        return response;
    }

    private static ApplyAssignmentsResponse applyProfileAssignments(
        TargetContext contextValue,
        Set<Id> assignIds,
        Set<Id> unassignIds,
        String changeNote
    ) {
        List<User> updates = new List<User>();
        List<c23_PermissionStudioLedgerService.LedgerItemPayload> ledgerItems =
            new List<c23_PermissionStudioLedgerService.LedgerItemPayload>();

        if (!assignIds.isEmpty()) {
            for (User userRecord : [
                SELECT Id, Name, Username, ProfileId, Profile.Name
                FROM User
                WHERE Id IN :assignIds
            ]) {
                if (userRecord.ProfileId == contextValue.targetId) {
                    continue;
                }

                User updateRecord = new User(
                    Id = userRecord.Id,
                    ProfileId = contextValue.targetId
                );
                updates.add(updateRecord);

                c23_PermissionStudioLedgerService.LedgerItemPayload ledgerItem =
                    new c23_PermissionStudioLedgerService.LedgerItemPayload();
                ledgerItem.itemKey = toUserLedgerKey(userRecord);
                ledgerItem.beforeJson = toProfileAssignmentJson(userRecord.ProfileId, userRecord.Profile == null ? null : userRecord.Profile.Name);
                ledgerItem.afterJson = toProfileAssignmentJson(contextValue.targetId, contextValue.targetName);
                ledgerItems.add(ledgerItem);
            }
        }

        if (!updates.isEmpty()) {
            updates = sanitizeUserUpdates(updates);
            update updates;
        }

        Integer insertCount = updates.size();
        Integer updateCount = 0;
        Integer changedCount = insertCount;
        Boolean removalSkipped = !unassignIds.isEmpty();

        c23_PermissionStudioLedgerService.LedgerWriteResult ledgerResult =
            c23_PermissionStudioLedgerService.writeChangeSafe(
                contextValue.targetType,
                contextValue.targetId,
                contextValue.targetName,
                Label.c23_PS_Assignments_Title,
                changeNote,
                assignIds.size() + unassignIds.size(),
                insertCount,
                updateCount,
                ledgerItems
            );

        ApplyAssignmentsResponse response = new ApplyAssignmentsResponse();
        response.changedCount = changedCount;
        response.insertCount = insertCount;
        response.updateCount = updateCount;
        response.totalRequestedCount = assignIds.size() + unassignIds.size();
        response.removalSkipped = removalSkipped;
        response.ledgerId = ledgerResult.headerId;
        response.ledgerTruncated = ledgerResult.isTruncated;
        response.ledgerStoredItemCount = ledgerResult.storedItemCount;
        response.ledgerTotalItemCount = ledgerResult.totalItemCount;
        response.message = removalSkipped
            ? Label.c23_PS_Assignments_ProfileRemoveNotSupported
            : Label.c23_PS_Assignments_ApplySuccess;
        return response;
    }

    private static TargetContext validateTarget(String targetType, Id targetId) {
        String normalizedType = normalizeTargetType(targetType);
        if (normalizedType == null || targetId == null) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_Error_InvalidAssignmentTarget);
        }

        TargetContext contextValue = new TargetContext();
        contextValue.targetType = normalizedType;
        contextValue.targetId = targetId;

        if (normalizedType == TARGET_PERMISSION_SET) {
            PermissionSet permissionSetRecord = c23_PermissionStudioSecurity.validatePermissionSet(
                targetId,
                'Assignments.validateTarget'
            );
            contextValue.targetName = String.isBlank(permissionSetRecord.Label)
                ? permissionSetRecord.Name
                : permissionSetRecord.Label;
            contextValue.supportsRemoval = true;
            return contextValue;
        }

        if (normalizedType == TARGET_PERMISSION_SET_GROUP) {
            List<PermissionSetGroup> groups = [
                SELECT Id, MasterLabel
                FROM PermissionSetGroup
                WHERE Id = :targetId
                LIMIT 1
            ];
            if (groups.isEmpty()) {
                throw c23_PermissionStudioSecurity.handled(Label.c23_PS_Error_InvalidAssignmentTarget);
            }
            contextValue.targetName = groups[0].MasterLabel;
            contextValue.supportsRemoval = true;
            return contextValue;
        }

        List<Profile> profiles = [
            SELECT Id, Name
            FROM Profile
            WHERE Id = :targetId
            LIMIT 1
        ];
        if (profiles.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_Error_InvalidAssignmentTarget);
        }
        contextValue.targetName = profiles[0].Name;
        contextValue.supportsRemoval = false;
        return contextValue;
    }

    private static List<AssignmentUserRow> queryAssignedUsers(TargetContext contextValue) {
        List<AssignmentUserRow> rows = new List<AssignmentUserRow>();

        if (contextValue.targetType == TARGET_PERMISSION_SET) {
            for (PermissionSetAssignment assignmentRecord : [
                SELECT AssigneeId, Assignee.Name, Assignee.Username, Assignee.Profile.Name
                FROM PermissionSetAssignment
                WHERE PermissionSetId = :contextValue.targetId
                ORDER BY Assignee.Name, Assignee.Username
                LIMIT 5000
            ]) {
                rows.add(toAssignedRow(assignmentRecord.Assignee));
            }
            rows.sort();
            return rows;
        }

        if (contextValue.targetType == TARGET_PERMISSION_SET_GROUP) {
            for (PermissionSetAssignment assignmentRecord : [
                SELECT AssigneeId, Assignee.Name, Assignee.Username, Assignee.Profile.Name
                FROM PermissionSetAssignment
                WHERE PermissionSetGroupId = :contextValue.targetId
                ORDER BY Assignee.Name, Assignee.Username
                LIMIT 5000
            ]) {
                rows.add(toAssignedRow(assignmentRecord.Assignee));
            }
            rows.sort();
            return rows;
        }

        for (User userRecord : [
            SELECT Id, Name, Username, Profile.Name
            FROM User
            WHERE ProfileId = :contextValue.targetId
            ORDER BY Name, Username
            LIMIT 5000
        ]) {
            rows.add(toAssignedRow(userRecord));
        }
        rows.sort();
        return rows;
    }

    private static Map<Id, PermissionSetAssignment> queryExistingAssignments(TargetContext contextValue, Set<Id> userIds) {
        Map<Id, PermissionSetAssignment> byAssigneeId = new Map<Id, PermissionSetAssignment>();
        if (userIds == null || userIds.isEmpty()) {
            return byAssigneeId;
        }

        if (contextValue.targetType == TARGET_PERMISSION_SET) {
            for (PermissionSetAssignment assignmentRecord : [
                SELECT Id, AssigneeId
                FROM PermissionSetAssignment
                WHERE PermissionSetId = :contextValue.targetId
                    AND AssigneeId IN :userIds
            ]) {
                byAssigneeId.put(assignmentRecord.AssigneeId, assignmentRecord);
            }
            return byAssigneeId;
        }

        for (PermissionSetAssignment assignmentRecord : [
            SELECT Id, AssigneeId
            FROM PermissionSetAssignment
            WHERE PermissionSetGroupId = :contextValue.targetId
                AND AssigneeId IN :userIds
        ]) {
            byAssigneeId.put(assignmentRecord.AssigneeId, assignmentRecord);
        }
        return byAssigneeId;
    }

    private static Map<Id, User> queryUsersById(Set<Id> userIds) {
        Map<Id, User> byId = new Map<Id, User>();
        if (userIds == null || userIds.isEmpty()) {
            return byId;
        }

        for (User userRecord : [
            SELECT Id, Name, Username, ProfileId, Profile.Name
            FROM User
            WHERE Id IN :userIds
        ]) {
            byId.put(userRecord.Id, userRecord);
        }
        return byId;
    }

    private static String normalizeTargetType(String targetType) {
        if (targetType == TARGET_PERMISSION_SET || targetType == TARGET_PERMISSION_SET_GROUP || targetType == TARGET_PROFILE) {
            return targetType;
        }
        return null;
    }

    private static Set<Id> sanitizeUserIds(List<Id> ids) {
        Set<Id> result = new Set<Id>();
        if (ids == null) {
            return result;
        }

        for (Id userId : ids) {
            if (userId != null) {
                result.add(userId);
            }
        }
        return result;
    }

    private static AssignmentUserRow toAssignedRow(User userRecord) {
        AssignmentUserRow row = new AssignmentUserRow();
        row.userId = userRecord.Id;
        row.name = userRecord.Name;
        row.username = userRecord.Username;
        row.profileName = userRecord.Profile == null ? null : userRecord.Profile.Name;
        return row;
    }

    private static UserLookupRow toLookupRow(User userRecord) {
        UserLookupRow row = new UserLookupRow();
        row.userId = userRecord.Id;
        row.name = userRecord.Name;
        row.username = userRecord.Username;
        row.profileName = userRecord.Profile == null ? null : userRecord.Profile.Name;
        return row;
    }

    private static String toUserLedgerKey(User userRecord) {
        if (userRecord == null) {
            return null;
        }
        return userRecord.Username + '|' + userRecord.Name;
    }

    private static String toAssignmentJson(Boolean assigned) {
        Map<String, Object> valueMap = new Map<String, Object>();
        valueMap.put('assigned', assigned == true);
        return JSON.serialize(valueMap);
    }

    private static String toProfileAssignmentJson(Id profileId, String profileName) {
        Map<String, Object> valueMap = new Map<String, Object>();
        valueMap.put('profileId', profileId == null ? null : String.valueOf(profileId));
        valueMap.put('profileName', profileName);
        return JSON.serialize(valueMap);
    }

    private static List<User> sanitizeUserUpdates(List<User> updateRows) {
        SObjectAccessDecision decision = Security.stripInaccessible(
            System.AccessType.UPDATABLE,
            updateRows
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
}