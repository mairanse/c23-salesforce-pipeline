public with sharing class c23_ExperienceSearchService {
    public class SearchRequest {
        @AuraEnabled public String query;
        @AuraEnabled public String objectFilter;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public Integer limitSize;
    }

    public class SearchResultItem {
        @AuraEnabled public String id;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public String detail;
        @AuraEnabled public Datetime lastModifiedDate;
    }

    public class SearchGroup {
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String label;
        @AuraEnabled public List<SearchResultItem> items = new List<SearchResultItem>();
    }

    public class SearchResponse {
        @AuraEnabled public List<SearchGroup> groups = new List<SearchGroup>();
        @AuraEnabled public Integer totalCount;
    }

    @AuraEnabled(cacheable=true)
    public static SearchResponse searchPortal(SearchRequest request) {
        SearchResponse response = new SearchResponse();
        if (request == null || String.isBlank(request.query) || request.query.trim().length() < 2) {
            response.totalCount = 0;
            return response;
        }

        String term = '%' + String.escapeSingleQuotes(request.query.trim()) + '%';
        Integer rowLimit = request.limitSize == null ? 10 : Math.max(1, Math.min(50, request.limitSize));
        String objectFilter = String.isBlank(request.objectFilter) ? 'All' : request.objectFilter;
        Datetime startDt = request.startDate == null ? null : Datetime.newInstance(request.startDate, Time.newInstance(0, 0, 0, 0));
        Datetime endDt = request.endDate == null ? null : Datetime.newInstance(request.endDate, Time.newInstance(23, 59, 59, 999));

        if (objectFilter == 'All' || objectFilter == 'Case') {
            response.groups.add(searchCases(term, rowLimit, startDt, endDt));
        }
        if (objectFilter == 'All' || objectFilter == 'Asset') {
            response.groups.add(searchAssets(term, rowLimit, startDt, endDt));
        }
        if (objectFilter == 'All' || objectFilter == 'Knowledge') {
            response.groups.add(searchKnowledge(term, rowLimit, startDt, endDt));
        }
        if (objectFilter == 'All' || objectFilter == 'Order') {
            response.groups.add(searchOrders(term, rowLimit, startDt, endDt));
        }

        Integer total = 0;
        List<SearchGroup> nonEmptyGroups = new List<SearchGroup>();
        for (SearchGroup resultGroup : response.groups) {
            total += resultGroup.items.size();
            if (!resultGroup.items.isEmpty()) {
                nonEmptyGroups.add(resultGroup);
            }
        }
        response.groups = nonEmptyGroups;
        response.totalCount = total;
        return response;
    }

    private static SearchGroup searchCases(String term, Integer rowLimit, Datetime startDt, Datetime endDt) {
        SearchGroup resultGroup = initGroup('Case', 'Cases');
        String soql =
            'SELECT Id, CaseNumber, Subject, Status, LastModifiedDate ' +
            'FROM Case ' +
            'WHERE (CaseNumber LIKE :term OR Subject LIKE :term)';

        if (startDt != null) {
            soql += ' AND LastModifiedDate >= :startDt';
        }
        if (endDt != null) {
            soql += ' AND LastModifiedDate <= :endDt';
        }

        soql += ' ORDER BY LastModifiedDate DESC LIMIT :rowLimit';

        for (Case row : (List<Case>) Database.query(soql)) {
            SearchResultItem item = new SearchResultItem();
            item.id = (String) row.Id;
            item.objectApiName = 'Case';
            item.title = row.CaseNumber;
            item.subtitle = row.Subject;
            item.detail = row.Status;
            item.lastModifiedDate = row.LastModifiedDate;
            resultGroup.items.add(item);
        }
        return resultGroup;
    }

    private static SearchGroup searchAssets(String term, Integer rowLimit, Datetime startDt, Datetime endDt) {
        SearchGroup resultGroup = initGroup('Asset', 'Assets');
        String soql =
            'SELECT Id, Name, SerialNumber, Status, LastModifiedDate ' +
            'FROM Asset ' +
            'WHERE (Name LIKE :term OR SerialNumber LIKE :term)';

        if (startDt != null) {
            soql += ' AND LastModifiedDate >= :startDt';
        }
        if (endDt != null) {
            soql += ' AND LastModifiedDate <= :endDt';
        }

        soql += ' ORDER BY LastModifiedDate DESC LIMIT :rowLimit';

        for (Asset row : (List<Asset>) Database.query(soql)) {
            SearchResultItem item = new SearchResultItem();
            item.id = (String) row.Id;
            item.objectApiName = 'Asset';
            item.title = row.Name;
            item.subtitle = row.SerialNumber;
            item.detail = row.Status;
            item.lastModifiedDate = row.LastModifiedDate;
            resultGroup.items.add(item);
        }
        return resultGroup;
    }

    private static SearchGroup searchKnowledge(String term, Integer rowLimit, Datetime startDt, Datetime endDt) {
        SearchGroup resultGroup = initGroup('Knowledge', 'Knowledge');
        if (!Schema.getGlobalDescribe().containsKey('Knowledge__kav')) {
            return resultGroup;
        }

        String soql =
            'SELECT Id, Title, Summary, UrlName, LastModifiedDate ' +
            'FROM Knowledge__kav ' +
            'WHERE PublishStatus = \'Online\' ' +
            'AND (Title LIKE :term OR Summary LIKE :term)';

        if (startDt != null) {
            soql += ' AND LastModifiedDate >= :startDt';
        }
        if (endDt != null) {
            soql += ' AND LastModifiedDate <= :endDt';
        }

        soql += ' ORDER BY LastModifiedDate DESC LIMIT :rowLimit';

        for (SObject row : Database.query(soql)) {
            SearchResultItem item = new SearchResultItem();
            item.id = (String) row.get('Id');
            item.objectApiName = 'Knowledge';
            item.title = (String) row.get('Title');
            item.subtitle = (String) row.get('Summary');
            item.detail = (String) row.get('UrlName');
            item.lastModifiedDate = (Datetime) row.get('LastModifiedDate');
            resultGroup.items.add(item);
        }
        return resultGroup;
    }

    private static SearchGroup searchOrders(String term, Integer rowLimit, Datetime startDt, Datetime endDt) {
        SearchGroup resultGroup = initGroup('Order', 'Orders');
        if (!Schema.getGlobalDescribe().containsKey('Order')) {
            return resultGroup;
        }

        String soql =
            'SELECT Id, OrderNumber, Status, EffectiveDate, LastModifiedDate ' +
            'FROM Order ' +
            'WHERE (OrderNumber LIKE :term OR Status LIKE :term)';

        if (startDt != null) {
            soql += ' AND LastModifiedDate >= :startDt';
        }
        if (endDt != null) {
            soql += ' AND LastModifiedDate <= :endDt';
        }

        soql += ' ORDER BY LastModifiedDate DESC LIMIT :rowLimit';

        for (Order row : (List<Order>) Database.query(soql)) {
            SearchResultItem item = new SearchResultItem();
            item.id = (String) row.Id;
            item.objectApiName = 'Order';
            item.title = row.OrderNumber;
            item.subtitle = String.valueOf(row.EffectiveDate);
            item.detail = row.Status;
            item.lastModifiedDate = row.LastModifiedDate;
            resultGroup.items.add(item);
        }
        return resultGroup;
    }

    private static SearchGroup initGroup(String objectApiName, String label) {
        SearchGroup resultGroup = new SearchGroup();
        resultGroup.objectApiName = objectApiName;
        resultGroup.label = label;
        return resultGroup;
    }
}
