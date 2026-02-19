@IsTest
private class c23_PermissionStudioServicesTest {
    private static final String ACCESS_PERMISSION_SET_NAME = 'c23_PermissionStudio_Admin';
    private static PermissionSet cachedPermissionSet;

    @IsTest
    static void testAccessGatingRequiresCustomPermission() {
        User noAccessUser = createUser('noAccess');

        System.runAs(noAccessUser) {
            Boolean didThrow = false;
            try {
                c23_PermissionStudioSecurity.assertAccess();
            } catch (AuraHandledException ex) {
                didThrow = true;
                System.assertEquals(Label.c23_PS_General_AccessDenied, ex.getMessage());
            }

            System.assert(didThrow, 'Expected access check to throw for users without custom permission.');
        }
    }

    @IsTest
    static void testGetSObjectCatalogReturnsRows() {
        User accessUser = createUserWithAccess('catalog');

        System.runAs(accessUser) {
            c23_SchemaService.permissionableObjectOverride = new Set<String>{ 'Account' };
            try {
                List<c23_SchemaService.SObjectCatalogRow> rows = c23_SchemaService.getSObjectCatalog();
                System.assertEquals(1, rows.size(), 'Expected exactly one row from test override.');
                System.assertEquals('Account', rows[0].apiName);
                System.assertEquals(false, rows[0].isCustom);
            } finally {
                c23_SchemaService.permissionableObjectOverride = null;
            }
        }
    }

    @IsTest
    static void testApplyObjectMatrixWritesLedger() {
        User accessUser = createUserWithAccess('apply');
        PermissionSet targetPermissionSet = getAccessPermissionSet();

        System.runAs(accessUser) {
            c23_SchemaService.permissionableObjectOverride = new Set<String>{ 'Account' };
            try {
                List<c23_PermissionStudioObjectPermService.ObjectMatrixRow> matrixRows =
                    c23_PermissionStudioObjectPermService.getObjectMatrix(targetPermissionSet.Id);
                System.assertEquals(1, matrixRows.size(), 'Expected one row from catalog override.');

                c23_PermissionStudioObjectPermService.ObjectMatrixRow accountRow = matrixRows[0];
                c23_PermissionStudioObjectPermService.DesiredStateRow desiredState =
                    buildDesiredStateForChange(accountRow);
                List<c23_PermissionStudioObjectPermService.DesiredStateRow> desiredRows =
                    new List<c23_PermissionStudioObjectPermService.DesiredStateRow>{ desiredState };

                c23_PermissionStudioObjectPermService.PreviewResponse preview =
                    c23_PermissionStudioObjectPermService.previewApplyObjectMatrix(targetPermissionSet.Id, desiredRows);
                System.assertEquals(true, preview.hasChanges);
                System.assert(preview.changedCount > 0, 'Expected at least one changed row in preview.');

                c23_PermissionStudioObjectPermService.ApplyResponse apply =
                    c23_PermissionStudioObjectPermService.applyObjectMatrix(
                        targetPermissionSet.Id,
                        desiredRows,
                        'Automated test apply'
                    );

                System.assert(apply.changedCount > 0, 'Expected apply to write one or more changes.');
                System.assertNotEquals(null, apply.ledgerId, 'Expected apply to return ledger header id.');

                ObjectPermissions persisted = [
                    SELECT PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete,
                        PermissionsViewAllRecords, PermissionsModifyAllRecords
                    FROM ObjectPermissions
                    WHERE ParentId = :targetPermissionSet.Id
                        AND SObjectType = 'Account'
                    LIMIT 1
                ];
                System.assertEquals(desiredState.permissionsRead, persisted.PermissionsRead);
                System.assertEquals(desiredState.permissionsCreate, persisted.PermissionsCreate);
                System.assertEquals(desiredState.permissionsEdit, persisted.PermissionsEdit);
                System.assertEquals(desiredState.permissionsDelete, persisted.PermissionsDelete);
                System.assertEquals(desiredState.permissionsViewAllRecords, persisted.PermissionsViewAllRecords);
                System.assertEquals(desiredState.permissionsModifyAllRecords, persisted.PermissionsModifyAllRecords);

                c23_PermissionStudioChange__c header = [
                    SELECT c23_ChangedCount__c, c23_TotalRequestedCount__c, c23_IsTruncated__c
                    FROM c23_PermissionStudioChange__c
                    WHERE Id = :apply.ledgerId
                    LIMIT 1
                ];
                System.assertEquals(Decimal.valueOf(apply.changedCount), header.c23_ChangedCount__c);
                System.assertEquals(Decimal.valueOf(apply.totalRequestedCount), header.c23_TotalRequestedCount__c);
                System.assertEquals(false, header.c23_IsTruncated__c);

                Integer itemCount = [
                    SELECT COUNT()
                    FROM c23_PermissionStudioChangeItem__c
                    WHERE c23_Change__c = :apply.ledgerId
                ];
                System.assert(itemCount > 0, 'Expected one or more ledger child items.');
            } finally {
                c23_SchemaService.permissionableObjectOverride = null;
            }
        }
    }

