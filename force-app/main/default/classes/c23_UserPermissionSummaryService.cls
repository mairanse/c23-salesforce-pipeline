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

    public class UserAssignmentSummary {
        @AuraEnabled public String profileName;
        @AuraEnabled public List<AssignmentItem> permissionSets;
        @AuraEnabled public List<AssignmentItem> permissionSetGroups;
        @AuraEnabled public List<AssignmentItem> mutingPermissionSets;
        @AuraEnabled public Integer permissionSetCount;
        @AuraEnabled public Integer permissionSetGroupCount;
        @AuraEnabled public Integer mutingPermissionSetCount;

        public UserAssignmentSummary() {
            permissionSets = new List<AssignmentItem>();
            permissionSetGroups = new List<AssignmentItem>();
            mutingPermissionSets = new List<AssignmentItem>();
            permissionSetCount = 0;
            permissionSetGroupCount = 0;
            mutingPermissionSetCount = 0;
        }
    }

    @AuraEnabled(cacheable=true)
    public static String ping() {
        return 'ok';
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
        UserAssignmentSummary summary = new UserAssignmentSummary();
        if (userId == null) {
            return summary;
        }

        User selectedUser = [
            SELECT Id, Profile.Name
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        summary.profileName = selectedUser.Profile != null ? selectedUser.Profile.Name : null;

        List<PermissionSetAssignment> permissionSetAssignments = [
            SELECT PermissionSetId, PermissionSet.Name
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
                AND PermissionSet.IsOwnedByProfile = false
            ORDER BY PermissionSet.Name
        ];
        for (PermissionSetAssignment assignment : permissionSetAssignments) {
            summary.permissionSets.add(new AssignmentItem(
                (String) assignment.PermissionSetId,
                assignment.PermissionSet != null ? assignment.PermissionSet.Name : null
            ));
        }
        summary.permissionSetCount = summary.permissionSets.size();

        List<PermissionSetAssignment> groupAssignments = [
            SELECT PermissionSetGroupId,
                PermissionSetGroup.DeveloperName,
                PermissionSetGroup.MasterLabel
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
                AND PermissionSetGroupId != null
            ORDER BY PermissionSetGroup.MasterLabel
        ];

        Set<Id> groupIds = new Set<Id>();
        for (PermissionSetAssignment groupAssignment : groupAssignments) {
            groupIds.add(groupAssignment.PermissionSetGroupId);
            String groupName = groupAssignment.PermissionSetGroup != null
                ? groupAssignment.PermissionSetGroup.MasterLabel
                : null;
            if (String.isBlank(groupName) && groupAssignment.PermissionSetGroup != null) {
                groupName = groupAssignment.PermissionSetGroup.DeveloperName;
            }

            summary.permissionSetGroups.add(new AssignmentItem(
                (String) groupAssignment.PermissionSetGroupId,
                groupName
            ));
        }
        summary.permissionSetGroupCount = summary.permissionSetGroups.size();

        if (!groupIds.isEmpty()) {
            List<PermissionSet> mutingSets = [
                SELECT Id, Name
                FROM PermissionSet
                WHERE Type = 'Muting'
                    AND PermissionSetGroupId IN :groupIds
                ORDER BY Name
            ];

            for (PermissionSet mutingSet : mutingSets) {
                summary.mutingPermissionSets.add(new AssignmentItem(
                    (String) mutingSet.Id,
                    mutingSet.Name
                ));
            }
        }

        summary.mutingPermissionSetCount = summary.mutingPermissionSets.size();
        return summary;
    }
}
