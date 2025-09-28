// DOM manipulation and element management
class DOMManager {
    constructor() {
        this.elements = this.cacheElements();
    }

    cacheElements() {
        return {
            currentNumber: document.getElementById('currentNumber'),
            numberInput: document.getElementById('numberInput'),
            addNumberBtn: document.getElementById('addNumberBtn'),
            resetBtn: document.getElementById('resetBtn'),
            undoBtn: document.getElementById('undoBtn'),
            undoCounter: document.getElementById('undoCounter'),
            hotContent: document.getElementById('hotContent'),
            noHotCategories: document.getElementById('noHotCategories'),
            historyGrid: document.getElementById('historyGrid'),
            verticalHistory: document.getElementById('verticalHistory'),
            gridCounter: document.getElementById('gridCounter'),
            verticalCounter: document.getElementById('verticalCounter'),
            hotThreshold: document.getElementById('hotThreshold')
        };
    }

    updateCurrentNumber(number) {
        if (this.elements.currentNumber) {
            this.elements.currentNumber.textContent = Helpers.formatNumberDisplay(number);
        }
    }

    updateStreakValue(elementId, value) {
        const element = document.getElementById(elementId);
        if (element) {
            const formattedValue = value.toString().padStart(2, '0');
            element.textContent = formattedValue;
            
            // Update streak class
            element.className = 'streak-value ' + Helpers.getStreakClass(value);
        }
    }

    updateUndoButton(undoCount, canUndo) {
        if (this.elements.undoBtn && this.elements.undoCounter) {
            this.elements.undoBtn.disabled = !canUndo;
            this.elements.undoCounter.textContent = `↩️ ${undoCount}/${CONFIG.MAX_UNDO}`;
            
            if (canUndo) {
                this.elements.undoCounter.style.background = '#34495e';
            } else {
                this.elements.undoCounter.style.background = '#bdc3c7';
            }
        }
    }

    clearNumberInput() {
        if (this.elements.numberInput) {
            this.elements.numberInput.value = '';
        }
    }

    getNumberInputValue() {
        return this.elements.numberInput ? this.elements.numberInput.value : '';
    }

    getHotThresholdValue() {
        return this.elements.hotThreshold ? parseInt(this.elements.hotThreshold.value, 10) : CONFIG.HOT_STREAK_THRESHOLD;
    }

    setHotThresholdValue(value) {
        if (this.elements.hotThreshold) {
            this.elements.hotThreshold.value = value;
        }
    }
}