    @IsTest
    static void testApplyObjectMatrixJsonAcceptsPayload() {
        User accessUser = createUserWithAccess('jsonap');
        PermissionSet targetPermissionSet = getAccessPermissionSet();

        System.runAs(accessUser) {
            c23_SchemaService.permissionableObjectOverride = new Set<String>{ 'Account' };
            try {
                Map<String, Object> desiredRow = new Map<String, Object>();
                desiredRow.put('apiName', 'Account');
                desiredRow.put('permissionsRead', true);
                desiredRow.put('permissionsCreate', true);
                desiredRow.put('permissionsEdit', true);
                desiredRow.put('permissionsDelete', true);
                desiredRow.put('permissionsViewAllRecords', true);
                desiredRow.put('permissionsModifyAllRecords', true);

                String payloadJson = JSON.serialize(new List<Object>{ desiredRow });

                c23_PermissionStudioObjectPermService.ApplyResponse apply =
                    c23_PermissionStudioObjectPermService.applyObjectMatrixJson(
                        targetPermissionSet.Id,
                        payloadJson,
                        'json payload apply'
                    );

                System.assertEquals(1, apply.totalRequestedCount, 'Expected Account payload row to be parsed.');
                System.assert(apply.changedCount >= 0, 'Expected valid response.');

                List<ObjectPermissions> accountPerms = [
                    SELECT PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete,
                        PermissionsViewAllRecords, PermissionsModifyAllRecords
                    FROM ObjectPermissions
                    WHERE ParentId = :targetPermissionSet.Id
                        AND SObjectType = 'Account'
                    LIMIT 1
                ];
                System.assertEquals(1, accountPerms.size(), 'Expected Account permissions row to exist after JSON apply.');
            } finally {
                c23_SchemaService.permissionableObjectOverride = null;
            }
        }
    }

    @IsTest
    static void testApplyObjectMatrixJsonRequestAcceptsWrapperPayload() {
        User accessUser = createUserWithAccess('jsonrq');
        PermissionSet targetPermissionSet = getAccessPermissionSet();

        System.runAs(accessUser) {
            c23_SchemaService.permissionableObjectOverride = new Set<String>{ 'Account' };
            try {
                Map<String, Object> desiredRow = new Map<String, Object>();
                desiredRow.put('apiName', 'Account');
                desiredRow.put('permissionsRead', true);
                desiredRow.put('permissionsCreate', false);
                desiredRow.put('permissionsEdit', false);
                desiredRow.put('permissionsDelete', false);
                desiredRow.put('permissionsViewAllRecords', false);
                desiredRow.put('permissionsModifyAllRecords', false);

                c23_PermissionStudioObjectPermService.ApplyObjectMatrixJsonRequest request =
                    new c23_PermissionStudioObjectPermService.ApplyObjectMatrixJsonRequest();
                request.parentPermissionSetId = String.valueOf(targetPermissionSet.Id);
                request.desiredStateRowsJson = JSON.serialize(new List<Object>{ desiredRow });
                request.changeNote = 'json wrapper apply';

                c23_PermissionStudioObjectPermService.ApplyResponse apply =
                    c23_PermissionStudioObjectPermService.applyObjectMatrixJsonRequest(request);

                System.assertEquals(1, apply.totalRequestedCount, 'Expected one requested row.');
            } finally {
                c23_SchemaService.permissionableObjectOverride = null;
            }
        }
    }

