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

    initializeEventListeners() {
        // Cache DOM elements
        this.elements = {
            fileInput: document.getElementById('fileInput'),
            uploadArea: document.getElementById('uploadArea'),
            generateBtn: document.getElementById('generateBtn'),
            downloadBtn: document.getElementById('downloadBtn'),
            copyPromptBtn: document.getElementById('copyPromptBtn'),
            analysisPrompt: document.getElementById('analysisPrompt'),
            filesList: document.getElementById('filesList'),
            fileButtons: document.getElementById('fileButtons'),
            resultsContainer: document.getElementById('resultsContainer'),
            uploadedFiles: document.getElementById('uploadedFiles'),
            aiPromptSection: document.getElementById('aiPromptSection'),
            aiPromptContent: document.getElementById('aiPromptContent')
        };

        // Drag and drop functionality with throttling
        let dragCounter = 0;
        this.elements.uploadArea.addEventListener('click', () => this.elements.fileInput.click());
        
        this.elements.uploadArea.addEventListener('dragenter', (e) => {
            e.preventDefault();
            dragCounter++;
            if (dragCounter === 1) {
                this.elements.uploadArea.classList.add('drag-over');
            }
        });

        this.elements.uploadArea.addEventListener('dragleave', (e) => {
            e.preventDefault();
            dragCounter--;
            if (dragCounter === 0) {
                this.elements.uploadArea.classList.remove('drag-over');
            }
        });

        this.elements.uploadArea.addEventListener('dragover', (e) => {
            e.preventDefault();
        });

        this.elements.uploadArea.addEventListener('drop', (e) => {
            e.preventDefault();
            dragCounter = 0;
            this.elements.uploadArea.classList.remove('drag-over');
            this.handleDrop(e);
        });

        // File input change
        this.elements.fileInput.addEventListener('change', this.handleFileSelect.bind(this));

        // Buttons with debouncing
        this.elements.generateBtn.addEventListener('click', this.debounce(this.generateAIPrompt.bind(this), 300));
        this.elements.downloadBtn.addEventListener('click', this.debounce(this.downloadAIReadyReport.bind(this), 300));
        this.elements.copyPromptBtn.addEventListener('click', this.copyAIPrompt.bind(this));

        // Auto-save prompt to localStorage
        this.elements.analysisPrompt.addEventListener('input', this.debounce(() => {
            localStorage.setItem('lastPrompt', this.elements.analysisPrompt.value);
        }, 500));

        // Restore last prompt
        const lastPrompt = localStorage.getItem('lastPrompt');
        if (lastPrompt) {
            this.elements.analysisPrompt.value = lastPrompt;
        }
    }

    setupKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            // Ctrl/Cmd + Enter to generate AI prompt
            if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
                e.preventDefault();
                this.elements.generateBtn.click();
            }
            // Ctrl/Cmd + S to download
            if ((e.ctrlKey || e.metaKey) && e.key === 's') {
                e.preventDefault();
                if (!this.elements.downloadBtn.disabled) {
                    this.elements.downloadBtn.click();
                }
            }
        });
    }

    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }

    async handleDrop(e) {
        const items = e.dataTransfer.items;
        const files = [];
        
        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            if (item.kind === 'file') {
                const entry = item.webkitGetAsEntry();
                if (entry) {
                    await this.traverseFileTree(entry, files);
                }
            }
        }
        
        this.processFiles(files);
    }

    async traverseFileTree(item, files, path = "") {
        return new Promise((resolve) => {
            if (item.isFile) {
                item.file((file) => {
                    file.fullPath = path + file.name;
                    files.push(file);
                    resolve();
                });
            } else if (item.isDirectory) {
                const dirReader = item.createReader();
                dirReader.readEntries(async (entries) => {
                    for (let entry of entries) {
                        await this.traverseFileTree(entry, files, path + item.name + "/");
                    }
                    resolve();
                });
            }
        });
    }

    handleFileSelect(e) {
        const files = Array.from(e.target.files);
        this.processFiles(files);
    }

    async processFiles(files) {
        const textFiles = files.filter(file => this.isValidFile(file));
        const totalSize = textFiles.reduce((sum, file) => sum + file.size, 0);
        
        // Check total size limit (10MB)
        if (totalSize > 10 * 1024 * 1024) {
            this.showMessage('Total ukuran file melebihi 10MB. Silakan pilih file yang lebih kecil.', 'error');
            return;
        }

        const promises = textFiles.map(async (file) => {
            try {
                const content = await this.readFileContent(file);
                const filePath = file.fullPath || file.webkitRelativePath || file.name;
                
                return {
                    name: file.name,
                    content: content,
                    size: file.size,
                    type: file.type || this.getMimeType(file.name),
                    path: filePath
                };
            } catch (error) {
                console.error(`Error reading file ${file.name}:`, error);
                return null;
            }
        });

        const results = await Promise.all(promises);
        const validResults = results.filter(r => r !== null);

        // Clear existing files and add new ones
        this.uploadedFiles.clear();
        validResults.forEach(fileData => {
            this.uploadedFiles.set(fileData.name, fileData);
        });

        this.updateFileList();
        this.updateFileButtons();
        
        if (validResults.length > 0) {
            this.showMessage(`${validResults.length} file berhasil diupload`, 'success');
        }
    }

    isValidFile(file) {
        const extension = file.name.split('.').pop().toLowerCase();
        return this.supportedExtensions.has(extension) || 
               file.type.startsWith('text/') ||
               file.size < 1024 * 1024; // Allow small files regardless of extension
    }

    getMimeType(filename) {
        const ext = filename.split('.').pop().toLowerCase();
        const mimeTypes = {
            'js': 'text/javascript',
            'html': 'text/html',
            'css': 'text/css',
            'json': 'application/json',
            'md': 'text/markdown',
            'py': 'text/x-python',
            'java': 'text/x-java',
            'cpp': 'text/x-c++',
            'c': 'text/x-c',
            'php': 'text/x-php',
            'rb': 'text/x-ruby',
            'go': 'text/x-go',
            'rs': 'text/x-rust',
            'swift': 'text/x-swift'
        };
        return mimeTypes[ext] || 'text/plain';
    }

    readFileContent(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = (e) => resolve(e.target.result);
            reader.onerror = (e) => reject(e);
            reader.readAsText(file);
        });
    }

    updateFileList() {
        const template = document.getElementById('fileItemTemplate');
        this.elements.filesList.innerHTML = '';

        const fragment = document.createDocumentFragment();
        
        this.uploadedFiles.forEach((file, filename) => {
            const clone = template.content.cloneNode(true);
            const fileItem = clone.querySelector('.file-item');
            
            clone.querySelector('.file-name').textContent = filename;
            clone.querySelector('.file-name').title = file.path || filename;
            clone.querySelector('.file-size').textContent = this.formatFileSize(file.size);
            
            const mentionBtn = clone.querySelector('.mention-btn');
            mentionBtn.addEventListener('click', () => this.mentionFile(filename));
            
            fragment.appendChild(clone);
        });

        this.elements.filesList.appendChild(fragment);
        this.elements.uploadedFiles.style.display = this.uploadedFiles.size > 0 ? 'block' : 'none';
    }

    updateFileButtons() {
        this.elements.fileButtons.innerHTML = '';
        const fragment = document.createDocumentFragment();

        this.uploadedFiles.forEach((file, filename) => {
            const button = document.createElement('button');
            button.className = 'file-mention-btn';
            button.textContent = filename;
            button.title = `Mention ${filename} dalam analisa`;
            button.addEventListener('click', () => this.mentionFile(filename));
            fragment.appendChild(button);
        });

        this.elements.fileButtons.appendChild(fragment);
    }

    mentionFile(filename) {
        const currentText = this.elements.analysisPrompt.value;
        const mentionText = `@${filename}`;
        
        if (!currentText.includes(mentionText)) {
            const newText = currentText ? `${currentText} ${mentionText}` : mentionText;
            this.elements.analysisPrompt.value = newText;
            this.elements.analysisPrompt.focus();
            
            // Trigger input event for auto-save
            const event = new Event('input', { bubbles: true });
            this.elements.analysisPrompt.dispatchEvent(event);
        }
    }

    formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    showMessage(text, type = 'info') {
        const message = document.createElement('div');
        message.className = `message ${type}`;
        message.textContent = text;
        this.elements.resultsContainer.insertBefore(message, this.elements.resultsContainer.firstChild);
        
        setTimeout(() => {
            message.style.opacity = '0';
            setTimeout(() => message.remove(), 300);
        }, 3000);
    }

    // Generate AI-ready prompt
    async generateAIPrompt() {
        const prompt = this.elements.analysisPrompt.value.trim();
        
        if (!prompt) {
            this.showMessage('Silakan masukkan permintaan upgrade/perbaikan terlebih dahulu!', 'error');
            return;
        }

        if (this.uploadedFiles.size === 0) {
            this.showMessage('Silakan upload file project terlebih dahulu!', 'error');
            return;
        }

        this.setButtonLoading(this.elements.generateBtn, true, '🚀 Generating AI Prompt...');

        try {
            const aiPrompt = await this.createAIPrompt(prompt);
            this.currentAIPrompt = aiPrompt;
            this.displayAIPrompt(aiPrompt);
            
            // Enable download button
            this.elements.downloadBtn.disabled = false;
            
            // Show AI prompt section with animation
            this.elements.aiPromptSection.style.display = 'block';
            
            this.showMessage('AI Prompt berhasil dibuat!', 'success');
        } catch (error) {
            console.error('AI Prompt generation error:', error);
            this.showMessage('Terjadi kesalahan saat membuat AI prompt: ' + error.message, 'error');
        } finally {
            this.setButtonLoading(this.elements.generateBtn, false, '🚀 GENERATE');
        }
    }

    setButtonLoading(button, loading, text) {
        button.disabled = loading;
        if (loading) {
            button.innerHTML = `<span class="loading-spinner"></span> ${text}`;
        } else {
            button.textContent = text;
        }
    }

    async createAIPrompt(userRequest) {
        // Simulate processing with actual work
        await this.delay(800);

        const mentionedFiles = this.extractMentionedFiles(userRequest);
        const projectContext = this.buildProjectContext(mentionedFiles);
        const analysisResults = this.performQuickAnalysis(projectContext);
        
        return {
            userRequest: userRequest,
            projectStructure: this.getProjectStructure(),
            fileContents: projectContext.fileContents,
            analysisResults: analysisResults,
            aiPromptText: this.buildAIPromptText(userRequest, projectContext, analysisResults),
            timestamp: new Date().toLocaleString('id-ID')
        };
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    buildAIPromptText(userRequest, projectContext, analysisResults) {
        const cleanRequest = userRequest.replace(/@\S+/g, '').trim();
        let promptText = `Saya memiliki project dengan struktur dan kode berikut. Tolong ${cleanRequest}\n\n`;
        
        // Add optimization notes if issues found
        if (analysisResults.issues.length > 0) {
            promptText += `=== ISSUES YANG DITEMUKAN ===\n`;
            analysisResults.issues.forEach(issue => {
                promptText += `- ${issue}\n`;
            });
            promptText += '\n';
        }
        
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
        
        promptText += `=== PERMINTAAN ===\n`;
        promptText += `${cleanRequest}\n\n`;
        
        promptText += `=== INSTRUKSI UNTUK AI ===\n`;
        promptText += `1. Berikan kode lengkap yang sudah diupdate untuk setiap file yang perlu diubah.\n`;
        promptText += `2. Pastikan kode sudah dioptimalkan, robust, dan mengikuti best practices.\n`;
        promptText += `3. Tambahkan error handling yang proper.\n`;
        promptText += `4. Gunakan sintaks modern (ES6+ untuk JavaScript).\n`;
        promptText += `5. Tambahkan komentar untuk bagian yang kompleks.\n\n`;
        
        promptText += `Format response:\n`;
        promptText += `=== FILENAME.EXT ===\n`;
        promptText += `[complete updated code here]\n\n`;
        
        return promptText;
    }

    performQuickAnalysis(context) {
        const analysis = {
            totalFiles: Object.keys(context.fileContents).length,
            totalLines: 0,
            fileTypes: new Set(),
            issues: [],
            recommendations: [],
            codeQuality: {
                hasOldSyntax: false,
                hasDebugCode: false,
                hasLongFiles: false,
                lackErrorHandling: false
            }
        };

        Object.entries(context.fileContents).forEach(([filename, content]) => {
            const lines = content.split('\n');
            const lineCount = lines.length;
            analysis.totalLines += lineCount;
            
            const ext = filename.split('.').pop().toLowerCase();
            analysis.fileTypes.add(ext);
            
            // JavaScript/TypeScript specific checks
            if (['js', 'ts', 'jsx', 'tsx'].includes(ext)) {
                if (/\bvar\s+\w+/.test(content)) {
                    analysis.issues.push(`${filename}: Menggunakan 'var' instead of 'let/const'`);
                    analysis.codeQuality.hasOldSyntax = true;
                }
                
                if (!/try\s*{/.test(content) && lineCount > 50) {
                    analysis.issues.push(`${filename}: Tidak ada error handling (try-catch)`);
                    analysis.codeQuality.lackErrorHandling = true;
                }
                
                if (/function\s*\(/.test(content) && !(/=>\s*{/.test(content))) {
                    analysis.recommendations.push(`${filename}: Pertimbangkan menggunakan arrow functions`);
                }
            }
            
            // General checks
            if (/console\.(log|debug|info)/.test(content)) {
                analysis.issues.push(`${filename}: Mengandung console statements`);
                analysis.codeQuality.hasDebugCode = true;
            }
            
            if (/TODO|FIXME|HACK|XXX/.test(content)) {
                analysis.issues.push(`${filename}: Mengandung TODO/FIXME comments`);
            }
            
            if (lineCount > 500) {
                analysis.issues.push(`${filename}: File terlalu besar (${lineCount} lines)`);
                analysis.codeQuality.hasLongFiles = true;
            }
            
            // Check for potential security issues
            if (/innerHTML\s*=/.test(content)) {
                analysis.issues.push(`${filename}: Menggunakan innerHTML (potential XSS risk)`);
            }
            
            if (/eval\s*\(/.test(content)) {
                analysis.issues.push(`${filename}: Menggunakan eval() (security risk)`);
            }
        });

        // Add general recommendations based on analysis
        if (analysis.codeQuality.hasOldSyntax) {
            analysis.recommendations.push('Upgrade ke ES6+ syntax untuk better performance');
        }
        
        if (analysis.codeQuality.lackErrorHandling) {
            analysis.recommendations.push('Tambahkan proper error handling untuk robustness');
        }

        return analysis;
    }

    displayAIPrompt(aiPrompt) {
        // Display analysis summary in results container
        const summaryHtml = this.createAnalysisSummary(aiPrompt.analysisResults);
        this.displayAnalysisResult({
            title: '📊 Quick Analysis Summary',
            content: summaryHtml,
            timestamp: aiPrompt.timestamp,
            isHtml: true
        });
        
        // Display AI prompt in prompt content
        this.elements.aiPromptContent.textContent = aiPrompt.aiPromptText;
    }

    createAnalysisSummary(analysis) {
        return `
Total Files: ${analysis.totalFiles}
Total Lines: ${analysis.totalLines}
File Types: ${Array.from(analysis.fileTypes).join(', ')}

Issues Found: ${analysis.issues.length}
${analysis.issues.slice(0, 5).map(i => `• ${i}`).join('\n')}
${analysis.issues.length > 5 ? `... and ${analysis.issues.length - 5} more issues` : ''}

Recommendations: ${analysis.recommendations.length}
${analysis.recommendations.slice(0, 3).map(r => `• ${r}`).join('\n')}`;
    }

    async copyAIPrompt() {
        if (!this.currentAIPrompt) {
            this.showMessage('Tidak ada AI prompt untuk dicopy!', 'error');
            return;
        }

        try {
            await navigator.clipboard.writeText(this.currentAIPrompt.aiPromptText);
            const btn = this.elements.copyPromptBtn;
            const originalText = btn.textContent;
            btn.textContent = '✅ Copied! Paste ke AI sekarang';
            setTimeout(() => {
                btn.textContent = originalText;
            }, 3000);
        } catch (err) {
            console.error('Copy failed:', err);
            this.showMessage('Gagal copy ke clipboard. Silakan select dan copy manual.', 'error');
        }
    }

    downloadAIReadyReport() {
        if (!this.currentAIPrompt) {
            this.showMessage('Generate AI prompt terlebih dahulu!', 'error');
            return;
        }

        const reportContent = this.generateAIReadyReportContent();
        const blob = new Blob([reportContent], { type: 'text/plain;charset=utf-8' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        
        const timestamp = new Date().toISOString().slice(0, 19).replace(/:/g, '-');
        a.href = url;
        a.download = `ai-ready-prompt-${timestamp}.txt`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        
        this.showMessage('Report berhasil didownload!', 'success');
    }

    generateAIReadyReportContent() {
        const report = [
            '=' .repeat(60),
            'AI-READY PROJECT ANALYSIS REPORT',
            '=' .repeat(60),
            `Generated: ${new Date().toLocaleString('id-ID')}`,
            `Total Files: ${this.uploadedFiles.size}`,
            '',
            '=' .repeat(60),
            'PROMPT FOR AI',
            '=' .repeat(60),
            '',
            this.currentAIPrompt.aiPromptText,
            '',
            '=' .repeat(60),
            'END OF REPORT',
            '=' .repeat(60)
        ].join('\n');
        
        return report;
    }

    extractMentionedFiles(prompt) {
        const mentions = prompt.match(/@(\S+)/g) || [];
        return mentions.map(mention => mention.substring(1));
    }

    buildProjectContext(mentionedFiles) {
        const context = {
            allFiles: Array.from(this.uploadedFiles.keys()),
            mentionedFiles: {},
            projectStructure: this.getProjectStructure(),
            fileContents: {}
        };

        const filesToInclude = mentionedFiles.length > 0 ? 
            mentionedFiles.filter(f => this.uploadedFiles.has(f)) : 
            Array.from(this.uploadedFiles.keys());

        filesToInclude.forEach(filename => {
            const file = this.uploadedFiles.get(filename);
            if (file) {
                context.mentionedFiles[filename] = file.content;
                context.fileContents[filename] = file.content;
            }
        });

        return context;
    }

    getProjectStructure() {
        const structure = {};
        
        this.uploadedFiles.forEach((file, filename) => {
            const path = file.path || filename;
            const parts = path.split(/[\/\\]/);
            let current = structure;
            
            for (let i = 0; i < parts.length; i++) {
                const part = parts[i];
                if (i === parts.length - 1) {
                    current[part] = {
                        type: 'file',
                        size: file.size,
                        path: path
                    };
                } else {
                    if (!current[part]) {
                        current[part] = {
                            type: 'folder',
                            children: {}
                        };
                    }
                    current = current[part].children;
                }
            }
        });
        
        return structure;
    }

    generateStructureTree(structure, indent = 0) {
        let tree = '';
        const prefix = '  '.repeat(indent);
        const entries = Object.entries(structure).sort((a, b) => {
            // Folders first, then files
            if (a[1].type === 'folder' && b[1].type === 'file') return -1;
            if (a[1].type === 'file' && b[1].type === 'folder') return 1;
            return a[0].localeCompare(b[0]);
        });
        
        for (const [name, item] of entries) {
            if (item.type === 'folder') {
                tree += `${prefix}📁 ${name}/\n`;
                tree += this.generateStructureTree(item.children, indent + 1);
            } else {
                tree += `${prefix}📄 ${name} (${this.formatFileSize(item.size)})\n`;
            }
        }
        
        return tree;
    }

    displayAnalysisResult(analysis) {
        const template = document.getElementById('resultTemplate');
        const clone = template.content.cloneNode(true);
        const resultElement = clone.querySelector('.analysis-result');
        
        resultElement.querySelector('.result-title').textContent = analysis.title;
        resultElement.querySelector('.result-time').textContent = analysis.timestamp;
        
        const contentElement = resultElement.querySelector('.result-content');
        if (analysis.isHtml) {
            contentElement.textContent = analysis.content; // Use textContent instead of innerHTML for security
        } else {
            contentElement.textContent = analysis.content;
        }
        
        // Add event listeners to buttons
        const copyBtn = resultElement.querySelector('.copy-btn');
        const clearBtn = resultElement.querySelector('.clear-btn');
        
        copyBtn.addEventListener('click', async () => {
            try {
                await navigator.clipboard.writeText(analysis.content);
                copyBtn.textContent = '✅ Copied!';
                setTimeout(() => {
                    copyBtn.textContent = '📋 Copy';
                }, 2000);
            } catch (err) {
                console.error('Copy failed:', err);
            }
        });
        
        clearBtn.addEventListener('click', () => {
            resultElement.remove();
            if (this.elements.resultsContainer.children.length === 0) {
                this.elements.resultsContainer.innerHTML = '<div class="placeholder">🚀 Upload project dan klik "GENERATE" untuk mulai</div>';
            }
        });
        
        // Remove placeholder if exists
        const placeholder = this.elements.resultsContainer.querySelector('.placeholder');
        if (placeholder) {
            placeholder.remove();
        }
        
        // Remove old messages
        const messages = this.elements.resultsContainer.querySelectorAll('.message');
        messages.forEach(m => m.remove());
        
        this.elements.resultsContainer.insertBefore(clone, this.elements.resultsContainer.firstChild);
        this.elements.resultsContainer.scrollTop = 0;
    }
}

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new EnhancedAIAnalyzer();
});