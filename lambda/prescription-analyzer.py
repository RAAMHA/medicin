import json
import boto3
import base64
import uuid
from datetime import datetime
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
textract_client = boto3.client('textract')

# Medicine database (in production, use DynamoDB or RDS)
MEDICINE_DATABASE = {
    'paracetamol': {
        'name': 'Paracetamol',
        'genericName': 'Acetaminophen',
        'dosage': '500mg',
        'frequency': '3 times daily',
        'duration': 'As needed',
        'sideEffects': 'Rare: skin rash, blood disorders',
        'precautions': 'Do not exceed 4g per day. Avoid alcohol.'
    },
    'ibuprofen': {
        'name': 'Ibuprofen',
        'genericName': 'Ibuprofen',
        'dosage': '400mg',
        'frequency': '2-3 times daily',
        'duration': 'Maximum 10 days',
        'sideEffects': 'Stomach upset, dizziness, headache',
        'precautions': 'Take with food. Avoid if allergic to NSAIDs.'
    },
    'amoxicillin': {
        'name': 'Amoxicillin',
        'genericName': 'Amoxicillin',
        'dosage': '250mg-500mg',
        'frequency': '3 times daily',
        'duration': '7-10 days',
        'sideEffects': 'Nausea, diarrhea, skin rash',
        'precautions': 'Complete full course. Inform doctor of allergies.'
    },
    'aspirin': {
        'name': 'Aspirin',
        'genericName': 'Acetylsalicylic acid',
        'dosage': '75mg-300mg',
        'frequency': 'Once daily',
        'duration': 'As prescribed',
        'sideEffects': 'Stomach irritation, bleeding',
        'precautions': 'Take with food. Monitor for bleeding.'
    },
    'metformin': {
        'name': 'Metformin',
        'genericName': 'Metformin HCl',
        'dosage': '500mg-1000mg',
        'frequency': '2-3 times daily',
        'duration': 'Long term',
        'sideEffects': 'Nausea, diarrhea, metallic taste',
        'precautions': 'Take with meals. Monitor kidney function.'
    }
}

def lambda_handler(event, context):
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Parse the request body
        if 'body' in event:
            body = json.loads(event['body'])
        else:
            body = event
            
        file_name = body.get('fileName', f'prescription_{uuid.uuid4()}.jpg')
        file_content = body.get('fileContent')
        content_type = body.get('contentType', 'image/jpeg')
        
        if not file_content:
            return create_response(400, {'error': 'No file content provided'})
        
        # Upload file to S3
        bucket_name = 'your-prescription-bucket'  # Replace with your bucket name
        s3_key = f'prescriptions/{datetime.now().strftime("%Y/%m/%d")}/{file_name}'
        
        # Decode base64 content
        file_bytes = base64.b64decode(file_content)
        
        # Upload to S3
        s3_client.put_object(
            Bucket=bucket_name,
            Key=s3_key,
            Body=file_bytes,
            ContentType=content_type
        )
        
        logger.info(f"File uploaded to S3: {s3_key}")
        
        # Analyze with Textract (for image files)
        if content_type.startswith('image/'):
            extracted_text = extract_text_from_image(file_bytes)
        else:
            # For text files, decode directly
            extracted_text = file_bytes.decode('utf-8')
        
        logger.info(f"Extracted text: {extracted_text}")
        
        # Analyze medicines from extracted text
        medicines = analyze_medicines(extracted_text)
        
        # Prepare response
        response_data = {
            'success': True,
            'fileName': file_name,
            's3Key': s3_key,
            'extractedText': extracted_text,
            'medicines': medicines,
            'timestamp': datetime.now().isoformat()
        }
        
        return create_response(200, response_data)
        
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        return create_response(500, {'error': f'Internal server error: {str(e)}'})

def extract_text_from_image(image_bytes):
    """Extract text from image using Amazon Textract"""
    try:
        response = textract_client.detect_document_text(
            Document={'Bytes': image_bytes}
        )
        
        # Extract text from Textract response
        extracted_text = ""
        for block in response['Blocks']:
            if block['BlockType'] == 'LINE':
                extracted_text += block['Text'] + "\n"
        
        return extracted_text.strip()
        
    except Exception as e:
        logger.error(f"Error extracting text: {str(e)}")
        return ""

def analyze_medicines(text):
    """Analyze extracted text to identify medicines"""
    medicines = []
    text_lower = text.lower()
    
    # Simple keyword matching (in production, use NLP/ML models)
    for medicine_key, medicine_info in MEDICINE_DATABASE.items():
        if medicine_key in text_lower or medicine_info['name'].lower() in text_lower:
            medicines.append(medicine_info)
    
    # If no medicines found, try to extract common medicine patterns
    if not medicines:
        # Look for common medicine name patterns
        import re
        
        # Common medicine suffixes
        medicine_patterns = [
            r'\b\w+cillin\b',  # antibiotics like amoxicillin
            r'\b\w+ol\b',      # like paracetamol
            r'\b\w+ine\b',     # like aspirin
            r'\b\w+min\b',     # like metformin
        ]
        
        found_medicines = []
        for pattern in medicine_patterns:
            matches = re.findall(pattern, text_lower)
            found_medicines.extend(matches)
        
        # Create generic entries for found medicines
        for med in found_medicines[:3]:  # Limit to 3 medicines
            medicines.append({
                'name': med.title(),
                'genericName': 'Please consult your pharmacist',
                'dosage': 'As prescribed',
                'frequency': 'As prescribed',
                'duration': 'As prescribed',
                'sideEffects': 'Consult your doctor or pharmacist',
                'precautions': 'Follow your doctor\'s instructions'
            })
    
    return medicines

def create_response(status_code, body):
    """Create HTTP response with CORS headers"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization'
        },
        'body': json.dumps(body)
    }