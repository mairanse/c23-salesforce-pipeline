public with sharing class c23_PermissionStudioUserSettingsService {
    private static final String DENSITY_KEY = 'tableDensity';
    private static final String DENSITY_COMFORTABLE = 'comfortable';
    private static final String DENSITY_COMPACT = 'compact';
    private static final Integer SETTINGS_FIELD_MAX_LENGTH = 4000;

    public class UserSettingsDTO {
        @AuraEnabled public String tableDensity;
    }

    @AuraEnabled(cacheable=true)
    public static UserSettingsDTO getUserSettings() {
        c23_PermissionStudioSecurity.assertAccess();
        User currentUser = getCurrentUserForRead();
        Map<String, Object> settingsMap = parseSettingsMap(currentUser.c23_PS_UserSettings__c);
        return buildResponse(settingsMap);
    }

    @AuraEnabled
    public static UserSettingsDTO saveUserSettings(UserSettingsDTO settings) {
        c23_PermissionStudioSecurity.assertAccess();
        User currentUser = getCurrentUserForRead();
        Map<String, Object> settingsMap = parseSettingsMap(currentUser.c23_PS_UserSettings__c);
        settingsMap.put(DENSITY_KEY, normalizeDensity(settings == null ? null : settings.tableDensity));

        String serialized = JSON.serialize(settingsMap);
        if (serialized != null && serialized.length() > SETTINGS_FIELD_MAX_LENGTH) {
            Map<String, Object> reducedMap = new Map<String, Object>();
            reducedMap.put(DENSITY_KEY, normalizeDensity(settings == null ? null : settings.tableDensity));
            serialized = JSON.serialize(reducedMap);
        }

        persistSettingsJson(serialized);
        return buildResponse(parseSettingsMap(serialized));
    }

    private static User getCurrentUserForRead() {
        List<User> queriedUsers = [
            SELECT Id, c23_PS_UserSettings__c
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

    private static void persistSettingsJson(String settingsJson) {
        User updateRecord = new User(
            Id = UserInfo.getUserId(),
            c23_PS_UserSettings__c = settingsJson
        );

        SObjectAccessDecision decision = Security.stripInaccessible(
            System.AccessType.UPDATABLE,
            new List<SObject>{ updateRecord }
        );
        assertNoStrippedFields(decision);
        update (User) decision.getRecords()[0];
    }

    private static Map<String, Object> parseSettingsMap(String rawValue) {
        Map<String, Object> settingsMap = new Map<String, Object>();
        if (String.isBlank(rawValue)) {
            return settingsMap;
        }

        Object parsed;
        try {
            parsed = JSON.deserializeUntyped(rawValue);
        } catch (Exception ex) {
            c23_ErrorLogService.logWarning(
                'UserSettings.parseSettingsMap',
                ex.getMessage(),
                'Unable to parse user settings JSON payload.',
                null
            );
            return settingsMap;
        }

        if (!(parsed instanceof Map<String, Object>)) {
            return settingsMap;
        }
        return (Map<String, Object>) parsed;
    }

    private static UserSettingsDTO buildResponse(Map<String, Object> settingsMap) {
        UserSettingsDTO response = new UserSettingsDTO();
        response.tableDensity = normalizeDensity(asString(settingsMap == null ? null : settingsMap.get(DENSITY_KEY)));
        return response;
    }

    private static String normalizeDensity(String rawDensity) {
        String normalized = rawDensity == null ? '' : rawDensity.trim().toLowerCase();
        if (normalized == DENSITY_COMPACT) {
            return DENSITY_COMPACT;
        }
        return DENSITY_COMFORTABLE;
    }

    private static String asString(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static void assertNoStrippedFields(SObjectAccessDecision decision) {
        Map<String, Set<String>> removedFields = decision == null ? null : decision.getRemovedFields();
        if (removedFields != null && !removedFields.isEmpty()) {
            throw c23_PermissionStudioSecurity.handled(Label.c23_PS_General_AccessDenied);
        }
    }
}