// Input validation
class Validator {
    static validateNumber(input) {
        if (typeof input !== 'string' && typeof input !== 'number') {
            throw new Error('Input harus string atau number');
        }

        const strInput = String(input).trim();
        
        const num = parseInt(strInput, 10);
        
        if (isNaN(num)) {
            throw new Error('Masukkan angka yang valid!');
        }

        if (!MEGAWHEEL_DATA.validNumbers.includes(num)) {
            throw new Error('Angka harus salah satu dari: 1,2,5,8,10,15,20,30,40!');
        }

        return num;
    }

    static sanitizeInput(input) {
        return String(input).replace(/[^0-9]/g, '').substring(0, 2);
    }
}