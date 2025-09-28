'use strict';

class EnhancedAIAnalyzer {
    constructor() {
        this.uploadedFiles = new Map();
        this.analysisHistory = [];
        this.currentAnalysis = null;
        this.currentAIPrompt = null;
        this.supportedExtensions = new Set([
            'js', 'html', 'css', 'md', 'txt', 'json', 'py', 'tsx', 
            'ts', 'jsx', 'vue', 'php', 'java', 'cpp', 'c', 'go', 
            'rs', 'rb', 'swift', 'yml', 'yaml', 'xml', 'sh', 'bat'
        ]);
        this.initializeEventListeners();
        this.setupKeyboardShortcuts();
    }

    // kode lain tetap ...

    buildAIPromptText(userRequest, projectContext, analysisResults) {
        const cleanRequest = userRequest.replace(/@\S+/g, '').trim();
        let promptText = `Saya memiliki project dengan struktur dan kode berikut. Tolong ${cleanRequest}\n\n`;
        
        if (analysisResults.issues.length > 0) {
            promptText += `=== ISSUES YANG DITEMUKAN ===\n`;
            analysisResults.issues.forEach(issue => {
                promptText += `- ${issue}\n`;
            });
            promptText += '\n';
        }

        promptText += `=== PERMINTAAN ===\n`;
        promptText += `${cleanRequest}\n\n`;

        promptText += `=== INSTRUKSI UNTUK AI ===\n`;
        promptText += `1. Berikan kode lengkap yang sudah diupdate untuk setiap file yang perlu diubah.\n`;
        promptText += `2. Pastikan kode sudah dioptimalkan, robust, dan mengikuti best practices.\n`;
        promptText += `3. Tambahkan error handling yang proper.\n`;
        promptText += `4. Gunakan sintaks modern (ES6+ untuk JavaScript).\n`;
        promptText += `5. Tambahkan komentar untuk bagian yang kompleks.\n\n`;

        promptText += `=== PROJECT STRUCTURE ===\n`;
        promptText += this.generateStructureTree(this.getProjectStructure()) + '\n\n';
        
        promptText += `=== FILE CONTENTS ===\n`;
        Object.entries(projectContext.fileContents).forEach(([filename, content]) => {
            promptText += `--- ${filename} ---\n`;
            const lines = content.split('\n');
            lines.forEach((line, index) => {
                promptText += `${String(index + 1).padStart(4)}: ${line}\n`;
            });
            promptText += '\n';
        });

        promptText += `Format response:\n`;
        promptText += `=== FILENAME.EXT ===\n`;
        promptText += `[complete updated code here]\n\n`;
        
        return promptText;
    }

    // kode lain tetap ...
}

document.addEventListener('DOMContentLoaded', () => {
    new EnhancedAIAnalyzer();
});