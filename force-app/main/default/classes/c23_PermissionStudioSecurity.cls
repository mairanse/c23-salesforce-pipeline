public with sharing class c23_PermissionStudioSecurity {
    public static final String ACCESS_PERMISSION = 'c23_PermissionStudio_Access';
    private static final String CONTEXT_VALIDATE_PERMISSION_SET = 'Security.validatePermissionSet';

    public static void assertAccess() {
        if (!FeatureManagement.checkPermission(ACCESS_PERMISSION)) {
            throw handled(Label.c23_PS_General_AccessDenied);
        }
    }

    public static PermissionSet validatePermissionSet(Id permissionSetId) {
        return validatePermissionSet(permissionSetId, null);
    }

    public static PermissionSet validatePermissionSet(Id permissionSetId, String context) {
        String errorContext = String.isBlank(context) ? CONTEXT_VALIDATE_PERMISSION_SET : context.trim();
        if (permissionSetId == null) {
            throw handled(
                Label.c23_PS_Error_InvalidPermissionSet,
                errorContext,
                buildInvalidPermissionSetDetails(null, false),
                null
            );
        }

        List<PermissionSet> permissionSets = [
            SELECT Id, Name, Label, IsOwnedByProfile
            FROM PermissionSet
            WHERE Id = :permissionSetId
            LIMIT 1
        ];

        if (permissionSets.isEmpty()) {
            throw handled(
                Label.c23_PS_Error_InvalidPermissionSet,
                errorContext,
                buildInvalidPermissionSetDetails(permissionSetId, true),
                permissionSetId
            );
        }

        return permissionSets[0];
    }

    public static AuraHandledException handled(String messageText) {
        return handled(messageText, null, null, null);
    }

    public static AuraHandledException handled(String messageText, String context, String detailsJson, Id recordId) {
        String safeMessage = String.isBlank(messageText) ? Label.c23_PS_General_Error : messageText;
        c23_ErrorLogService.logHandled(safeMessage, context, detailsJson, recordId);
        AuraHandledException ex = new AuraHandledException(safeMessage);
        ex.setMessage(safeMessage);
        return ex;
    }

    private static String buildInvalidPermissionSetDetails(Id permissionSetId, Boolean notFound) {
        Map<String, Object> details = new Map<String, Object>();
        details.put('permissionSetId', permissionSetId == null ? null : String.valueOf(permissionSetId));
        details.put('notFound', notFound == true);
        return JSON.serialize(details);
    }
}