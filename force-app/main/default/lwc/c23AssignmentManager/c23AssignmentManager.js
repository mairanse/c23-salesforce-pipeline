import { api, LightningElement, wire } from 'lwc';
import LightningPrompt from 'lightning/prompt';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getListInfosByObjectName, getListRecordsByName } from 'lightning/uiListsApi';
import applyAssignments from '@salesforce/apex/c23_PermissionStudioAssignmentService.applyAssignments';
import getAssignmentSnapshot from '@salesforce/apex/c23_PermissionStudioAssignmentService.getAssignmentSnapshot';
import searchAssignableUsers from '@salesforce/apex/c23_PermissionStudioAssignmentService.searchAssignableUsers';
import USER_OBJECT from '@salesforce/schema/User';
import c23_PS_Assignments_AssignedUsers from '@salesforce/label/c.c23_PS_Assignments_AssignedUsers';
import c23_PS_Assignments_ApplyResult from '@salesforce/label/c.c23_PS_Assignments_ApplyResult';
import c23_PS_Assignments_ApplySuccess from '@salesforce/label/c.c23_PS_Assignments_ApplySuccess';
import c23_PS_Assignments_Column_Active from '@salesforce/label/c.c23_PS_Assignments_Column_Active';
import c23_PS_Assignments_Filter_ActiveOnly from '@salesforce/label/c.c23_PS_Assignments_Filter_ActiveOnly';
import c23_PS_Assignments_Filter_Profile from '@salesforce/label/c.c23_PS_Assignments_Filter_Profile';
import c23_PS_Assignments_LoadList from '@salesforce/label/c.c23_PS_Assignments_LoadList';
import c23_PS_Assignments_PendingAdds from '@salesforce/label/c.c23_PS_Assignments_PendingAdds';
import c23_PS_Assignments_PendingRemoves from '@salesforce/label/c.c23_PS_Assignments_PendingRemoves';
import c23_PS_Assignments_ProfileRemoveHint from '@salesforce/label/c.c23_PS_Assignments_ProfileRemoveHint';
import c23_PS_Assignments_SearchUsers from '@salesforce/label/c.c23_PS_Assignments_SearchUsers';
import c23_PS_Assignments_Subtitle from '@salesforce/label/c.c23_PS_Assignments_Subtitle';
import c23_PS_Assignments_Title from '@salesforce/label/c.c23_PS_Assignments_Title';
import c23_PS_Assignments_UserListView from '@salesforce/label/c.c23_PS_Assignments_UserListView';
import c23_PS_Explorer_Type from '@salesforce/label/c.c23_PS_Explorer_Type';
import c23_PS_Explorer_Type_PermissionSet from '@salesforce/label/c.c23_PS_Explorer_Type_PermissionSet';
import c23_PS_Explorer_Type_PermissionSetGroup from '@salesforce/label/c.c23_PS_Explorer_Type_PermissionSetGroup';
import c23_PS_Explorer_Type_Profile from '@salesforce/label/c.c23_PS_Explorer_Type_Profile';
import c23_PS_General_Add from '@salesforce/label/c.c23_PS_General_Add';
import c23_PS_General_Apply from '@salesforce/label/c.c23_PS_General_Apply';
import c23_PS_General_ChangeNote from '@salesforce/label/c.c23_PS_General_ChangeNote';
import c23_PS_General_ConfirmSave from '@salesforce/label/c.c23_PS_General_ConfirmSave';
import c23_PS_General_Error from '@salesforce/label/c.c23_PS_General_Error';
import c23_PS_General_Loading from '@salesforce/label/c.c23_PS_General_Loading';
import c23_PS_General_Name from '@salesforce/label/c.c23_PS_General_Name';
import c23_PS_General_NoResults from '@salesforce/label/c.c23_PS_General_NoResults';
import c23_PS_General_Profile from '@salesforce/label/c.c23_PS_General_Profile';
import c23_PS_General_Remove from '@salesforce/label/c.c23_PS_General_Remove';
import c23_PS_General_Reset from '@salesforce/label/c.c23_PS_General_Reset';
import c23_PS_General_Search from '@salesforce/label/c.c23_PS_General_Search';
import c23_PS_General_All from '@salesforce/label/c.c23_PS_General_All';
import c23_PS_General_ToastErrorTitle from '@salesforce/label/c.c23_PS_General_ToastErrorTitle';
import c23_PS_General_ToastSuccessTitle from '@salesforce/label/c.c23_PS_General_ToastSuccessTitle';
import c23_PS_General_Username from '@salesforce/label/c.c23_PS_General_Username';
import c23_PS_General_Yes from '@salesforce/label/c.c23_PS_General_Yes';
import c23_PS_General_No from '@salesforce/label/c.c23_PS_General_No';
import c23_PS_Ledger_ViewRecord from '@salesforce/label/c.c23_PS_Ledger_ViewRecord';
import c23_PS_ObjectMatrix_ChangedCount from '@salesforce/label/c.c23_PS_ObjectMatrix_ChangedCount';
import c23_PS_ObjectMatrix_InsertCount from '@salesforce/label/c.c23_PS_ObjectMatrix_InsertCount';
import c23_PS_ObjectMatrix_UpdateCount from '@salesforce/label/c.c23_PS_ObjectMatrix_UpdateCount';

