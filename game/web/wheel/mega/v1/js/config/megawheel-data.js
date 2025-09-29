// Mega Wheel number data configuration
const MEGAWHEEL_DATA = {
    validNumbers: [1, 2, 5, 8, 10, 15, 20, 30, 40],
    
    // Number of segments for each number
    segments: {
        1: 20,
        2: 13,
        5: 7,
        8: 4,
        10: 4,
        15: 2,
        20: 2,
        30: 1,
        40: 1
    },
    
    // Payout odds for each number
    payouts: {
        1: '1:1',
        2: '2:1',
        5: '5:1',
        8: '8:1',
        10: '10:1',
        15: '15:1',
        20: '20:1',
        30: '30:1',
        40: '40:1'
    },
    
    // Maximum multipliers for each number
    maxMultipliers: {
        1: 'x100',
        2: 'x200',
        5: 'x250',
        8: 'x250',
        10: 'x250',
        15: 'x500',
        20: 'x500',
        30: 'x500',
        40: 'x500'
    }
};