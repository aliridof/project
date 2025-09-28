// Main application class
class RouletteTracker {
    constructor() {
        this.stateManager = new StateManager();
        this.domManager = new DOMManager();
        this.hotCategoriesManager = new HotCategoriesManager(this.domManager);
        this.historyManager = new HistoryManager(this.domManager);
        
        this.isProcessing = false;
        this.streakHistory = []; // NEW: untuk menyimpan riwayat streak
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
                    const value = e.target.value;
                    if (Storage.setHotThreshold(value)) {
                        this.hotCategoriesManager.update(this.stateManager.streaks);
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
            
            // NEW: Simpan streaks sebelumnya untuk deteksi threshold
            const previousStreaks = { ...this.stateManager.streaks };
            
            this.stateManager.saveStateForUndo();
            this.processNumber(number, previousStreaks); // MODIFIED: pass previousStreaks
            this.domManager.clearNumberInput();
            
        } catch (error) {
            Notification.showError(error.message);
        } finally {
            this.isProcessing = false;
        }
    }

    processNumber(number, previousStreaks) { // MODIFIED: parameter previousStreaks
        const categories = StreakManager.getNumberCategories(number);
        
        this.stateManager.currentNumber = number;
        this.stateManager.addToHistory(number, categories);
        this.stateManager.streaks = StreakManager.updateStreaks(this.stateManager.streaks, number);
        
        // NEW: Deteksi streak yang mencapai threshold
        this.detectStreakThreshold(previousStreaks, this.stateManager.streaks);
        
        this.updateDisplay();
        Storage.saveAppState(this.stateManager);
    }

    // NEW: Method untuk mendeteksi streak yang mencapai threshold
    detectStreakThreshold(previousStreaks, currentStreaks) {
        const threshold = this.domManager.getHotThresholdValue();
        
        Object.keys(currentStreaks).forEach(category => {
            const currentValue = currentStreaks[category];
            const previousValue = previousStreaks[category];
            
            // Jika streak mencapai threshold tepat (dari threshold-1 ke threshold)
            if (currentValue === threshold && previousValue === threshold - 1) {
                this.addToStreakHistory(category, currentValue, threshold);
                Notification.showSuccess(`🎯 ${this.getCategoryLabel(category)} mencapai streak ${threshold}!`);
            }
        });
    }

    // NEW: Method untuk menambah streak history
    addToStreakHistory(category, streakValue, threshold) {
        const record = {
            category: category,
            label: this.getCategoryLabel(category),
            streakValue: streakValue,
            threshold: threshold,
            timestamp: new Date().toISOString(),
            number: this.stateManager.currentNumber
        };
        
        this.streakHistory.unshift(record);
        
        // Batasi maksimal 20 record
        if (this.streakHistory.length > 20) {
            this.streakHistory.pop();
        }
        
        this.updateStreakHistoryDisplay();
    }

    // NEW: Method untuk mendapatkan label kategori
    getCategoryLabel(category) {
        const mapping = {
            'd0': 'D0', 'd1': 'D1', 'd2': 'D2', 'd3': 'D3',
            'c0': 'C0', 'c1': 'C1', 'c2': 'C2', 'c3': 'C3',
            'zeroSize': 'ZERO', 'small': 'SMALL', 'big': 'BIG',
            'zeroParity': 'ZERO', 'even': 'EVEN', 'odd': 'ODD',
            'zeroColor': 'ZERO', 'red': 'RED', 'black': 'BLACK'
        };
        return mapping[category] || category;
    }

    // NEW: Method untuk update tampilan streak history
    updateStreakHistoryDisplay() {
        const container = document.getElementById('streakHistoryContent');
        const noHistory = document.getElementById('noStreakHistory');
        
        if (!container) return;

        container.innerHTML = '';

        if (this.streakHistory.length === 0) {
            noHistory.textContent = 'Belum ada Streak History';
            container.appendChild(noHistory);
        } else {
            this.streakHistory.forEach(record => {
                const item = this.createStreakHistoryItem(record);
                container.appendChild(item);
            });
        }
    }

    // NEW: Method untuk membuat item streak history
    createStreakHistoryItem(record) {
        const itemDiv = document.createElement('div');
        itemDiv.className = 'streak-history-item';
        
        const categoryInfo = document.createElement('div');
        categoryInfo.className = 'streak-history-category';
        
        // Tambahkan bullet color
        if (record.label === 'RED') {
            categoryInfo.innerHTML = '<span class="bullet bullet-red"></span> RED';
        } else if (record.label === 'BLACK') {
            categoryInfo.innerHTML = '<span class="bullet bullet-black"></span> BLACK';
        } else if (record.label === 'ZERO' || record.label === 'D0' || record.label === 'C0') {
            categoryInfo.innerHTML = '<span class="bullet bullet-green"></span> ' + record.label;
        } else {
            categoryInfo.textContent = record.label;
        }
        
        const detailsDiv = document.createElement('div');
        detailsDiv.className = 'streak-history-details';
        
        const valueSpan = document.createElement('span');
        valueSpan.className = 'streak-history-value';
        valueSpan.textContent = `Streak: ${record.streakValue}`;
        
        const numberSpan = document.createElement('span');
        numberSpan.className = 'streak-history-number';
        numberSpan.textContent = `Number: ${Helpers.formatNumberDisplay(record.number)}`;
        
        const timeSpan = document.createElement('span');
        timeSpan.className = 'streak-history-time';
        timeSpan.textContent = Helpers.formatTimestamp(record.timestamp);
        
        detailsDiv.appendChild(valueSpan);
        detailsDiv.appendChild(numberSpan);
        detailsDiv.appendChild(timeSpan);
        
        itemDiv.appendChild(categoryInfo);
        itemDiv.appendChild(detailsDiv);
        
        return itemDiv;
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
        // NEW: Reset streak history juga
        this.streakHistory = [];
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

        // Update history
        this.historyManager.update(this.stateManager.history);

        // NEW: Update streak history
        this.updateStreakHistoryDisplay();

        // Update undo button
        this.domManager.updateUndoButton(
            this.stateManager.getUndoCount(),
            this.stateManager.canUndo()
        );
    }

    updateAllStreakValues() {
        const streaks = this.stateManager.streaks;
        
        this.domManager.updateStreakValue('d0-value', streaks.d0);
        this.domManager.updateStreakValue('d1-value', streaks.d1);
        this.domManager.updateStreakValue('d2-value', streaks.d2);
        this.domManager.updateStreakValue('d3-value', streaks.d3);
        this.domManager.updateStreakValue('c0-value', streaks.c0);
        this.domManager.updateStreakValue('c1-value', streaks.c1);
        this.domManager.updateStreakValue('c2-value', streaks.c2);
        this.domManager.updateStreakValue('c3-value', streaks.c3);
        this.domManager.updateStreakValue('zero-size-value', streaks.zeroSize);
        this.domManager.updateStreakValue('small-value', streaks.small);
        this.domManager.updateStreakValue('big-value', streaks.big);
        this.domManager.updateStreakValue('zero-parity-value', streaks.zeroParity);
        this.domManager.updateStreakValue('even-value', streaks.even);
        this.domManager.updateStreakValue('odd-value', streaks.odd);
        this.domManager.updateStreakValue('zero-color-value', streaks.zeroColor);
        this.domManager.updateStreakValue('red-value', streaks.red);
        this.domManager.updateStreakValue('black-value', streaks.black);
    }

    loadAppState() {
        if (Storage.loadAppState(this.stateManager)) {
            Notification.showSuccess('Data sebelumnya berhasil dimuat');
        }
    }
}