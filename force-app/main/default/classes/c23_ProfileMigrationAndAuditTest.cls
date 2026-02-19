@IsTest
private class c23_ProfileMigrationAndAuditTest {
    private static final String ACCESS_PERMISSION_SET_NAME = 'c23_PermissionStudio_Admin';
    private static PermissionSet cachedAccessPermissionSet;

    @IsTest
    static void testBuildPlanForProfile() {
        User accessUser = createUserWithAccess('migplan');

        System.runAs(accessUser) {
            c23_ProfileMigrationPlanService.MigrationPlanDTO plan =
                c23_ProfileMigrationPlanService.buildPlan(
                    accessUser.ProfileId,
                    c23_ProfileMigrationPlanService.TARGET_MODE_CREATE,
                    null,
                    'c23 Test Migration Plan',
                    'c23_TestMigrationPlan',
                    c23_ProfileMigrationPlanService.MERGE_STRATEGY_UNION,
                    null
                );

            System.assertNotEquals(null, plan, 'Expected migration plan.');
            System.assertEquals(accessUser.ProfileId, plan.profileId, 'Expected selected profile in plan.');
            System.assertNotEquals(null, plan.sourcePermissionSetId, 'Expected profile-owned permission set.');
        }
    }

    @IsTest
    static void testStartMigrationJobAndGetStatus() {
        User accessUser = createUserWithAccess('migjob');

        System.runAs(accessUser) {
            String unique = String.valueOf(Math.abs(Crypto.getRandomInteger()));
            String targetName = 'c23 Test Mig ' + unique.substring(0, Math.min(6, unique.length()));
            String targetApi = 'c23_TestMig_' + unique.substring(0, Math.min(10, unique.length()));

            Test.startTest();
            c23_ProfileMigrationJobService.JobStartDTO startResponse =
                c23_ProfileMigrationJobService.start(
                    accessUser.ProfileId,
                    c23_ProfileMigrationPlanService.TARGET_MODE_CREATE,
                    null,
                    targetName,
                    targetApi,
                    c23_ProfileMigrationPlanService.MERGE_STRATEGY_UNION,
                    null,
                    false,
                    false,
                    null
                );
            Test.stopTest();

            System.assertNotEquals(null, startResponse, 'Expected start response.');
            System.assertNotEquals(null, startResponse.jobId, 'Expected migration job id.');

            c23_ProfileMigrationJobService.JobStatusDTO statusResponse =
                c23_ProfileMigrationJobService.getStatus(startResponse.jobId);
            System.assertNotEquals(null, statusResponse, 'Expected status response.');
            System.assertNotEquals(null, statusResponse.status, 'Expected status value.');
        }
    }

    @IsTest
    static void testAuditSearchAndLedgerQuery() {
        User accessUser = createUserWithAccess('auditq');

        System.runAs(accessUser) {
            List<c23_AuditQueryService.PermissionKeyDTO> searchRows =
                c23_AuditQueryService.searchPermissionKeys('', new List<String>{ 'SYSTEM' });
            System.assertNotEquals(null, searchRows, 'Expected search rows response.');
            if (!searchRows.isEmpty()) {
                System.assertEquals('SYSTEM', searchRows[0].category, 'Expected system key category.');
            }

            List<c23_AuditQueryService.LedgerEventDTO> ledgerRows =
                c23_AuditQueryService.getLedgerEvents(
                    null,
                    Date.today().addDays(-7),
                    Date.today()
                );
            System.assertNotEquals(null, ledgerRows, 'Expected ledger rows response.');
        }
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
        if (cachedAccessPermissionSet == null) {
            cachedAccessPermissionSet = [
                SELECT Id, Name
                FROM PermissionSet
                WHERE Name = :ACCESS_PERMISSION_SET_NAME
                LIMIT 1
            ];
        }
        return cachedAccessPermissionSet;
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
        String usernameValue = 'c23.ps.mig.' + safeKey + '.' + unique + '@example.invalid';

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
}