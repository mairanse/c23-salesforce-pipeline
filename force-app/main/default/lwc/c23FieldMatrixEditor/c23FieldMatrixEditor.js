import { api, LightningElement } from 'lwc';
import LightningConfirm from 'lightning/confirm';
import LightningPrompt from 'lightning/prompt';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import applyFieldMatrixJsonEnvelope from '@salesforce/apex/c23_PermissionStudioFieldPermService.applyFieldMatrixJsonEnvelope';
import getFieldMatrix from '@salesforce/apex/c23_PermissionStudioFieldPermService.getFieldMatrix';
import getFieldObjectOptions from '@salesforce/apex/c23_PermissionStudioFieldPermService.getFieldObjectOptions';
import applyObjectMatrixJsonEnvelope from '@salesforce/apex/c23_PermissionStudioObjectPermService.applyObjectMatrixJsonEnvelope';
import getObjectMatrix from '@salesforce/apex/c23_PermissionStudioObjectPermService.getObjectMatrix';
import applyTabVisibility from '@salesforce/apex/c23_PermissionStudioTabPermService.applyTabVisibility';
import getTabVisibilityMatrix from '@salesforce/apex/c23_PermissionStudioTabPermService.getTabVisibilityMatrix';
import c23_PS_Error_InvalidPermissionSet from '@salesforce/label/c.c23_PS_Error_InvalidPermissionSet';
import c23_PS_Field_ApplySuccess from '@salesforce/label/c.c23_PS_Field_ApplySuccess';
import c23_PS_Field_Column_Field from '@salesforce/label/c.c23_PS_Field_Column_Field';
import c23_PS_Field_Column_FieldApiName from '@salesforce/label/c.c23_PS_Field_Column_FieldApiName';
import c23_PS_Field_Column_Required from '@salesforce/label/c.c23_PS_Field_Column_Required';
import c23_PS_Field_Column_Type from '@salesforce/label/c.c23_PS_Field_Column_Type';
import c23_PS_Field_NoObjectSelected from '@salesforce/label/c.c23_PS_Field_NoObjectSelected';
import c23_PS_Field_Object from '@salesforce/label/c.c23_PS_Field_Object';
import c23_PS_Field_Preset_NONE from '@salesforce/label/c.c23_PS_Field_Preset_None';
import c23_PS_Field_Preset_RE from '@salesforce/label/c.c23_PS_Field_Preset_RE';
import c23_PS_Field_Preset_RO from '@salesforce/label/c.c23_PS_Field_Preset_RO';
import c23_PS_Field_NoTabVisibilityForObject from '@salesforce/label/c.c23_PS_Field_NoTabVisibilityForObject';
import c23_PS_Field_RecordTypes_Title from '@salesforce/label/c.c23_PS_Field_RecordTypes_Title';
import c23_PS_Field_RecordTypes_Unsupported from '@salesforce/label/c.c23_PS_Field_RecordTypes_Unsupported';
import c23_PS_Field_SwitchObjectConfirmLabel from '@salesforce/label/c.c23_PS_Field_SwitchObjectConfirmLabel';
import c23_PS_Field_SwitchObjectConfirmMessage from '@salesforce/label/c.c23_PS_Field_SwitchObjectConfirmMessage';
import c23_PS_Field_Subtitle from '@salesforce/label/c.c23_PS_Field_Subtitle';
import c23_PS_Field_Title from '@salesforce/label/c.c23_PS_Field_Title';
import c23_PS_General_Apply from '@salesforce/label/c.c23_PS_General_Apply';
import c23_PS_General_ApplyNoChangesDetected from '@salesforce/label/c.c23_PS_General_ApplyNoChangesDetected';
import c23_PS_General_ChangeNote from '@salesforce/label/c.c23_PS_General_ChangeNote';
import c23_PS_General_ConfirmSave from '@salesforce/label/c.c23_PS_General_ConfirmSave';
import c23_PS_General_Error from '@salesforce/label/c.c23_PS_General_Error';
import c23_PS_General_Loading from '@salesforce/label/c.c23_PS_General_Loading';
import c23_PS_General_No from '@salesforce/label/c.c23_PS_General_No';
import c23_PS_General_NoPendingChanges from '@salesforce/label/c.c23_PS_General_NoPendingChanges';
import c23_PS_General_NoResults from '@salesforce/label/c.c23_PS_General_NoResults';
import c23_PS_General_PendingChanges from '@salesforce/label/c.c23_PS_General_PendingChanges';
import c23_PS_General_Reset from '@salesforce/label/c.c23_PS_General_Reset';
import c23_PS_General_Search from '@salesforce/label/c.c23_PS_General_Search';
import c23_PS_General_ToastErrorTitle from '@salesforce/label/c.c23_PS_General_ToastErrorTitle';
import c23_PS_General_ToastSuccessTitle from '@salesforce/label/c.c23_PS_General_ToastSuccessTitle';
import c23_PS_General_Yes from '@salesforce/label/c.c23_PS_General_Yes';
import c23_PS_Ledger_ViewRecord from '@salesforce/label/c.c23_PS_Ledger_ViewRecord';
import c23_PS_Ledger_Truncated from '@salesforce/label/c.c23_PS_Ledger_Truncated';
import c23_PS_ObjectMatrix_ApplyResult from '@salesforce/label/c.c23_PS_ObjectMatrix_ApplyResult';
import c23_PS_ObjectMatrix_ApplySuccess from '@salesforce/label/c.c23_PS_ObjectMatrix_ApplySuccess';
import c23_PS_ObjectMatrix_ChangeNotePlaceholder from '@salesforce/label/c.c23_PS_ObjectMatrix_ChangeNotePlaceholder';
import c23_PS_ObjectMatrix_ChangedCount from '@salesforce/label/c.c23_PS_ObjectMatrix_ChangedCount';
import c23_PS_ObjectMatrix_Column_Create from '@salesforce/label/c.c23_PS_ObjectMatrix_Column_Create';
import c23_PS_ObjectMatrix_Column_Delete from '@salesforce/label/c.c23_PS_ObjectMatrix_Column_Delete';
import c23_PS_ObjectMatrix_Column_Edit from '@salesforce/label/c.c23_PS_ObjectMatrix_Column_Edit';
import c23_PS_ObjectMatrix_Column_ModifyAll from '@salesforce/label/c.c23_PS_ObjectMatrix_Column_ModifyAll';
import c23_PS_ObjectMatrix_Column_Read from '@salesforce/label/c.c23_PS_ObjectMatrix_Column_Read';
import c23_PS_ObjectMatrix_Column_ViewAll from '@salesforce/label/c.c23_PS_ObjectMatrix_Column_ViewAll';
import c23_PS_ObjectMatrix_Column_ViewAllFields from '@salesforce/label/c.c23_PS_ObjectMatrix_Column_ViewAllFields';
import c23_PS_ObjectMatrix_Filter_CustomOnly from '@salesforce/label/c.c23_PS_ObjectMatrix_Filter_CustomOnly';
import c23_PS_ObjectMatrix_Filter_DifferencesOnly from '@salesforce/label/c.c23_PS_ObjectMatrix_Filter_DifferencesOnly';
import c23_PS_ObjectMatrix_InsertCount from '@salesforce/label/c.c23_PS_ObjectMatrix_InsertCount';
import c23_PS_ObjectMatrix_PermissionSet from '@salesforce/label/c.c23_PS_ObjectMatrix_PermissionSet';
import c23_PS_ObjectMatrix_SelectAll from '@salesforce/label/c.c23_PS_ObjectMatrix_SelectAll';
import c23_PS_ObjectMatrix_Title from '@salesforce/label/c.c23_PS_ObjectMatrix_Title';
import c23_PS_ObjectMatrix_UpdateCount from '@salesforce/label/c.c23_PS_ObjectMatrix_UpdateCount';
import c23_PS_Tab_Column_Visibility from '@salesforce/label/c.c23_PS_Tab_Column_Visibility';
import c23_PS_Tab_Title from '@salesforce/label/c.c23_PS_Tab_Title';
import c23_PS_Tab_Visibility_DefaultOff from '@salesforce/label/c.c23_PS_Tab_Visibility_DefaultOff';
import c23_PS_Tab_Visibility_DefaultOn from '@salesforce/label/c.c23_PS_Tab_Visibility_DefaultOn';
import c23_PS_Tab_Visibility_Hidden from '@salesforce/label/c.c23_PS_Tab_Visibility_Hidden';

