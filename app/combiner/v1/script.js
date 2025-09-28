class DeepseekAnalyzer {
    constructor() {
        this.uploadedFiles = new Map();
        this.analysisHistory = [];
        this.currentAnalysis = null;
        this.initializeEventListeners();
    }

    initializeEventListeners() {
        // File input handling
        const fileInput = document.getElementById('fileInput');
        const uploadArea = document.getElementById('uploadArea');
        const analyzeBtn = document.getElementById('analyzeBtn');
        const downloadBtn = document.getElementById('downloadBtn');

        // Drag and drop functionality
        uploadArea.addEventListener('click', () => fileInput.click());
        uploadArea.addEventListener('dragover', this.handleDragOver.bind(this));
        uploadArea.addEventListener('dragleave', this.handleDragLeave.bind(this));
        uploadArea.addEventListener('drop', this.handleDrop.bind(this));

        // File input change
        fileInput.addEventListener('change', this.handleFileSelect.bind(this));

        // Analyze button
        analyzeBtn.addEventListener('click', this.analyzeProject.bind(this));

        // Download button
        downloadBtn.addEventListener('click', this.downloadAnalysisReport.bind(this));
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
                    type: file.type,
                    path: file.webkitRelativePath || file.name
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
            this.currentAnalysis = analysis;
            this.analysisHistory.push(analysis);
            this.displayAnalysisResult(analysis);
            
            // Enable download button
            document.getElementById('downloadBtn').disabled = false;
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
            prompt: prompt,
            timestamp: new Date().toLocaleString(),
            mentionedFiles: mentionedFiles,
            projectContext: projectContext
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
            projectStructure: this.getProjectStructure(),
            fileContents: {}
        };

        if (mentionedFiles.length === 0) {
            // If no specific files mentioned, include all files
            this.uploadedFiles.forEach((file, filename) => {
                context.mentionedFiles[filename] = file.content;
                context.fileContents[filename] = file.content;
            });
        } else {
            // Only include mentioned files
            mentionedFiles.forEach(filename => {
                if (this.uploadedFiles.has(filename)) {
                    context.mentionedFiles[filename] = this.uploadedFiles.get(filename).content;
                    context.fileContents[filename] = this.uploadedFiles.get(filename).content;
                }
            });
        }

        return context;
    }

    getProjectStructure() {
        const structure = {};
        
        this.uploadedFiles.forEach((file, filename) => {
            const path = file.path || filename;
            const parts = path.split('/');
            let current = structure;
            
            for (let i = 0; i < parts.length; i++) {
                const part = parts[i];
                if (i === parts.length - 1) {
                    // File
                    current[part] = {
                        type: 'file',
                        size: file.size,
                        path: path
                    };
                } else {
                    // Folder
                    if (!current[part] || current[part].type !== 'folder') {
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

    generateAnalysisResponse(prompt, context) {
        const fileList = Object.keys(context.mentionedFiles).join(', ');
        
        return `ANALYSIS REQUEST: ${prompt}

PROJECT CONTEXT:
- Total Files: ${context.allFiles.length}
- Files Analyzed: ${fileList}

DETAILED ANALYSIS:
${this.generateDetailedAnalysis(prompt, context)}

RECOMMENDATIONS:
${this.generateRecommendations(context)}

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

    generateRecommendations(context) {
        let recommendations = [];
        
        Object.entries(context.mentionedFiles).forEach(([filename, content]) => {
            if (filename.endsWith('.js') && content.length > 5000) {
                recommendations.push(`Pertimbangkan untuk memecah file ${filename} menjadi modul yang lebih kecil`);
            }
            
            if (content.includes('var ')) {
                recommendations.push(`Ganti 'var' dengan 'let/const' di file ${filename}`);
            }
            
            if (content.includes('==')) {
                recommendations.push(`Gunakan '===' instead of '==' di file ${filename}`);
            }
        });
        
        if (recommendations.length === 0) {
            recommendations.push('Struktur kode sudah baik, pertahankan!');
        }
        
        return recommendations.map((rec, index) => `${index + 1}. ${rec}`).join('\n');
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
            // If no results left, show placeholder
            if (resultsContainer.children.length === 0) {
                resultsContainer.innerHTML = '<div class="placeholder">🚀 Upload project dan klik "Analisa Project" untuk mulai</div>';
            }
        });
        
        // Remove placeholder if it exists
        const placeholder = resultsContainer.querySelector('.placeholder');
        if (placeholder) {
            placeholder.remove();
        }
        
        resultsContainer.prepend(resultElement);
        resultsContainer.scrollTop = 0;
    }

    // NEW: Function to generate and download analysis report
    downloadAnalysisReport() {
        if (!this.currentAnalysis) {
            alert('Tidak ada analisa untuk didownload! Silakan analisa project terlebih dahulu.');
            return;
        }

        const reportContent = this.generateReportContent();
        const blob = new Blob([reportContent], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        
        a.href = url;
        a.download = `deepseek-analysis-report-${new Date().toISOString().slice(0, 19).replace(/:/g, '-')}.txt`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    generateReportContent() {
        let report = '';
        
        // Header
        report += '='.repeat(80) + '\n';
        report += 'DEEPSEEK PROJECT ANALYSIS REPORT\n';
        report += '='.repeat(80) + '\n\n';
        
        // Metadata
        report += `Generated: ${new Date().toLocaleString()}\n`;
        report += `Total Files: ${this.uploadedFiles.size}\n`;
        report += `Analysis Request: ${this.currentAnalysis.prompt}\n\n`;
        
        // Project Structure
        report += 'PROJECT STRUCTURE\n';
        report += '-'.repeat(40) + '\n';
        report += this.generateStructureTree(this.getProjectStructure()) + '\n\n';
        
        // File Contents with line numbers
        report += 'FILE CONTENTS WITH ANALYSIS\n';
        report += '-'.repeat(40) + '\n\n';
        
        this.uploadedFiles.forEach((file, filename) => {
            report += `FILE: ${filename}\n`;
            report += `PATH: ${file.path || filename}\n`;
            report += `SIZE: ${this.formatFileSize(file.size)}\n`;
            report += '-'.repeat(60) + '\n\n';
            
            // File content with line numbers
            const lines = file.content.split('\n');
            lines.forEach((line, index) => {
                report += `${(index + 1).toString().padStart(4)}: ${line}\n`;
            });
            
            // File-specific analysis
            report += '\n' + 'ANALYSIS FOR THIS FILE:\n';
            report += '~'.repeat(30) + '\n';
            report += this.generateFileAnalysis(filename, file.content) + '\n\n';
            
            report += '='.repeat(80) + '\n\n';
        });
        
        // Overall Analysis
        report += 'OVERALL ANALYSIS AND RECOMMENDATIONS\n';
        report += '-'.repeat(50) + '\n\n';
        report += this.currentAnalysis.content + '\n\n';
        
        // Analysis History
        if (this.analysisHistory.length > 1) {
            report += 'ANALYSIS HISTORY\n';
            report += '-'.repeat(30) + '\n\n';
            this.analysisHistory.forEach((analysis, index) => {
                report += `Analysis #${index + 1} (${analysis.timestamp}):\n`;
                report += `Request: ${analysis.prompt}\n`;
                report += `Files Analyzed: ${analysis.mentionedFiles.join(', ') || 'All files'}\n`;
                report += '---\n\n';
            });
        }
        
        return report;
    }

    generateStructureTree(structure, indent = 0) {
        let tree = '';
        const prefix = '  '.repeat(indent);
        
        for (const [name, item] of Object.entries(structure)) {
            if (item.type === 'folder') {
                tree += `${prefix}📁 ${name}/\n`;
                tree += this.generateStructureTree(item.children, indent + 1);
            } else {
                tree += `${prefix}📄 ${name} (${this.formatFileSize(item.size)})\n`;
            }
        }
        
        return tree;
    }

    generateFileAnalysis(filename, content) {
        let analysis = '';
        
        if (filename.endsWith('.js')) {
            analysis += this.analyzeJavaScriptFile(content);
        } else if (filename.endsWith('.html')) {
            analysis += this.analyzeHTMLFile(content);
        } else if (filename.endsWith('.css')) {
            analysis += this.analyzeCSSFile(content);
        } else {
            analysis += `File Type: ${filename.split('.').pop() || 'Unknown'}\n`;
            analysis += `Line Count: ${content.split('\n').length}\n`;
            analysis += `File Size: ${content.length} characters\n`;
        }
        
        // Add specific recommendations
        analysis += '\nRECOMMENDATIONS:\n';
        const recommendations = this.getFileRecommendations(filename, content);
        recommendations.forEach((rec, index) => {
            analysis += `${index + 1}. ${rec}\n`;
        });
        
        return analysis;
    }

    getFileRecommendations(filename, content) {
        const recommendations = [];
        
        if (filename.endsWith('.js')) {
            if (content.includes('var ')) {
                recommendations.push('Ganti "var" dengan "let" atau "const" untuk better scoping');
            }
            if (content.includes('==')) {
                recommendations.push('Gunakan "===" untuk strict equality checks');
            }
            if (content.includes('console.log')) {
                recommendations.push('Hapus atau comment console.log statements untuk production');
            }
            if (content.length > 5000) {
                recommendations.push('Pertimbangkan untuk memecah file menjadi modul yang lebih kecil');
            }
        }
        
        if (filename.endsWith('.html')) {
            if (!content.includes('<!DOCTYPE html>')) {
                recommendations.push('Tambahkan DOCTYPE declaration');
            }
            if (!content.includes('<meta charset="UTF-8">')) {
                recommendations.push('Tambahkan charset meta tag');
            }
            if (!content.includes('<meta name="viewport"')) {
                recommendations.push('Tambahkan viewport meta tag untuk responsive design');
            }
        }
        
        if (filename.endsWith('.css')) {
            const longSelectors = content.match(/([^{]+\{[^}]+\})/g)?.filter(rule => rule.length > 200) || [];
            if (longSelectors.length > 0) {
                recommendations.push('Pertimbangkan untuk memecah CSS rules yang terlalu panjang');
            }
        }
        
        if (recommendations.length === 0) {
            recommendations.push('Tidak ada rekomendasi spesifik - file terlihat baik');
        }
        
        return recommendations;
    }
}

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new DeepseekAnalyzer();
});