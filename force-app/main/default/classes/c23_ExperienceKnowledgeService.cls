public with sharing class c23_ExperienceKnowledgeService {
    public class FacetOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
    }

    public class KnowledgeArticleItem {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String summary;
        @AuraEnabled public String urlName;
        @AuraEnabled public String category;
        @AuraEnabled public Datetime lastModifiedDate;
    }

    public class KnowledgeSearchResponse {
        @AuraEnabled public List<KnowledgeArticleItem> items = new List<KnowledgeArticleItem>();
        @AuraEnabled public List<FacetOption> facets = new List<FacetOption>();
    }

    public class KnowledgeArticleDetail {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String summary;
        @AuraEnabled public String body;
        @AuraEnabled public String urlName;
        @AuraEnabled public Datetime lastModifiedDate;
    }

    public interface SummaryProvider {
        String summarize(String articleId, String content);
    }

    public class PlaceholderSummaryProvider implements SummaryProvider {
        public String summarize(String articleId, String content) {
            return 'AI Summary (placeholder): Article ' + articleId +
                ' discusses key points, recommended actions, and next steps. Configure a provider in c23_ExperienceKnowledgeService to replace this summary.';
        }
    }

    @AuraEnabled(cacheable=true)
    public static KnowledgeSearchResponse searchArticles(String query, String categoryFilter) {
        KnowledgeSearchResponse response = new KnowledgeSearchResponse();
        if (!Schema.getGlobalDescribe().containsKey('Knowledge__kav')) {
            return response;
        }

        String term = '%' + (String.isBlank(query) ? '' : String.escapeSingleQuotes(query.trim())) + '%';
        List<SObject> rows = Database.query(
            'SELECT Id, Title, Summary, UrlName, LastModifiedDate ' +
            'FROM Knowledge__kav ' +
            'WHERE PublishStatus = \'Online\' ' +
            'AND (Title LIKE :term OR Summary LIKE :term) ' +
            'ORDER BY LastModifiedDate DESC ' +
            'LIMIT 30'
        );

        Integer howToCount = 0;
        Integer troubleshootingCount = 0;
        Integer generalCount = 0;

        for (SObject row : rows) {
            KnowledgeArticleItem item = new KnowledgeArticleItem();
            item.id = (String) row.get('Id');
            item.title = (String) row.get('Title');
            item.summary = (String) row.get('Summary');
            item.urlName = (String) row.get('UrlName');
            item.lastModifiedDate = (Datetime) row.get('LastModifiedDate');
            item.category = inferCategory(item.title, item.summary);

            if (item.category == 'How-To') {
                howToCount++;
            } else if (item.category == 'Troubleshooting') {
                troubleshootingCount++;
            } else {
                generalCount++;
            }

            if (String.isBlank(categoryFilter) || categoryFilter == 'All' || categoryFilter == item.category) {
                response.items.add(item);
            }
        }

        response.facets.add(buildFacet('All', 'All', rows.size()));
        response.facets.add(buildFacet('How-To', 'How-To', howToCount));
        response.facets.add(buildFacet('Troubleshooting', 'Troubleshooting', troubleshootingCount));
        response.facets.add(buildFacet('General', 'General', generalCount));

        return response;
    }

    @AuraEnabled(cacheable=true)
    public static KnowledgeArticleDetail getArticleDetail(String articleId) {
        KnowledgeArticleDetail detail = new KnowledgeArticleDetail();
        if (String.isBlank(articleId) || !Schema.getGlobalDescribe().containsKey('Knowledge__kav')) {
            return detail;
        }

        List<SObject> rows = Database.query(
            'SELECT Id, Title, Summary, UrlName, LastModifiedDate ' +
            'FROM Knowledge__kav WHERE Id = :articleId LIMIT 1'
        );

        if (!rows.isEmpty()) {
            SObject row = rows[0];
            detail.id = (String) row.get('Id');
            detail.title = (String) row.get('Title');
            detail.summary = (String) row.get('Summary');
            detail.urlName = (String) row.get('UrlName');
            detail.lastModifiedDate = (Datetime) row.get('LastModifiedDate');
            detail.body = detail.summary;
        }

        return detail;
    }

    @AuraEnabled(cacheable=true)
    public static String getAiSummary(String articleId) {
        KnowledgeArticleDetail detail = getArticleDetail(articleId);
        SummaryProvider provider = resolveProvider();
        return provider.summarize(articleId, detail.body);
    }

    private static SummaryProvider resolveProvider() {
        return new PlaceholderSummaryProvider();
    }

    private static String inferCategory(String title, String summary) {
        String combined = ((title == null ? '' : title) + ' ' + (summary == null ? '' : summary)).toLowerCase();
        if (combined.contains('how to') || combined.contains('setup') || combined.contains('configure')) {
            return 'How-To';
        }
        if (combined.contains('error') || combined.contains('issue') || combined.contains('trouble')) {
            return 'Troubleshooting';
        }
        return 'General';
    }

    private static FacetOption buildFacet(String value, String label, Integer count) {
        FacetOption facet = new FacetOption();
        facet.value = value;
        facet.label = label;
        facet.count = count;
        return facet;
    }
}