export default class C23FieldMatrixEditor extends LightningElement {
    @api permissionSetName;
    @api density = 'comfortable';

    _permissionSetId;
    rows = [];
    objectOptions = [];
    objectPermissionRows = [];
    tabVisibilityRows = [];
    selectedObjectPermissionRow = null;
    selectedTabVisibilityRow = null;
    selectedObjectApiName = '';
    objectSearchKey = '';
    rowSearchKey = '';
    filterCustomOnly = false;
    filterDifferencesOnly = false;

    isLoadingObjects = false;
    isLoadingRows = false;
    isLoadingObjectPermissions = false;
    isLoadingTabVisibility = false;
    isApplying = false;
    errorMessage = '';
    changeNote = '';
    applyResult = null;
    applyResultMessage = '';

    labels = {
        title: c23_PS_Field_Title,
        subtitle: c23_PS_Field_Subtitle,
        invalidPermissionSet: c23_PS_Error_InvalidPermissionSet,
        object: c23_PS_Field_Object,
        noObjectSelected: c23_PS_Field_NoObjectSelected,
        columnField: c23_PS_Field_Column_Field,
        columnFieldApiName: c23_PS_Field_Column_FieldApiName,
        columnType: c23_PS_Field_Column_Type,
        columnRequired: c23_PS_Field_Column_Required,
        presetRo: c23_PS_Field_Preset_RO,
        presetRe: c23_PS_Field_Preset_RE,
        presetNone: c23_PS_Field_Preset_NONE,
        noTabVisibilityForObject: c23_PS_Field_NoTabVisibilityForObject,
        recordTypesTitle: c23_PS_Field_RecordTypes_Title,
        recordTypesUnsupported: c23_PS_Field_RecordTypes_Unsupported,
        switchObjectConfirmLabel: c23_PS_Field_SwitchObjectConfirmLabel,
        switchObjectConfirmMessage: c23_PS_Field_SwitchObjectConfirmMessage,
        applySuccess: c23_PS_Field_ApplySuccess,
        applySuccessGeneric: c23_PS_ObjectMatrix_ApplySuccess,
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
        yes: c23_PS_General_Yes,
        no: c23_PS_General_No,
        viewLedger: c23_PS_Ledger_ViewRecord,
        ledgerTruncated: c23_PS_Ledger_Truncated,
        applyResult: c23_PS_ObjectMatrix_ApplyResult,
        changeNotePlaceholder: c23_PS_ObjectMatrix_ChangeNotePlaceholder,
        changedCount: c23_PS_ObjectMatrix_ChangedCount,
        columnCreate: c23_PS_ObjectMatrix_Column_Create,
        columnDelete: c23_PS_ObjectMatrix_Column_Delete,
        columnEdit: c23_PS_ObjectMatrix_Column_Edit,
        columnModifyAll: c23_PS_ObjectMatrix_Column_ModifyAll,
        columnRead: c23_PS_ObjectMatrix_Column_Read,
        columnViewAll: c23_PS_ObjectMatrix_Column_ViewAll,
        columnViewAllFields: c23_PS_ObjectMatrix_Column_ViewAllFields,
        filterCustomOnly: c23_PS_ObjectMatrix_Filter_CustomOnly,
        filterDifferencesOnly: c23_PS_ObjectMatrix_Filter_DifferencesOnly,
        insertCount: c23_PS_ObjectMatrix_InsertCount,
        permissionSet: c23_PS_ObjectMatrix_PermissionSet,
        selectAll: c23_PS_ObjectMatrix_SelectAll,
        objectAccessTitle: c23_PS_ObjectMatrix_Title,
        updateCount: c23_PS_ObjectMatrix_UpdateCount,
        tabVisibilityTitle: c23_PS_Tab_Title,
        tabVisibilityLabel: c23_PS_Tab_Column_Visibility,
        visibilityDefaultOn: c23_PS_Tab_Visibility_DefaultOn,
        visibilityDefaultOff: c23_PS_Tab_Visibility_DefaultOff,
        visibilityHidden: c23_PS_Tab_Visibility_Hidden
    };

