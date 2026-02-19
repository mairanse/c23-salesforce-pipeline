public with sharing class c23_PermissionStudioTabPermService {
    private static final Integer PREVIEW_SAMPLE_LIMIT = 25;
    private static final String VISIBILITY_DEFAULT_ON = 'DefaultOn';
    private static final String VISIBILITY_DEFAULT_OFF = 'DefaultOff';
    private static final String VISIBILITY_HIDDEN = 'Hidden';

    public class TabPermRow implements Comparable {
        @AuraEnabled public String tabName;
        @AuraEnabled public String tabLabel;
        @AuraEnabled public Boolean isCustom;
        @AuraEnabled public String visibility;
        @AuraEnabled public String currentVisibility;

        public Integer compareTo(Object otherObject) {
            TabPermRow otherValue = (TabPermRow) otherObject;
            String thisSort = ((tabLabel == null ? '' : tabLabel) + '|' + tabName).toLowerCase();
            String otherSort = ((otherValue.tabLabel == null ? '' : otherValue.tabLabel) + '|' + otherValue.tabName).toLowerCase();
            if (thisSort == otherSort) {
                return 0;
            }
            return thisSort < otherSort ? -1 : 1;
        }
    }

    public class DesiredTabPermRow {
        @AuraEnabled public String tabName;
        @AuraEnabled public String visibility;
    }

    public class DiffSampleRow {
        @AuraEnabled public String key;
        @AuraEnabled public String beforeJson;
        @AuraEnabled public String afterJson;
    }

    public class PreviewResponse {
        @AuraEnabled public Integer changedCount;
        @AuraEnabled public Integer insertCount;
        @AuraEnabled public Integer updateCount;
        @AuraEnabled public Integer totalRequestedCount;
        @AuraEnabled public Boolean hasChanges;
        @AuraEnabled public List<DiffSampleRow> sampleRows;
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

    private class TabCatalogRow {
        public String tabName;
        public String tabLabel;
        public Boolean isCustom;
    }

    private class ChangeComputationResult {
        public PermissionSet permissionSetRecord;
        public Integer totalRequestedCount = 0;
        public Integer insertCount = 0;
        public Integer updateCount = 0;
        public Integer changedCount = 0;
        public List<PermissionSetTabSetting> toInsert = new List<PermissionSetTabSetting>();
        public List<PermissionSetTabSetting> toUpdate = new List<PermissionSetTabSetting>();
        public List<DiffSampleRow> previewSamples = new List<DiffSampleRow>();
        public List<c23_PermissionStudioLedgerService.LedgerItemPayload> ledgerItems =
            new List<c23_PermissionStudioLedgerService.LedgerItemPayload>();
    }

    @AuraEnabled
    public static List<TabPermRow> getTabVisibilityMatrix(Id parentPermissionSetId) {
        c23_PermissionStudioSecurity.assertAccess();
        PermissionSet permissionSetRecord = c23_PermissionStudioSecurity.validatePermissionSet(
            parentPermissionSetId,
            'TabPerm.getTabVisibilityMatrix'
        );

        Map<String, TabCatalogRow> tabCatalogByName = buildTabCatalogByName();
        if (tabCatalogByName.isEmpty()) {
            return new List<TabPermRow>();
        }

        Map<String, PermissionSetTabSetting> existingByName = new Map<String, PermissionSetTabSetting>();
        for (PermissionSetTabSetting existing : [
            SELECT Id, Name, Visibility
            FROM PermissionSetTabSetting
            WHERE ParentId = :permissionSetRecord.Id
                AND Name IN :tabCatalogByName.keySet()
        ]) {
            existingByName.put(existing.Name, existing);
        }

        List<TabPermRow> rows = new List<TabPermRow>();
        for (String tabName : tabCatalogByName.keySet()) {
            TabCatalogRow catalogRow = tabCatalogByName.get(tabName);
            PermissionSetTabSetting existing = existingByName.get(tabName);
            String currentVisibility = existing == null ? VISIBILITY_DEFAULT_OFF : normalizeVisibility(existing.Visibility);

            TabPermRow row = new TabPermRow();
            row.tabName = tabName;
            row.tabLabel = catalogRow.tabLabel;
            row.isCustom = catalogRow.isCustom;
            row.visibility = currentVisibility;
            row.currentVisibility = currentVisibility;
            rows.add(row);
        }

        rows.sort();
        return rows;
    }

    @AuraEnabled
    public static PreviewResponse previewApplyTabVisibility(
        Id parentPermissionSetId,
        List<DesiredTabPermRow> desiredStateRows
    ) {
        c23_PermissionStudioSecurity.assertAccess();
        ChangeComputationResult result = computeChanges(parentPermissionSetId, desiredStateRows);

        PreviewResponse response = new PreviewResponse();
        response.changedCount = result.changedCount;
        response.insertCount = result.insertCount;
        response.updateCount = result.updateCount;
        response.totalRequestedCount = result.totalRequestedCount;
        response.hasChanges = result.changedCount > 0;
        response.sampleRows = result.previewSamples;
        return response;
    }

    @AuraEnabled
    public static ApplyResponse applyTabVisibility(
        Id parentPermissionSetId,
        List<DesiredTabPermRow> desiredStateRows,
        String changeNote
    ) {
        c23_PermissionStudioSecurity.assertAccess();
        ChangeComputationResult result;
        try {
            result = computeChanges(parentPermissionSetId, desiredStateRows);
        } catch (AuraHandledException ex) {
            if (ex.getMessage() == Label.c23_PS_Error_NoDesiredRows) {
                return buildNoChangeResponse(0);
            }
            throw ex;
        }

        if (result.changedCount == 0) {
            return buildNoChangeResponse(result.totalRequestedCount);
        }

        if (!result.toInsert.isEmpty()) {
            insert result.toInsert;
        }

        if (!result.toUpdate.isEmpty()) {
            update result.toUpdate;
        }

        c23_PermissionStudioLedgerService.LedgerWriteResult ledgerResult =
            c23_PermissionStudioLedgerService.writeChangeSafe(
                'PermissionSet',
                result.permissionSetRecord.Id,
                result.permissionSetRecord.Label,
                Label.c23_PS_Tab_Title,
                changeNote,
                result.totalRequestedCount,
                result.insertCount,
                result.updateCount,
                result.ledgerItems
            );

        ApplyResponse response = new ApplyResponse();
        response.changedCount = result.changedCount;
        response.insertCount = result.insertCount;
        response.updateCount = result.updateCount;
        response.totalRequestedCount = result.totalRequestedCount;
        response.ledgerId = ledgerResult.headerId;
        response.ledgerTruncated = ledgerResult.isTruncated;
        response.ledgerStoredItemCount = ledgerResult.storedItemCount;
        response.ledgerTotalItemCount = ledgerResult.totalItemCount;
        response.message = Label.c23_PS_Tab_ApplySuccess;
        return response;
    }

    private static ChangeComputationResult computeChanges(
        Id parentPermissionSetId,
        List<DesiredTabPermRow> desiredStateRows
    ) {
        ChangeComputationResult result = new ChangeComputationResult();
        result.permissionSetRecord = c23_PermissionStudioSecurity.validatePermissionSet(
            parentPermissionSetId,
            'TabPerm.computeChanges'
        );

        if (desiredStateRows == null || desiredStateRows.isEmpty()) {
            return result;
        }

        Map<String, TabCatalogRow> tabCatalogByName = buildTabCatalogByName();
        if (tabCatalogByName.isEmpty()) {
            return result;
        }

        Map<String, String> desiredByTab = new Map<String, String>();
        for (DesiredTabPermRow desiredRow : desiredStateRows) {
            if (desiredRow == null || String.isBlank(desiredRow.tabName)) {
                continue;
            }

            String tabName = desiredRow.tabName.trim();
            if (!tabCatalogByName.containsKey(tabName)) {
                continue;
            }

            desiredByTab.put(tabName, normalizeVisibility(desiredRow.visibility));
        }

        if (desiredByTab.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(
                Label.c23_PS_Error_InvalidDesiredRows,
                'TabPerm.computeChanges',
                buildInvalidDesiredRowsDetails(result.permissionSetRecord.Id, desiredStateRows, tabCatalogByName, desiredByTab),
                result.permissionSetRecord.Id
            );
        }

        result.totalRequestedCount = desiredByTab.size();

        Map<String, PermissionSetTabSetting> existingByName = new Map<String, PermissionSetTabSetting>();
        for (PermissionSetTabSetting existing : [
            SELECT Id, Name, Visibility
            FROM PermissionSetTabSetting
            WHERE ParentId = :result.permissionSetRecord.Id
                AND Name IN :desiredByTab.keySet()
        ]) {
            existingByName.put(existing.Name, existing);
        }

        for (String tabName : desiredByTab.keySet()) {
            String afterVisibility = desiredByTab.get(tabName);
            PermissionSetTabSetting existing = existingByName.get(tabName);
            String beforeVisibility = existing == null ? VISIBILITY_DEFAULT_OFF : normalizeVisibility(existing.Visibility);
            if (beforeVisibility == afterVisibility) {
                continue;
            }

            if (existing == null) {
                if (afterVisibility != VISIBILITY_DEFAULT_OFF) {
                    PermissionSetTabSetting toCreate = new PermissionSetTabSetting();
                    toCreate.ParentId = result.permissionSetRecord.Id;
                    toCreate.Name = tabName;
                    toCreate.Visibility = afterVisibility;
                    result.toInsert.add(toCreate);
                    result.insertCount++;
                }
            } else {
                existing.Visibility = afterVisibility;
                result.toUpdate.add(existing);
                result.updateCount++;
            }

            result.changedCount++;

            c23_PermissionStudioLedgerService.LedgerItemPayload ledgerItem =
                new c23_PermissionStudioLedgerService.LedgerItemPayload();
            ledgerItem.itemKey = tabName;
            ledgerItem.beforeJson = toVisibilityJson(beforeVisibility);
            ledgerItem.afterJson = toVisibilityJson(afterVisibility);
            result.ledgerItems.add(ledgerItem);

            if (result.previewSamples.size() < PREVIEW_SAMPLE_LIMIT) {
                DiffSampleRow sample = new DiffSampleRow();
                sample.key = tabName;
                sample.beforeJson = ledgerItem.beforeJson;
                sample.afterJson = ledgerItem.afterJson;
                result.previewSamples.add(sample);
            }
        }

        return result;
    }

    private static ApplyResponse buildNoChangeResponse(Integer totalRequestedCount) {
        ApplyResponse response = new ApplyResponse();
        response.changedCount = 0;
        response.insertCount = 0;
        response.updateCount = 0;
        response.totalRequestedCount = totalRequestedCount == null ? 0 : totalRequestedCount;
        response.ledgerId = null;
        response.ledgerTruncated = false;
        response.ledgerStoredItemCount = 0;
        response.ledgerTotalItemCount = 0;
        response.message = Label.c23_PS_General_NoPendingChanges;
        return response;
    }

    private static String buildInvalidDesiredRowsDetails(
        Id permissionSetId,
        List<DesiredTabPermRow> desiredStateRows,
        Map<String, TabCatalogRow> tabCatalogByName,
        Map<String, String> desiredByTab
    ) {
        Map<String, Object> details = new Map<String, Object>();
        details.put('permissionSetId', permissionSetId == null ? null : String.valueOf(permissionSetId));
        details.put('incomingCount', desiredStateRows == null ? 0 : desiredStateRows.size());
        details.put('catalogCount', tabCatalogByName == null ? 0 : tabCatalogByName.size());
        details.put('acceptedCount', desiredByTab == null ? 0 : desiredByTab.size());

        List<String> incomingSample = new List<String>();
        if (desiredStateRows != null) {
            for (DesiredTabPermRow row : desiredStateRows) {
                if (row == null || String.isBlank(row.tabName)) {
                    continue;
                }
                incomingSample.add(row.tabName.trim());
                if (incomingSample.size() >= 25) {
                    break;
                }
            }
        }
        details.put('incomingTabSample', incomingSample);

        return JSON.serialize(details);
    }

    private static Map<String, TabCatalogRow> buildTabCatalogByName() {
        Map<String, TabCatalogRow> response = new Map<String, TabCatalogRow>();

        List<TabDefinition> tabDefinitions = [
            SELECT Name, Label, IsCustom
            FROM TabDefinition
            ORDER BY Label, Name
            LIMIT 2000
        ];

        for (TabDefinition tabDefinition : tabDefinitions) {
            if (String.isBlank(tabDefinition.Name)) {
                continue;
            }

            TabCatalogRow row = new TabCatalogRow();
            row.tabName = tabDefinition.Name;
            row.tabLabel = tabDefinition.Label;
            row.isCustom = tabDefinition.IsCustom;
            response.put(tabDefinition.Name, row);
        }

        return response;
    }

    private static String normalizeVisibility(String visibilityValue) {
        if (visibilityValue == VISIBILITY_DEFAULT_ON || visibilityValue == VISIBILITY_DEFAULT_OFF || visibilityValue == VISIBILITY_HIDDEN) {
            return visibilityValue;
        }
        return VISIBILITY_DEFAULT_OFF;
    }

    private static String toVisibilityJson(String visibilityValue) {
        Map<String, Object> valueMap = new Map<String, Object>();
        valueMap.put('visibility', normalizeVisibility(visibilityValue));
        return JSON.serialize(valueMap);
    }
}