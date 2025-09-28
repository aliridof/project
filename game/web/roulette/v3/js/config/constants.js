// Application constants and configuration
const CONFIG = {
    MAX_HISTORY: 100,
    MAX_UNDO: 5,
    HOT_STREAK_THRESHOLD: 5,
    MEDIUM_STREAK_THRESHOLD: 10,
    STORAGE_KEYS: {
        APP_STATE: 'rouletteAppState',
        HOT_THRESHOLD: 'hotThreshold'
    }
};

// Category mapping for display
const CATEGORY_MAPPING = {
    d0: { group: 'DOZEN', label: 'D0' },
    d1: { group: 'DOZEN', label: 'D1' },
    d2: { group: 'DOZEN', label: 'D2' },
    d3: { group: 'DOZEN', label: 'D3' },
    c0: { group: 'COLUMN', label: 'C0' },
    c1: { group: 'COLUMN', label: 'C1' },
    c2: { group: 'COLUMN', label: 'C2' },
    c3: { group: 'COLUMN', label: 'C3' },
    zeroSize: { group: 'BESAR-KECIL', label: 'ZERO' },
    small: { group: 'BESAR-KECIL', label: 'SMALL' },
    big: { group: 'BESAR-KECIL', label: 'BIG' },
    zeroParity: { group: 'GANJIL-GENAP', label: 'ZERO' },
    even: { group: 'GANJIL-GENAP', label: 'EVEN' },
    odd: { group: 'GANJIL-GENAP', label: 'ODD' },
    zeroColor: { group: 'HITAM-MERAH', label: 'ZERO' },
    red: { group: 'HITAM-MERAH', label: 'RED' },
    black: { group: 'HITAM-MERAH', label: 'BLACK' }
};