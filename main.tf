# ===============VPC===============
# module "vpc" {
#   source   = "./modules/vpc"
#   az_count = 2
# }

# ===============S3 Bucket for Documents===============
module "documents_s3_bucket" {
  source      = "./modules/s3"
  bucket_name = "${var.s3_documents_name_prefix}.${var.domain}"
}

module "analyzed_documents_s3_bucket" {
  source      = "./modules/s3"
  bucket_name = "${var.s3_analyzed_documents_name_prefix}.${var.domain}"
}

# resource "cloudflare_record" "cf_record_documents" {
#   zone_id         = var.cloudflare_zone_id
#   allow_overwrite = true
#   proxied         = true
#   name            = var.s3_documents_name_prefix
#   type            = "CNAME"
#   data {
#     content = module.documents_s3_bucket.bucket_name_regional_domain_name
#   }
# }

# ===============Textract Flow===============
data "aws_caller_identity" "current" {}

# textract role begin
resource "aws_iam_role" "textract_role" {
  name = "Textract"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": {
    "Sid": "ConfusedDeputyPreventionExamplePolicy",
    "Effect": "Allow",
    "Principal": {
      "Service": "textract.amazonaws.com"
    },
    "Action": "sts:AssumeRole",
    "Condition": {
      "ArnLike": {
        "aws:SourceArn": "arn:aws:textract:*:${data.aws_caller_identity.current.account_id}:*"
      },
      "StringEquals": {
        "aws:SourceAccount": "${data.aws_caller_identity.current.account_id}"
      }
    }
  }
}
EOF
}

data "aws_iam_policy_document" "pass_role" {
  version = "2012-10-17"
  statement {
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.textract_role.arn]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "textract_pass_role_policy" {
  name   = "textract-pass-role-policy"
  policy = data.aws_iam_policy_document.pass_role.json
}

resource "aws_iam_role_policy_attachment" "textract_role_policy_attachment" {
  role       = aws_iam_role.textract_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonTextractFullAccess"
}

resource "aws_iam_role_policy_attachment" "textract_role_policy_attachment_sns_publish" {
  role       = aws_iam_role.textract_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonTextractServiceRole"
}

# END textract role

# Lambda invoke textract begin
resource "aws_iam_role" "lambda_invoke_textract" {
  name = "lambda-invoke-textract-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_invoke_textract_policy" {
  name = "lambda-invoke-textract-policy"
  role = aws_iam_role.lambda_invoke_textract.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject"
        ],
        Resource = [
          "${module.documents_s3_bucket.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "textract:*"
        ],
        Resource = "*"
      }
    ]
  })
}

module "lambda_invoke_textract" {
  source        = "./modules/lambda"
  function_name = "invoke-textract"
  role_arn      = aws_iam_role.lambda_invoke_textract.arn
  environment_vars = {
    TEXTRACT_DESTINATION_TOPIC = aws_sns_topic.textract_updates.arn
    TEXTRACT_ROLE_ARN          = aws_iam_role.textract_role.arn
  }
}

resource "aws_lambda_permission" "s3_document_invoke" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_invoke_textract.arn
  principal     = "s3.amazonaws.com"
  source_arn    = module.documents_s3_bucket.bucket_arn
}

resource "aws_s3_bucket_notification" "documents_s3_bucket_notification" {
  bucket = module.documents_s3_bucket.bucket_name

  lambda_function {
    lambda_function_arn = module.lambda_invoke_textract.arn
    events              = ["s3:ObjectCreated:*"]
  }
}
# Lambda invoke textract END

# Lambda analyze textract begin
resource "aws_iam_role" "lambda_analyze_textract" {
  name = "lambda-analyze-textract-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_analyze_textract_policy" {
  name = "lambda-analyze-textract-policy"
  role = aws_iam_role.lambda_analyze_textract.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "sqs:*"
        ],
        Resource = [
          "*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject"
        ],
        Resource = [
          "${module.analyzed_documents_s3_bucket.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "textract:*"
        ],
        Resource = "*"
      }
    ]
  })
}

module "lambda_analyze_textract" {
  source        = "./modules/lambda"
  function_name = "analyze-textract"
  role_arn      = aws_iam_role.lambda_analyze_textract.arn
  environment_vars = {
    S3_ANALYZED_BUCKET = module.analyzed_documents_s3_bucket.bucket_name
  }
}

resource "aws_sns_topic" "textract_updates" {
  name = "AmazonTextract-Topic"
}

resource "aws_sqs_queue" "textract_queue" {
  name                       = "textract-queue"
  visibility_timeout_seconds = 7200
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action : ["sqs:SendMessage"],
        Condition : {
          ArnEquals : {
            "aws:SourceArn" : aws_sns_topic.textract_updates.arn
          }
        },
        Effect : "Allow",
        Principal : {
          Service : "sns.amazonaws.com"
        },
        Resource : "*"
      },
      {
        Action : ["sqs:ReceiveMessage"],
        Condition : {
          ArnEquals : {
            "aws:SourceArn" : module.lambda_analyze_textract.arn
          }
        },
        Effect : "Allow",
        Principal : {
          Service : "lambda.amazonaws.com"
        },
        Resource : "*"
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "textract_sqs_target" {
  topic_arn = aws_sns_topic.textract_updates.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.textract_queue.arn
}

resource "aws_lambda_event_source_mapping" "textract_queue" {
  event_source_arn = aws_sqs_queue.textract_queue.arn
  function_name    = module.lambda_analyze_textract.arn
  batch_size       = 10
  enabled          = true
}
# Lambda analyze textract END
