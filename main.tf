resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "mckinnel-test-bucket"
  acl    = "private"
}

resource "aws_iam_role" "codepipeline_role" {
  name = "test-role"

  assume_role_policy = data.aws_iam_policy_document.codepipeline-assume-role-policy.json
}

data "aws_iam_policy_document" "codepipeline-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codepipeline-role-policy" {
  statement {
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]
    resources = ["*"]
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

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = aws_iam_role.codepipeline_role.id

  policy = data.aws_iam_policy_document.codepipeline-role-policy.json
}

resource "aws_kms_key" "s3_kms_key" {
  description             = "Test KMS key"
  deletion_window_in_days = 10
}

resource "aws_kms_alias" "s3_kms_key_alias" {
  name          = "alias/codepipeline-key"
  target_key_id = aws_kms_key.s3_kms_key.key_id
}

resource "aws_codepipeline" "codepipeline" {
  name     = "tf-test-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"

    encryption_key {
      id   = aws_kms_alias.s3_kms_key_alias.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner      = "chrismckinnel-leaven"
        Repo       = "test-cloudformation-repo"
        Branch     = "master"
        OAuthToken = var.GITHUB_OAUTH_TOKEN
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = "test"
        EnvironmentVariables = jsonencode([
          {
            name  = "CODEPIPELINE_BUCKET",
            value = aws_s3_bucket.codepipeline_bucket.id
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }
}

