import { api, LightningElement } from 'lwc';
import LightningPrompt from 'lightning/prompt';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import applyObjectMatrixJsonEnvelope from '@salesforce/apex/c23_PermissionStudioObjectPermService.applyObjectMatrixJsonEnvelope';
import getObjectMatrix from '@salesforce/apex/c23_PermissionStudioObjectPermService.getObjectMatrix';
import c23_PS_Error_InvalidPermissionSet from '@salesforce/label/c.c23_PS_Error_InvalidPermissionSet';
import c23_PS_General_Apply from '@salesforce/label/c.c23_PS_General_Apply';
import c23_PS_General_ApplyNoChangesDetected from '@salesforce/label/c.c23_PS_General_ApplyNoChangesDetected';
import c23_PS_General_ChangeNote from '@salesforce/label/c.c23_PS_General_ChangeNote';
import c23_PS_General_ConfirmSave from '@salesforce/label/c.c23_PS_General_ConfirmSave';
import c23_PS_General_Error from '@salesforce/label/c.c23_PS_General_Error';
import c23_PS_General_Loading from '@salesforce/label/c.c23_PS_General_Loading';
import c23_PS_General_ToastErrorTitle from '@salesforce/label/c.c23_PS_General_ToastErrorTitle';
import c23_PS_General_ToastSuccessTitle from '@salesforce/label/c.c23_PS_General_ToastSuccessTitle';
import c23_PS_Ledger_Truncated from '@salesforce/label/c.c23_PS_Ledger_Truncated';
import c23_PS_Ledger_ViewRecord from '@salesforce/label/c.c23_PS_Ledger_ViewRecord';
import c23_PS_ObjectMatrix_ApplyResult from '@salesforce/label/c.c23_PS_ObjectMatrix_ApplyResult';
import c23_PS_ObjectMatrix_ApplySuccess from '@salesforce/label/c.c23_PS_ObjectMatrix_ApplySuccess';
import c23_PS_ObjectMatrix_ChangedCount from '@salesforce/label/c.c23_PS_ObjectMatrix_ChangedCount';
import c23_PS_ObjectMatrix_Column_Create from '@salesforce/label/c.c23_PS_ObjectMatrix_Column_Create';
import c23_PS_ObjectMatrix_Column_Delete from '@salesforce/label/c.c23_PS_ObjectMatrix_Column_Delete';
import c23_PS_ObjectMatrix_Column_Edit from '@salesforce/label/c.c23_PS_ObjectMatrix_Column_Edit';
import c23_PS_ObjectMatrix_Column_ModifyAll from '@salesforce/label/c.c23_PS_ObjectMatrix_Column_ModifyAll';
import c23_PS_ObjectMatrix_Column_Object from '@salesforce/label/c.c23_PS_ObjectMatrix_Column_Object';
import c23_PS_ObjectMatrix_Column_Read from '@salesforce/label/c.c23_PS_ObjectMatrix_Column_Read';
import c23_PS_ObjectMatrix_Column_ViewAllFields from '@salesforce/label/c.c23_PS_ObjectMatrix_Column_ViewAllFields';
import c23_PS_ObjectMatrix_Column_ViewAll from '@salesforce/label/c.c23_PS_ObjectMatrix_Column_ViewAll';
import c23_PS_ObjectMatrix_Filter_AccessOnly from '@salesforce/label/c.c23_PS_ObjectMatrix_Filter_AccessOnly';
import c23_PS_ObjectMatrix_Filter_CustomOnly from '@salesforce/label/c.c23_PS_ObjectMatrix_Filter_CustomOnly';
import c23_PS_ObjectMatrix_Filter_DifferencesOnly from '@salesforce/label/c.c23_PS_ObjectMatrix_Filter_DifferencesOnly';
import c23_PS_ObjectMatrix_InsertCount from '@salesforce/label/c.c23_PS_ObjectMatrix_InsertCount';
import c23_PS_ObjectMatrix_NoPermissionSetSelected from '@salesforce/label/c.c23_PS_ObjectMatrix_NoPermissionSetSelected';
import c23_PS_ObjectMatrix_NoRows from '@salesforce/label/c.c23_PS_ObjectMatrix_NoRows';
import c23_PS_ObjectMatrix_ObjectApiName from '@salesforce/label/c.c23_PS_ObjectMatrix_ObjectApiName';
import c23_PS_ObjectMatrix_SearchObjects from '@salesforce/label/c.c23_PS_ObjectMatrix_SearchObjects';
import c23_PS_ObjectMatrix_SelectAll from '@salesforce/label/c.c23_PS_ObjectMatrix_SelectAll';
import c23_PS_ObjectMatrix_UpdateCount from '@salesforce/label/c.c23_PS_ObjectMatrix_UpdateCount';