    @IsTest
    static void testApplyObjectMatrixJsonEnvelopeAcceptsPayload() {
        User accessUser = createUserWithAccess('jsonen');
        PermissionSet targetPermissionSet = getAccessPermissionSet();

        System.runAs(accessUser) {
            c23_SchemaService.permissionableObjectOverride = new Set<String>{ 'Account' };
            try {
                Map<String, Object> desiredRow = new Map<String, Object>();
                desiredRow.put('apiName', 'Account');
                desiredRow.put('permissionsRead', true);
                desiredRow.put('permissionsCreate', false);
                desiredRow.put('permissionsEdit', false);
                desiredRow.put('permissionsDelete', false);
                desiredRow.put('permissionsViewAllRecords', false);
                desiredRow.put('permissionsModifyAllRecords', false);

                Map<String, Object> requestPayload = new Map<String, Object>();
                requestPayload.put('parentPermissionSetId', String.valueOf(targetPermissionSet.Id));
                requestPayload.put('permissionSetId', String.valueOf(targetPermissionSet.Id));
                requestPayload.put('desiredStateRowsJson', JSON.serialize(new List<Object>{ desiredRow }));
                requestPayload.put('changeNote', 'json envelope apply');

                c23_PermissionStudioObjectPermService.ApplyResponse apply =
                    c23_PermissionStudioObjectPermService.applyObjectMatrixJsonEnvelope(JSON.serialize(requestPayload));

                System.assertEquals(1, apply.totalRequestedCount, 'Expected one requested row from envelope.');
            } finally {
                c23_SchemaService.permissionableObjectOverride = null;
            }
        }
    }

    @IsTest
    static void testPreviewObjectMatrixAcceptsDescribeObjectsWhenCatalogIsEmpty() {
        User accessUser = createUserWithAccess('objdesc');
        PermissionSet targetPermissionSet = getAccessPermissionSet();

        System.runAs(accessUser) {
            c23_SchemaService.permissionableObjectOverride = new Set<String>();
            try {
                c23_PermissionStudioObjectPermService.DesiredStateRow desiredState =
                    new c23_PermissionStudioObjectPermService.DesiredStateRow();
                desiredState.key = ' account ';
                desiredState.permissionsRead = true;
                desiredState.permissionsCreate = false;
                desiredState.permissionsEdit = false;
                desiredState.permissionsDelete = false;
                desiredState.permissionsViewAllRecords = false;
                desiredState.permissionsModifyAllRecords = false;

                c23_PermissionStudioObjectPermService.PreviewResponse preview =
                    c23_PermissionStudioObjectPermService.previewApplyObjectMatrix(
                        targetPermissionSet.Id,
                        new List<c23_PermissionStudioObjectPermService.DesiredStateRow>{ desiredState }
                    );

                System.assertNotEquals(null, preview, 'Expected preview response.');
                System.assertEquals(1, preview.totalRequestedCount, 'Expected Account desired row to be accepted.');
            } finally {
                c23_SchemaService.permissionableObjectOverride = null;
            }
        }
    }

