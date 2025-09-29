// Main application class
class MegaWheelTracker {
    constructor() {
        this.stateManager = new StateManager();
        this.domManager = new DOMManager();
        this.hotCategoriesManager = new HotCategoriesManager(this.domManager);
        this.streakHistoryManager = new StreakHistoryManager(this.domManager);
        this.historyManager = new HistoryManager(this.domManager);
        
        this.isProcessing = false;
        this.init();
    }

    init() {
        this.loadAppState();
        this.setupEventListeners();
        this.updateDisplay();
        
        // Set initial hot threshold value
        const initialThreshold = Storage.getHotThreshold();
        this.domManager.setHotThresholdValue(initialThreshold);
        this.hotCategoriesManager.update(this.stateManager.streaks);
        this.streakHistoryManager.update(this.stateManager.streakHistory, initialThreshold);
    }

    setupEventListeners() {
        // Number input events
        if (this.domManager.elements.addNumberBtn) {
            this.domManager.elements.addNumberBtn.addEventListener('click', () => this.addNumber());
        }

        if (this.domManager.elements.numberInput) {
            this.domManager.elements.numberInput.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    this.addNumber();
                }
            });

            // Sanitize input in real-time
            this.domManager.elements.numberInput.addEventListener('input', (e) => {
                e.target.value = Validator.sanitizeInput(e.target.value);
            });
        }

        // Control buttons
        if (this.domManager.elements.resetBtn) {
            this.domManager.elements.resetBtn.addEventListener('click', () => this.resetAll());
        }

        if (this.domManager.elements.undoBtn) {
            this.domManager.elements.undoBtn.addEventListener('click', () => this.undo());
        }

        // Hot threshold control
        if (this.domManager.elements.hotThreshold) {
            this.domManager.elements.hotThreshold.addEventListener('input', 
                Helpers.debounce((e) => {
                    try {
                        const value = e.target.value;
                        if (Storage.setHotThreshold(value)) {
                            this.hotCategoriesManager.update(this.stateManager.streaks);
                            this.streakHistoryManager.update(this.stateManager.streakHistory, value);
                        }
                    } catch (error) {
                        ErrorHandler.handleError(error, 'Failed to update threshold');
                    }
                }, 300)
            );
        }

        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            if ((e.ctrlKey || e.metaKey) && e.key === 'z') {
                e.preventDefault();
                this.undo();
            }
            
            // Ctrl+R for reset
            if ((e.ctrlKey || e.metaKey) && e.key === 'r') {
                e.preventDefault();
                this.resetAll();
            }
        });
    }

    addNumber() {
        if (this.isProcessing) return;
        
        this.isProcessing = true;

        try {
            const inputValue = this.domManager.getNumberInputValue();
            const number = Validator.validateNumber(inputValue);
            
            this.stateManager.saveStateForUndo();
            this.processNumber(number);
            this.domManager.clearNumberInput();
            
        } catch (error) {
            Notification.showError(error.message);
        } finally {
            this.isProcessing = false;
        }
    }

    processNumber(number) {
        const categories = StreakManager.getNumberCategories(number);
        
        this.stateManager.currentNumber = number;
        this.stateManager.addToHistory(number, categories);
        this.stateManager.streaks = StreakManager.updateStreaks(this.stateManager.streaks, number);
        this.stateManager.updateStreakHistory(number);
        
        this.updateDisplay();
        Storage.saveAppState(this.stateManager);
    }

    undo() {
        if (this.stateManager.undo()) {
            this.updateDisplay();
            Storage.saveAppState(this.stateManager);
            Notification.showSuccess('Undo berhasil');
        }
    }

    resetAll() {
        if (!confirm('Reset semua streak, history, dan undo stack?')) return;

        this.stateManager.saveStateForUndo();
        this.stateManager.reset();
        this.updateDisplay();
        Storage.saveAppState(this.stateManager);
        Notification.showSuccess('Reset berhasil');
    }

    updateDisplay() {
        // Update current number
        this.domManager.updateCurrentNumber(this.stateManager.currentNumber);

        // Update all streak values
        this.updateAllStreakValues();

        // Update hot categories
        this.hotCategoriesManager.update(this.stateManager.streaks);

        // Update streak history
        const threshold = this.domManager.getHotThresholdValue();
        this.streakHistoryManager.update(this.stateManager.streakHistory, threshold);

        // Update history
        this.historyManager.update(this.stateManager.history);

        // Update undo button
        this.domManager.updateUndoButton(
            this.stateManager.getUndoCount(),
            this.stateManager.canUndo()
        );
    }

    updateAllStreakValues() {
        const streaks = this.stateManager.streaks;
        
        this.domManager.updateStreakValue('n1-value', streaks.n1);
        this.domManager.updateStreakValue('n2-value', streaks.n2);
        this.domManager.updateStreakValue('n5-value', streaks.n5);
        this.domManager.updateStreakValue('n8-value', streaks.n8);
        this.domManager.updateStreakValue('n10-value', streaks.n10);
        this.domManager.updateStreakValue('n15-value', streaks.n15);
        this.domManager.updateStreakValue('n20-value', streaks.n20);
        this.domManager.updateStreakValue('n30-value', streaks.n30);
        this.domManager.updateStreakValue('n40-value', streaks.n40);
    }

    loadAppState() {
        if (Storage.loadAppState(this.stateManager)) {
            Notification.showSuccess('Data sebelumnya berhasil dimuat');
        }
    }
}