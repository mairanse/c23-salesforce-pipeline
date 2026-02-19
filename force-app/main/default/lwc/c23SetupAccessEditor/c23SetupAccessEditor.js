import { api, LightningElement } from 'lwc';
import LightningPrompt from 'lightning/prompt';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import applySetupAccess from '@salesforce/apex/c23_PermissionStudioSetupAccessService.applySetupAccess';
import getSetupAccessMatrix from '@salesforce/apex/c23_PermissionStudioSetupAccessService.getSetupAccessMatrix';
import c23_PS_Setup_ApplySuccess from '@salesforce/label/c.c23_PS_Setup_ApplySuccess';
import c23_PS_Setup_Column_ApiName from '@salesforce/label/c.c23_PS_Setup_Column_ApiName';
import c23_PS_Setup_Column_Enabled from '@salesforce/label/c.c23_PS_Setup_Column_Enabled';
import c23_PS_Setup_Column_Name from '@salesforce/label/c.c23_PS_Setup_Column_Name';
import c23_PS_Setup_Column_Type from '@salesforce/label/c.c23_PS_Setup_Column_Type';
import c23_PS_Setup_Filter_Type from '@salesforce/label/c.c23_PS_Setup_Filter_Type';
import c23_PS_Setup_Filter_Type_All from '@salesforce/label/c.c23_PS_Setup_Filter_Type_All';
import c23_PS_Setup_Filter_Type_ApexClass from '@salesforce/label/c.c23_PS_Setup_Filter_Type_ApexClass';
import c23_PS_Setup_Filter_Type_CustomPermission from '@salesforce/label/c.c23_PS_Setup_Filter_Type_CustomPermission';
import c23_PS_Setup_Preset_DisableSelected from '@salesforce/label/c.c23_PS_Setup_Preset_DisableSelected';
import c23_PS_Setup_Preset_EnableSelected from '@salesforce/label/c.c23_PS_Setup_Preset_EnableSelected';
import c23_PS_Setup_Subtitle from '@salesforce/label/c.c23_PS_Setup_Subtitle';
import c23_PS_Setup_Title from '@salesforce/label/c.c23_PS_Setup_Title';
import c23_PS_General_Apply from '@salesforce/label/c.c23_PS_General_Apply';
import c23_PS_General_ApplyNoChangesDetected from '@salesforce/label/c.c23_PS_General_ApplyNoChangesDetected';
import c23_PS_General_ChangeNote from '@salesforce/label/c.c23_PS_General_ChangeNote';
import c23_PS_General_ConfirmSave from '@salesforce/label/c.c23_PS_General_ConfirmSave';
import c23_PS_General_Error from '@salesforce/label/c.c23_PS_General_Error';
import c23_PS_General_Loading from '@salesforce/label/c.c23_PS_General_Loading';
import c23_PS_General_NoPendingChanges from '@salesforce/label/c.c23_PS_General_NoPendingChanges';
import c23_PS_General_NoResults from '@salesforce/label/c.c23_PS_General_NoResults';
import c23_PS_General_PendingChanges from '@salesforce/label/c.c23_PS_General_PendingChanges';
import c23_PS_General_Reset from '@salesforce/label/c.c23_PS_General_Reset';
import c23_PS_General_Search from '@salesforce/label/c.c23_PS_General_Search';
import c23_PS_General_ToastErrorTitle from '@salesforce/label/c.c23_PS_General_ToastErrorTitle';
import c23_PS_General_ToastSuccessTitle from '@salesforce/label/c.c23_PS_General_ToastSuccessTitle';
import c23_PS_Ledger_ViewRecord from '@salesforce/label/c.c23_PS_Ledger_ViewRecord';
import c23_PS_Ledger_Truncated from '@salesforce/label/c.c23_PS_Ledger_Truncated';
import c23_PS_ObjectMatrix_ApplyResult from '@salesforce/label/c.c23_PS_ObjectMatrix_ApplyResult';
import c23_PS_ObjectMatrix_ChangeNotePlaceholder from '@salesforce/label/c.c23_PS_ObjectMatrix_ChangeNotePlaceholder';
import c23_PS_ObjectMatrix_ChangedCount from '@salesforce/label/c.c23_PS_ObjectMatrix_ChangedCount';
import c23_PS_ObjectMatrix_Filter_DifferencesOnly from '@salesforce/label/c.c23_PS_ObjectMatrix_Filter_DifferencesOnly';
import c23_PS_ObjectMatrix_InsertCount from '@salesforce/label/c.c23_PS_ObjectMatrix_InsertCount';
import c23_PS_ObjectMatrix_PermissionSet from '@salesforce/label/c.c23_PS_ObjectMatrix_PermissionSet';
import c23_PS_ObjectMatrix_SelectAll from '@salesforce/label/c.c23_PS_ObjectMatrix_SelectAll';
import c23_PS_ObjectMatrix_UpdateCount from '@salesforce/label/c.c23_PS_ObjectMatrix_UpdateCount';

