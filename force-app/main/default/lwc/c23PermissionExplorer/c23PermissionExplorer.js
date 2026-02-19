import { api, LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getExplorerData from '@salesforce/apex/c23_PermissionStudioExplorerService.getExplorerData';
import getRecentSelections from '@salesforce/apex/c23_PermissionStudioRecentService.getRecentSelections';
import saveRecentSelection from '@salesforce/apex/c23_PermissionStudioRecentService.saveRecentSelection';
import c23_PS_Explorer_Profiles from '@salesforce/label/c.c23_PS_Explorer_Profiles';
import c23_PS_Explorer_PermissionSets from '@salesforce/label/c.c23_PS_Explorer_PermissionSets';
import c23_PS_Explorer_PermissionSetGroups from '@salesforce/label/c.c23_PS_Explorer_PermissionSetGroups';
import c23_PS_Explorer_RecentTitle from '@salesforce/label/c.c23_PS_Explorer_RecentTitle';
import c23_PS_Explorer_RecentEmpty from '@salesforce/label/c.c23_PS_Explorer_RecentEmpty';
import c23_PS_Explorer_SearchResults from '@salesforce/label/c.c23_PS_Explorer_SearchResults';
import c23_PS_Explorer_SummaryTitle from '@salesforce/label/c.c23_PS_Explorer_SummaryTitle';
import c23_PS_Explorer_Tab_Groups from '@salesforce/label/c.c23_PS_Explorer_Tab_Groups';
import c23_PS_Explorer_Tab_Profiles from '@salesforce/label/c.c23_PS_Explorer_Tab_Profiles';
import c23_PS_Explorer_Tab_Recent from '@salesforce/label/c.c23_PS_Explorer_Tab_Recent';
import c23_PS_Explorer_Tab_Sets from '@salesforce/label/c.c23_PS_Explorer_Tab_Sets';
import c23_PS_Explorer_Type from '@salesforce/label/c.c23_PS_Explorer_Type';
import c23_PS_Explorer_Name from '@salesforce/label/c.c23_PS_Explorer_Name';
import c23_PS_Explorer_Count_ObjectPerms from '@salesforce/label/c.c23_PS_Explorer_Count_ObjectPerms';
import c23_PS_Explorer_Count_FieldPerms from '@salesforce/label/c.c23_PS_Explorer_Count_FieldPerms';
import c23_PS_Explorer_Count_SetupAccess from '@salesforce/label/c.c23_PS_Explorer_Count_SetupAccess';
import c23_PS_Explorer_Count_Assignments from '@salesforce/label/c.c23_PS_Explorer_Count_Assignments';
import c23_PS_Explorer_Count_PsgMembers from '@salesforce/label/c.c23_PS_Explorer_Count_PsgMembers';
import c23_PS_Explorer_Count_HasMuting from '@salesforce/label/c.c23_PS_Explorer_Count_HasMuting';
import c23_PS_Explorer_Type_Profile from '@salesforce/label/c.c23_PS_Explorer_Type_Profile';
import c23_PS_Explorer_Type_PermissionSet from '@salesforce/label/c.c23_PS_Explorer_Type_PermissionSet';
import c23_PS_Explorer_Type_PermissionSetGroup from '@salesforce/label/c.c23_PS_Explorer_Type_PermissionSetGroup';
import c23_PS_General_Error from '@salesforce/label/c.c23_PS_General_Error';
import c23_PS_General_Loading from '@salesforce/label/c.c23_PS_General_Loading';
import c23_PS_General_NoResults from '@salesforce/label/c.c23_PS_General_NoResults';
import c23_PS_General_NoSelection from '@salesforce/label/c.c23_PS_General_NoSelection';
import c23_PS_General_Refresh from '@salesforce/label/c.c23_PS_General_Refresh';
import c23_PS_General_Search from '@salesforce/label/c.c23_PS_General_Search';
import c23_PS_General_ToastErrorTitle from '@salesforce/label/c.c23_PS_General_ToastErrorTitle';
import c23_PS_General_Yes from '@salesforce/label/c.c23_PS_General_Yes';
import c23_PS_General_No from '@salesforce/label/c.c23_PS_General_No';

const TYPE_PERMISSION_SET = 'PermissionSet';
const TYPE_PROFILE = 'Profile';
const TYPE_PERMISSION_SET_GROUP = 'PermissionSetGroup';
const TAB_RECENT = 'RECENT';

export default class C23PermissionExplorer extends LightningElement {
    @api showSummary;

    labels = {
        profiles: c23_PS_Explorer_Profiles,
        permissionSets: c23_PS_Explorer_PermissionSets,
        permissionSetGroups: c23_PS_Explorer_PermissionSetGroups,
        recentTitle: c23_PS_Explorer_RecentTitle,
        recentEmpty: c23_PS_Explorer_RecentEmpty,
        searchResults: c23_PS_Explorer_SearchResults,
        summaryTitle: c23_PS_Explorer_SummaryTitle,
        tabGroups: c23_PS_Explorer_Tab_Groups,
        tabProfiles: c23_PS_Explorer_Tab_Profiles,
        tabRecent: c23_PS_Explorer_Tab_Recent,
        tabSets: c23_PS_Explorer_Tab_Sets,
        type: c23_PS_Explorer_Type,
        name: c23_PS_Explorer_Name,
        countObjectPerms: c23_PS_Explorer_Count_ObjectPerms,
        countFieldPerms: c23_PS_Explorer_Count_FieldPerms,
        countSetupAccess: c23_PS_Explorer_Count_SetupAccess,
        countAssignments: c23_PS_Explorer_Count_Assignments,
        countPsgMembers: c23_PS_Explorer_Count_PsgMembers,
        countHasMuting: c23_PS_Explorer_Count_HasMuting,
        typeProfile: c23_PS_Explorer_Type_Profile,
        typePermissionSet: c23_PS_Explorer_Type_PermissionSet,
        typePermissionSetGroup: c23_PS_Explorer_Type_PermissionSetGroup,
        error: c23_PS_General_Error,
        loading: c23_PS_General_Loading,
        noResults: c23_PS_General_NoResults,
        noSelection: c23_PS_General_NoSelection,
        refresh: c23_PS_General_Refresh,
        search: c23_PS_General_Search,
        toastErrorTitle: c23_PS_General_ToastErrorTitle,
        yes: c23_PS_General_Yes,
        no: c23_PS_General_No
    };

    searchKey = '';
    isLoading = false;
    errorMessage = '';
    activeTab = TAB_RECENT;

    permissionSets = [];
    permissionSetGroups = [];
    profiles = [];
    recentSelections = [];
    selectedItem = null;

    connectedCallback() {
        this.loadData();
    }

    get showSummaryPanel() {
        return this.showSummary !== false && this.showSummary !== 'false';
    }

    get explorerClass() {
        return this.showSummaryPanel ? 'c23-explorer' : 'c23-explorer c23-explorer--single';
    }

    get leftPaneClass() {
        return this.showSummaryPanel ? 'c23-explorer__left' : 'c23-explorer__left c23-explorer__left--embedded';
    }

    get hasSelectedItem() {
        return this.selectedItem !== null;
    }

    get selectedItemDomKey() {
        if (!this.selectedItem) {
            return '';
        }
        return `${this.selectedItem.type}-${this.selectedItem.id}`;
    }

    get summaryRows() {
        if (!this.selectedItem) {
            return [];
        }

        const rows = [
            this.summaryRow('type', this.labels.type, this.selectedItem.typeLabel),
            this.summaryRow('name', this.labels.name, this.selectedItem.displayName)
        ];

        if (this.selectedItem.type === TYPE_PERMISSION_SET || this.selectedItem.type === TYPE_PROFILE) {
            rows.push(this.summaryRow('objectPerms', this.labels.countObjectPerms, this.toCount(this.selectedItem.objectPermissionsCount)));
            rows.push(this.summaryRow('fieldPerms', this.labels.countFieldPerms, this.toCount(this.selectedItem.fieldPermissionsCount)));
            rows.push(this.summaryRow('setupAccess', this.labels.countSetupAccess, this.toCount(this.selectedItem.setupEntityAccessCount)));
            rows.push(this.summaryRow('assignments', this.labels.countAssignments, this.toCount(this.selectedItem.assignmentCount)));
        }

        if (this.selectedItem.type === TYPE_PERMISSION_SET_GROUP) {
            rows.push(this.summaryRow('members', this.labels.countPsgMembers, this.toCount(this.selectedItem.memberCount)));
            rows.push(this.summaryRow('assignments', this.labels.countAssignments, this.toCount(this.selectedItem.assignmentCount)));
            rows.push(this.summaryRow('hasMuting', this.labels.countHasMuting, this.booleanText(this.selectedItem.hasMutingPermissionSet)));
        }

        return rows;
    }

    get hasSearchKey() {
        return this.searchKey.trim() !== '';
    }

    get filteredRecentSelections() {
        return this.decorateItems(this.filterItems(this.recentSelections), 'Recent');
    }

    get hasFilteredRecentSelections() {
        return this.filteredRecentSelections.length > 0;
    }

    get searchResultItems() {
        if (!this.hasSearchKey) {
            return [];
        }

        return this.decorateItems(this.filterItems(this.allExplorerItems), 'Search');
    }

    get hasSearchResultItems() {
        return this.searchResultItems.length > 0;
    }

    get recentTabItems() {
        return this.decorateItems(this.filterItems(this.recentSelections), TAB_RECENT);
    }

    get hasRecentTabItems() {
        return this.recentTabItems.length > 0;
    }

    get showNoRecentTabItems() {
        return !this.hasRecentTabItems;
    }

    get permissionSetTabItems() {
        return this.decorateItems(this.filterItems(this.permissionSets), TYPE_PERMISSION_SET);
    }

    get hasPermissionSetTabItems() {
        return this.permissionSetTabItems.length > 0;
    }

    get showNoPermissionSetTabItems() {
        return !this.hasPermissionSetTabItems;
    }

    get permissionSetGroupTabItems() {
        return this.decorateItems(this.filterItems(this.permissionSetGroups), TYPE_PERMISSION_SET_GROUP);
    }

    get hasPermissionSetGroupTabItems() {
        return this.permissionSetGroupTabItems.length > 0;
    }

    get showNoPermissionSetGroupTabItems() {
        return !this.hasPermissionSetGroupTabItems;
    }

    get profileTabItems() {
        return this.decorateItems(this.filterItems(this.profiles), TYPE_PROFILE);
    }

    get hasProfileTabItems() {
        return this.profileTabItems.length > 0;
    }

    get showNoProfileTabItems() {
        return !this.hasProfileTabItems;
    }

    get showNoSearchResults() {
        return this.hasSearchKey && !this.hasSearchResultItems;
    }

    get allExplorerItems() {
        return [...this.permissionSetGroups, ...this.permissionSets, ...this.profiles];
    }

    async loadData() {
        this.isLoading = true;
        this.errorMessage = '';

        try {
            const [explorerResponse, recentResponse] = await Promise.all([getExplorerData(), getRecentSelections()]);
            this.permissionSets = this.normalizePermissionSets(explorerResponse.permissionSets || []);
            this.permissionSetGroups = this.normalizePermissionSetGroups(explorerResponse.permissionSetGroups || []);
            this.profiles = this.normalizeProfiles(explorerResponse.profiles || []);
            this.recentSelections = this.normalizeRecentSelections(recentResponse || []);
            this.selectDefaultItem();
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.loadData();
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value || '';
    }

    handleTabActive(event) {
        const tabKey =
            (event && event.currentTarget && event.currentTarget.value) ||
            (event && event.target && event.target.value) ||
            (event && event.detail && event.detail.value) ||
            '';
        this.activeTab = tabKey || this.activeTab || TAB_RECENT;
        this.ensureSelectedItemVisible();
    }

    handleItemClick(event) {
        const itemId = event.currentTarget.dataset.id;
        const itemType = event.currentTarget.dataset.type;
        const selected = this.findItem(itemType, itemId);

        if (!selected) {
            return;
        }

        this.selectedItem = selected;
        this.dispatchSelectionChange();
        this.ensureSelectedItemVisible();

        if (this.isRecentTrackable(selected)) {
            this.persistRecentSelection(selected);
        }
    }

    async persistRecentSelection(selected) {
        try {
            const recentRows = await saveRecentSelection({
                itemType: selected.type,
                targetId: selected.id
            });
            this.recentSelections = this.normalizeRecentSelections(recentRows || []);
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.showErrorToast(this.errorMessage);
        }
    }

    dispatchSelectionChange() {
        if (!this.selectedItem) {
            return;
        }

        this.dispatchEvent(
            new CustomEvent('selectionchange', {
                detail: {
                    selectedItem: this.selectedItem,
                    summaryRows: this.summaryRows
                }
            })
        );
    }

    selectDefaultItem() {
        const retained = this.selectedItem ? this.findItem(this.selectedItem.type, this.selectedItem.id) : null;
        const recentSelection = this.recentSelections.length > 0 ? this.recentSelections[0] : null;
        const recentDefault = recentSelection ? this.findItem(recentSelection.type, recentSelection.id) : null;

        this.selectedItem = retained || recentDefault || null;
        this.activeTab = TAB_RECENT;
        this.dispatchSelectionChange();
        this.ensureSelectedItemVisible();
    }

    filterItems(items) {
        const search = this.searchKey.trim().toLowerCase();
        if (!search) {
            return items;
        }

        return items.filter((item) => item.displayName.toLowerCase().includes(search));
    }

    decorateItems(items, sectionKey) {
        return items.map((item) => {
            const isSelected = this.selectedItem && this.selectedItem.id === item.id && this.selectedItem.type === item.type;
            const className = isSelected ? 'c23-explorer__item c23-explorer__item_selected' : 'c23-explorer__item';
            const domKey = `${item.type}-${item.id}`;
            return {
                ...item,
                buttonClass: className,
                key: `${sectionKey}-${item.type}-${item.id}`,
                domKey
            };
        });
    }

    findItem(itemType, itemId) {
        if (itemType === TYPE_PERMISSION_SET) {
            return this.permissionSets.find((item) => item.id === itemId) || null;
        }
        if (itemType === TYPE_PROFILE) {
            return this.profiles.find((item) => item.id === itemId) || null;
        }
        if (itemType === TYPE_PERMISSION_SET_GROUP) {
            return this.permissionSetGroups.find((item) => item.id === itemId) || null;
        }
        return null;
    }

    normalizePermissionSets(items) {
        return items
            .filter((item) => item.isOwnedByProfile !== true)
            .map((item) => ({
                ...item,
                id: item.id,
                type: TYPE_PERMISSION_SET,
                typeLabel: this.labels.typePermissionSet,
                typeChipClass: 'c23-explorer__type-chip c23-explorer__type-chip_permset',
                displayName: item.label || item.apiName,
                editorPermissionSetId: item.id
            }));
    }

    normalizePermissionSetGroups(items) {
        return items.map((item) => ({
            ...item,
            id: item.id,
            type: TYPE_PERMISSION_SET_GROUP,
            typeLabel: this.labels.typePermissionSetGroup,
            typeChipClass: 'c23-explorer__type-chip c23-explorer__type-chip_psg',
            displayName: item.label || item.developerName
        }));
    }

    normalizeProfiles(items) {
        return items.map((item) => ({
            ...item,
            id: item.id,
            type: TYPE_PROFILE,
            typeLabel: this.labels.typeProfile,
            typeChipClass: 'c23-explorer__type-chip c23-explorer__type-chip_profile',
            displayName: item.name,
            editorPermissionSetId: item.ownedPermissionSetId
        }));
    }

    normalizeRecentSelections(items) {
        const rows = [];
        for (const item of items) {
            if (!item || !item.itemType || !item.targetId) {
                continue;
            }

            if (item.itemType !== TYPE_PERMISSION_SET && item.itemType !== TYPE_PROFILE) {
                continue;
            }

            rows.push({
                id: item.targetId,
                type: item.itemType,
                typeLabel: item.itemType === TYPE_PROFILE ? this.labels.typeProfile : this.labels.typePermissionSet,
                typeChipClass:
                    item.itemType === TYPE_PROFILE
                        ? 'c23-explorer__type-chip c23-explorer__type-chip_profile'
                        : 'c23-explorer__type-chip c23-explorer__type-chip_permset',
                displayName: item.displayName || item.targetId
            });
        }
        return rows;
    }

    isRecentTrackable(item) {
        return item && (item.type === TYPE_PERMISSION_SET || item.type === TYPE_PROFILE);
    }

    summaryRow(key, label, value) {
        return {
            key,
            label,
            value
        };
    }

    booleanText(value) {
        return value ? this.labels.yes : this.labels.no;
    }

    toCount(value) {
        return String(value || 0);
    }

    resolveErrorMessage(error) {
        const bodyMessage = error && error.body && error.body.message ? error.body.message : '';
        return bodyMessage || this.labels.error;
    }

    showErrorToast(message) {
        if (!message) {
            return;
        }
        this.dispatchEvent(
            new ShowToastEvent({
                title: this.labels.toastErrorTitle,
                message,
                variant: 'error'
            })
        );
    }

    ensureSelectedItemVisible() {
        const domKey = this.selectedItemDomKey;
        if (!domKey) {
            return;
        }

        window.requestAnimationFrame(() => {
            const selector = `button[data-item-key=\"${domKey}\"]`;
            const selectedButton = this.template.querySelector(selector);
            if (selectedButton) {
                selectedButton.scrollIntoView({ block: 'nearest' });
            }
        });
    }
}