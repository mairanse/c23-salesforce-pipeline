import { LightningElement } from 'lwc';
import getUserSettings from '@salesforce/apex/c23_PermissionStudioUserSettingsService.getUserSettings';
import saveUserSettings from '@salesforce/apex/c23_PermissionStudioUserSettingsService.saveUserSettings';
import c23_PS_App_ExplorerCollapse from '@salesforce/label/c.c23_PS_App_ExplorerCollapse';
import c23_PS_App_ExplorerExpand from '@salesforce/label/c.c23_PS_App_ExplorerExpand';
import c23_PS_App_HideDetails from '@salesforce/label/c.c23_PS_App_HideDetails';
import c23_PS_App_LeftPaneTitle from '@salesforce/label/c.c23_PS_App_LeftPaneTitle';
import c23_PS_App_RightPanePrompt from '@salesforce/label/c.c23_PS_App_RightPanePrompt';
import c23_PS_App_RightPaneTitle from '@salesforce/label/c.c23_PS_App_RightPaneTitle';
import c23_PS_App_ShowDetails from '@salesforce/label/c.c23_PS_App_ShowDetails';
import c23_PS_Assignments_Title from '@salesforce/label/c.c23_PS_Assignments_Title';
import c23_PS_General_Apply from '@salesforce/label/c.c23_PS_General_Apply';
import c23_PS_General_PendingChanges from '@salesforce/label/c.c23_PS_General_PendingChanges';
import c23_PS_General_Reset from '@salesforce/label/c.c23_PS_General_Reset';
import c23_PS_MIG_Action_Close from '@salesforce/label/c.c23_PS_MIG_Action_Close';
import c23_PS_MIG_Action_Migrate from '@salesforce/label/c.c23_PS_MIG_Action_Migrate';
import c23_PS_ObjectMatrix_Density from '@salesforce/label/c.c23_PS_ObjectMatrix_Density';
import c23_PS_ObjectMatrix_Density_Comfortable from '@salesforce/label/c.c23_PS_ObjectMatrix_Density_Comfortable';
import c23_PS_ObjectMatrix_Density_Compact from '@salesforce/label/c.c23_PS_ObjectMatrix_Density_Compact';

const TYPE_PERMISSION_SET = 'PermissionSet';
const TYPE_PROFILE = 'Profile';
const TYPE_PERMISSION_SET_GROUP = 'PermissionSetGroup';
const DENSITY_COMFORTABLE = 'comfortable';
const DENSITY_COMPACT = 'compact';

export default class C23PermissionStudioApp extends LightningElement {
    labels = {
        apply: c23_PS_General_Apply,
        assignmentsTitle: c23_PS_Assignments_Title,
        close: c23_PS_MIG_Action_Close,
        density: c23_PS_ObjectMatrix_Density,
        densityComfortable: c23_PS_ObjectMatrix_Density_Comfortable,
        densityCompact: c23_PS_ObjectMatrix_Density_Compact,
        explorerCollapse: c23_PS_App_ExplorerCollapse,
        explorerExpand: c23_PS_App_ExplorerExpand,
        hideDetails: c23_PS_App_HideDetails,
        leftPaneTitle: c23_PS_App_LeftPaneTitle,
        migrate: c23_PS_MIG_Action_Migrate,
        pendingChanges: c23_PS_General_PendingChanges,
        reset: c23_PS_General_Reset,
        rightPanePrompt: c23_PS_App_RightPanePrompt,
        rightPaneTitle: c23_PS_App_RightPaneTitle,
        showDetails: c23_PS_App_ShowDetails
    };

    summaryRows = [];
    selectedItem = null;
    isDetailsExpanded = true;
    isExplorerCollapsed = false;
    isMigrationWizardOpen = false;
    isAssignmentsDialogOpen = false;
    tableDensity = DENSITY_COMFORTABLE;
    editorState = this.defaultEditorState();

    connectedCallback() {
        this.loadUserSettings();
    }

    get shellClass() {
        return this.isExplorerCollapsed ? 'c23-shell c23-shell--explorer-collapsed' : 'c23-shell';
    }

    get leftPaneClass() {
        return this.isExplorerCollapsed ? 'c23-shell__left c23-shell__left--collapsed' : 'c23-shell__left';
    }

