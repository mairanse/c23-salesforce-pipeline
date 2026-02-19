public with sharing class c23_AuditQueryService {
    private static final Integer SEARCH_RESULT_LIMIT = 200;
    private static final Integer WHO_HAS_LIMIT = 50000;
    private static final Integer LEDGER_LIMIT = 5000;
    private static final String SYSTEM_PERMISSION_PREFIX = 'permissions';

    public class PermissionKeyDTO implements Comparable {
        @AuraEnabled public String key;
        @AuraEnabled public String displayLabel;
        @AuraEnabled public String category;

        public Integer compareTo(Object otherObject) {
            PermissionKeyDTO otherValue = (PermissionKeyDTO) otherObject;
            String thisSort = (displayLabel == null ? '' : displayLabel).toLowerCase();
            String otherSort = (otherValue == null || otherValue.displayLabel == null ? '' : otherValue.displayLabel).toLowerCase();
            if (thisSort == otherSort) {
                return 0;
            }
            return thisSort < otherSort ? -1 : 1;
        }
    }

    public class WhoHasRowDTO implements Comparable {
        @AuraEnabled public Id userId;
        @AuraEnabled public String name;
        @AuraEnabled public String username;
        @AuraEnabled public String profileName;
        @AuraEnabled public String accessLevel;
        @AuraEnabled public String sourceSummary;

        public Integer compareTo(Object otherObject) {
            WhoHasRowDTO otherValue = (WhoHasRowDTO) otherObject;
            String thisSort = ((name == null ? '' : name) + '|' + (username == null ? '' : username)).toLowerCase();
            String otherSort = ((otherValue == null || otherValue.name == null ? '' : otherValue.name) + '|' +
                (otherValue == null || otherValue.username == null ? '' : otherValue.username)).toLowerCase();
            if (thisSort == otherSort) {
                return 0;
            }
            return thisSort < otherSort ? -1 : 1;
        }
    }

    public class LedgerEventDTO {
        @AuraEnabled public Id changeId;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String targetType;
        @AuraEnabled public String targetName;
        @AuraEnabled public String sectionName;
        @AuraEnabled public Integer changedCount;
    }

    public class SnapshotDiffDTO {
        @AuraEnabled public Datetime eventDate;
        @AuraEnabled public String permissionKey;
        @AuraEnabled public String beforeValue;
        @AuraEnabled public String afterValue;
    }

    private class WhoHasAccumulator {
        public Id userId;
        public String name;
        public String username;
        public String profileName;
        public Set<String> sources = new Set<String>();
    }

    @AuraEnabled(cacheable=true)
    public static List<PermissionKeyDTO> searchPermissionKeys(String term, List<String> categories) {
        c23_PermissionStudioSecurity.assertAccess();
        String searchTerm = String.isBlank(term) ? '' : term.trim().toLowerCase();
        Set<String> requestedCategories = normalizeCategories(categories);

        List<PermissionKeyDTO> rows = new List<PermissionKeyDTO>();
        if (requestedCategories.contains('SYSTEM')) {
            appendSystemKeys(rows, searchTerm);
        }
        if (requestedCategories.contains('OBJECT')) {
            appendObjectKeys(rows, searchTerm);
        }
        if (requestedCategories.contains('FIELD')) {
            appendFieldKeys(rows, searchTerm);
        }

        rows.sort();
        if (rows.size() > SEARCH_RESULT_LIMIT) {
            List<PermissionKeyDTO> limitedRows = new List<PermissionKeyDTO>();
            for (Integer index = 0; index < SEARCH_RESULT_LIMIT; index++) {
                limitedRows.add(rows[index]);
            }
            rows = limitedRows;
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<WhoHasRowDTO> whoHas(String permissionKey, Datetime asOfDate) {
        c23_PermissionStudioSecurity.assertAccess();
        if (String.isBlank(permissionKey)) {
            return new List<WhoHasRowDTO>();
        }

        ParsedPermissionKey parsed = parsePermissionKey(permissionKey.trim());
        if (parsed == null) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_Audit_Error_InvalidPermissionKey);
        }

        Set<Id> permissionSetIds = new Set<Id>();
        Set<Id> profileIds = new Set<Id>();
        String accessLevel = Label.c23_PS_General_Yes;

        if (parsed.category == 'SYSTEM') {
            gatherSystemPermissionSets(parsed, permissionSetIds, profileIds);
        } else if (parsed.category == 'OBJECT') {
            accessLevel = permissionTokenLabel(parsed.permissionToken);
            gatherObjectPermissionSets(parsed, permissionSetIds, profileIds);
        } else if (parsed.category == 'FIELD') {
            accessLevel = permissionTokenLabel(parsed.permissionToken);
            gatherFieldPermissionSets(parsed, permissionSetIds, profileIds);
        }

        return queryUsersWithAccess(permissionSetIds, profileIds, accessLevel);
    }

    @AuraEnabled(cacheable=true)
    public static List<LedgerEventDTO> getLedgerEvents(Id targetId, Date dateFrom, Date dateTo) {
        c23_PermissionStudioSecurity.assertAccess();

        Date startDate = dateFrom == null ? Date.today().addDays(-30) : dateFrom;
        Date endDate = dateTo == null ? Date.today() : dateTo;
        Datetime startDateTime = Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        Datetime endDateTime = Datetime.newInstance(endDate.addDays(1), Time.newInstance(0, 0, 0, 0));
        String targetIdText = targetId == null ? null : String.valueOf(targetId);

        List<LedgerEventDTO> rows = new List<LedgerEventDTO>();
        List<c23_PermissionStudioChange__c> ledgerRows;
        if (String.isBlank(targetIdText)) {
            ledgerRows = [
                SELECT Id,
                    CreatedDate,
                    c23_TargetType__c,
                    c23_TargetName__c,
                    c23_Section__c,
                    c23_ChangedCount__c
                FROM c23_PermissionStudioChange__c
                WHERE CreatedDate >= :startDateTime
                    AND CreatedDate < :endDateTime
                ORDER BY CreatedDate DESC
                LIMIT :LEDGER_LIMIT
            ];
        } else {
            ledgerRows = [
                SELECT Id,
                    CreatedDate,
                    c23_TargetType__c,
                    c23_TargetName__c,
                    c23_Section__c,
                    c23_ChangedCount__c
                FROM c23_PermissionStudioChange__c
                WHERE c23_TargetId__c = :targetIdText
                    AND CreatedDate >= :startDateTime
                    AND CreatedDate < :endDateTime
                ORDER BY CreatedDate DESC
                LIMIT :LEDGER_LIMIT
            ];
        }

        for (c23_PermissionStudioChange__c row : ledgerRows) {
            LedgerEventDTO dto = new LedgerEventDTO();
            dto.changeId = row.Id;
            dto.createdDate = row.CreatedDate;
            dto.targetType = row.c23_TargetType__c;
            dto.targetName = row.c23_TargetName__c;
            dto.sectionName = row.c23_Section__c;
            dto.changedCount = row.c23_ChangedCount__c == null ? 0 : Integer.valueOf(row.c23_ChangedCount__c);
            rows.add(dto);
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<SnapshotDiffDTO> getSnapshotDiff(Date dateFrom, Date dateTo) {
        c23_PermissionStudioSecurity.assertAccess();
        return new List<SnapshotDiffDTO>();
    }

    private class ParsedPermissionKey {
        public String category;
        public String objectApiName;
        public String fieldPath;
        public String permissionToken;
        public String systemFieldApiName;
    }

    private static ParsedPermissionKey parsePermissionKey(String permissionKey) {
        if (permissionKey.startsWith('sys:')) {
            ParsedPermissionKey parsed = new ParsedPermissionKey();
            parsed.category = 'SYSTEM';
            parsed.systemFieldApiName = permissionKey.substring(4);
            return parsed;
        }
        if (permissionKey.startsWith('obj:')) {
            List<String> parts = permissionKey.split(':');
            if (parts.size() != 3) {
                return null;
            }
            ParsedPermissionKey parsed = new ParsedPermissionKey();
            parsed.category = 'OBJECT';
            parsed.objectApiName = parts[1];
            parsed.permissionToken = parts[2];
            return parsed;
        }
        if (permissionKey.startsWith('fld:')) {
            List<String> parts = permissionKey.split(':');
            if (parts.size() != 3) {
                return null;
            }
            ParsedPermissionKey parsed = new ParsedPermissionKey();
            parsed.category = 'FIELD';
            parsed.fieldPath = parts[1];
            parsed.permissionToken = parts[2];
            return parsed;
        }
        return null;
    }

    private static void gatherSystemPermissionSets(ParsedPermissionKey parsed, Set<Id> permissionSetIds, Set<Id> profileIds) {
        if (String.isBlank(parsed.systemFieldApiName) || !parsed.systemFieldApiName.toLowerCase().startsWith(SYSTEM_PERMISSION_PREFIX)) {
            return;
        }
        Map<String, Schema.SObjectField> fieldMap = PermissionSet.SObjectType.getDescribe().fields.getMap();
        String canonicalFieldApiName = resolveSystemPermissionFieldApiName(parsed.systemFieldApiName, fieldMap);
        if (String.isBlank(canonicalFieldApiName) || !fieldMap.containsKey(canonicalFieldApiName)) {
            return;
        }
        Schema.DescribeFieldResult describeField = fieldMap.get(canonicalFieldApiName).getDescribe();
        if (describeField.getType() != Schema.DisplayType.Boolean) {
            return;
        }

        List<PermissionSet> rows = Database.query(
            'SELECT Id, ProfileId FROM PermissionSet WHERE ' + canonicalFieldApiName + ' = true'
        );
        collectPermissionSetAndProfileIds(rows, permissionSetIds, profileIds);
    }

    private static void gatherObjectPermissionSets(ParsedPermissionKey parsed, Set<Id> permissionSetIds, Set<Id> profileIds) {
        String fieldName = objectPermissionFieldName(parsed.permissionToken);
        if (fieldName == null) {
            return;
        }
        String soql = 'SELECT ParentId FROM ObjectPermissions WHERE SObjectType = :parsed.objectApiName AND ' + fieldName + ' = true';
        List<ObjectPermissions> rows = Database.query(soql);
        for (ObjectPermissions row : rows) {
            permissionSetIds.add(row.ParentId);
        }
        collectProfileIdsFromPermissionSetIds(permissionSetIds, profileIds);
    }

    private static void gatherFieldPermissionSets(ParsedPermissionKey parsed, Set<Id> permissionSetIds, Set<Id> profileIds) {
        String fieldName = fieldPermissionFieldName(parsed.permissionToken);
        if (fieldName == null) {
            return;
        }
        String soql = 'SELECT ParentId FROM FieldPermissions WHERE Field = :parsed.fieldPath AND ' + fieldName + ' = true';
        List<FieldPermissions> rows = Database.query(soql);
        for (FieldPermissions row : rows) {
            permissionSetIds.add(row.ParentId);
        }
        collectProfileIdsFromPermissionSetIds(permissionSetIds, profileIds);
    }

    private static String objectPermissionFieldName(String permissionToken) {
        if (permissionToken == 'read') {
            return 'PermissionsRead';
        }
        if (permissionToken == 'create') {
            return 'PermissionsCreate';
        }
        if (permissionToken == 'edit') {
            return 'PermissionsEdit';
        }
        if (permissionToken == 'delete') {
            return 'PermissionsDelete';
        }
        if (permissionToken == 'viewall') {
            return 'PermissionsViewAllRecords';
        }
        if (permissionToken == 'modifyall') {
            return 'PermissionsModifyAllRecords';
        }
        return null;
    }

    private static String fieldPermissionFieldName(String permissionToken) {
        if (permissionToken == 'read') {
            return 'PermissionsRead';
        }
        if (permissionToken == 'edit') {
            return 'PermissionsEdit';
        }
        return null;
    }

    private static void collectPermissionSetAndProfileIds(
        List<PermissionSet> rows,
        Set<Id> permissionSetIds,
        Set<Id> profileIds
    ) {
        for (PermissionSet row : rows) {
            permissionSetIds.add(row.Id);
            if (row.ProfileId != null) {
                profileIds.add(row.ProfileId);
            }
        }
    }

    private static void collectProfileIdsFromPermissionSetIds(Set<Id> permissionSetIds, Set<Id> profileIds) {
        if (permissionSetIds == null || permissionSetIds.isEmpty()) {
            return;
        }
        for (PermissionSet row : [
            SELECT Id, ProfileId
            FROM PermissionSet
            WHERE Id IN :permissionSetIds
        ]) {
            if (row.ProfileId != null) {
                profileIds.add(row.ProfileId);
            }
        }
    }

    private static List<WhoHasRowDTO> queryUsersWithAccess(Set<Id> permissionSetIds, Set<Id> profileIds, String accessLevel) {
        Map<Id, WhoHasAccumulator> byUserId = new Map<Id, WhoHasAccumulator>();

        if (!permissionSetIds.isEmpty()) {
            for (PermissionSetAssignment assignmentRow : [
                SELECT AssigneeId, Assignee.Name, Assignee.Username, Assignee.Profile.Name
                FROM PermissionSetAssignment
                WHERE PermissionSetId IN :permissionSetIds
                LIMIT :WHO_HAS_LIMIT
            ]) {
                upsertAccumulator(byUserId, assignmentRow.AssigneeId, assignmentRow.Assignee, Label.c23_PS_Audit_Source_PermissionSet);
            }
        }

        if (!profileIds.isEmpty()) {
            for (User userRow : [
                SELECT Id, Name, Username, Profile.Name
                FROM User
                WHERE IsActive = true
                    AND ProfileId IN :profileIds
                LIMIT :WHO_HAS_LIMIT
            ]) {
                upsertAccumulator(byUserId, userRow.Id, userRow, Label.c23_PS_Audit_Source_Profile);
            }
        }

        List<WhoHasRowDTO> response = new List<WhoHasRowDTO>();
        for (WhoHasAccumulator item : byUserId.values()) {
            WhoHasRowDTO row = new WhoHasRowDTO();
            row.userId = item.userId;
            row.name = item.name;
            row.username = item.username;
            row.profileName = item.profileName;
            row.accessLevel = accessLevel;
            List<String> sources = new List<String>();
            sources.addAll(item.sources);
            sources.sort();
            row.sourceSummary = String.join(sources, ', ');
            response.add(row);
        }
        response.sort();
        return response;
    }

    private static void upsertAccumulator(Map<Id, WhoHasAccumulator> byUserId, Id userId, User userRow, String sourceLabel) {
        if (userId == null || userRow == null) {
            return;
        }
        WhoHasAccumulator item = byUserId.get(userId);
        if (item == null) {
            item = new WhoHasAccumulator();
            item.userId = userRow.Id;
            item.name = userRow.Name;
            item.username = userRow.Username;
            item.profileName = userRow.Profile == null ? null : userRow.Profile.Name;
            byUserId.put(userId, item);
        }
        item.sources.add(sourceLabel);
    }

    private static Set<String> normalizeCategories(List<String> categories) {
        Set<String> response = new Set<String>();
        if (categories == null || categories.isEmpty()) {
            response.add('SYSTEM');
            response.add('OBJECT');
            response.add('FIELD');
            return response;
        }
        for (String category : categories) {
            if (String.isBlank(category)) {
                continue;
            }
            String normalized = category.trim().toUpperCase();
            if (normalized == 'SYSTEM' || normalized == 'OBJECT' || normalized == 'FIELD') {
                response.add(normalized);
            }
        }
        if (response.isEmpty()) {
            response.add('SYSTEM');
            response.add('OBJECT');
            response.add('FIELD');
        }
        return response;
    }

    private static void appendSystemKeys(List<PermissionKeyDTO> rows, String searchTerm) {
        Map<String, Schema.SObjectField> fieldMap = PermissionSet.SObjectType.getDescribe().fields.getMap();
        for (String fieldApiName : fieldMap.keySet()) {
            if (String.isBlank(fieldApiName) || !fieldApiName.toLowerCase().startsWith(SYSTEM_PERMISSION_PREFIX)) {
                continue;
            }
            Schema.DescribeFieldResult describeField = fieldMap.get(fieldApiName).getDescribe();
            if (describeField.getType() != Schema.DisplayType.Boolean) {
                continue;
            }
            String labelValue = describeField.getLabel();
            if (!matchesSearch(searchTerm, fieldApiName, labelValue)) {
                continue;
            }

            PermissionKeyDTO row = new PermissionKeyDTO();
            row.key = 'sys:' + fieldApiName;
            row.displayLabel = labelValue + ' (' + fieldApiName + ')';
            row.category = 'SYSTEM';
            rows.add(row);
        }
    }

    private static String resolveSystemPermissionFieldApiName(
        String incomingFieldApiName,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        if (String.isBlank(incomingFieldApiName) || fieldMap == null || fieldMap.isEmpty()) {
            return null;
        }

        String trimmed = incomingFieldApiName.trim();
        if (fieldMap.containsKey(trimmed)) {
            return trimmed;
        }

        for (String fieldApiName : fieldMap.keySet()) {
            if (fieldApiName != null && fieldApiName.toLowerCase() == trimmed.toLowerCase()) {
                return fieldApiName;
            }
        }

        return null;
    }

    private static void appendObjectKeys(List<PermissionKeyDTO> rows, String searchTerm) {
        for (c23_SchemaService.SObjectCatalogRow objectRow : c23_SchemaService.getSObjectCatalog()) {
            if (!matchesSearch(searchTerm, objectRow.apiName, objectRow.label)) {
                continue;
            }
            addObjectKey(rows, objectRow.apiName, objectRow.label, 'read');
            addObjectKey(rows, objectRow.apiName, objectRow.label, 'create');
            addObjectKey(rows, objectRow.apiName, objectRow.label, 'edit');
            addObjectKey(rows, objectRow.apiName, objectRow.label, 'delete');
            addObjectKey(rows, objectRow.apiName, objectRow.label, 'viewall');
            addObjectKey(rows, objectRow.apiName, objectRow.label, 'modifyall');
            if (rows.size() >= SEARCH_RESULT_LIMIT) {
                return;
            }
        }
    }

    private static void addObjectKey(List<PermissionKeyDTO> rows, String apiName, String labelValue, String permissionToken) {
        PermissionKeyDTO row = new PermissionKeyDTO();
        row.key = 'obj:' + apiName + ':' + permissionToken;
        row.displayLabel = (String.isBlank(labelValue) ? apiName : labelValue) + ' ' + permissionTokenLabel(permissionToken);
        row.category = 'OBJECT';
        rows.add(row);
    }

    private static void appendFieldKeys(List<PermissionKeyDTO> rows, String searchTerm) {
        Integer fieldScanLimit = SEARCH_RESULT_LIMIT * 5;
        List<AggregateResult> fieldRows = [
            SELECT Field fieldPath
            FROM FieldPermissions
            GROUP BY Field
            LIMIT :fieldScanLimit
        ];

        for (AggregateResult item : fieldRows) {
            String fieldPath = (String) item.get('fieldPath');
            if (String.isBlank(fieldPath)) {
                continue;
            }
            if (!String.isBlank(searchTerm) && !fieldPath.toLowerCase().contains(searchTerm)) {
                continue;
            }
            PermissionKeyDTO readKey = new PermissionKeyDTO();
            readKey.key = 'fld:' + fieldPath + ':read';
            readKey.displayLabel = fieldPath + ' ' + permissionTokenLabel('read');
            readKey.category = 'FIELD';
            rows.add(readKey);

            PermissionKeyDTO editKey = new PermissionKeyDTO();
            editKey.key = 'fld:' + fieldPath + ':edit';
            editKey.displayLabel = fieldPath + ' ' + permissionTokenLabel('edit');
            editKey.category = 'FIELD';
            rows.add(editKey);

            if (rows.size() >= SEARCH_RESULT_LIMIT) {
                return;
            }
        }
    }

    private static String permissionTokenLabel(String permissionToken) {
        if (permissionToken == 'read') {
            return Label.c23_PS_ObjectMatrix_Column_Read;
        }
        if (permissionToken == 'create') {
            return Label.c23_PS_ObjectMatrix_Column_Create;
        }
        if (permissionToken == 'edit') {
            return Label.c23_PS_ObjectMatrix_Column_Edit;
        }
        if (permissionToken == 'delete') {
            return Label.c23_PS_ObjectMatrix_Column_Delete;
        }
        if (permissionToken == 'viewall') {
            return Label.c23_PS_ObjectMatrix_Column_ViewAll;
        }
        if (permissionToken == 'modifyall') {
            return Label.c23_PS_ObjectMatrix_Column_ModifyAll;
        }
        return permissionToken;
    }

    private static Boolean matchesSearch(String searchTerm, String apiName, String labelValue) {
        if (String.isBlank(searchTerm)) {
            return true;
        }
        String safeApi = String.isBlank(apiName) ? '' : apiName.toLowerCase();
        String safeLabel = String.isBlank(labelValue) ? '' : labelValue.toLowerCase();
        return safeApi.contains(searchTerm) || safeLabel.contains(searchTerm);
    }

}