const TYPE_PERMISSION_SET = 'PermissionSet';
const TYPE_PERMISSION_SET_GROUP = 'PermissionSetGroup';
const TYPE_PROFILE = 'Profile';
const SEARCH_LIMIT = 50;
const USER_OBJECT_API_NAME = USER_OBJECT.objectApiName;
const USER_LIST_PAGE_SIZE = 200;
const USER_LIST_OPTIONAL_FIELDS = ['User.Name', 'User.Username', 'User.Profile.Name', 'User.IsActive'];
const PROFILE_FILTER_ALL = 'ALL';

export default class C23AssignmentManager extends LightningElement {
    @api density = 'comfortable';
    _targetId;
    _targetType;
    _targetName;
    activeTargetKey = '';
    pendingTargetSync = false;

    baseRows = [];
    rows = [];
    searchRows = [];
    listViewOptions = [];
    selectedListViewApiName = '';
    activeListViewApiName = '';

    lookupSearchKey = '';
    assignedSearchKey = '';
    selectedProfileFilter = PROFILE_FILTER_ALL;
    filterActiveOnly = true;
    changeNote = '';

    isLoading = false;
    isSearching = false;
    isApplying = false;
    errorMessage = '';
    applyResult = null;
    applyResultMessage = '';
    supportsRemoval = true;
    removalHint = '';

    labels = {
        assignedUsers: c23_PS_Assignments_AssignedUsers,
        apply: c23_PS_General_Apply,
        applyResult: c23_PS_Assignments_ApplyResult,
        applySuccess: c23_PS_Assignments_ApplySuccess,
        columnActive: c23_PS_Assignments_Column_Active,
        changeNote: c23_PS_General_ChangeNote,
        confirmSave: c23_PS_General_ConfirmSave,
        error: c23_PS_General_Error,
        filterActiveOnly: c23_PS_Assignments_Filter_ActiveOnly,
        filterProfile: c23_PS_Assignments_Filter_Profile,
        loading: c23_PS_General_Loading,
        loadList: c23_PS_Assignments_LoadList,
        noResults: c23_PS_General_NoResults,
        pendingAdds: c23_PS_Assignments_PendingAdds,
        pendingRemoves: c23_PS_Assignments_PendingRemoves,
        profile: c23_PS_General_Profile,
        profileRemoveHint: c23_PS_Assignments_ProfileRemoveHint,
        remove: c23_PS_General_Remove,
        reset: c23_PS_General_Reset,
        search: c23_PS_General_Search,
        searchUsers: c23_PS_Assignments_SearchUsers,
        subtitle: c23_PS_Assignments_Subtitle,
        title: c23_PS_Assignments_Title,
        toastErrorTitle: c23_PS_General_ToastErrorTitle,
        toastSuccessTitle: c23_PS_General_ToastSuccessTitle,
        type: c23_PS_Explorer_Type,
        typePermissionSet: c23_PS_Explorer_Type_PermissionSet,
        typePermissionSetGroup: c23_PS_Explorer_Type_PermissionSetGroup,
        typeProfile: c23_PS_Explorer_Type_Profile,
        add: c23_PS_General_Add,
        name: c23_PS_General_Name,
        all: c23_PS_General_All,
        no: c23_PS_General_No,
        yes: c23_PS_General_Yes,
        userListView: c23_PS_Assignments_UserListView,
        username: c23_PS_General_Username,
        viewLedger: c23_PS_Ledger_ViewRecord,
        changedCount: c23_PS_ObjectMatrix_ChangedCount,
        insertCount: c23_PS_ObjectMatrix_InsertCount,
        updateCount: c23_PS_ObjectMatrix_UpdateCount
    };

