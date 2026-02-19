public with sharing class c23_PermissionStudioExplorerService {
    public class ExplorerResponse {
        @AuraEnabled public List<PermissionSetRow> permissionSets = new List<PermissionSetRow>();
        @AuraEnabled public List<PermissionSetGroupRow> permissionSetGroups = new List<PermissionSetGroupRow>();
        @AuraEnabled public List<ProfileRow> profiles = new List<ProfileRow>();
    }

    public class PermissionSetRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean isOwnedByProfile;
        @AuraEnabled public Id profileId;
        @AuraEnabled public String profileName;
        @AuraEnabled public Integer objectPermissionsCount;
        @AuraEnabled public Integer fieldPermissionsCount;
        @AuraEnabled public Integer setupEntityAccessCount;
        @AuraEnabled public Integer assignmentCount;
    }

    public class PermissionSetGroupRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String developerName;
        @AuraEnabled public String label;
        @AuraEnabled public String status;
        @AuraEnabled public Integer memberCount;
        @AuraEnabled public Integer assignmentCount;
        @AuraEnabled public Boolean hasMutingPermissionSet;
    }

    public class ProfileRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Id ownedPermissionSetId;
        @AuraEnabled public String ownedPermissionSetName;
        @AuraEnabled public Integer objectPermissionsCount;
        @AuraEnabled public Integer fieldPermissionsCount;
        @AuraEnabled public Integer setupEntityAccessCount;
        @AuraEnabled public Integer assignmentCount;
    }

    @AuraEnabled(cacheable=true)
    public static ExplorerResponse getExplorerData() {
        c23_PermissionStudioSecurity.assertAccess();

        ExplorerResponse response = new ExplorerResponse();

        List<PermissionSet> permissionSets = [
            SELECT Id, Name, Label, IsOwnedByProfile, ProfileId, Profile.Name
            FROM PermissionSet
            ORDER BY Label, Name
            LIMIT 2000
        ];

        Set<Id> permissionSetIds = new Set<Id>();
        for (PermissionSet permissionSetRecord : permissionSets) {
            permissionSetIds.add(permissionSetRecord.Id);
        }

        Map<Id, Integer> objectPermissionCounts = getCountMapByParentId(
            [
                SELECT ParentId parentId, COUNT(Id) totalCount
                FROM ObjectPermissions
                WHERE ParentId IN :permissionSetIds
                GROUP BY ParentId
            ],
            'parentId',
            'totalCount'
        );

        Map<Id, Integer> fieldPermissionCounts = getCountMapByParentId(
            [
                SELECT ParentId parentId, COUNT(Id) totalCount
                FROM FieldPermissions
                WHERE ParentId IN :permissionSetIds
                GROUP BY ParentId
            ],
            'parentId',
            'totalCount'
        );

        Map<Id, Integer> setupEntityAccessCounts = getCountMapByParentId(
            [
                SELECT ParentId parentId, COUNT(Id) totalCount
                FROM SetupEntityAccess
                WHERE ParentId IN :permissionSetIds
                GROUP BY ParentId
            ],
            'parentId',
            'totalCount'
        );

        Map<Id, Integer> permissionSetAssignmentCounts = getCountMapByParentId(
            [
                SELECT PermissionSetId parentId, COUNT(Id) totalCount
                FROM PermissionSetAssignment
                WHERE PermissionSetId IN :permissionSetIds
                GROUP BY PermissionSetId
            ],
            'parentId',
            'totalCount'
        );

        for (PermissionSet permissionSetRecord : permissionSets) {
            PermissionSetRow row = new PermissionSetRow();
            row.id = permissionSetRecord.Id;
            row.apiName = permissionSetRecord.Name;
            row.label = permissionSetRecord.Label;
            row.isOwnedByProfile = permissionSetRecord.IsOwnedByProfile;
            row.profileId = permissionSetRecord.ProfileId;
            row.profileName = permissionSetRecord.Profile != null ? permissionSetRecord.Profile.Name : null;
            row.objectPermissionsCount = getOrZero(objectPermissionCounts, permissionSetRecord.Id);
            row.fieldPermissionsCount = getOrZero(fieldPermissionCounts, permissionSetRecord.Id);
            row.setupEntityAccessCount = getOrZero(setupEntityAccessCounts, permissionSetRecord.Id);
            row.assignmentCount = getOrZero(permissionSetAssignmentCounts, permissionSetRecord.Id);
            response.permissionSets.add(row);
        }

        Map<Id, PermissionSetRow> profileOwnedPermissionSetByProfileId = new Map<Id, PermissionSetRow>();
        for (PermissionSetRow permissionSetRow : response.permissionSets) {
            if (permissionSetRow.isOwnedByProfile == true && permissionSetRow.profileId != null) {
                profileOwnedPermissionSetByProfileId.put(permissionSetRow.profileId, permissionSetRow);
            }
        }

        List<PermissionSetGroup> permissionSetGroups = [
            SELECT Id, DeveloperName, MasterLabel, Status
            FROM PermissionSetGroup
            ORDER BY MasterLabel, DeveloperName
            LIMIT 2000
        ];

        Set<Id> permissionSetGroupIds = new Set<Id>();
        for (PermissionSetGroup permissionSetGroupRecord : permissionSetGroups) {
            permissionSetGroupIds.add(permissionSetGroupRecord.Id);
        }

        Map<Id, Integer> permissionSetGroupMemberCounts = getCountMapByParentId(
            [
                SELECT PermissionSetGroupId parentId, COUNT(Id) totalCount
                FROM PermissionSetGroupComponent
                WHERE PermissionSetGroupId IN :permissionSetGroupIds
                GROUP BY PermissionSetGroupId
            ],
            'parentId',
            'totalCount'
        );

        Map<Id, Integer> permissionSetGroupAssignmentCounts = getCountMapByParentId(
            [
                SELECT PermissionSetGroupId parentId, COUNT(Id) totalCount
                FROM PermissionSetAssignment
                WHERE PermissionSetGroupId IN :permissionSetGroupIds
                GROUP BY PermissionSetGroupId
            ],
            'parentId',
            'totalCount'
        );

        Set<Id> permissionSetGroupsWithMuting = new Set<Id>();
        for (PermissionSet permissionSetRecord : [
            SELECT PermissionSetGroupId
            FROM PermissionSet
            WHERE PermissionSetGroupId IN :permissionSetGroupIds
                AND Type = 'Muting'
        ]) {
            permissionSetGroupsWithMuting.add(permissionSetRecord.PermissionSetGroupId);
        }

        for (PermissionSetGroup permissionSetGroupRecord : permissionSetGroups) {
            PermissionSetGroupRow row = new PermissionSetGroupRow();
            row.id = permissionSetGroupRecord.Id;
            row.developerName = permissionSetGroupRecord.DeveloperName;
            row.label = permissionSetGroupRecord.MasterLabel;
            row.status = permissionSetGroupRecord.Status;
            row.memberCount = getOrZero(permissionSetGroupMemberCounts, permissionSetGroupRecord.Id);
            row.assignmentCount = getOrZero(permissionSetGroupAssignmentCounts, permissionSetGroupRecord.Id);
            row.hasMutingPermissionSet = permissionSetGroupsWithMuting.contains(permissionSetGroupRecord.Id);
            response.permissionSetGroups.add(row);
        }

        List<Profile> profiles = [
            SELECT Id, Name
            FROM Profile
            ORDER BY Name
            LIMIT 2000
        ];

        for (Profile profileRecord : profiles) {
            ProfileRow row = new ProfileRow();
            row.id = profileRecord.Id;
            row.name = profileRecord.Name;

            PermissionSetRow profileOwnedPermissionSet = profileOwnedPermissionSetByProfileId.get(profileRecord.Id);
            if (profileOwnedPermissionSet != null) {
                row.ownedPermissionSetId = profileOwnedPermissionSet.id;
                row.ownedPermissionSetName = String.isBlank(profileOwnedPermissionSet.label)
                    ? profileOwnedPermissionSet.apiName
                    : profileOwnedPermissionSet.label;
                row.objectPermissionsCount = profileOwnedPermissionSet.objectPermissionsCount;
                row.fieldPermissionsCount = profileOwnedPermissionSet.fieldPermissionsCount;
                row.setupEntityAccessCount = profileOwnedPermissionSet.setupEntityAccessCount;
                row.assignmentCount = profileOwnedPermissionSet.assignmentCount;
            } else {
                row.objectPermissionsCount = 0;
                row.fieldPermissionsCount = 0;
                row.setupEntityAccessCount = 0;
                row.assignmentCount = 0;
            }

            response.profiles.add(row);
        }

        return response;
    }

    private static Integer getOrZero(Map<Id, Integer> sourceMap, Id keyId) {
        if (sourceMap == null || !sourceMap.containsKey(keyId) || sourceMap.get(keyId) == null) {
            return 0;
        }
        return sourceMap.get(keyId);
    }

    private static Map<Id, Integer> getCountMapByParentId(
        List<AggregateResult> aggregateResults,
        String idAlias,
        String countAlias
    ) {
        Map<Id, Integer> responseMap = new Map<Id, Integer>();

        for (AggregateResult aggregateResult : aggregateResults) {
            Id parentId = (Id) aggregateResult.get(idAlias);
            Integer countValue = (Integer) aggregateResult.get(countAlias);
            responseMap.put(parentId, countValue == null ? 0 : countValue);
        }

        return responseMap;
    }
}