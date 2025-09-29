// DOM manipulation and element management
class DOMManager {
    constructor() {
        this.elements = this.cacheElements();
    }

    cacheElements() {
        try {
            return {
                currentNumber: document.getElementById('currentNumber'),
                numberInput: document.getElementById('numberInput'),
                addNumberBtn: document.getElementById('addNumberBtn'),
                resetBtn: document.getElementById('resetBtn'),
                undoBtn: document.getElementById('undoBtn'),
                undoCounter: document.getElementById('undoCounter'),
                hotContent: document.getElementById('hotContent'),
                noHotCategories: document.getElementById('noHotCategories'),
                streakHistoryContent: document.getElementById('streakHistoryContent'),
                noStreakHistory: document.getElementById('noStreakHistory'),
                historyGrid: document.getElementById('historyGrid'),
                verticalHistory: document.getElementById('verticalHistory'),
                gridCounter: document.getElementById('gridCounter'),
                verticalCounter: document.getElementById('verticalCounter'),
                hotThreshold: document.getElementById('hotThreshold')
            };
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to cache DOM elements');
            return {};
        }
    }

    updateCurrentNumber(number) {
        try {
            if (this.elements.currentNumber) {
                this.elements.currentNumber.textContent = Helpers.formatNumberDisplay(number);
            }
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to update current number');
        }
    }

    updateStreakValue(elementId, value) {
        try {
            const element = document.getElementById(elementId);
            if (element) {
                const formattedValue = value.toString().padStart(2, '0');
                element.textContent = formattedValue;
                
                // Update streak class
                element.className = 'streak-value ' + Helpers.getStreakClass(value);
            }
        } catch (error) {
            ErrorHandler.handleError(error, `Failed to update streak value for ${elementId}`);
        }
    }

    updateUndoButton(undoCount, canUndo) {
        try {
            if (this.elements.undoBtn && this.elements.undoCounter) {
                this.elements.undoBtn.disabled = !canUndo;
                this.elements.undoCounter.textContent = `↩️ ${undoCount}/${CONFIG.MAX_UNDO}`;
                
                if (canUndo) {
                    this.elements.undoCounter.style.background = '#34495e';
                } else {
                    this.elements.undoCounter.style.background = '#bdc3c7';
                }
            }
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to update undo button');
        }
    }

    clearNumberInput() {
        try {
            if (this.elements.numberInput) {
                this.elements.numberInput.value = '';
            }
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to clear number input');
        }
    }

    getNumberInputValue() {
        try {
            return this.elements.numberInput ? this.elements.numberInput.value : '';
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to get number input value');
            return '';
        }
    }

    getHotThresholdValue() {
        try {
            return this.elements.hotThreshold ? parseInt(this.elements.hotThreshold.value, 10) : CONFIG.HOT_STREAK_THRESHOLD;
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to get hot threshold value');
            return CONFIG.HOT_STREAK_THRESHOLD;
        }
    }

    setHotThresholdValue(value) {
        try {
            if (this.elements.hotThreshold) {
                this.elements.hotThreshold.value = value;
            }
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to set hot threshold value');
        }
    }
}