    @api
    get targetId() {
        return this._targetId;
    }

    set targetId(value) {
        this._targetId = value;
        this.scheduleTargetChange();
    }

    @api
    get targetType() {
        return this._targetType;
    }

    set targetType(value) {
        this._targetType = value;
        this.scheduleTargetChange();
    }

    @api
    get targetName() {
        return this._targetName;
    }

    set targetName(value) {
        this._targetName = value;
        this.scheduleTargetChange();
    }

    get hasTarget() {
        return Boolean(this._targetId && this._targetType);
    }

    get targetTypeLabel() {
        if (this._targetType === TYPE_PERMISSION_SET) {
            return this.labels.typePermissionSet;
        }
        if (this._targetType === TYPE_PERMISSION_SET_GROUP) {
            return this.labels.typePermissionSetGroup;
        }
        if (this._targetType === TYPE_PROFILE) {
            return this.labels.typeProfile;
        }
        return '';
    }

    get targetDisplayName() {
        return this._targetName || '';
    }

    get isResetDisabled() {
        return this.isLoading || this.isSearching || this.isApplying;
    }

    get isLoadListDisabled() {
        return !this.selectedListViewApiName || this.isLoading || this.isSearching || this.isApplying;
    }

    get profileFilterOptions() {
        const options = [{ label: this.labels.all, value: PROFILE_FILTER_ALL }];
        const profileNames = new Set();
        for (const row of this.searchRows) {
            if (row && row.profileName) {
                profileNames.add(row.profileName);
            }
        }

        const sortedProfileNames = Array.from(profileNames).sort((left, right) => left.localeCompare(right));
        for (const profileName of sortedProfileNames) {
            options.push({ label: profileName, value: profileName });
        }
        return options;
    }

    get isApplyDisabled() {
        return !this.hasPendingChanges || this.isLoading || this.isSearching || this.isApplying;
    }

    get pendingAdds() {
        return this.rows.filter((row) => row.assigned && !row.currentAssigned);
    }

    get pendingRemoves() {
        return this.rows.filter((row) => !row.assigned && row.currentAssigned);
    }

    get hasPendingChanges() {
        return this.pendingAdds.length > 0 || this.pendingRemoves.length > 0;
    }

    get pendingAddsText() {
        return `${this.labels.pendingAdds}: ${this.pendingAdds.length}`;
    }

    get pendingRemovesText() {
        return `${this.labels.pendingRemoves}: ${this.pendingRemoves.length}`;
    }

    get visibleAssignedRows() {
        const searchValue = this.assignedSearchKey.trim().toLowerCase();
        return this.rows
            .filter((row) => row.assigned)
            .filter((row) => {
                if (!searchValue) {
                    return true;
                }
                const nameValue = (row.name || '').toLowerCase();
                const usernameValue = (row.username || '').toLowerCase();
                return nameValue.includes(searchValue) || usernameValue.includes(searchValue);
            })
            .map((row) => ({
                ...row,
                canRemove: this.supportsRemoval
            }));
    }

    get hasVisibleAssignedRows() {
        return this.visibleAssignedRows.length > 0;
    }

    get filteredSearchRows() {
        return this.searchRows.filter((row) => {
            if (this.filterActiveOnly && row.isActive !== true) {
                return false;
            }
            if (this.selectedProfileFilter !== PROFILE_FILTER_ALL && row.profileName !== this.selectedProfileFilter) {
                return false;
            }
            return true;
        });
    }

