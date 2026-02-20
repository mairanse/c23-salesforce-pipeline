public with sharing class c23_ExperienceContentService {
    public class ContentItem {
        @AuraEnabled public String key;
        @AuraEnabled public String contentType;
        @AuraEnabled public String audience;
        @AuraEnabled public String title;
        @AuraEnabled public String message;
        @AuraEnabled public String subhead;
        @AuraEnabled public String imageUrl;
        @AuraEnabled public String primaryLabel;
        @AuraEnabled public String primaryUrl;
        @AuraEnabled public String secondaryLabel;
        @AuraEnabled public String secondaryUrl;
        @AuraEnabled public Integer priority;
        @AuraEnabled public Datetime startAt;
        @AuraEnabled public Datetime endAt;
    }

    @AuraEnabled(cacheable=true)
    public static ContentItem getAnnouncement(String routeKey) {
        List<ContentItem> items = getContentByType('Announcement', routeKey);
        return items.isEmpty() ? null : items[0];
    }

    @AuraEnabled(cacheable=true)
    public static ContentItem getSmartCta(String routeKey) {
        List<ContentItem> items = getContentByType('CTA', routeKey);
        return items.isEmpty() ? null : items[0];
    }

    @AuraEnabled
    public static Boolean logCtaClick(String contentKey, String targetUrl) {
        System.debug(LoggingLevel.INFO,
            'c23 CTA click => key=' + contentKey + ', targetUrl=' + targetUrl + ', user=' + UserInfo.getUserId()
        );
        return true;
    }

    @AuraEnabled(cacheable=true)
    public static List<ContentItem> getHeroVariants(String routeKey) {
        return getContentByType('Hero', routeKey);
    }

    private static List<ContentItem> getContentByType(String contentType, String routeKey) {
        Datetime nowValue = System.now();
        Boolean isGuest = UserInfo.getUserType() == 'Guest';
        String normalizedRoute = String.isBlank(routeKey) ? '' : routeKey.trim().toLowerCase();

        List<ContentItem> items = new List<ContentItem>();
        for (c23_Experience_Content_Config__mdt row : [
            SELECT DeveloperName,
                c23_ContentType__c,
                c23_Audience__c,
                c23_Title__c,
                c23_Message__c,
                c23_Subhead__c,
                c23_ImageUrl__c,
                c23_PrimaryLabel__c,
                c23_PrimaryUrl__c,
                c23_SecondaryLabel__c,
                c23_SecondaryUrl__c,
                c23_Priority__c,
                c23_IsActive__c,
                c23_StartAt__c,
                c23_EndAt__c,
                c23_RoutePattern__c
            FROM c23_Experience_Content_Config__mdt
            WHERE c23_ContentType__c = :contentType
            ORDER BY c23_Priority__c DESC, DeveloperName ASC
        ]) {
            if (!row.c23_IsActive__c) {
                continue;
            }
            if (!isInSchedule(row.c23_StartAt__c, row.c23_EndAt__c, nowValue)) {
                continue;
            }
            if (!matchesAudience(row.c23_Audience__c, isGuest)) {
                continue;
            }
            if (!matchesRoute(row.c23_RoutePattern__c, normalizedRoute)) {
                continue;
            }

            ContentItem item = new ContentItem();
            item.key = row.DeveloperName;
            item.contentType = row.c23_ContentType__c;
            item.audience = row.c23_Audience__c;
            item.title = row.c23_Title__c;
            item.message = row.c23_Message__c;
            item.subhead = row.c23_Subhead__c;
            item.imageUrl = row.c23_ImageUrl__c;
            item.primaryLabel = row.c23_PrimaryLabel__c;
            item.primaryUrl = row.c23_PrimaryUrl__c;
            item.secondaryLabel = row.c23_SecondaryLabel__c;
            item.secondaryUrl = row.c23_SecondaryUrl__c;
            item.priority = row.c23_Priority__c == null ? 0 : Integer.valueOf(row.c23_Priority__c);
            item.startAt = row.c23_StartAt__c;
            item.endAt = row.c23_EndAt__c;
            items.add(item);
        }

        return items;
    }

    private static Boolean matchesAudience(String audience, Boolean isGuest) {
        if (String.isBlank(audience) || audience == 'All') {
            return true;
        }
        if (audience == 'Guest') {
            return isGuest;
        }
        if (audience == 'Authenticated') {
            return !isGuest;
        }
        return true;
    }

    private static Boolean matchesRoute(String routePattern, String routeKey) {
        if (String.isBlank(routePattern)) {
            return true;
        }
        String normalizedPattern = routePattern.trim().toLowerCase();
        if (normalizedPattern == '*') {
            return true;
        }
        if (String.isBlank(routeKey)) {
            return false;
        }
        return routeKey.contains(normalizedPattern);
    }

    private static Boolean isInSchedule(Datetime startAt, Datetime endAt, Datetime nowValue) {
        if (startAt != null && nowValue < startAt) {
            return false;
        }
        if (endAt != null && nowValue > endAt) {
            return false;
        }
        return true;
    }
}
