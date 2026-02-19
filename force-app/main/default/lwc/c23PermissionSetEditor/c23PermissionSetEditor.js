import { api, LightningElement } from 'lwc';
import c23_PS_Audit_Title from '@salesforce/label/c.c23_PS_Audit_Title';
import c23_PS_Field_Title from '@salesforce/label/c.c23_PS_Field_Title';
import c23_PS_ObjectMatrix_Title from '@salesforce/label/c.c23_PS_ObjectMatrix_Title';
import c23_PS_Setup_Title from '@salesforce/label/c.c23_PS_Setup_Title';
import c23_PS_System_Title from '@salesforce/label/c.c23_PS_System_Title';
import c23_PS_Tab_Title from '@salesforce/label/c.c23_PS_Tab_Title';

const SECTION_OBJECT = 'OBJECT';
const SECTION_FIELD = 'FIELD';
const SECTION_SYSTEM = 'SYSTEM';
const SECTION_TAB = 'TAB';
const SECTION_SETUP = 'SETUP';
const SECTION_AUDIT = 'AUDIT';

export default class C23PermissionSetEditor extends LightningElement {
    @api permissionSetId;
    @api permissionSetName;
    @api density = 'comfortable';

    selectedSection = SECTION_OBJECT;
    objectEditorState = this.defaultObjectEditorState();

    labels = {
        audit: c23_PS_Audit_Title,
        field: c23_PS_Field_Title,
        object: c23_PS_ObjectMatrix_Title,
        setup: c23_PS_Setup_Title,
        system: c23_PS_System_Title,
        tab: c23_PS_Tab_Title
    };

    connectedCallback() {
        this.emitEditorStateChange();
    }

    get tabItems() {
        return [
            this.tabItem(SECTION_OBJECT, this.labels.object),
            this.tabItem(SECTION_FIELD, this.labels.field),
            this.tabItem(SECTION_SYSTEM, this.labels.system),
            this.tabItem(SECTION_TAB, this.labels.tab),
            this.tabItem(SECTION_SETUP, this.labels.setup),
            this.tabItem(SECTION_AUDIT, this.labels.audit)
        ];
    }

    get showObjectEditor() {
        return this.selectedSection === SECTION_OBJECT;
    }

    get showFieldEditor() {
        return this.selectedSection === SECTION_FIELD;
    }

    get showSystemEditor() {
        return this.selectedSection === SECTION_SYSTEM;
    }

    get showTabEditor() {
        return this.selectedSection === SECTION_TAB;
    }

    get showSetupEditor() {
        return this.selectedSection === SECTION_SETUP;
    }

    get showAuditEditor() {
        return this.selectedSection === SECTION_AUDIT;
    }

    @api
    async applyActiveSection() {
        const editor = this.activeEditorElement();
        if (editor && typeof editor.applyChanges === 'function') {
            await editor.applyChanges();
        }
    }

    @api
    async resetActiveSection() {
        const editor = this.activeEditorElement();
        if (editor && typeof editor.resetChanges === 'function') {
            await editor.resetChanges();
        }
    }

    handleTabClick(event) {
        const nextSection =
            (event && event.currentTarget && event.currentTarget.dataset && event.currentTarget.dataset.section) || '';
        if (!nextSection || nextSection === this.selectedSection) {
            return;
        }
        this.selectedSection = nextSection;
        this.emitEditorStateChange();
    }

    handleObjectEditorStateChange(event) {
        const detail = event.detail || {};
        const pendingCount = Number(detail.pendingCount || 0);
        this.objectEditorState = {
            pendingCount: Number.isNaN(pendingCount) ? 0 : Math.max(0, pendingCount),
            canSave: detail.canSave === true,
            canReset: detail.canReset === true,
            supportsGlobalActions: true
        };
        this.emitEditorStateChange();
    }

    tabItem(value, label) {
        const isSelected = this.selectedSection === value;
        return {
            value,
            label,
            isSelected,
            className: isSelected ? 'c23-editor__tab c23-editor__tab_active' : 'c23-editor__tab'
        };
    }

    emitEditorStateChange() {
        const detail = this.currentEditorState();
        this.dispatchEvent(
            new CustomEvent('editorstatechange', {
                detail
            })
        );
    }

    currentEditorState() {
        if (this.selectedSection === SECTION_OBJECT) {
            return {
                pendingCount: this.objectEditorState.pendingCount,
                canSave: this.objectEditorState.canSave,
                canReset: this.objectEditorState.canReset,
                supportsGlobalActions: true,
                section: SECTION_OBJECT
            };
        }

        return {
            pendingCount: 0,
            canSave: false,
            canReset: false,
            supportsGlobalActions: false,
            section: this.selectedSection
        };
    }

    activeEditorElement() {
        if (this.selectedSection === SECTION_OBJECT) {
            return this.template.querySelector('c-c23-object-matrix-editor');
        }
        if (this.selectedSection === SECTION_FIELD) {
            return this.template.querySelector('c-c23-field-matrix-editor');
        }
        if (this.selectedSection === SECTION_SYSTEM) {
            return this.template.querySelector('c-c23-system-perm-editor');
        }
        if (this.selectedSection === SECTION_TAB) {
            return this.template.querySelector('c-c23-tab-visibility-editor');
        }
        if (this.selectedSection === SECTION_SETUP) {
            return this.template.querySelector('c-c23-setup-access-editor');
        }
        return null;
    }

    defaultObjectEditorState() {
        return {
            pendingCount: 0,
            canSave: false,
            canReset: false,
            supportsGlobalActions: true
        };
    }
}