    @api
    get permissionSetId() {
        return this._permissionSetId;
    }

    set permissionSetId(value) {
        this._permissionSetId = value;
        this.resetForNewTarget();
        if (this._permissionSetId) {
            this.initializeForTarget();
        }
    }

    get hasPermissionSet() {
        return Boolean(this._permissionSetId);
    }

    get isLoading() {
        return this.isLoadingObjects || this.isLoadingRows || this.isLoadingObjectPermissions || this.isLoadingTabVisibility;
    }

    get permissionSetDisplay() {
        return this.permissionSetName || '';
    }

    get hasSelectedObject() {
        return this.selectedObjectApiName !== '';
    }

    get filteredObjectOptions() {
        const searchValue = this.objectSearchKey.trim().toLowerCase();
        const filtered = this.objectOptions.filter((option) => {
            if (!searchValue) {
                return true;
            }
            const labelValue = (option.label || '').toLowerCase();
            const apiValue = (option.value || '').toLowerCase();
            return labelValue.includes(searchValue) || apiValue.includes(searchValue);
        });

        return filtered.map((option) => ({
            ...option,
            key: option.value,
            className: option.value === this.selectedObjectApiName ? 'c23-field__object-option c23-field__object-option_selected' : 'c23-field__object-option'
        }));
    }

