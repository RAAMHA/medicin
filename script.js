// Configuration - Replace with your actual values
const CONFIG = {
    API_GATEWAY_URL: 'https://your-api-gateway-url.amazonaws.com/prod/analyze',
    S3_BUCKET: 'your-prescription-bucket',
    REGION: 'us-east-1'
};

class PrescriptionAnalyzer {
    constructor() {
        this.initializeElements();
        this.setupEventListeners();
        this.selectedFile = null;
    }

    initializeElements() {
        this.uploadArea = document.getElementById('uploadArea');
        this.fileInput = document.getElementById('fileInput');
        this.uploadBtn = document.getElementById('uploadBtn');
        this.loading = document.getElementById('loading');
        this.results = document.getElementById('results');
        this.error = document.getElementById('error');
        this.medicineInfo = document.getElementById('medicineInfo');
        this.errorMessage = document.getElementById('errorMessage');
    }

    setupEventListeners() {
        // File input events
        this.uploadArea.addEventListener('click', () => this.fileInput.click());
        this.fileInput.addEventListener('change', (e) => this.handleFileSelect(e));
        
        // Drag and drop events
        this.uploadArea.addEventListener('dragover', (e) => this.handleDragOver(e));
        this.uploadArea.addEventListener('dragleave', (e) => this.handleDragLeave(e));
        this.uploadArea.addEventListener('drop', (e) => this.handleDrop(e));
        
        // Upload button
        this.uploadBtn.addEventListener('click', () => this.uploadAndAnalyze());
    }

    handleDragOver(e) {
        e.preventDefault();
        this.uploadArea.classList.add('dragover');
    }

    handleDragLeave(e) {
        e.preventDefault();
        this.uploadArea.classList.remove('dragover');
    }

    handleDrop(e) {
        e.preventDefault();
        this.uploadArea.classList.remove('dragover');
        const files = e.dataTransfer.files;
        if (files.length > 0) {
            this.selectedFile = files[0];
            this.updateUploadArea();
        }
    }

    handleFileSelect(e) {
        const file = e.target.files[0];
        if (file) {
            this.selectedFile = file;
            this.updateUploadArea();
        }
    }

    updateUploadArea() {
        if (this.selectedFile) {
            this.uploadArea.innerHTML = `
                <div class="upload-icon">✅</div>
                <h3>File Selected</h3>
                <p>${this.selectedFile.name}</p>
                <p>Size: ${(this.selectedFile.size / 1024 / 1024).toFixed(2)} MB</p>
            `;
            this.uploadBtn.disabled = false;
        }
    }

    async uploadAndAnalyze() {
        if (!this.selectedFile) return;

        this.showLoading();
        
        try {
            // Convert file to base64
            const base64File = await this.fileToBase64(this.selectedFile);
            
            // Call API Gateway endpoint
            const response = await fetch(CONFIG.API_GATEWAY_URL, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    fileName: this.selectedFile.name,
                    fileContent: base64File,
                    contentType: this.selectedFile.type
                })
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const result = await response.json();
            this.displayResults(result);
            
        } catch (error) {
            console.error('Error:', error);
            this.showError('Failed to analyze prescription. Please try again.');
        }
    }

    fileToBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.readAsDataURL(file);
            reader.onload = () => {
                // Remove the data:image/jpeg;base64, part
                const base64 = reader.result.split(',')[1];
                resolve(base64);
            };
            reader.onerror = error => reject(error);
        });
    }

    showLoading() {
        this.loading.style.display = 'block';
        this.results.style.display = 'none';
        this.error.style.display = 'none';
    }

    displayResults(data) {
        this.loading.style.display = 'none';
        this.results.style.display = 'block';
        this.error.style.display = 'none';

        // Parse the medicine data
        const medicines = data.medicines || [];
        
        if (medicines.length === 0) {
            this.medicineInfo.innerHTML = `
                <div class="medicine-card">
                    <div class="medicine-name">No medicines detected</div>
                    <p>Please ensure your prescription is clear and readable.</p>
                </div>
            `;
            return;
        }

        this.medicineInfo.innerHTML = medicines.map(medicine => `
            <div class="medicine-card">
                <div class="medicine-name">${medicine.name}</div>
                <div class="medicine-details">
                    <div class="detail-item">
                        <span class="detail-label">Generic Name</span>
                        <span class="detail-value">${medicine.genericName || 'N/A'}</span>
                    </div>
                    <div class="detail-item">
                        <span class="detail-label">Dosage</span>
                        <span class="detail-value">${medicine.dosage || 'N/A'}</span>
                    </div>
                    <div class="detail-item">
                        <span class="detail-label">Frequency</span>
                        <span class="detail-value">${medicine.frequency || 'N/A'}</span>
                    </div>
                    <div class="detail-item">
                        <span class="detail-label">Duration</span>
                        <span class="detail-value">${medicine.duration || 'N/A'}</span>
                    </div>
                    <div class="detail-item">
                        <span class="detail-label">Side Effects</span>
                        <span class="detail-value">${medicine.sideEffects || 'Consult your doctor'}</span>
                    </div>
                    <div class="detail-item">
                        <span class="detail-label">Precautions</span>
                        <span class="detail-value">${medicine.precautions || 'Follow doctor\'s advice'}</span>
                    </div>
                </div>
            </div>
        `).join('');
    }

    showError(message) {
        this.loading.style.display = 'none';
        this.results.style.display = 'none';
        this.error.style.display = 'block';
        this.errorMessage.textContent = message;
    }
}

// Initialize the application
document.addEventListener('DOMContentLoaded', () => {
    new PrescriptionAnalyzer();
});