    get explorerToggleIcon() {
        return this.isExplorerCollapsed ? 'utility:chevronright' : 'utility:chevronleft';
    }

    get explorerToggleLabel() {
        return this.isExplorerCollapsed ? this.labels.explorerExpand : this.labels.explorerCollapse;
    }

    get hasSelection() {
        return this.selectedItem !== null;
    }

    get hasSummaryRows() {
        return this.summaryRows.length > 0;
    }

    get metricRows() {
        return this.summaryRows.slice(2);
    }

    get hasMetricRows() {
        return this.metricRows.length > 0;
    }

    get hasSummaryCountsText() {
        return this.summaryCountsText !== '';
    }

    get summaryCountsText() {
        if (!this.hasMetricRows) {
            return '';
        }
        return this.metricRows.map((row) => `${row.label} ${row.value}`).join(' · ');
    }

    get selectionContextText() {
        if (!this.hasSelection) {
            return this.labels.rightPaneTitle;
        }
        const typeLabel = this.selectedItem.typeLabel || this.labels.rightPaneTitle;
        const nameLabel = this.selectedItem.displayName || '';
        return `${typeLabel} > ${nameLabel}`;
    }

    get showDetailsPanel() {
        return this.isDetailsExpanded && (this.hasSummaryRows || !this.hasSelection);
    }

    get showDetailsToggle() {
        return this.hasSummaryRows;
    }

