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
    image                       = "aws/codebuild/standard:1.0"
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
