resource "aws_s3_bucket" "codebuild_bucket" {
  bucket = "mckinnel-codebuild-test-bucket"
  acl    = "private"
}

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role"

  assume_role_policy = data.aws_iam_policy_document.codebuild-assume-role-policy.json
}

data "aws_iam_policy_document" "codebuild-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codebuild-role-policy" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"

    ]
    resources = [
      "*"
    ]
  }
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObject",
    ]
    resources = [
      aws_s3_bucket.codepipeline_bucket.arn,
      "${aws_s3_bucket.codepipeline_bucket.arn}/*",
      aws_s3_bucket.codebuild_bucket.arn,
      "${aws_s3_bucket.codebuild_bucket.arn}/*",
    ]
  }
  statement {
    actions = [
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyPair",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:Decrypt"
    ]
    resources = [aws_kms_key.s3_kms_key.arn]
  }
  statement {
    actions = [
      "cloudformation:List*",
      "cloudformation:Get*",
      "cloudformation:ValidateTemplate"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    actions = [
      "cloudformation:CreateStack",
      "cloudformation:CreateUploadBucket",
      "cloudformation:DeleteStack",
      "cloudformation:Describe*",
      "cloudformation:UpdateStack"
    ]
    resources = [
      "arn:aws:cloudformation:ap-southeast-2:*:stack/test-serverless-project-*/*"
    ]
  }
  statement {
    actions = [
      "lambda:Get*",
      "lambda:List*",
      "lambda:CreateFunction"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    actions = [
      "s3:GetBucketLocation",
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:GetBucketPolicy"
      "s3:GetBucketPolicyStatus"
      "s3:PutBucketPolicy"
      "s3:DeleteBucketPolicy"
      "s3:PutAccelerateConfiguration",
      "s3:GetEncryptionConfiguration",
      "s3:PutEncryptionConfiguration"
    ]
    resources = [
      "arn:aws:s3:::test-serverless-project*serverlessdeploy*"
    ]
  }
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::test-serverless-project*serverlessdeploy*"
    ]
  }
  statement {
    actions = [
      "lambda:AddPermission",
      "lambda:CreateAlias",
      "lambda:DeleteFunction",
      "lambda:InvokeFunction",
      "lambda:PublishVersion",
      "lambda:RemovePermission",
      "lambda:Update*"
    ]
    resources = [
      "arn:aws:lambda:ap-southeast-2:*:function:test-serverless-project-*-*"
    ]
  }
  statement {
    actions = [
      "apigateway:GET",
      "apigateway:POST",
      "apigateway:PUT",
      "apigateway:DELETE",
      "apigateway:PATCH"
    ]
    resources = [
      "arn:aws:apigateway:*::/restapis*",
      "arn:aws:apigateway:*::/apikeys*",
      "arn:aws:apigateway:*::/usageplans*"
    ]
  }
  statement {
    actions = [
      "iam:PassRole"
    ]
    resources = [
      "arn:aws:iam::*:role/*"
    ]
  }
  statement {
    actions = [
      "iam:GetRole",
      "iam:CreateRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:DeleteRole"
    ]
    resources = [
      "arn:aws:iam::*:role/test-serverless-project-*-ap-southeast-2-lambdaRole"
    ]
  }
}

resource "aws_iam_role_policy" "codebuild_role_policy" {
  name = "codebuild_role_policy"
  role = aws_iam_role.codebuild_role.id

  policy = data.aws_iam_policy_document.codebuild-role-policy.json
}

resource "aws_codebuild_project" "example" {
  name          = "test"
  description   = "test_codebuild_project"
  build_timeout = "5"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type     = "S3"
    location = aws_s3_bucket.codebuild_bucket.bucket
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "node:lts"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "codebuild-test-log-group"
      stream_name = "codebuild-test-log-stream"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.codebuild_bucket.id}/build-log"
    }
  }

  source {
    type = "CODEPIPELINE"
  }
}
