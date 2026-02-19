public with sharing class c23_ProfileMigrationPlanService {
    public static final String TARGET_MODE_CREATE = 'CREATE';
    public static final String TARGET_MODE_MERGE = 'MERGE';
    public static final String MERGE_STRATEGY_UNION = 'UNION';
    public static final String MERGE_STRATEGY_OVERWRITE = 'OVERWRITE';
    public static final String CATEGORY_OBJECT = 'OBJECT';
    public static final String CATEGORY_FIELD = 'FIELD';
    public static final String CATEGORY_SYSTEM = 'SYSTEM';
    public static final String CATEGORY_TAB = 'TAB';
    public static final String CATEGORY_SETUP = 'SETUP';
    public static final String SETUP_TYPE_APEX_CLASS = 'ApexClass';
    public static final String SETUP_TYPE_CUSTOM_PERMISSION = 'CustomPermission';
    public static final String TAB_DEFAULT_OFF = 'DefaultOff';
    private static final String SYSTEM_PERMISSION_PREFIX = 'permissions';

    public class ScopeOptionsDTO {
        @AuraEnabled public Boolean includeObjectPermissions;
        @AuraEnabled public Boolean includeFieldPermissions;
        @AuraEnabled public Boolean includeSystemPermissions;
        @AuraEnabled public Boolean includeTabVisibility;
        @AuraEnabled public Boolean includeSetupAccess;
        @AuraEnabled public Boolean includeGrantedOnly;
        @AuraEnabled public Boolean includeCustomObjectsOnly;
    }

    public class PlanItemDTO {
        @AuraEnabled public String key;
        @AuraEnabled public String category;
        @AuraEnabled public String label;
        @AuraEnabled public String sourceValue;
        @AuraEnabled public String targetValue;
        @AuraEnabled public String resultValue;
        @AuraEnabled public Boolean hasAccess;
        @AuraEnabled public Boolean isChanged;
        @AuraEnabled public Boolean isCustom;
    }

    public class CategoryCountDTO {
        @AuraEnabled public String category;
        @AuraEnabled public Integer count;
    }

    public class MigrationPlanDTO {
        @AuraEnabled public Id profileId;
        @AuraEnabled public String profileName;
        @AuraEnabled public Id sourcePermissionSetId;
        @AuraEnabled public String sourcePermissionSetName;
        @AuraEnabled public String targetMode;
        @AuraEnabled public Id targetPermissionSetId;
        @AuraEnabled public String targetPermissionSetName;
        @AuraEnabled public String targetPermissionSetApiName;
        @AuraEnabled public String mergeStrategy;
        @AuraEnabled public ScopeOptionsDTO scopeOptions;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Integer changedCount;
        @AuraEnabled public List<CategoryCountDTO> categoryCounts;
        @AuraEnabled public List<PlanItemDTO> objectRows;
        @AuraEnabled public List<PlanItemDTO> fieldRows;
        @AuraEnabled public List<PlanItemDTO> systemRows;
        @AuraEnabled public List<PlanItemDTO> tabRows;
        @AuraEnabled public List<PlanItemDTO> setupRows;
    }

    public class ValidationResultDTO {
        @AuraEnabled public Boolean isValid;
        @AuraEnabled public List<String> warnings;
    }

    private class SystemFieldDefinition implements Comparable {
        public String apiName;
        public String label;

        public Integer compareTo(Object otherObject) {
            SystemFieldDefinition otherValue = (SystemFieldDefinition) otherObject;
            String thisSort = ((label == null ? '' : label) + '|' + apiName).toLowerCase();
            String otherSort = ((otherValue.label == null ? '' : otherValue.label) + '|' + otherValue.apiName).toLowerCase();
            if (thisSort == otherSort) {
                return 0;
            }
            return thisSort < otherSort ? -1 : 1;
        }
    }

    @AuraEnabled
    public static MigrationPlanDTO buildPlan(
        Id profileId,
        String targetMode,
        Id targetPermissionSetId,
        String targetPermissionSetName,
        String targetPermissionSetApiName,
        String mergeStrategy,
        String scopeOptionsJson
    ) {
        c23_PermissionStudioSecurity.assertAccess();

        ScopeOptionsDTO scopeOptions = parseScopeOptions(scopeOptionsJson);
        String safeTargetMode = normalizeTargetMode(targetMode);
        String safeMergeStrategy = normalizeMergeStrategy(mergeStrategy);

        Profile profileRecord = loadProfile(profileId);
        PermissionSet sourcePermissionSet = loadSourcePermissionSet(profileRecord.Id);
        PermissionSet targetPermissionSet = loadTargetPermissionSet(safeTargetMode, targetPermissionSetId);

        MigrationPlanDTO plan = new MigrationPlanDTO();
        plan.profileId = profileRecord.Id;
        plan.profileName = profileRecord.Name;
        plan.sourcePermissionSetId = sourcePermissionSet.Id;
        plan.sourcePermissionSetName = String.isBlank(sourcePermissionSet.Label) ? sourcePermissionSet.Name : sourcePermissionSet.Label;
        plan.targetMode = safeTargetMode;
        plan.targetPermissionSetId = targetPermissionSet == null ? null : targetPermissionSet.Id;
        plan.targetPermissionSetName = safeTargetMode == TARGET_MODE_CREATE
            ? targetPermissionSetName
            : (targetPermissionSet == null ? null : (String.isBlank(targetPermissionSet.Label) ? targetPermissionSet.Name : targetPermissionSet.Label));
        plan.targetPermissionSetApiName = safeTargetMode == TARGET_MODE_CREATE
            ? targetPermissionSetApiName
            : (targetPermissionSet == null ? null : targetPermissionSet.Name);
        plan.mergeStrategy = safeMergeStrategy;
        plan.scopeOptions = scopeOptions;

        plan.objectRows = new List<PlanItemDTO>();
        plan.fieldRows = new List<PlanItemDTO>();
        plan.systemRows = new List<PlanItemDTO>();
        plan.tabRows = new List<PlanItemDTO>();
        plan.setupRows = new List<PlanItemDTO>();
        plan.categoryCounts = new List<CategoryCountDTO>();

        Set<String> customObjectApiNames = scopeOptions.includeCustomObjectsOnly == true
            ? getCustomObjectApiNames()
            : new Set<String>();

        if (scopeOptions.includeObjectPermissions == true) {
            buildObjectRows(plan, sourcePermissionSet.Id, targetPermissionSet == null ? null : targetPermissionSet.Id, customObjectApiNames);
        }

        if (scopeOptions.includeFieldPermissions == true) {
            buildFieldRows(plan, sourcePermissionSet.Id, targetPermissionSet == null ? null : targetPermissionSet.Id, customObjectApiNames);
        }

        if (scopeOptions.includeSystemPermissions == true) {
            buildSystemRows(plan, sourcePermissionSet.Id, targetPermissionSet == null ? null : targetPermissionSet.Id);
        }

        if (scopeOptions.includeTabVisibility == true) {
            buildTabRows(plan, sourcePermissionSet.Id, targetPermissionSet == null ? null : targetPermissionSet.Id);
        }

        if (scopeOptions.includeSetupAccess == true) {
            buildSetupRows(plan, sourcePermissionSet.Id, targetPermissionSet == null ? null : targetPermissionSet.Id);
        }

        finalizeCounts(plan);
        return plan;
    }

    @AuraEnabled
    public static ValidationResultDTO validatePlan(String planJson) {
        c23_PermissionStudioSecurity.assertAccess();

        ValidationResultDTO response = new ValidationResultDTO();
        response.isValid = true;
        response.warnings = new List<String>();

        if (String.isBlank(planJson)) {
            response.isValid = false;
            return response;
        }

        MigrationPlanDTO plan = (MigrationPlanDTO) JSON.deserialize(planJson, MigrationPlanDTO.class);
        if (plan == null || plan.changedCount == null || plan.changedCount == 0) {
            response.warnings.add(Label.c23_PS_General_NoPendingChanges);
        }

        if (plan != null && plan.targetMode == TARGET_MODE_CREATE && String.isBlank(plan.targetPermissionSetName)) {
            response.isValid = false;
            response.warnings.add(Label.c23_PS_MIG_Error_TargetName);
        }

        return response;
    }

    public static ScopeOptionsDTO parseScopeOptions(String scopeOptionsJson) {
        ScopeOptionsDTO options = String.isBlank(scopeOptionsJson)
            ? new ScopeOptionsDTO()
            : (ScopeOptionsDTO) JSON.deserialize(scopeOptionsJson, ScopeOptionsDTO.class);

        if (options.includeObjectPermissions == null) {
            options.includeObjectPermissions = true;
        }
        if (options.includeFieldPermissions == null) {
            options.includeFieldPermissions = true;
        }
        if (options.includeSystemPermissions == null) {
            options.includeSystemPermissions = true;
        }
        if (options.includeTabVisibility == null) {
            options.includeTabVisibility = true;
        }
        if (options.includeSetupAccess == null) {
            options.includeSetupAccess = true;
        }
        if (options.includeGrantedOnly == null) {
            options.includeGrantedOnly = true;
        }
        if (options.includeCustomObjectsOnly == null) {
            options.includeCustomObjectsOnly = false;
        }

        return options;
    }

    public static List<String> getSystemPermissionFieldApiNames(Boolean updateableOnly) {
        List<SystemFieldDefinition> fieldDefinitions = getSystemFieldDefinitions(updateableOnly);
        List<String> names = new List<String>();
        for (SystemFieldDefinition fieldDefinition : fieldDefinitions) {
            names.add(fieldDefinition.apiName);
        }
        return names;
    }

    private static void buildObjectRows(MigrationPlanDTO plan, Id sourcePermissionSetId, Id targetPermissionSetId, Set<String> customObjectApiNames) {
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
        if (targetPermissionSetId != null && !objectApiNames.isEmpty()) {
            for (ObjectPermissions targetRow : [
                SELECT SObjectType,
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

        for (ObjectPermissions sourceRow : sourceRows) {
            String objectApiName = sourceRow.SObjectType;
            Boolean isCustom = customObjectApiNames.isEmpty() ? false : customObjectApiNames.contains(objectApiName);
            if (plan.scopeOptions.includeCustomObjectsOnly == true && !isCustom) {
                continue;
            }

            ObjectPermissions targetRow = targetByObject.get(objectApiName);
            addObjectRow(plan.objectRows, plan, objectApiName, 'Read', sourceRow.PermissionsRead, targetRow == null ? false : targetRow.PermissionsRead, isCustom);
            addObjectRow(plan.objectRows, plan, objectApiName, 'Create', sourceRow.PermissionsCreate, targetRow == null ? false : targetRow.PermissionsCreate, isCustom);
            addObjectRow(plan.objectRows, plan, objectApiName, 'Edit', sourceRow.PermissionsEdit, targetRow == null ? false : targetRow.PermissionsEdit, isCustom);
            addObjectRow(plan.objectRows, plan, objectApiName, 'Delete', sourceRow.PermissionsDelete, targetRow == null ? false : targetRow.PermissionsDelete, isCustom);
            addObjectRow(plan.objectRows, plan, objectApiName, 'ViewAll', sourceRow.PermissionsViewAllRecords, targetRow == null ? false : targetRow.PermissionsViewAllRecords, isCustom);
            addObjectRow(plan.objectRows, plan, objectApiName, 'ModifyAll', sourceRow.PermissionsModifyAllRecords, targetRow == null ? false : targetRow.PermissionsModifyAllRecords, isCustom);
        }
    }

    private static void addObjectRow(
        List<PlanItemDTO> rows,
        MigrationPlanDTO plan,
        String objectApiName,
        String permType,
        Boolean sourceValue,
        Boolean targetValue,
        Boolean isCustom
    ) {
        Boolean sourceGranted = sourceValue == true;
        if (plan.scopeOptions.includeGrantedOnly == true && !sourceGranted) {
            return;
        }

        Boolean targetGranted = targetValue == true;
        Boolean resultGranted = resolveBooleanResult(plan, sourceGranted, targetGranted);

        PlanItemDTO row = new PlanItemDTO();
        row.key = 'obj:' + objectApiName + ':' + permType.toLowerCase();
        row.category = CATEGORY_OBJECT;
        row.label = objectApiName + ' ' + permType;
        row.sourceValue = boolText(sourceGranted);
        row.targetValue = boolText(targetGranted);
        row.resultValue = boolText(resultGranted);
        row.hasAccess = resultGranted;
        row.isChanged = resultGranted != targetGranted;
        row.isCustom = isCustom;
        rows.add(row);
    }

    private static void buildFieldRows(MigrationPlanDTO plan, Id sourcePermissionSetId, Id targetPermissionSetId, Set<String> customObjectApiNames) {
        List<FieldPermissions> sourceRows = [
            SELECT Field, PermissionsRead, PermissionsEdit
            FROM FieldPermissions
            WHERE ParentId = :sourcePermissionSetId
            LIMIT 50000
        ];

        Set<String> fieldPaths = new Set<String>();
        for (FieldPermissions sourceRow : sourceRows) {
            if (!String.isBlank(sourceRow.Field)) {
                fieldPaths.add(sourceRow.Field);
            }
        }

        Map<String, FieldPermissions> targetByField = new Map<String, FieldPermissions>();
        if (targetPermissionSetId != null && !fieldPaths.isEmpty()) {
            for (FieldPermissions targetRow : [
                SELECT Field, PermissionsRead, PermissionsEdit
                FROM FieldPermissions
                WHERE ParentId = :targetPermissionSetId
                    AND Field IN :fieldPaths
                LIMIT 50000
            ]) {
                targetByField.put(targetRow.Field, targetRow);
            }
        }

        for (FieldPermissions sourceRow : sourceRows) {
            String fieldPath = sourceRow.Field;
            if (String.isBlank(fieldPath) || !fieldPath.contains('.')) {
                continue;
            }

            String objectApiName = fieldPath.substring(0, fieldPath.indexOf('.'));
            Boolean isCustom = customObjectApiNames.isEmpty() ? false : customObjectApiNames.contains(objectApiName);
            if (plan.scopeOptions.includeCustomObjectsOnly == true && !isCustom) {
                continue;
            }

            FieldPermissions targetRow = targetByField.get(fieldPath);
            addFieldRow(plan.fieldRows, plan, fieldPath, 'Read', sourceRow.PermissionsRead, targetRow == null ? false : targetRow.PermissionsRead, isCustom);
            addFieldRow(plan.fieldRows, plan, fieldPath, 'Edit', sourceRow.PermissionsEdit, targetRow == null ? false : targetRow.PermissionsEdit, isCustom);
        }
    }

    private static void addFieldRow(
        List<PlanItemDTO> rows,
        MigrationPlanDTO plan,
        String fieldPath,
        String permType,
        Boolean sourceValue,
        Boolean targetValue,
        Boolean isCustom
    ) {
        Boolean sourceGranted = sourceValue == true;
        if (plan.scopeOptions.includeGrantedOnly == true && !sourceGranted) {
            return;
        }

        Boolean targetGranted = targetValue == true;
        Boolean resultGranted = resolveBooleanResult(plan, sourceGranted, targetGranted);

        PlanItemDTO row = new PlanItemDTO();
        row.key = 'fld:' + fieldPath + ':' + permType.toLowerCase();
        row.category = CATEGORY_FIELD;
        row.label = fieldPath + ' ' + permType;
        row.sourceValue = boolText(sourceGranted);
        row.targetValue = boolText(targetGranted);
        row.resultValue = boolText(resultGranted);
        row.hasAccess = resultGranted;
        row.isChanged = resultGranted != targetGranted;
        row.isCustom = isCustom;
        rows.add(row);
    }

    private static void buildSystemRows(MigrationPlanDTO plan, Id sourcePermissionSetId, Id targetPermissionSetId) {
        List<SystemFieldDefinition> fields = getSystemFieldDefinitions(true);
        if (fields.isEmpty()) {
            return;
        }

        List<String> apiNames = new List<String>();
        Map<String, SystemFieldDefinition> fieldByApiName = new Map<String, SystemFieldDefinition>();
        for (SystemFieldDefinition fieldDefinition : fields) {
            apiNames.add(fieldDefinition.apiName);
            fieldByApiName.put(fieldDefinition.apiName, fieldDefinition);
        }

        PermissionSet sourceRecord = queryPermissionSetWithFields(sourcePermissionSetId, apiNames);
        PermissionSet targetRecord = targetPermissionSetId == null ? null : queryPermissionSetWithFields(targetPermissionSetId, apiNames);

        for (String fieldApiName : apiNames) {
            Boolean sourceGranted = asBoolean(sourceRecord.get(fieldApiName));
            if (plan.scopeOptions.includeGrantedOnly == true && !sourceGranted) {
                continue;
            }

            Boolean targetGranted = targetRecord == null ? false : asBoolean(targetRecord.get(fieldApiName));
            Boolean resultGranted = resolveBooleanResult(plan, sourceGranted, targetGranted);

            PlanItemDTO row = new PlanItemDTO();
            row.key = 'sys:' + fieldApiName;
            row.category = CATEGORY_SYSTEM;
            row.label = fieldByApiName.get(fieldApiName).label;
            row.sourceValue = boolText(sourceGranted);
            row.targetValue = boolText(targetGranted);
            row.resultValue = boolText(resultGranted);
            row.hasAccess = resultGranted;
            row.isChanged = resultGranted != targetGranted;
            row.isCustom = false;
            plan.systemRows.add(row);
        }
    }

    private static void buildTabRows(MigrationPlanDTO plan, Id sourcePermissionSetId, Id targetPermissionSetId) {
        Map<String, TabDefinition> tabDefinitionByName = new Map<String, TabDefinition>();
        List<TabDefinition> tabDefinitions = [
            SELECT Name, Label, IsCustom
            FROM TabDefinition
            LIMIT 2000
        ];
        for (TabDefinition tabDefinition : tabDefinitions) {
            tabDefinitionByName.put(tabDefinition.Name, tabDefinition);
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
        if (targetPermissionSetId != null) {
            for (PermissionSetTabSetting targetRow : [
                SELECT Name, Visibility
                FROM PermissionSetTabSetting
                WHERE ParentId = :targetPermissionSetId
                    AND Name IN :sourceByName.keySet()
                LIMIT 5000
            ]) {
                targetByName.put(targetRow.Name, targetRow);
            }
        }

        for (String tabName : sourceByName.keySet()) {
            TabDefinition tabDefinition = tabDefinitionByName.get(tabName);
            Boolean isCustom = tabDefinition == null ? false : tabDefinition.IsCustom;
            if (plan.scopeOptions.includeCustomObjectsOnly == true && !isCustom) {
                continue;
            }

            String sourceVisibility = normalizeVisibility(sourceByName.get(tabName).Visibility);
            if (plan.scopeOptions.includeGrantedOnly == true && sourceVisibility == TAB_DEFAULT_OFF) {
                continue;
            }

            String targetVisibility = targetByName.containsKey(tabName)
                ? normalizeVisibility(targetByName.get(tabName).Visibility)
                : TAB_DEFAULT_OFF;
            String resultVisibility = resolveVisibilityResult(plan, sourceVisibility, targetVisibility);

            PlanItemDTO row = new PlanItemDTO();
            row.key = 'tab:' + tabName;
            row.category = CATEGORY_TAB;
            row.label = tabDefinition == null || String.isBlank(tabDefinition.Label) ? tabName : tabDefinition.Label;
            row.sourceValue = sourceVisibility;
            row.targetValue = targetVisibility;
            row.resultValue = resultVisibility;
            row.hasAccess = resultVisibility != TAB_DEFAULT_OFF;
            row.isChanged = resultVisibility != targetVisibility;
            row.isCustom = isCustom;
            plan.tabRows.add(row);
        }
    }

    private static void buildSetupRows(MigrationPlanDTO plan, Id sourcePermissionSetId, Id targetPermissionSetId) {
        Map<String, SetupEntityAccess> sourceByKey = new Map<String, SetupEntityAccess>();
        Set<Id> setupEntityIds = new Set<Id>();
        for (SetupEntityAccess sourceRow : [
            SELECT SetupEntityType, SetupEntityId
            FROM SetupEntityAccess
            WHERE ParentId = :sourcePermissionSetId
                AND SetupEntityType IN :new Set<String>{ SETUP_TYPE_APEX_CLASS, SETUP_TYPE_CUSTOM_PERMISSION }
            LIMIT 50000
        ]) {
            String rowKey = sourceRow.SetupEntityType + ':' + String.valueOf(sourceRow.SetupEntityId);
            sourceByKey.put(rowKey, sourceRow);
            setupEntityIds.add(sourceRow.SetupEntityId);
        }

        if (sourceByKey.isEmpty()) {
            return;
        }

        Map<String, SetupEntityAccess> targetByKey = new Map<String, SetupEntityAccess>();
        if (targetPermissionSetId != null && !setupEntityIds.isEmpty()) {
            for (SetupEntityAccess targetRow : [
                SELECT SetupEntityType, SetupEntityId
                FROM SetupEntityAccess
                WHERE ParentId = :targetPermissionSetId
                    AND SetupEntityType IN :new Set<String>{ SETUP_TYPE_APEX_CLASS, SETUP_TYPE_CUSTOM_PERMISSION }
                    AND SetupEntityId IN :setupEntityIds
                LIMIT 50000
            ]) {
                String rowKey = targetRow.SetupEntityType + ':' + String.valueOf(targetRow.SetupEntityId);
                targetByKey.put(rowKey, targetRow);
            }
        }

        Map<Id, String> setupLabelById = loadSetupLabels(setupEntityIds);
        for (String rowKey : sourceByKey.keySet()) {
            SetupEntityAccess sourceRow = sourceByKey.get(rowKey);
            Boolean sourceGranted = true;
            Boolean targetGranted = targetByKey.containsKey(rowKey);
            Boolean resultGranted = resolveBooleanResult(plan, sourceGranted, targetGranted);

            PlanItemDTO row = new PlanItemDTO();
            row.key = 'setup:' + rowKey;
            row.category = CATEGORY_SETUP;
            row.label = setupLabelById.containsKey(sourceRow.SetupEntityId)
                ? setupLabelById.get(sourceRow.SetupEntityId)
                : String.valueOf(sourceRow.SetupEntityId);
            row.sourceValue = boolText(sourceGranted);
            row.targetValue = boolText(targetGranted);
            row.resultValue = boolText(resultGranted);
            row.hasAccess = resultGranted;
            row.isChanged = resultGranted != targetGranted;
            row.isCustom = false;
            plan.setupRows.add(row);
        }
    }

    private static Map<Id, String> loadSetupLabels(Set<Id> setupEntityIds) {
        Map<Id, String> labelById = new Map<Id, String>();
        if (setupEntityIds == null || setupEntityIds.isEmpty()) {
            return labelById;
        }

        for (ApexClass classRow : [
            SELECT Id, Name
            FROM ApexClass
            WHERE Id IN :setupEntityIds
            LIMIT 50000
        ]) {
            labelById.put(classRow.Id, classRow.Name);
        }

        for (CustomPermission permissionRow : [
            SELECT Id, MasterLabel, DeveloperName
            FROM CustomPermission
            WHERE Id IN :setupEntityIds
            LIMIT 50000
        ]) {
            labelById.put(
                permissionRow.Id,
                String.isBlank(permissionRow.MasterLabel) ? permissionRow.DeveloperName : permissionRow.MasterLabel
            );
        }

        return labelById;
    }

    private static void finalizeCounts(MigrationPlanDTO plan) {
        Integer objectCount = countChanged(plan.objectRows);
        Integer fieldCount = countChanged(plan.fieldRows);
        Integer systemCount = countChanged(plan.systemRows);
        Integer tabCount = countChanged(plan.tabRows);
        Integer setupCount = countChanged(plan.setupRows);

        plan.categoryCounts.add(buildCategoryCount(CATEGORY_OBJECT, objectCount));
        plan.categoryCounts.add(buildCategoryCount(CATEGORY_FIELD, fieldCount));
        plan.categoryCounts.add(buildCategoryCount(CATEGORY_SYSTEM, systemCount));
        plan.categoryCounts.add(buildCategoryCount(CATEGORY_TAB, tabCount));
        plan.categoryCounts.add(buildCategoryCount(CATEGORY_SETUP, setupCount));

        plan.totalCount = safeSize(plan.objectRows) + safeSize(plan.fieldRows) + safeSize(plan.systemRows) + safeSize(plan.tabRows) + safeSize(plan.setupRows);
        plan.changedCount = objectCount + fieldCount + systemCount + tabCount + setupCount;
    }

    private static Integer countChanged(List<PlanItemDTO> rows) {
        Integer countValue = 0;
        for (PlanItemDTO row : rows) {
            if (row != null && row.isChanged == true) {
                countValue++;
            }
        }
        return countValue;
    }

    private static Integer safeSize(List<PlanItemDTO> rows) {
        return rows == null ? 0 : rows.size();
    }

    private static CategoryCountDTO buildCategoryCount(String category, Integer countValue) {
        CategoryCountDTO row = new CategoryCountDTO();
        row.category = category;
        row.count = countValue == null ? 0 : countValue;
        return row;
    }

    private static Boolean resolveBooleanResult(MigrationPlanDTO plan, Boolean sourceValue, Boolean targetValue) {
        Boolean sourceGranted = sourceValue == true;
        Boolean targetGranted = targetValue == true;
        if (plan.targetMode == TARGET_MODE_CREATE) {
            return sourceGranted;
        }
        if (plan.mergeStrategy == MERGE_STRATEGY_OVERWRITE) {
            return sourceGranted;
        }
        return sourceGranted || targetGranted;
    }

    private static String resolveVisibilityResult(MigrationPlanDTO plan, String sourceVisibility, String targetVisibility) {
        if (plan.targetMode == TARGET_MODE_CREATE) {
            return sourceVisibility;
        }
        if (plan.mergeStrategy == MERGE_STRATEGY_OVERWRITE) {
            return sourceVisibility;
        }
        if (sourceVisibility == TAB_DEFAULT_OFF) {
            return targetVisibility;
        }
        return sourceVisibility;
    }

    private static String boolText(Boolean value) {
        return value == true ? Label.c23_PS_General_Yes : Label.c23_PS_General_No;
    }

    private static Boolean asBoolean(Object value) {
        return value != null && (Boolean) value;
    }

    private static PermissionSet queryPermissionSetWithFields(Id permissionSetId, List<String> fieldApiNames) {
        List<String> safeFieldApiNames = fieldApiNames == null ? new List<String>() : new List<String>(fieldApiNames);
        safeFieldApiNames.sort();

        String soql = 'SELECT Id';
        if (!safeFieldApiNames.isEmpty()) {
            soql += ',' + String.join(safeFieldApiNames, ',');
        }
        soql += ' FROM PermissionSet WHERE Id = :permissionSetId LIMIT 1';

        List<SObject> records = Database.query(soql);
        return records.isEmpty() ? null : (PermissionSet) records[0];
    }

    private static List<SystemFieldDefinition> getSystemFieldDefinitions(Boolean updateableOnly) {
        List<SystemFieldDefinition> definitions = new List<SystemFieldDefinition>();
        Map<String, Schema.SObjectField> allFields = PermissionSet.SObjectType.getDescribe().fields.getMap();
        for (String fieldApiName : allFields.keySet()) {
            if (String.isBlank(fieldApiName) || !fieldApiName.toLowerCase().startsWith(SYSTEM_PERMISSION_PREFIX)) {
                continue;
            }
            Schema.DescribeFieldResult describeField = allFields.get(fieldApiName).getDescribe();
            if (describeField.getType() != Schema.DisplayType.Boolean) {
                continue;
            }
            if (updateableOnly == true && !describeField.isUpdateable()) {
                continue;
            }

            SystemFieldDefinition definition = new SystemFieldDefinition();
            definition.apiName = fieldApiName;
            definition.label = describeField.getLabel();
            definitions.add(definition);
        }
        definitions.sort();
        return definitions;
    }

    private static String normalizeVisibility(String visibilityValue) {
        if (visibilityValue == 'DefaultOn' || visibilityValue == 'DefaultOff' || visibilityValue == 'Hidden') {
            return visibilityValue;
        }
        return TAB_DEFAULT_OFF;
    }

    private static Set<String> getCustomObjectApiNames() {
        Set<String> customNames = new Set<String>();
        for (c23_SchemaService.SObjectCatalogRow row : c23_SchemaService.getSObjectCatalog()) {
            if (row.isCustom == true) {
                customNames.add(row.apiName);
            }
        }
        return customNames;
    }

    private static Profile loadProfile(Id profileId) {
        if (profileId == null) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_MIG_Error_InvalidProfile);
        }
        List<Profile> profiles = [
            SELECT Id, Name
            FROM Profile
            WHERE Id = :profileId
            LIMIT 1
        ];
        if (profiles.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_MIG_Error_InvalidProfile);
        }
        return profiles[0];
    }

    private static PermissionSet loadSourcePermissionSet(Id profileId) {
        List<PermissionSet> permissionSets = [
            SELECT Id, Name, Label
            FROM PermissionSet
            WHERE ProfileId = :profileId
                AND IsOwnedByProfile = true
            LIMIT 1
        ];
        if (permissionSets.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_MIG_Error_InvalidProfileSource);
        }
        return permissionSets[0];
    }

    private static PermissionSet loadTargetPermissionSet(String targetMode, Id targetPermissionSetId) {
        if (targetMode == TARGET_MODE_CREATE) {
            return null;
        }

        if (targetPermissionSetId == null) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_MIG_Error_TargetMergeSelection);
        }

        List<PermissionSet> permissionSets = [
            SELECT Id, Name, Label
            FROM PermissionSet
            WHERE Id = :targetPermissionSetId
            LIMIT 1
        ];
        if (permissionSets.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_MIG_Error_TargetMergeSelection);
        }
        return permissionSets[0];
    }

    private static String normalizeTargetMode(String targetMode) {
        if (targetMode == TARGET_MODE_CREATE || targetMode == TARGET_MODE_MERGE) {
            return targetMode;
        }
        return TARGET_MODE_CREATE;
    }

    private static String normalizeMergeStrategy(String mergeStrategy) {
        if (mergeStrategy == MERGE_STRATEGY_OVERWRITE || mergeStrategy == MERGE_STRATEGY_UNION) {
            return mergeStrategy;
        }
        return MERGE_STRATEGY_UNION;
    }
}