export default class C23SetupAccessEditor extends LightningElement {
    @api permissionSetName;
    @api density = 'comfortable';

    _permissionSetId;
    rows = [];
    searchKey = '';
    selectedTypeFilter = 'ALL';
    filterDifferencesOnly = false;
    isLoading = false;
    isApplying = false;
    errorMessage = '';
    changeNote = '';
    applyResult = null;
    applyResultMessage = '';

    labels = {
        title: c23_PS_Setup_Title,
        subtitle: c23_PS_Setup_Subtitle,
        columnType: c23_PS_Setup_Column_Type,
        columnName: c23_PS_Setup_Column_Name,
        columnApiName: c23_PS_Setup_Column_ApiName,
        columnEnabled: c23_PS_Setup_Column_Enabled,
        filterType: c23_PS_Setup_Filter_Type,
        filterTypeAll: c23_PS_Setup_Filter_Type_All,
        filterTypeApexClass: c23_PS_Setup_Filter_Type_ApexClass,
        filterTypeCustomPermission: c23_PS_Setup_Filter_Type_CustomPermission,
        presetEnableVisible: c23_PS_Setup_Preset_EnableSelected,
        presetDisableVisible: c23_PS_Setup_Preset_DisableSelected,
        applySuccess: c23_PS_Setup_ApplySuccess,
        apply: c23_PS_General_Apply,
        applyNoChangesDetected: c23_PS_General_ApplyNoChangesDetected,
        changeNote: c23_PS_General_ChangeNote,
        confirmSave: c23_PS_General_ConfirmSave,
        error: c23_PS_General_Error,
        loading: c23_PS_General_Loading,
        noPendingChanges: c23_PS_General_NoPendingChanges,
        noResults: c23_PS_General_NoResults,
        pendingChanges: c23_PS_General_PendingChanges,
        reset: c23_PS_General_Reset,
        search: c23_PS_General_Search,
        toastErrorTitle: c23_PS_General_ToastErrorTitle,
        toastSuccessTitle: c23_PS_General_ToastSuccessTitle,
        viewLedger: c23_PS_Ledger_ViewRecord,
        ledgerTruncated: c23_PS_Ledger_Truncated,
        applyResult: c23_PS_ObjectMatrix_ApplyResult,
        changeNotePlaceholder: c23_PS_ObjectMatrix_ChangeNotePlaceholder,
        changedCount: c23_PS_ObjectMatrix_ChangedCount,
        filterDifferencesOnly: c23_PS_ObjectMatrix_Filter_DifferencesOnly,
        insertCount: c23_PS_ObjectMatrix_InsertCount,
        permissionSet: c23_PS_ObjectMatrix_PermissionSet,
        selectAll: c23_PS_ObjectMatrix_SelectAll,
        updateCount: c23_PS_ObjectMatrix_UpdateCount
    };

    @api
    get permissionSetId() {
        return this._permissionSetId;
    }

    set permissionSetId(value) {
        this._permissionSetId = value;
        this.resetForNewTarget();
        if (this._permissionSetId) {
            this.loadMatrix();
        }
    }

