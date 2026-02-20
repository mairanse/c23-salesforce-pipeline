import { LightningElement, api, track } from 'lwc';
import getAnnouncement from '@salesforce/apex/c23_ExperienceContentService.getAnnouncement';

export default class C23AnnouncementBar extends LightningElement {
    @api routeKey = 'default';
    @track content;
    @track errorMessage;

    isDismissed = false;

    connectedCallback() {
        this.loadContent();
    }

    get storageKey() {
        return this.content?.key ? `c23:announcement:dismissed:${this.content.key}` : null;
    }

    get isVisible() {
        return Boolean(this.content) && !this.isDismissed;
    }

    get title() {
        return this.content?.title || 'Announcement';
    }

    get message() {
        return this.content?.message || '';
    }

    async loadContent() {
        this.errorMessage = null;
        try {
            const item = await getAnnouncement({ routeKey: this.routeKey });
            this.content = item;
            this.isDismissed = this.readDismissedState();
        } catch (error) {
            this.content = null;
            this.errorMessage = error?.body?.message || 'Unable to load announcement.';
        }
    }

    handleDismiss() {
        this.isDismissed = true;
        if (this.storageKey) {
            localStorage.setItem(this.storageKey, '1');
        }
    }

    readDismissedState() {
        if (!this.storageKey) {
            return false;
        }
        return localStorage.getItem(this.storageKey) === '1';
    }
}