    get decoratedSearchRows() {
        return this.filteredSearchRows.map((row) => {
            const localRow = this.findRow(row.userId);
            const isAssigned = localRow ? localRow.assigned : false;
            return {
                ...row,
                activeText: row.isActive ? this.labels.yes : this.labels.no,
                isAddDisabled: isAssigned
            };
        });
    }

    get hasSearchRows() {
        return this.decoratedSearchRows.length > 0;
    }

    get showApplyResult() {
        return this.applyResultMessage !== '';
    }

    get hasLedgerId() {
        return Boolean(this.applyResult && this.applyResult.ledgerId);
    }

    get ledgerRecordUrl() {
        return this.hasLedgerId ? `/lightning/r/c23_PermissionStudioChange__c/${this.applyResult.ledgerId}/view` : '';
    }

    get applyChangedCountText() {
        return this.applyResult ? String(this.applyResult.changedCount || 0) : '0';
    }

    get applyInsertCountText() {
        return this.applyResult ? String(this.applyResult.insertCount || 0) : '0';
    }

    get applyUpdateCountText() {
        return this.applyResult ? String(this.applyResult.updateCount || 0) : '0';
    }

    get densityClass() {
        return this.density === 'compact' ? 'density-compact' : 'density-comfortable';
    }

    get searchTableWrapClass() {
        return `c23-assignment__table-wrap ${this.densityClass}`;
    }

    get assignedTableWrapClass() {
        return `c23-assignment__table-wrap ${this.densityClass}`;
    }

    @wire(getListInfosByObjectName, { objectApiName: USER_OBJECT_API_NAME, pageSize: USER_LIST_PAGE_SIZE })
    wiredUserListViews({ data, error }) {
        if (data) {
            this.listViewOptions = this.normalizeListViewOptions(data);
            if (!this.selectedListViewApiName && this.listViewOptions.length > 0) {
                this.selectedListViewApiName = this.listViewOptions[0].value;
            }
            return;
        }

        if (error) {
            this.listViewOptions = [];
            this.showErrorToast(this.resolveErrorMessage(error));
        }
    }

    @wire(getListRecordsByName, {
        objectApiName: USER_OBJECT_API_NAME,
        listViewApiName: '$activeListViewApiName',
        optionalFields: USER_LIST_OPTIONAL_FIELDS,
        pageSize: USER_LIST_PAGE_SIZE
    })
    wiredUserListRecords({ data, error }) {
        if (!this.activeListViewApiName) {
            return;
        }

        this.isSearching = false;
        if (data) {
            this.searchRows = this.normalizeListViewRows(data);
            return;
        }

        if (error) {
            this.searchRows = [];
            this.errorMessage = this.resolveErrorMessage(error);
            this.showErrorToast(this.errorMessage);
        }
    }

    scheduleTargetChange() {
        if (this.pendingTargetSync) {
            return;
        }
        this.pendingTargetSync = true;
        Promise.resolve().then(() => {
            this.pendingTargetSync = false;
            this.handleTargetChange();
        });
    }

    handleTargetChange() {
        const targetKey = `${this._targetType || ''}:${this._targetId || ''}`;
        if (!this.hasTarget) {
            this.activeTargetKey = '';
            this.resetState();
            return;
        }

        if (targetKey === this.activeTargetKey) {
            return;
        }

        this.activeTargetKey = targetKey;
        this.lookupSearchKey = '';
        this.assignedSearchKey = '';
        this.selectedProfileFilter = PROFILE_FILTER_ALL;
        this.filterActiveOnly = true;
        this.changeNote = '';
        this.loadSnapshot();
    }

    async loadSnapshot() {
        if (!this.hasTarget) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        this.applyResult = null;
        this.applyResultMessage = '';
        this.searchRows = [];

        try {
            const response = await getAssignmentSnapshot({
                targetType: this._targetType,
                targetId: this._targetId
            });

            this.supportsRemoval = response && response.supportsRemoval === true;
            this.removalHint = response && response.removalHint ? response.removalHint : this.labels.profileRemoveHint;

            const assignedUsers = response && response.assignedUsers ? response.assignedUsers : [];
            this.baseRows = assignedUsers.map((row) => this.toLocalRow(row, true, true));
            this.rows = this.baseRows.map((row) => ({ ...row }));
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.baseRows = [];
            this.rows = [];
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isLoading = false;
        }
    }

