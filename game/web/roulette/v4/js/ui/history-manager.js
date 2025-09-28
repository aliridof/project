// History display management
class HistoryManager {
    constructor(domManager) {
        this.domManager = domManager;
    }

    update(history) {
        this.updateGridHistory(history);
        this.updateVerticalHistory(history);
        this.updateCounters(history.length);
    }

    updateGridHistory(history) {
        const container = this.domManager.elements.historyGrid;
        if (!container) return;

        container.innerHTML = '';

        history.forEach((item, index) => {
            const div = document.createElement('div');
            div.className = 'history-number';
            div.textContent = Helpers.formatNumberDisplay(item.number);
            div.title = `#${history.length - index}: ${Helpers.formatNumberDisplay(item.number)} — ${Helpers.formatTimestamp(item.timestamp)}`;

            // Set background color based on number
            if (item.number === 0 || item.number === '00') {
                div.style.background = '#27ae60';
            } else if (ROULETTE_DATA.redNumbers.includes(item.number)) {
                div.style.background = '#e74c3c';
            } else {
                div.style.background = '#2c3e50';
            }

            container.appendChild(div);
        });
    }

    updateVerticalHistory(history) {
        const container = this.domManager.elements.verticalHistory;
        if (!container) return;

        container.innerHTML = '';

        history.forEach((item) => {
            const historyItem = this.createHistoryItem(item);
            container.appendChild(historyItem);
        });
    }

    createHistoryItem(item) {
        const historyItem = document.createElement('div');
        historyItem.className = 'history-item';

        // Number circle
        const numberCircle = document.createElement('div');
        numberCircle.className = 'history-number-large';
        numberCircle.textContent = Helpers.formatNumberDisplay(item.number);
        
        // Set background color
        if (item.number === 0 || item.number === '00') {
            numberCircle.style.background = '#27ae60';
        } else if (ROULETTE_DATA.redNumbers.includes(item.number)) {
            numberCircle.style.background = '#e74c3c';
        } else {
            numberCircle.style.background = '#2c3e50';
        }

        // Details
        const details = document.createElement('div');
        details.className = 'history-details';

        const detailsHTML = `
            <div class="history-detail-item">
                <span class="history-detail-label">DOZEN:</span>
                <span class="history-detail-value">${item.categories.dozen}</span>
            </div>
            <div class="history-detail-item">
                <span class="history-detail-label">COLUMN:</span>
                <span class="history-detail-value">${item.categories.column}</span>
            </div>
            <div class="history-detail-item">
                <span class="history-detail-label">BESAR-KECIL:</span>
                <span class="history-detail-value">${item.categories.size}</span>
            </div>
            <div class="history-detail-item">
                <span class="history-detail-label">GANJIL-GENAP:</span>
                <span class="history-detail-value">${item.categories.parity}</span>
            </div>
            <div class="history-detail-item">
                <span class="history-detail-label">HITAM-MERAH:</span>
                <span class="history-detail-value">
                    ${item.categories.color === 'RED' ? '<span class="bullet bullet-red"></span>' : ''}
                    ${item.categories.color === 'BLACK' ? '<span class="bullet bullet-black"></span>' : ''}
                    ${item.categories.color === 'ZERO' ? '<span class="bullet bullet-green"></span>' : ''}
                    ${item.categories.color}
                </span>
            </div>
            <div class="history-detail-item">
                <span class="history-detail-label">WAKTU:</span>
                <span class="history-detail-value history-timestamp">${Helpers.formatTimestamp(item.timestamp)}</span>
            </div>
        `;

        details.innerHTML = detailsHTML;
        historyItem.appendChild(numberCircle);
        historyItem.appendChild(details);

        return historyItem;
    }

    updateCounters(historyLength) {
        if (this.domManager.elements.gridCounter) {
            this.domManager.elements.gridCounter.textContent = `Total: ${historyLength} numbers`;
        }
        if (this.domManager.elements.verticalCounter) {
            this.domManager.elements.verticalCounter.textContent = `Total: ${historyLength} numbers`;
        }
    }
}