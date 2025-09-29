// Application initialization
document.addEventListener('DOMContentLoaded', function() {
    try {
        // Initialize the main application
        window.megawheelApp = new MegaWheelTracker();
        
        console.log('Mega Wheel Tracker initialized successfully');
        
        // Auto-save every 30 seconds
        setInterval(() => {
            if (window.megawheelApp && window.megawheelApp.stateManager) {
                Storage.saveAppState(window.megawheelApp.stateManager);
            }
        }, 30000);
        
    } catch (error) {
        console.error('Failed to initialize Mega Wheel Tracker:', error);
        Notification.showError('Gagal memuat aplikasi. Silakan refresh halaman.');
    }
});