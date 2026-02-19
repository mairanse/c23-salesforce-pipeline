import { api, LightningElement } from 'lwc';
import LightningPrompt from 'lightning/prompt';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import applyGroupMembership from '@salesforce/apex/c23_PermissionStudioPsgService.applyGroupMembership';
import getPermissionSetGroupEditor from '@salesforce/apex/c23_PermissionStudioPsgService.getPermissionSetGroupEditor';
import c23_PS_General_Add from '@salesforce/label/c.c23_PS_General_Add';
import c23_PS_General_Apply from '@salesforce/label/c.c23_PS_General_Apply';
import c23_PS_General_ChangeNote from '@salesforce/label/c.c23_PS_General_ChangeNote';
import c23_PS_General_ConfirmSave from '@salesforce/label/c.c23_PS_General_ConfirmSave';
import c23_PS_General_Error from '@salesforce/label/c.c23_PS_General_Error';
import c23_PS_General_Loading from '@salesforce/label/c.c23_PS_General_Loading';
import c23_PS_General_NoResults from '@salesforce/label/c.c23_PS_General_NoResults';
import c23_PS_General_Remove from '@salesforce/label/c.c23_PS_General_Remove';
import c23_PS_General_Reset from '@salesforce/label/c.c23_PS_General_Reset';
import c23_PS_General_Search from '@salesforce/label/c.c23_PS_General_Search';
import c23_PS_General_ToastErrorTitle from '@salesforce/label/c.c23_PS_General_ToastErrorTitle';
import c23_PS_General_ToastSuccessTitle from '@salesforce/label/c.c23_PS_General_ToastSuccessTitle';
import c23_PS_Ledger_ViewRecord from '@salesforce/label/c.c23_PS_Ledger_ViewRecord';
import c23_PS_ObjectMatrix_ApplyResult from '@salesforce/label/c.c23_PS_ObjectMatrix_ApplyResult';
import c23_PS_ObjectMatrix_ChangedCount from '@salesforce/label/c.c23_PS_ObjectMatrix_ChangedCount';
import c23_PS_ObjectMatrix_InsertCount from '@salesforce/label/c.c23_PS_ObjectMatrix_InsertCount';
import c23_PS_ObjectMatrix_UpdateCount from '@salesforce/label/c.c23_PS_ObjectMatrix_UpdateCount';
import c23_PS_PSG_AvailablePermissionSets from '@salesforce/label/c.c23_PS_PSG_AvailablePermissionSets';
import c23_PS_PSG_ApplySuccess from '@salesforce/label/c.c23_PS_PSG_ApplySuccess';
import c23_PS_PSG_MembersTitle from '@salesforce/label/c.c23_PS_PSG_MembersTitle';
import c23_PS_PSG_Name from '@salesforce/label/c.c23_PS_PSG_Name';
import c23_PS_PSG_PendingAdds from '@salesforce/label/c.c23_PS_PSG_PendingAdds';
import c23_PS_PSG_PendingRemoves from '@salesforce/label/c.c23_PS_PSG_PendingRemoves';
import c23_PS_PSG_Status from '@salesforce/label/c.c23_PS_PSG_Status';
import c23_PS_PSG_Subtitle from '@salesforce/label/c.c23_PS_PSG_Subtitle';
import c23_PS_PSG_Title from '@salesforce/label/c.c23_PS_PSG_Title';

export default class C23PermissionSetGroupEditor extends LightningElement {
    @api density = 'comfortable';
    _permissionSetGroupId;
    _permissionSetGroupName;

    groupStatus = '';
    groupNameFromService = '';
    availableSearchKey = '';
    memberSearchKey = '';
    changeNote = '';

    baseRows = [];
    rows = [];

    isLoading = false;
    isApplying = false;
    errorMessage = '';
    applyResult = null;
    applyResultMessage = '';

    labels = {
        add: c23_PS_General_Add,
        apply: c23_PS_General_Apply,
        applyResult: c23_PS_ObjectMatrix_ApplyResult,
        applySuccess: c23_PS_PSG_ApplySuccess,
        availablePermissionSets: c23_PS_PSG_AvailablePermissionSets,
        changedCount: c23_PS_ObjectMatrix_ChangedCount,
        changeNote: c23_PS_General_ChangeNote,
        confirmSave: c23_PS_General_ConfirmSave,
        error: c23_PS_General_Error,
        insertCount: c23_PS_ObjectMatrix_InsertCount,
        loading: c23_PS_General_Loading,
        membersTitle: c23_PS_PSG_MembersTitle,
        name: c23_PS_PSG_Name,
        noResults: c23_PS_General_NoResults,
        pendingAdds: c23_PS_PSG_PendingAdds,
        pendingRemoves: c23_PS_PSG_PendingRemoves,
        remove: c23_PS_General_Remove,
        reset: c23_PS_General_Reset,
        search: c23_PS_General_Search,
        toastErrorTitle: c23_PS_General_ToastErrorTitle,
        toastSuccessTitle: c23_PS_General_ToastSuccessTitle,
        viewLedger: c23_PS_Ledger_ViewRecord,
        status: c23_PS_PSG_Status,
        subtitle: c23_PS_PSG_Subtitle,
        title: c23_PS_PSG_Title,
        updateCount: c23_PS_ObjectMatrix_UpdateCount
    };

    @api
    get permissionSetGroupId() {
        return this._permissionSetGroupId;
    }