    get detailsToggleIcon() {
        return this.isDetailsExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get detailsToggleLabel() {
        return this.isDetailsExpanded ? this.labels.hideDetails : this.labels.showDetails;
    }

    get showPermissionSetEditor() {
        return Boolean(
            this.selectedItem &&
                (this.selectedItem.type === TYPE_PERMISSION_SET || this.selectedItem.type === TYPE_PROFILE) &&
                this.selectedItem.editorPermissionSetId
        );
    }

    get showPermissionSetGroupEditor() {
        return Boolean(this.selectedItem && this.selectedItem.type === TYPE_PERMISSION_SET_GROUP && this.selectedItem.id);
    }

    get showEditorPlaceholder() {
        return !this.showPermissionSetEditor && !this.showPermissionSetGroupEditor;
    }

    get showAssignmentManager() {
        return Boolean(this.selectedItem && this.selectedItem.id && this.selectedItem.type);
    }

    get showMigrationAction() {
        return Boolean(
            this.selectedItem &&
                this.selectedItem.type === TYPE_PROFILE &&
                this.selectedItem.id &&
                this.selectedItem.editorPermissionSetId
        );
    }

    get showGlobalActionButtons() {
        return this.showPermissionSetEditor && this.editorState.supportsGlobalActions === true;
    }

    get pendingBadgeText() {
        return `${this.labels.pendingChanges}: ${this.pendingChangeCount}`;
    }

    get pendingBadgeClass() {
        return this.pendingChangeCount > 0
            ? 'c23-shell__pending-badge c23-shell__pending-badge--armed'
            : 'c23-shell__pending-badge';
    }

    get showDensityToggle() {
        return this.hasSelection;
    }

    get densityComfortableClass() {
        return this.tableDensity === DENSITY_COMFORTABLE
            ? 'c23-shell__density-button c23-shell__density-button_active'
            : 'c23-shell__density-button';
    }

    get densityCompactClass() {
        return this.tableDensity === DENSITY_COMPACT
            ? 'c23-shell__density-button c23-shell__density-button_active'
            : 'c23-shell__density-button';
    }

    get pendingChangeCount() {
        return Number(this.editorState.pendingCount || 0);
    }

    get isSaveDisabled() {
        return !this.editorState.canSave;
    }

    get isResetDisabled() {
        return !this.editorState.canReset;
    }

    get saveVariant() {
        return this.pendingChangeCount > 0 ? 'brand' : 'neutral';
    }

    get selectedProfileId() {
        return this.showMigrationAction ? this.selectedItem.id : null;
    }

    get selectedProfileName() {
        return this.showMigrationAction ? this.selectedItem.displayName : null;
    }

    get selectedProfilePermissionSetId() {
        return this.showMigrationAction ? this.selectedItem.editorPermissionSetId : null;
    }

    get selectedPermissionSetId() {
        return this.showPermissionSetEditor ? this.selectedItem.editorPermissionSetId : null;
    }

    get selectedPermissionSetName() {
        return this.showPermissionSetEditor ? this.selectedItem.displayName : null;
    }

    get selectedPermissionSetGroupId() {
        return this.showPermissionSetGroupEditor ? this.selectedItem.id : null;
    }

    get selectedPermissionSetGroupName() {
        return this.showPermissionSetGroupEditor ? this.selectedItem.displayName : null;
    }

    get assignmentTargetId() {
        return this.showAssignmentManager ? this.selectedItem.id : null;
    }

    get assignmentTargetType() {
        return this.showAssignmentManager ? this.selectedItem.type : null;
    }

    get assignmentTargetName() {
        return this.showAssignmentManager ? this.selectedItem.displayName : null;
    }

    handleSelectionChange(event) {
        const detail = event.detail || {};
        this.summaryRows = detail.summaryRows || [];
        this.selectedItem = detail.selectedItem || null;
        this.isMigrationWizardOpen = false;
        this.isAssignmentsDialogOpen = false;
        this.isDetailsExpanded = !this.hasSelection;
        this.editorState = this.defaultEditorState();
    }

    handleToggleExplorer() {
        this.isExplorerCollapsed = !this.isExplorerCollapsed;
    }

    handleToggleDetails() {
        this.isDetailsExpanded = !this.isDetailsExpanded;
    }

    handleDensityChange(event) {
        const nextDensity =
            (event && event.currentTarget && event.currentTarget.dataset && event.currentTarget.dataset.density) ||
            DENSITY_COMFORTABLE;
        const normalizedDensity = this.normalizeDensity(nextDensity);
        if (normalizedDensity === this.tableDensity) {
            return;
        }

        this.tableDensity = normalizedDensity;
        this.persistUserSettings();
    }

    handleEditorStateChange(event) {
        const detail = event.detail || {};
        const pendingCount = Number(detail.pendingCount || 0);
        const supportsGlobalActions = detail.supportsGlobalActions === true;
        this.editorState = {
            pendingCount: Number.isNaN(pendingCount) ? 0 : Math.max(0, pendingCount),
            canSave: supportsGlobalActions && detail.canSave === true,
            canReset: supportsGlobalActions && detail.canReset === true,
            supportsGlobalActions
        };
    }

    handleSave() {
        if (!this.showGlobalActionButtons || this.isSaveDisabled) {
            return;
        }

        const editor = this.template.querySelector('c-c23-permission-set-editor');
        if (editor && typeof editor.applyActiveSection === 'function') {
            editor.applyActiveSection();
        }
    }

    handleReset() {
        if (!this.showGlobalActionButtons || this.isResetDisabled) {
            return;
        }

        const editor = this.template.querySelector('c-c23-permission-set-editor');
        if (editor && typeof editor.resetActiveSection === 'function') {
            editor.resetActiveSection();
        }
    }

    handleOpenAssignments() {
        if (!this.showAssignmentManager) {
            return;
        }
        this.isAssignmentsDialogOpen = true;
    }

    handleCloseAssignments() {
        this.isAssignmentsDialogOpen = false;
    }

    handleOpenMigrationWizard() {
        this.isMigrationWizardOpen = true;
    }

    handleCloseMigrationWizard() {
        this.isMigrationWizardOpen = false;
    }

    async loadUserSettings() {
        try {
            const settings = await getUserSettings();
            this.tableDensity = this.normalizeDensity(settings && settings.tableDensity);
        } catch (error) {
            this.tableDensity = DENSITY_COMFORTABLE;
        }
    }

    async persistUserSettings() {
        try {
            await saveUserSettings({
                settings: {
                    tableDensity: this.tableDensity
                }
            });
        } catch (error) {
            // Ignore preference-save failures and keep UI responsive.
        }
    }

    normalizeDensity(rawDensity) {
        return rawDensity === DENSITY_COMPACT ? DENSITY_COMPACT : DENSITY_COMFORTABLE;
    }

    defaultEditorState() {
        return {
            pendingCount: 0,
            canSave: false,
            canReset: false,
            supportsGlobalActions: false
        };
    }
}