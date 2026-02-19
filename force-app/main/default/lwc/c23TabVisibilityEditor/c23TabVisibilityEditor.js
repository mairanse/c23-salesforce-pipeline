import { api, LightningElement } from 'lwc';
import LightningPrompt from 'lightning/prompt';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import applyTabVisibility from '@salesforce/apex/c23_PermissionStudioTabPermService.applyTabVisibility';
import getTabVisibilityMatrix from '@salesforce/apex/c23_PermissionStudioTabPermService.getTabVisibilityMatrix';
import c23_PS_Tab_ApplySuccess from '@salesforce/label/c.c23_PS_Tab_ApplySuccess';
import c23_PS_Tab_Column_ApiName from '@salesforce/label/c.c23_PS_Tab_Column_ApiName';
import c23_PS_Tab_Column_Tab from '@salesforce/label/c.c23_PS_Tab_Column_Tab';
import c23_PS_Tab_Column_Visibility from '@salesforce/label/c.c23_PS_Tab_Column_Visibility';
import c23_PS_Tab_Subtitle from '@salesforce/label/c.c23_PS_Tab_Subtitle';
import c23_PS_Tab_Title from '@salesforce/label/c.c23_PS_Tab_Title';
import c23_PS_Tab_Visibility_DefaultOff from '@salesforce/label/c.c23_PS_Tab_Visibility_DefaultOff';
import c23_PS_Tab_Visibility_DefaultOn from '@salesforce/label/c.c23_PS_Tab_Visibility_DefaultOn';
import c23_PS_Tab_Visibility_Hidden from '@salesforce/label/c.c23_PS_Tab_Visibility_Hidden';
import c23_PS_General_Apply from '@salesforce/label/c.c23_PS_General_Apply';
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
import c23_PS_ObjectMatrix_Filter_CustomOnly from '@salesforce/label/c.c23_PS_ObjectMatrix_Filter_CustomOnly';
import c23_PS_ObjectMatrix_Filter_DifferencesOnly from '@salesforce/label/c.c23_PS_ObjectMatrix_Filter_DifferencesOnly';
import c23_PS_ObjectMatrix_InsertCount from '@salesforce/label/c.c23_PS_ObjectMatrix_InsertCount';
import c23_PS_ObjectMatrix_PermissionSet from '@salesforce/label/c.c23_PS_ObjectMatrix_PermissionSet';
import c23_PS_ObjectMatrix_UpdateCount from '@salesforce/label/c.c23_PS_ObjectMatrix_UpdateCount';

export default class C23TabVisibilityEditor extends LightningElement {
    @api permissionSetName;
    @api density = 'comfortable';

    _permissionSetId;
    rows = [];
    searchKey = '';
    filterCustomOnly = false;
    filterDifferencesOnly = false;
    isLoading = false;
    isApplying = false;
    errorMessage = '';
    changeNote = '';
    applyResult = null;
    applyResultMessage = '';

