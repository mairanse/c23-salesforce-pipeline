import { LightningElement, track } from 'lwc';
import searchUsers from '@salesforce/apex/c23_UserPermissionSummaryService.searchUsers';

const MIN_QUERY_LENGTH = 2;
const DEBOUNCE_MS = 300;

export default class C23UserLookup extends LightningElement {
    @track results = [];
    @track errorMessage;

    query = '';
    debounceTimeout;
    showDropdown = false;

    get hasResults() {
        return this.results.length > 0;
    }

    get shouldShowDropdown() {
        return this.showDropdown && (this.hasResults || this.errorMessage);
    }

    handleInput(event) {
        this.query = event.target.value || '';
        this.errorMessage = null;

        if (this.debounceTimeout) {
            clearTimeout(this.debounceTimeout);
        }

        if (this.query.trim().length < MIN_QUERY_LENGTH) {
            this.results = [];
            this.showDropdown = false;
            return;
        }

        this.debounceTimeout = setTimeout(() => {
            this.fetchUsers();
        }, DEBOUNCE_MS);
    }

    async fetchUsers() {
        try {
            const foundUsers = await searchUsers({ query: this.query });
            this.results = foundUsers;
            this.showDropdown = true;
        } catch (error) {
            this.results = [];
            this.showDropdown = true;
            this.errorMessage = error?.body?.message || 'Unable to search users right now.';
        }
    }

    handleSelect(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selectedUser = this.results.find((user) => user.id === selectedId);

        if (!selectedUser) {
            return;
        }

        this.query = selectedUser.name;
        this.showDropdown = false;

        this.dispatchEvent(
            new CustomEvent('userselected', {
                detail: {
                    userId: selectedUser.id,
                    user: selectedUser
                }
            })
        );
    }

    handleFocus() {
        if (this.hasResults || this.errorMessage) {
            this.showDropdown = true;
        }
    }

    handleBlur() {
        setTimeout(() => {
            this.showDropdown = false;
        }, 150);
    }
}
