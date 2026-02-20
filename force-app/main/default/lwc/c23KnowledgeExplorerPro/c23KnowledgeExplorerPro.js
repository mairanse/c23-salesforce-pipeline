import { LightningElement, track } from 'lwc';
import searchArticles from '@salesforce/apex/c23_ExperienceKnowledgeService.searchArticles';
import getArticleDetail from '@salesforce/apex/c23_ExperienceKnowledgeService.getArticleDetail';
import getAiSummary from '@salesforce/apex/c23_ExperienceKnowledgeService.getAiSummary';

export default class C23KnowledgeExplorerPro extends LightningElement {
    @track query = '';
    @track categoryFilter = 'All';
    @track facets = [];
    @track items = [];
    @track selectedArticle;
    @track aiSummary;
    @track errorMessage;
    @track isLoading = false;

    connectedCallback() {
        this.loadArticles();
    }

    get hasItems() {
        return this.items.length > 0;
    }

    get hasSelectedArticle() {
        return Boolean(this.selectedArticle?.id);
    }

    get facetOptions() {
        return this.facets.map((facet) => ({
            label: `${facet.label} (${facet.count})`,
            value: facet.value
        }));
    }

    async loadArticles() {
        this.isLoading = true;
        this.errorMessage = null;
        try {
            const response = await searchArticles({ query: this.query, categoryFilter: this.categoryFilter });
            this.items = response?.items || [];
            this.facets = response?.facets || [];
        } catch (error) {
            this.errorMessage = error?.body?.message || 'Unable to load knowledge articles.';
            this.items = [];
            this.facets = [];
        } finally {
            this.isLoading = false;
        }
    }

    handleQueryChange(event) {
        this.query = event.target.value || '';
        this.loadArticles();
    }

    handleFacetChange(event) {
        this.categoryFilter = event.detail.value;
        this.loadArticles();
    }

    async handleSelectArticle(event) {
        const articleId = event.currentTarget.dataset.id;
        if (!articleId) {
            return;
        }

        try {
            this.errorMessage = null;
            this.selectedArticle = await getArticleDetail({ articleId });
            this.aiSummary = await getAiSummary({ articleId });
        } catch (error) {
            this.errorMessage = error?.body?.message || 'Unable to load article details.';
        }
    }
}
