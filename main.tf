terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" {
  region = var.region  # 利用したいAWSリージョン
}

# ------------------------------
# SQS
# ------------------------------
resource "aws_sqs_queue" "example_queue" {
  name                      = "my-example-queue"
  delay_seconds             = 0
  max_message_size          = 262144   # デフォルト: 256KB
  message_retention_seconds = 345600   # デフォルト: 4日
  receive_wait_time_seconds = 10
}


# DynamoDB テーブル（ユーザー用）
resource "aws_dynamodb_table" "users" {
  name           = "${var.project_name}-users"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-users"
  }
}

# DynamoDB テーブル（投稿用）
resource "aws_dynamodb_table" "posts" {
  name           = "${var.project_name}-posts"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "authorId"
    type = "S"
  }

  global_secondary_index {
    name               = "AuthorIndex"
    hash_key           = "authorId"
    projection_type    = "ALL"
  }

  tags = {
    Name = "${var.project_name}-posts"
  }
}

# AppSync GraphQL API
resource "aws_appsync_graphql_api" "main" {
  name                = "${var.project_name}-api"
  authentication_type = "API_KEY"
  schema              = file("${path.module}/config/graphql/schema.graphql")

  tags = {
    Name = "${var.project_name}-api"
  }
}

# API Key
resource "aws_appsync_api_key" "main" {
  api_id  = aws_appsync_graphql_api.main.id
  expires = timeadd(timestamp(), "8760h")
}

# IAM Role for AppSync
resource "aws_iam_role" "appsync" {
  name = "${var.project_name}-appsync-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "appsync" {
  name = "${var.project_name}-appsync-policy"
  role = aws_iam_role.appsync.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          aws_dynamodb_table.users.arn,
          aws_dynamodb_table.posts.arn,
          "${aws_dynamodb_table.posts.arn}/index/*"
        ]
      }
    ]
  })
}

# Data Sources
resource "aws_appsync_datasource" "users" {
  api_id           = aws_appsync_graphql_api.main.id
  name             = "UsersTable"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.users.name
  }
}

resource "aws_appsync_datasource" "posts" {
  api_id           = aws_appsync_graphql_api.main.id
  name             = "PostsTable"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.posts.name
  }
}

# Resolvers
resource "aws_appsync_resolver" "get_user" {
  api_id      = aws_appsync_graphql_api.main.id
  field       = "getUser"
  type        = "Query"
  data_source = aws_appsync_datasource.users.name

  request_template = jsonencode({
    version = "2018-05-29"
    operation = "GetItem"
    key = {
      id = { S = "$ctx.args.id" }
    }
  })

  response_template = "#if($ctx.error)$util.error($ctx.error.message, $ctx.error.type)#end$util.toJson($ctx.result)"
}

resource "aws_appsync_resolver" "list_users" {
  api_id      = aws_appsync_graphql_api.main.id
  field       = "listUsers"
  type        = "Query"
  data_source = aws_appsync_datasource.users.name

  request_template = jsonencode({
    version = "2018-05-29"
    operation = "Scan"
  })

  response_template = "#if($ctx.error)$util.error($ctx.error.message, $ctx.error.type)#end$util.toJson($ctx.result.items)"
}

resource "aws_appsync_resolver" "create_user" {
  api_id      = aws_appsync_graphql_api.main.id
  field       = "createUser"
  type        = "Mutation"
  data_source = aws_appsync_datasource.users.name

  request_template = jsonencode({
    version = "2018-05-29"
    operation = "PutItem"
    key = {
      id = { S = "$util.autoId()" }
    }
    attributeValues = {
      name = { S = "$ctx.args.input.name" }
      email = { S = "$ctx.args.input.email" }
      createdAt = { S = "$util.time.nowISO8601()" }
    }
  })

  response_template = "#if($ctx.error)$util.error($ctx.error.message, $ctx.error.type)#end$util.toJson($ctx.result)"
}

resource "aws_appsync_resolver" "create_post" {
  api_id      = aws_appsync_graphql_api.main.id
  field       = "createPost"
  type        = "Mutation"
  data_source = aws_appsync_datasource.posts.name

  request_template = jsonencode({
    version = "2018-05-29"
    operation = "PutItem"
    key = {
      id = { S = "$util.autoId()" }
    }
    attributeValues = {
      title = { S = "$ctx.args.input.title" }
      content = { S = "$ctx.args.input.content" }
      authorId = { S = "$ctx.args.input.authorId" }
      createdAt = { S = "$util.time.nowISO8601()" }
    }
  })

  response_template = "#if($ctx.error)$util.error($ctx.error.message, $ctx.error.type)#end$util.toJson($ctx.result)"
}