    labels = {
        title: c23_PS_Tab_Title,
        subtitle: c23_PS_Tab_Subtitle,
        columnTab: c23_PS_Tab_Column_Tab,
        columnApiName: c23_PS_Tab_Column_ApiName,
        columnVisibility: c23_PS_Tab_Column_Visibility,
        visibilityDefaultOn: c23_PS_Tab_Visibility_DefaultOn,
        visibilityDefaultOff: c23_PS_Tab_Visibility_DefaultOff,
        visibilityHidden: c23_PS_Tab_Visibility_Hidden,
        applySuccess: c23_PS_Tab_ApplySuccess,
        apply: c23_PS_General_Apply,
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
        filterCustomOnly: c23_PS_ObjectMatrix_Filter_CustomOnly,
        filterDifferencesOnly: c23_PS_ObjectMatrix_Filter_DifferencesOnly,
        insertCount: c23_PS_ObjectMatrix_InsertCount,
        permissionSet: c23_PS_ObjectMatrix_PermissionSet,
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

    get visibilityOptions() {
        return [
            { label: this.labels.visibilityDefaultOn, value: 'DefaultOn' },
            { label: this.labels.visibilityDefaultOff, value: 'DefaultOff' },
            { label: this.labels.visibilityHidden, value: 'Hidden' }
        ];
    }

    get visibleRows() {
        return this.rows.filter((row) => this.rowPassesFilters(row));
    }

    get hasVisibleRows() {
        return this.visibleRows.length > 0;
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
        return `c23-tab__table-wrap ${this.densityClass}`;
    }

    async loadMatrix() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const data = await getTabVisibilityMatrix({ parentPermissionSetId: this._permissionSetId });
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

    handleFilterCustomOnly(event) {
        this.filterCustomOnly = event.target.checked;
    }

    handleFilterDifferencesOnly(event) {
        this.filterDifferencesOnly = event.target.checked;
    }

    handleVisibilityChange(event) {
        const rowKey =
            (event.currentTarget && event.currentTarget.dataset && event.currentTarget.dataset.key) ||
            (event.target && event.target.dataset && event.target.dataset.key) ||
            '';
        if (!rowKey) {
            return;
        }
        const visibility = event.detail.value || 'DefaultOff';
        this.rows = this.rows.map((row) => {
            if (row.tabName !== rowKey) {
                return row;
            }
            return { ...row, visibility };
        });
    }

    handlePresetDefaultOn() {
        this.applyVisibilityPreset('DefaultOn');
    }

    handlePresetDefaultOff() {
        this.applyVisibilityPreset('DefaultOff');
    }

    handlePresetHidden() {
        this.applyVisibilityPreset('Hidden');
    }

    applyVisibilityPreset(visibility) {
        const visibleKeys = new Set(this.visibleRows.map((row) => row.tabName));
        this.rows = this.rows.map((row) => {
            if (!visibleKeys.has(row.tabName)) {
                return row;
            }
            return { ...row, visibility };
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
        this.applyResultMessage = '';
        try {
            const response = await applyTabVisibility({
                parentPermissionSetId: this._permissionSetId,
                desiredStateRows: this.buildDesiredStateRows(),
                changeNote: changeNoteValue
            });
            this.applyResult = response;
            this.applyResultMessage = response.message || this.labels.applySuccess;
            this.showSuccessToast(this.applyResultMessage);
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
                tabName: this.safeString(row && row.tabName),
                visibility: this.safeString(row && row.visibility)
            }))
            .filter((row) => row.tabName !== '');
    }

    rowPassesFilters(row) {
        const searchValue = this.searchKey.trim().toLowerCase();
        const labelValue = (row.tabLabel || '').toLowerCase();
        const nameValue = (row.tabName || '').toLowerCase();
        if (searchValue && !labelValue.includes(searchValue) && !nameValue.includes(searchValue)) {
            return false;
        }
        if (this.filterCustomOnly && !row.isCustom) {
            return false;
        }
        if (this.filterDifferencesOnly && !this.rowHasDifference(row)) {
            return false;
        }
        return true;
    }

    rowHasDifference(row) {
        if (!row || !row.tabName) {
            return false;
        }
        return row.visibility !== row.currentVisibility;
    }

    normalizeMatrixRows(rawRows) {
        return rawRows.map((row) => this.normalizeIncomingRow(row));
    }

    normalizeIncomingRow(row) {
        const currentVisibility = this.safeString(row && row.currentVisibility);
        const visibility = this.safeString(row && row.visibility);
        return {
            tabName: this.safeString(row && row.tabName),
            tabLabel: this.safeString(row && row.tabLabel),
            isCustom: row && row.isCustom === true,
            visibility: visibility || currentVisibility || 'DefaultOff',
            currentVisibility: currentVisibility || 'DefaultOff'
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
        this.filterCustomOnly = false;
        this.filterDifferencesOnly = false;
        this.errorMessage = '';
        this.changeNote = '';
        this.applyResult = null;
        this.applyResultMessage = '';
    }
}