    handleLookupSearchChange(event) {
        this.lookupSearchKey = event.target.value || '';
    }

    handleAssignedSearchChange(event) {
        this.assignedSearchKey = event.target.value || '';
    }

    handleListViewChange(event) {
        this.selectedListViewApiName = event.detail && event.detail.value ? event.detail.value : '';
    }

    handleActiveOnlyChange(event) {
        this.filterActiveOnly = event.target.checked;
    }

    handleProfileFilterChange(event) {
        this.selectedProfileFilter = event.detail && event.detail.value ? event.detail.value : PROFILE_FILTER_ALL;
    }

    handleLoadList() {
        if (!this.selectedListViewApiName) {
            return;
        }

        this.errorMessage = '';
        this.isSearching = true;
        this.searchRows = [];
        this.activeListViewApiName = this.selectedListViewApiName;
    }

    async handleSearchUsers() {
        const searchValue = this.lookupSearchKey.trim();
        if (!searchValue) {
            this.searchRows = [];
            return;
        }

        this.isSearching = true;
        this.errorMessage = '';
        try {
            const results = await searchAssignableUsers({
                searchKey: searchValue,
                maxResults: SEARCH_LIMIT
            });
            this.activeListViewApiName = '';
            this.selectedProfileFilter = PROFILE_FILTER_ALL;
            this.searchRows = (results || []).map((row) => this.toLookupRow(row));
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.searchRows = [];
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isSearching = false;
        }
    }

    handleAddUser(event) {
        const userId = event.currentTarget.dataset.userId;
        if (!userId) {
            return;
        }

        const existing = this.findRow(userId);
        if (existing) {
            existing.assigned = true;
            this.rows = [...this.rows];
            return;
        }

        const source = this.searchRows.find((row) => row.userId === userId);
        if (!source) {
            return;
        }

        this.rows = [...this.rows, this.toLocalRow(source, true, false)];
    }

    handleRemoveUser(event) {
        if (!this.supportsRemoval) {
            return;
        }

        const userId = event.currentTarget.dataset.userId;
        const existing = this.findRow(userId);
        if (!existing) {
            return;
        }

        existing.assigned = false;
        this.rows = [...this.rows];
    }

    async handleReset() {
        this.rows = this.baseRows.map((row) => ({ ...row }));
        this.searchRows = [];
        this.lookupSearchKey = '';
        this.assignedSearchKey = '';
        this.activeListViewApiName = '';
        this.selectedProfileFilter = PROFILE_FILTER_ALL;
        this.filterActiveOnly = true;
        this.changeNote = '';
        this.applyResult = null;
        this.applyResultMessage = '';
        this.errorMessage = '';
    }

    async handleApply() {
        if (this.isApplyDisabled) {
            return;
        }

        const changeNoteValue = await LightningPrompt.open({
            label: this.labels.changeNote,
            message: this.labels.confirmSave,
            defaultValue: this.changeNote || ''
        });
        if (changeNoteValue === null) {
            return;
        }
        this.changeNote = changeNoteValue;

        this.isApplying = true;
        this.errorMessage = '';
        this.applyResult = null;
        this.applyResultMessage = '';

        try {
            const assignUserIds = this.pendingAdds.map((row) => row.userId);
            const unassignUserIds = this.pendingRemoves.map((row) => row.userId);

            const response = await applyAssignments({
                targetType: this._targetType,
                targetId: this._targetId,
                assignUserIds,
                unassignUserIds,
                changeNote: changeNoteValue
            });

            this.applyResult = response;
            this.applyResultMessage = response && response.message ? response.message : this.labels.applySuccess;
            this.showSuccessToast(this.applyResultMessage);
            await this.loadSnapshot();
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isApplying = false;
        }
    }

