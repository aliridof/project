// Application initialization
document.addEventListener('DOMContentLoaded', function() {
    try {
        // Initialize the main application
        window.rouletteApp = new RouletteTracker();
        
        console.log('Roulette Tracker initialized successfully');
        
        // Auto-save every 30 seconds
        setInterval(() => {
            if (window.rouletteApp && window.rouletteApp.stateManager) {
                Storage.saveAppState(window.rouletteApp.stateManager);
            }
        }, 30000);
        
    } catch (error) {
        console.error('Failed to initialize Roulette Tracker:', error);
        Notification.showError('Gagal memuat aplikasi. Silakan refresh halaman.');
    }
});