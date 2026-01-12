terraform {
  required_providers {
    aws = {}
  }
}

provider "aws" {
  profile = "gmail"
  region = "ap-northeast-1"
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-secrets-role"

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
            "token.actions.githubusercontent.com:sub" = "repo:nphamvn/remoteit-ansible:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}
resource "aws_iam_policy" "secrets_read" {
  name = "github-actions-secrets-read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.openvpn.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.secrets_read.arn
}

resource "aws_secretsmanager_secret" "openvpn" {
  name = "openvpn-client"
}

resource "aws_secretsmanager_secret_version" "openvpn_value" {
  secret_id     = aws_secretsmanager_secret.openvpn.id
  secret_string = file("client.ovpn")
}
