# ============================================================================
# GitHub Actions OIDC Setup
# ============================================================================
# GitHub Actions가 AWS에 접근할 수 있도록 OIDC 설정
#
# 사용법:
#   cd github-oidc
#   terraform init
#   terraform apply
#
# ⚠️ 이 파일은 infra-terragrunt 배포 전에 먼저 실행해야 합니다!
# ============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# ============================================================================
# Variables
# ============================================================================
variable "github_org" {
  description = "GitHub Organization 또는 Username"
  type        = string
}

variable "github_repo" {
  description = "GitHub Repository 이름"
  type        = string
}

# ============================================================================
# GitHub OIDC Provider
# ============================================================================
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name      = "github-actions-oidc"
    ManagedBy = "terraform"
  }
}

# ============================================================================
# IAM Role for GitHub Actions
# ============================================================================
resource "aws_iam_role" "github_actions" {
  name = "github-actions-terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "github-actions-terraform"
    ManagedBy = "terraform"
  }
}

# ============================================================================
# IAM Policy - AdministratorAccess (또는 필요한 권한만)
# ============================================================================
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ============================================================================
# Outputs
# ============================================================================
output "role_arn" {
  description = "GitHub Secrets에 등록할 Role ARN (AWS_ROLE_ARN)"
  value       = aws_iam_role.github_actions.arn
}

output "setup_instructions" {
  description = "설정 가이드"
  value       = <<-EOT

  ============================================
  ✅ GitHub Actions OIDC 설정 완료!
  ============================================

  다음 단계:

  1. GitHub Repository → Settings → Secrets and variables → Actions

  2. New repository secret 클릭

  3. 다음 Secret 추가:
     Name:  AWS_ROLE_ARN
     Value: ${aws_iam_role.github_actions.arn}

  4. 이제 PR 생성하면 자동으로 Plan 실행됩니다!

  EOT
}