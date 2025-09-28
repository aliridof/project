// Input validation
class Validator {
    static validateNumber(input) {
        if (typeof input !== 'string' && typeof input !== 'number') {
            throw new Error('Input harus string atau number');
        }

        const strInput = String(input).trim();
        
        // Handle '00' as special case
        if (strInput === '00') return '00';

        const num = parseInt(strInput, 10);
        
        if (isNaN(num)) {
            throw new Error('Masukkan angka yang valid!');
        }

        if (num < 0 || num > 36) {
            throw new Error('Angka harus antara 0-36 atau 00!');
        }

        return num;
    }

    static sanitizeInput(input) {
        return String(input).replace(/[^0-9]/g, '').substring(0, 2);
    }
}