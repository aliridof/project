// Application state management
class StateManager {
    constructor() {
        this.streaks = this.initializeStreaks();
        this.streakHistory = [];
        this.history = [];
        this.currentNumber = null;
        this.undoStack = [];
    }

    initializeStreaks() {
        return {
            d0: 0, d1: 0, d2: 0, d3: 0,
            c0: 0, c1: 0, c2: 0, c3: 0,
            zeroSize: 0, small: 0, big: 0,
            zeroParity: 0, even: 0, odd: 0,
            zeroColor: 0, red: 0, black: 0
        };
    }

    saveStateForUndo() {
        try {
            if (this.undoStack.length >= CONFIG.MAX_UNDO) {
                this.undoStack.shift();
            }
            
            this.undoStack.push({
                streaks: { ...this.streaks },
                streakHistory: [...this.streakHistory],
                currentNumber: this.currentNumber,
                history: [...this.history]
            });
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to save state for undo');
        }
    }

    undo() {
        try {
            if (this.undoStack.length === 0) return false;
            
            const previousState = this.undoStack.pop();
            this.streaks = { ...previousState.streaks };
            this.streakHistory = [...previousState.streakHistory];
            this.currentNumber = previousState.currentNumber;
            this.history = [...previousState.history];
            
            return true;
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to undo');
            return false;
        }
    }

    reset() {
        this.streaks = this.initializeStreaks();
        this.streakHistory = [];
        this.history = [];
        this.currentNumber = null;
        this.undoStack = [];
    }

    addToHistory(number, categories) {
        try {
            this.history.unshift({
                number: number,
                categories: categories,
                timestamp: new Date().toISOString()
            });

            if (this.history.length > CONFIG.MAX_HISTORY) {
                this.history.pop();
            }
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to add to history');
        }
    }

    updateStreakHistory(number) {
        try {
            const categories = StreakManager.getNumberCategories(number);
            const timestamp = new Date().toISOString();
            
            // Update streak history for all categories
            for (const [categoryKey, streakValue] of Object.entries(this.streaks)) {
                const categoryInfo = CATEGORY_MAPPING[categoryKey];
                if (categoryInfo) {
                    this.streakHistory.unshift({
                        category: categoryKey,
                        group: categoryInfo.group,
                        label: categoryInfo.label,
                        streak: streakValue,
                        timestamp: timestamp
                    });
                }
            }
            
            // Keep only recent history
            if (this.streakHistory.length > CONFIG.MAX_HISTORY * 2) {
                this.streakHistory = this.streakHistory.slice(0, CONFIG.MAX_HISTORY * 2);
            }
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to update streak history');
        }
    }

    getUndoCount() {
        return this.undoStack.length;
    }

    canUndo() {
        return this.undoStack.length > 0;
    }
}