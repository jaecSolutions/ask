import json
import boto3
import os
LOGGER = Logger()
TRACER = Tracer()
textract = boto3.client('textract')
s3 = boto3.client('s3')
@TRACER.capture_lambda_handler
@LOGGER.inject_lambda_context(log_event=True)
def handler(event, context):
    # Iterate over each record in the event
    for record in event['Records']:
        # Extract the body of the SQS message
        sns_payload = json.loads(record['body'])
        textract_payload = json.loads(sns_payload.get('Message'))
        # Extract the Job ID from the message (assuming the message contains it)
        job_id = textract_payload.get('JobId')
        if job_id:
            # Retrieve the Textract results
            response = textract.get_document_analysis(JobId=job_id)
            # Save to S3
            s3.put_object(
                Bucket=os.getenv('S3_ANALYZED_BUCKET'),
                Key=f'{job_id}.json',
                Body=json.dumps(response),
                ContentType='application/json'
            )
        else:
            LOGGER.info(f"Job ID not found in the message.")
    return {
        'statusCode': 200,
        'body': json.dumps('Messages processed successfully.')
    }