    set permissionSetGroupId(value) {
        this._permissionSetGroupId = value;
        this.resetForTarget();
        if (this._permissionSetGroupId) {
            this.loadEditor();
        }
    }

    @api
    get permissionSetGroupName() {
        return this._permissionSetGroupName;
    }

    set permissionSetGroupName(value) {
        this._permissionSetGroupName = value;
    }

    get hasGroup() {
        return Boolean(this._permissionSetGroupId);
    }

    get groupDisplayName() {
        return this.groupNameFromService || this._permissionSetGroupName || '';
    }

    get memberRows() {
        const searchValue = this.memberSearchKey.trim().toLowerCase();
        return this.rows
            .filter((row) => row.isMember)
            .filter((row) => {
                if (!searchValue) {
                    return true;
                }
                return row.searchValue.includes(searchValue);
            });
    }

    get availableRows() {
        const searchValue = this.availableSearchKey.trim().toLowerCase();
        return this.rows
            .filter((row) => !row.isMember)
            .filter((row) => {
                if (!searchValue) {
                    return true;
                }
                return row.searchValue.includes(searchValue);
            });
    }

    get hasMemberRows() {
        return this.memberRows.length > 0;
    }

    get hasAvailableRows() {
        return this.availableRows.length > 0;
    }

    get pendingAdds() {
        return this.rows.filter((row) => row.isMember && !row.currentMember);
    }

    get pendingRemoves() {
        return this.rows.filter((row) => !row.isMember && row.currentMember);
    }

    get pendingAddsText() {
        return `${this.labels.pendingAdds}: ${this.pendingAdds.length}`;
    }

    get pendingRemovesText() {
        return `${this.labels.pendingRemoves}: ${this.pendingRemoves.length}`;
    }

    get hasPendingChanges() {
        return this.pendingAdds.length > 0 || this.pendingRemoves.length > 0;
    }

    get isResetDisabled() {
        return this.isLoading || this.isApplying;
    }

    get isApplyDisabled() {
        return !this.hasPendingChanges || this.isLoading || this.isApplying;
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

    get availableTableWrapClass() {
        return `c23-psg__table-wrap ${this.densityClass}`;
    }

    get memberTableWrapClass() {
        return `c23-psg__table-wrap ${this.densityClass}`;
    }

    async loadEditor() {
        this.isLoading = true;
        this.errorMessage = '';
        this.applyResult = null;
        this.applyResultMessage = '';

        try {
            const response = await getPermissionSetGroupEditor({
                permissionSetGroupId: this._permissionSetGroupId
            });

            this.groupStatus = response && response.status ? response.status : '';
            this.groupNameFromService = response && response.label ? response.label : '';

            const memberRows = (response && response.memberPermissionSets ? response.memberPermissionSets : []).map((row) =>
                this.toLocalRow(row, true, true)
            );
            const availableRows = (response && response.availablePermissionSets ? response.availablePermissionSets : []).map((row) =>
                this.toLocalRow(row, false, false)
            );

            this.baseRows = [...memberRows, ...availableRows];
            this.rows = this.baseRows.map((row) => ({ ...row }));
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.baseRows = [];
            this.rows = [];
            this.groupStatus = '';
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isLoading = false;
        }
    }

    handleAvailableSearchChange(event) {
        this.availableSearchKey = event.target.value || '';
    }

    handleMemberSearchChange(event) {
        this.memberSearchKey = event.target.value || '';
    }

    handleAddMember(event) {
        const permissionSetId = event.currentTarget.dataset.permissionSetId;
        const row = this.findRow(permissionSetId);
        if (!row) {
            return;
        }
        row.isMember = true;
        this.rows = [...this.rows];
    }

    handleRemoveMember(event) {
        const permissionSetId = event.currentTarget.dataset.permissionSetId;
        const row = this.findRow(permissionSetId);
        if (!row) {
            return;
        }
        row.isMember = false;
        this.rows = [...this.rows];
    }

    handleReset() {
        this.rows = this.baseRows.map((row) => ({ ...row }));
        this.availableSearchKey = '';
        this.memberSearchKey = '';
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
            const desiredPermissionSetIds = this.rows.filter((row) => row.isMember).map((row) => row.id);
            const response = await applyGroupMembership({
                permissionSetGroupId: this._permissionSetGroupId,
                desiredPermissionSetIds,
                changeNote: changeNoteValue
            });
            this.applyResult = response;
            this.applyResultMessage = response && response.message ? response.message : this.labels.applySuccess;
            this.showSuccessToast(this.applyResultMessage);
            await this.loadEditor();
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isApplying = false;
        }
    }

    toLocalRow(source, isMember, currentMember) {
        const nameValue = source.label || source.apiName;
        return {
            id: source.id,
            apiName: source.apiName,
            label: nameValue,
            isMember,
            currentMember,
            searchValue: `${nameValue || ''}|${source.apiName || ''}`.toLowerCase()
        };
    }

    findRow(permissionSetId) {
        return this.rows.find((row) => row.id === permissionSetId) || null;
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

    resetForTarget() {
        this.groupStatus = '';
        this.groupNameFromService = '';
        this.availableSearchKey = '';
        this.memberSearchKey = '';
        this.changeNote = '';
        this.baseRows = [];
        this.rows = [];
        this.isLoading = false;
        this.isApplying = false;
        this.errorMessage = '';
        this.applyResult = null;
        this.applyResultMessage = '';
    }
}