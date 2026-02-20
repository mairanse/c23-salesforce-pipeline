public with sharing class c23_UserPermissionSummaryService {
    public class UserSearchResult {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String username;
        @AuraEnabled public String email;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String profileName;

        public UserSearchResult(User userRecord) {
            id = (String) userRecord.Id;
            name = userRecord.Name;
            username = userRecord.Username;
            email = userRecord.Email;
            isActive = userRecord.IsActive;
            profileName = userRecord.Profile != null ? userRecord.Profile.Name : null;
        }
    }

    public class AssignmentItem {
        @AuraEnabled public String id;
        @AuraEnabled public String name;

        public AssignmentItem(String itemId, String itemName) {
            id = itemId;
            name = itemName;
        }
    }

    public class PermissionSetGroupItem {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String mutingPermissionSetId;
        @AuraEnabled public String mutingPermissionSetName;

        public PermissionSetGroupItem(String itemId, String itemName, String mutingId, String mutingName) {
            id = itemId;
            name = itemName;
            mutingPermissionSetId = mutingId;
            mutingPermissionSetName = mutingName;
        }
    }

    public class UserAssignmentSummary {
        @AuraEnabled public String userId;
        @AuraEnabled public String profileName;
        @AuraEnabled public List<AssignmentItem> permissionSets;
        @AuraEnabled public List<PermissionSetGroupItem> permissionSetGroups;
        @AuraEnabled public List<AssignmentItem> mutingPermissionSets;
        @AuraEnabled public Integer permissionSetCount;
        @AuraEnabled public Integer permissionSetGroupCount;
        @AuraEnabled public Integer mutingPermissionSetCount;

        public UserAssignmentSummary() {
            permissionSets = new List<AssignmentItem>();
            permissionSetGroups = new List<PermissionSetGroupItem>();
            mutingPermissionSets = new List<AssignmentItem>();
            permissionSetCount = 0;
            permissionSetGroupCount = 0;
            mutingPermissionSetCount = 0;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<UserSearchResult> searchUsers(String query) {
        if (String.isBlank(query)) {
            return new List<UserSearchResult>();
        }

        String normalizedQuery = query.trim();
        if (normalizedQuery.length() < 2) {
            return new List<UserSearchResult>();
        }

        String likeQuery = '%' + normalizedQuery + '%';
        List<User> users = [
            SELECT Id, Name, Username, Email, IsActive, Profile.Name
            FROM User
            WHERE Name LIKE :likeQuery
                OR Username LIKE :likeQuery
                OR Email LIKE :likeQuery
            ORDER BY Name
            LIMIT 20
        ];

        List<UserSearchResult> results = new List<UserSearchResult>();
        for (User userRecord : users) {
            results.add(new UserSearchResult(userRecord));
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static UserAssignmentSummary getAssignments(Id userId) {
        if (userId == null) {
            return new UserAssignmentSummary();
        }

        List<UserAssignmentSummary> summaries = getAssignmentsBulk(new List<Id>{ userId });
        return summaries.isEmpty() ? new UserAssignmentSummary() : summaries[0];
    }

    @AuraEnabled(cacheable=true)
    public static List<UserAssignmentSummary> getAssignmentsBulk(List<Id> userIds) {
        List<UserAssignmentSummary> orderedSummaries = new List<UserAssignmentSummary>();
        if (userIds == null || userIds.isEmpty()) {
            return orderedSummaries;
        }

        Set<Id> requestedIds = new Set<Id>();
        for (Id userId : userIds) {
            if (userId != null) {
                requestedIds.add(userId);
            }
        }
        if (requestedIds.isEmpty()) {
            return orderedSummaries;
        }

        Map<Id, UserAssignmentSummary> summaryByUserId = new Map<Id, UserAssignmentSummary>();
        for (Id userId : requestedIds) {
            UserAssignmentSummary summary = new UserAssignmentSummary();
            summary.userId = (String) userId;
            summaryByUserId.put(userId, summary);
        }

        for (User userRecord : [
            SELECT Id, Profile.Name
            FROM User
            WHERE Id IN :requestedIds
        ]) {
            UserAssignmentSummary summary = summaryByUserId.get(userRecord.Id);
            if (summary != null) {
                summary.profileName = userRecord.Profile != null ? userRecord.Profile.Name : null;
            }
        }

        for (PermissionSetAssignment assignment : [
            SELECT AssigneeId, PermissionSetId, PermissionSet.Name, PermissionSet.IsOwnedByProfile
            FROM PermissionSetAssignment
            WHERE AssigneeId IN :requestedIds
                AND PermissionSet.IsOwnedByProfile = false
            ORDER BY PermissionSet.Name
        ]) {
            UserAssignmentSummary summary = summaryByUserId.get(assignment.AssigneeId);
            if (summary != null) {
                summary.permissionSets.add(new AssignmentItem(
                    (String) assignment.PermissionSetId,
                    assignment.PermissionSet != null ? assignment.PermissionSet.Name : null
                ));
            }
        }

        Map<Id, Set<Id>> groupIdsByUserId = new Map<Id, Set<Id>>();
        Map<Id, String> groupNameById = new Map<Id, String>();
        Map<Id, Id> mutingIdByGroupId = new Map<Id, Id>();
        Set<Id> allGroupIds = new Set<Id>();
        Set<Id> mutingIds = new Set<Id>();

        Boolean usedPsga = loadPermissionSetGroupAssignments(
            requestedIds,
            groupIdsByUserId,
            groupNameById,
            mutingIdByGroupId,
            allGroupIds,
            mutingIds
        );

        if (!usedPsga) {
            for (PermissionSetAssignment groupAssignment : [
                SELECT AssigneeId, PermissionSetGroupId
                FROM PermissionSetAssignment
                WHERE AssigneeId IN :requestedIds
                    AND PermissionSetGroupId != null
            ]) {
                if (!groupIdsByUserId.containsKey(groupAssignment.AssigneeId)) {
                    groupIdsByUserId.put(groupAssignment.AssigneeId, new Set<Id>());
                }
                groupIdsByUserId.get(groupAssignment.AssigneeId).add(groupAssignment.PermissionSetGroupId);
                allGroupIds.add(groupAssignment.PermissionSetGroupId);
            }

            if (!allGroupIds.isEmpty()) {
                for (PermissionSet mutingSet : [
                    SELECT Id, PermissionSetGroupId
                    FROM PermissionSet
                    WHERE Type = 'Muting'
                        AND PermissionSetGroupId IN :allGroupIds
                ]) {
                    mutingIdByGroupId.put(mutingSet.PermissionSetGroupId, mutingSet.Id);
                    mutingIds.add(mutingSet.Id);
                }
            }
        }

        if (!allGroupIds.isEmpty()) {
            for (PermissionSetGroup groupRecord : [
                SELECT Id, MasterLabel, DeveloperName
                FROM PermissionSetGroup
                WHERE Id IN :allGroupIds
            ]) {
                String groupName = String.isBlank(groupRecord.MasterLabel)
                    ? groupRecord.DeveloperName
                    : groupRecord.MasterLabel;
                groupNameById.put(groupRecord.Id, groupName);
            }
        }

        Map<Id, String> mutingNameById = new Map<Id, String>();
        if (!mutingIds.isEmpty()) {
            for (PermissionSet mutingSet : [
                SELECT Id, Name
                FROM PermissionSet
                WHERE Id IN :mutingIds
                ORDER BY Name
            ]) {
                mutingNameById.put(mutingSet.Id, mutingSet.Name);
            }
        }

        for (Id userId : summaryByUserId.keySet()) {
            UserAssignmentSummary summary = summaryByUserId.get(userId);
            Set<Id> userGroupIds = groupIdsByUserId.get(userId);
            Set<Id> userMutingIds = new Set<Id>();

            if (userGroupIds != null) {
                for (Id groupId : userGroupIds) {
                    Id mutingId = mutingIdByGroupId.get(groupId);
                    String mutingName = mutingId != null ? mutingNameById.get(mutingId) : null;
                    summary.permissionSetGroups.add(new PermissionSetGroupItem(
                        (String) groupId,
                        groupNameById.get(groupId),
                        mutingId != null ? (String) mutingId : null,
                        mutingName
                    ));

                    if (mutingId != null) {
                        userMutingIds.add(mutingId);
                    }
                }
            }

            for (Id mutingId : userMutingIds) {
                summary.mutingPermissionSets.add(new AssignmentItem(
                    (String) mutingId,
                    mutingNameById.get(mutingId)
                ));
            }

            summary.permissionSetCount = summary.permissionSets.size();
            summary.permissionSetGroupCount = summary.permissionSetGroups.size();
            summary.mutingPermissionSetCount = summary.mutingPermissionSets.size();
        }

        for (Id originalUserId : userIds) {
            if (originalUserId != null && summaryByUserId.containsKey(originalUserId)) {
                orderedSummaries.add(summaryByUserId.get(originalUserId));
            }
        }

        return orderedSummaries;
    }

    private static Boolean loadPermissionSetGroupAssignments(
        Set<Id> requestedIds,
        Map<Id, Set<Id>> groupIdsByUserId,
        Map<Id, String> groupNameById,
        Map<Id, Id> mutingIdByGroupId,
        Set<Id> allGroupIds,
        Set<Id> mutingIds
    ) {
        try {
            List<SObject> rows = Database.query(
                'SELECT AssigneeId, PermissionSetGroup.Id, PermissionSetGroup.MasterLabel, PermissionSetGroup.DeveloperName, PermissionSetGroup.MutingPermissionSetId ' +
                'FROM PermissionSetGroupAssignment WHERE AssigneeId IN :requestedIds'
            );

            for (SObject row : rows) {
                Id assigneeId = (Id) row.get('AssigneeId');
                SObject groupRef = row.getSObject('PermissionSetGroup');
                if (assigneeId == null || groupRef == null) {
                    continue;
                }

                Id groupId = (Id) groupRef.get('Id');
                if (groupId == null) {
                    continue;
                }

                if (!groupIdsByUserId.containsKey(assigneeId)) {
                    groupIdsByUserId.put(assigneeId, new Set<Id>());
                }
                groupIdsByUserId.get(assigneeId).add(groupId);
                allGroupIds.add(groupId);

                String groupName = (String) groupRef.get('MasterLabel');
                if (String.isBlank(groupName)) {
                    groupName = (String) groupRef.get('DeveloperName');
                }
                groupNameById.put(groupId, groupName);

                Id mutingId = (Id) groupRef.get('MutingPermissionSetId');
                if (mutingId != null) {
                    mutingIdByGroupId.put(groupId, mutingId);
                    mutingIds.add(mutingId);
                }
            }

            return true;
        } catch (Exception ex) {
            return false;
        }
    }
}
