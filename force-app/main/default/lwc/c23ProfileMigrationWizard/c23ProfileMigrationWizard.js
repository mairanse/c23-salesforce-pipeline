import { api, LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getExplorerData from '@salesforce/apex/c23_PermissionStudioExplorerService.getExplorerData';
import buildPlan from '@salesforce/apex/c23_ProfileMigrationPlanService.buildPlan';
import startMigration from '@salesforce/apex/c23_ProfileMigrationJobService.start';
import getStatus from '@salesforce/apex/c23_ProfileMigrationJobService.getStatus';
import getWarnings from '@salesforce/apex/c23_ProfileMigrationJobService.getWarnings';
import c23_PS_General_Cancel from '@salesforce/label/c.c23_PS_General_Cancel';
import c23_PS_General_Back from '@salesforce/label/c.c23_PS_General_Back';
import c23_PS_General_Next from '@salesforce/label/c.c23_PS_General_Next';
import c23_PS_General_Loading from '@salesforce/label/c.c23_PS_General_Loading';
import c23_PS_General_Error from '@salesforce/label/c.c23_PS_General_Error';
import c23_PS_General_ToastErrorTitle from '@salesforce/label/c.c23_PS_General_ToastErrorTitle';
import c23_PS_General_ToastSuccessTitle from '@salesforce/label/c.c23_PS_General_ToastSuccessTitle';
import c23_PS_ObjectMatrix_Title from '@salesforce/label/c.c23_PS_ObjectMatrix_Title';
import c23_PS_Field_Title from '@salesforce/label/c.c23_PS_Field_Title';
import c23_PS_System_Title from '@salesforce/label/c.c23_PS_System_Title';
import c23_PS_Tab_Title from '@salesforce/label/c.c23_PS_Tab_Title';
import c23_PS_Setup_Title from '@salesforce/label/c.c23_PS_Setup_Title';
import c23_PS_MIG_Title from '@salesforce/label/c.c23_PS_MIG_Title';
import c23_PS_MIG_Action_Close from '@salesforce/label/c.c23_PS_MIG_Action_Close';
import c23_PS_MIG_Action_Run from '@salesforce/label/c.c23_PS_MIG_Action_Run';
import c23_PS_MIG_SourceProfile from '@salesforce/label/c.c23_PS_MIG_SourceProfile';
import c23_PS_MIG_Step_Scope from '@salesforce/label/c.c23_PS_MIG_Step_Scope';
import c23_PS_MIG_Step_Target from '@salesforce/label/c.c23_PS_MIG_Step_Target';
import c23_PS_MIG_Step_Preview from '@salesforce/label/c.c23_PS_MIG_Step_Preview';
import c23_PS_MIG_Step_Execute from '@salesforce/label/c.c23_PS_MIG_Step_Execute';
import c23_PS_MIG_Scope_Object from '@salesforce/label/c.c23_PS_MIG_Scope_Object';
import c23_PS_MIG_Scope_Field from '@salesforce/label/c.c23_PS_MIG_Scope_Field';
import c23_PS_MIG_Scope_System from '@salesforce/label/c.c23_PS_MIG_Scope_System';
import c23_PS_MIG_Scope_Tab from '@salesforce/label/c.c23_PS_MIG_Scope_Tab';
import c23_PS_MIG_Scope_Setup from '@salesforce/label/c.c23_PS_MIG_Scope_Setup';
import c23_PS_MIG_Scope_GrantedOnly from '@salesforce/label/c.c23_PS_MIG_Scope_GrantedOnly';
import c23_PS_MIG_Scope_CustomOnly from '@salesforce/label/c.c23_PS_MIG_Scope_CustomOnly';
import c23_PS_MIG_Target_Mode from '@salesforce/label/c.c23_PS_MIG_Target_Mode';
import c23_PS_MIG_Target_ModeCreate from '@salesforce/label/c.c23_PS_MIG_Target_ModeCreate';
import c23_PS_MIG_Target_ModeMerge from '@salesforce/label/c.c23_PS_MIG_Target_ModeMerge';
import c23_PS_MIG_Target_PermissionSetName from '@salesforce/label/c.c23_PS_MIG_Target_PermissionSetName';
import c23_PS_MIG_Target_PermissionSetApiName from '@salesforce/label/c.c23_PS_MIG_Target_PermissionSetApiName';
import c23_PS_MIG_Target_MergePermissionSet from '@salesforce/label/c.c23_PS_MIG_Target_MergePermissionSet';
import c23_PS_MIG_Target_MergeStrategy from '@salesforce/label/c.c23_PS_MIG_Target_MergeStrategy';
import c23_PS_MIG_Target_MergeStrategyUnion from '@salesforce/label/c.c23_PS_MIG_Target_MergeStrategyUnion';
import c23_PS_MIG_Target_MergeStrategyOverwrite from '@salesforce/label/c.c23_PS_MIG_Target_MergeStrategyOverwrite';
import c23_PS_MIG_Preview_PlannedChanges from '@salesforce/label/c.c23_PS_MIG_Preview_PlannedChanges';
import c23_PS_MIG_Preview_Filter_Differences from '@salesforce/label/c.c23_PS_MIG_Preview_Filter_Differences';
import c23_PS_MIG_Preview_Filter_Access from '@salesforce/label/c.c23_PS_MIG_Preview_Filter_Access';
import c23_PS_MIG_Preview_Filter_Custom from '@salesforce/label/c.c23_PS_MIG_Preview_Filter_Custom';
import c23_PS_MIG_Preview_Column_Key from '@salesforce/label/c.c23_PS_MIG_Preview_Column_Key';
import c23_PS_MIG_Preview_Column_Source from '@salesforce/label/c.c23_PS_MIG_Preview_Column_Source';
import c23_PS_MIG_Preview_Column_Target from '@salesforce/label/c.c23_PS_MIG_Preview_Column_Target';
import c23_PS_MIG_Preview_Column_Result from '@salesforce/label/c.c23_PS_MIG_Preview_Column_Result';
import c23_PS_MIG_Execute_AssignUsers from '@salesforce/label/c.c23_PS_MIG_Execute_AssignUsers';
import c23_PS_MIG_Execute_SwapUsers from '@salesforce/label/c.c23_PS_MIG_Execute_SwapUsers';
import c23_PS_MIG_Execute_BaseProfile from '@salesforce/label/c.c23_PS_MIG_Execute_BaseProfile';
import c23_PS_MIG_Execute_Status from '@salesforce/label/c.c23_PS_MIG_Execute_Status';
import c23_PS_MIG_Execute_TargetPermissionSet from '@salesforce/label/c.c23_PS_MIG_Execute_TargetPermissionSet';
import c23_PS_MIG_Warnings_Title from '@salesforce/label/c.c23_PS_MIG_Warnings_Title';
import c23_PS_MIG_Status_Queued from '@salesforce/label/c.c23_PS_MIG_Status_Queued';
import c23_PS_MIG_Status_Running from '@salesforce/label/c.c23_PS_MIG_Status_Running';
import c23_PS_MIG_Status_Finalizing from '@salesforce/label/c.c23_PS_MIG_Status_Finalizing';
import c23_PS_MIG_Status_Completed from '@salesforce/label/c.c23_PS_MIG_Status_Completed';
import c23_PS_MIG_Status_CompletedWithWarnings from '@salesforce/label/c.c23_PS_MIG_Status_CompletedWithWarnings';
import c23_PS_MIG_Status_Failed from '@salesforce/label/c.c23_PS_MIG_Status_Failed';
import c23_PS_MIG_Error_SelectScope from '@salesforce/label/c.c23_PS_MIG_Error_SelectScope';
import c23_PS_MIG_Error_TargetName from '@salesforce/label/c.c23_PS_MIG_Error_TargetName';
import c23_PS_MIG_Error_TargetMergeSelection from '@salesforce/label/c.c23_PS_MIG_Error_TargetMergeSelection';
import c23_PS_MIG_NoRows from '@salesforce/label/c.c23_PS_MIG_NoRows';
import c23_PS_MIG_StartSuccess from '@salesforce/label/c.c23_PS_MIG_StartSuccess';

const STEP_SCOPE = 0;
const STEP_TARGET = 1;
const STEP_PREVIEW = 2;
const STEP_EXECUTE = 3;
const POLL_INTERVAL_MS = 2000;

export default class C23ProfileMigrationWizard extends LightningElement {
    @api profileId;
    @api profileName;
    @api sourcePermissionSetId;
    @api density = 'comfortable';

    labels = {
        title: c23_PS_MIG_Title,
        close: c23_PS_MIG_Action_Close,
        runMigration: c23_PS_MIG_Action_Run,
        cancel: c23_PS_General_Cancel,
        back: c23_PS_General_Back,
        next: c23_PS_General_Next,
        loading: c23_PS_General_Loading,
        error: c23_PS_General_Error,
        toastErrorTitle: c23_PS_General_ToastErrorTitle,
        toastSuccessTitle: c23_PS_General_ToastSuccessTitle,
        stepScope: c23_PS_MIG_Step_Scope,
        stepTarget: c23_PS_MIG_Step_Target,
        stepPreview: c23_PS_MIG_Step_Preview,
        stepExecute: c23_PS_MIG_Step_Execute,
        sourceProfile: c23_PS_MIG_SourceProfile,
        scopeObject: c23_PS_MIG_Scope_Object,
        scopeField: c23_PS_MIG_Scope_Field,
        scopeSystem: c23_PS_MIG_Scope_System,
        scopeTab: c23_PS_MIG_Scope_Tab,
        scopeSetup: c23_PS_MIG_Scope_Setup,
        scopeGrantedOnly: c23_PS_MIG_Scope_GrantedOnly,
        scopeCustomOnly: c23_PS_MIG_Scope_CustomOnly,
        targetMode: c23_PS_MIG_Target_Mode,
        targetModeCreate: c23_PS_MIG_Target_ModeCreate,
        targetModeMerge: c23_PS_MIG_Target_ModeMerge,
        targetPermissionSetName: c23_PS_MIG_Target_PermissionSetName,
        targetPermissionSetApiName: c23_PS_MIG_Target_PermissionSetApiName,
        targetMergePermissionSet: c23_PS_MIG_Target_MergePermissionSet,
        targetMergeStrategy: c23_PS_MIG_Target_MergeStrategy,
        targetMergeStrategyUnion: c23_PS_MIG_Target_MergeStrategyUnion,
        targetMergeStrategyOverwrite: c23_PS_MIG_Target_MergeStrategyOverwrite,
        previewPlannedChanges: c23_PS_MIG_Preview_PlannedChanges,
        previewFilterDifferences: c23_PS_MIG_Preview_Filter_Differences,
        previewFilterAccess: c23_PS_MIG_Preview_Filter_Access,
        previewFilterCustom: c23_PS_MIG_Preview_Filter_Custom,
        previewColumnKey: c23_PS_MIG_Preview_Column_Key,
        previewColumnSource: c23_PS_MIG_Preview_Column_Source,
        previewColumnTarget: c23_PS_MIG_Preview_Column_Target,
        previewColumnResult: c23_PS_MIG_Preview_Column_Result,
        executeAssignUsers: c23_PS_MIG_Execute_AssignUsers,
        executeSwapUsers: c23_PS_MIG_Execute_SwapUsers,
        executeBaseProfile: c23_PS_MIG_Execute_BaseProfile,
        executeStatus: c23_PS_MIG_Execute_Status,
        executeTargetPermissionSet: c23_PS_MIG_Execute_TargetPermissionSet,
        warningsTitle: c23_PS_MIG_Warnings_Title,
        statusQueued: c23_PS_MIG_Status_Queued,
        statusRunning: c23_PS_MIG_Status_Running,
        statusFinalizing: c23_PS_MIG_Status_Finalizing,
        statusCompleted: c23_PS_MIG_Status_Completed,
        statusCompletedWithWarnings: c23_PS_MIG_Status_CompletedWithWarnings,
        statusFailed: c23_PS_MIG_Status_Failed,
        errorSelectScope: c23_PS_MIG_Error_SelectScope,
        errorTargetName: c23_PS_MIG_Error_TargetName,
        errorTargetMergeSelection: c23_PS_MIG_Error_TargetMergeSelection,
        noRows: c23_PS_MIG_NoRows,
        startSuccess: c23_PS_MIG_StartSuccess,
        objectTitle: c23_PS_ObjectMatrix_Title,
        fieldTitle: c23_PS_Field_Title,
        systemTitle: c23_PS_System_Title,
        tabTitle: c23_PS_Tab_Title,
        setupTitle: c23_PS_Setup_Title
    };

    currentStep = STEP_SCOPE;
    scopeObjectPermissions = true;
    scopeFieldPermissions = true;
    scopeSystemPermissions = true;
    scopeTabVisibility = true;
    scopeSetupAccess = true;
    scopeGrantedOnly = true;
    scopeCustomObjectsOnly = false;

    targetMode = 'CREATE';
    targetPermissionSetId = '';
    targetPermissionSetName = '';
    targetPermissionSetApiName = '';
    mergeStrategy = 'UNION';
    hasManualApiName = false;

    permissionSetOptions = [];
    profileOptions = [];

    plan = null;
    previewCategory = 'OBJECT';
    previewDifferencesOnly = true;
    previewRowsWithAccess = false;
    previewCustomObjectsOnly = false;

    assignUsersFromProfile = true;
    switchUsersToBase = false;
    baseProfileId = '';

    isLoadingOptions = false;
    isLoadingPreview = false;
    isStartingMigration = false;
    isPollingStatus = false;
    errorMessage = '';

    migrationJobId = null;
    migrationJob = null;
    warnings = [];
    pollHandle = null;

    connectedCallback() {
        this.targetPermissionSetName = this.defaultTargetName;
        this.targetPermissionSetApiName = this.sanitizeApiName(this.targetPermissionSetName);
        this.loadTargetOptions();
    }

    disconnectedCallback() {
        this.stopPolling();
    }

    get stepRows() {
        return [
            this.buildStepRow('scope', this.labels.stepScope, STEP_SCOPE),
            this.buildStepRow('target', this.labels.stepTarget, STEP_TARGET),
            this.buildStepRow('preview', this.labels.stepPreview, STEP_PREVIEW),
            this.buildStepRow('execute', this.labels.stepExecute, STEP_EXECUTE)
        ];
    }

    get isScopeStep() {
        return this.currentStep === STEP_SCOPE;
    }

    get isTargetStep() {
        return this.currentStep === STEP_TARGET;
    }

    get isPreviewStep() {
        return this.currentStep === STEP_PREVIEW;
    }

    get isExecuteStep() {
        return this.currentStep === STEP_EXECUTE;
    }

    get isBusy() {
        return this.isLoadingOptions || this.isLoadingPreview || this.isStartingMigration || this.isPollingStatus;
    }

    get showSpinner() {
        return this.isBusy;
    }

    get hasErrorMessage() {
        return this.errorMessage !== '';
    }

    get isBackDisabled() {
        return this.currentStep === STEP_SCOPE || this.isBusy;
    }

    get showNextButton() {
        return this.currentStep !== STEP_EXECUTE;
    }

    get showRunButton() {
        return this.currentStep === STEP_EXECUTE;
    }

    get isNextDisabled() {
        if (this.isBusy) {
            return true;
        }
        if (this.currentStep === STEP_SCOPE) {
            return !this.hasAnyScopeSelected;
        }
        if (this.currentStep === STEP_TARGET) {
            return !this.isTargetStepValid;
        }
        return false;
    }

    get isRunDisabled() {
        if (this.isBusy || !this.plan) {
            return true;
        }
        if (this.migrationJobId) {
            return true;
        }
        if (this.switchUsersToBase && !this.baseProfileId) {
            return true;
        }
        if (this.hasTerminalJobStatus) {
            return true;
        }
        return false;
    }

    get targetModeOptions() {
        return [
            { label: this.labels.targetModeCreate, value: 'CREATE' },
            { label: this.labels.targetModeMerge, value: 'MERGE' }
        ];
    }

    get mergeStrategyOptions() {
        return [
            { label: this.labels.targetMergeStrategyUnion, value: 'UNION' },
            { label: this.labels.targetMergeStrategyOverwrite, value: 'OVERWRITE' }
        ];
    }

    get isCreateMode() {
        return this.targetMode === 'CREATE';
    }

    get isMergeMode() {
        return this.targetMode === 'MERGE';
    }

    get hasAnyScopeSelected() {
        return (
            this.scopeObjectPermissions ||
            this.scopeFieldPermissions ||
            this.scopeSystemPermissions ||
            this.scopeTabVisibility ||
            this.scopeSetupAccess
        );
    }

    get isTargetStepValid() {
        if (this.isCreateMode) {
            return this.targetPermissionSetName.trim() !== '' && this.targetPermissionSetApiName.trim() !== '';
        }
        return this.targetPermissionSetId !== '';
    }

    get defaultTargetName() {
        const sourceName = this.profileName || '';
        return `${sourceName} Migrated`;
    }

    get previewCategoryRows() {
        const categories = [
            { value: 'OBJECT', label: this.labels.objectTitle, count: this.countByCategory('OBJECT') },
            { value: 'FIELD', label: this.labels.fieldTitle, count: this.countByCategory('FIELD') },
            { value: 'SYSTEM', label: this.labels.systemTitle, count: this.countByCategory('SYSTEM') },
            { value: 'TAB', label: this.labels.tabTitle, count: this.countByCategory('TAB') },
            { value: 'SETUP', label: this.labels.setupTitle, count: this.countByCategory('SETUP') }
        ];

        return categories.map((row) => ({
            ...row,
            label: `${row.label} (${row.count})`,
            className: row.value === this.previewCategory ? 'c23-mig__tab c23-mig__tab_active' : 'c23-mig__tab'
        }));
    }

    get plannedChangesCountText() {
        const count = this.plan && this.plan.changedCount ? this.plan.changedCount : 0;
        return String(count);
    }

    get visiblePreviewRows() {
        const rows = this.getRowsByCategory();
        return rows.filter((row) => this.previewRowPassesFilters(row));
    }

    get showPreviewRows() {
        return this.visiblePreviewRows.length > 0;
    }

    get densityClass() {
        return this.density === 'compact' ? 'density-compact' : 'density-comfortable';
    }

    get previewTableWrapClass() {
        return `c23-mig__table-wrap ${this.densityClass}`;
    }

    get showBaseProfileSelector() {
        return this.switchUsersToBase;
    }

    get showJobStatus() {
        return this.migrationJob !== null;
    }

    get showWarnings() {
        return this.warnings.length > 0;
    }

    get hasTerminalJobStatus() {
        if (!this.migrationJob || !this.migrationJob.status) {
            return false;
        }
        return (
            this.migrationJob.status === 'Completed' ||
            this.migrationJob.status === 'CompletedWithWarnings' ||
            this.migrationJob.status === 'Failed'
        );
    }

    get jobStatusLabel() {
        if (!this.migrationJob || !this.migrationJob.status) {
            return '';
        }
        if (this.migrationJob.status === 'Queued') {
            return this.labels.statusQueued;
        }
        if (this.migrationJob.status === 'Running') {
            return this.labels.statusRunning;
        }
        if (this.migrationJob.status === 'Finalizing') {
            return this.labels.statusFinalizing;
        }
        if (this.migrationJob.status === 'Completed') {
            return this.labels.statusCompleted;
        }
        if (this.migrationJob.status === 'CompletedWithWarnings') {
            return this.labels.statusCompletedWithWarnings;
        }
        if (this.migrationJob.status === 'Failed') {
            return this.labels.statusFailed;
        }
        return this.migrationJob.status;
    }

    get showTargetPermissionSetLink() {
        return Boolean(this.migrationJob && this.migrationJob.targetPermissionSetId);
    }

    get targetPermissionSetUrl() {
        return this.showTargetPermissionSetLink
            ? `/lightning/r/PermissionSet/${this.migrationJob.targetPermissionSetId}/view`
            : '';
    }

    get jobTargetPermissionSetName() {
        if (!this.migrationJob) {
            return '';
        }
        return this.migrationJob.targetPermissionSetName || this.migrationJob.targetPermissionSetId || '';
    }

    async loadTargetOptions() {
        this.isLoadingOptions = true;
        this.errorMessage = '';
        try {
            const response = await getExplorerData();
            this.permissionSetOptions = this.toPermissionSetOptions(response && response.permissionSets ? response.permissionSets : []);
            this.profileOptions = this.toProfileOptions(response && response.profiles ? response.profiles : []);
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
        } finally {
            this.isLoadingOptions = false;
        }
    }

    toPermissionSetOptions(permissionSets) {
        return permissionSets
            .filter((row) => row && row.isOwnedByProfile !== true)
            .map((row) => ({
                value: row.id,
                label: row.label || row.apiName
            }))
            .sort((left, right) => this.compareValues(left.label, right.label));
    }

    toProfileOptions(profiles) {
        return (profiles || [])
            .map((row) => ({
                value: row.id,
                label: row.name
            }))
            .sort((left, right) => this.compareValues(left.label, right.label));
    }

    compareValues(left, right) {
        const leftValue = (left || '').toLowerCase();
        const rightValue = (right || '').toLowerCase();
        if (leftValue === rightValue) {
            return 0;
        }
        return leftValue < rightValue ? -1 : 1;
    }

    handleClose() {
        this.stopPolling();
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleBack() {
        if (this.isBackDisabled) {
            return;
        }
        this.currentStep = Math.max(STEP_SCOPE, this.currentStep - 1);
        this.errorMessage = '';
    }

    async handleNext() {
        if (this.isNextDisabled) {
            if (this.currentStep === STEP_SCOPE) {
                this.errorMessage = this.labels.errorSelectScope;
            }
            if (this.currentStep === STEP_TARGET) {
                this.errorMessage = this.isCreateMode ? this.labels.errorTargetName : this.labels.errorTargetMergeSelection;
            }
            return;
        }

        if (this.currentStep === STEP_TARGET) {
            await this.loadPlanPreview();
            if (!this.plan) {
                return;
            }
        }

        if (this.currentStep < STEP_EXECUTE) {
            this.currentStep += 1;
        }
    }

    handleScopeToggle(event) {
        const fieldName = event.target && event.target.dataset ? event.target.dataset.field : '';
        if (!fieldName) {
            return;
        }
        this[fieldName] = event.target.checked === true;
    }

    handleTargetModeChange(event) {
        this.targetMode = event.detail.value || 'CREATE';
    }

    handleTargetNameChange(event) {
        this.targetPermissionSetName = event.target.value || '';
        if (!this.hasManualApiName) {
            this.targetPermissionSetApiName = this.sanitizeApiName(this.targetPermissionSetName);
        }
    }

    handleTargetApiNameChange(event) {
        this.hasManualApiName = true;
        this.targetPermissionSetApiName = this.sanitizeApiName(event.target.value || '');
    }

    handleTargetPermissionSetChange(event) {
        this.targetPermissionSetId = event.detail.value || '';
    }

    handleMergeStrategyChange(event) {
        this.mergeStrategy = event.detail.value || 'UNION';
    }

    handlePreviewCategorySelect(event) {
        const value = event.currentTarget && event.currentTarget.dataset ? event.currentTarget.dataset.value : '';
        if (!value) {
            return;
        }
        this.previewCategory = value;
    }

    handlePreviewDifferencesOnly(event) {
        this.previewDifferencesOnly = event.target.checked === true;
    }

    handlePreviewAccessOnly(event) {
        this.previewRowsWithAccess = event.target.checked === true;
    }

    handlePreviewCustomOnly(event) {
        this.previewCustomObjectsOnly = event.target.checked === true;
    }

    handleAssignUsersToggle(event) {
        this.assignUsersFromProfile = event.target.checked === true;
    }

    handleSwitchUsersToggle(event) {
        this.switchUsersToBase = event.target.checked === true;
    }

    handleBaseProfileChange(event) {
        this.baseProfileId = event.detail.value || '';
    }

    async loadPlanPreview() {
        this.isLoadingPreview = true;
        this.errorMessage = '';
        try {
            const response = await buildPlan({
                profileId: this.profileId,
                targetMode: this.targetMode,
                targetPermissionSetId: this.isMergeMode ? this.targetPermissionSetId : null,
                targetPermissionSetName: this.isCreateMode ? this.targetPermissionSetName : null,
                targetPermissionSetApiName: this.isCreateMode ? this.targetPermissionSetApiName : null,
                mergeStrategy: this.mergeStrategy,
                scopeOptionsJson: JSON.stringify(this.scopeOptions)
            });
            this.plan = response;
            this.previewCategory = this.resolveDefaultPreviewCategory();
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isLoadingPreview = false;
        }
    }

    async handleRunMigration() {
        if (this.isRunDisabled) {
            return;
        }

        this.isStartingMigration = true;
        this.errorMessage = '';
        try {
            const response = await startMigration({
                profileId: this.profileId,
                targetMode: this.targetMode,
                targetPermissionSetId: this.isMergeMode ? this.targetPermissionSetId : null,
                targetPermissionSetName: this.isCreateMode ? this.targetPermissionSetName : null,
                targetPermissionSetApiName: this.isCreateMode ? this.targetPermissionSetApiName : null,
                mergeStrategy: this.mergeStrategy,
                scopeOptionsJson: JSON.stringify(this.scopeOptions),
                assignUsersFromProfile: this.assignUsersFromProfile,
                switchUsersToBaseProfile: this.switchUsersToBase,
                baseProfileId: this.switchUsersToBase ? this.baseProfileId : null
            });
            this.migrationJobId = response.jobId;
            this.migrationJob = {
                status: response.status,
                targetPermissionSetId: response.targetPermissionSetId,
                targetPermissionSetName: response.targetPermissionSetName
            };
            this.showSuccessToast(this.labels.startSuccess);
            this.startPolling();
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isStartingMigration = false;
        }
    }

    startPolling() {
        this.stopPolling();
        this.pollHandle = setInterval(() => {
            this.refreshStatus();
        }, POLL_INTERVAL_MS);
        this.refreshStatus();
    }

    stopPolling() {
        if (this.pollHandle) {
            clearInterval(this.pollHandle);
            this.pollHandle = null;
        }
    }

    async refreshStatus() {
        if (!this.migrationJobId) {
            return;
        }

        this.isPollingStatus = true;
        try {
            const status = await getStatus({ jobId: this.migrationJobId });
            this.migrationJob = status;

            if (this.hasTerminalJobStatus) {
                this.stopPolling();
                if (status && status.warningCount && status.warningCount > 0) {
                    await this.loadWarnings();
                }
            }
        } catch (error) {
            this.stopPolling();
            this.errorMessage = this.resolveErrorMessage(error);
            this.showErrorToast(this.errorMessage);
        } finally {
            this.isPollingStatus = false;
        }
    }

    async loadWarnings() {
        if (!this.migrationJobId) {
            this.warnings = [];
            return;
        }
        try {
            const warningRows = await getWarnings({ jobId: this.migrationJobId });
            this.warnings = (warningRows || []).map((row, index) => ({
                key: `warning-${index}-${row.permissionKey}`,
                message: row.message
            }));
        } catch (error) {
            this.errorMessage = this.resolveErrorMessage(error);
        }
    }

    get scopeOptions() {
        return {
            includeObjectPermissions: this.scopeObjectPermissions,
            includeFieldPermissions: this.scopeFieldPermissions,
            includeSystemPermissions: this.scopeSystemPermissions,
            includeTabVisibility: this.scopeTabVisibility,
            includeSetupAccess: this.scopeSetupAccess,
            includeGrantedOnly: this.scopeGrantedOnly,
            includeCustomObjectsOnly: this.scopeCustomObjectsOnly
        };
    }

    getRowsByCategory() {
        if (!this.plan) {
            return [];
        }
        if (this.previewCategory === 'OBJECT') {
            return this.plan.objectRows || [];
        }
        if (this.previewCategory === 'FIELD') {
            return this.plan.fieldRows || [];
        }
        if (this.previewCategory === 'SYSTEM') {
            return this.plan.systemRows || [];
        }
        if (this.previewCategory === 'TAB') {
            return this.plan.tabRows || [];
        }
        if (this.previewCategory === 'SETUP') {
            return this.plan.setupRows || [];
        }
        return [];
    }

    previewRowPassesFilters(row) {
        if (!row) {
            return false;
        }
        if (this.previewDifferencesOnly && row.isChanged !== true) {
            return false;
        }
        if (this.previewRowsWithAccess && row.hasAccess !== true) {
            return false;
        }
        if (this.previewCustomObjectsOnly && row.isCustom !== true) {
            return false;
        }
        return true;
    }

    countByCategory(category) {
        if (!this.plan || !this.plan.categoryCounts) {
            return 0;
        }
        if (Array.isArray(this.plan.categoryCounts)) {
            const row = this.plan.categoryCounts.find((item) => item.category === category);
            return row && row.count ? row.count : 0;
        }
        const value = this.plan.categoryCounts[category];
        return value ? value : 0;
    }

    resolveDefaultPreviewCategory() {
        const rows = this.previewCategoryRows;
        const nonZero = rows.find((row) => row.count > 0);
        return nonZero ? nonZero.value : 'OBJECT';
    }

    buildStepRow(key, label, index) {
        let className = 'c23-mig__step';
        if (index < this.currentStep) {
            className += ' c23-mig__step_done';
        }
        if (index === this.currentStep) {
            className += ' c23-mig__step_active';
        }
        return {
            key,
            label,
            className
        };
    }

    sanitizeApiName(value) {
        const normalized = (value || '')
            .trim()
            .replace(/[^A-Za-z0-9_]/g, '_')
            .replace(/_+/g, '_');
        if (!normalized) {
            return '';
        }
        const startsWithLetter = /^[A-Za-z]/.test(normalized);
        const withPrefix = startsWithLetter ? normalized : `PS_${normalized}`;
        return withPrefix.substring(0, 40);
    }

    resolveErrorMessage(error) {
        const bodyMessage = error && error.body && error.body.message ? error.body.message : '';
        return bodyMessage || this.labels.error;
    }

    showSuccessToast(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: this.labels.toastSuccessTitle,
                message,
                variant: 'success'
            })
        );
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