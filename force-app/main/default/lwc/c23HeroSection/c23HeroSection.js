import { LightningElement, api, track } from 'lwc';
import getHeroVariants from '@salesforce/apex/c23_ExperienceContentService.getHeroVariants';

export default class C23HeroSection extends LightningElement {
    @api routeKey = 'default';
    @track hero;
    @track errorMessage;

    connectedCallback() {
        this.loadHero();
    }

    get hasHero() {
        return Boolean(this.hero);
    }

    get title() {
        return this.hero?.title || '';
    }

    get subhead() {
        return this.hero?.subhead || this.hero?.message || '';
    }

    get imageUrl() {
        return this.hero?.imageUrl || '';
    }

    get hasImage() {
        return Boolean(this.imageUrl);
    }

    get hasPrimary() {
        return Boolean(this.hero?.primaryLabel && this.hero?.primaryUrl);
    }

    get hasSecondary() {
        return Boolean(this.hero?.secondaryLabel && this.hero?.secondaryUrl);
    }

    get primaryLabel() {
        return this.hero?.primaryLabel || '';
    }

    get secondaryLabel() {
        return this.hero?.secondaryLabel || '';
    }

    async loadHero() {
        this.errorMessage = null;
        try {
            const variants = await getHeroVariants({ routeKey: this.routeKey });
            this.hero = (variants || [])[0] || null;
        } catch (error) {
            this.hero = null;
            this.errorMessage = error?.body?.message || 'Unable to load hero content.';
        }
    }

    handlePrimary() {
        if (this.hero?.primaryUrl) {
            window.location.assign(this.hero.primaryUrl);
        }
    }

    handleSecondary() {
        if (this.hero?.secondaryUrl) {
            window.location.assign(this.hero.secondaryUrl);
        }
    }
}
