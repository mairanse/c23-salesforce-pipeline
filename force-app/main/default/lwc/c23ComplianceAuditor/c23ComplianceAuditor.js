import { api, LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchPermissionKeys from '@salesforce/apex/c23_AuditQueryService.searchPermissionKeys';
import whoHas from '@salesforce/apex/c23_AuditQueryService.whoHas';
import getLedgerEvents from '@salesforce/apex/c23_AuditQueryService.getLedgerEvents';
import c23_PS_Audit_Title from '@salesforce/label/c.c23_PS_Audit_Title';
import c23_PS_Audit_Subtitle from '@salesforce/label/c.c23_PS_Audit_Subtitle';
import c23_PS_Audit_WhoHas_Title from '@salesforce/label/c.c23_PS_Audit_WhoHas_Title';
import c23_PS_Audit_WhoHas_Search from '@salesforce/label/c.c23_PS_Audit_WhoHas_Search';
import c23_PS_Audit_WhoHas_SearchButton from '@salesforce/label/c.c23_PS_Audit_WhoHas_SearchButton';
import c23_PS_Audit_WhoHas_Key from '@salesforce/label/c.c23_PS_Audit_WhoHas_Key';
import c23_PS_Audit_WhoHas_Run from '@salesforce/label/c.c23_PS_Audit_WhoHas_Run';
import c23_PS_Audit_WhoHas_NoRows from '@salesforce/label/c.c23_PS_Audit_WhoHas_NoRows';
import c23_PS_Audit_WhoHas_Column_Name from '@salesforce/label/c.c23_PS_Audit_WhoHas_Column_Name';
import c23_PS_Audit_WhoHas_Column_Username from '@salesforce/label/c.c23_PS_Audit_WhoHas_Column_Username';
import c23_PS_Audit_WhoHas_Column_Profile from '@salesforce/label/c.c23_PS_Audit_WhoHas_Column_Profile';
import c23_PS_Audit_WhoHas_Column_Access from '@salesforce/label/c.c23_PS_Audit_WhoHas_Column_Access';
import c23_PS_Audit_WhoHas_Column_Source from '@salesforce/label/c.c23_PS_Audit_WhoHas_Column_Source';
import c23_PS_Audit_Changes_Title from '@salesforce/label/c.c23_PS_Audit_Changes_Title';
import c23_PS_Audit_Changes_DateFrom from '@salesforce/label/c.c23_PS_Audit_Changes_DateFrom';
import c23_PS_Audit_Changes_DateTo from '@salesforce/label/c.c23_PS_Audit_Changes_DateTo';
import c23_PS_Audit_Changes_Load from '@salesforce/label/c.c23_PS_Audit_Changes_Load';
import c23_PS_Audit_Changes_NoRows from '@salesforce/label/c.c23_PS_Audit_Changes_NoRows';
import c23_PS_Audit_Changes_Column_When from '@salesforce/label/c.c23_PS_Audit_Changes_Column_When';
import c23_PS_Audit_Changes_Column_TargetType from '@salesforce/label/c.c23_PS_Audit_Changes_Column_TargetType';
import c23_PS_Audit_Changes_Column_TargetName from '@salesforce/label/c.c23_PS_Audit_Changes_Column_TargetName';
import c23_PS_Audit_Changes_Column_Section from '@salesforce/label/c.c23_PS_Audit_Changes_Column_Section';
import c23_PS_Audit_Changes_Column_Changed from '@salesforce/label/c.c23_PS_Audit_Changes_Column_Changed';
import c23_PS_Audit_Export_WhoHas from '@salesforce/label/c.c23_PS_Audit_Export_WhoHas';
import c23_PS_Audit_Export_Changes from '@salesforce/label/c.c23_PS_Audit_Export_Changes';
import c23_PS_General_Loading from '@salesforce/label/c.c23_PS_General_Loading';
import c23_PS_General_Error from '@salesforce/label/c.c23_PS_General_Error';
import c23_PS_General_ToastErrorTitle from '@salesforce/label/c.c23_PS_General_ToastErrorTitle';

const PERMISSION_CATEGORIES = ['SYSTEM', 'OBJECT', 'FIELD'];

export default class C23ComplianceAuditor extends LightningElement {
    @api permissionSetId;
    @api permissionSetName;
    @api density = 'comfortable';

    labels = {
        title: c23_PS_Audit_Title,
        subtitle: c23_PS_Audit_Subtitle,
        whoHasTitle: c23_PS_Audit_WhoHas_Title,
        permissionSearch: c23_PS_Audit_WhoHas_Search,
        searchKeys: c23_PS_Audit_WhoHas_SearchButton,
        permissionKey: c23_PS_Audit_WhoHas_Key,
        runWhoHas: c23_PS_Audit_WhoHas_Run,
        noWhoHasRows: c23_PS_Audit_WhoHas_NoRows,
        columnName: c23_PS_Audit_WhoHas_Column_Name,
        columnUsername: c23_PS_Audit_WhoHas_Column_Username,
        columnProfile: c23_PS_Audit_WhoHas_Column_Profile,
        columnAccess: c23_PS_Audit_WhoHas_Column_Access,
        columnSource: c23_PS_Audit_WhoHas_Column_Source,
        changesTitle: c23_PS_Audit_Changes_Title,
        dateFrom: c23_PS_Audit_Changes_DateFrom,
        dateTo: c23_PS_Audit_Changes_DateTo,
        loadChanges: c23_PS_Audit_Changes_Load,
        noChangeRows: c23_PS_Audit_Changes_NoRows,
        columnWhen: c23_PS_Audit_Changes_Column_When,
        columnTargetType: c23_PS_Audit_Changes_Column_TargetType,
        columnTargetName: c23_PS_Audit_Changes_Column_TargetName,
        columnSection: c23_PS_Audit_Changes_Column_Section,
        columnChanged: c23_PS_Audit_Changes_Column_Changed,
        exportWhoHas: c23_PS_Audit_Export_WhoHas,
        exportChanges: c23_PS_Audit_Export_Changes,
        loading: c23_PS_General_Loading,
        error: c23_PS_General_Error,
        toastErrorTitle: c23_PS_General_ToastErrorTitle
    };

    permissionSearch = '';
    selectedPermissionKey = '';
    permissionKeyOptions = [];
    whoHasRows = [];
    changeRows = [];

    dateFrom = '';
    dateTo = '';

    isLoadingKeys = false;
    isLoadingWhoHas = false;
    isLoadingChanges = false;
    errorMessage = '';

    connectedCallback() {
        const today = new Date();
        const past = new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000);
        this.dateTo = this.toDateInput(today);
        this.dateFrom = this.toDateInput(past);
        this.loadChanges();
    }

    get showSpinner() {
        return this.isLoadingKeys || this.isLoadingWhoHas || this.isLoadingChanges;
    }

    get hasErrorMessage() {
        return this.errorMessage !== '';
    }

    get showWhoHasRows() {
        return this.whoHasRows.length > 0;
    }

    get showNoWhoHasRows() {
        return !this.showSpinner && this.selectedPermissionKey !== '' && !this.showWhoHasRows;
    }

    get showChangeRows() {
        return this.changeRows.length > 0;
    }

    get showNoChangeRows() {
        return !this.showSpinner && !this.showChangeRows;
    }

    get isSearchKeysDisabled() {
        return this.isLoadingKeys || this.permissionSearch.trim() === '';
    }

    get isWhoHasDisabled() {
        return this.isLoadingWhoHas || this.selectedPermissionKey === '';
    }

    get isLoadChangesDisabled() {
        return this.isLoadingChanges || this.dateFrom === '' || this.dateTo === '';
    }

    get isExportWhoHasDisabled() {
        return this.whoHasRows.length === 0;
    }

    get isExportChangesDisabled() {
        return this.changeRows.length === 0;
    }

    get densityClass() {
        return this.density === 'compact' ? 'density-compact' : 'density-comfortable';
    }

    get whoHasTableWrapClass() {
        return `c23-audit__table-wrap ${this.densityClass}`;
    }

    get changesTableWrapClass() {
        return `c23-audit__table-wrap ${this.densityClass}`;
    }

    handlePermissionSearchChange(event) {
        this.permissionSearch = event.target.value || '';
    }

    handlePermissionKeyChange(event) {
        this.selectedPermissionKey = event.detail.value || '';
    }

    handleDateFromChange(event) {
        this.dateFrom = event.target.value || '';
    }

    handleDateToChange(event) {
        this.dateTo = event.target.value || '';
    }

    async handleSearchPermissionKeys() {
        if (this.isSearchKeysDisabled) {
            return;
        }
        this.isLoadingKeys = true;
        this.errorMessage = '';
        try {
            const rows = await searchPermissionKeys({
                term: this.permissionSearch,
                categories: PERMISSION_CATEGORIES
            });
            this.permissionKeyOptions = (rows || []).map((row) => ({
                value: row.key,
                label: row.displayLabel
            }));
            if (this.permissionKeyOptions.length > 0) {
                this.selectedPermissionKey = this.permissionKeyOptions[0].value;
            }
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isLoadingKeys = false;
        }
    }

    async handleRunWhoHas() {
        if (this.isWhoHasDisabled) {
            return;
        }
        this.isLoadingWhoHas = true;
        this.errorMessage = '';
        try {
            const rows = await whoHas({
                permissionKey: this.selectedPermissionKey,
                asOfDate: null
            });
            this.whoHasRows = (rows || []).map((row) => ({
                key: `${row.userId}-${row.sourceSummary}`,
                ...row
            }));
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isLoadingWhoHas = false;
        }
    }

    async handleLoadChanges() {
        await this.loadChanges();
    }

    async loadChanges() {
        if (this.dateFrom === '' || this.dateTo === '') {
            return;
        }
        this.isLoadingChanges = true;
        this.errorMessage = '';
        try {
            const rows = await getLedgerEvents({
                targetId: this.permissionSetId,
                dateFrom: this.dateFrom,
                dateTo: this.dateTo
            });
            this.changeRows = (rows || []).map((row) => ({
                key: row.changeId,
                ...row,
                createdDateDisplay: this.formatDateTime(row.createdDate)
            }));
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isLoadingChanges = false;
        }
    }

    handleExportWhoHas() {
        if (this.isExportWhoHasDisabled) {
            return;
        }
        const headers = [
            this.labels.columnName,
            this.labels.columnUsername,
            this.labels.columnProfile,
            this.labels.columnAccess,
            this.labels.columnSource
        ];
        const rows = this.whoHasRows.map((row) => [
            row.name,
            row.username,
            row.profileName,
            row.accessLevel,
            row.sourceSummary
        ]);
        this.downloadCsv('permission-studio-who-has.csv', headers, rows);
    }

    handleExportChanges() {
        if (this.isExportChangesDisabled) {
            return;
        }
        const headers = [
            this.labels.columnWhen,
            this.labels.columnTargetType,
            this.labels.columnTargetName,
            this.labels.columnSection,
            this.labels.columnChanged
        ];
        const rows = this.changeRows.map((row) => [
            row.createdDateDisplay,
            row.targetType,
            row.targetName,
            row.sectionName,
            row.changedCount
        ]);
        this.downloadCsv('permission-studio-ledger-events.csv', headers, rows);
    }

    downloadCsv(fileName, headers, rows) {
        const lines = [];
        lines.push(headers.map((value) => this.csvEscape(value)).join(','));
        for (const row of rows) {
            lines.push(row.map((value) => this.csvEscape(value)).join(','));
        }
        const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(blob);
        const anchor = document.createElement('a');
        anchor.href = url;
        anchor.download = fileName;
        anchor.target = '_self';
        anchor.click();
        URL.revokeObjectURL(url);
    }

    csvEscape(value) {
        const text = value === null || value === undefined ? '' : String(value);
        const escaped = text.replace(/"/g, '""');
        return `"${escaped}"`;
    }

    toDateInput(value) {
        const year = value.getFullYear();
        const month = String(value.getMonth() + 1).padStart(2, '0');
        const day = String(value.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    formatDateTime(value) {
        if (!value) {
            return '';
        }
        const asDate = new Date(value);
        if (Number.isNaN(asDate.getTime())) {
            return value;
        }
        return asDate.toLocaleString();
    }

    resolveErrorMessage(error) {
        const bodyMessage = error && error.body && error.body.message ? error.body.message : '';
        return bodyMessage || this.labels.error;
    }

    showErrorToast(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: this.labels.toastErrorTitle,
                message,
                variant: 'error'
            })
        );
    }
}