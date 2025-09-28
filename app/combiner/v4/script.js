'use strict';

/**
 * Enhanced AI Project Analyzer
 * Simplified version with combined prompt generation and analysis
 */
class EnhancedAIAnalyzer {
    constructor() {
        this.uploadedFiles = new Map();
        this.currentAIPrompt = null;
        this.supportedExtensions = new Set([
            'js', 'html', 'css', 'md', 'txt', 'json', 'py', 'tsx', 
            'ts', 'jsx', 'vue', 'php', 'java', 'cpp', 'c', 'go', 
            'rs', 'rb', 'swift', 'yml', 'yaml', 'xml', 'sh', 'bat'
        ]);
        this.initializeEventListeners();
        this.setupKeyboardShortcuts();
        this.restoreLastSession();
    }

    /**
     * Initialize all event listeners with proper error handling
     */
    initializeEventListeners() {
        try {
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
                uploadedFiles: document.getElementById('uploadedFiles'),
                aiPromptSection: document.getElementById('aiPromptSection'),
                aiPromptContent: document.getElementById('aiPromptContent')
            };

            // Validate required elements
            const missingElements = Object.entries(this.elements)
                .filter(([key, element]) => !element)
                .map(([key]) => key);
            
            if (missingElements.length > 0) {
                throw new Error(`Missing DOM elements: ${missingElements.join(', ')}`);
            }

            this.setupDragAndDrop();
            this.setupFileHandling();
            this.setupButtons();
            this.setupAutoSave();

        } catch (error) {
            console.error('Initialization error:', error);
            this.showMessage('Error initializing application: ' + error.message, 'error');
        }
    }

    /**
     * Setup drag and drop functionality with proper event handling
     */
    setupDragAndDrop() {
        let dragCounter = 0;
        
        this.elements.uploadArea.addEventListener('click', () => {
            this.elements.fileInput.click();
        });
        
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
    }

    /**
     * Setup file handling events
     */
    setupFileHandling() {
        this.elements.fileInput.addEventListener('change', this.handleFileSelect.bind(this));
    }

    /**
     * Setup button event listeners with debouncing
     */
    setupButtons() {
        this.elements.generateBtn.addEventListener('click', 
            this.debounce(this.generateCombinedOutput.bind(this), 300)
        );
        
        this.elements.downloadBtn.addEventListener('click', 
            this.debounce(this.downloadAIReadyReport.bind(this), 300)
        );
        
        this.elements.copyPromptBtn.addEventListener('click', 
            this.copyAIPrompt.bind(this)
        );
    }

    /**
     * Setup auto-save functionality using memory storage
     */
    setupAutoSave() {
        this.elements.analysisPrompt.addEventListener('input', 
            this.debounce(() => {
                // Use in-memory storage instead of localStorage for artifact compatibility
                this.lastPrompt = this.elements.analysisPrompt.value;
            }, 500)
        );
    }

    /**
     * Restore last session from memory (if available)
     */
    restoreLastSession() {
        if (this.lastPrompt) {
            this.elements.analysisPrompt.value = this.lastPrompt;
        }
    }

    /**
     * Setup keyboard shortcuts for better UX
     */
    setupKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            // Ctrl/Cmd + Enter to generate
            if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
                e.preventDefault();
                if (!this.elements.generateBtn.disabled) {
                    this.elements.generateBtn.click();
                }
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

    /**
     * Debounce utility function
     */
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

    /**
     * Handle drag and drop file traversal
     */
    async handleDrop(e) {
        try {
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
            
            await this.processFiles(files);
        } catch (error) {
            console.error('Drop handling error:', error);
            this.showMessage('Error processing dropped files: ' + error.message, 'error');
        }
    }

    /**
     * Recursively traverse file tree for directories
     */
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
                    try {
                        for (let entry of entries) {
                            await this.traverseFileTree(entry, files, path + item.name + "/");
                        }
                        resolve();
                    } catch (error) {
                        console.error('Directory traversal error:', error);
                        resolve();
                    }
                });
            }
        });
    }

    /**
     * Handle file input selection
     */
    handleFileSelect(e) {
        const files = Array.from(e.target.files);
        this.processFiles(files);
    }

    /**
     * Process and validate uploaded files
     */
    async processFiles(files) {
        try {
            const textFiles = files.filter(file => this.isValidFile(file));
            const totalSize = textFiles.reduce((sum, file) => sum + file.size, 0);
            
            // Check total size limit (10MB)
            if (totalSize > 10 * 1024 * 1024) {
                this.showMessage('Total ukuran file melebihi 10MB. Silakan pilih file yang lebih kecil.', 'error');
                return;
            }

            const filePromises = textFiles.map(async (file) => {
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

            const results = await Promise.all(filePromises);
            const validResults = results.filter(r => r !== null);

            // Update uploaded files collection
            this.uploadedFiles.clear();
            validResults.forEach(fileData => {
                this.uploadedFiles.set(fileData.name, fileData);
            });

            this.updateFileList();
            this.updateFileButtons();
            
            if (validResults.length > 0) {
                this.showMessage(`${validResults.length} file berhasil diupload`, 'success');
            }

        } catch (error) {
            console.error('File processing error:', error);
            this.showMessage('Error processing files: ' + error.message, 'error');
        }
    }

    /**
     * Check if file is valid for processing
     */
    isValidFile(file) {
        const extension = file.name.split('.').pop().toLowerCase();
        return this.supportedExtensions.has(extension) || 
               file.type.startsWith('text/') ||
               file.size < 1024 * 1024; // Allow small files regardless of extension
    }

    /**
     * Get MIME type based on file extension
     */
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

    /**
     * Read file content asynchronously
     */
    readFileContent(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = (e) => resolve(e.target.result);
            reader.onerror = (e) => reject(new Error('Failed to read file'));
            reader.readAsText(file);
        });
    }

    /**
     * Update file list display
     */
    updateFileList() {
        const template = document.getElementById('fileItemTemplate');
        if (!template) {
            console.error('File item template not found');
            return;
        }

        this.elements.filesList.innerHTML = '';
        const fragment = document.createDocumentFragment();
        
        this.uploadedFiles.forEach((file, filename) => {
            const clone = template.content.cloneNode(true);
            
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

    /**
     * Update file mention buttons
     */
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

    /**
     * Add file mention to textarea
     */
    mentionFile(filename) {
        const currentText = this.elements.analysisPrompt.value;
        const mentionText = `@${filename}`;
        
        if (!currentText.includes(mentionText)) {
            const newText = currentText ? `${currentText} ${mentionText}` : mentionText;
            this.elements.analysisPrompt.value = newText;
            this.elements.analysisPrompt.focus();
            
            // Trigger auto-save
            this.lastPrompt = newText;
        }
    }

    /**
     * Format file size for display
     */
    formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    /**
     * Show message with auto-dismiss
     */
    showMessage(text, type = 'info') {
        const message = document.createElement('div');
        message.className = `message ${type}`;
        message.textContent = text;
        
        // Insert at the top of AI prompt section if visible, otherwise in main content
        const targetContainer = this.elements.aiPromptSection.style.display !== 'none' 
            ? this.elements.aiPromptSection 
            : this.elements.uploadArea.parentNode;
            
        targetContainer.insertBefore(message, targetContainer.firstChild);
        
        setTimeout(() => {
            message.style.opacity = '0';
            setTimeout(() => message.remove(), 300);
        }, 4000);
    }

    /**
     * MAIN FUNCTION: Generate combined AI prompt and analysis
     * This replaces the separate analyze and generate functions
     */
    async generateCombinedOutput() {
        const prompt = this.elements.analysisPrompt.value.trim();
        
        if (!prompt) {
            this.showMessage('Silakan masukkan permintaan terlebih dahulu!', 'error');
            return;
        }

        if (this.uploadedFiles.size === 0) {
            this.showMessage('Silakan upload file project terlebih dahulu!', 'error');
            return;
        }

        this.setButtonLoading(this.elements.generateBtn, true, '🚀 Generating...');

        try {
            // Generate comprehensive AI prompt with analysis
            const combinedResult = await this.createCombinedAIPrompt(prompt);
            this.currentAIPrompt = combinedResult;
            this.displayCombinedResult(combinedResult);
            
            // Enable download button
            this.elements.downloadBtn.disabled = false;
            
            // Show AI prompt section
            this.elements.aiPromptSection.style.display = 'block';
            
            this.showMessage('AI Prompt dan Analisis berhasil dibuat!', 'success');
            
        } catch (error) {
            console.error('Generation error:', error);
            this.showMessage('Terjadi kesalahan: ' + error.message, 'error');
        } finally {
            this.setButtonLoading(this.elements.generateBtn, false, '🚀 GENERATE');
        }
    }

    /**
     * Set button loading state
     */
    setButtonLoading(button, loading, text) {
        button.disabled = loading;
        if (loading) {
            button.innerHTML = `<span class="loading-spinner"></span> ${text}`;
        } else {
            button.textContent = text;
        }
    }

    /**
     * Create comprehensive AI prompt with integrated analysis
     */
    async createCombinedAIPrompt(userRequest) {
        // Simulate processing time for better UX
        await this.delay(1200);

        const mentionedFiles = this.extractMentionedFiles(userRequest);
        const projectContext = this.buildProjectContext(mentionedFiles);
        const analysisResults = this.performComprehensiveAnalysis(projectContext);
        
        return {
            userRequest: userRequest,
            projectStructure: this.getProjectStructure(),
            fileContents: projectContext.fileContents,
            analysisResults: analysisResults,
            combinedPromptText: this.buildCombinedPromptText(userRequest, projectContext, analysisResults),
            timestamp: new Date().toLocaleString('id-ID')
        };
    }

    /**
     * Build comprehensive prompt text combining request and analysis
     */
    buildCombinedPromptText(userRequest, projectContext, analysisResults) {
        const cleanRequest = userRequest.replace(/@\S+/g, '').trim();
        let promptText = `Saya memiliki project dengan struktur dan kode berikut. Tolong ${cleanRequest}\n\n`;
        
        // Add analysis summary first
        promptText += `=== ANALYSIS SUMMARY ===\n`;
        promptText += `Total Files: ${analysisResults.totalFiles}\n`;
        promptText += `Total Lines: ${analysisResults.totalLines}\n`;
        promptText += `File Types: ${Array.from(analysisResults.fileTypes).join(', ')}\n`;
        promptText += `Code Quality Score: ${this.calculateQualityScore(analysisResults)}/100\n\n`;
        
        // Add issues found
        if (analysisResults.issues.length > 0) {
            promptText += `=== ISSUES YANG DITEMUKAN ===\n`;
            analysisResults.issues.forEach(issue => {
                promptText += `- ${issue}\n`;
            });
            promptText += '\n';
        }
        
        // Add recommendations
        if (analysisResults.recommendations.length > 0) {
            promptText += `=== RECOMMENDATIONS ===\n`;
            analysisResults.recommendations.forEach(rec => {
                promptText += `- ${rec}\n`;
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
        
        promptText += `=== INSTRUKSI UNTUK AI ===\n`;
        promptText += `1. Berikan kode lengkap yang sudah diupdate untuk setiap file yang perlu diubah.\n`;
        promptText += `2. Pastikan kode sudah dioptimalkan, robust, dan mengikuti best practices.\n`;
        promptText += `3. Tambahkan error handling yang proper.\n`;
        promptText += `4. Gunakan sintaks modern (ES6+ untuk JavaScript).\n`;
        promptText += `5. Fix semua issues yang ditemukan dalam analysis.\n`;
        promptText += `6. Implementasikan semua recommendations yang relevan.\n`;
        promptText += `7. Tambahkan komentar untuk bagian yang kompleks.\n\n`;
        
        promptText += `Format response:\n`;
        promptText += `=== FILENAME.EXT ===\n`;
        promptText += `[complete updated code here]\n\n`;
        
        return promptText;
    }

    /**
     * Perform comprehensive code analysis
     */
    performComprehensiveAnalysis(context) {
        const analysis = {
            totalFiles: Object.keys(context.fileContents).length,
            totalLines: 0,
            fileTypes: new Set(),
            issues: [],
            recommendations: [],
            security: [],
            performance: [],
            codeQuality: {
                hasOldSyntax: false,
                hasDebugCode: false,
                hasLongFiles: false,
                lackErrorHandling: false,
                hasSecurityIssues: false,
                hasPerformanceIssues: false
            }
        };

        Object.entries(context.fileContents).forEach(([filename, content]) => {
            const lines = content.split('\n');
            const lineCount = lines.length;
            analysis.totalLines += lineCount;
            
            const ext = filename.split('.').pop().toLowerCase();
            analysis.fileTypes.add(ext);
            
            // Language-specific analysis
            this.analyzeByLanguage(filename, content, analysis);
            
            // General code quality checks
            this.performGeneralChecks(filename, content, lineCount, analysis);
        });

        // Generate recommendations based on findings
        this.generateSmartRecommendations(analysis);

        return analysis;
    }

    /**
     * Analyze code by programming language
     */
    analyzeByLanguage(filename, content, analysis) {
        const ext = filename.split('.').pop().toLowerCase();
        
        switch (ext) {
            case 'js':
            case 'ts':
            case 'jsx':
            case 'tsx':
                this.analyzeJavaScriptTypeScript(filename, content, analysis);
                break;
            case 'html':
                this.analyzeHTML(filename, content, analysis);
                break;
            case 'css':
                this.analyzeCSS(filename, content, analysis);
                break;
            case 'py':
                this.analyzePython(filename, content, analysis);
                break;
            default:
                this.analyzeGeneric(filename, content, analysis);
        }
    }

    /**
     * Analyze JavaScript/TypeScript files
     */
    analyzeJavaScriptTypeScript(filename, content, analysis) {
        // Check for old syntax
        if (/\bvar\s+\w+/.test(content)) {
            analysis.issues.push(`${filename}: Using 'var' instead of 'let/const'`);
            analysis.codeQuality.hasOldSyntax = true;
        }

        // Check for error handling
        if (!/try\s*{|catch\s*\(|\.catch\(/.test(content) && content.length > 1000) {
            analysis.issues.push(`${filename}: Missing error handling`);
            analysis.codeQuality.lackErrorHandling = true;
        }

        // Check for modern features
        if (!/(?:const|let)\s+\w+\s*=\s*\(.*\)\s*=>/.test(content) && /function\s+\w+\s*\(/.test(content)) {
            analysis.recommendations.push(`${filename}: Consider using arrow functions`);
        }

        // Performance checks
        if (/document\.getElementById/.test(content) && content.match(/document\.getElementById/g).length > 5) {
            analysis.performance.push(`${filename}: Multiple DOM queries - consider caching elements`);
            analysis.codeQuality.hasPerformanceIssues = true;
        }

        // Security checks
        if (/innerHTML\s*=/.test(content)) {
            analysis.security.push(`${filename}: innerHTML usage - potential XSS risk`);
            analysis.codeQuality.hasSecurityIssues = true;
        }

        if (/eval\s*\(/.test(content)) {
            analysis.security.push(`${filename}: eval() usage - security risk`);
            analysis.codeQuality.hasSecurityIssues = true;
        }
    }

    /**
     * Analyze HTML files
     */
    analyzeHTML(filename, content, analysis) {
        if (!content.includes('<!DOCTYPE html>')) {
            analysis.issues.push(`${filename}: Missing DOCTYPE declaration`);
        }

        if (!content.includes('<meta charset=')) {
            analysis.issues.push(`${filename}: Missing charset meta tag`);
        }

        if (!content.includes('viewport')) {
            analysis.recommendations.push(`${filename}: Add viewport meta tag for responsive design`);
        }
    }

    /**
     * Analyze CSS files
     */
    analyzeCSS(filename, content, analysis) {
        const rules = content.match(/[^{}]+\{[^{}]*\}/g) || [];
        
        if (rules.length > 200) {
            analysis.performance.push(`${filename}: Large CSS file - consider splitting or using CSS modules`);
        }

        if (!content.includes('@media')) {
            analysis.recommendations.push(`${filename}: No media queries found - consider responsive design`);
        }
    }

    /**
     * Analyze Python files
     */
    analyzePython(filename, content, analysis) {
        if (!/try:\s*$[\s\S]*?except[\s\S]*?:/m.test(content) && content.length > 1000) {
            analysis.issues.push(`${filename}: Missing exception handling`);
        }

        if (!/^if __name__ == ['"']__main__['"]:/m.test(content) && content.includes('def ')) {
            analysis.recommendations.push(`${filename}: Add main guard for better module structure`);
        }
    }

    /**
     * Generic file analysis
     */
    analyzeGeneric(filename, content, analysis) {
        // Basic checks for any file type
        const longLines = content.split('\n').filter(line => line.length > 120);
        if (longLines.length > content.split('\n').length * 0.1) {
            analysis.issues.push(`${filename}: Many long lines (>120 characters)`);
        }
    }

    /**
     * Perform general code quality checks
     */
    performGeneralChecks(filename, content, lineCount, analysis) {
        // Debug code detection
        if (/console\.(log|debug|info|warn|error)|print\(|println!|fmt\.Print/.test(content)) {
            analysis.issues.push(`${filename}: Debug statements found`);
            analysis.codeQuality.hasDebugCode = true;
        }

        // TODO/FIXME comments
        if (/TODO|FIXME|HACK|XXX|BUG/.test(content)) {
            analysis.issues.push(`${filename}: Contains TODO/FIXME comments`);
        }

        // File size check
        if (lineCount > 500) {
            analysis.issues.push(`${filename}: Large file (${lineCount} lines) - consider refactoring`);
            analysis.codeQuality.hasLongFiles = true;
        }

        // Potential credential exposure
        if (/(?:password|secret|key|token)\s*[:=]\s*['"][^'"]{8,}['"]|api[_-]?key\s*[:=]/i.test(content)) {
            analysis.security.push(`${filename}: Potential hardcoded credentials`);
        }
    }

    /**
     * Generate smart recommendations based on analysis
     */
    generateSmartRecommendations(analysis) {
        if (analysis.codeQuality.hasOldSyntax) {
            analysis.recommendations.push('Modernize JavaScript syntax (ES6+) for better performance and readability');
        }

        if (analysis.codeQuality.lackErrorHandling) {
            analysis.recommendations.push('Add comprehensive error handling for better robustness');
        }

        if (analysis.codeQuality.hasLongFiles) {
            analysis.recommendations.push('Split large files into smaller, more maintainable modules');
        }

        if (analysis.codeQuality.hasSecurityIssues) {
            analysis.recommendations.push('Address security vulnerabilities (XSS, code injection risks)');
        }

        if (analysis.codeQuality.hasPerformanceIssues) {
            analysis.recommendations.push('Optimize performance bottlenecks (DOM access, large loops)');
        }

        if (analysis.totalFiles > 1 && !analysis.fileTypes.has('json')) {
            analysis.recommendations.push('Consider adding package.json for better dependency management');
        }

        // Consolidate issues into recommendations and security findings
        analysis.issues.forEach(issue => {
            if (issue.includes('security') || issue.includes('XSS') || issue.includes('eval')) {
                analysis.security.push(issue);
            }
        });
    }

    /**
     * Calculate overall code quality score
     */
    calculateQualityScore(analysis) {
        let score = 100;
        
        // Deduct points for various issues
        score -= Math.min(analysis.issues.length * 5, 30);
        score -= Math.min(analysis.security.length * 10, 40);
        score -= Math.min(analysis.performance.length * 8, 30);
        
        // Bonus points for good practices
        if (analysis.fileTypes.has('json')) score += 5; // Has package.json
        if (analysis.totalFiles < 10 && analysis.totalLines < 2000) score += 10; // Reasonable size
        
        return Math.max(score, 0);
    }

    /**
     * Delay utility for UX
     */
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    /**
     * Display combined results in the AI prompt section
     */
    displayCombinedResult(result) {
        // Create formatted display content
        const displayContent = this.createDisplayContent(result);
        this.elements.aiPromptContent.textContent = displayContent;
    }

    /**
     * Create formatted display content
     */
    createDisplayContent(result) {
        const analysis = result.analysisResults;
        let displayText = `=== QUICK ANALYSIS SUMMARY ===\n`;
        displayText += `📊 Files: ${analysis.totalFiles} | Lines: ${analysis.totalLines} | Quality: ${this.calculateQualityScore(analysis)}/100\n`;
        displayText += `📁 Types: ${Array.from(analysis.fileTypes).join(', ')}\n\n`;
        
        if (analysis.issues.length > 0) {
            displayText += `⚠️ Issues Found (${analysis.issues.length}):\n`;
            analysis.issues.slice(0, 5).forEach(issue => {
                displayText += `• ${issue}\n`;
            });
            if (analysis.issues.length > 5) {
                displayText += `... and ${analysis.issues.length - 5} more\n`;
            }
            displayText += '\n';
        }

        if (analysis.security.length > 0) {
            displayText += `🔒 Security Concerns (${analysis.security.length}):\n`;
            analysis.security.forEach(sec => {
                displayText += `• ${sec}\n`;
            });
            displayText += '\n';
        }

        if (analysis.recommendations.length > 0) {
            displayText += `💡 Recommendations (${analysis.recommendations.length}):\n`;
            analysis.recommendations.slice(0, 5).forEach(rec => {
                displayText += `• ${rec}\n`;
            });
            displayText += '\n';
        }

        displayText += `${'='.repeat(60)}\n`;
        displayText += `FULL AI PROMPT (Copy semua untuk AI):\n`;
        displayText += `${'='.repeat(60)}\n\n`;
        displayText += result.combinedPromptText;
        
        return displayText;
    }

    /**
     * Copy AI prompt to clipboard
     */
    async copyAIPrompt() {
        if (!this.currentAIPrompt) {
            this.showMessage('Generate prompt terlebih dahulu!', 'error');
            return;
        }

        try {
            await navigator.clipboard.writeText(this.currentAIPrompt.combinedPromptText);
            const btn = this.elements.copyPromptBtn;
            const originalText = btn.textContent;
            btn.textContent = '✅ Copied! Paste ke AI sekarang';
            btn.style.background = '#27ae60';
            
            setTimeout(() => {
                btn.textContent = originalText;
                btn.style.background = '#17a2b8';
            }, 3000);
            
        } catch (err) {
            console.error('Copy failed:', err);
            // Fallback: select text for manual copy
            this.elements.aiPromptContent.select();
            this.showMessage('Please copy the text manually (Ctrl+C)', 'error');
        }
    }

    /**
     * Download comprehensive AI-ready report
     */
    downloadAIReadyReport() {
        if (!this.currentAIPrompt) {
            this.showMessage('Generate prompt terlebih dahulu!', 'error');
            return;
        }

        try {
            const reportContent = this.generateComprehensiveReport();
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
            
        } catch (error) {
            console.error('Download error:', error);
            this.showMessage('Error downloading report: ' + error.message, 'error');
        }
    }

    /**
     * Generate comprehensive report content
     */
    generateComprehensiveReport() {
        const analysis = this.currentAIPrompt.analysisResults;
        const report = [
            '='.repeat(60),
            'AI-READY PROJECT ANALYSIS REPORT',
            '='.repeat(60),
            `Generated: ${new Date().toLocaleString('id-ID')}`,
            `Total Files: ${this.uploadedFiles.size}`,
            `Quality Score: ${this.calculateQualityScore(analysis)}/100`,
            '',
            '='.repeat(60),
            'ANALYSIS SUMMARY',
            '='.repeat(60),
            `Files: ${analysis.totalFiles}`,
            `Lines: ${analysis.totalLines}`,
            `Types: ${Array.from(analysis.fileTypes).join(', ')}`,
            `Issues: ${analysis.issues.length}`,
            `Security: ${analysis.security.length}`,
            `Recommendations: ${analysis.recommendations.length}`,
            '',
            '='.repeat(60),
            'PROMPT FOR AI',
            '='.repeat(60),
            '',
            this.currentAIPrompt.combinedPromptText,
            '',
            '='.repeat(60),
            'END OF REPORT',
            '='.repeat(60)
        ].join('\n');
        
        return report;
    }

    /**
     * Extract mentioned files from prompt
     */
    extractMentionedFiles(prompt) {
        const mentions = prompt.match(/@(\S+)/g) || [];
        return mentions.map(mention => mention.substring(1));
    }

    /**
     * Build project context for analysis
     */
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

    /**
     * Get project structure
     */
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

    /**
     * Generate tree structure display
     */
    generateStructureTree(structure, indent = 0) {
        let tree = '';
        const prefix = '  '.repeat(indent);
        const entries = Object.entries(structure).sort((a, b) => {
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
}

// Initialize the application when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    try {
        new EnhancedAIAnalyzer();
        console.log('Enhanced AI Analyzer initialized successfully');
    } catch (error) {
        console.error('Failed to initialize analyzer:', error);
    }
});