// Streak history display management
class StreakHistoryManager {
    constructor(domManager) {
        this.domManager = domManager;
    }

    update(streakHistory, threshold) {
        try {
            const filteredHistory = this.filterStreakHistory(streakHistory, threshold);
            this.renderStreakHistory(filteredHistory);
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to update streak history');
        }
    }

    filterStreakHistory(streakHistory, threshold) {
        try {
            const thresholdValue = parseInt(threshold, 10);
            if (isNaN(thresholdValue) return [];
            
            return streakHistory.filter(entry => entry.streak >= thresholdValue);
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to filter streak history');
            return [];
        }
    }

    renderStreakHistory(filteredHistory) {
        const streakHistoryContent = this.domManager.elements.streakHistoryContent;
        const noStreakHistory = this.domManager.elements.noStreakHistory;
        
        if (!streakHistoryContent) return;

        try {
            // Clear existing content
            while (streakHistoryContent.firstChild) {
                streakHistoryContent.removeChild(streakHistoryContent.firstChild);
            }

            if (filteredHistory.length === 0) {
                noStreakHistory.textContent = 'Belum ada Streak History';
                streakHistoryContent.appendChild(noStreakHistory);
            } else {
                // Group by timestamp
                const groupedHistory = this.groupByTimestamp(filteredHistory);
                
                Object.entries(groupedHistory).forEach(([timestamp, entries]) => {
                    const historyGroup = this.createHistoryGroup(timestamp, entries);
                    streakHistoryContent.appendChild(historyGroup);
                });
            }
        } catch (error) {
            ErrorHandler.handleError(error, 'Failed to render streak history');
        }
    }

    groupByTimestamp(history) {
        const grouped = {};
        
        history.forEach(entry => {
            if (!grouped[entry.timestamp]) {
                grouped[entry.timestamp] = [];
            }
            grouped[entry.timestamp].push(entry);
        });
        
        return grouped;
    }

    createHistoryGroup(timestamp, entries) {
        const groupDiv = document.createElement('div');
        groupDiv.className = 'streak-history-group';
        
        const headerDiv = document.createElement('div');
        headerDiv.className = 'streak-history-header';
        
        const timeDiv = document.createElement('div');
        timeDiv.className = 'streak-history-time';
        timeDiv.textContent = Helpers.formatTimestamp(timestamp);
        
        const countDiv = document.createElement('div');
        countDiv.className = 'streak-history-count';
        countDiv.textContent = `${entries.length} categories`;
        
        headerDiv.appendChild(timeDiv);
        headerDiv.appendChild(countDiv);
        
        const itemsDiv = document.createElement('div');
        itemsDiv.className = 'streak-history-items';
        
        entries.forEach(entry => {
            const itemDiv = this.createHistoryItem(entry);
            itemsDiv.appendChild(itemDiv);
        });
        
        groupDiv.appendChild(headerDiv);
        groupDiv.appendChild(itemsDiv);
        
        return groupDiv;
    }

    createHistoryItem(entry) {
        const itemDiv = document.createElement('div');
        itemDiv.className = 'streak-history-item';
        
        const labelSpan = document.createElement('span');
        labelSpan.className = 'streak-history-item-label';
        
        // Add bullet for categories
        if (entry.label === 'RED') {
            const bullet = document.createElement('span');
            bullet.className = 'bullet bullet-red';
            labelSpan.appendChild(bullet);
        } else if (entry.label === 'BLACK') {
            const bullet = document.createElement('span');
            bullet.className = 'bullet bullet-black';
            labelSpan.appendChild(bullet);
        } else if (entry.label === 'ZERO' || entry.label === 'D0' || entry.label === 'C0') {
            const bullet = document.createElement('span');
            bullet.className = 'bullet bullet-green';
            labelSpan.appendChild(bullet);
        }
        
        labelSpan.appendChild(document.createTextNode(entry.label));
        
        const valueSpan = document.createElement('span');
        valueSpan.className = 'streak-history-item-value';
        valueSpan.textContent = entry.streak.toString().padStart(2, '0');
        
        itemDiv.appendChild(labelSpan);
        itemDiv.appendChild(valueSpan);
        
        return itemDiv;
    }
}