    get hasPermissionSet() {
        return Boolean(this._permissionSetId);
    }

    get permissionSetDisplay() {
        return this.permissionSetName || '';
    }

    get typeFilterOptions() {
        return [
            { label: this.labels.filterTypeAll, value: 'ALL' },
            { label: this.labels.filterTypeApexClass, value: 'ApexClass' },
            { label: this.labels.filterTypeCustomPermission, value: 'CustomPermission' }
        ];
    }

    get visibleRows() {
        return this.rows.filter((row) => this.rowPassesFilters(row));
    }

    get hasVisibleRows() {
        return this.visibleRows.length > 0;
    }

    get isAllEnabledSelected() {
        return this.hasVisibleRows && this.visibleRows.every((row) => row.enabled === true);
    }

    get isEnabledColumnSelected() {
        return this.isAllEnabledSelected;
    }

    get selectAllEnabledLabel() {
        return `${this.labels.selectAll} ${this.labels.columnEnabled}`;
    }

    get pendingRows() {
        return this.rows.filter((row) => this.rowHasDifference(row));
    }

    get hasPendingChanges() {
        return this.pendingRows.length > 0;
    }

    get pendingCountText() {
        return `${this.labels.pendingChanges}: ${this.pendingRows.length}`;
    }

    get showNoRows() {
        return this.hasPermissionSet && !this.isLoading && !this.hasVisibleRows;
    }

    get showNoPendingChangesMessage() {
        return !this.hasPendingChanges;
    }

    get isSaveDisabled() {
        return !this.hasPendingChanges || this.isLoading || this.isApplying;
    }

    get isResetDisabled() {
        return this.isLoading || this.isApplying;
    }

    get showApplyResult() {
        return this.applyResultMessage !== '';
    }

