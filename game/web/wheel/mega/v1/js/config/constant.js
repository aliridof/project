// Application constants and configuration
const CONFIG = {
    MAX_HISTORY: 100,
    MAX_UNDO: 5,
    HOT_STREAK_THRESHOLD: 5,
    MEDIUM_STREAK_THRESHOLD: 10,
    STORAGE_KEYS: {
        APP_STATE: 'megawheelAppState',
        HOT_THRESHOLD: 'hotThreshold'
    }
};

// Category mapping for display
const CATEGORY_MAPPING = {
    n1: { group: 'MEGA WHEEL NUMBERS', label: '1' },
    n2: { group: 'MEGA WHEEL NUMBERS', label: '2' },
    n5: { group: 'MEGA WHEEL NUMBERS', label: '5' },
    n8: { group: 'MEGA WHEEL NUMBERS', label: '8' },
    n10: { group: 'MEGA WHEEL NUMBERS', label: '10' },
    n15: { group: 'MEGA WHEEL NUMBERS', label: '15' },
    n20: { group: 'MEGA WHEEL NUMBERS', label: '20' },
    n30: { group: 'MEGA WHEEL NUMBERS', label: '30' },
    n40: { group: 'MEGA WHEEL NUMBERS', label: '40' }
};