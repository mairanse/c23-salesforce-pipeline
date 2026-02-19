public with sharing class c23_UserPermissionSummaryService {
    public class UserSearchResult {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String username;
        @AuraEnabled public String email;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String profileName;

        public UserSearchResult(User userRecord) {
            id = (String) userRecord.Id;
            name = userRecord.Name;
            username = userRecord.Username;
            email = userRecord.Email;
            isActive = userRecord.IsActive;
            profileName = userRecord.Profile != null ? userRecord.Profile.Name : null;
        }
    }

    @AuraEnabled(cacheable=true)
    public static String ping() {
        return 'ok';
    }

    @AuraEnabled(cacheable=true)
    public static List<UserSearchResult> searchUsers(String query) {
        if (String.isBlank(query)) {
            return new List<UserSearchResult>();
        }

        String normalizedQuery = query.trim();
        if (normalizedQuery.length() < 2) {
            return new List<UserSearchResult>();
        }

        String likeQuery = '%' + normalizedQuery + '%';
        List<User> users = [
            SELECT Id, Name, Username, Email, IsActive, Profile.Name
            FROM User
            WHERE Name LIKE :likeQuery
                OR Username LIKE :likeQuery
                OR Email LIKE :likeQuery
            ORDER BY Name
            LIMIT 20
        ];

        List<UserSearchResult> results = new List<UserSearchResult>();
        for (User userRecord : users) {
            results.add(new UserSearchResult(userRecord));
        }

        return results;
    }
}
