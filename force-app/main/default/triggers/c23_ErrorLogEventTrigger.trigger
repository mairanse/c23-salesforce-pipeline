trigger c23_ErrorLogEventTrigger on c23_ErrorLogEvent__e (after insert) {
    c23_ErrorLogEventTriggerHandler.handleAfterInsert(Trigger.New);
}