    get showLedgerTruncated() {
        return this.applyResult && this.applyResult.ledgerTruncated === true;
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

    get tableWrapClass() {
        return `c23-setup__table-wrap ${this.densityClass}`;
    }

    async loadMatrix() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const data = await getSetupAccessMatrix({ parentPermissionSetId: this._permissionSetId });
            this.rows = this.normalizeMatrixRows(data || []);
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.rows = [];
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isLoading = false;
        }
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value || '';
    }

    handleTypeFilterChange(event) {
        this.selectedTypeFilter = event.detail.value || 'ALL';
    }

    handleFilterDifferencesOnly(event) {
        this.filterDifferencesOnly = event.target.checked;
    }

    handleSelectAllToggle(event) {
        const checked = event.target && event.target.checked === true;
        this.applyEnabledToVisibleRows(checked);
    }

    handleSelectAllEnabledToggle(event) {
        const checked = event.target && event.target.checked === true;
        this.applyEnabledToVisibleRows(checked);
    }

    applyEnabledToVisibleRows(enabledValue) {
        if (!this.hasVisibleRows) {
            return;
        }
        const visibleKeys = new Set(this.visibleRows.map((row) => row.rowKey));
        this.rows = this.rows.map((row) => {
            if (!visibleKeys.has(row.rowKey)) {
                return row;
            }
            return { ...row, enabled: enabledValue };
        });
    }

    handleEnabledToggle(event) {
        const rowKey =
            (event.target && event.target.name ? event.target.name : '') ||
            (event.currentTarget && event.currentTarget.name ? event.currentTarget.name : '');
        if (!rowKey) {
            return;
        }
        const checked = event.target && event.target.checked === true;
        this.rows = this.rows.map((row) => {
            if (row.rowKey !== rowKey) {
                return row;
            }
            return { ...row, enabled: checked };
        });
    }

    handleEnableVisible() {
        const visibleKeys = new Set(this.visibleRows.map((row) => row.rowKey));
        this.rows = this.rows.map((row) => {
            if (!visibleKeys.has(row.rowKey)) {
                return row;
            }
            return { ...row, enabled: true };
        });
    }

    handleDisableVisible() {
        const visibleKeys = new Set(this.visibleRows.map((row) => row.rowKey));
        this.rows = this.rows.map((row) => {
            if (!visibleKeys.has(row.rowKey)) {
                return row;
            }
            return { ...row, enabled: false };
        });
    }

    async handleReset() {
        this.applyResult = null;
        this.applyResultMessage = '';
        await this.loadMatrix();
    }

    async handleApply() {
        if (this.isSaveDisabled) {
            return;
        }
        const pendingCountBefore = this.pendingRows.length;

        const changeNoteValue = await LightningPrompt.open({
            label: this.labels.changeNote,
            message: this.labels.confirmSave,
            defaultValue: this.changeNote || ''
        });
        if (changeNoteValue === null) {
            return;
        }
        this.changeNote = changeNoteValue;

        const desiredStateRows = this.buildDesiredStateRows();
        if (pendingCountBefore > 0 && desiredStateRows.length === 0) {
            this.applyResultMessage = this.labels.applyNoChangesDetected;
            this.showErrorToast(this.applyResultMessage);
            return;
        }

        this.isApplying = true;
        this.errorMessage = '';
        this.applyResultMessage = '';
        try {
            const response = await applySetupAccess({
                parentPermissionSetId: this._permissionSetId,
                desiredStateRows,
                changeNote: changeNoteValue
            });
            this.applyResult = response;
            this.applyResultMessage = response.message || this.labels.applySuccess;
            const changedCount = response && response.changedCount ? response.changedCount : 0;
            if (changedCount > 0) {
                this.showSuccessToast(this.applyResultMessage);
            } else if (pendingCountBefore > 0) {
                this.applyResultMessage = this.labels.applyNoChangesDetected;
                this.showErrorToast(this.applyResultMessage);
            } else {
                this.showInfoToast(this.applyResultMessage);
            }
            await this.loadMatrix();
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isApplying = false;
        }
    }

    buildDesiredStateRows() {
        return this.pendingRows
            .map((row) => ({
                setupEntityType: this.safeString(row && row.setupEntityType),
                setupEntityId: this.safeString(row && row.setupEntityId),
                enabled: row && row.enabled === true
            }))
            .filter((row) => row.setupEntityType !== '' && row.setupEntityId !== '');
    }

    rowPassesFilters(row) {
        const searchValue = this.searchKey.trim().toLowerCase();
        const labelValue = (row.label || '').toLowerCase();
        const apiValue = (row.apiName || '').toLowerCase();
        if (searchValue && !labelValue.includes(searchValue) && !apiValue.includes(searchValue)) {
            return false;
        }
        if (this.selectedTypeFilter !== 'ALL' && row.setupEntityType !== this.selectedTypeFilter) {
            return false;
        }
        if (this.filterDifferencesOnly && !this.rowHasDifference(row)) {
            return false;
        }
        return true;
    }

    rowHasDifference(row) {
        if (!row || !row.rowKey) {
            return false;
        }
        return row.enabled !== row.currentEnabled;
    }

    normalizeMatrixRows(rawRows) {
        return rawRows.map((row) => this.normalizeIncomingRow(row));
    }

    normalizeIncomingRow(row) {
        return {
            rowKey: this.safeString(row && row.rowKey),
            setupEntityType: this.safeString(row && row.setupEntityType),
            setupEntityId: this.safeString(row && row.setupEntityId),
            label: this.safeString(row && row.label),
            apiName: this.safeString(row && row.apiName),
            enabled: row && row.enabled === true,
            currentEnabled: row && row.currentEnabled === true
        };
    }

    safeString(value) {
        return typeof value === 'string' ? value : '';
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

    showInfoToast(message) {
        this.dispatchToast(this.labels.applyResult, message, 'info');
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

    resetForNewTarget() {
        this.rows = [];
        this.searchKey = '';
        this.selectedTypeFilter = 'ALL';
        this.filterDifferencesOnly = false;
        this.errorMessage = '';
        this.changeNote = '';
        this.applyResult = null;
        this.applyResultMessage = '';
    }
}