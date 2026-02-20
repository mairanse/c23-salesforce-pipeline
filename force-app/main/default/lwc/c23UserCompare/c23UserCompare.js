import { LightningElement, track } from 'lwc';
import getAssignmentsBulk from '@salesforce/apex/c23_UserPermissionSummaryService.getAssignmentsBulk';
import searchUsers from '@salesforce/apex/c23_UserPermissionSummaryService.searchUsers';

const MAX_USERS = 4;
const MIN_QUERY_LENGTH = 2;
const DEBOUNCE_MS = 300;

const CATEGORY_CONFIG = [
    { key: 'permissionSets', label: 'Permission Sets' },
    { key: 'permissionSetGroups', label: 'Permission Set Groups' },
    { key: 'mutingPermissionSets', label: 'Muting Permission Sets' }
];

export default class C23UserCompare extends LightningElement {
    @track selectedUsers = [];
    @track summaryByUserId = {};
    @track comparisonSections = [];
    @track searchResults = [];
    @track errorMessage;
    @track maxUsersMessage;

    query = '';
    showDropdown = false;
    debounceTimeout;
    isLoading = false;

    get hasSelectedUsers() {
        return this.selectedUsers.length > 0;
    }

    get hasComparison() {
        return this.comparisonSections.length > 0;
    }

    get canAddMoreUsers() {
        return this.selectedUsers.length < MAX_USERS;
    }

    get selectedUserIds() {
        return this.selectedUsers.map((user) => user.id);
    }

    get hasSearchResults() {
        return this.searchResults.length > 0;
    }

    get shouldShowDropdown() {
        return this.showDropdown && (this.hasSearchResults || this.errorMessage);
    }

    handleInput(event) {
        this.query = event.target.value || '';
        this.errorMessage = null;

        if (this.debounceTimeout) {
            clearTimeout(this.debounceTimeout);
        }

        if (!this.canAddMoreUsers || this.query.trim().length < MIN_QUERY_LENGTH) {
            this.searchResults = [];
            this.showDropdown = false;
            return;
        }

        this.debounceTimeout = setTimeout(() => {
            this.fetchUsers();
        }, DEBOUNCE_MS);
    }

    async fetchUsers() {
        try {
            const users = await searchUsers({ query: this.query });
            const selectedIds = new Set(this.selectedUserIds);
            this.searchResults = (users || []).filter((user) => !selectedIds.has(user.id));
            this.showDropdown = true;
        } catch (error) {
            this.searchResults = [];
            this.showDropdown = true;
            this.errorMessage = error?.body?.message || 'Unable to search users right now.';
        }
    }

    handleSelectUser(event) {
        if (!this.canAddMoreUsers) {
            this.maxUsersMessage = `You can compare up to ${MAX_USERS} users.`;
            this.showDropdown = false;
            return;
        }

        const selectedId = event.currentTarget.dataset.id;
        const selectedUser = this.searchResults.find((user) => user.id === selectedId);
        if (!selectedUser) {
            return;
        }

        this.maxUsersMessage = null;
        this.selectedUsers = [
            ...this.selectedUsers,
            {
                id: selectedUser.id,
                name: selectedUser.name,
                username: selectedUser.username,
                profileName: selectedUser.profileName || ''
            }
        ];

        this.query = '';
        this.searchResults = [];
        this.showDropdown = false;

        if (!this.canAddMoreUsers) {
            this.maxUsersMessage = `Maximum reached: compare up to ${MAX_USERS} users.`;
        }

        this.loadComparison();
    }

    handleRemoveUser(event) {
        const userId = event.currentTarget.dataset.id;
        this.selectedUsers = this.selectedUsers.filter((user) => user.id !== userId);

        if (this.canAddMoreUsers) {
            this.maxUsersMessage = null;
        }

        if (this.selectedUsers.length === 0) {
            this.summaryByUserId = {};
            this.comparisonSections = [];
            return;
        }

        this.loadComparison();
    }

    handleFocus() {
        if (this.hasSearchResults || this.errorMessage) {
            this.showDropdown = true;
        }
    }

    handleBlur() {
        setTimeout(() => {
            this.showDropdown = false;
        }, 150);
    }

    async loadComparison() {
        this.errorMessage = null;
        this.isLoading = true;

        try {
            const summaries = await getAssignmentsBulk({ userIds: this.selectedUserIds });
            this.summaryByUserId = this.buildSummaryMap(summaries || []);
            this.comparisonSections = this.buildComparisonSections();
        } catch (error) {
            this.errorMessage = error?.body?.message || 'Unable to load comparison data.';
            this.comparisonSections = [];
        } finally {
            this.isLoading = false;
        }
    }

    buildSummaryMap(summaries) {
        const map = {};
        summaries.forEach((summary) => {
            map[summary.userId] = summary;
        });
        return map;
    }

    buildComparisonSections() {
        return CATEGORY_CONFIG.map((category) => this.buildCategoryComparison(category));
    }

    buildCategoryComparison(category) {
        const userIds = this.selectedUserIds;
        const presenceByItemId = {};
        const nameByItemId = {};

        userIds.forEach((userId) => {
            const summary = this.summaryByUserId[userId] || {};
            const items = summary[category.key] || [];
            items.forEach((item) => {
                if (!presenceByItemId[item.id]) {
                    presenceByItemId[item.id] = new Set();
                }
                presenceByItemId[item.id].add(userId);
                nameByItemId[item.id] = item.name;
            });
        });

        const allItemIds = Object.keys(presenceByItemId);
        const common = [];
        const uniqueByUser = [];
        const missingByUser = [];
        const userColumns = [];

        const sortedItemIds = [...allItemIds].sort((leftId, rightId) => {
            const leftName = nameByItemId[leftId] || '';
            const rightName = nameByItemId[rightId] || '';
            return leftName.localeCompare(rightName);
        });

        sortedItemIds.forEach((itemId) => {
            if (presenceByItemId[itemId].size === userIds.length) {
                common.push({ id: itemId, name: nameByItemId[itemId] });
            }
        });

        userIds.forEach((userId) => {
            const uniqueItems = [];
            const missingItems = [];
            const assignedItems = [];

            sortedItemIds.forEach((itemId) => {
                const holders = presenceByItemId[itemId];
                const hasItem = holders.has(userId);
                if (hasItem) {
                    assignedItems.push({ id: itemId, name: nameByItemId[itemId] });
                }
                if (holders.size === 1 && hasItem) {
                    uniqueItems.push({ id: itemId, name: nameByItemId[itemId] });
                }
                if (!hasItem) {
                    missingItems.push({ id: itemId, name: nameByItemId[itemId] });
                }
            });

            const selectedUser = this.selectedUsers.find((user) => user.id === userId);
            const userName = selectedUser ? selectedUser.name : userId;

            userColumns.push({
                userId,
                userName,
                items: assignedItems,
                hasItems: assignedItems.length > 0,
                countLabel: `(${assignedItems.length})`
            });

            uniqueByUser.push({
                userId,
                userName,
                items: uniqueItems,
                hasItems: uniqueItems.length > 0,
                countLabel: `(${uniqueItems.length})`
            });

            missingByUser.push({
                userId,
                userName,
                items: missingItems,
                hasItems: missingItems.length > 0,
                countLabel: `(${missingItems.length})`
            });
        });

        return {
            key: category.key,
            label: category.label,
            common,
            hasCommon: common.length > 0,
            commonCountLabel: `(${common.length})`,
            userColumns,
            uniqueByUser,
            missingByUser
        };
    }
}
