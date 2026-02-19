import { LightningElement, track } from 'lwc';

export default class C23UserPermissionSummary extends LightningElement {
    @track selectedUser;

    handleUserSelected(event) {
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
    }

    get activeLabel() {
        if (!this.selectedUser) {
            return '';
        }

        return this.selectedUser.isActive ? 'Yes' : 'No';
    }
}
