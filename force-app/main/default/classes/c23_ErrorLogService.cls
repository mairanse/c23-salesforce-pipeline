public without sharing class c23_ErrorLogService {
    private static final Integer MAX_SHORT_TEXT = 255;
    private static final Integer MAX_ID_TEXT = 18;
    private static final Integer MAX_LONG_TEXT = 32768;

    private static final String SEVERITY_INFO = 'Info';
    private static final String SEVERITY_WARN = 'Warn';
    private static final String SEVERITY_ERROR = 'Error';
    private static final String SEVERITY_FATAL = 'Fatal';

    @TestVisible
    private static Boolean loggingDisabled = false;

    public static void logHandled(String messageText, String context, String detailsJson, Id recordId) {
        logInternal(SEVERITY_ERROR, messageText, context, null, null, detailsJson, recordId);
    }

    public static void logWarning(String context, String messageText, String detailsJson, Id recordId) {
        logInternal(SEVERITY_WARN, messageText, context, null, null, detailsJson, recordId);
    }

    public static void logException(String context, Exception ex, String detailsJson, Id recordId) {
        String messageText = ex == null ? null : ex.getMessage();
        String stackTrace = ex == null ? null : ex.getStackTraceString();
        String exceptionType = ex == null ? null : ex.getTypeName();
        logInternal(SEVERITY_ERROR, messageText, context, exceptionType, stackTrace, detailsJson, recordId);
    }

    private static void logInternal(
        String severity,
        String messageText,
        String context,
        String exceptionType,
        String stackTrace,
        String detailsJson,
        Id recordId
    ) {
        if (loggingDisabled) {
            return;
        }

        if (Limits.getDmlStatements() >= Limits.getLimitDmlStatements()) {
            return;
        }

        try {
            String safeSeverity = normalizeSeverity(severity);
            String safeMessage = clipLong(messageText);
            String safeContext = clipShort(String.isBlank(context) ? deriveContextFromStack(stackTrace) : context);
            String safeExceptionType = clipShort(exceptionType);
            String safeStackTrace = clipLong(stackTrace);
            String safeDetailsJson = clipLong(detailsJson);
            String safeUserId = clipId(UserInfo.getUserId());
            String safeRecordId = recordId == null ? null : clipId(String.valueOf(recordId));

            // Test context keeps synchronous writes so tests can assert rows deterministically.
            if (Test.isRunningTest()) {
                insertLogRow(
                    safeSeverity,
                    safeMessage,
                    safeContext,
                    safeExceptionType,
                    safeStackTrace,
                    safeDetailsJson,
                    safeUserId,
                    safeRecordId
                );
                return;
            }

            // Use PublishImmediately platform event so logs persist even when the caller transaction rolls back.
            Boolean published = publishLogEvent(
                safeSeverity,
                safeMessage,
                safeContext,
                safeExceptionType,
                safeStackTrace,
                safeDetailsJson,
                safeUserId,
                safeRecordId
            );
            if (!published) {
                insertLogRow(
                    safeSeverity,
                    safeMessage,
                    safeContext,
                    safeExceptionType,
                    safeStackTrace,
                    safeDetailsJson,
                    safeUserId,
                    safeRecordId
                );
            }
        } catch (Exception ignored) {
            // Logging must never block the primary flow.
        }
    }

    private static Boolean publishLogEvent(
        String severity,
        String messageText,
        String context,
        String exceptionType,
        String stackTrace,
        String detailsJson,
        String userIdText,
        String recordIdText
    ) {
        c23_ErrorLogEvent__e eventRow = new c23_ErrorLogEvent__e();
        eventRow.c23_Severity__c = severity;
        eventRow.c23_Message__c = messageText;
        eventRow.c23_Context__c = context;
        eventRow.c23_ExceptionType__c = exceptionType;
        eventRow.c23_StackTrace__c = stackTrace;
        eventRow.c23_DetailsJson__c = detailsJson;
        eventRow.c23_UserId__c = userIdText;
        eventRow.c23_RecordId__c = recordIdText;
        Database.SaveResult publishResult = EventBus.publish(eventRow);
        return publishResult != null && publishResult.isSuccess();
    }

    private static void insertLogRow(
        String severity,
        String messageText,
        String context,
        String exceptionType,
        String stackTrace,
        String detailsJson,
        String userIdText,
        String recordIdText
    ) {
        c23_ErrorLog__c logRow = new c23_ErrorLog__c();
        logRow.c23_Severity__c = severity;
        logRow.c23_Message__c = messageText;
        logRow.c23_Context__c = context;
        logRow.c23_ExceptionType__c = exceptionType;
        logRow.c23_StackTrace__c = stackTrace;
        logRow.c23_DetailsJson__c = detailsJson;
        logRow.c23_UserId__c = userIdText;
        logRow.c23_RecordId__c = recordIdText;
        insert logRow;
    }

    private static String deriveContextFromStack(String stackTrace) {
        if (String.isBlank(stackTrace)) {
            return null;
        }

        for (String lineValue : stackTrace.split('\n')) {
            String trimmed = lineValue == null ? '' : lineValue.trim();
            if (!trimmed.startsWith('Class.')) {
                continue;
            }

            String candidate = trimmed.substring(6);
            Integer markerIndex = candidate.indexOf(':');
            if (markerIndex > 0) {
                candidate = candidate.substring(0, markerIndex);
            }
            return clipShort(candidate);
        }

        return null;
    }

    private static String normalizeSeverity(String severity) {
        if (severity == SEVERITY_INFO || severity == SEVERITY_WARN || severity == SEVERITY_ERROR || severity == SEVERITY_FATAL) {
            return severity;
        }
        return SEVERITY_ERROR;
    }

    private static String clipShort(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String trimmed = value.trim();
        if (trimmed.length() <= MAX_SHORT_TEXT) {
            return trimmed;
        }
        return trimmed.substring(0, MAX_SHORT_TEXT);
    }

    private static String clipId(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String trimmed = value.trim();
        if (trimmed.length() <= MAX_ID_TEXT) {
            return trimmed;
        }
        return trimmed.substring(0, MAX_ID_TEXT);
    }

    private static String clipLong(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        if (value.length() <= MAX_LONG_TEXT) {
            return value;
        }
        return value.substring(0, MAX_LONG_TEXT);
    }
}