provider "aws" {
  region = "ap-northeast-1"  # 利用したいAWSリージョン
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

# ------------------------------
# AppSync(GraphQL実験用)
# URL:aws_appsync_graphql_api.this.uris["GRAPHQL"]
# key:aws_appsync_api_key.this.key
# ------------------------------
resource "aws_appsync_graphql_api" "this" {
  name                 = "sample-appsync"
  authentication_type  = "API_KEY"

  # スキーマを直接埋め込み
  schema = <<EOF
type Query {
  hello(name: String): String
}
EOF
}

# API_KEY 認証の有効化
resource "aws_appsync_api_key" "this" {
  api_id  = aws_appsync_graphql_api.this.id
  # expires を省略するとデフォルト 7 日後に失効します
}

# NONE データソース（擬似レスポンス用）
resource "aws_appsync_datasource" "none" {
  api_id     = aws_appsync_graphql_api.this.id
  name       = "NoneDataSource"
  type       = "NONE"
}

# Resolver 定義：hello フィールド
resource "aws_appsync_resolver" "hello" {
  api_id      = aws_appsync_graphql_api.this.id
  type        = "Query"
  field       = "hello"
  data_source = aws_appsync_datasource.none.name

  # リクエストテンプレートは空のペイロードを返す
  request_template = <<EOF
{
  "version": "2017-02-28",
  "payload": {}
}
EOF

  # レスポンステンプレートで引数を読み取り、文字列として返却
  response_template = <<EOF
#if($ctx.error)
  $util.error($ctx.error.message, $ctx.error.type)
#end

#set($name = $ctx.arguments.name)
#if(!$name)
  #set($name = "World")
#end

$util.toJson("Hello, $name!")
EOF
}