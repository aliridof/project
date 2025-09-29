// Error handling utilities
class ErrorHandler {
    static init() {
        try {
            window.addEventListener('error', this.handleGlobalError.bind(this));
            window.addEventListener('unhandledrejection', this.handlePromiseRejection.bind(this));
        } catch (error) {
            console.error('Failed to initialize error handler:', error);
        }
    }

    static handleGlobalError(event) {
        try {
            const error = event.error;
            this.logError('Global error:', error);
            this.showNotification('Terjadi kesalahan sistem', 'error');
        } catch (fallbackError) {
            console.error('Critical error in error handler:', fallbackError);
        }
    }

    static handlePromiseRejection(event) {
        try {
            const reason = event.reason;
            this.logError('Unhandled promise rejection:', reason);
            event.preventDefault();
        } catch (error) {
            console.error('Error handling promise rejection:', error);
        }
    }

    static handleError(error, context = '') {
        try {
            const message = context ? `${context}: ${error.message}` : error.message;
            this.logError(message, error);
            this.showNotification(message, 'error');
        } catch (fallbackError) {
            console.error('Critical error in error handler:', fallbackError, 'Original error:', error);
        }
    }

    static logError(message, error) {
        if (typeof console !== 'undefined' && console.error) {
            console.error(message, error);
        }
    }

    static showNotification(message, type = 'info') {
        try {
            if (typeof Notification !== 'undefined') {
                Notification.show(message, type);
            }
        } catch (error) {
            console.error('Failed to show notification:', error);
        }
    }
}

// Initialize error handling
ErrorHandler.init();