    toLocalRow(source, assigned, currentAssigned) {
        return {
            userId: source.userId,
            name: source.name,
            username: source.username,
            profileName: source.profileName,
            assigned,
            currentAssigned
        };
    }

    toLookupRow(source) {
        return {
            userId: source.userId,
            name: source.name,
            username: source.username,
            profileName: source.profileName || '',
            isActive: source.isActive !== false
        };
    }

    normalizeListViewOptions(data) {
        const rawLists = Array.isArray(data && data.lists) ? data.lists : Object.values((data && data.lists) || {});
        const options = [];
        for (const rawList of rawLists) {
            const listInfo = rawList && rawList.info ? rawList.info : rawList;
            const value = listInfo && listInfo.apiName ? listInfo.apiName : '';
            const label = listInfo && listInfo.label ? listInfo.label : value;
            if (!value) {
                continue;
            }
            options.push({ label, value });
        }

        options.sort((left, right) => left.label.localeCompare(right.label));
        return options;
    }

    normalizeListViewRows(data) {
        const recordCollection = data && data.records ? data.records : null;
        const records = Array.isArray(recordCollection && recordCollection.records)
            ? recordCollection.records
            : Array.isArray(data && data.records)
              ? data.records
              : [];

        const rows = [];
        for (const record of records) {
            const userId = record && record.id ? record.id : '';
            if (!userId) {
                continue;
            }

            rows.push(
                this.toLookupRow({
                    userId,
                    name: this.recordFieldText(record, 'Name'),
                    username: this.recordFieldText(record, 'Username'),
                    profileName: this.recordFieldText(record, 'Profile.Name'),
                    isActive: this.recordFieldBoolean(record, 'IsActive')
                })
            );
        }

        rows.sort((left, right) => {
            const leftSort = `${left.name || ''}|${left.username || ''}`.toLowerCase();
            const rightSort = `${right.name || ''}|${right.username || ''}`.toLowerCase();
            if (leftSort === rightSort) {
                return 0;
            }
            return leftSort < rightSort ? -1 : 1;
        });
        return rows;
    }

    recordFieldText(record, fieldApiName) {
        const fields = record && record.fields ? record.fields : {};
        const field = fields[fieldApiName];
        if (!field) {
            return '';
        }
        if (field.displayValue !== undefined && field.displayValue !== null) {
            return String(field.displayValue);
        }
        if (field.value !== undefined && field.value !== null) {
            return String(field.value);
        }
        return '';
    }

    recordFieldBoolean(record, fieldApiName) {
        const fields = record && record.fields ? record.fields : {};
        const field = fields[fieldApiName];
        if (!field) {
            return false;
        }
        if (field.value === true || field.displayValue === true) {
            return true;
        }
        if (field.value === false || field.displayValue === false) {
            return false;
        }
        const textValue = field.value !== undefined && field.value !== null ? String(field.value).toLowerCase() : '';
        return textValue === 'true';
    }

    findRow(userId) {
        return this.rows.find((row) => row.userId === userId) || null;
    }

    resolveErrorMessage(error) {
        const bodyMessage = error && error.body && error.body.message ? error.body.message : '';
        return bodyMessage || this.labels.error;
    }

    showSuccessToast(message) {
        this.dispatchToast(this.labels.toastSuccessTitle, message, 'success');
    }

    showErrorToast(message) {
        this.dispatchToast(this.labels.toastErrorTitle, message, 'error');
    }

    dispatchToast(title, message, variant) {
        if (!message) {
            return;
        }
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    resetState() {
        this.baseRows = [];
        this.rows = [];
        this.searchRows = [];
        this.lookupSearchKey = '';
        this.assignedSearchKey = '';
        this.activeListViewApiName = '';
        this.selectedProfileFilter = PROFILE_FILTER_ALL;
        this.filterActiveOnly = true;
        this.changeNote = '';
        this.isLoading = false;
        this.isSearching = false;
        this.isApplying = false;
        this.errorMessage = '';
        this.applyResult = null;
        this.applyResultMessage = '';
        this.supportsRemoval = true;
        this.removalHint = '';
    }
}