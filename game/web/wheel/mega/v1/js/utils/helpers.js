// Helper functions
class Helpers {
    static formatNumberDisplay(num) {
        if (num === null || typeof num === 'undefined') return '--';
        return num;
    }

    static formatTimestamp(isoString) {
        if (!isoString) return '';
        try {
            const d = new Date(isoString);
            if (isNaN(d.getTime())) return isoString;

            const pad = (n) => n.toString().padStart(2, '0');
            const year = d.getFullYear();
            const month = pad(d.getMonth() + 1);
            const day = pad(d.getDate());
            const hours = pad(d.getHours());
            const minutes = pad(d.getMinutes());
            const seconds = pad(d.getSeconds());
            return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
        } catch (error) {
            return isoString;
        }
    }

    static debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }

    static getStreakClass(value) {
        if (value > CONFIG.MEDIUM_STREAK_THRESHOLD) return 'streak-high';
        if (value > CONFIG.HOT_STREAK_THRESHOLD) return 'streak-medium';
        return 'streak-normal';
    }

    static getNumberColor(number) {
        const segments = MEGAWHEEL_DATA.segments[number];
        if (segments >= 15) return '#27ae60'; // Green for high probability
        if (segments >= 5) return '#3498db';  // Blue for medium probability
        return '#e74c3c'; // Red for low probability
    }

    static getSegmentInfo(number) {
        return {
            segments: MEGAWHEEL_DATA.segments[number],
            payout: MEGAWHEEL_DATA.payouts[number],
            maxMultiplier: MEGAWHEEL_DATA.maxMultipliers[number]
        };
    }
}