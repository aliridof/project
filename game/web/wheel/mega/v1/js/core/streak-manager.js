// Streak calculation and management
class StreakManager {
    static getNumberCategories(number) {
        return {
            number: number,
            segments: MEGAWHEEL_DATA.segments[number],
            payout: MEGAWHEEL_DATA.payouts[number],
            maxMultiplier: MEGAWHEEL_DATA.maxMultipliers[number]
        };
    }

    static updateStreaks(streaks, number) {
        const updatedStreaks = { ...streaks };
        
        for (const key in updatedStreaks) {
            if (this.containsNumber(key, number)) {
                updatedStreaks[key] = 0;
            } else {
                updatedStreaks[key]++;
            }
        }
        
        return updatedStreaks;
    }

    static containsNumber(category, number) {
        switch(category) {
            case 'n1': return number === 1;
            case 'n2': return number === 2;
            case 'n5': return number === 5;
            case 'n8': return number === 8;
            case 'n10': return number === 10;
            case 'n15': return number === 15;
            case 'n20': return number === 20;
            case 'n30': return number === 30;
            case 'n40': return number === 40;
            default: return false;
        }
    }
}