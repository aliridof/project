// LocalStorage management
class Storage {
    static saveAppState(stateManager) {
        try {
            const payload = {
                streaks: stateManager.streaks,
                streakHistory: stateManager.streakHistory,
                history: stateManager.history,
                currentNumber: stateManager.currentNumber
            };
            localStorage.setItem(CONFIG.STORAGE_KEYS.APP_STATE, JSON.stringify(payload));
            return true;
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to save app state');
            return false;
        }
    }

    static loadAppState(stateManager) {
        try {
            const raw = localStorage.getItem(CONFIG.STORAGE_KEYS.APP_STATE);
            if (!raw) return false;

            const parsed = JSON.parse(raw);
            if (parsed && typeof parsed === 'object') {
                if (parsed.streaks) stateManager.streaks = { ...stateManager.streaks, ...parsed.streaks };
                if (Array.isArray(parsed.streakHistory)) stateManager.streakHistory = parsed.streakHistory;
                if (Array.isArray(parsed.history)) stateManager.history = parsed.history.slice(0, CONFIG.MAX_HISTORY);
                if (typeof parsed.currentNumber !== 'undefined') stateManager.currentNumber = parsed.currentNumber;
                return true;
            }
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to load app state');
        }
        return false;
    }

    static getHotThreshold() {
        try {
            const raw = localStorage.getItem(CONFIG.STORAGE_KEYS.HOT_THRESHOLD);
            const parsed = parseInt(raw, 10);
            if (!isNaN(parsed) && parsed > 0) return parsed;
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to load hot threshold');
        }
        return CONFIG.HOT_STREAK_THRESHOLD;
    }

    static setHotThreshold(value) {
        try {
            const n = parseInt(value, 10);
            if (!isNaN(n) && n > 0) {
                localStorage.setItem(CONFIG.STORAGE_KEYS.HOT_THRESHOLD, n.toString());
                return true;
            }
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to save hot threshold');
        }
        return false;
    }
}