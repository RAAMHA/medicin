# Medicine Prescription Analyzer

A complete DevOps/MLOps practice project that analyzes medicine prescriptions using AWS services with CI/CD pipeline.

## 🏗️ Architecture

```
User Upload → S3 → Lambda (Textract) → API Gateway → CloudFront → User
```

## 🛠️ Technologies Used

- **Frontend**: HTML, CSS, JavaScript
- **Backend**: AWS Lambda (Python)
- **Storage**: Amazon S3
- **OCR**: Amazon Textract
- **API**: Amazon API Gateway
- **CDN**: Amazon CloudFront
- **Infrastructure**: Terraform
- **CI/CD**: GitHub Actions

## 📋 Prerequisites

1. AWS Account with appropriate permissions
2. GitHub account
3. Terraform installed locally (for testing)
4. Node.js 18+ installed

## 🚀 Setup Instructions

### Step 1: Clone and Setup Repository

```bash
git clone <your-repo-url>
cd medicine-prescription-analyzer
npm install
```

### Step 2: Configure AWS Credentials

Add these secrets to your GitHub repository:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### Step 3: Deploy Infrastructure

The deployment happens automatically via GitHub Actions when you push to main branch.

Manual deployment:
```bash
# Prepare Lambda package
cd lambda
zip -r ../terraform/prescription_analyzer.zip . -x "*.pyc" "__pycache__/*"

# Deploy infrastructure
cd ../terraform
terraform init
terraform plan
terraform apply
```

### Step 4: Update Configuration

After deployment, update the API Gateway URL in `script.js`:
```javascript
const CONFIG = {
    API_GATEWAY_URL: 'https://your-actual-api-id.execute-api.us-east-1.amazonaws.com/prod/analyze',
    // ... other config
};
```

### Step 5: Deploy Frontend

```bash
npm run build
aws s3 sync dist/ s3://your-website-bucket-name/ --delete
```

## 🧪 Testing the Application

1. Open the CloudFront URL in your browser
2. Upload a prescription image or text file
3. Click "Analyze Prescription"
4. View the medicine information results

## 📁 Project Structure

```
├── index.html              # Frontend HTML
├── style.css              # Frontend styles
├── script.js              # Frontend JavaScript
├── lambda/
│   ├── prescription-analyzer.py  # Lambda function
│   └── requirements.txt          # Python dependencies
├── terraform/
│   └── main.tf            # Infrastructure as Code
├── .github/workflows/
│   └── deploy.yml         # CI/CD pipeline
└── README.md
```

## 🔧 AWS Services Configuration

### S3 Buckets
- **Prescription Bucket**: Stores uploaded prescription files
- **Website Bucket**: Hosts static frontend files

### Lambda Function
- **Runtime**: Python 3.9
- **Timeout**: 30 seconds
- **Memory**: 128 MB
- **Permissions**: S3, Textract, CloudWatch Logs

### API Gateway
- **Type**: REST API
- **CORS**: Enabled
- **Methods**: POST, OPTIONS

### CloudFront
- **Origin**: S3 website bucket
- **Caching**: Enabled with TTL
- **HTTPS**: Redirect enabled

## 🔍 Medicine Database

The system includes a basic medicine database with information for:
- Paracetamol
- Ibuprofen
- Amoxicillin
- Aspirin
- Metformin

## 🚨 Security Considerations

1. **IAM Roles**: Least privilege access
2. **S3 Encryption**: Server-side encryption enabled
3. **API Gateway**: Rate limiting recommended
4. **CORS**: Configured for frontend domain

## 📊 Monitoring and Logging

- **CloudWatch Logs**: Lambda function logs
- **S3 Access Logs**: File upload tracking
- **API Gateway Logs**: Request/response logging

## 🔄 CI/CD Pipeline

The GitHub Actions workflow:
1. **Test**: Syntax validation and build testing
2. **Infrastructure**: Terraform deployment
3. **Frontend**: Build and deploy to S3
4. **Invalidation**: CloudFront cache invalidation

## 💰 Cost Optimization

- **S3**: Lifecycle policies for old files
- **Lambda**: Right-sized memory allocation
- **CloudFront**: Appropriate caching strategies
- **API Gateway**: Request-based pricing

## 🎯 DevOps Learning Objectives

This project covers:
- ✅ Infrastructure as Code (Terraform)
- ✅ CI/CD Pipelines (GitHub Actions)
- ✅ Containerization concepts
- ✅ Cloud services integration
- ✅ Monitoring and logging
- ✅ Security best practices

## 🔮 Future Enhancements

1. **ML Integration**: Add actual ML models for medicine recognition
2. **Database**: Replace in-memory database with DynamoDB
3. **Authentication**: Add user authentication
4. **Mobile App**: React Native or Flutter app
5. **Advanced OCR**: Custom trained models
6. **Multi-language**: Support multiple languages

## 🐛 Troubleshooting

### Common Issues:

1. **Lambda Timeout**: Increase timeout in Terraform
2. **CORS Errors**: Check API Gateway CORS configuration
3. **S3 Access**: Verify bucket policies and IAM roles
4. **Textract Limits**: Check AWS service quotas

### Debug Commands:

```bash
# Check Lambda logs
aws logs tail /aws/lambda/medicine-prescription-analyzer-analyzer --follow

# Test API Gateway
curl -X POST https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/analyze

# Check S3 bucket contents
aws s3 ls s3://your-bucket-name --recursive
```

## 📞 Support

For issues and questions:
1. Check the troubleshooting section
2. Review AWS CloudWatch logs
3. Verify IAM permissions
4. Check Terraform state

---

**Happy Learning! 🎉**

This project provides hands-on experience with modern DevOps practices and AWS cloud services.