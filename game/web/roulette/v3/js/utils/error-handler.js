// Error handling utilities
class ErrorHandler {
    static init() {
        window.addEventListener('error', this.handleGlobalError.bind(this));
        window.addEventListener('unhandledrejection', this.handlePromiseRejection.bind(this));
    }

    static handleGlobalError(event) {
        console.error('Global error:', event.error);
        this.showNotification('Terjadi kesalahan sistem', 'error');
    }

    static handlePromiseRejection(event) {
        console.error('Unhandled promise rejection:', event.reason);
        event.preventDefault();
    }

    static showNotification(message, type = 'info') {
        // Implementation moved to notification.js
        if (typeof Notification !== 'undefined') {
            Notification.show(message, type);
        } else {
            console.log(`${type.toUpperCase()}: ${message}`);
        }
    }
}

// Initialize error handling
ErrorHandler.init();