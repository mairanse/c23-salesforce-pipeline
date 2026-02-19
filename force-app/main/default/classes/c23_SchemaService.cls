public with sharing class c23_SchemaService {
    @TestVisible
    private static Set<String> permissionableObjectOverride;

    public class SObjectCatalogRow implements Comparable {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean isCustom;

        public Integer compareTo(Object otherObject) {
            SObjectCatalogRow otherRow = (SObjectCatalogRow) otherObject;
            String thisSortValue = ((label == null ? '' : label) + '|' + apiName).toLowerCase();
            String otherSortValue = ((otherRow.label == null ? '' : otherRow.label) + '|' + otherRow.apiName).toLowerCase();
            if (thisSortValue == otherSortValue) {
                return 0;
            }
            return thisSortValue < otherSortValue ? -1 : 1;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<SObjectCatalogRow> getSObjectCatalog() {
        c23_PermissionStudioSecurity.assertAccess();

        List<SObjectCatalogRow> rows = new List<SObjectCatalogRow>();
        Map<String, Schema.SObjectType> describeMap = Schema.getGlobalDescribe();
        Set<String> permissionableObjectApiNames = getPermissionableObjectApiNames();

        if (permissionableObjectApiNames.isEmpty()) {
            return rows;
        }

        for (String apiName : permissionableObjectApiNames) {
            Schema.SObjectType objectType = describeMap.get(apiName);
            if (objectType == null) {
                continue;
            }

            Schema.DescribeSObjectResult describeResult = objectType.getDescribe();

            if (describeResult.isDeprecatedAndHidden() || describeResult.isCustomSetting()) {
                continue;
            }

            SObjectCatalogRow row = new SObjectCatalogRow();
            row.apiName = apiName;
            row.label = describeResult.getLabel();
            row.isCustom = describeResult.isCustom();
            rows.add(row);
        }

        rows.sort();
        return rows;
    }

    private static Set<String> getPermissionableObjectApiNames() {
        if (Test.isRunningTest() && permissionableObjectOverride != null) {
            return new Set<String>(permissionableObjectOverride);
        }

        Set<String> apiNames = new Set<String>();
        for (AggregateResult aggregateResult : [
            SELECT SObjectType objectApiName
            FROM ObjectPermissions
            GROUP BY SObjectType
        ]) {
            String objectApiName = (String) aggregateResult.get('objectApiName');
            if (!String.isBlank(objectApiName)) {
                apiNames.add(objectApiName);
            }
        }

        return apiNames;
    }
}