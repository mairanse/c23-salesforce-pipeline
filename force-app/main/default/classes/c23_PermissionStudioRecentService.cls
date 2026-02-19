public with sharing class c23_PermissionStudioRecentService {
    private static final Integer MAX_RECENT_ITEMS = 10;
    private static final String TYPE_PERMISSION_SET = 'PermissionSet';
    private static final String TYPE_PROFILE = 'Profile';

    public class RecentSelectionRow {
        @AuraEnabled public String itemType;
        @AuraEnabled public String targetId;
        @AuraEnabled public String displayName;
        @AuraEnabled public Id editorPermissionSetId;
        @AuraEnabled public Long viewedAt;
    }

    @AuraEnabled(cacheable=true)
    public static List<RecentSelectionRow> getRecentSelections() {
        c23_PermissionStudioSecurity.assertAccess();
        User currentUser = getCurrentUserForRead();
        return parseSelections(currentUser.c23_PS_RecentSelections__c);
    }

    @AuraEnabled
    public static List<RecentSelectionRow> saveRecentSelection(String itemType, Id targetId) {
        c23_PermissionStudioSecurity.assertAccess();
        RecentSelectionRow latest = resolveSelection(itemType, targetId);
        List<RecentSelectionRow> existing = getRecentSelections();

        List<RecentSelectionRow> merged = new List<RecentSelectionRow>();
        merged.add(latest);

        Set<String> seenKeys = new Set<String>{ toSelectionKey(latest.itemType, latest.targetId) };
        for (RecentSelectionRow existingRow : existing) {
            if (merged.size() >= MAX_RECENT_ITEMS || existingRow == null) {
                continue;
            }

            String key = toSelectionKey(existingRow.itemType, existingRow.targetId);
            if (String.isBlank(key) || seenKeys.contains(key)) {
                continue;
            }

            seenKeys.add(key);
            merged.add(existingRow);
        }

        persistSelections(merged);
        return merged;
    }

    private static RecentSelectionRow resolveSelection(String itemType, Id targetId) {
        String normalizedType = normalizeItemType(itemType);
        if (normalizedType == null || targetId == null) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_Error_InvalidPermissionSet);
        }

        if (normalizedType == TYPE_PERMISSION_SET) {
            List<PermissionSet> permissionSets = [
                SELECT Id, Name, Label
                FROM PermissionSet
                WHERE Id = :targetId
                LIMIT 1
            ];
            if (permissionSets.isEmpty()) {
                throw c23_PermissionStudioSecurity.handled(Label.c23_PS_Error_InvalidPermissionSet);
            }

            PermissionSet permissionSetRecord = permissionSets[0];
            return createSelection(
                TYPE_PERMISSION_SET,
                permissionSetRecord.Id,
                String.isBlank(permissionSetRecord.Label) ? permissionSetRecord.Name : permissionSetRecord.Label,
                permissionSetRecord.Id
            );
        }

        List<Profile> profiles = [
            SELECT Id, Name
            FROM Profile
            WHERE Id = :targetId
            LIMIT 1
        ];
        if (profiles.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_Error_InvalidPermissionSet);
        }

        Profile profileRecord = profiles[0];
        Id editorPermissionSetId = null;
        List<PermissionSet> profileOwnedPermissionSets = [
            SELECT Id
            FROM PermissionSet
            WHERE IsOwnedByProfile = true
                AND ProfileId = :profileRecord.Id
            LIMIT 1
        ];
        if (!profileOwnedPermissionSets.isEmpty()) {
            editorPermissionSetId = profileOwnedPermissionSets[0].Id;
        }

        return createSelection(TYPE_PROFILE, profileRecord.Id, profileRecord.Name, editorPermissionSetId);
    }

    private static RecentSelectionRow createSelection(
        String itemType,
        Id targetId,
        String displayName,
        Id editorPermissionSetId
    ) {
        RecentSelectionRow row = new RecentSelectionRow();
        row.itemType = itemType;
        row.targetId = String.valueOf(targetId);
        row.displayName = clipText(displayName, 255);
        row.editorPermissionSetId = editorPermissionSetId;
        row.viewedAt = Datetime.now().getTime();
        return row;
    }

    private static User getCurrentUserForRead() {
        List<User> queriedUsers = [
            SELECT Id, c23_PS_RecentSelections__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (queriedUsers.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_General_AccessDenied);
        }

        SObjectAccessDecision decision = Security.stripInaccessible(
            System.AccessType.READABLE,
            queriedUsers
        );
        assertNoStrippedFields(decision);
        return (User) decision.getRecords()[0];
    }

    private static void persistSelections(List<RecentSelectionRow> selections) {
        String serialized = serializeSelections(selections);
        User updateRecord = new User(
            Id = UserInfo.getUserId(),
            c23_PS_RecentSelections__c = serialized
        );

        SObjectAccessDecision decision = Security.stripInaccessible(
            System.AccessType.UPDATABLE,
            new List<SObject>{ updateRecord }
        );
        assertNoStrippedFields(decision);
        update (User) decision.getRecords()[0];
    }

    private static List<RecentSelectionRow> parseSelections(String rawValue) {
        List<RecentSelectionRow> rows = new List<RecentSelectionRow>();
        if (String.isBlank(rawValue)) {
            return rows;
        }

        List<Object> rawList;
        try {
            rawList = (List<Object>) JSON.deserializeUntyped(rawValue);
        } catch (Exception ex) {
            c23_ErrorLogService.logWarning(
                'RecentService.parseSelections',
                ex.getMessage(),
                'Unable to parse recent selections JSON payload.',
                null
            );
            return rows;
        }

        for (Object rawItem : rawList) {
            if (!(rawItem instanceof Map<String, Object>)) {
                continue;
            }

            Map<String, Object> itemMap = (Map<String, Object>) rawItem;
            String itemType = normalizeItemType(asString(itemMap.get('itemType')));
            String targetId = asString(itemMap.get('targetId'));
            if (itemType == null || String.isBlank(targetId)) {
                continue;
            }

            RecentSelectionRow row = new RecentSelectionRow();
            row.itemType = itemType;
            row.targetId = targetId;
            row.displayName = clipText(asString(itemMap.get('displayName')), 255);
            row.editorPermissionSetId = toId(asString(itemMap.get('editorPermissionSetId')));
            row.viewedAt = asLong(itemMap.get('viewedAt'));

            if (row.itemType == TYPE_PERMISSION_SET && row.editorPermissionSetId == null) {
                row.editorPermissionSetId = toId(row.targetId);
            }

            rows.add(row);
            if (rows.size() >= MAX_RECENT_ITEMS) {
                break;
            }
        }

        return rows;
    }

    private static String serializeSelections(List<RecentSelectionRow> selections) {
        List<Map<String, Object>> payload = new List<Map<String, Object>>();
        for (RecentSelectionRow row : selections) {
            if (row == null || String.isBlank(row.itemType) || String.isBlank(row.targetId)) {
                continue;
            }

            Map<String, Object> valueMap = new Map<String, Object>();
            valueMap.put('itemType', row.itemType);
            valueMap.put('targetId', row.targetId);
            valueMap.put('displayName', clipText(row.displayName, 255));
            valueMap.put('editorPermissionSetId', row.editorPermissionSetId == null ? null : String.valueOf(row.editorPermissionSetId));
            valueMap.put('viewedAt', row.viewedAt == null ? Datetime.now().getTime() : row.viewedAt);
            payload.add(valueMap);

            if (payload.size() >= MAX_RECENT_ITEMS) {
                break;
            }
        }
        return JSON.serialize(payload);
    }

    private static String normalizeItemType(String itemType) {
        if (itemType == TYPE_PERMISSION_SET || itemType == TYPE_PROFILE) {
            return itemType;
        }
        return null;
    }

    private static String toSelectionKey(String itemType, String targetId) {
        String normalizedType = normalizeItemType(itemType);
        if (normalizedType == null || String.isBlank(targetId)) {
            return null;
        }
        return normalizedType + ':' + targetId;
    }

    private static String asString(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Long asLong(Object value) {
        if (value == null) {
            return null;
        }

        try {
            if (value instanceof Decimal) {
                return ((Decimal) value).longValue();
            }
            if (value instanceof Integer) {
                return Long.valueOf(String.valueOf(value));
            }
            if (value instanceof Long) {
                return (Long) value;
            }
            String text = String.valueOf(value).trim();
            if (String.isBlank(text)) {
                return null;
            }
            return Long.valueOf(text);
        } catch (Exception ignored) {
            return null;
        }
    }

    private static Id toId(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        try {
            return (Id) value;
        } catch (Exception ignored) {
            return null;
        }
    }

    private static String clipText(String value, Integer maxLength) {
        if (value == null) {
            return null;
        }
        if (maxLength == null || maxLength <= 0 || value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }

    private static void assertNoStrippedFields(SObjectAccessDecision decision) {
        Map<String, Set<String>> removedFields = decision == null ? null : decision.getRemovedFields();
        if (removedFields != null && !removedFields.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_General_AccessDenied);
        }
    }
}