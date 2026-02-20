import { LightningElement, track } from 'lwc';
import searchPortal from '@salesforce/apex/c23_ExperienceSearchService.searchPortal';

const DEBOUNCE_MS = 300;

export default class C23PortalGlobalSearch extends LightningElement {
    @track query = '';
    @track objectFilter = 'All';
    @track groups = [];
    @track errorMessage;
    @track isLoading = false;

    debounceTimeout;

    objectFilterOptions = [
        { label: 'All', value: 'All' },
        { label: 'Cases', value: 'Case' },
        { label: 'Orders', value: 'Order' },
        { label: 'Assets', value: 'Asset' },
        { label: 'Knowledge', value: 'Knowledge' }
    ];

    get hasResults() {
        return this.groups.length > 0;
    }

    get showEmpty() {
        return !this.isLoading && !this.errorMessage && !this.hasResults && this.query.trim().length >= 2;
    }

    handleQueryChange(event) {
        this.query = event.target.value || '';
        if (this.debounceTimeout) {
            clearTimeout(this.debounceTimeout);
        }
        if (this.query.trim().length < 2) {
            this.groups = [];
            this.errorMessage = null;
            return;
        }
        this.debounceTimeout = setTimeout(() => this.runSearch(), DEBOUNCE_MS);
    }

    handleObjectFilterChange(event) {
        this.objectFilter = event.detail.value;
        if (this.query.trim().length >= 2) {
            this.runSearch();
        }
    }

    async runSearch() {
        this.isLoading = true;
        this.errorMessage = null;
        try {
            const response = await searchPortal({
                request: {
                    query: this.query,
                    objectFilter: this.objectFilter,
                    limitSize: 8
                }
            });
            this.groups = this.buildGroups(response?.groups || []);
        } catch (error) {
            this.groups = [];
            this.errorMessage = error?.body?.message || 'Unable to search right now.';
        } finally {
            this.isLoading = false;
        }
    }

    buildGroups(rawGroups) {
        return rawGroups.map((group) => ({
            ...group,
            key: group.objectApiName,
            countLabel: `(${(group.items || []).length})`
        }));
    }
}
