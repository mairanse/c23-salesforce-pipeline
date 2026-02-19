public with sharing class c23_UserPermissionSummaryService {
    @AuraEnabled(cacheable=true)
    public static String ping() {
        return 'ok';
    }
}
