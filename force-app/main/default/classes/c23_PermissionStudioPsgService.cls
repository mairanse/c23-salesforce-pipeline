public with sharing class c23_PermissionStudioPsgService {
    public class PermissionSetOption implements Comparable {
        @AuraEnabled public Id id;
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;

        public Integer compareTo(Object otherObject) {
            PermissionSetOption otherValue = (PermissionSetOption) otherObject;
            String thisSort = ((label == null ? '' : label) + '|' + (apiName == null ? '' : apiName)).toLowerCase();
            String otherSort = ((otherValue.label == null ? '' : otherValue.label) + '|' + (otherValue.apiName == null ? '' : otherValue.apiName)).toLowerCase();
            if (thisSort == otherSort) {
                return 0;
            }
            return thisSort < otherSort ? -1 : 1;
        }
    }

    public class GroupEditorResponse {
        @AuraEnabled public Id groupId;
        @AuraEnabled public String developerName;
        @AuraEnabled public String label;
        @AuraEnabled public String status;
        @AuraEnabled public Integer memberCount;
        @AuraEnabled public List<PermissionSetOption> memberPermissionSets;
        @AuraEnabled public List<PermissionSetOption> availablePermissionSets;
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

    @AuraEnabled
    public static GroupEditorResponse getPermissionSetGroupEditor(Id permissionSetGroupId) {
        c23_PermissionStudioSecurity.assertAccess();
        PermissionSetGroup groupRecord = validatePermissionSetGroup(permissionSetGroupId);

        Map<Id, PermissionSet> catalogById = queryEditablePermissionSetCatalog();
        Set<Id> memberPermissionSetIds = new Set<Id>();
        for (PermissionSetGroupComponent component : [
            SELECT PermissionSetId
            FROM PermissionSetGroupComponent
            WHERE PermissionSetGroupId = :groupRecord.Id
        ]) {
            memberPermissionSetIds.add(component.PermissionSetId);
        }

        List<PermissionSetOption> members = new List<PermissionSetOption>();
        List<PermissionSetOption> available = new List<PermissionSetOption>();
        for (PermissionSet permissionSetRecord : catalogById.values()) {
            PermissionSetOption option = toOption(permissionSetRecord);
            if (memberPermissionSetIds.contains(permissionSetRecord.Id)) {
                members.add(option);
            } else {
                available.add(option);
            }
        }

        members.sort();
        available.sort();

        GroupEditorResponse response = new GroupEditorResponse();
        response.groupId = groupRecord.Id;
        response.developerName = groupRecord.DeveloperName;
        response.label = groupRecord.MasterLabel;
        response.status = groupRecord.Status;
        response.memberCount = members.size();
        response.memberPermissionSets = members;
        response.availablePermissionSets = available;
        return response;
    }

    @AuraEnabled
    public static ApplyResponse applyGroupMembership(
        Id permissionSetGroupId,
        List<Id> desiredPermissionSetIds,
        String changeNote
    ) {
        c23_PermissionStudioSecurity.assertAccess();
        PermissionSetGroup groupRecord = validatePermissionSetGroup(permissionSetGroupId);
        Set<Id> desiredIds = sanitizeDesiredPermissionSetIds(desiredPermissionSetIds);

        Map<Id, PermissionSetGroupComponent> existingByPermissionSetId = new Map<Id, PermissionSetGroupComponent>();
        for (PermissionSetGroupComponent component : [
            SELECT Id, PermissionSetId
            FROM PermissionSetGroupComponent
            WHERE PermissionSetGroupId = :groupRecord.Id
        ]) {
            existingByPermissionSetId.put(component.PermissionSetId, component);
        }

        Map<Id, PermissionSet> catalogById = queryEditablePermissionSetCatalog();
        List<PermissionSetGroupComponent> toInsert = new List<PermissionSetGroupComponent>();
        List<PermissionSetGroupComponent> toDelete = new List<PermissionSetGroupComponent>();
        List<c23_PermissionStudioLedgerService.LedgerItemPayload> ledgerItems =
            new List<c23_PermissionStudioLedgerService.LedgerItemPayload>();

        for (Id desiredPermissionSetId : desiredIds) {
            if (!catalogById.containsKey(desiredPermissionSetId)) {
                continue;
            }
            if (existingByPermissionSetId.containsKey(desiredPermissionSetId)) {
                continue;
            }

            PermissionSetGroupComponent newComponent = new PermissionSetGroupComponent();
            newComponent.PermissionSetGroupId = groupRecord.Id;
            newComponent.PermissionSetId = desiredPermissionSetId;
            toInsert.add(newComponent);

            c23_PermissionStudioLedgerService.LedgerItemPayload addedItem =
                new c23_PermissionStudioLedgerService.LedgerItemPayload();
            addedItem.itemKey = toLedgerItemKey(catalogById.get(desiredPermissionSetId));
            addedItem.beforeJson = toMembershipJson(false);
            addedItem.afterJson = toMembershipJson(true);
            ledgerItems.add(addedItem);
        }

        for (Id existingPermissionSetId : existingByPermissionSetId.keySet()) {
            if (desiredIds.contains(existingPermissionSetId)) {
                continue;
            }

            toDelete.add(existingByPermissionSetId.get(existingPermissionSetId));

            PermissionSet existingPermissionSet = catalogById.get(existingPermissionSetId);
            c23_PermissionStudioLedgerService.LedgerItemPayload removedItem =
                new c23_PermissionStudioLedgerService.LedgerItemPayload();
            removedItem.itemKey = existingPermissionSet == null
                ? String.valueOf(existingPermissionSetId)
                : toLedgerItemKey(existingPermissionSet);
            removedItem.beforeJson = toMembershipJson(true);
            removedItem.afterJson = toMembershipJson(false);
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
                'PermissionSetGroup',
                groupRecord.Id,
                groupRecord.MasterLabel,
                Label.c23_PS_PSG_MembersTitle,
                changeNote,
                desiredIds.size(),
                insertCount,
                updateCount,
                ledgerItems
            );

        ApplyResponse response = new ApplyResponse();
        response.changedCount = changedCount;
        response.insertCount = insertCount;
        response.updateCount = updateCount;
        response.totalRequestedCount = desiredIds.size();
        response.ledgerId = ledgerResult.headerId;
        response.ledgerTruncated = ledgerResult.isTruncated;
        response.ledgerStoredItemCount = ledgerResult.storedItemCount;
        response.ledgerTotalItemCount = ledgerResult.totalItemCount;
        response.message = Label.c23_PS_PSG_ApplySuccess;
        return response;
    }

    private static PermissionSetGroup validatePermissionSetGroup(Id permissionSetGroupId) {
        if (permissionSetGroupId == null) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_Error_InvalidPermissionSetGroup);
        }

        List<PermissionSetGroup> groups = [
            SELECT Id, DeveloperName, MasterLabel, Status
            FROM PermissionSetGroup
            WHERE Id = :permissionSetGroupId
            LIMIT 1
        ];

        if (groups.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_Error_InvalidPermissionSetGroup);
        }

        return groups[0];
    }

    private static Set<Id> sanitizeDesiredPermissionSetIds(List<Id> desiredPermissionSetIds) {
        Set<Id> ids = new Set<Id>();
        if (desiredPermissionSetIds == null) {
            return ids;
        }

        for (Id permissionSetId : desiredPermissionSetIds) {
            if (permissionSetId != null) {
                ids.add(permissionSetId);
            }
        }
        return ids;
    }

    private static Map<Id, PermissionSet> queryEditablePermissionSetCatalog() {
        Map<Id, PermissionSet> byId = new Map<Id, PermissionSet>();
        for (PermissionSet permissionSetRecord : [
            SELECT Id, Name, Label, IsOwnedByProfile, Type
            FROM PermissionSet
            WHERE IsOwnedByProfile = false
                AND (Type = null OR Type != 'Muting')
            ORDER BY Label, Name
            LIMIT 5000
        ]) {
            byId.put(permissionSetRecord.Id, permissionSetRecord);
        }
        return byId;
    }

    private static PermissionSetOption toOption(PermissionSet permissionSetRecord) {
        PermissionSetOption option = new PermissionSetOption();
        option.id = permissionSetRecord.Id;
        option.apiName = permissionSetRecord.Name;
        option.label = String.isBlank(permissionSetRecord.Label) ? permissionSetRecord.Name : permissionSetRecord.Label;
        return option;
    }

    private static String toLedgerItemKey(PermissionSet permissionSetRecord) {
        if (permissionSetRecord == null) {
            return null;
        }
        String labelValue = String.isBlank(permissionSetRecord.Label) ? permissionSetRecord.Name : permissionSetRecord.Label;
        return permissionSetRecord.Name + '|' + labelValue;
    }

    private static String toMembershipJson(Boolean isMember) {
        Map<String, Object> valueMap = new Map<String, Object>();
        valueMap.put('isMember', isMember == true);
        return JSON.serialize(valueMap);
    }
}