import { LightningElement, api, track } from 'lwc';
import getSmartCta from '@salesforce/apex/c23_ExperienceContentService.getSmartCta';
import logCtaClick from '@salesforce/apex/c23_ExperienceContentService.logCtaClick';

export default class C23SmartCtaBanner extends LightningElement {
    @api routeKey = 'default';
    @track content;
    @track errorMessage;

    connectedCallback() {
        this.loadContent();
    }

    get isVisible() {
        return Boolean(this.content);
    }

    get title() {
        return this.content?.title || 'Take Action';
    }

    get message() {
        return this.content?.message || '';
    }

    get primaryLabel() {
        return this.content?.primaryLabel || 'Learn More';
    }

    get hasSecondaryCta() {
        return Boolean(this.content?.secondaryLabel && this.content?.secondaryUrl);
    }

    get secondaryLabel() {
        return this.content?.secondaryLabel || '';
    }

    async loadContent() {
        this.errorMessage = null;
        try {
            this.content = await getSmartCta({ routeKey: this.routeKey });
        } catch (error) {
            this.content = null;
            this.errorMessage = error?.body?.message || 'Unable to load CTA.';
        }
    }

    async handlePrimaryClick() {
        if (!this.content?.primaryUrl) {
            return;
        }
        await this.logClick(this.content.primaryUrl);
        window.location.assign(this.content.primaryUrl);
    }

    async handleSecondaryClick() {
        if (!this.content?.secondaryUrl) {
            return;
        }
        await this.logClick(this.content.secondaryUrl);
        window.location.assign(this.content.secondaryUrl);
    }

    async logClick(targetUrl) {
        try {
            await logCtaClick({ contentKey: this.content?.key, targetUrl });
        } catch (e) {
            // intentionally lightweight
        }
    }
}
