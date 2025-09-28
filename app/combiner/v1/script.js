class DeepseekAnalyzer {
    constructor() {
        this.uploadedFiles = new Map();
        this.initializeEventListeners();
    }

    initializeEventListeners() {
        // File input handling
        const fileInput = document.getElementById('fileInput');
        const uploadArea = document.getElementById('uploadArea');
        const analyzeBtn = document.getElementById('analyzeBtn');

        // Drag and drop functionality
        uploadArea.addEventListener('click', () => fileInput.click());
        uploadArea.addEventListener('dragover', this.handleDragOver.bind(this));
        uploadArea.addEventListener('dragleave', this.handleDragLeave.bind(this));
        uploadArea.addEventListener('drop', this.handleDrop.bind(this));

        // File input change
        fileInput.addEventListener('change', this.handleFileSelect.bind(this));

        // Analyze button
        analyzeBtn.addEventListener('click', this.analyzeProject.bind(this));
    }

    handleDragOver(e) {
        e.preventDefault();
        document.getElementById('uploadArea').classList.add('drag-over');
    }

    handleDragLeave(e) {
        e.preventDefault();
        document.getElementById('uploadArea').classList.remove('drag-over');
    }

    handleDrop(e) {
        e.preventDefault();
        document.getElementById('uploadArea').classList.remove('drag-over');
        
        const files = Array.from(e.dataTransfer.files);
        this.processFiles(files);
    }

    handleFileSelect(e) {
        const files = Array.from(e.target.files);
        this.processFiles(files);
    }

    async processFiles(files) {
        const textFiles = files.filter(file => 
            file.type.startsWith('text/') || 
            file.name.match(/\.(js|html|css|md|txt|json)$/i)
        );

        for (const file of textFiles) {
            try {
                const content = await this.readFileContent(file);
                this.uploadedFiles.set(file.name, {
                    name: file.name,
                    content: content,
                    size: file.size,
                    type: file.type
                });
            } catch (error) {
                console.error(`Error reading file ${file.name}:`, error);
            }
        }

        this.updateFileList();
        this.updateFileButtons();
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
        const filesList = document.getElementById('filesList');
        const template = document.getElementById('fileItemTemplate');
        
        filesList.innerHTML = '';

        this.uploadedFiles.forEach((file, filename) => {
            const clone = template.content.cloneNode(true);
            const fileItem = clone.querySelector('.file-item');
            
            fileItem.querySelector('.file-name').textContent = filename;
            fileItem.querySelector('.file-size').textContent = this.formatFileSize(file.size);
            
            const mentionBtn = fileItem.querySelector('.mention-btn');
            mentionBtn.addEventListener('click', () => this.mentionFile(filename));
            
            filesList.appendChild(clone);
        });

        // Show/hide uploaded files section
        const uploadedFilesSection = document.getElementById('uploadedFiles');
        uploadedFilesSection.style.display = this.uploadedFiles.size > 0 ? 'block' : 'none';
    }

    updateFileButtons() {
        const fileButtons = document.getElementById('fileButtons');
        fileButtons.innerHTML = '';

        this.uploadedFiles.forEach((file, filename) => {
            const button = document.createElement('button');
            button.className = 'file-mention-btn';
            button.textContent = filename;
            button.title = `Mention ${filename} dalam analisa`;
            button.addEventListener('click', () => this.mentionFile(filename));
            fileButtons.appendChild(button);
        });
    }

    mentionFile(filename) {
        const promptTextarea = document.getElementById('analysisPrompt');
        const currentText = promptTextarea.value;
        const mentionText = `@${filename}`;
        
        if (currentText.includes(mentionText)) {
            return; // Already mentioned
        }

        const newText = currentText ? `${currentText} ${mentionText}` : mentionText;
        promptTextarea.value = newText;
        promptTextarea.focus();
    }

    formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    async analyzeProject() {
        const prompt = document.getElementById('analysisPrompt').value.trim();
        
        if (!prompt) {
            alert('Silakan masukkan permintaan analisa terlebih dahulu!');
            return;
        }

        if (this.uploadedFiles.size === 0) {
            alert('Silakan upload file project terlebih dahulu!');
            return;
        }

        const analyzeBtn = document.getElementById('analyzeBtn');
        analyzeBtn.disabled = true;
        analyzeBtn.textContent = '🔍 Menganalisa...';

        try {
            const analysis = await this.performAnalysis(prompt);
            this.displayAnalysisResult(analysis);
        } catch (error) {
            console.error('Analysis error:', error);
            this.displayAnalysisResult({
                title: '❌ Error',
                content: 'Terjadi kesalahan saat menganalisa project: ' + error.message
            });
        } finally {
            analyzeBtn.disabled = false;
            analyzeBtn.textContent = '🔍 Analisa Project';
        }
    }

    async performAnalysis(prompt) {
        // Simulate API call delay
        await new Promise(resolve => setTimeout(resolve, 2000));

        const mentionedFiles = this.extractMentionedFiles(prompt);
        const projectContext = this.buildProjectContext(mentionedFiles);
        
        return {
            title: '📊 Hasil Analisa Project',
            content: this.generateAnalysisResponse(prompt, projectContext),
            timestamp: new Date().toLocaleTimeString()
        };
    }

    extractMentionedFiles(prompt) {
        const mentions = prompt.match(/@(\S+)/g) || [];
        return mentions.map(mention => mention.substring(1)); // Remove @ symbol
    }

    buildProjectContext(mentionedFiles) {
        const context = {
            allFiles: Array.from(this.uploadedFiles.keys()),
            mentionedFiles: {},
            projectStructure: this.getProjectStructure()
        };

        if (mentionedFiles.length === 0) {
            // If no specific files mentioned, include all files
            this.uploadedFiles.forEach((file, filename) => {
                context.mentionedFiles[filename] = file.content;
            });
        } else {
            // Only include mentioned files
            mentionedFiles.forEach(filename => {
                if (this.uploadedFiles.has(filename)) {
                    context.mentionedFiles[filename] = this.uploadedFiles.get(filename).content;
                }
            });
        }

        return context;
    }

    getProjectStructure() {
        const files = Array.from(this.uploadedFiles.keys());
        const structure = {};
        
        files.forEach(file => {
            const parts = file.split('/');
            let current = structure;
            
            parts.forEach((part, index) => {
                if (index === parts.length - 1) {
                    current[part] = 'file';
                } else {
                    if (!current[part]) {
                        current[part] = {};
                    }
                    current = current[part];
                }
            });
        });
        
        return structure;
    }

    generateAnalysisResponse(prompt, context) {
        const fileList = Object.keys(context.mentionedFiles).join(', ');
        
        return `ANALYSIS REQUEST: ${prompt}

PROJECT CONTEXT:
- Total Files: ${context.allFiles.length}
- Files Analyzed: ${fileList}
- Project Structure: ${JSON.stringify(context.projectStructure, null, 2)}

DETAILED ANALYSIS:
${this.generateDetailedAnalysis(prompt, context)}

RECOMMENDATIONS:
1. Perbaikan yang disarankan untuk file-file yang dianalisa
2. Optimasi struktur kode
3. Best practices implementation

NEXT STEPS:
- Implementasikan perubahan yang disarankan
- Test functionality setelah perubahan
- Review ulang architecture jika diperlukan

CATATAN:
Analisa ini berdasarkan pattern dan best practices umum. 
Selalu test perubahan di environment development terlebih dahulu.`;
    }

    generateDetailedAnalysis(prompt, context) {
        let analysis = '';

        Object.entries(context.mentionedFiles).forEach(([filename, content]) => {
            analysis += `\n--- ANALYSIS FOR: ${filename} ---\n`;
            
            // Simple analysis based on file type and content
            if (filename.endsWith('.js')) {
                analysis += this.analyzeJavaScriptFile(content);
            } else if (filename.endsWith('.html')) {
                analysis += this.analyzeHTMLFile(content);
            } else if (filename.endsWith('.css')) {
                analysis += this.analyzeCSSFile(content);
            } else {
                analysis += `File type: ${filename.split('.').pop()}\n`;
                analysis += `Lines: ${content.split('\n').length}\n`;
                analysis += `Size: ${content.length} characters\n`;
            }

            // Check for common issues
            analysis += this.checkCommonIssues(filename, content);
        });

        return analysis;
    }

    analyzeJavaScriptFile(content) {
        const lines = content.split('\n');
        const functions = content.match(/function\s+(\w+)|const\s+(\w+)\s*=\s*\(|let\s+(\w+)\s*=\s*\(/g) || [];
        const classes = content.match(/class\s+(\w+)/g) || [];
        
        return `JavaScript Analysis:
- Total Lines: ${lines.length}
- Functions Found: ${functions.length}
- Classes Found: ${classes.length}
- Code Structure: ${lines.length > 100 ? 'Complex' : 'Simple'}
- Potential Issues: ${this.checkJSIssues(content)}`;
    }

    analyzeHTMLFile(content) {
        const elements = content.match(/<\/?(\w+)/g) || [];
        const uniqueElements = [...new Set(elements)].length;
        
        return `HTML Analysis:
- Total Elements: ${elements.length}
- Unique Elements: ${uniqueElements}
- Structure Complexity: ${elements.length > 50 ? 'High' : 'Medium'}`;
    }

    analyzeCSSFile(content) {
        const rules = content.match(/([^{]+\{[^}]+\})/g) || [];
        const selectors = content.match(/([^{]+)\{/g) || [];
        
        return `CSS Analysis:
- Total Rules: ${rules.length}
- Selectors: ${selectors.length}
- Specificity Analysis: Standard`;
    }

    checkJSIssues(content) {
        const issues = [];
        
        if (content.includes('console.log')) {
            issues.push('Debug statements found');
        }
        if (content.includes('var ')) {
            issues.push('Using var instead of let/const');
        }
        if (content.includes('==')) {
            issues.push('Using loose equality operator');
        }
        
        return issues.length > 0 ? issues.join(', ') : 'No major issues found';
    }

    checkCommonIssues(filename, content) {
        const issues = [];
        
        // Large file check
        if (content.length > 10000) {
            issues.push('File terlalu besar, pertimbangkan untuk split');
        }
        
        // Long lines check
        const longLines = content.split('\n').filter(line => line.length > 120);
        if (longLines.length > 5) {
            issues.push('Banyak line yang terlalu panjang');
        }
        
        return issues.length > 0 ? `\nISSUES: ${issues.join('; ')}` : '\nNo major structural issues';
    }

    displayAnalysisResult(analysis) {
        const resultsContainer = document.getElementById('resultsContainer');
        const template = document.getElementById('resultTemplate');
        
        const clone = template.content.cloneNode(true);
        const resultElement = clone.querySelector('.analysis-result');
        
        resultElement.querySelector('.result-title').textContent = analysis.title;
        resultElement.querySelector('.result-time').textContent = analysis.timestamp;
        resultElement.querySelector('.result-content').textContent = analysis.content;
        
        // Add event listeners to buttons
        const copyBtn = resultElement.querySelector('.copy-btn');
        const clearBtn = resultElement.querySelector('.clear-btn');
        
        copyBtn.addEventListener('click', () => {
            navigator.clipboard.writeText(analysis.content).then(() => {
                copyBtn.textContent = '✓ Copied!';
                setTimeout(() => {
                    copyBtn.textContent = '📋 Copy';
                }, 2000);
            });
        });
        
        clearBtn.addEventListener('click', () => {
            resultElement.remove();
        });
        
        // Remove placeholder if it exists
        const placeholder = resultsContainer.querySelector('.placeholder');
        if (placeholder) {
            placeholder.remove();
        }
        
        resultsContainer.prepend(resultElement);
        resultsContainer.scrollTop = 0;
    }
}

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new DeepseekAnalyzer();
});

// Add some utility functions
window.utils = {
    formatCode: function(code, language) {
        return `\`\`\`${language}\n${code}\n\`\`\``;
    },
    
    estimateAnalysisTime: function(filesCount) {
        return Math.max(2000, filesCount * 1000); // Minimum 2 seconds
    }
};