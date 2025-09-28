// Streak calculation and management
class StreakManager {
    static getNumberCategories(number) {
        return {
            dozen: this.getDozen(number),
            column: this.getColumn(number),
            size: this.getSize(number),
            parity: this.getParity(number),
            color: this.getColor(number)
        };
    }

    static getDozen(number) {
        if (number === '00' || number === 0) return 'D0';
        if (number >= 1 && number <= 12) return 'D1';
        if (number >= 13 && number <= 24) return 'D2';
        if (number >= 25 && number <= 36) return 'D3';
        return '-';
    }

    static getColumn(number) {
        if (number === 0 || number === '00') return 'C0';
        if (ROULETTE_DATA.columns.c1.includes(number)) return 'C1';
        if (ROULETTE_DATA.columns.c2.includes(number)) return 'C2';
        if (ROULETTE_DATA.columns.c3.includes(number)) return 'C3';
        return '-';
    }

    static getSize(number) {
        if (number === 0 || number === '00') return 'ZERO';
        if (number >= 1 && number <= 18) return 'SMALL';
        if (number >= 19 && number <= 36) return 'BIG';
        return '-';
    }

    static getParity(number) {
        if (number === 0 || number === '00') return 'ZERO';
        if (number % 2 === 0) return 'EVEN';
        return 'ODD';
    }

    static getColor(number) {
        if (number === 0 || number === '00') return 'ZERO';
        if (ROULETTE_DATA.redNumbers.includes(number)) return 'RED';
        return 'BLACK';
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
            case 'd0': return number === '00' || number === 0;
            case 'd1': return ROULETTE_DATA.dozens.d1.includes(number);
            case 'd2': return ROULETTE_DATA.dozens.d2.includes(number);
            case 'd3': return ROULETTE_DATA.dozens.d3.includes(number);
            case 'c0': return number === '00' || number === 0;
            case 'c1': return ROULETTE_DATA.columns.c1.includes(number);
            case 'c2': return ROULETTE_DATA.columns.c2.includes(number);
            case 'c3': return ROULETTE_DATA.columns.c3.includes(number);
            case 'zeroSize': return number === '00' || number === 0;
            case 'small': return number > 0 && number <= 18;
            case 'big': return number >= 19 && number <= 36;
            case 'zeroParity': return number === '00' || number === 0;
            case 'even': return number !== '00' && number !== 0 && number % 2 === 0;
            case 'odd': return number !== '00' && number !== 0 && number % 2 === 1;
            case 'zeroColor': return number === '00' || number === 0;
            case 'red': return ROULETTE_DATA.redNumbers.includes(number);
            case 'black': return ROULETTE_DATA.blackNumbers.includes(number);
            default: return false;
        }
    }
}