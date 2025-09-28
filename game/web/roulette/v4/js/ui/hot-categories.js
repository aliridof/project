// Hot categories display management
class HotCategoriesManager {
    constructor(domManager) {
        this.domManager = domManager;
    }

    update(streaks) {
        const threshold = this.domManager.getHotThresholdValue();
        const hotCategories = this.getHotCategories(streaks, threshold);
        this.renderHotCategories(hotCategories);
    }

    getHotCategories(streaks, threshold) {
        const hotCategories = {};
        
        for (const [key, value] of Object.entries(streaks)) {
            if (value > threshold) {
                const mapping = CATEGORY_MAPPING[key];
                if (!hotCategories[mapping.group]) {
                    hotCategories[mapping.group] = [];
                }
                hotCategories[mapping.group].push({
                    label: mapping.label,
                    value: value
                });
            }
        }
        
        return hotCategories;
    }

    renderHotCategories(hotCategories) {
        const hotContent = this.domManager.elements.hotContent;
        const noHotCategories = this.domManager.elements.noHotCategories;
        
        if (!hotContent) return;

        hotContent.innerHTML = '';

        if (Object.keys(hotCategories).length === 0) {
            noHotCategories.textContent = 'Belum ada Streak';
            hotContent.appendChild(noHotCategories);
        } else {
            for (const [groupName, items] of Object.entries(hotCategories)) {
                const groupDiv = this.createCategoryGroup(groupName, items);
                hotContent.appendChild(groupDiv);
            }
        }
    }

    createCategoryGroup(groupName, items) {
        const groupDiv = document.createElement('div');
        groupDiv.className = 'hot-category-group';
        
        const titleDiv = document.createElement('div');
        titleDiv.className = 'hot-category-title';
        titleDiv.textContent = groupName;
        
        const itemsDiv = document.createElement('div');
        itemsDiv.className = 'hot-category-items';
        
        items.forEach(item => {
            const itemDiv = this.createHotItem(item);
            itemsDiv.appendChild(itemDiv);
        });
        
        groupDiv.appendChild(titleDiv);
        groupDiv.appendChild(itemsDiv);
        
        return groupDiv;
    }

    createHotItem(item) {
        const itemDiv = document.createElement('div');
        itemDiv.className = 'hot-item';
        
        const labelSpan = document.createElement('span');
        labelSpan.className = 'hot-item-label';
        
        // Add bullet for categories
        if (item.label === 'RED') {
            const bullet = document.createElement('span');
            bullet.className = 'bullet bullet-red';
            labelSpan.appendChild(bullet);
        } else if (item.label === 'BLACK') {
            const bullet = document.createElement('span');
            bullet.className = 'bullet bullet-black';
            labelSpan.appendChild(bullet);
        } else if (item.label === 'ZERO' || item.label === 'D0' || item.label === 'C0') {
            const bullet = document.createElement('span');
            bullet.className = 'bullet bullet-green';
            labelSpan.appendChild(bullet);
        }
        
        labelSpan.appendChild(document.createTextNode(item.label));
        
        const valueSpan = document.createElement('span');
        valueSpan.className = 'hot-item-value';
        valueSpan.textContent = item.value.toString().padStart(2, '0');
        
        itemDiv.appendChild(labelSpan);
        itemDiv.appendChild(valueSpan);
        
        return itemDiv;
    }
}