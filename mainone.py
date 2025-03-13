Invoke-textract lambdafrom aws_lambda_powertools import Tracer, Logger
import boto3
import os
import json
LOGGER = Logger()
TRACER = Tracer()
textract = boto3.client('textract')
s3 = boto3.client('s3')
@TRACER.capture_lambda_handler
@LOGGER.inject_lambda_context(log_event=True)
def handler(event, context):
   # Parse the S3 event data
    bucket = event['Records'][0]['s3']['bucket']['name']
    document = event['Records'][0]['s3']['object']['key']
    # Call Textract to start the asynchronous job
    response = textract.start_document_analysis(
        DocumentLocation={
            'S3Object': {
                'Bucket': bucket,
                'Name': document
            }
        },
        NotificationChannel={
            "SNSTopicArn": os.getenv("TEXTRACT_DESTINATION_TOPIC"),
            "RoleArn": os.getenv("TEXTRACT_ROLE_ARN")
        },
        FeatureTypes=["TABLES", "FORMS"]
    )
    # Get the job ID from the response
    job_id = response['JobId']
    LOGGER.info(f'Textract job started with JobId: {job_id}')
    # Optionally, you could store the JobId in a database or another S3 bucket for tracking
    # For example:
    # store_job_id_in_s3(job_id, bucket, document)
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Textract job started successfully',
            'jobId': job_id
        })
    }