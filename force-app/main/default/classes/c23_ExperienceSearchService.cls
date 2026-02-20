public with sharing class c23_ExperienceSearchService {
    @AuraEnabled(cacheable=true)
    public static String ping() { return 'ok'; }
}