    @IsTest
    static void testApplyObjectMatrixInvalidRowsWritesErrorLog() {
        User accessUser = createUserWithAccess('objlog');
        PermissionSet targetPermissionSet = getAccessPermissionSet();

        System.runAs(accessUser) {
            c23_PermissionStudioObjectPermService.DesiredStateRow invalidRow =
                new c23_PermissionStudioObjectPermService.DesiredStateRow();
            invalidRow.apiName = 'c23_NotARealObject__c';
            invalidRow.permissionsRead = true;
            invalidRow.permissionsCreate = false;
            invalidRow.permissionsEdit = false;
            invalidRow.permissionsDelete = false;
            invalidRow.permissionsViewAllRecords = false;
            invalidRow.permissionsModifyAllRecords = false;

            Boolean threwExpected = false;
            try {
                c23_PermissionStudioObjectPermService.applyObjectMatrix(
                    targetPermissionSet.Id,
                    new List<c23_PermissionStudioObjectPermService.DesiredStateRow>{ invalidRow },
                    'invalid row test'
                );
            } catch (AuraHandledException ex) {
                threwExpected = true;
                System.assertEquals(Label.c23_PS_Error_InvalidDesiredRows, ex.getMessage());
            }
            System.assertEquals(true, threwExpected, 'Expected invalid desired rows exception.');

            List<c23_ErrorLog__c> logs = [
                SELECT c23_Context__c, c23_Message__c, c23_DetailsJson__c, c23_RecordId__c
                FROM c23_ErrorLog__c
                WHERE c23_Context__c = 'ObjectPerm.computeChanges'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            System.assertEquals(1, logs.size(), 'Expected one error log row.');
            System.assertEquals(Label.c23_PS_Error_InvalidDesiredRows, logs[0].c23_Message__c);
            System.assertEquals(String.valueOf(targetPermissionSet.Id), logs[0].c23_RecordId__c);
            System.assert(logs[0].c23_DetailsJson__c.contains('c23_NotARealObject__c'));
        }
    }

    @IsTest
    static void testApplyFieldMatrixJsonEnvelopeAcceptsPayload() {
        User accessUser = createUserWithAccess('fldenv');
        PermissionSet targetPermissionSet = getAccessPermissionSet();

        System.runAs(accessUser) {
            c23_SchemaService.permissionableObjectOverride = new Set<String>{ 'Account' };
            try {
                List<c23_PermissionStudioFieldPermService.FieldMatrixRow> matrixRows =
                    c23_PermissionStudioFieldPermService.getFieldMatrix(targetPermissionSet.Id, 'Account');
                System.assert(matrixRows.size() > 0, 'Expected at least one Account field row.');

                c23_PermissionStudioFieldPermService.FieldMatrixRow firstRow = matrixRows[0];
                Map<String, Object> desiredRow = new Map<String, Object>();
                desiredRow.put('fieldPath', firstRow.fieldPath);
                desiredRow.put('permissionsRead', firstRow.permissionsRead);
                desiredRow.put('permissionsEdit', firstRow.permissionsEdit);

                Map<String, Object> payload = new Map<String, Object>();
                payload.put('parentPermissionSetId', String.valueOf(targetPermissionSet.Id));
                payload.put('permissionSetId', String.valueOf(targetPermissionSet.Id));
                payload.put('objectApiName', 'Account');
                payload.put('desiredStateRowsJson', JSON.serialize(new List<Object>{ desiredRow }));
                payload.put('changeNote', 'field envelope apply');

                c23_PermissionStudioFieldPermService.ApplyResponse apply =
                    c23_PermissionStudioFieldPermService.applyFieldMatrixJsonEnvelope(JSON.serialize(payload));

                System.assertEquals(1, apply.totalRequestedCount, 'Expected one desired field row from envelope.');
            } finally {
                c23_SchemaService.permissionableObjectOverride = null;
            }
        }
    }

    @IsTest
    static void testApplyFieldMatrixJsonRequestAcceptsFieldApiAlias() {
        User accessUser = createUserWithAccess('fldreq');
        PermissionSet targetPermissionSet = getAccessPermissionSet();

        System.runAs(accessUser) {
            c23_SchemaService.permissionableObjectOverride = new Set<String>{ 'Account' };
            try {
                List<c23_PermissionStudioFieldPermService.FieldMatrixRow> matrixRows =
                    c23_PermissionStudioFieldPermService.getFieldMatrix(targetPermissionSet.Id, 'Account');
                System.assert(matrixRows.size() > 0, 'Expected at least one Account field row.');

                c23_PermissionStudioFieldPermService.FieldMatrixRow firstRow = matrixRows[0];
                Map<String, Object> desiredRow = new Map<String, Object>();
                desiredRow.put('fieldApiName', firstRow.fieldApiName);
                desiredRow.put('permissionsRead', firstRow.permissionsRead);
                desiredRow.put('permissionsEdit', firstRow.permissionsEdit);

                c23_PermissionStudioFieldPermService.ApplyFieldMatrixJsonRequest request =
                    new c23_PermissionStudioFieldPermService.ApplyFieldMatrixJsonRequest();
                request.parentPermissionSetId = String.valueOf(targetPermissionSet.Id);
                request.permissionSetId = String.valueOf(targetPermissionSet.Id);
                request.objectApiName = 'Account';
                request.desiredStateRowsJson = JSON.serialize(new List<Object>{ desiredRow });
                request.changeNote = 'field request apply';

                c23_PermissionStudioFieldPermService.ApplyResponse apply =
                    c23_PermissionStudioFieldPermService.applyFieldMatrixJsonRequest(request);

                System.assertEquals(1, apply.totalRequestedCount, 'Expected alias field row to resolve to field path.');
            } finally {
                c23_SchemaService.permissionableObjectOverride = null;
            }
        }
    }

    @IsTest
    static void testApplySystemPermissionsJsonEnvelopeAcceptsPayload() {
        User accessUser = createUserWithAccess('sysenv');
        PermissionSet targetPermissionSet = getAccessPermissionSet();

        System.runAs(accessUser) {
            List<c23_PermissionStudioSystemPermService.SystemPermRow> matrixRows =
                c23_PermissionStudioSystemPermService.getSystemPermissionMatrix(targetPermissionSet.Id);
            System.assert(matrixRows.size() > 0, 'Expected one or more system permission rows.');

            c23_PermissionStudioSystemPermService.SystemPermRow firstRow = matrixRows[0];
            Map<String, Object> desiredRow = new Map<String, Object>();
            desiredRow.put('apiName', firstRow.apiName);
            desiredRow.put('enabled', firstRow.enabled);

            Map<String, Object> payload = new Map<String, Object>();
            payload.put('parentPermissionSetId', String.valueOf(targetPermissionSet.Id));
            payload.put('permissionSetId', String.valueOf(targetPermissionSet.Id));
            payload.put('desiredStateRowsJson', JSON.serialize(new List<Object>{ desiredRow }));
            payload.put('changeNote', 'system envelope apply');

            c23_PermissionStudioSystemPermService.ApplyResponse apply =
                c23_PermissionStudioSystemPermService.applySystemPermissionsJsonEnvelope(JSON.serialize(payload));

            System.assertEquals(1, apply.totalRequestedCount, 'Expected one desired system row from envelope.');
        }
    }

    @IsTest
    static void testApplySystemPermissionsJsonRequestAcceptsKeyAlias() {
        User accessUser = createUserWithAccess('sysreq');
        PermissionSet targetPermissionSet = getAccessPermissionSet();

        System.runAs(accessUser) {
            List<c23_PermissionStudioSystemPermService.SystemPermRow> matrixRows =
                c23_PermissionStudioSystemPermService.getSystemPermissionMatrix(targetPermissionSet.Id);
            System.assert(matrixRows.size() > 0, 'Expected one or more system permission rows.');

            c23_PermissionStudioSystemPermService.SystemPermRow firstRow = matrixRows[0];
            Map<String, Object> desiredRow = new Map<String, Object>();
            desiredRow.put('key', firstRow.apiName);
            desiredRow.put('enabled', firstRow.enabled);

            c23_PermissionStudioSystemPermService.ApplySystemPermJsonRequest request =
                new c23_PermissionStudioSystemPermService.ApplySystemPermJsonRequest();
            request.parentPermissionSetId = String.valueOf(targetPermissionSet.Id);
            request.permissionSetId = String.valueOf(targetPermissionSet.Id);
            request.desiredStateRowsJson = JSON.serialize(new List<Object>{ desiredRow });
            request.changeNote = 'system request apply';

            c23_PermissionStudioSystemPermService.ApplyResponse apply =
                c23_PermissionStudioSystemPermService.applySystemPermissionsJsonRequest(request);

            System.assertEquals(1, apply.totalRequestedCount, 'Expected key alias row to resolve.');
        }
    }

    @IsTest
    static void testRecentSelectionsSaveAndLoad() {
        User accessUser = createUserWithAccess('recent');
        PermissionSet targetPermissionSet = getAccessPermissionSet();
        Id profileId = accessUser.ProfileId;

        System.runAs(accessUser) {
            List<c23_PermissionStudioRecentService.RecentSelectionRow> initialRows =
                c23_PermissionStudioRecentService.getRecentSelections();
            System.assertEquals(0, initialRows.size(), 'Expected no recent selections by default.');

            List<c23_PermissionStudioRecentService.RecentSelectionRow> afterPermissionSet =
                c23_PermissionStudioRecentService.saveRecentSelection('PermissionSet', targetPermissionSet.Id);
            System.assertEquals(1, afterPermissionSet.size(), 'Expected one recent selection after first save.');
            System.assertEquals('PermissionSet', afterPermissionSet[0].itemType);
            System.assertEquals(String.valueOf(targetPermissionSet.Id), afterPermissionSet[0].targetId);

            List<c23_PermissionStudioRecentService.RecentSelectionRow> afterProfile =
                c23_PermissionStudioRecentService.saveRecentSelection('Profile', profileId);
            System.assert(afterProfile.size() >= 1, 'Expected at least one recent selection after profile save.');
            System.assertEquals('Profile', afterProfile[0].itemType);
            System.assertEquals(String.valueOf(profileId), afterProfile[0].targetId);
            System.assertNotEquals(null, afterProfile[0].editorPermissionSetId, 'Expected profile-owned permission set id.');

            List<c23_PermissionStudioRecentService.RecentSelectionRow> loadedRows =
                c23_PermissionStudioRecentService.getRecentSelections();
            System.assertEquals('Profile', loadedRows[0].itemType);
            System.assertEquals(String.valueOf(profileId), loadedRows[0].targetId);
        }
    }

    @IsTest
    static void testUserSettingsSaveAndLoadDensity() {
        User accessUser = createUserWithAccess('userset');

        System.runAs(accessUser) {
            c23_PermissionStudioUserSettingsService.UserSettingsDTO initialSettings =
                c23_PermissionStudioUserSettingsService.getUserSettings();
            System.assertEquals('comfortable', initialSettings.tableDensity, 'Expected default density value.');

            c23_PermissionStudioUserSettingsService.UserSettingsDTO settingsRequest =
                new c23_PermissionStudioUserSettingsService.UserSettingsDTO();
            settingsRequest.tableDensity = 'compact';

            c23_PermissionStudioUserSettingsService.UserSettingsDTO savedSettings =
                c23_PermissionStudioUserSettingsService.saveUserSettings(settingsRequest);
            System.assertEquals('compact', savedSettings.tableDensity, 'Expected saved density value.');

            User persistedUser = [
                SELECT c23_PS_UserSettings__c
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            System.assertNotEquals(null, persistedUser.c23_PS_UserSettings__c, 'Expected persisted user settings JSON.');
            System.assert(
                persistedUser.c23_PS_UserSettings__c.contains('tableDensity'),
                'Expected persisted JSON payload to include density key.'
            );
            System.assert(
                persistedUser.c23_PS_UserSettings__c.contains('compact'),
                'Expected persisted JSON payload to include compact density.'
            );

            c23_PermissionStudioUserSettingsService.UserSettingsDTO loadedSettings =
                c23_PermissionStudioUserSettingsService.getUserSettings();
            System.assertEquals('compact', loadedSettings.tableDensity, 'Expected loaded density value.');
        }
    }

    @IsTest
    static void testAssignmentServicePermissionSetAssignAndUnassign() {
        User accessUser = createUserWithAccess('asgsvc');
        User targetUser = createUser('asgusr');
        PermissionSet targetPermissionSet = getAccessPermissionSet();

        System.runAs(accessUser) {
            c23_PermissionStudioAssignmentService.AssignmentSnapshotResponse initialSnapshot =
                c23_PermissionStudioAssignmentService.getAssignmentSnapshot('PermissionSet', targetPermissionSet.Id);
            System.assertEquals('PermissionSet', initialSnapshot.targetType);
            System.assertEquals(true, initialSnapshot.supportsRemoval);

            c23_PermissionStudioAssignmentService.ApplyAssignmentsResponse assignResponse =
                c23_PermissionStudioAssignmentService.applyAssignments(
                    'PermissionSet',
                    targetPermissionSet.Id,
                    new List<Id>{ targetUser.Id },
                    new List<Id>(),
                    'assign test'
                );
            System.assert(assignResponse.changedCount > 0, 'Expected at least one assignment change.');

            Integer assignedCount = [
                SELECT COUNT()
                FROM PermissionSetAssignment
                WHERE PermissionSetId = :targetPermissionSet.Id
                    AND AssigneeId = :targetUser.Id
            ];
            System.assertEquals(1, assignedCount, 'Expected user assignment to be inserted.');

            c23_PermissionStudioAssignmentService.ApplyAssignmentsResponse unassignResponse =
                c23_PermissionStudioAssignmentService.applyAssignments(
                    'PermissionSet',
                    targetPermissionSet.Id,
                    new List<Id>(),
                    new List<Id>{ targetUser.Id },
                    'unassign test'
                );
            System.assert(unassignResponse.changedCount > 0, 'Expected at least one unassignment change.');

            Integer unassignedCount = [
                SELECT COUNT()
                FROM PermissionSetAssignment
                WHERE PermissionSetId = :targetPermissionSet.Id
                    AND AssigneeId = :targetUser.Id
            ];
            System.assertEquals(0, unassignedCount, 'Expected user assignment to be removed.');
        }
    }

    @IsTest
    static void testPsgServiceMembershipApply() {
        User accessUser = createUserWithAccess('psgsvc');
        PermissionSet permissionSetRecord = getAccessPermissionSet();
        PermissionSetGroup groupRecord = createPermissionSetGroupForTest('c23psgt');

        System.runAs(accessUser) {
            c23_PermissionStudioPsgService.GroupEditorResponse initialResponse =
                c23_PermissionStudioPsgService.getPermissionSetGroupEditor(groupRecord.Id);
            System.assertEquals(groupRecord.Id, initialResponse.groupId);

            c23_PermissionStudioPsgService.ApplyResponse addResponse =
                c23_PermissionStudioPsgService.applyGroupMembership(
                    groupRecord.Id,
                    new List<Id>{ permissionSetRecord.Id },
                    'add member'
                );
            System.assert(addResponse.changedCount > 0, 'Expected membership insert change.');

            Integer membershipCount = [
                SELECT COUNT()
                FROM PermissionSetGroupComponent
                WHERE PermissionSetGroupId = :groupRecord.Id
                    AND PermissionSetId = :permissionSetRecord.Id
            ];
            System.assertEquals(1, membershipCount, 'Expected permission set to be added to group.');

            c23_PermissionStudioPsgService.ApplyResponse removeResponse =
                c23_PermissionStudioPsgService.applyGroupMembership(
                    groupRecord.Id,
                    new List<Id>(),
                    'remove member'
                );
            System.assert(removeResponse.changedCount > 0, 'Expected membership delete change.');

            Integer finalMembershipCount = [
                SELECT COUNT()
                FROM PermissionSetGroupComponent
                WHERE PermissionSetGroupId = :groupRecord.Id
                    AND PermissionSetId = :permissionSetRecord.Id
            ];
            System.assertEquals(0, finalMembershipCount, 'Expected permission set to be removed from group.');
        }
    }

    private static c23_PermissionStudioObjectPermService.DesiredStateRow buildDesiredStateForChange(
        c23_PermissionStudioObjectPermService.ObjectMatrixRow row
    ) {
        c23_PermissionStudioObjectPermService.DesiredStateRow desired =
            new c23_PermissionStudioObjectPermService.DesiredStateRow();
        desired.apiName = row.apiName;
        // Keep read enabled so the row remains queryable; flip create to guarantee a change.
        desired.permissionsRead = true;
        desired.permissionsCreate = row.permissionsCreate == true ? false : true;
        desired.permissionsEdit = false;
        desired.permissionsDelete = false;
        desired.permissionsViewAllFields = false;
        desired.permissionsViewAllRecords = false;
        desired.permissionsModifyAllRecords = false;

        return desired;
    }

    private static User createUserWithAccess(String key) {
        User userRecord = createUser(key);
        insert new PermissionSetAssignment(
            AssigneeId = userRecord.Id,
            PermissionSetId = getAccessPermissionSet().Id
        );
        return userRecord;
    }

    private static PermissionSet getAccessPermissionSet() {
        if (cachedPermissionSet == null) {
            cachedPermissionSet = [
                SELECT Id, Name
                FROM PermissionSet
                WHERE Name = :ACCESS_PERMISSION_SET_NAME
                LIMIT 1
            ];
        }
        return cachedPermissionSet;
    }

    private static User createUser(String key) {
        String safeKey = String.isBlank(key) ? 'usr' : key.toLowerCase().replaceAll('[^a-z0-9]', '');
        if (String.isBlank(safeKey)) {
            safeKey = 'usr';
        }
        if (safeKey.length() > 5) {
            safeKey = safeKey.substring(0, 5);
        }

        String unique = String.valueOf(Datetime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        String aliasValue = (safeKey + 'user').substring(0, Math.min(8, (safeKey + 'user').length()));
        String usernameValue = 'c23.ps.' + safeKey + '.' + unique + '@example.invalid';

        User userRecord = new User(
            Alias = aliasValue,
            Email = usernameValue,
            EmailEncodingKey = 'UTF-8',
            LastName = 'Permission Studio',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = usernameValue
        );
        insert userRecord;
        return userRecord;
    }

    private static PermissionSetGroup createPermissionSetGroupForTest(String key) {
        String safeKey = String.isBlank(key) ? 'psg' : key.toLowerCase().replaceAll('[^a-z0-9]', '');
        if (safeKey.length() > 10) {
            safeKey = safeKey.substring(0, 10);
        }
        String unique = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        String devName = ('c23_' + safeKey + '_' + unique).toLowerCase();
        if (devName.length() > 40) {
            devName = devName.substring(0, 40);
        }

        PermissionSetGroup groupRecord = new PermissionSetGroup(
            DeveloperName = devName,
            MasterLabel = 'c23 PSG ' + safeKey + ' ' + unique.substring(0, Math.min(6, unique.length()))
        );
        insert groupRecord;
        return groupRecord;
    }
}