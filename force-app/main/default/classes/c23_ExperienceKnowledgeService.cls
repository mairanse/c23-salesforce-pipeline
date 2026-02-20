public with sharing class c23_ExperienceKnowledgeService {
    @AuraEnabled(cacheable=true)
    public static String ping() { return 'ok'; }
}