    get hasFilteredObjectOptions() {
        return this.filteredObjectOptions.length > 0;
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
            this.visibleRows.every((row) => row.permissionsRead === true && row.permissionsEdit === true)
        );
    }

    get isReadColumnSelected() {
        return this.hasVisibleRows && this.visibleRows.every((row) => row.permissionsRead === true);
    }

    get isEditColumnSelected() {
        return this.hasVisibleRows && this.visibleRows.every((row) => row.permissionsEdit === true);
    }

    get selectAllReadLabel() {
        return `${this.labels.selectAll} ${this.labels.columnRead}`;
    }

    get selectAllEditLabel() {
        return `${this.labels.selectAll} ${this.labels.columnEdit}`;
    }

    get showNoRows() {
        return this.hasPermissionSet && this.hasSelectedObject && !this.isLoading && !this.hasVisibleRows;
    }

    get pendingRows() {
        return this.rows.filter((row) => this.rowHasDifference(row));
    }

    get hasSelectedObjectPermissionRow() {
        return this.selectedObjectPermissionRow !== null;
    }

    get hasSelectedTabVisibilityRow() {
        return this.selectedTabVisibilityRow !== null;
    }

    get hasObjectAccessPendingChange() {
        return this.hasSelectedObjectPermissionRow && this.objectRowHasDifference(this.selectedObjectPermissionRow);
    }

    get hasTabVisibilityPendingChange() {
        return this.hasSelectedTabVisibilityRow && this.tabRowHasDifference(this.selectedTabVisibilityRow);
    }

    get pendingCount() {
        return this.pendingRows.length + (this.hasObjectAccessPendingChange ? 1 : 0) + (this.hasTabVisibilityPendingChange ? 1 : 0);
    }

    get hasPendingChanges() {
        return this.pendingCount > 0;
    }

    get pendingCountText() {
        return `${this.labels.pendingChanges}: ${this.pendingCount}`;
    }

    get objectAccessPendingText() {
        return this.hasObjectAccessPendingChange ? this.labels.pendingChanges : this.labels.noPendingChanges;
    }

    get objectAccessBadgeClass() {
        return this.hasObjectAccessPendingChange
            ? 'c23-field__pending-pill c23-field__pending-pill_armed'
            : 'c23-field__pending-pill';
    }

    get tabVisibilityOptions() {
        return [
            { label: this.labels.visibilityDefaultOn, value: 'DefaultOn' },
            { label: this.labels.visibilityDefaultOff, value: 'DefaultOff' },
            { label: this.labels.visibilityHidden, value: 'Hidden' }
        ];
    }

    get selectedTabVisibilityValue() {
        return this.hasSelectedTabVisibilityRow ? this.selectedTabVisibilityRow.visibility : this.labels.visibilityDefaultOff;
    }

    get objectAccessToggleRows() {
        if (!this.hasSelectedObjectPermissionRow) {
            return [];
        }
        return [
            this.objectAccessToggle('permissionsRead', this.labels.columnRead),
            this.objectAccessToggle('permissionsCreate', this.labels.columnCreate),
            this.objectAccessToggle('permissionsEdit', this.labels.columnEdit),
            this.objectAccessToggle('permissionsDelete', this.labels.columnDelete),
            this.objectAccessToggle('permissionsViewAllFields', this.labels.columnViewAllFields),
            this.objectAccessToggle('permissionsViewAllRecords', this.labels.columnViewAll),
            this.objectAccessToggle('permissionsModifyAllRecords', this.labels.columnModifyAll)
        ];
    }

    get showNoPendingChangesMessage() {
        return this.hasSelectedObject && !this.hasPendingChanges;
    }

    get isSaveDisabled() {
        return !this.hasSelectedObject || !this.hasPendingChanges || this.isLoading || this.isApplying;
    }

    get isResetDisabled() {
        return !this.hasSelectedObject || this.isLoading || this.isApplying;
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
        return `c23-field__table-wrap ${this.densityClass}`;
    }

    objectAccessToggle(fieldName, label) {
        const row = this.selectedObjectPermissionRow;
        return {
            key: fieldName,
            fieldName,
            label,
            checked: row && row[fieldName] === true
        };
    }

    async initializeForTarget() {
        await Promise.all([this.loadObjectOptions(), this.loadObjectPermissionMatrix(), this.loadTabVisibilityMatrix()]);
        this.syncSelectedObjectContext();
    }

    async loadObjectOptions() {
        this.isLoadingObjects = true;
        this.errorMessage = '';
        try {
            const options = await getFieldObjectOptions();
            this.objectOptions = (options || []).map((item) => ({
                label: this.safeString((item && item.label) || (item && item.apiName)),
                value: this.safeString(item && item.apiName)
            }));
            if (this.objectOptions.length === 0) {
                this.selectedObjectApiName = '';
                this.rows = [];
                this.syncSelectedObjectContext();
                return;
            }

            const hasSelection = this.objectOptions.some((item) => item.value === this.selectedObjectApiName);
            if (!hasSelection) {
                this.selectedObjectApiName = this.objectOptions[0].value;
            }

            if (this.selectedObjectApiName) {
                await this.loadMatrix();
                this.syncSelectedObjectContext();
            }
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isLoadingObjects = false;
        }
    }

    async loadObjectPermissionMatrix() {
        if (!this.hasPermissionSet) {
            this.objectPermissionRows = [];
            this.selectedObjectPermissionRow = null;
            return;
        }

        this.isLoadingObjectPermissions = true;
        this.errorMessage = '';
        try {
            const data = await getObjectMatrix({ parentPermissionSetId: this._permissionSetId });
            this.objectPermissionRows = this.normalizeObjectPermissionRows(data || []);
            this.syncSelectedObjectContext();
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.objectPermissionRows = [];
            this.selectedObjectPermissionRow = null;
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isLoadingObjectPermissions = false;
        }
    }

    async loadTabVisibilityMatrix() {
        if (!this.hasPermissionSet) {
            this.tabVisibilityRows = [];
            this.selectedTabVisibilityRow = null;
            return;
        }

        this.isLoadingTabVisibility = true;
        this.errorMessage = '';
        try {
            const data = await getTabVisibilityMatrix({ parentPermissionSetId: this._permissionSetId });
            this.tabVisibilityRows = this.normalizeTabVisibilityRows(data || []);
            this.syncSelectedObjectContext();
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.tabVisibilityRows = [];
            this.selectedTabVisibilityRow = null;
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isLoadingTabVisibility = false;
        }
    }

    async loadMatrix() {
        if (!this.hasPermissionSet || !this.hasSelectedObject) {
            this.rows = [];
            return;
        }

        this.isLoadingRows = true;
        this.errorMessage = '';
        try {
            const data = await getFieldMatrix({
                parentPermissionSetId: this._permissionSetId,
                objectApiName: this.selectedObjectApiName
            });
            this.rows = this.normalizeMatrixRows(data || []);
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.rows = [];
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isLoadingRows = false;
        }
    }

    syncSelectedObjectContext() {
        const objectApiName = this.safeTrimString(this.selectedObjectApiName);
        if (!objectApiName) {
            this.selectedObjectPermissionRow = null;
            this.selectedTabVisibilityRow = null;
            return;
        }

        const objectKey = objectApiName.toLowerCase();
        const objectRow = this.objectPermissionRows.find((row) => row.apiNameKey === objectKey);
        this.selectedObjectPermissionRow = objectRow ? this.normalizeObjectPermissionRow({ ...objectRow }) : null;

        const tabRow = this.tabVisibilityRows.find((row) => row.tabNameKey === objectKey);
        this.selectedTabVisibilityRow = tabRow ? { ...tabRow } : null;
    }

    handleObjectSearchChange(event) {
        this.objectSearchKey = event.target.value || '';
    }

    async handleObjectSelect(event) {
        const selectedValue = event.currentTarget.dataset.value;
        if (!selectedValue || selectedValue === this.selectedObjectApiName) {
            return;
        }

        if (this.hasPendingChanges) {
            const shouldSwitch = await this.confirmSwitchObjectDiscard();
            if (!shouldSwitch) {
                return;
            }
        }

        this.selectedObjectApiName = selectedValue;
        this.applyResult = null;
        this.applyResultMessage = '';
        this.syncSelectedObjectContext();
        await this.loadMatrix();
    }

    async confirmSwitchObjectDiscard() {
        return LightningConfirm.open({
            label: this.labels.switchObjectConfirmLabel,
            message: this.labels.switchObjectConfirmMessage,
            theme: 'warning'
        });
    }

    handleRowSearchChange(event) {
        this.rowSearchKey = event.target.value || '';
    }

    handleFilterCustomOnly(event) {
        this.filterCustomOnly = event.target.checked;
    }

    handleFilterDifferencesOnly(event) {
        this.filterDifferencesOnly = event.target.checked;
    }

    handleObjectAccessToggle(event) {
        if (!this.hasSelectedObjectPermissionRow) {
            return;
        }
        const fieldName =
            (event.currentTarget && event.currentTarget.dataset && event.currentTarget.dataset.field) ||
            (event.target && event.target.dataset && event.target.dataset.field) ||
            '';
        if (!fieldName) {
            return;
        }

        const checked = event.target && event.target.checked === true;
        this.selectedObjectPermissionRow = this.normalizeObjectPermissionRow({
            ...this.selectedObjectPermissionRow,
            [fieldName]: checked
        });
    }

    handleTabVisibilityChange(event) {
        if (!this.hasSelectedTabVisibilityRow) {
            return;
        }
        const visibility = event.detail && event.detail.value ? event.detail.value : this.labels.visibilityDefaultOff;
        this.selectedTabVisibilityRow = {
            ...this.selectedTabVisibilityRow,
            visibility
        };
    }

    handleSelectAllToggle(event) {
        const checked = event.target && event.target.checked === true;
        this.applyPermissionToVisibleRows({
            permissionsRead: checked,
            permissionsEdit: checked
        });
    }

    handleSelectAllReadToggle(event) {
        const checked = event.target && event.target.checked === true;
        this.applyPermissionToVisibleRows({ permissionsRead: checked });
    }

    handleSelectAllEditToggle(event) {
        const checked = event.target && event.target.checked === true;
        this.applyPermissionToVisibleRows({ permissionsEdit: checked });
    }

    applyPermissionToVisibleRows(changes) {
        if (!changes || !this.hasVisibleRows) {
            return;
        }
        const visiblePaths = new Set(this.visibleRows.map((row) => row.fieldPath));
        this.rows = this.rows.map((row) => {
            if (!visiblePaths.has(row.fieldPath)) {
                return row;
            }
            return this.normalizeRow({ ...row, ...changes });
        });
    }

    handlePermissionToggle(event) {
        const rowKey =
            (event.currentTarget && event.currentTarget.dataset && event.currentTarget.dataset.key) ||
            (event.target && event.target.dataset && event.target.dataset.key) ||
            '';
        const fieldName =
            (event.currentTarget && event.currentTarget.dataset && event.currentTarget.dataset.field) ||
            (event.target && event.target.dataset && event.target.dataset.field) ||
            '';
        if (!rowKey || !fieldName) {
            return;
        }
        const checked = event.target && event.target.checked === true;
        this.rows = this.rows.map((row) => {
            if (row.fieldPath !== rowKey) {
                return row;
            }
            return this.normalizeRow({ ...row, [fieldName]: checked });
        });
    }

    handlePresetApply(event) {
        const preset = event.currentTarget.dataset.preset;
        const visiblePaths = new Set(this.visibleRows.map((row) => row.fieldPath));
        this.rows = this.rows.map((row) => {
            if (!visiblePaths.has(row.fieldPath)) {
                return row;
            }

            const updated = { ...row };
            if (preset === 'RO') {
                updated.permissionsRead = true;
                updated.permissionsEdit = false;
            }
            if (preset === 'RE') {
                updated.permissionsRead = true;
                updated.permissionsEdit = true;
            }
            if (preset === 'NONE') {
                updated.permissionsRead = false;
                updated.permissionsEdit = false;
            }
            return this.normalizeRow(updated);
        });
    }

    async handleReset() {
        this.applyResult = null;
        this.applyResultMessage = '';
        await this.reloadCurrentObjectContext();
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

        const desiredFieldRows = this.buildDesiredFieldStateRows();
        const desiredObjectRows = this.buildDesiredObjectStateRows();
        const desiredTabRows = this.buildDesiredTabStateRows();
        if (
            pendingCountBefore > 0 &&
            desiredFieldRows.length === 0 &&
            desiredObjectRows.length === 0 &&
            desiredTabRows.length === 0
        ) {
            this.applyResultMessage = this.labels.applyNoChangesDetected;
            this.showErrorToast(this.applyResultMessage);
            return;
        }

        this.isApplying = true;
        this.errorMessage = '';
        this.applyResultMessage = '';
        try {
            const responses = [];
            if (desiredFieldRows.length > 0) {
                responses.push(await this.applyFieldChanges(desiredFieldRows, changeNoteValue));
            }
            if (desiredObjectRows.length > 0) {
                responses.push(await this.applyObjectChanges(desiredObjectRows, changeNoteValue));
            }
            if (desiredTabRows.length > 0) {
                responses.push(await this.applyTabChanges(desiredTabRows, changeNoteValue));
            }

            this.applyResult = this.aggregateApplyResponses(responses);
            this.applyResultMessage = this.applyResult.message || this.labels.applySuccessGeneric;
            const changedCount = this.applyResult.changedCount || 0;
            if (changedCount > 0) {
                this.showSuccessToast(this.applyResultMessage);
            } else if (pendingCountBefore > 0) {
                this.applyResultMessage = this.labels.applyNoChangesDetected;
                this.showErrorToast(this.applyResultMessage);
            } else {
                this.showSuccessToast(this.applyResultMessage);
            }
            await this.reloadCurrentObjectContext();
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isApplying = false;
        }
    }

    async applyFieldChanges(desiredStateRows, changeNoteValue) {
        const requestPayload = {
            parentPermissionSetId: this.safeTrimString(this._permissionSetId),
            permissionSetId: this.safeTrimString(this._permissionSetId),
            objectApiName: this.safeTrimString(this.selectedObjectApiName),
            desiredStateRowsJson: JSON.stringify(desiredStateRows),
            changeNote: changeNoteValue
        };
        return applyFieldMatrixJsonEnvelope({
            requestJson: JSON.stringify(requestPayload)
        });
    }

    async applyObjectChanges(desiredStateRows, changeNoteValue) {
        const requestPayload = {
            parentPermissionSetId: this.safeTrimString(this._permissionSetId),
            permissionSetId: this.safeTrimString(this._permissionSetId),
            desiredStateRowsJson: JSON.stringify(desiredStateRows),
            changeNote: changeNoteValue
        };
        return applyObjectMatrixJsonEnvelope({
            requestJson: JSON.stringify(requestPayload)
        });
    }

    async applyTabChanges(desiredStateRows, changeNoteValue) {
        return applyTabVisibility({
            parentPermissionSetId: this._permissionSetId,
            desiredStateRows,
            changeNote: changeNoteValue
        });
    }

    aggregateApplyResponses(responses) {
        const aggregate = {
            changedCount: 0,
            insertCount: 0,
            updateCount: 0,
            totalRequestedCount: 0,
            ledgerId: null,
            ledgerTruncated: false,
            message: this.labels.applySuccessGeneric
        };

        const list = (responses || []).filter((response) => response);
        const ledgerIds = [];
        for (const response of list) {
            aggregate.changedCount += Number(response.changedCount || 0);
            aggregate.insertCount += Number(response.insertCount || 0);
            aggregate.updateCount += Number(response.updateCount || 0);
            aggregate.totalRequestedCount += Number(response.totalRequestedCount || 0);
            aggregate.ledgerTruncated = aggregate.ledgerTruncated || response.ledgerTruncated === true;
            if (response.ledgerId) {
                ledgerIds.push(response.ledgerId);
            }
        }

        if (ledgerIds.length === 1) {
            aggregate.ledgerId = ledgerIds[0];
        }

        if (list.length === 1 && list[0].message) {
            aggregate.message = list[0].message;
        }

        return aggregate;
    }

    async reloadCurrentObjectContext() {
        await Promise.all([this.loadMatrix(), this.loadObjectPermissionMatrix(), this.loadTabVisibilityMatrix()]);
        this.syncSelectedObjectContext();
    }

    buildDesiredFieldStateRows() {
        return this.pendingRows
            .map((row) => ({
                fieldPath: this.safeString(row && row.fieldPath),
                permissionsRead: row && row.permissionsRead === true,
                permissionsEdit: row && row.permissionsEdit === true
            }))
            .filter((row) => row.fieldPath !== '');
    }

    buildDesiredObjectStateRows() {
        if (!this.hasSelectedObjectPermissionRow || !this.objectRowHasDifference(this.selectedObjectPermissionRow)) {
            return [];
        }

        const row = this.selectedObjectPermissionRow;
        return [
            {
                apiName: this.safeString(row.apiName),
                permissionsRead: row.permissionsRead === true,
                permissionsCreate: row.permissionsCreate === true,
                permissionsEdit: row.permissionsEdit === true,
                permissionsDelete: row.permissionsDelete === true,
                permissionsViewAllFields: row.permissionsViewAllFields === true,
                permissionsViewAllRecords: row.permissionsViewAllRecords === true,
                permissionsModifyAllRecords: row.permissionsModifyAllRecords === true
            }
        ];
    }

    buildDesiredTabStateRows() {
        if (!this.hasSelectedTabVisibilityRow || !this.tabRowHasDifference(this.selectedTabVisibilityRow)) {
            return [];
        }

        const row = this.selectedTabVisibilityRow;
        return [
            {
                tabName: this.safeString(row.tabName),
                visibility: this.safeString(row.visibility)
            }
        ];
    }

    rowPassesFilters(row) {
        const searchValue = this.rowSearchKey.trim().toLowerCase();
        const labelValue = (row.label || '').toLowerCase();
        const apiValue = (row.fieldApiName || '').toLowerCase();
        const typeValue = (row.dataType || '').toLowerCase();
        if (
            searchValue &&
            !labelValue.includes(searchValue) &&
            !apiValue.includes(searchValue) &&
            !typeValue.includes(searchValue)
        ) {
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
        if (!row || !row.fieldPath) {
            return false;
        }
        return row.permissionsRead !== row.currentPermissionsRead || row.permissionsEdit !== row.currentPermissionsEdit;
    }

    objectRowHasDifference(row) {
        if (!row || !row.apiName) {
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

    tabRowHasDifference(row) {
        if (!row || !row.tabName) {
            return false;
        }
        return row.visibility !== row.currentVisibility;
    }

    normalizeRow(row) {
        const normalized = { ...row };
        if (normalized.permissionsEdit) {
            normalized.permissionsRead = true;
        }
        if (!normalized.permissionsRead) {
            normalized.permissionsEdit = false;
        }
        return normalized;
    }

    normalizeObjectPermissionRow(row) {
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
        const isRequired = row && row.isRequired === true;
        return this.normalizeRow({
            fieldPath: this.safeString(row && row.fieldPath),
            fieldApiName: this.safeString(row && row.fieldApiName),
            label: this.safeString(row && row.label),
            dataType: this.safeString(row && row.dataType),
            isRequired,
            requiredText: isRequired ? this.labels.yes : this.labels.no,
            isCustom: row && row.isCustom === true,
            permissionsRead: row && row.permissionsRead === true,
            permissionsEdit: row && row.permissionsEdit === true,
            currentPermissionsRead: row && row.currentPermissionsRead === true,
            currentPermissionsEdit: row && row.currentPermissionsEdit === true
        });
    }

    normalizeObjectPermissionRows(rawRows) {
        return rawRows.map((row) => this.normalizeIncomingObjectPermissionRow(row));
    }

    normalizeIncomingObjectPermissionRow(row) {
        const apiName = this.safeTrimString(row && row.apiName);
        return this.normalizeObjectPermissionRow({
            apiName,
            apiNameKey: apiName.toLowerCase(),
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
        });
    }

    normalizeTabVisibilityRows(rawRows) {
        return rawRows.map((row) => this.normalizeIncomingTabVisibilityRow(row));
    }

    normalizeIncomingTabVisibilityRow(row) {
        const tabName = this.safeTrimString(row && row.tabName);
        const currentVisibility = this.safeString(row && row.currentVisibility);
        const visibility = this.safeString(row && row.visibility);
        return {
            tabName,
            tabNameKey: tabName.toLowerCase(),
            tabLabel: this.safeString(row && row.tabLabel),
            visibility: visibility || currentVisibility || this.labels.visibilityDefaultOff,
            currentVisibility: currentVisibility || this.labels.visibilityDefaultOff
        };
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
        this.objectOptions = [];
        this.objectPermissionRows = [];
        this.tabVisibilityRows = [];
        this.selectedObjectPermissionRow = null;
        this.selectedTabVisibilityRow = null;
        this.selectedObjectApiName = '';
        this.objectSearchKey = '';
        this.rowSearchKey = '';
        this.filterCustomOnly = false;
        this.filterDifferencesOnly = false;
        this.errorMessage = '';
        this.changeNote = '';
        this.applyResult = null;
        this.applyResultMessage = '';
    }
}