import { LightningElement, track } from 'lwc';
import getAssignments from '@salesforce/apex/c23_UserPermissionSummaryService.getAssignments';

export default class C23UserPermissionSummary extends LightningElement {
    @track selectedUser;
    @track assignmentSummary;
    @track assignmentSections = [];
    @track assignmentError;

    isLoadingAssignments = false;
    openSectionNames = ['permissionSets', 'permissionSetGroups', 'mutingPermissionSets'];

    async handleUserSelected(event) {
        const user = event.detail?.user;
        const userId = event.detail?.userId;

        if (!userId) {
            return;
        }

        this.selectedUser = {
            id: userId,
            name: user?.name || '',
            username: user?.username || '',
            email: user?.email || '',
            isActive: user?.isActive,
            profileName: user?.profileName || ''
        };

        this.assignmentError = null;
        this.assignmentSummary = null;
        this.assignmentSections = [];
        this.isLoadingAssignments = true;

        try {
            const summary = await getAssignments({ userId });
            this.assignmentSummary = summary;
            this.selectedUser.profileName = summary?.profileName || this.selectedUser.profileName;
            this.assignmentSections = this.buildSections(summary);
        } catch (error) {
            this.assignmentError = error?.body?.message || 'Unable to load assignment summary.';
        } finally {
            this.isLoadingAssignments = false;
        }
    }

    buildSections(summary) {
        const permissionSets = summary?.permissionSets || [];
        const permissionSetGroups = summary?.permissionSetGroups || [];
        const mutingPermissionSets = summary?.mutingPermissionSets || [];

        return [
            {
                name: 'permissionSets',
                title: `Permission Sets (${summary?.permissionSetCount || 0})`,
                items: permissionSets,
                hasItems: permissionSets.length > 0,
                emptyMessage: 'No Permission Set assignments.'
            },
            {
                name: 'permissionSetGroups',
                title: `Permission Set Groups (${summary?.permissionSetGroupCount || 0})`,
                items: permissionSetGroups,
                hasItems: permissionSetGroups.length > 0,
                emptyMessage: 'No Permission Set Group assignments.'
            },
            {
                name: 'mutingPermissionSets',
                title: `Muting Permission Sets (${summary?.mutingPermissionSetCount || 0})`,
                items: mutingPermissionSets,
                hasItems: mutingPermissionSets.length > 0,
                emptyMessage: 'No Muting Permission Sets derived from group assignments.'
            }
        ];
    }

    get activeLabel() {
        if (!this.selectedUser) {
            return '';
        }

        return this.selectedUser.isActive ? 'Yes' : 'No';
    }

    get hasAssignmentSections() {
        return this.assignmentSections.length > 0;
    }
}
