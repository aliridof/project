// Application state management
class StateManager {
    constructor() {
        this.streaks = this.initializeStreaks();
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
        if (this.undoStack.length >= CONFIG.MAX_UNDO) {
            this.undoStack.shift();
        }
        
        this.undoStack.push({
            streaks: { ...this.streaks },
            currentNumber: this.currentNumber,
            history: [...this.history]
        });
    }

    undo() {
        if (this.undoStack.length === 0) return false;
        
        const previousState = this.undoStack.pop();
        this.streaks = { ...previousState.streaks };
        this.currentNumber = previousState.currentNumber;
        this.history = [...previousState.history];
        
        return true;
    }

    reset() {
        this.streaks = this.initializeStreaks();
        this.history = [];
        this.currentNumber = null;
        this.undoStack = [];
    }

    addToHistory(number, categories) {
        this.history.unshift({
            number: number,
            categories: categories,
            timestamp: new Date().toISOString()
        });

        if (this.history.length > CONFIG.MAX_HISTORY) {
            this.history.pop();
        }
    }

    getUndoCount() {
        return this.undoStack.length;
    }

    canUndo() {
        return this.undoStack.length > 0;
    }
}