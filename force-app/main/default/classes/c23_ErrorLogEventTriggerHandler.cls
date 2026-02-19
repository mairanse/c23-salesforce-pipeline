public without sharing class c23_ErrorLogEventTriggerHandler {
    public static void handleAfterInsert(List<c23_ErrorLogEvent__e> eventRows) {
        if (eventRows == null || eventRows.isEmpty()) {
            return;
        }

        List<c23_ErrorLog__c> rowsToInsert = new List<c23_ErrorLog__c>();
        for (c23_ErrorLogEvent__e eventRow : eventRows) {
            if (eventRow == null) {
                continue;
            }

            c23_ErrorLog__c row = new c23_ErrorLog__c();
            row.c23_Severity__c = normalizeSeverity(eventRow.c23_Severity__c);
            row.c23_Message__c = eventRow.c23_Message__c;
            row.c23_Context__c = eventRow.c23_Context__c;
            row.c23_ExceptionType__c = eventRow.c23_ExceptionType__c;
            row.c23_StackTrace__c = eventRow.c23_StackTrace__c;
            row.c23_DetailsJson__c = eventRow.c23_DetailsJson__c;
            row.c23_UserId__c = eventRow.c23_UserId__c;
            row.c23_RecordId__c = eventRow.c23_RecordId__c;
            rowsToInsert.add(row);
        }

        if (rowsToInsert.isEmpty()) {
            return;
        }

        try {
            insert rowsToInsert;
        } catch (Exception ignored) {
            // Error-log sink failures must never bubble into platform-event processing.
        }
    }

    private static String normalizeSeverity(String severityValue) {
        if (severityValue == 'Info' || severityValue == 'Warn' || severityValue == 'Error' || severityValue == 'Fatal') {
            return severityValue;
        }
        return 'Error';
    }
}