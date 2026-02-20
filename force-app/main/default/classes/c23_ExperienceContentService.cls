public with sharing class c23_ExperienceContentService {
    @AuraEnabled(cacheable=true)
    public static String ping() { return 'ok'; }
}