const SEARCH_DEBOUNCE_MS = 200;

export default class C23ObjectMatrixEditor extends LightningElement {
    @api permissionSetName;
    @api density = 'comfortable';

    _permissionSetId;
    rows = [];
    isLoading = false;
    isApplying = false;
    errorMessage = '';
    applyResultMessage = '';
    changeNote = '';
    applyResult = null;

    filterCustomOnly = false;
    filterAccessOnly = false;
    filterDifferencesOnly = false;
    searchKeyInput = '';
    searchKey = '';
    isTableScrolled = false;

    searchDebounceHandle;
    lastEditorStateToken = '';

    labels = {
        apply: c23_PS_General_Apply,
        applyNoChangesDetected: c23_PS_General_ApplyNoChangesDetected,
        changeNote: c23_PS_General_ChangeNote,
        confirmSave: c23_PS_General_ConfirmSave,
        error: c23_PS_General_Error,
        invalidPermissionSet: c23_PS_Error_InvalidPermissionSet,
        loading: c23_PS_General_Loading,
        toastErrorTitle: c23_PS_General_ToastErrorTitle,
        toastSuccessTitle: c23_PS_General_ToastSuccessTitle,
        viewLedger: c23_PS_Ledger_ViewRecord,
        applyResult: c23_PS_ObjectMatrix_ApplyResult,
        applySuccess: c23_PS_ObjectMatrix_ApplySuccess,
        changedCount: c23_PS_ObjectMatrix_ChangedCount,
        columnCreate: c23_PS_ObjectMatrix_Column_Create,
        columnDelete: c23_PS_ObjectMatrix_Column_Delete,
        columnEdit: c23_PS_ObjectMatrix_Column_Edit,
        columnModifyAll: c23_PS_ObjectMatrix_Column_ModifyAll,
        columnObject: c23_PS_ObjectMatrix_Column_Object,
        columnObjectApiName: c23_PS_ObjectMatrix_ObjectApiName,
        columnRead: c23_PS_ObjectMatrix_Column_Read,
        columnViewAllFields: c23_PS_ObjectMatrix_Column_ViewAllFields,
        columnViewAll: c23_PS_ObjectMatrix_Column_ViewAll,
        filterAccessOnly: c23_PS_ObjectMatrix_Filter_AccessOnly,
        filterCustomOnly: c23_PS_ObjectMatrix_Filter_CustomOnly,
        filterDifferencesOnly: c23_PS_ObjectMatrix_Filter_DifferencesOnly,
        insertCount: c23_PS_ObjectMatrix_InsertCount,
        noPermissionSetSelected: c23_PS_ObjectMatrix_NoPermissionSetSelected,
        noRows: c23_PS_ObjectMatrix_NoRows,
        searchObjects: c23_PS_ObjectMatrix_SearchObjects,
        selectAll: c23_PS_ObjectMatrix_SelectAll,
        updateCount: c23_PS_ObjectMatrix_UpdateCount,
        ledgerTruncated: c23_PS_Ledger_Truncated
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

    renderedCallback() {
        this.notifyEditorStateIfChanged();
    }

    disconnectedCallback() {
        window.clearTimeout(this.searchDebounceHandle);
    }

    @api
    async applyChanges() {
        await this.handleApply();
    }

    @api
    async resetChanges() {
        await this.handleReset();
    }

    get hasPermissionSet() {
        return Boolean(this._permissionSetId);
    }

    get showNoPermissionSet() {
        return !this.hasPermissionSet;
    }

    get visibleRows() {
        return this.rows.filter((row) => this.rowPassesFilters(row));
    }

    get hasVisibleRows() {
        return this.visibleRows.length > 0;
    }

    get isAllPermissionsSelected() {
        return (
            this.hasVisibleRows &&
            this.visibleRows.every(
                (row) =>
                    row.permissionsRead === true &&
                    row.permissionsCreate === true &&
                    row.permissionsEdit === true &&
                    row.permissionsDelete === true &&
                    row.permissionsViewAllFields === true &&
                    row.permissionsViewAllRecords === true &&
                    row.permissionsModifyAllRecords === true
            )
        );
    }

    get isReadColumnSelected() {
        return this.hasVisibleRows && this.visibleRows.every((row) => row.permissionsRead === true);
    }

    get isCreateColumnSelected() {
        return this.hasVisibleRows && this.visibleRows.every((row) => row.permissionsCreate === true);
    }

    get isEditColumnSelected() {
        return this.hasVisibleRows && this.visibleRows.every((row) => row.permissionsEdit === true);
    }

    get isDeleteColumnSelected() {
        return this.hasVisibleRows && this.visibleRows.every((row) => row.permissionsDelete === true);
    }

    get isViewAllFieldsColumnSelected() {
        return this.hasVisibleRows && this.visibleRows.every((row) => row.permissionsViewAllFields === true);
    }

    get isViewAllColumnSelected() {
        return this.hasVisibleRows && this.visibleRows.every((row) => row.permissionsViewAllRecords === true);
    }

    get isModifyAllColumnSelected() {
        return this.hasVisibleRows && this.visibleRows.every((row) => row.permissionsModifyAllRecords === true);
    }

    get selectAllReadLabel() {
        return `${this.labels.selectAll} ${this.labels.columnRead}`;
    }

    get selectAllCreateLabel() {
        return `${this.labels.selectAll} ${this.labels.columnCreate}`;
    }

    get selectAllEditLabel() {
        return `${this.labels.selectAll} ${this.labels.columnEdit}`;
    }

    get selectAllDeleteLabel() {
        return `${this.labels.selectAll} ${this.labels.columnDelete}`;
    }

    get selectAllViewAllFieldsLabel() {
        return `${this.labels.selectAll} ${this.labels.columnViewAllFields}`;
    }

    get selectAllViewAllLabel() {
        return `${this.labels.selectAll} ${this.labels.columnViewAll}`;
    }

    get selectAllModifyAllLabel() {
        return `${this.labels.selectAll} ${this.labels.columnModifyAll}`;
    }

    get showNoRows() {
        return this.hasPermissionSet && !this.isLoading && !this.hasVisibleRows;
    }

    get pendingRows() {
        return this.rows.filter((row) => this.rowHasDifference(row));
    }

    get pendingCount() {
        return this.pendingRows.length;
    }

    get hasPendingChanges() {
        return this.pendingCount > 0;
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

    get controlsClass() {
        return this.isTableScrolled ? 'c23-matrix__controls c23-matrix__controls_scrolled' : 'c23-matrix__controls';
    }

    get tableShellClass() {
        const classes = ['c23-matrix__table-shell', this.densityClass];
        if (this.isTableScrolled) {
            classes.push('c23-matrix__table-shell_scrolled');
        }
        return classes.join(' ');
    }

    async loadMatrix() {
        if (!this.hasPermissionSet) {
            this.rows = [];
            return;
        }
        this.isLoading = true;
        this.errorMessage = '';
        this.isTableScrolled = false;

        try {
            const data = await getObjectMatrix({ parentPermissionSetId: this._permissionSetId });
            this.rows = this.normalizeMatrixRows(data || []);
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.rows = [];
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isLoading = false;
        }
    }

    handleSearchInput(event) {
        this.searchKeyInput = event.target.value || '';
        window.clearTimeout(this.searchDebounceHandle);
        this.searchDebounceHandle = window.setTimeout(() => {
            this.searchKey = this.searchKeyInput;
        }, SEARCH_DEBOUNCE_MS);
    }

    handleTableScroll(event) {
        const scrollTop = event && event.target ? event.target.scrollTop : 0;
        this.isTableScrolled = scrollTop > 1;
    }

    handleFilterCustomOnly(event) {
        this.filterCustomOnly = event.target.checked;
    }

    handleFilterAccessOnly(event) {
        this.filterAccessOnly = event.target.checked;
    }

    handleFilterDifferencesOnly(event) {
        this.filterDifferencesOnly = event.target.checked;
    }

    handleReadToggle(event) {
        this.handlePermissionToggle(event, 'permissionsRead');
    }

    handleCreateToggle(event) {
        this.handlePermissionToggle(event, 'permissionsCreate');
    }

    handleEditToggle(event) {
        this.handlePermissionToggle(event, 'permissionsEdit');
    }

    handleDeleteToggle(event) {
        this.handlePermissionToggle(event, 'permissionsDelete');
    }

    handleViewAllFieldsToggle(event) {
        this.handlePermissionToggle(event, 'permissionsViewAllFields');
    }

    handleViewAllToggle(event) {
        this.handlePermissionToggle(event, 'permissionsViewAllRecords');
    }

    handleModifyAllToggle(event) {
        this.handlePermissionToggle(event, 'permissionsModifyAllRecords');
    }

    handleSelectAllToggle(event) {
        const checked = event.target && event.target.checked === true;
        this.applyPermissionToVisibleRows({
            permissionsRead: checked,
            permissionsCreate: checked,
            permissionsEdit: checked,
            permissionsDelete: checked,
            permissionsViewAllFields: checked,
            permissionsViewAllRecords: checked,
            permissionsModifyAllRecords: checked
        });
    }

    handleSelectAllReadToggle(event) {
        this.handleColumnSelectToggle(event, 'permissionsRead');
    }

    handleSelectAllCreateToggle(event) {
        this.handleColumnSelectToggle(event, 'permissionsCreate');
    }

    handleSelectAllEditToggle(event) {
        this.handleColumnSelectToggle(event, 'permissionsEdit');
    }

    handleSelectAllDeleteToggle(event) {
        this.handleColumnSelectToggle(event, 'permissionsDelete');
    }

    handleSelectAllViewAllFieldsToggle(event) {
        this.handleColumnSelectToggle(event, 'permissionsViewAllFields');
    }

    handleSelectAllViewAllToggle(event) {
        this.handleColumnSelectToggle(event, 'permissionsViewAllRecords');
    }

    handleSelectAllModifyAllToggle(event) {
        this.handleColumnSelectToggle(event, 'permissionsModifyAllRecords');
    }

    handleColumnSelectToggle(event, fieldName) {
        const checked = event.target && event.target.checked === true;
        this.applyPermissionToVisibleRows({ [fieldName]: checked });
    }

    applyPermissionToVisibleRows(changes) {
        if (!changes || !this.hasVisibleRows) {
            return;
        }
        const visibleApiNames = new Set(this.visibleRows.map((row) => this.safeTrimString(row.apiName)));
        this.rows = this.rows.map((row) => {
            if (!visibleApiNames.has(this.safeTrimString(row.apiName))) {
                return row;
            }
            return this.normalizeRow({ ...row, ...changes });
        });
    }

    handlePermissionToggle(event, fieldName) {
        const rowKey = this.safeTrimString(
            (event.target && event.target.name ? event.target.name : '') ||
                (event.currentTarget && event.currentTarget.name ? event.currentTarget.name : '')
        );
        if (!rowKey || !fieldName) {
            return;
        }
        const checked = event.target && event.target.checked === true;

        this.rows = this.rows.map((row) => {
            if (this.safeTrimString(row && row.apiName) !== rowKey) {
                return row;
            }
            return this.normalizeRow({ ...row, [fieldName]: checked });
        });
    }

    async handleReset() {
        this.applyResultMessage = '';
        this.applyResult = null;
        await this.loadMatrix();
    }

    async handleApply() {
        if (this.isSaveDisabled) {
            return;
        }
        if (!this.hasPermissionSet) {
            this.showErrorToast(this.labels.invalidPermissionSet);
            return;
        }
        const pendingCountBefore = this.pendingCount;

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
            const requestPayload = {
                parentPermissionSetId: this.safeTrimString(this._permissionSetId),
                permissionSetId: this.safeTrimString(this._permissionSetId),
                desiredStateRowsJson: JSON.stringify(desiredStateRows),
                changeNote: changeNoteValue
            };
            const response = await applyObjectMatrixJsonEnvelope({
                requestJson: JSON.stringify(requestPayload)
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
                apiName: this.safeTrimString(row && row.apiName),
                permissionsRead: row && row.permissionsRead === true,
                permissionsCreate: row && row.permissionsCreate === true,
                permissionsEdit: row && row.permissionsEdit === true,
                permissionsDelete: row && row.permissionsDelete === true,
                permissionsViewAllFields: row && row.permissionsViewAllFields === true,
                permissionsViewAllRecords: row && row.permissionsViewAllRecords === true,
                permissionsModifyAllRecords: row && row.permissionsModifyAllRecords === true
            }))
            .filter((row) => row.apiName !== '');
    }

    rowPassesFilters(row) {
        const searchValue = this.searchKey.trim().toLowerCase();
        const rowLabel = (row.label || '').toLowerCase();
        const rowApiName = (row.apiName || '').toLowerCase();
        if (searchValue && !rowLabel.includes(searchValue) && !rowApiName.includes(searchValue)) {
            return false;
        }
        if (this.filterCustomOnly && !row.isCustom) {
            return false;
        }
        if (this.filterAccessOnly && !this.rowHasAnyAccess(row)) {
            return false;
        }
        if (this.filterDifferencesOnly && !this.rowHasDifference(row)) {
            return false;
        }
        return true;
    }

    rowHasAnyAccess(row) {
        return (
            row.permissionsRead ||
            row.permissionsCreate ||
            row.permissionsEdit ||
            row.permissionsDelete ||
            row.permissionsViewAllFields ||
            row.permissionsViewAllRecords ||
            row.permissionsModifyAllRecords
        );
    }

    rowHasDifference(row) {
        if (!row || this.safeTrimString(row.apiName) === '') {
            return false;
        }
        return (
            row.permissionsRead !== row.currentPermissionsRead ||
            row.permissionsCreate !== row.currentPermissionsCreate ||
            row.permissionsEdit !== row.currentPermissionsEdit ||
            row.permissionsDelete !== row.currentPermissionsDelete ||
            row.permissionsViewAllFields !== row.currentPermissionsViewAllFields ||
            row.permissionsViewAllRecords !== row.currentPermissionsViewAllRecords ||
            row.permissionsModifyAllRecords !== row.currentPermissionsModifyAllRecords
        );
    }

    normalizeRow(row) {
        const normalized = { ...row };

        if (normalized.permissionsModifyAllRecords) {
            normalized.permissionsRead = true;
            normalized.permissionsCreate = true;
            normalized.permissionsEdit = true;
            normalized.permissionsDelete = true;
            normalized.permissionsViewAllFields = true;
            normalized.permissionsViewAllRecords = true;
        }

        if (normalized.permissionsViewAllFields) {
            normalized.permissionsRead = true;
        }

        if (normalized.permissionsViewAllRecords) {
            normalized.permissionsRead = true;
        }

        if (normalized.permissionsCreate || normalized.permissionsEdit || normalized.permissionsDelete) {
            normalized.permissionsRead = true;
        }

        if (!normalized.permissionsRead) {
            normalized.permissionsCreate = false;
            normalized.permissionsEdit = false;
            normalized.permissionsDelete = false;
            normalized.permissionsViewAllFields = false;
            normalized.permissionsViewAllRecords = false;
            normalized.permissionsModifyAllRecords = false;
        }

        return normalized;
    }

    normalizeMatrixRows(rawRows) {
        return rawRows.map((row) => this.normalizeIncomingRow(row));
    }

    normalizeIncomingRow(row) {
        const normalizedRow = {
            apiName: this.safeTrimString(row && row.apiName),
            label: this.safeString(row && row.label),
            isCustom: row && row.isCustom === true,
            permissionsRead: row && row.permissionsRead === true,
            permissionsCreate: row && row.permissionsCreate === true,
            permissionsEdit: row && row.permissionsEdit === true,
            permissionsDelete: row && row.permissionsDelete === true,
            permissionsViewAllFields: row && row.permissionsViewAllFields === true,
            permissionsViewAllRecords: row && row.permissionsViewAllRecords === true,
            permissionsModifyAllRecords: row && row.permissionsModifyAllRecords === true,
            currentPermissionsRead: row && row.currentPermissionsRead === true,
            currentPermissionsCreate: row && row.currentPermissionsCreate === true,
            currentPermissionsEdit: row && row.currentPermissionsEdit === true,
            currentPermissionsDelete: row && row.currentPermissionsDelete === true,
            currentPermissionsViewAllFields: row && row.currentPermissionsViewAllFields === true,
            currentPermissionsViewAllRecords: row && row.currentPermissionsViewAllRecords === true,
            currentPermissionsModifyAllRecords: row && row.currentPermissionsModifyAllRecords === true
        };

        return this.normalizeRow(normalizedRow);
    }

    safeString(value) {
        return typeof value === 'string' ? value : '';
    }

    safeTrimString(value) {
        return typeof value === 'string' ? value.trim() : '';
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

    notifyEditorStateIfChanged() {
        const stateToken = `${this.pendingCount}|${this.isSaveDisabled ? '1' : '0'}|${this.isResetDisabled ? '1' : '0'}`;
        if (stateToken === this.lastEditorStateToken) {
            return;
        }

        this.lastEditorStateToken = stateToken;
        this.dispatchEvent(
            new CustomEvent('editorstatechange', {
                detail: {
                    pendingCount: this.pendingCount,
                    canSave: !this.isSaveDisabled,
                    canReset: !this.isResetDisabled,
                    supportsGlobalActions: true
                },
                bubbles: true,
                composed: true
            })
        );
    }

    resetForNewTarget() {
        this.rows = [];
        this.errorMessage = '';
        this.applyResultMessage = '';
        this.applyResult = null;
        this.changeNote = '';
        this.filterCustomOnly = false;
        this.filterAccessOnly = false;
        this.filterDifferencesOnly = false;
        this.searchKeyInput = '';
        this.searchKey = '';
        this.isTableScrolled = false;
        this.lastEditorStateToken = '';
        window.clearTimeout(this.searchDebounceHandle);
    }
}